# 03 - Operations

How it runs once built. Read `04-improvement.md` for how it changes, and
`06-recovery-and-incidents.md` for when something is wrong.

---

## 1. The daily check-in

Thirty seconds. Evening, every day. This is the foundation, not a feature: everything the
weekly review knows, it knows from here.

**Shape.** Three or four questions, fixed, answerable while standing up:

- What actually happened today against what you meant to do?
- What got in the way, genuinely, not the tidy version?
- Energy, one to five.
- Anything you want kept.

**Recorded** as one JSONL line in `daily/check-ins.jsonl`: the date, the raw answers, an
energy integer, and an `intended_vs_actual` field. **Never edited.** A later correction is a
new line, not a rewrite. The value of this file is that it was written on the day.

**When it is missed.** One missed day is nothing. The system does not nag, does not send a
guilt-shaped message, and does not ask the user to catch up on four days at once: asking
someone to reconstruct Tuesday on Friday produces fiction, and fiction in the ground-truth file
is worse than a gap. It records the gap. Below ten of the last fourteen days the weekly review
names its own thin evidence, and at twenty-one days the system goes dormant rather than
producing confident reviews about nothing. See `01-architecture.md` section 11.

**Delivery.** The user's phone, through the Claude app connected to Remote Control on the VPS.
There is no push in v1: the user opens the app. If that turns out to be the thing that kills
the habit, that is the single strongest trigger for the phone app in `05-after-v1.md`, and it
is the kind of finding two weeks of ordinary use produces and no amount of design does.

**What the check-in deliberately does not capture yet.** Sleep hours, time blocks and a morning
brief were all in earlier versions of this design and are parked in `05-after-v1.md` with
trigger conditions, not dropped. They are the things that would let the review say "all
evenings, all office days" rather than reasoning from prose alone. They are also more personal
data, captured more often, and the user has chosen to add them once the habit itself has held.
That order is defensible: a system that captures more than the user sustains is a system that
gets abandoned with more of their life in it.

The procedure lives in `skills/check-in/`.

---

## 2. Filing, and the rule about asking

**The user never files anything.** Filing happens as a side effect of conversation, at
act-then-report autonomy, with no permission prompt.

When the system is unsure where something goes, it **files it in the most likely place and
says so in one line.** It does not ask. Asking is the exact mental load the system exists to
remove, and a system that asks twice a week where things go has become another thing to
maintain.

"I put that under `reference/business/pricing.md`" is correct. "Where would you like me to put
this?" is a design failure.

Misfiling is cheap: the file is findable by grep, the change ledger records the move, and the
weekly audit surfaces anything filed somewhere odd. Asking is expensive, because it spends the
thing the user has least of.

**Report tidily, do not narrate.** "Filed that under the pricing project and linked it to the
side-hustle goal" is useful. A running commentary on every write is noise.

**What happens automatically, from ordinary conversation:**

| The user says | The system does |
|---|---|
| Something they are worried about | Files it with provenance, raises it at the weekly review if it recurs |
| A goal is done, or dead | Moves it to achieved or abandoned, with the date and the reason |
| A fact about themselves or their situation | Updates `goals/` or `reference/`, marked `confirmed` |
| Something that contradicts a stored fact | Flags the contradiction, does not silently overwrite |
| A decision, in passing | Appends it to the decisions record with the reasoning |
| A thought, on the phone | Files to `reference/` under the most likely area |

**Keep the map current.** `START-HERE.md` is regenerated whenever the structure changes, and
every directory carries a one-line `README.md` saying what is in it and what puts things there.

**Archive, never delete**, except on an explicit request to forget, which follows section 7.

The procedure lives in `skills/file-this/`.

---

## 3. Model routing

Route by rule, in code. `--model` on the cron invocation is the routing mechanism. **There is
no router**, because a process that calls APIs to choose a model bills per token outside the
subscription.

| Work | Model | Why |
|---|---|---|
| Parsing a check-in into fields; extracting structure from prose | `haiku` | Needs language, not judgement |
| Check-in conversation; filing; weekly review first pass | `sonnet` | Pro's default, and the workhorse |
| Escalation only | `opus` | Expensive on a shared limit. Never the default |

These are aliases, resolved by the CLI, and what they resolve to changes over time. The run
record stores the model actually served so a silent change is visible.

### Escalate on evidence, never on self-assessment

A model that is not capable enough for a task is not reliable at noticing it. The failure mode
is a confident wrong answer, not a request for help. So escalation is never triggered by the
model saying it is unsure.

Escalate when, and only when:

1. A check failed.
2. Output failed schema validation.
3. The model hedged (see the limit below).
4. A retry already failed.
5. The input exceeds the model's context window.

**Honest limit on trigger 3.** "The model hedged" is detected by pattern-matching the output
for hedge markers. That is crude. It catches "I'm not certain", "it's difficult to say", "this
may not be accurate"; it misses confident nonsense entirely, which is the case that matters
most. Triggers 1, 2 and 5 are mechanical and reliable. Trigger 3 is a heuristic and is
labelled one.

**Some routines use no model at all.** The change ledger is `sha256sum`, `sort` and `diff`; the
backup is `restic`; the security observations are `ss`, `getent` and `diff`; the health check is
the harness. Putting a model in a deterministic job buys nothing and adds cost, latency and a
failure mode. If a routine's output is fully determined by its input, it gets no `--model`
because it makes no model call.

### Budget and degradation

- **At most two escalations per run.** Exhausting the budget is a recorded failure in the run
  record, not a silent continuation.
- **A model-specific limit is not a failed run.** "You've hit your Opus limit" means switching
  model keeps the work moving, so the script falls back to `sonnet`, sets `"degraded": true` in
  the run record, and the weekly review names it. A degraded review is labelled degraded.
- **A session or weekly limit is a failed run.** Nothing to fall back to. It exits non-zero,
  the freshness check catches it, and the user finds out.

---

## 4. Autonomy

Three levels. Everything the system does sits in exactly one.

| Level | What | Examples |
|---|---|---|
| **Act, then report** | Reversible, inside the data mount | Filing, naming, moving, formatting, writing the review, appending records |
| **Propose, then wait** | Changes how the system works | Edits to `CLAUDE.md` or skills, new or changed routines, adopting anything from the research scan, promoting an `inferred` claim to `confirmed` |
| **Never** | Changes what the system is allowed to do | `settings.json`, deny rules, hooks, cron, backup config, secrets, container flags |

The third level is enforced by ownership and read-only mounts, not by instruction
(`CTR.2`-`CTR.6`). Proposals are written to `ops/proposals/` and applied by the user from the
host. **It may improve its methods. It may never improve its own authority.**

**Permanently capped at propose-only**, regardless of track record: anything touching money,
employer systems, other people's data, or anything that sends a message on the user's behalf.
v1 has no connection that could do any of these. The rule is here because the file outlives v1.

---

## 5. The weekly review

Sunday evening. Input: the week's check-ins, the goals, the previous review, the open
proposals, and the week's check score.

It must produce, in this order:

1. **One bottleneck.** Not a list. The single thing that, removed, would have made the biggest
   difference to the week that actually happened.
2. **The evidence.** Specific lines from the check-ins, quoted with dates. A bottleneck named
   without evidence is a hunch wearing a suit.
3. **Constraint or self-sabotage, argued from the record.** The distinction is: a constraint
   shows up as the same obstacle across different weeks with different intentions;
   self-sabotage shows up as capacity that existed and went somewhere else. The evidence for
   either is in the check-ins or the call is not made. "I'm not sure which this is" is an
   acceptable and useful output.
4. **The smallest intervention the user would actually do.** Judged against their stated
   capacity in `goals/`, not against an idealised week. An intervention the user will not do is
   not a smaller version of a good plan; it is a way of generating another abandoned system.
5. **What it got wrong last week.** The previous review's intervention, and whether it
   happened. Unflinching. A review that never revisits its own advice is just weekly optimism.

Written to `review/YYYY-WW.md`. If the week's evidence is thin, it says so at the top and makes
weaker claims. That sentence is worth more than a confident review built on four data points.

**A review may conclude that nothing needs to change.** One that always finds something is
generating noise to justify itself.

The procedure, the diagnostic ladder behind output 3, and the self-sabotage protocol live in
`skills/weekly-review/`, `skills/bottleneck/` and `skills/patterns/`. Those three files are
where the actual value of this system lives; everything else in this document set exists to
keep them running and honest.

---

## 6. Backups, and what a restore drill is for

Nightly backup of `data/` and `conf/`, weekly `forget` and `prune`, weekly verification.

Retention as a starting point: 7 daily, 4 weekly, 12 monthly. Tune it once you know how much
the data actually grows.

**Google Drive throttles.** A large `forget`+`prune` can fail part-way on consumer storage.
Keep prune weekly rather than daily, keep rclone concurrency low, and treat a failed prune as
something to look at rather than a reason to stop backing up.

**Verification is not `restic check` alone.** Metadata checking passes on a repository whose
data blobs are corrupt. Weekly: `restic check --read-data-subset=5%`. Monthly: the actual
drill, restore the canary file and compare sha256 (`BK.4`).

**Once a quarter, the user does a restore themselves**, with someone watching, from the
rebuild package and the offline key. Not Claude Code, and not the checks. The purpose is to
find out whether the human can recover the system, which is the scenario that matters and the
one no automated check can test. Read the offline key at the same time: a key you have not
looked at in a year is a key you are assuming.

---

## 7. Deletion, honestly

When the user asks for something to be forgotten, there are four places it lives, and they
behave differently.

| Where | What can be done | Truthfully |
|---|---|---|
| **Live data** | Removed on request | Genuinely gone from the live system |
| **Derived mentions** | Found by a search pass and **listed** | Summaries, reviews and notes may repeat it. These are found, listed, and removed on confirmation. **Listed, not assumed absent** |
| **Backup snapshots** | Nothing, until they age out | Snapshots keep what the live system forgets. Saying otherwise would be a lie |
| **Anthropic-side transcripts** | Nothing from here | Anything said in a Remote Control session was stored server-side. With the training setting off, consumer retention is 30 days; with it on, 5 years |

**The rule that follows: if something must never reach a backup, it must never be written at
all.** There is no retrospective fix. When the user is about to say something that must not
persist, the honest answer is "don't put that in here", and the system should say so rather
than promise a deletion it cannot perform.

A deletion request produces a written record in `ops/` of what was removed, what was found and
listed, and what will persist until when. Including the fourth row. Especially the fourth row.

---

## 8. When something breaks

**A check is failing.** Read the detail on the FAIL line; it names the path or the value. Fix
the property, not the check. Editing a check to make it pass is the one move that converts this
harness from an asset into a liability, and the `expected-ids.txt` manifest exists to make a
quietly deleted check visible.

**A routine stopped.** `tail ops/runs/<routine>.jsonl` for the last exit status and
`error_class`, then `ops/logs/<routine>-<date>.log` for the detail if it is inside the 30-day
window. Usual suspects, in order: the halt flag still set from last week, a stale lock file
(`RUN.6`), a usage limit, the container not running, a full disk.

**The container is unhealthy.** Destroy and recreate it. That is what disposable means, and
stage 2 required you to prove it. The data is on the host mount and the credential is on the
home mount, so it comes back without a login.

**The host is gone.** New VPS, rebuild package, restore from snapshots, secrets from the
password manager. `RESTORE.md` in the rebuild package is the procedure, and the quarterly drill
is what makes it more than a document.

**Locked out.** Tailscale from another enrolled device. If Tailscale itself is the problem, the
Hetzner console is the break-glass path, which is why you rehearsed it in stage 1 and why the
console password belongs in the password manager.

**Something looks wrong rather than broken.** `06-recovery-and-incidents.md`. Stop first, then
diagnose; the order matters and it is the one people get backwards.

---

## 9. The weekly health check

`./run-all.sh --json >> ops/check-scores.jsonl`, every week, forever.

These checks are not build scaffolding. Every property they test can silently stop being true
months later: a package update rebinding sshd to a wildcard, a container recreated without
`--cap-drop`, a permission loosened during debugging and never tightened, a hook that stopped
being registered, a backup that has been failing for six weeks into a log nobody reads.

The score is recorded rather than merely read, because the trend is the signal. A suite that
went from all-green to two-red three weeks ago and has stayed there is telling you something
that a green-or-red glance never would.

**Signals are printed separately and never gate.** `./run-all.sh --signals` reports check-in
coverage and intervention follow-through. A fortnight of illness must not read as a system
fault, both because it is not one and because a red suite unlocks out-of-window changes under
`04-improvement.md`.

## 10. The nightly security observations

Deterministic, no model, and separate from the health check on purpose.

The harness proves a configuration is correct once a week. This notices a behaviour change the
next morning: a new listening socket, a new local user, a changed authorised-keys file, a spike
in failed SSH attempts, a container running that should not be, a tenfold jump in outbound
bytes. Changes append to `ops/security/alerts.md`.

That last one is worth stating plainly: sustained unexpected outbound traffic is what both a
runaway fetcher and an exfiltrating session look like from the outside, and nothing else in
this design would notice either.

Alerts are read at the weekly audit, and anything that looks like compromise goes straight to
`06-recovery-and-incidents.md` rather than being investigated in place.
