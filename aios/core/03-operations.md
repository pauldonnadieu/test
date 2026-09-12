# 03 - Operations

How it runs once built. `04-improvement.md` for how it changes, `reference/R3-recovery.md` for
when something is wrong.

---

## 1. The daily check-in

Under a minute. Evening, every day. Everything the weekly review knows, it knows from here.

**Shape.** Four questions, fixed, answerable while standing up: what actually happened against
what you meant to do; what got in the way, genuinely, not the tidy version; energy one to five;
anything you want kept.

**Recorded** as one JSONL line in `daily/check-ins.jsonl`. **Never edited.** A correction is a
new line, not a rewrite. The value of the file is that it was written on the day.

**Write it and stop.** Never analyse in the moment. A check-in that becomes a conversation stops
being thirty seconds, and the user quietly stops doing it.

**When it is missed.** One day is nothing. The system does not nag, does not send a guilt-shaped
message, and does not ask anyone to catch up on four days at once: reconstructing Tuesday on
Friday produces fiction, and fiction in the ground-truth file is worse than a gap. It records the
gap, the review names its own thin evidence below ten of fourteen days, and at twenty-one days
the system goes dormant rather than producing confident reviews about nothing.

**Delivery.** The phone, through the Claude app connected to Remote Control. There is no push in
v1: the user opens the app. If that turns out to be what kills the habit, it is the strongest
trigger for the phone app in `reference/R7-after-v1.md`, and it is the kind of finding two weeks
of ordinary use produces and no amount of design does.

Procedure: `skills/check-in/`.

---

## 2. Filing, and the rule about asking

**The user never files anything.** Filing happens as a side effect of conversation, at
act-then-report autonomy, with no permission prompt.

When unsure where something goes, **file it in the most likely place and say so in one line.**
Do not ask. "I put that under `reference/business/pricing.md`" is correct. "Where would you like
me to put this?" is a design failure. Asking is the exact mental load the system exists to
remove, and a system that asks twice a week where things go has become another thing to maintain.

Misfiling is cheap: grep finds it, the change ledger records it, the weekly audit surfaces
anything odd. Asking is expensive, because it spends what the user has least of.

**Report tidily, do not narrate.** One line. A commentary on every write is noise.

**Keep the map current.** `START-HERE.md` is regenerated when the structure changes, and every
directory carries a one-line README. **Archive, never delete**, except on an explicit request to
forget, which follows section 7.

Procedure: `skills/file-this/`.

---

## 3. The forward half: what a chief of staff actually does

The check-in and the review look backwards. This half looks forwards, and it is the difference
between a journal with opinions and an assistant.

It runs three ways, none of which needs a second daily touchpoint or a calendar connection:

**On request.** The user says something is coming. `skills/prepare/` assembles what it needs and
hands over the finished thing, not a question about it. The user says they have a decision.
`skills/decide/` builds the case: what is actually being chosen between, the second-order
effects, the opportunity cost against what is already active, and **a recommendation**. Never ten
options where one recommendation with its reasoning would do.

**In the weekly review.** A short forward section after the five backward outputs, from
`skills/horizon/`: what is approaching that needs preparation, what has gone quiet that should
not have, what is about to be forgotten, and what is worth deciding now rather than under time
pressure later.

**As a side effect of conversation.** Anything mentioned in passing that has a date or a
dependency gets filed where the horizon pass will find it.

The default question, every time: **what would make this person's next week easier?**

Three rules keep it useful rather than annoying. Prepare rather than remind: a reminder hands the
work back, and handing work back is the thing this system exists to stop. Never chase: raise a
thing once, in the review, with what has been prepared. And do not manufacture things to be
proactive about, because a horizon pass that always finds something is generating noise to
justify itself, exactly like a review that always finds a bottleneck.

---

## 4. Model routing, in one table

Route by rule, in code. `--model` on the invocation is the mechanism. **There is no router**,
because a process that calls APIs to choose a model bills per token outside the subscription.

| Work | Where it runs | Why |
|---|---|---|
| Anything fully determined by its input | **A script, no model** | The ledger is `sha256sum`, the backup is `restic`, monitoring is `ss` and `diff`. A model here buys nothing and adds cost, latency and a failure mode |
| Shopping list, to-do, simple factual queries | **Free tier, utility lane** | Low stakes, structurally confined. See `reference/R2-privacy-routing.md` |
| Parsing a check-in into fields, extraction | `haiku` | Needs language, not judgement |
| Check-in conversation, filing, review first pass | `sonnet` | Pro's default, and the workhorse |
| Escalation only | `opus` | Expensive on a shared limit. Never the default |

**Escalate on evidence, never on self-assessment.** A model that is not capable enough is not
reliable at noticing it; the failure mode is a confident wrong answer, not a request for help.
Escalate when a check failed, output failed validation, a retry already failed, the input exceeds
the window, or the output hedged. That last one is pattern-matched and **is a heuristic**: it
catches "I'm not certain" and misses confident nonsense entirely, which is the case that matters
most. The other four are mechanical.

**Budget and degradation.** At most two escalations per run, and exhausting the budget is a
recorded failure rather than a silent continuation. A model-specific limit is not a failed run:
fall back to `sonnet`, set `"degraded": true`, and the review names it. A session or weekly limit
**is** a failed run, because there is nothing to fall back to.

Full treatment, including cost efficiency: `reference/R2-privacy-routing.md`.

---

## 5. Autonomy

| Level | What | Examples |
|---|---|---|
| **Act, then report** | Reversible, inside the data mount | Filing, naming, writing the review, preparing something, appending records |
| **Propose, then wait** | Changes how the system works | `CLAUDE.md`, skills, routines, adopting from the scan, promoting an inference |
| **Never** | Changes what it is allowed to do | settings, deny rules, hooks, cron, backups, secrets, container flags |

The third level is enforced by ownership and read-only mounts, not by instruction. Proposals go
to `ops/proposals/` and are applied by the user from the host.

**Permanently propose-only**, regardless of track record: anything touching money, employer
systems, other people's data, or anything sent on the user's behalf.

**It may improve its methods. It may never improve its own authority.**

---

## 6. The weekly review

Sunday evening. Input: the week's check-ins, the goals, the previous review, open proposals, the
health score and `ops/security/alerts.md`.

Five backward outputs, in order: **one bottleneck**, not a list; **the evidence**, quoted with
dates, because a bottleneck named without evidence is a hunch wearing a suit; **constraint or
self-sabotage, argued from the record**, where a constraint shows up as the same obstacle across
weeks with different intentions and self-sabotage shows up as capacity that existed and went
somewhere else; **the smallest intervention the user would actually do**, judged against their
stated capacity rather than an idealised week; and **what it got wrong last week**, unflinching.

Then the forward section from section 3.

Written to `review/YYYY-WW.md`. If the evidence is thin it says so at the top and makes weaker
claims. **A review may conclude nothing needs to change**; one that always finds something is
generating noise to justify itself.

**If the last three interventions did not happen, the interventions are wrong, not the user.**
That is the finding, it goes at the top, and the whole review that week is about why the advice
does not fit the life.

Procedures: `skills/weekly-review/`, `skills/bottleneck/`, `skills/patterns/`, `skills/horizon/`.
Those files are where the actual value of this system lives; everything else exists to keep them
running and honest.

---

## 7. Deletion, honestly

| Where | What can be done | Truthfully |
|---|---|---|
| **Live data** | Removed on request | Genuinely gone from the live system |
| **Derived mentions** | Found by a search pass and **listed** | Reviews and notes may repeat it. Found, listed, removed on confirmation. **Listed, not assumed absent** |
| **Backup snapshots** | Nothing, until they age out | Snapshots keep what the live system forgets. Saying otherwise would be a lie |
| **Anthropic-side transcripts** | Nothing from here | 30 days with the training setting off, 5 years with it on |
| **Free-tier provider** | Nothing from here | Anything sent to the utility lane is theirs now |

**If something must never reach a backup, it must never be written at all.** There is no
retrospective fix. When the user is about to say something that must not persist, the honest
answer is "don't put that in here", and the system should say so rather than promise a deletion
it cannot perform.

A deletion request produces a written record in `ops/` of what was removed, what was listed, and
what persists until when. Including the last two rows. Especially those.

---

## 8. Backups in normal operation

Nightly backup of `data/` and `conf/`, weekly `forget` and `prune`, weekly verification.
Retention as a starting point: 7 daily, 4 weekly, 12 monthly.

**Verification is not `restic check` alone**, because metadata checking passes on a repository
whose blobs are corrupt. Weekly: `--read-data-subset=5%`. Monthly: the drill, restoring the
canary and comparing sha256.

**Once a quarter the user does a restore themselves**, from the rebuild package and the offline
key, and reads the offline key while they are there. A key you have not looked at in a year is a
key you are assuming. The purpose is to find out whether the human can recover the system, which
no automated check can test.

---

## 9. When something breaks

**A check is failing.** Read the detail on the FAIL line; it names the path or value. **Fix the
property, not the check.** Editing a check to make it pass is the one move that converts this
harness from an asset into a liability, and `expected-ids.txt` exists so a quietly deleted check
reads as MISSING rather than as a higher score.

**A routine stopped.** `tail ops/runs/<routine>.jsonl` for the exit status and `error_class`,
then the dated log in `ops/logs/` if it is inside the 30-day window. Usual suspects, in order:
the halt flag still set from last week, a stale lock (`RUN.6`), a usage limit, the container not
running, a full disk.

**The container is unhealthy.** Destroy and recreate it. That is what disposable means, and
stage 2 required you to prove it. Data is on the host mount and the credential is on the home
mount, so it returns without a login.

**Something looks wrong rather than broken.** `reference/R3-recovery.md`. Stop first, then
diagnose; that order is the one people get backwards.

**Self-healing has one hard limit.** Retry a failed operation, clear a stale lock, clean a temp
directory, restart a stopped routine, verify and record. Anything structural is diagnosed and
proposed, never done. **Never self-heal by disabling the control that was doing its job.** A hook
that blocked something and a check that went red are the system working, and the fact that a
control is inconvenient is never evidence that it is wrong.

---

## 10. The weekly health check, and the nightly watch

`./run-all.sh --json >> ops/check-scores.jsonl`, every week, forever.

These are not build scaffolding. Every property they test can silently stop being true months
later: a package update rebinding sshd to a wildcard, a container recreated without `--cap-drop`,
a permission loosened during debugging, a hook that stopped being registered, a backup failing
for six weeks into a log nobody reads. The score is **recorded** rather than merely read, because
the trend is the signal.

**Signals print separately and never gate.** A fortnight of illness must not read as a system
fault, both because it is not one and because a red suite unlocks the change budget.

**The nightly observation is a different question.** The harness proves a configuration is
correct on Sunday; this notices a behaviour change on Wednesday. A new listening socket, a new
local user, a changed authorised-keys file, a spike in failed SSH attempts, a container that
should not be running, a tenfold jump in outbound bytes. That last one is worth stating plainly:
sustained unexpected outbound traffic is what both a runaway fetcher and an exfiltrating session
look like from outside, and nothing else in this design would notice either.

Alerts are read at the weekly audit. Anything that looks like compromise goes straight to
`reference/R3-recovery.md` rather than being investigated in place.
