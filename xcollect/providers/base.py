"""Provider adapter interface.

Every adapter turns one HTTP response into a `Page` of normalised `Tweet`s and
reports what that response cost. Cost accounting lives here rather than in the
collector because the whole point of the abstraction is that providers bill on
different axes: per tweet returned vs per call made.
"""

from __future__ import annotations

import abc
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

from ..models import Page

USER_AGENT = "xcollect/0.1 (+https://github.com/)"


class ProviderError(RuntimeError):
    """Raised for anything that makes a response unusable."""


class ResponseShapeError(ProviderError):
    """The provider answered, but not in the shape this adapter expects.

    Kept distinct because it means the adapter needs updating, not that the
    network or the credentials are broken. Run `python -m xcollect probe` to
    dump the raw response and fix the mapping.
    """


class Provider(abc.ABC):
    name: str = "base"
    #: "tweet" or "call" - the axis this provider bills on.
    billing_unit: str = "tweet"
    #: Seconds to wait between requests. Free tiers are often rate limited.
    min_interval_s: float = 0.0
    #: Worst-case cost of one call, used as budget headroom so the ceiling is
    #: never crossed rather than merely detected afterwards.
    max_call_cost_usd: float = 0.0

    def __init__(self, api_key: str, *, timeout: float = 30.0) -> None:
        if not api_key:
            raise ProviderError(f"{self.name}: no API key supplied")
        self.api_key = api_key
        self.timeout = timeout
        self._last_request_at = 0.0

    @abc.abstractmethod
    def search(self, query: str, cursor: str | None = None) -> Page:
        """Run one advanced-search request and return a single page."""

    # -- shared HTTP plumbing -------------------------------------------------

    def _throttle(self) -> None:
        if not self.min_interval_s:
            return
        wait = self.min_interval_s - (time.monotonic() - self._last_request_at)
        if wait > 0:
            time.sleep(wait)

    def _get(
        self,
        url: str,
        params: dict[str, Any],
        headers: dict[str, str],
        *,
        retries: int = 3,
    ) -> dict[str, Any]:
        clean = {k: v for k, v in params.items() if v is not None}
        full = f"{url}?{urllib.parse.urlencode(clean)}"
        headers = {"User-Agent": USER_AGENT, "Accept": "application/json", **headers}

        last_error: Exception | None = None
        for attempt in range(retries):
            self._throttle()
            request = urllib.request.Request(full, headers=headers, method="GET")
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    self._last_request_at = time.monotonic()
                    body = response.read().decode("utf-8")
                return json.loads(body)
            except urllib.error.HTTPError as exc:
                self._last_request_at = time.monotonic()
                detail = exc.read().decode("utf-8", "replace")[:400]
                # 402 means credits exhausted, 401/403 mean bad key. Retrying
                # those just burns time and, on some providers, quota.
                if exc.code in (400, 401, 402, 403, 404):
                    raise ProviderError(
                        f"{self.name}: HTTP {exc.code} - {detail}"
                    ) from exc
                last_error = exc
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                self._last_request_at = time.monotonic()
                last_error = exc
            if attempt < retries - 1:
                time.sleep(2**attempt)

        raise ProviderError(f"{self.name}: request failed after {retries} attempts: {last_error}")


def _require(payload: dict[str, Any], key: str, provider: str) -> Any:
    if key not in payload:
        raise ResponseShapeError(
            f"{provider}: expected key {key!r} in response, got keys "
            f"{sorted(payload)[:12]}. Run `python -m xcollect probe` and update the adapter."
        )
    return payload[key]


def env_key(*names: str) -> str:
    for name in names:
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return ""
