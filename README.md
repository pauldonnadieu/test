# xcollect

Hourly collector for X/Twitter posts: new posts from a fixed account list, plus
popular posts matching keyword topics. Designed to run for about **$2-3 USD a
month** (roughly $3-4.50 AUD), with the first few weeks free on provider signup
credits.

## The approach, and why

It does not scrape x.com. It calls a third-party read API that has already
solved the scraping problem, which means there is no anti-bot arms race to lose,
no residential proxies to rent, no burner accounts to get suspended, and nothing
that breaks when X rotates its GraphQL identifiers. Free CI hosting works
because the runner only ever talks to an ordinary HTTPS API.

The cost, therefore, is the whole design problem. Three mechanisms keep it down,
in order of how much they save:

1. **`since_time` watermarks.** Every query carries the timestamp of the last
   successful run, so X filters old posts server-side *before* the provider
   bills us. This is the difference between paying for 20 tweets an hour per
   account and paying for the one that is actually new.
2. **Handle batching.** `(from:a OR from:b OR ...)` puts ~20 accounts in one
   call instead of twenty calls. One request per batch per hour.
3. **`min_faves` floors on topics.** Turns "popular posts about X" from an
   unbounded firehose into a handful per hour. Applied by X before billing, so
   it is a direct cost reduction rather than a client-side filter.

Plus adaptive backoff: a source that returns nothing twice running drops to half
cadence, and is promoted again the moment it produces.

**The load-bearing assumption:** mechanism 1 only saves money if the provider
passes `since_time` through to X's search rather than filtering client-side
after being billed. The early-stop logic protects us either way (we never
paginate past the watermark), but the per-hour cost differs by roughly 20x
depending on the answer. Verify it on free credits before topping up: run the
same query with a one-hour `since_time` and a one-week one, and compare what
`status` reports.

## Setup

```bash
pip install -r requirements.txt
cp config.yaml my-config.yaml     # edit handles and topics
export TWITTERAPI_IO_KEY=...      # sign up, no card, $1 free credit
```

See what it would ask for, without spending anything:

```bash
python -m xcollect run --dry-run
```

Then run it for real:

```bash
python -m xcollect run
python -m xcollect status
```

## Choosing a provider

Two adapters ship, and they bill on **different axes**, which matters more than
the headline rate:

| Provider | Bills per | Rate | Free credit |
|---|---|---|---|
| `twitterapi_io` | tweet returned | $0.00015 (~$0.15/1k) | $1 |
| `twitterapis_com` | call made | $0.0008/call (~20 tweets) | $0.50 |

Break-even is about **5.3 tweets per call**. Below that, per-tweet billing wins;
above it, per-call wins. An hourly poller with watermarks returns *small* pages
by design, often empty, so per-tweet billing is probably cheaper here despite
looking 4x more expensive on the sticker.

Probably. Measure it rather than trusting the arithmetic:

```bash
python -m xcollect compare --query "(from:nasa) since_time:$(( $(date +%s) - 3600 ))"
python -m xcollect status          # prints observed tweets-per-call and a monthly projection
```

Run the real config for 24 hours on free credits, then read `status`. The
projection line is the number to act on.

> The `twitterapis_com` response mapping is **provisional** — their docs were
> unreachable when it was written, so it tries the conventional field spellings
> and fails loudly with instructions if none match. Verify it with
> `python -m xcollect probe --provider twitterapis_com --raw` before relying on it.

## Keeping the bill down

`config.yaml` holds more of the cost than the code does. In order of impact:

- **`topics[].cadence_hours`** — 2 instead of 1 halves the expensive half of the
  workload. Popular posts need time to accumulate likes anyway, so this arguably
  improves results.
- **`topics[].min_faves`** — directly proportional savings.
- **`accounts.cadence_hours`** and `backoff_max_level`.

`budget.monthly_usd_ceiling` is enforced in code, not on a dashboard: spend is
recorded per call as it happens (so a crash cannot lose it), and a run that
would cross the ceiling stops and records itself as `capped`.

## Deployment

`.github/workflows/collect.yml` runs it hourly for free. Set these secrets:

- `TWITTERAPI_IO_KEY` (or `TWITTERAPIS_COM_KEY`)
- `LIBSQL_URL` and `LIBSQL_AUTH_TOKEN` — a [Turso](https://turso.tech) free-tier
  database. **Not optional in CI:** without durable state, every run is a cold
  start reaching back `cold_start_hours`, and the cost model collapses. Locally,
  omit them and it uses a SQLite file.

## Commands

| Command | Purpose |
|---|---|
| `run` | Collect everything due. `--dry-run` prints queries and spends nothing. `--force` ignores cadence. |
| `status` | Spend against ceiling, watermarks, recent runs, monthly projection. |
| `compare` | Phase-0 bake-off: one query across every provider, cost per tweet. |
| `probe` | Dump one raw response, to verify or fix an adapter's mapping. |
| `export` | Collected tweets as JSONL on stdout. |

## Tests

```bash
python -m pytest tests/ -q
```

No network. The load-bearing test is
`test_second_run_bills_almost_nothing` — if that ever fails, the project costs
roughly 20x what it is meant to.

## What this deliberately does not do

Scrape x.com directly, drive a browser, or use agentic/computer-use browsing.
All three cost far more than the API (agentic browsing is ~1000x), and none of
them solve detection: X fingerprints TLS (JA4), HTTP/2 framing, browser
fingerprint, IP reputation and account behaviour, none of which change because a
model is moving the cursor.

Self-hosted RSSHub is the genuine $0 option and is documented here as a
fallback, not a recommendation: its X routes now require `TWITTER_AUTH_TOKEN`
from a logged-in account, so "free" means burner accounts on rotation,
suspensions as routine, and breakage every few weeks.

## Legal note

Reading public posts is generally lawful (*hiQ Labs v. LinkedIn*), but every
route here breaches X's terms of service. Using a third-party API moves that
exposure onto the provider rather than your own accounts and IPs. Not legal
advice.
