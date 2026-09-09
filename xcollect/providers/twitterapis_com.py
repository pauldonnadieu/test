"""TwitterAPIs.com adapter - bills per call, not per tweet.

IMPORTANT: the exact response shape here is PROVISIONAL. Their docs were not
reachable when this was written, so the mapping below is tolerant by design: it
tries the field spellings these providers conventionally use and raises
ResponseShapeError with a clear message if none match. Run

    python -m xcollect probe --provider twitterapis_com --query "from:nasa"

during phase 0, then tighten `_TWEET_KEYS` / `_map` against the real payload.
The per-call billing model is the verified part, and it is the reason this
adapter exists at all: at $0.0008 per call returning up to ~20 tweets, it beats
per-tweet pricing whenever a call comes back with more than ~5.3 tweets.
"""

from __future__ import annotations

from typing import Any

from ..models import Page, Tweet
from .base import Provider, ResponseShapeError
from .twitterapi_io import _as_int, _parse_created_at

BASE_URL = "https://api.twitterapis.com"
USD_PER_CALL = 0.0008

# Response containers to look in, most likely first.
_TWEET_KEYS = ("tweets", "data", "results", "items", "statuses")
_CURSOR_KEYS = ("next_cursor", "nextCursor", "cursor", "next")


def _first(item: dict[str, Any], *names: str, default: Any = None) -> Any:
    for name in names:
        if name in item and item[name] is not None:
            return item[name]
    return default


class TwitterApisCom(Provider):
    name = "twitterapis_com"
    billing_unit = "call"
    min_interval_s = 1.0
    max_call_cost_usd = USD_PER_CALL

    def search(self, query: str, cursor: str | None = None) -> Page:
        payload = self._get(
            f"{BASE_URL}/twitter/tweet/advanced_search",
            {"query": query, "queryType": "Latest", "cursor": cursor},
            {"X-API-Key": self.api_key},
        )

        raw_tweets = None
        for key in _TWEET_KEYS:
            value = payload.get(key)
            if isinstance(value, list):
                raw_tweets = value
                break
        if raw_tweets is None:
            raise ResponseShapeError(
                f"{self.name}: no tweet list found under any of {_TWEET_KEYS}. "
                f"Response keys: {sorted(payload)[:12]}. "
                "Run `python -m xcollect probe --provider twitterapis_com` and update _TWEET_KEYS."
            )

        tweets = [self._map(item) for item in raw_tweets]
        next_cursor = _first(payload, *_CURSOR_KEYS) or None

        # Billed per call regardless of how many tweets came back - which is
        # exactly why an empty poll is expensive here and cheap on twitterapi.io.
        return Page(
            tweets=tweets,
            next_cursor=str(next_cursor) if next_cursor else None,
            cost_usd=USD_PER_CALL,
            billed_units=1.0,
            unit="call",
        )

    def _map(self, item: dict[str, Any]) -> Tweet:
        author = _first(item, "author", "user", default={}) or {}
        handle = _first(author, "userName", "username", "screen_name", "handle", default="")
        tweet_id = _first(item, "id", "id_str", "tweet_id")
        if tweet_id is None:
            raise ResponseShapeError(
                f"{self.name}: tweet object has no id field. Keys: {sorted(item)[:12]}"
            )
        return Tweet(
            id=str(tweet_id),
            created_at=_parse_created_at(_first(item, "createdAt", "created_at", "date")),
            text=_first(item, "text", "full_text", "content", default="") or "",
            author_handle=str(handle),
            author_id=str(_first(author, "id", "id_str", "user_id", default="") or ""),
            like_count=_as_int(_first(item, "likeCount", "favorite_count", "likes")),
            retweet_count=_as_int(_first(item, "retweetCount", "retweet_count", "retweets")),
            reply_count=_as_int(_first(item, "replyCount", "reply_count", "replies")),
            quote_count=_as_int(_first(item, "quoteCount", "quote_count", "quotes")),
            view_count=_as_int(_first(item, "viewCount", "view_count", "views")) or None,
            lang=_first(item, "lang", "language"),
            is_reply=bool(_first(item, "isReply", "is_reply", "in_reply_to_status_id")),
            is_retweet=bool(_first(item, "isRetweet", "is_retweet", "retweeted_status")),
            raw=item,
        )
