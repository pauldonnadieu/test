# AIOS

A coach, mentor, executive assistant and chief of staff that runs on a VPS the user owns, knows
their goals and their actual capacity, and is judged on one thing: whether their life measurably
improved.

It works from what they **did**, not what they planned. An under-a-minute daily check-in is the
foundation; without it the system can only reason about intentions, and reasoning about
intentions is how every productivity system the user has abandoned worked. From that ground truth
it produces a weekly review that names one real bottleneck with evidence, separates genuine
constraint from self-sabotage, and prepares the smallest intervention the user would actually do.
It also looks forward: what is approaching, what needs preparing, what decision is coming, what
is about to be forgotten.

The user never files anything, never maintains the structure, and never answers a question about
where something goes.

---

## How to read this

The **spine** is always read. The **reference** documents are loaded when the moment needs them,
exactly as skills work. This is deliberate: a blueprint too long for one session to hold fails at
the one job it has.

| Read | When |
|---|---|
| `00-PROVEN.md` | **Before anything else.** What has been tested, what has been carried forward, and what has never been run |
| `core/01-architecture.md` | Once, properly, before building |
| `HUMAN-TASKS.md` | Before stage 1. Everything only a person can do, in build order |
| `core/02-build.md` | While building. Fourteen stages, each with a definition of done and a check |
| `core/03-operations.md` | Once it runs |
| `core/04-improvement.md` | Weekly, on its own |

| Reference | Load it when |
|---|---|
| `reference/R1-security.md` | Building, changing or auditing a boundary |
| `reference/R2-privacy-routing.md` | Configuring the lanes, changing routing, or asking where time and money go |
| `reference/R3-recovery.md` | **Before you need it.** Kill switch, rotation, incidents, restore |
| `reference/R4-currency.md` | The weekly scan, or when the runtime has moved |
| `reference/R5-lifecycle.md` | Planning, upgrades, end of life, or losing track of what is due |
| `reference/R6-worked-example.md` | Before writing any skill output. One full week, end to end |
| `reference/R7-after-v1.md` | When tempted to add something |

`checks/` is not documentation. It is the executable half and it runs for as long as the system
exists. `conf/` holds the instruction file, the three settings files and the four hooks. `bin/`
holds the routines. `skills/` holds the work. `test/` holds the tests of this documentation.

---

## Start here

```bash
cd checks
./run-all.sh --self-test                         # proves the runner before you trust any score
cp config.env.example config.env && "$EDITOR" config.env
./run-all.sh                                     # near zero on a fresh box. That is correct
```

Then work through `core/02-build.md` stage by stage. **A stage is done when its check passes**,
not when the work feels finished.

---

## Seven things that are true about this system

1. **It does not learn.** The model starts every session from nothing. What compounds is the
   files. Being straight about this is what stops the design being wishful.
2. **Every boundary assumes the one in front of it already failed.** Losing any single component
   costs that component, not everything.
3. **Enforcement is deterministic or it is decoration.** Ownership, container flags, deny rules
   and hooks are shell and kernel, not judgement. Nothing that guards this depends on the model
   choosing well, and none of it costs a token.
4. **A skipped check is a failure.** An unrun check is an unknown, and an unknown is not a pass.
   The runner enforces this, and it has been tested doing so.
5. **A check that has only ever passed proves nothing.** Every check that can be exercised here
   has been watched failing on a deliberately broken case first.
6. **It may improve its methods, never its own authority.** Changes to what it is allowed to do
   are the user's, always, and are not reachable from inside the container.
7. **Stability is the default state.** At most one adopted change a month unless something is
   broken. "No change this week" is a recorded outcome, not silence.

## What this build assumes

Hetzner VPS in an EU region, about 2 vCPU / 4 GB, Ubuntu LTS. Tailscale for administration and
break-glass, no inbound port. One non-root Docker container, disposable, with personal data on a
host bind mount. restic via rclone to Google Drive, encrypted before upload. No git anywhere in
the AIOS. No database server. Claude Code is the runtime, with no framework, orchestrator or
workflow engine. No calendar, no email. No local models.

**Budget: a Claude Pro subscription plus about 10 AUD a month for the VPS, as a hard constraint.**
Free tiers from other providers do low-stakes utility work in a structurally confined lane so the
subscription is spent where judgement is needed. The design fits inside that or it is the wrong
design, and `reference/R2-privacy-routing.md` says plainly what it gives up to stay there.

## Conventions

**Goals, not scripts.** Claude Code knows how to harden a box. It cannot know what the user wants
proven. Where a method is named it is a starting point and you are expected to improve on it.
Where a *definition of done* is named, it is not negotiable.

**Method is a starting point. Done is not.**
