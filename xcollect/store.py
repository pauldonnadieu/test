"""SQLite persistence: collected tweets, per-source watermarks, spend ledger.

Local runs use stdlib sqlite3 against a file. CI runs point LIBSQL_URL at a
Turso database so state survives the ephemeral runner; the libsql client is
DB-API compatible, so nothing below changes.
"""

from __future__ import annotations

import json
import os
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .models import Tweet

SCHEMA = """
CREATE TABLE IF NOT EXISTS tweets (
    id              TEXT PRIMARY KEY,
    created_at      INTEGER NOT NULL,
    text            TEXT NOT NULL,
    author_handle   TEXT NOT NULL,
    author_id       TEXT,
    like_count      INTEGER DEFAULT 0,
    retweet_count   INTEGER DEFAULT 0,
    reply_count     INTEGER DEFAULT 0,
    quote_count     INTEGER DEFAULT 0,
    view_count      INTEGER,
    lang            TEXT,
    is_reply        INTEGER DEFAULT 0,
    is_retweet      INTEGER DEFAULT 0,
    source_key      TEXT NOT NULL,
    first_seen_at   INTEGER NOT NULL,
    raw             TEXT
);
CREATE INDEX IF NOT EXISTS idx_tweets_created ON tweets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tweets_source  ON tweets(source_key, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tweets_author  ON tweets(author_handle, created_at DESC);

CREATE TABLE IF NOT EXISTS sources (
    key               TEXT PRIMARY KEY,
    kind              TEXT NOT NULL,
    last_run_at       INTEGER,
    high_water_id     TEXT,
    backoff_level     INTEGER DEFAULT 0,
    consecutive_empty INTEGER DEFAULT 0,
    last_new_count    INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS runs (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at   INTEGER NOT NULL,
    finished_at  INTEGER,
    provider     TEXT NOT NULL,
    status       TEXT NOT NULL,
    new_tweets   INTEGER DEFAULT 0,
    calls        INTEGER DEFAULT 0,
    billed_units REAL DEFAULT 0,
    cost_usd     REAL DEFAULT 0,
    note         TEXT
);

CREATE TABLE IF NOT EXISTS spend (
    month        TEXT NOT NULL,
    provider     TEXT NOT NULL,
    calls        INTEGER DEFAULT 0,
    billed_units REAL DEFAULT 0,
    cost_usd     REAL DEFAULT 0,
    PRIMARY KEY (month, provider)
);
"""


@dataclass(slots=True)
class SourceState:
    key: str
    kind: str
    last_run_at: int | None = None
    high_water_id: str | None = None
    backoff_level: int = 0
    consecutive_empty: int = 0
    last_new_count: int = 0

    @property
    def high_water_int(self) -> int:
        try:
            return int(self.high_water_id or 0)
        except (TypeError, ValueError):
            return 0


def now_epoch() -> int:
    return int(datetime.now(tz=timezone.utc).timestamp())


def current_month() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m")


class Store:
    def __init__(self, path: str = "xcollect.db") -> None:
        self.path = path
        self.conn = self._connect(path)
        self.conn.executescript(SCHEMA)
        self.conn.commit()

    @staticmethod
    def _connect(path: str) -> Any:
        url = os.environ.get("LIBSQL_URL", "").strip()
        if url:
            try:
                import libsql  # type: ignore
            except ImportError as exc:  # pragma: no cover - depends on env
                raise RuntimeError(
                    "LIBSQL_URL is set but the 'libsql' package is not installed; "
                    "pip install libsql, or unset LIBSQL_URL to use a local file"
                ) from exc
            return libsql.connect(url, auth_token=os.environ.get("LIBSQL_AUTH_TOKEN", ""))
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def close(self) -> None:
        self.conn.close()

    def __enter__(self) -> "Store":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    # -- sources --------------------------------------------------------------

    def get_source(self, key: str, kind: str) -> SourceState:
        """Read a source's watermark state. Deliberately does not create a row:
        planning a run (including a dry run) must not mutate the database."""
        row = self.conn.execute("SELECT * FROM sources WHERE key = ?", (key,)).fetchone()
        if row is None:
            return SourceState(key=key, kind=kind)
        return SourceState(
            key=row["key"],
            kind=row["kind"],
            last_run_at=row["last_run_at"],
            high_water_id=row["high_water_id"],
            backoff_level=row["backoff_level"] or 0,
            consecutive_empty=row["consecutive_empty"] or 0,
            last_new_count=row["last_new_count"] or 0,
        )

    def save_source(self, state: SourceState) -> None:
        self.conn.execute(
            """
            INSERT INTO sources
                (key, kind, last_run_at, high_water_id, backoff_level,
                 consecutive_empty, last_new_count)
            VALUES (?,?,?,?,?,?,?)
            ON CONFLICT(key) DO UPDATE SET
                kind = excluded.kind,
                last_run_at = excluded.last_run_at,
                high_water_id = excluded.high_water_id,
                backoff_level = excluded.backoff_level,
                consecutive_empty = excluded.consecutive_empty,
                last_new_count = excluded.last_new_count
            """,
            (
                state.key,
                state.kind,
                state.last_run_at,
                state.high_water_id,
                state.backoff_level,
                state.consecutive_empty,
                state.last_new_count,
            ),
        )
        self.conn.commit()

    def all_sources(self) -> list[SourceState]:
        rows = self.conn.execute("SELECT * FROM sources ORDER BY key").fetchall()
        return [
            SourceState(
                key=r["key"],
                kind=r["kind"],
                last_run_at=r["last_run_at"],
                high_water_id=r["high_water_id"],
                backoff_level=r["backoff_level"] or 0,
                consecutive_empty=r["consecutive_empty"] or 0,
                last_new_count=r["last_new_count"] or 0,
            )
            for r in rows
        ]

    # -- tweets ---------------------------------------------------------------

    def known_ids(self, ids: Iterable[str]) -> set[str]:
        ids = list(ids)
        if not ids:
            return set()
        found: set[str] = set()
        # Chunked to stay under SQLite's variable limit on large pages.
        for start in range(0, len(ids), 500):
            chunk = ids[start : start + 500]
            placeholders = ",".join("?" * len(chunk))
            rows = self.conn.execute(
                f"SELECT id FROM tweets WHERE id IN ({placeholders})", chunk
            ).fetchall()
            found.update(r["id"] for r in rows)
        return found

    def insert_tweets(self, tweets: list[Tweet], source_key: str) -> int:
        """Insert, ignoring duplicates. Returns the number actually new."""
        if not tweets:
            return 0
        seen = now_epoch()
        rows = [
            (
                t.id,
                int(t.created_at.timestamp()),
                t.text,
                t.author_handle,
                t.author_id,
                t.like_count,
                t.retweet_count,
                t.reply_count,
                t.quote_count,
                t.view_count,
                t.lang,
                int(t.is_reply),
                int(t.is_retweet),
                source_key,
                seen,
                json.dumps(t.raw, separators=(",", ":")),
            )
            for t in tweets
        ]
        before = self.conn.total_changes
        self.conn.executemany(
            """
            INSERT OR IGNORE INTO tweets
                (id, created_at, text, author_handle, author_id, like_count,
                 retweet_count, reply_count, quote_count, view_count, lang,
                 is_reply, is_retweet, source_key, first_seen_at, raw)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            rows,
        )
        self.conn.commit()
        return self.conn.total_changes - before

    def tweet_count(self) -> int:
        return self.conn.execute("SELECT COUNT(*) AS n FROM tweets").fetchone()["n"]

    # -- runs and spend -------------------------------------------------------

    def start_run(self, provider: str) -> int:
        cur = self.conn.execute(
            "INSERT INTO runs (started_at, provider, status) VALUES (?, ?, 'running')",
            (now_epoch(), provider),
        )
        self.conn.commit()
        return int(cur.lastrowid)

    def finish_run(
        self,
        run_id: int,
        *,
        status: str,
        new_tweets: int,
        calls: int,
        billed_units: float,
        cost_usd: float,
        note: str = "",
    ) -> None:
        self.conn.execute(
            """
            UPDATE runs SET finished_at = ?, status = ?, new_tweets = ?, calls = ?,
                            billed_units = ?, cost_usd = ?, note = ?
             WHERE id = ?
            """,
            (now_epoch(), status, new_tweets, calls, billed_units, cost_usd, note, run_id),
        )
        self.conn.commit()

    def record_spend(self, provider: str, *, calls: int, billed_units: float, cost_usd: float) -> None:
        month = current_month()
        self.conn.execute(
            "INSERT OR IGNORE INTO spend (month, provider) VALUES (?, ?)", (month, provider)
        )
        self.conn.execute(
            """
            UPDATE spend
               SET calls = calls + ?, billed_units = billed_units + ?, cost_usd = cost_usd + ?
             WHERE month = ? AND provider = ?
            """,
            (calls, billed_units, cost_usd, month, provider),
        )
        self.conn.commit()

    def month_spend(self, month: str | None = None) -> float:
        month = month or current_month()
        row = self.conn.execute(
            "SELECT COALESCE(SUM(cost_usd), 0) AS total FROM spend WHERE month = ?", (month,)
        ).fetchone()
        return float(row["total"])

    def spend_rows(self, month: str | None = None) -> list[dict[str, Any]]:
        month = month or current_month()
        rows = self.conn.execute("SELECT * FROM spend WHERE month = ?", (month,)).fetchall()
        return [dict(r) for r in rows]

    def recent_runs(self, limit: int = 20) -> list[dict[str, Any]]:
        rows = self.conn.execute(
            "SELECT * FROM runs ORDER BY id DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]
