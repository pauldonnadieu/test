"""twitterapi.io adapter - bills per tweet returned.

Endpoint and response shape per docs.twitterapi.io: advanced_search takes the
full X search syntax and paginates with an opaque cursor.
"""

from __future__ import annotations

from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any

from ..models import Page, Tweet
from .base import Provider, ResponseShapeError, _require

BASE_URL = "https://api.twitterapi.io"
USD_PER_TWEET = 0.00015


def _parse_created_at(value: Any) -> datetime:
    """twitterapi.io returns X's native format: 'Wed Sep 09 11:22:33 +0000 2026'."""
    if not value:
        return datetime.now(tz=timezone.utc)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)
    try:
        return parsedate_to_datetime(str(value)).astimezone(timezone.utc)
    except (TypeError, ValueError):
        pass
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return datetime.now(tz=timezone.utc)


def _as_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


class TwitterApiIo(Provider):
    name = "twitterapi_io"
    billing_unit = "tweet"
    # Free tier allows one request per 5s; paid tiers lift this. Being polite
    # by default costs nothing at hourly cadence.
    min_interval_s = 5.0
    # A full advanced_search page is 20 tweets.
    max_call_cost_usd = 20 * USD_PER_TWEET

    def search(self, query: str, cursor: str | None = None) -> Page:
        payload = self._get(
            f"{BASE_URL}/twitter/tweet/advanced_search",
            {"query": query, "queryType": "Latest", "cursor": cursor},
            {"X-API-Key": self.api_key},
        )
        raw_tweets = _require(payload, "tweets", self.name)
        if not isinstance(raw_tweets, list):
            raise ResponseShapeError(f"{self.name}: 'tweets' was {type(raw_tweets).__name__}, expected list")

        tweets = [self._map(item) for item in raw_tweets]
        next_cursor = payload.get("next_cursor") or None
        if not payload.get("has_next_page", bool(next_cursor)):
            next_cursor = None

        return Page(
            tweets=tweets,
            next_cursor=next_cursor,
            cost_usd=len(tweets) * USD_PER_TWEET,
            billed_units=float(len(tweets)),
            unit="tweet",
        )

    def _map(self, item: dict[str, Any]) -> Tweet:
        author = item.get("author") or {}
        handle = author.get("userName") or author.get("screen_name") or ""
        return Tweet(
            id=str(_require(item, "id", self.name)),
            created_at=_parse_created_at(item.get("createdAt") or item.get("created_at")),
            text=item.get("text") or "",
            author_handle=handle,
            author_id=str(author.get("id") or ""),
            like_count=_as_int(item.get("likeCount")),
            retweet_count=_as_int(item.get("retweetCount")),
            reply_count=_as_int(item.get("replyCount")),
            quote_count=_as_int(item.get("quoteCount")),
            view_count=_as_int(item.get("viewCount")) or None,
            lang=item.get("lang"),
            is_reply=bool(item.get("isReply") or item.get("inReplyToId")),
            is_retweet=bool(item.get("retweeted_tweet") or item.get("retweetedTweet")),
            raw=item,
        )
