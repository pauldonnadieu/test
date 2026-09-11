# AIOS

A coach and chief of staff that runs on a VPS the user owns, knows their goals and their
actual capacity, and is judged on one thing: whether their life measurably improved.

The hinge is that it knows what they **did**, not what they planned. A thirty-second daily
check-in is the foundation. Without it the system can only reason about intentions, and
reasoning about intentions is how every productivity system the user has abandoned worked.
From that ground truth it produces a weekly review that names one real bottleneck, separates
genuine constraint from self-sabotage using evidence rather than a hunch, and prepares the
smallest intervention the user would actually do.

The user never files anything, never maintains the structure, and never answers a question
about where something goes.

## Read in this order

| # | File | When you read it |
|---|------|------------------|
| 0 | `00-READ-ME-FIRST-proven.md` | Before anything else. What has actually been tested, and what has not |
| 1 | `01-architecture.md` | Once, properly, before building. The system, the boundaries, and the limits that are real |
| 2 | `HUMAN-TASKS.md` | Before stage 1. Everything only a person can do, in the order the build needs it |
| 3 | `02-build.md` | While building. Thirteen stages, each a goal with a definition of done and a check that proves it |
| 4 | `03-operations.md` | Once it runs, and whenever something breaks |
| 5 | `06-recovery-and-incidents.md` | Before you need it. The kill switch, rotation, and what to do when something is wrong |
| 6 | `04-improvement.md` | Weekly, on its own |
| 7 | `05-after-v1.md` | When you are tempted to add something to v1 |
| 8 | `test/VPS-ACCEPTANCE.md` | On the real machine. The checks a sandbox cannot run |

`checks/` is not documentation. It is the executable half of this set, and it runs for as long
as the system exists. `skills/` holds the procedures, including the coaching work that is the
actual point of the system. `test/` holds the tests of this documentation: a cold-reader dry
run (`E2E-PROCEDURE.md`), the acceptance test for the real VPS (`VPS-ACCEPTANCE.md`), and the
template every self-proposed change must fill in (`PROPOSAL-TEMPLATE.md`).

`CHANGELOG-v4.md` records what changed from the previous version of this set and why, so the
decisions do not have to be re-derived in six months.

**Before you trust any of it: `00-READ-ME-FIRST-proven.md`.** Roughly a third of the checks
have never been run anywhere, and they include the ones carrying the most security weight.
That file says exactly which, and why.

## Start here

```bash
cd checks
./run-all.sh --self-test      # proves the runner scores correctly before you trust it
cp config.env.example config.env && "$EDITOR" config.env
./run-all.sh                  # will score near zero on a fresh box; that is correct
```

Then work through `02-build.md` stage by stage. A stage is done when its check passes, not
when the work feels finished.

## Six things that are true about this system

1. **It does not learn.** The model starts every session from nothing. What compounds is the
   files. Being straight about this is what stops the design being wishful.
2. **Every boundary assumes the one in front of it already failed.** Losing any single
   component costs that component, not everything.
3. **Enforcement is deterministic or it is decoration.** Ownership, container flags, deny
   rules and hooks are all shell and kernel, not judgement. Nothing that guards this system
   depends on the model choosing well.
4. **A skipped check is a failure.** An unrun check is an unknown, and an unknown is not a
   pass. The runner enforces this; it is not a convention anyone has to remember.
5. **It may improve its methods, never its own authority.** Changes to what it is allowed to
   do are the user's, always, and are not reachable from inside the container.
6. **Stability is the default state.** At most one adopted change a month unless something is
   broken. "No change this week" is a recorded outcome, not silence.

## What this build assumes

Hetzner VPS in an EU region, about 2 vCPU / 4 GB, Ubuntu LTS. Tailscale for administration and
break-glass, no inbound port on the VPS. One non-root Docker container, disposable, with
personal data on a host bind mount. restic via rclone to Google Drive, encrypted before
upload. No git anywhere in the AIOS. No database server. Claude Code is the runtime, with no
framework, orchestrator or workflow engine. No connections in v1: no calendar, no email. No
local models in v1.

Budget: a Claude Pro subscription (about 35 AUD/month) plus the VPS (about 10 AUD/month). The
design holds inside that or it is the wrong design.

## Conventions in these documents

**Goals, not scripts.** Claude Code knows how to harden a box. It cannot know what the user
wants proven. Where a method is named, it is labelled a starting point and you are expected to
improve on it. Where a *definition of done* is named, it is not negotiable.

**Method is a starting point. Done is not.**
