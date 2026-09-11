# AIOS

A personal AI operating system: coach, mentor, strategic partner and executive assistant. Runs on a self-hosted VPS, holds highly sensitive personal data, controlled from an iPhone.

## What is here

**Build-time.** Read these to build the system. `BUILD.md` goes obsolete once the build is done; `ARCHITECTURE.md` does not.

| File | Purpose |
|---|---|
| [docs/BUILD.md](docs/BUILD.md) | The build itself. Stages, acceptance gates, stop points. Start here. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Decisions, threat model, network shape, filesystem layout, interface strategy. Reference during and after the build. |

**Runtime.** These are deployed as-is to the VPS. They are the system's operating instructions, loaded on every session, so they are kept deliberately short.

| File | Deployed to |
|---|---|
| [runtime/CLAUDE.md](runtime/CLAUDE.md) | `/srv/aios-data/CLAUDE.md` |
| [runtime/policy/security.md](runtime/policy/security.md) | `/srv/aios-data/policy/security.md` |
| [runtime/policy/trust.md](runtime/policy/trust.md) | `/srv/aios-data/policy/trust.md` |
| [runtime/policy/autonomy.md](runtime/policy/autonomy.md) | `/srv/aios-data/policy/autonomy.md` |
| [runtime/SCHEMAS.md](runtime/SCHEMAS.md) | `/srv/aios-data/policy/schemas.md` |
| [runtime/RECOVERY.template.md](runtime/RECOVERY.template.md) | `/opt/aios-rebuild/RECOVERY.md`, filled in during Stage 7 |

## Read order

1. `docs/ARCHITECTURE.md` for the shape and the reasoning.
2. `docs/BUILD.md` and work the stages in order.
3. Deploy `runtime/` where Stage 3 says to.

## Origin

Distilled from five source documents: a design brief, a data security policy, a mission and partnership statement, an architecture brief, and a memory and data trust policy. Section 9 of `ARCHITECTURE.md` records what changed and why.
