"""A provider that answers from a scripted list, so tests never touch a network."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from xcollect.models import Page, Tweet
from xcollect.providers.base import Provider

BASE_ID = 1_800_000_000_000_000_000


def make_tweet(offset: int, *, handle: str = "nasa", likes: int = 10) -> Tweet:
    return Tweet(
        id=str(BASE_ID + offset),
        created_at=datetime(2026, 9, 9, tzinfo=timezone.utc) + timedelta(minutes=offset),
        text=f"post {offset}",
        author_handle=handle,
        author_id="1",
        like_count=likes,
    )


class FakeProvider(Provider):
    name = "fake"
    billing_unit = "tweet"
    min_interval_s = 0.0

    def __init__(self, pages: list[list[Tweet]], *, per_tweet: float = 0.00015,
                 per_call: float = 0.0, unit: str = "tweet") -> None:
        super().__init__(api_key="test")
        self.pages = pages
        self.per_tweet = per_tweet
        self.per_call = per_call
        self.unit = unit
        self.calls: list[tuple[str, str | None]] = []
        # Worst case one page of 20 tweets, matching the real adapters.
        self.max_call_cost_usd = per_call if unit == "call" else 20 * per_tweet

    def search(self, query: str, cursor: str | None = None) -> Page:
        self.calls.append((query, cursor))
        index = int(cursor) if cursor else 0
        tweets = self.pages[index] if index < len(self.pages) else []
        # Newest first, the order X's Latest search returns.
        tweets = sorted(tweets, key=lambda t: t.id_int, reverse=True)
        has_more = index + 1 < len(self.pages)
        cost = self.per_call if self.unit == "call" else len(tweets) * self.per_tweet
        return Page(
            tweets=tweets,
            next_cursor=str(index + 1) if has_more else None,
            cost_usd=cost,
            billed_units=1.0 if self.unit == "call" else float(len(tweets)),
            unit=self.unit,
        )
