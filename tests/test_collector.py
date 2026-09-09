"""The tests that actually protect the budget.

The cost model rests on one behaviour: a second run immediately after a first
must fetch and bill almost nothing. If that breaks, the project costs 20x what
it is meant to, so it is tested from several directions.
"""

from __future__ import annotations

import pytest

from fakes import BASE_ID, FakeProvider, make_tweet
from xcollect.collector import collect, effective_interval_s, plan, since_for
from xcollect.config import Config
from xcollect.store import Store

HOUR = 3600
NOW = 1_788_000_000


def build_config(**overrides):
    data = {
        "provider": "fake",
        "budget": {"monthly_usd_ceiling": 3.0, "max_pages_per_query": 3},
        "accounts": {"handles": ["nasa"], "cadence_hours": 1},
        "collection": {"cold_start_hours": 6, "overlap_seconds": 300},
    }
    data.update(overrides)
    return Config.from_dict(data)


@pytest.fixture
def store():
    with Store(":memory:") as s:
        yield s


def test_first_run_collects_and_sets_watermark(store):
    provider = FakeProvider([[make_tweet(1), make_tweet(2), make_tweet(3)]])
    report = collect(build_config(), store, provider, now=NOW)

    assert report.new_tweets == 3
    assert report.status == "ok"
    assert store.get_source("accounts:0", "accounts").high_water_id == str(BASE_ID + 3)


def test_second_run_bills_almost_nothing(store):
    """The single most important behaviour in the project."""
    config = build_config()
    tweets = [make_tweet(1), make_tweet(2), make_tweet(3)]

    first = collect(config, store, FakeProvider([tweets]), now=NOW)
    # An hour later the provider still returns the same posts (since_time is
    # advisory; the provider decides). Nothing new must be stored or paginated.
    second = collect(config, store, FakeProvider([tweets]), now=NOW + HOUR)

    assert first.new_tweets == 3
    assert second.new_tweets == 0
    assert second.calls == 1, "must not paginate past the watermark"
    assert store.tweet_count() == 3


def test_pagination_stops_at_the_watermark_instead_of_paying_for_known_pages(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)

    # Three pages available, but page one already reaches back past the
    # watermark, so pages two and three must never be requested.
    provider = FakeProvider([
        [make_tweet(3), make_tweet(1)],
        [make_tweet(0)],
        [make_tweet(-1)],
    ])
    report = collect(config, store, provider, now=NOW + HOUR)

    assert len(provider.calls) == 1
    assert report.new_tweets == 1


def test_pagination_continues_while_everything_is_new(store):
    provider = FakeProvider([[make_tweet(5), make_tweet(4)], [make_tweet(3), make_tweet(2)]])
    report = collect(build_config(), store, provider, now=NOW)

    assert len(provider.calls) == 2
    assert report.new_tweets == 4


def test_max_pages_caps_a_runaway_query(store):
    config = build_config(budget={"monthly_usd_ceiling": 3.0, "max_pages_per_query": 2})
    provider = FakeProvider([[make_tweet(i)] for i in range(9, 0, -1)])
    collect(config, store, provider, now=NOW)

    assert len(provider.calls) == 2


def test_duplicates_across_sources_are_stored_once(store):
    config = build_config(topics=[{"name": "t", "keywords": ["nasa"], "min_faves": 0}])
    shared = make_tweet(7)
    provider = FakeProvider([[shared]])
    report = collect(config, store, provider, now=NOW)

    assert store.tweet_count() == 1
    assert report.new_tweets == 1, "the second source must not double-count a known id"


def test_interrupted_run_still_records_what_it_spent(store):
    """A crash must not lose the spend record, or the ceiling stops meaning anything."""
    class Exploding(FakeProvider):
        def search(self, query, cursor=None):
            page = super().search(query, cursor)
            if len(self.calls) >= 2:
                raise RuntimeError("boom")
            return page

    config = build_config(topics=[{"name": "t", "keywords": ["x"], "min_faves": 0}])
    provider = Exploding([[make_tweet(1)]])
    with pytest.raises(RuntimeError):
        collect(config, store, provider, now=NOW)

    assert store.month_spend() > 0


# -- budget -------------------------------------------------------------------

def test_run_is_capped_once_the_ceiling_is_reached(store):
    config = build_config(budget={"monthly_usd_ceiling": 0.0001, "max_pages_per_query": 3})
    store.record_spend("fake", calls=1, billed_units=10, cost_usd=0.001)

    provider = FakeProvider([[make_tweet(1)]])
    report = collect(config, store, provider, now=NOW)

    assert report.status == "capped"
    assert provider.calls == [], "must not spend after the ceiling is reached"


def test_ceiling_stops_a_run_partway_through(store):
    config = build_config(
        budget={"monthly_usd_ceiling": 0.0004, "max_pages_per_query": 5},
        topics=[{"name": "a", "keywords": ["x"], "min_faves": 0},
                {"name": "b", "keywords": ["y"], "min_faves": 0}],
    )
    provider = FakeProvider([[make_tweet(i) for i in range(3)]])
    report = collect(config, store, provider, now=NOW)

    assert report.status == "capped"
    assert len(provider.calls) < 3


# -- cadence and backoff ------------------------------------------------------

def test_source_is_skipped_until_its_cadence_elapses(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)

    assert plan(config, store, now=NOW + 600) == []
    assert len(plan(config, store, now=NOW + HOUR)) == 1


def test_empty_runs_back_off_but_only_after_two(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)

    collect(config, store, FakeProvider([[]]), now=NOW + HOUR)
    assert store.get_source("accounts:0", "accounts").backoff_level == 0, "one quiet hour is not a trend"

    collect(config, store, FakeProvider([[]]), now=NOW + 2 * HOUR)
    assert store.get_source("accounts:0", "accounts").backoff_level == 1

    # Backed off to 2-hourly, so one hour later it is not due.
    assert plan(config, store, now=NOW + 3 * HOUR) == []
    assert len(plan(config, store, now=NOW + 4 * HOUR)) == 1


def test_backoff_resets_the_moment_a_source_produces(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)
    collect(config, store, FakeProvider([[]]), now=NOW + HOUR)
    collect(config, store, FakeProvider([[]]), now=NOW + 2 * HOUR)
    collect(config, store, FakeProvider([[make_tweet(9)]]), now=NOW + 4 * HOUR)

    state = store.get_source("accounts:0", "accounts")
    assert state.backoff_level == 0
    assert state.consecutive_empty == 0


def test_backoff_is_capped(store):
    assert effective_interval_s(1, backoff_level=9, max_level=2) == 4 * HOUR


# -- watermark windows --------------------------------------------------------

def test_cold_start_reaches_back_the_configured_window(store):
    config = build_config()
    state = store.get_source("accounts:0", "accounts")
    assert since_for(state, config, NOW) == NOW - 6 * HOUR


def test_window_overlaps_the_previous_run_to_cover_the_seam(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)
    state = store.get_source("accounts:0", "accounts")
    assert since_for(state, config, NOW + HOUR) == NOW - 300


def test_long_outage_does_not_produce_an_unbounded_catch_up_query(store):
    config = build_config()
    collect(config, store, FakeProvider([[make_tweet(1)]]), now=NOW)
    state = store.get_source("accounts:0", "accounts")
    later = NOW + 30 * 24 * HOUR
    assert since_for(state, config, later) == later - 48 * HOUR


# -- dry run ------------------------------------------------------------------

def test_dry_run_neither_calls_nor_writes(store):
    provider = FakeProvider([[make_tweet(1)]])
    collect(build_config(), store, provider, dry_run=True, now=NOW)

    assert provider.calls == []
    assert store.tweet_count() == 0
    assert store.all_sources() == []
    assert store.month_spend() == 0


def test_a_crashed_run_is_recorded_as_error_not_left_running(store):
    class Exploding(FakeProvider):
        def search(self, query, cursor=None):
            raise RuntimeError("boom")

    with pytest.raises(RuntimeError):
        collect(build_config(), store, Exploding([[]]), now=NOW)

    run = store.recent_runs(1)[0]
    assert run["status"] == "error"
    assert "boom" in run["note"]


def test_spend_never_crosses_the_ceiling(store):
    """Headroom means we stop before an unaffordable call, not after it."""
    ceiling = 0.002
    config = build_config(
        budget={"monthly_usd_ceiling": ceiling, "max_pages_per_query": 10},
        topics=[{"name": f"t{i}", "keywords": ["x"], "min_faves": 0} for i in range(6)],
    )
    provider = FakeProvider([[make_tweet(i) for i in range(20)]])
    collect(config, store, provider, now=NOW)

    assert store.month_spend() <= ceiling
