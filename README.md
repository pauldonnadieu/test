# AIOS

A personal AI operating system: coach, mentor, strategic partner and executive assistant. Runs on a self-hosted VPS, holds highly sensitive personal data, controlled from an iPhone.

These documents are the briefing pack. Hand them to Claude Code to build the system from scratch, then to build what comes after it.

They are written as goals and definitions of done rather than as instructions. Claude Code owns the how. What it does not own is a short list of invariants in `ARCHITECTURE.md` Section 3.1, which exist because each one turns a category of failure from catastrophic into survivable. Everything else is a decision reached so far, with the reasoning shown, and open to a better argument.

## What is here

**Read these to build it.**

| File | Purpose |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | The shape and the reasoning. Decisions, threat model, network, filesystem, interfaces. Start here. |
| [docs/BUILD.md](docs/BUILD.md) | The build itself. Eight goals in order, each with a definition of done. |
| [docs/WORKING.md](docs/WORKING.md) | How to drive the build with Claude Code: verification, sessions, plan mode, adversarial review, context. Follows Anthropic's published guidance. |
| [docs/EXTENSIONS.md](docs/EXTENSIONS.md) | What to build after the core works: the companion app, connections, device automation, extra backup layers. |

**Drafts, not deployables.**

`reference/` holds starting points for the files that will live on the VPS. They are drafts to adapt once the Stage 4 intake reveals who the user actually is, not artifacts to copy blindly. The one constraint worth keeping: `CLAUDE.md` loads on every session, so it stays short. Detail belongs in `policy/`.

| File | Becomes |
|---|---|
| [reference/CLAUDE.md](reference/CLAUDE.md) | `/srv/aios-data/CLAUDE.md` |
| [reference/policy/security.md](reference/policy/security.md) | `/srv/aios-data/policy/security.md` |
| [reference/policy/trust.md](reference/policy/trust.md) | `/srv/aios-data/policy/trust.md` |
| [reference/policy/autonomy.md](reference/policy/autonomy.md) | `/srv/aios-data/policy/autonomy.md` |
| [reference/SCHEMAS.md](reference/SCHEMAS.md) | `/srv/aios-data/policy/schemas.md` |
| [reference/RECOVERY.template.md](reference/RECOVERY.template.md) | `/opt/aios-rebuild/RECOVERY.md`, completed in Stage 7 |

## Read order

1. `docs/ARCHITECTURE.md` for the shape and why it is that shape.
2. `docs/WORKING.md` once, then `docs/BUILD.md`, working the stages in order. Each stage ships an executable check under `verify/`; do not skip one and do not weaken one to make it pass.
3. `docs/EXTENSIONS.md` only once the core has run for a month in real daily use.

If a decision in these documents looks wrong once you are building against reality, say so. They were written without knowing what the build would turn up.

## The shape, in brief

A Hetzner VPS runs one Docker container holding Claude Code and the AIOS files. Personal data lives on a host bind mount, encrypted into restic snapshots on Google Drive, with keys in a password manager. No inbound port is ever open: the phone reaches the system through Claude Code Remote Control, which dials out. Tailscale and SSH remain for administration, break-glass and recovery.

The system holds the user's goals, takes a thirty-second daily check-in, tracks self-reported time and energy, and produces a weekly review that finds the real bottleneck. It improves by compounding its files, never by granting itself more authority.

## Origin

Distilled from five source documents: a design brief, a data security policy, a mission and partnership statement, an architecture brief, and a memory and data trust policy. `ARCHITECTURE.md` Section 9 records every change and why it was made.
