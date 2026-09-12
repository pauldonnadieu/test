# What changed, and why

This set replaces `aios-v4/`, which replaced three earlier versions. Recorded so none of it has
to be re-derived in six months.

---

## The one structural difference

**The harness exists and has been tested.** Every previous version specified checks; this one
ships them and proves them. 127 assertions across five suites, each run against a correct case
and a deliberately broken one.

That is not a documentation improvement, it is a different kind of artefact, and writing it
immediately found three real defects that no amount of re-reading had:

1. **The container checks passed for the wrong reason.** With no Docker daemon, every negative
   check in stage 2 passed because `docker exec` itself failed. The result was indistinguishable
   from a system with no boundary at all. The stage now gates on reaching the container first.
2. **The regression gate missed the case it exists for.** It caught a passing check that vanished
   but not a *failing* one deleted to hide it, which is the actual cheat. Any vanished ID is now
   a regression.
3. **Two kill-switch checks were wrong**, one demanding an inline halt check from scripts that
   correctly delegate, the other leaking the real data path into its own fixture.

This is the argument for writing the executable half before the prose, and it is why
`00-PROVEN.md` can now distinguish four tiers of evidence instead of two.

---

## New capability

### The chief-of-staff half

v4 specified a strong retrospective coach and almost no anticipatory assistant. The forward
function had lived in the daily brief, the brief was parked for good reasons, and the function
went with it by accident. The user asked for coach, mentor, EA **and** chief of staff, and two
thirds of that was missing.

Restored as three skills and a section, with no daily brief and no personal data required:
`prepare` (assemble what is coming before it arrives, and hand over the finished thing, not a
question about it), `decide` (build the case, name the second-order effects and the opportunity
cost, and **recommend**), `horizon` (what is approaching, what has gone quiet, what is about to
be forgotten). The weekly review gained a short forward section.

The governing rule is **prepare rather than remind**, because a reminder hands the work back and
handing work back is what the system exists to stop.

### The free-tier utility lane

The user wanted free tiers from other providers doing low-stakes work so the Pro subscription
goes where judgement is needed. The stated boundary was "anything but financial", which cannot be
enforced: sensitivity is a property of sentences, not files, and a check-in mentioning the
mortgage is financial, personal, and sits in `daily/`.

So the boundary is structural. The lane reaches exactly `utility/` and `untrusted-external/` and
nothing else exists to it, the router runs **on the host** so the container never holds the
credential, and the write-guard enforces the confinement in both directions (`FT.1`-`FT.6`, all
six proven by sabotage). The documents say plainly that a to-do list is still a portrait of a
life over time, and the lane is opt-in per item rather than a default destination.

### Currency, properly

v4 gave "staying on the cutting edge" one skill and five bullets, despite it being a stated
purpose. `R4-currency.md` rebuilds it: three questions in priority order, a tiered watchlist with
an explicit do-not-ingest list and an annual verification of the list itself, source grading, and
**a separate seven-step procedure for evaluating a runtime capability**, which is a different act
from adopting a tool and the one most likely to produce real improvement. Three standing triggers
are written down so the scan recognises them rather than re-evaluating monthly.

### The long arc

`R5-lifecycle.md`: the maintenance rhythm on one page, the arc from week one to year one, and
upgrade procedures for Ubuntu LTS end of life, the container image, Claude Code itself and the
VPS. `DRIFT.1` detected a breaking CLI change in v4 and nothing told you what to do about it.

### A worked example

`R6-worked-example.md`: one complete week with real artefacts, a review with dated evidence, an
audit that names its own failure, a proposal through its whole life including the red-first test,
and a quiet week that correctly changes nothing. Fictional and labelled as such. No previous
version had one, and no amount of specification shows what "a bottleneck with evidence" reads
like.

### Structure

Layered. A spine of about 12,000 words that a build session holds, and seven reference documents
loaded when the moment needs them. v4 was one linear set that had grown to the point where a cold
session might not reach the later stages.

---

## Carried from v4, unchanged in substance

The six defect corrections that version made, all of which survive review: `conf/` inside the
backup (`BK.7`, `BK.8`), OAuth persistence across a container rebuild (`CTR.11`, `CTR.12`), the
timezone step (`HOST.10`), run records holding metadata rather than model output
(`LOG.1`-`LOG.4`), health and signals scored separately, and backup coverage actually checked.

The four hooks, now implemented and proven. The four-layer kill switch, now with the ordering
verified inside the library rather than assumed. Rotation and incident response. Security
monitoring distinct from health checks. The intake stage. Provenance and trust levels. The
coaching skills. The honest-limits discipline.

---

## Deliberately unchanged

No git. No connections. No local models. No framework, no database server, no inbound port.
Remote Control inside the container. Route by rule, never a model router. The three-way recovery
split. One adoption a month. A skipped check is a failure. A test must be seen to fail before the
change is applied.

All of it survives review. The narrowing that produced v3 got the hard parts right, and every
version since has been an argument with its omissions rather than with its design.

---

## Still not earned

**Nobody has read this version cold.** The two cold-reader runs that gave an earlier version its
credibility read a different set. `test/E2E-PROCEDURE.md`, twice, before the real build.

**Everything that needs a real machine is still a specification**: stage 1, the container flags,
OAuth persistence, the backup destination, cron, Remote Control, recovery, and the free-tier
provider call itself. `00-PROVEN.md` says which is which, and it is the first thing to read.
