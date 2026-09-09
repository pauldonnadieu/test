"""Command line entry point."""

from __future__ import annotations

import argparse
import json
import logging
import sys
from datetime import datetime, timezone

from . import providers
from .budget import BudgetGuard
from .collector import collect, plan
from .config import Config, ConfigError
from .providers.base import ProviderError
from .store import Store, current_month


def _setup_logging(verbose: bool) -> None:
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(message)s",
        datefmt="%H:%M:%S",
    )


def _fmt_ts(epoch: int | None) -> str:
    if not epoch:
        return "never"
    return datetime.fromtimestamp(epoch, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")


def cmd_run(args: argparse.Namespace) -> int:
    config = Config.load(args.config)
    provider_name = args.provider or config.provider
    with Store(args.db) as store:
        if args.dry_run:
            sources = plan(config, store, force=args.force)
            if not sources:
                print("Nothing due. Use --force to plan every source anyway.")
                return 0
            print(f"Provider: {provider_name}   (dry run, nothing will be requested)")
            print(f"Budget:   ${config.budget.monthly_usd_ceiling:.2f}/month, "
                  f"${store.month_spend():.4f} spent in {current_month()}")
            print(f"Would make up to {len(sources) * config.budget.max_pages_per_query} "
                  f"call(s) across {len(sources)} source(s):\n")
            for source in sources:
                print(f"  {source.key}  (since {_fmt_ts(source.since_epoch)})")
                print(f"    {source.query}\n")
            return 0

        try:
            provider = providers.build(provider_name)
        except ProviderError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 2

        report = collect(config, store, provider, force=args.force)

    print(
        f"[{report.status}] {report.new_tweets} new tweets, {report.fetched} fetched, "
        f"{report.calls} calls, {report.billed_units:g} {provider.billing_unit}(s) billed, "
        f"${report.cost_usd:.5f}"
    )
    if report.calls:
        print(f"tweets per call: {report.tweets_per_call:.2f} "
              f"(break-even vs per-tweet pricing is ~5.3)")
    if report.note:
        print(f"note: {report.note}")
    for result in report.results:
        if result.error:
            print(f"  ! {result.key}: {result.error}", file=sys.stderr)
    return 1 if report.status == "partial" else 0


def cmd_status(args: argparse.Namespace) -> int:
    config = Config.load(args.config) if args.config else None
    with Store(args.db) as store:
        month = current_month()
        spent = store.month_spend()
        print(f"Database:  {args.db}")
        print(f"Tweets:    {store.tweet_count()}")
        ceiling = config.budget.monthly_usd_ceiling if config else None
        if ceiling:
            pct = 100 * spent / ceiling if ceiling else 0
            print(f"Spend:     ${spent:.4f} of ${ceiling:.2f} in {month} ({pct:.0f}%)")
        else:
            print(f"Spend:     ${spent:.4f} in {month}")
        for row in store.spend_rows():
            per_unit = row["cost_usd"] / row["billed_units"] if row["billed_units"] else 0
            print(f"           {row['provider']}: {row['calls']} calls, "
                  f"{row['billed_units']:g} units, ${row['cost_usd']:.4f} "
                  f"(${per_unit:.6f}/unit)")

        sources = store.all_sources()
        if sources:
            print("\nSources:")
            for state in sources:
                backoff = f" backoff x{2 ** state.backoff_level}" if state.backoff_level else ""
                print(f"  {state.key:<28} last {_fmt_ts(state.last_run_at)} "
                      f"new={state.last_new_count}{backoff}")

        runs = store.recent_runs(args.runs)
        if runs:
            print("\nRecent runs:")
            for run in runs:
                print(f"  {_fmt_ts(run['started_at'])}  {run['status']:<8} "
                      f"new={run['new_tweets']:<4} calls={run['calls']:<4} "
                      f"${run['cost_usd']:.5f}  {run['note'] or ''}")

        # Projection is the number that actually matters for the budget.
        if runs:
            billed = [r for r in runs if r["calls"]]
            if billed:
                avg = sum(r["cost_usd"] for r in billed) / len(billed)
                print(f"\nAt ${avg:.5f}/run and hourly cadence: "
                      f"~${avg * 24 * 30:.2f}/month projected.")
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    """Dump one raw response. Use this to verify or fix an adapter's mapping."""
    try:
        provider = providers.build(args.provider)
        page = provider.search(args.query)
    except ProviderError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    print(f"provider:     {provider.name}")
    print(f"tweets:       {len(page.tweets)}")
    print(f"billed:       {page.billed_units:g} {page.unit}(s) = ${page.cost_usd:.6f}")
    print(f"next_cursor:  {page.next_cursor!r}")
    if page.tweets:
        print("\nfirst tweet, normalised:")
        first = page.tweets[0]
        print(json.dumps({
            "id": first.id, "created_at": first.created_at.isoformat(),
            "author": first.author_handle, "likes": first.like_count,
            "url": first.url, "text": first.text[:160],
        }, indent=2))
        if args.raw:
            print("\nraw payload of first tweet:")
            print(json.dumps(first.raw, indent=2)[:4000])
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    """Phase 0: run one identical query through every provider and compare.

    This is what settles per-tweet vs per-call billing with data rather than
    arithmetic, including whether a provider charges for an empty result.
    """
    rows = []
    for name in args.providers:
        try:
            provider = providers.build(name)
            page = provider.search(args.query)
        except ProviderError as exc:
            print(f"  {name}: error - {exc}", file=sys.stderr)
            continue
        count = len(page.tweets)
        rows.append({
            "provider": name,
            "unit": page.unit,
            "tweets": count,
            "billed": page.billed_units,
            "cost": page.cost_usd,
            "per_tweet": page.cost_usd / count if count else float("inf"),
        })

    if not rows:
        return 2
    print(f"query: {args.query}\n")
    print(f"{'provider':<18}{'unit':<8}{'tweets':>7}{'billed':>9}{'cost $':>11}{'$/tweet':>12}")
    for row in sorted(rows, key=lambda r: r["per_tweet"]):
        per = "-" if row["per_tweet"] == float("inf") else f"{row['per_tweet']:.6f}"
        print(f"{row['provider']:<18}{row['unit']:<8}{row['tweets']:>7}"
              f"{row['billed']:>9g}{row['cost']:>11.6f}{per:>12}")
    print("\nRepeat this against a realistic since_time window before choosing. "
          "A provider that looks cheap on a full page can be the expensive one "
          "on the near-empty pages an hourly poller actually makes.")
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    with Store(args.db) as store:
        query = "SELECT * FROM tweets"
        params: tuple = ()
        if args.since:
            since = int(datetime.fromisoformat(args.since).replace(tzinfo=timezone.utc).timestamp())
            query += " WHERE created_at >= ?"
            params = (since,)
        query += " ORDER BY created_at DESC"
        if args.limit:
            query += f" LIMIT {int(args.limit)}"
        for row in store.conn.execute(query, params):
            record = dict(row)
            record.pop("raw", None)
            record["created_at"] = datetime.fromtimestamp(
                record["created_at"], tz=timezone.utc
            ).isoformat()
            record["url"] = f"https://x.com/{record['author_handle']}/status/{record['id']}"
            print(json.dumps(record, separators=(",", ":")))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="xcollect", description=__doc__)
    parser.add_argument("--db", default="xcollect.db", help="SQLite path (default: xcollect.db)")
    parser.add_argument("-v", "--verbose", action="store_true")
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="collect everything currently due")
    run.add_argument("--config", default="config.yaml")
    run.add_argument("--provider", help="override the provider named in config")
    run.add_argument("--dry-run", action="store_true",
                     help="print the queries and stop, without spending anything")
    run.add_argument("--force", action="store_true", help="ignore cadence and poll every source")
    run.set_defaults(func=cmd_run)

    status = sub.add_parser("status", help="spend, watermarks and recent runs")
    status.add_argument("--config", default="config.yaml")
    status.add_argument("--runs", type=int, default=10)
    status.set_defaults(func=cmd_status)

    probe = sub.add_parser("probe", help="dump one raw response to verify an adapter")
    probe.add_argument("--provider", required=True, choices=sorted(providers.REGISTRY))
    probe.add_argument("--query", default="from:nasa")
    probe.add_argument("--raw", action="store_true", help="include the raw tweet payload")
    probe.set_defaults(func=cmd_probe)

    compare = sub.add_parser("compare", help="phase-0 bake-off between providers")
    compare.add_argument("--providers", nargs="+", default=sorted(providers.REGISTRY))
    compare.add_argument("--query", default="from:nasa")
    compare.set_defaults(func=cmd_compare)

    export = sub.add_parser("export", help="write collected tweets as JSONL to stdout")
    export.add_argument("--since", help="ISO date, e.g. 2026-09-01")
    export.add_argument("--limit", type=int)
    export.set_defaults(func=cmd_export)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _setup_logging(args.verbose)
    try:
        return args.func(args)
    except ConfigError as exc:
        print(f"config error: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
