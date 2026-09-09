"""Normalised records shared by every provider adapter."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


@dataclass(slots=True)
class Tweet:
    """One post, normalised away from any provider's response shape."""

    id: str
    created_at: datetime
    text: str
    author_handle: str
    author_id: str
    like_count: int = 0
    retweet_count: int = 0
    reply_count: int = 0
    quote_count: int = 0
    view_count: int | None = None
    lang: str | None = None
    is_reply: bool = False
    is_retweet: bool = False
    raw: dict[str, Any] = field(default_factory=dict, repr=False)

    @property
    def url(self) -> str:
        return f"https://x.com/{self.author_handle}/status/{self.id}"

    @property
    def id_int(self) -> int:
        """Snowflake IDs sort chronologically as integers."""
        return int(self.id)


@dataclass(slots=True)
class Page:
    """One provider response, plus what it cost us."""

    tweets: list[Tweet]
    next_cursor: str | None
    cost_usd: float
    # What the provider actually billed: tweets for per-tweet pricing,
    # calls for per-call pricing. Kept separate from cost_usd so the
    # phase-0 bake-off can compare billing models, not just totals.
    billed_units: float
    unit: str

    @property
    def has_next(self) -> bool:
        return bool(self.next_cursor) and bool(self.tweets)


def parse_epoch(value: Any) -> datetime:
    return datetime.fromtimestamp(int(value), tz=timezone.utc)
