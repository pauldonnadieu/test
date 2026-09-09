"""Config loading and query construction.

Query construction is the cost centre of this project, so it lives here rather
than being scattered through the collector: every operator we add is applied
server-side by X's search, which means it filters *before* the provider bills us.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

# X's advanced search caps queries at roughly 512 characters. Staying under a
# configurable margin keeps batched from: clauses from silently truncating.
DEFAULT_MAX_QUERY_CHARS = 480


class ConfigError(ValueError):
    pass


@dataclass(slots=True)
class BudgetConfig:
    monthly_usd_ceiling: float = 3.00
    max_pages_per_query: int = 3
    # Refuse to start a run that could not possibly finish within the ceiling.
    stop_on_exceeded: bool = True


@dataclass(slots=True)
class CollectionConfig:
    #: Re-ask for a small overlap before the last watermark so a post that
    #: landed mid-request is not lost between runs.
    overlap_seconds: int = 300
    #: How far back to reach the very first time a source is seen.
    cold_start_hours: int = 6
    #: Cap on the window after an outage, so a week of downtime does not
    #: produce one enormous (and expensive) catch-up query.
    max_lookback_hours: int = 48
    handles_per_batch: int = 20
    max_query_chars: int = DEFAULT_MAX_QUERY_CHARS


@dataclass(slots=True)
class AccountsConfig:
    handles: list[str] = field(default_factory=list)
    cadence_hours: int = 1
    #: Empty runs double the interval, up to 2**level. Level 2 means a silent
    #: account is polled every 4 hours instead of every hour.
    backoff_max_level: int = 2
    exclude_replies: bool = True
    exclude_retweets: bool = True
    lang: str | None = None


@dataclass(slots=True)
class TopicConfig:
    name: str
    keywords: list[str]
    #: The single biggest cost lever. Applied by X before the provider bills us.
    min_faves: int = 500
    min_retweets: int = 0
    cadence_hours: int = 2
    backoff_max_level: int = 1
    exclude_replies: bool = True
    exclude_retweets: bool = True
    lang: str | None = "en"


@dataclass(slots=True)
class Config:
    provider: str = "twitterapi_io"
    budget: BudgetConfig = field(default_factory=BudgetConfig)
    collection: CollectionConfig = field(default_factory=CollectionConfig)
    accounts: AccountsConfig = field(default_factory=AccountsConfig)
    topics: list[TopicConfig] = field(default_factory=list)

    @classmethod
    def load(cls, path: str | Path) -> "Config":
        path = Path(path)
        if not path.exists():
            raise ConfigError(f"config not found: {path}")
        data = yaml.safe_load(path.read_text()) or {}
        if not isinstance(data, dict):
            raise ConfigError(f"{path}: expected a mapping at the top level")
        return cls.from_dict(data)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Config":
        topics = []
        for index, raw in enumerate(data.get("topics") or []):
            if not isinstance(raw, dict):
                raise ConfigError(f"topics[{index}]: expected a mapping")
            if not raw.get("name"):
                raise ConfigError(f"topics[{index}]: missing 'name'")
            if not raw.get("keywords"):
                raise ConfigError(f"topic {raw['name']!r}: needs at least one keyword")
            topics.append(TopicConfig(**_only_known(raw, TopicConfig)))

        accounts = AccountsConfig(**_only_known(data.get("accounts") or {}, AccountsConfig))
        accounts.handles = [h.lstrip("@").strip() for h in accounts.handles if str(h).strip()]

        config = cls(
            provider=data.get("provider", "twitterapi_io"),
            budget=BudgetConfig(**_only_known(data.get("budget") or {}, BudgetConfig)),
            collection=CollectionConfig(**_only_known(data.get("collection") or {}, CollectionConfig)),
            accounts=accounts,
            topics=topics,
        )
        if not config.accounts.handles and not config.topics:
            raise ConfigError("nothing to collect: define accounts.handles or topics")
        if config.budget.monthly_usd_ceiling <= 0:
            raise ConfigError("budget.monthly_usd_ceiling must be positive")
        return config


def _only_known(raw: dict[str, Any], target: type) -> dict[str, Any]:
    """Drop unknown keys with a clear error rather than a TypeError traceback."""
    known = {f for f in target.__dataclass_fields__}
    unknown = set(raw) - known
    if unknown:
        raise ConfigError(
            f"{target.__name__}: unknown option(s) {sorted(unknown)}; valid: {sorted(known)}"
        )
    return dict(raw)


# -- query construction -------------------------------------------------------


def _filters(exclude_replies: bool, exclude_retweets: bool, lang: str | None) -> list[str]:
    parts = []
    if exclude_replies:
        parts.append("-filter:replies")
    if exclude_retweets:
        # nativeretweets is the operator X's search honours; -is:retweet is the
        # v2 API spelling and is silently ignored by search.
        parts.append("-filter:nativeretweets")
    if lang:
        parts.append(f"lang:{lang}")
    return parts


def batch_handles(handles: list[str], per_batch: int, max_chars: int) -> list[list[str]]:
    """Split handles into groups whose OR-clause fits X's query length cap.

    Batching is what makes the account list affordable: one call covers ~20
    accounts instead of 20 calls covering one each.
    """
    batches: list[list[str]] = []
    current: list[str] = []
    current_chars = 0
    for handle in handles:
        clause = len(handle) + len("from: OR ")
        too_long = current and (current_chars + clause > max_chars or len(current) >= per_batch)
        if too_long:
            batches.append(current)
            current, current_chars = [], 0
        current.append(handle)
        current_chars += clause
    if current:
        batches.append(current)
    return batches


def accounts_query(handles: list[str], since_epoch: int, cfg: AccountsConfig) -> str:
    froms = " OR ".join(f"from:{h}" for h in handles)
    parts = [f"({froms})", f"since_time:{since_epoch}"]
    parts += _filters(cfg.exclude_replies, cfg.exclude_retweets, cfg.lang)
    return " ".join(parts)


def topic_query(topic: TopicConfig, since_epoch: int) -> str:
    terms = " OR ".join(_quote(k) for k in topic.keywords)
    parts = [f"({terms})", f"since_time:{since_epoch}"]
    if topic.min_faves > 0:
        parts.append(f"min_faves:{topic.min_faves}")
    if topic.min_retweets > 0:
        parts.append(f"min_retweets:{topic.min_retweets}")
    parts += _filters(topic.exclude_replies, topic.exclude_retweets, topic.lang)
    return " ".join(parts)


def _quote(keyword: str) -> str:
    keyword = keyword.strip()
    if not keyword:
        return keyword
    # Multi-word keywords must be quoted or X treats them as separate ORed terms.
    if " " in keyword and not (keyword.startswith('"') and keyword.endswith('"')):
        return f'"{keyword}"'
    return keyword
