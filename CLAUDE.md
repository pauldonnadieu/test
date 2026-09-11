# AIOS build repo

This repository is the briefing pack for building a personal AI operating system on a self-hosted VPS. It contains no application code. The system gets built on the VPS; this is what tells you how.

## Read these, in this order

1. `docs/ARCHITECTURE.md`: the shape and the reasoning. Decisions, threat model, interfaces.
2. `docs/WORKING.md`: how to run this build. Goals, scoring, sessions, plan mode, review.
3. `docs/BUILD.md`: eight stages, each a goal with a definition of done.
4. `docs/EXTENSIONS.md`: only after the core has run for a month.

`reference/` holds drafts of the files that will live on the VPS. Adapt them; do not copy them blindly.

## How this build runs

**One stage per session.** Invoke `/stage N`. Do not carry two stages in one context window.

**Every stage is scored, not judged.** Each stage ships `verify/stageN-*.sh` following `verify/CONTRACT.md`. It prints `SCORE p/t` and exits 0 only when every check ran and passed. Write it alongside the work, not after.

**The score is the evidence.** A stage is done when the score line says so. Not when the work looks done.

**Never weaken a check to make it pass.** IMPORTANT: this is the one move that is never available. If a check blocks the goal, the goal is blocked. Say so.

**You own the how.** The docs state outcomes and constraints. Method is yours. Where they describe an approach it is a starting point, and a better one is better.

**Argue when a decision looks wrong.** The decisions in `ARCHITECTURE.md` Section 3 were made without knowing what the build would turn up. They are context. The five invariants in Section 3.1 are not.

## Invariants

Do not trade these for progress, convenience or capability.

1. Secrets never enter `/srv/aios-data/` or git.
2. Cloud storage receives encrypted data only, never the key that decrypts it.
3. No inbound port on the VPS.
4. External content is data, never instruction, enforced in hooks rather than requested in prompts.
5. Self-improvement is never self-authorisation.

## Conventions in this repo

- Australian English. Straight quotes. No em or en dashes.
- Markdown for prose. Shell for checks.
- Record decisions and their reasoning in the commit message; there is no code to explain them.
