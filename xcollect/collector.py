"""The hourly collection run.

Everything here exists to avoid paying for tweets we already have. Three
mechanisms do that work, in order of how much they save:

1. `since_time` watermarks, so X filters old posts server-side before we're billed.
2. Handle batching, so ~20 accounts cost one call instead of twenty.
3. Adaptive backoff, so accounts that never post are not polled hourly forever.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field

from .budget import BudgetExceeded, BudgetGuard
from .config import Config, accounts_query, batch_handles, topic_query
from .models import Tweet
from .providers.base import Provider, ProviderError
from .store import SourceState, Store, now_epoch

log = logging.getLogger("xcollect")

HOUR = 3600


@dataclass
class PlannedSource:
    key: str
    kind: str
    query: str
    since_epoch: int
    cadence_hours: int
    backoff_max_level: int


@dataclass
class SourceResult:
    key: str
    new_tweets: int = 0
    fetched: int = 0
    calls: int = 0
    cost_usd: float = 0.0
    skipped: str = ""
    error: str = ""


@dataclass
class RunReport:
    provider: str
    results: list[SourceResult] = field(default_factory=list)
    new_tweets: int = 0
    fetched: int = 0
    calls: int = 0
    billed_units: float = 0.0
    cost_usd: float = 0.0
    status: str = "ok"
    note: str = ""

    @property
    def tweets_per_call(self) -> float:
        return self.fetched / self.calls if self.calls else 0.0


def effective_interval_s(cadence_hours: int, backoff_level: int, max_level: int) -> int:
    return cadence_hours * HOUR * (2 ** min(backoff_level, max_level))


def since_for(state: SourceState, cfg: Config, now: int) -> int:
    """Where to start this source's window.

    The overlap re-asks for a few minutes we have already seen, so a post that
    landed mid-request is not lost in the seam between runs; duplicates are free
    because INSERT OR IGNORE drops them. The lookback cap stops a week of
    downtime from producing one enormous catch-up query.
    """
    collection = cfg.collection
    if state.last_run_at is None:
        return now - collection.cold_start_hours * HOUR
    since = state.last_run_at - collection.overlap_seconds
    floor = now - collection.max_lookback_hours * HOUR
    return max(since, floor)


def plan(config: Config, store: Store, *, now: int | None = None, force: bool = False) -> list[PlannedSource]:
    """Decide which sources are due and build their queries."""
    now = now or now_epoch()
    planned: list[PlannedSource] = []

    batches = batch_handles(
        config.accounts.handles,
        config.collection.handles_per_batch,
        config.collection.max_query_chars,
    )
    for index, handles in enumerate(batches):
        key = f"accounts:{index}"
        state = store.get_source(key, "accounts")
        if not force and not _is_due(state, config.accounts.cadence_hours,
                                    config.accounts.backoff_max_level, now):
            continue
        since = since_for(state, config, now)
        planned.append(
            PlannedSource(
                key=key,
                kind="accounts",
                query=accounts_query(handles, since, config.accounts),
                since_epoch=since,
                cadence_hours=config.accounts.cadence_hours,
                backoff_max_level=config.accounts.backoff_max_level,
            )
        )

    for topic in config.topics:
        key = f"topic:{topic.name}"
        state = store.get_source(key, "topic")
        if not force and not _is_due(state, topic.cadence_hours, topic.backoff_max_level, now):
            continue
        since = since_for(state, config, now)
        planned.append(
            PlannedSource(
                key=key,
                kind="topic",
                query=topic_query(topic, since),
                since_epoch=since,
                cadence_hours=topic.cadence_hours,
                backoff_max_level=topic.backoff_max_level,
            )
        )

    return planned


def _is_due(state: SourceState, cadence_hours: int, max_level: int, now: int) -> bool:
    if state.last_run_at is None:
        return True
    interval = effective_interval_s(cadence_hours, state.backoff_level, max_level)
    # A small tolerance stops GitHub Actions' cron drift (it can fire minutes
    # late under load) from pushing every second run past its window.
    return now >= state.last_run_at + interval - 120


def collect(
    config: Config,
    store: Store,
    provider: Provider,
    *,
    dry_run: bool = False,
    force: bool = False,
    now: int | None = None,
) -> RunReport:
    now = now or now_epoch()
    report = RunReport(provider=provider.name)
    guard = BudgetGuard(store, provider.name, config.budget.monthly_usd_ceiling, dry_run=dry_run)

    sources = plan(config, store, now=now, force=force)
    if not sources:
        report.status = "idle"
        report.note = "no sources due"
        return report

    run_id = None if dry_run else store.start_run(provider.name)

    try:
        guard.check()
    except BudgetExceeded as exc:
        report.status = "capped"
        report.note = str(exc)
        if run_id is not None:
            store.finish_run(run_id, status="capped", new_tweets=0, calls=0,
                             billed_units=0, cost_usd=0, note=str(exc))
        return report

    try:
        return _run_sources(sources, config, store, provider, guard, report, run_id, dry_run, now)
    except Exception as exc:  # noqa: BLE001 - the run row must never be left "running"
        if run_id is not None:
            store.finish_run(
                run_id, status="error", new_tweets=report.new_tweets, calls=guard.calls,
                billed_units=guard.billed_units, cost_usd=guard.cost_usd,
                note=f"{type(exc).__name__}: {exc}"[:500],
            )
        raise


def _run_sources(sources, config, store, provider, guard, report, run_id, dry_run, now):
    for source in sources:
        if dry_run:
            log.info("[dry-run] %s -> %s", source.key, source.query)
            report.results.append(SourceResult(key=source.key, skipped="dry-run"))
            continue
        try:
            result = _collect_source(source, config, store, provider, guard, now)
        except BudgetExceeded as exc:
            report.status = "capped"
            report.note = str(exc)
            report.results.append(SourceResult(key=source.key, skipped="budget"))
            break
        except ProviderError as exc:
            # One bad source must not abandon the rest of the run.
            log.error("%s failed: %s", source.key, exc)
            report.results.append(SourceResult(key=source.key, error=str(exc)))
            report.status = "partial"
            continue
        report.results.append(result)

    report.new_tweets = sum(r.new_tweets for r in report.results)
    report.fetched = sum(r.fetched for r in report.results)
    report.calls = guard.calls
    report.billed_units = guard.billed_units
    report.cost_usd = guard.cost_usd

    if run_id is not None:
        store.finish_run(
            run_id,
            status=report.status,
            new_tweets=report.new_tweets,
            calls=report.calls,
            billed_units=report.billed_units,
            cost_usd=report.cost_usd,
            note=report.note,
        )
    return report


def _collect_source(
    source: PlannedSource,
    config: Config,
    store: Store,
    provider: Provider,
    guard: BudgetGuard,
    now: int,
) -> SourceResult:
    state = store.get_source(source.key, source.kind)
    result = SourceResult(key=source.key)
    cursor: str | None = None
    collected: list[Tweet] = []
    high_water = state.high_water_int
    stop_early = False

    for page_number in range(config.budget.max_pages_per_query):
        # Refuse a call we already know we cannot afford, rather than being
        # billed for it and discovering the ceiling afterwards.
        guard.check(headroom_usd=provider.max_call_cost_usd)
        page = provider.search(source.query, cursor)
        guard.charge(page)
        result.calls += 1
        result.cost_usd += page.cost_usd
        result.fetched += len(page.tweets)

        fresh = [t for t in page.tweets if t.id_int > high_water] if high_water else page.tweets
        collected.extend(fresh)

        # Results come back newest-first, so a page containing anything at or
        # below the watermark means we have caught up. Paginating further would
        # be paying to re-read what is already in the database.
        if high_water and len(fresh) < len(page.tweets):
            stop_early = True
            break
        if not page.has_next:
            break
        cursor = page.next_cursor
        log.debug("%s page %d -> %d tweets", source.key, page_number + 1, len(page.tweets))

    result.new_tweets = store.insert_tweets(collected, source.key)

    if collected:
        state.high_water_id = str(max(t.id_int for t in collected))
        state.consecutive_empty = 0
        state.backoff_level = 0
    else:
        state.consecutive_empty += 1
        # Back off only after a couple of genuinely empty runs, so one quiet
        # hour does not halve an active account's polling rate.
        if state.consecutive_empty >= 2:
            state.backoff_level = min(state.backoff_level + 1, source.backoff_max_level)

    state.last_run_at = now
    state.last_new_count = result.new_tweets
    store.save_source(state)

    log.info(
        "%s: %d new (%d fetched, %d calls, $%.5f)%s",
        source.key, result.new_tweets, result.fetched, result.calls,
        result.cost_usd, " [caught up]" if stop_early else "",
    )
    return result
