# R5 - The long arc

What owning this looks like after the build. Loaded when planning, when something reaches end of
life, or when you have lost track of what is due.

---

## 1. The rhythm, on one page

| When | What | Who |
|---|---|---|
| **Daily** | The check-in. Under a minute | You |
| Daily, unattended | Backup, change ledger, security observation, sweep | The machine |
| **Weekly** | Read the review. That is the whole point | You |
| Weekly, unattended | Weekly review, audit, research scan, full health suite recorded | The machine |
| **Monthly** | Approve or reject what is in `ops/proposals/`. At most one adoption | You |
| Monthly, unattended | Restore drill on the canary file | The machine |
| **Quarterly** | Full restore drill on a second VPS, by hand. Read the offline key | You |
| **Quarterly** | The tier-3 read: open `CLAUDE.md` and one review cold and ask whether they are any good | You |
| **Annually** | Re-attest everything in stage 0. Re-verify the watchlist. Re-run the intake | You |

Everything in the "you" column is roughly two hours a quarter plus a minute a day. If it becomes
more than that, something has gone wrong with the design rather than with your discipline, and
that is a finding for the audit.

---

## 2. The arc

**Week one to two.** Change nothing. Two weeks of ordinary use is the cheapest way to find out
which parts of the design were wishful, and the improvement loop does not start until there is a
baseline to measure against.

**Month one.** The first real question is not whether the system works but whether you read the
review voluntarily. If you do not, that is the finding, and it outranks everything in the backlog.
Expect the first genuine defect here: something in the intake that was wrong, or a routine
scheduled at a stupid hour.

**Month three.** Enough check-ins for patterns to be real rather than suggestive. This is the
first point at which `skills/patterns/` has enough evidence to say anything, and the first point
at which intervention follow-through means something as a number.

**Month six.** Re-read the goal files cold. Some will describe a person who no longer exists, and
retiring a goal is a healthy outcome rather than a failure. Check whether the structure is still
being maintained by the system or whether you have started filing things by hand, because that is
the earliest sign that the filing rules have drifted from your actual life.

**Year one.** Re-run the intake properly, as a conversation, not a patch. A year of check-ins and
reviews is better material for that conversation than anything you had the first time. Re-attest
everything. Check the watchlist still points at things that exist.

---

## 3. Upgrades and end of life

Three things will reach end of life on their own schedule, and none of them will ask first.

### The operating system

Ubuntu LTS is supported for years, and the end still arrives. **Plan the move six months before
the date, not after it**, and treat it as a rebuild rather than an in-place upgrade: you have a
tested recovery path, which makes a fresh box with a restore the lower-risk option and also a
free rehearsal of the drill.

Procedure: new VPS on the new release, follow `RESTORE.md`, run the full suite, run both in
parallel for a day, cut over, destroy the old one. The only new work is confirming the pinned
base image and the CLI still install on the new release.

### The container image and its dependencies

Pinned, never `latest` (`RB.7`), which means they do not move until you move them. Review at the
quarterly drill: base image security updates matter, feature releases do not. Bump, rebuild,
re-run the suite, and if the suite is green the change is done. If it is red, you have learned
something cheap.

### Claude Code itself

The one that moves fastest and the one most likely to break something quietly. `DRIFT.1` fails if
a flag the scripts pass has vanished, `DRIFT.2` records the version and reports a change, and
`DRIFT.3` checks the hook payload adapter still looks right.

**When drift reports a change:** read the release notes before the next scan, re-run
`stage-03-runtime`, and specifically re-verify the hook contract, because the adapter is the part
of this design most exposed to an upstream change. If a flag was renamed, fix the scripts, do not
widen the check.

### The VPS itself

Resizing is a Hetzner console operation and a reboot, which means `test/VPS-ACCEPTANCE.md` part 4
applies: everything must come back with no human intervention. Do it on a day you are watching.
Growing beyond the current class is a budget conversation, and the usual reason is a local model,
which `R2` section 2 says to defer until it is evidence rather than a hunch.

---

## 4. When something is retired

**A skill that has not fired in ninety days** is a retirement proposal at the weekly audit. Skill
debt is a real cost: routing quality degrades with count, so fewer and sharper wins.

**A check whose property no longer matters** is a proposal like any other, never a quiet deletion,
which the regression gate would catch anyway. Removing a check is the cheapest way to make a
change look safe, and that is exactly why it is a deliberate act with an argument attached.

**A goal** moves to achieved or abandoned with the date and the reason. Abandoned is a real
outcome and using it honestly is healthier than a file that quietly stops being mentioned.

**The whole system**, if it ever comes to that: the data is plain files, the backup is a standard
restic repository, and nothing here is a format anyone is locked into. That is a design property
worth preserving, and it is the reason there is no database.

---

## 5. What to watch for over years

**The structure drifting.** If you start filing things by hand, the filing rules no longer match
your life. Fix the rules.

**The reviews getting samey.** Either the bottleneck genuinely has not moved, which is a finding,
or the review has learned to produce a shape rather than an argument, which is a different and
worse finding.

**The improvement ledger busier than the check-in log.** The most likely way this particular
system gets abandoned is that building it becomes more interesting than using it.
`skills/patterns/` names overengineering as a watch item for exactly this reason, and it applies
to the AIOS itself as much as to anything else in the user's life.

**Silence.** A month of quiet weeks is the loop working. A month of quiet weeks *and* no
check-ins is the system being dead while looking healthy, which is what the signals score and the
dormancy rule exist to make visible.
