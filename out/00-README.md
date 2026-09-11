# AIOS

A personal AI operating system on a self-hosted VPS: coach, mentor, strategic partner and executive assistant for long-term goals. Controlled from an iPhone. Holds highly sensitive personal data.

Hand these four documents to Claude Code.

| File | What it is |
|---|---|
| `01-ARCHITECTURE.md` | The shape and the reasoning. Decisions, threat model, folder layout, model routing, data flow. Start here. |
| `02-BUILD.md` | Eight goals in order, each with a definition of done and an executable check. |
| `03-OPERATING.md` | What it is once running. Persona, coaching loop, trust and provenance, deletion, autonomy, the weekly audit and research rituals. Source for its own instruction files. |
| `04-EXTENSIONS.md` | After the core works: the phone control panel, the scraping pipeline, connections, offline backup. |

## How to run the build

One session per stage. Open with the stage goal rather than the whole document. Each stage ships a check script that prints a score and exits non-zero on failure; a stage is done when the score says so, never when the work looks done. Never weaken a check to make it pass.

Claude Code owns the method. These documents state outcomes, constraints and what done looks like. Where they describe an approach it is a starting point, and a better one is better. The decisions in `01-ARCHITECTURE.md` §3 are context and can be argued with; the five invariants in §3.1 cannot.

## The shape in one paragraph

A Hetzner VPS with no inbound port, reachable only over Tailscale. Claude Code in a non-root container; all personal data on a host bind mount outside it. No git. Encrypted restic snapshots to Google Drive with keys in a password manager and offline, recovery split into rebuild package, data and secrets, and a restore proven on a throwaway box. Controlled from the Claude iOS app via Remote Control, which dials out so nothing listens. It holds your goals, takes a thirty-second daily check-in, tracks self-reported time and energy, and produces a weekly review that names one real bottleneck. It improves by auditing its own performance weekly and scanning the landscape weekly, proposing changes you approve, and changing nothing unless it is proven worth it.

## One thing worth knowing before you start

The structure is built to be read. Seven directories at the top, grouped by what they are to you: `me/`, `journal/`, `tracking/`, `projects/`, `knowledge/`, `untrusted/`, and `system/` for the machine's own business. A `START-HERE.md` at the root explains the lot in one screen and is regenerated whenever anything moves.

You never file anything. Every directory the system uses is maintained by the AIOS itself, as a side effect of talking to it. Mention a worry and it is filed with provenance; say a goal is finished and it moves; describe something you are building and the project folder appears. If it is unsure where something goes it guesses, tells you, and moves on rather than asking. A folder structure you have to maintain would be the second job this system was supposed to remove.

## First step

Create a Hetzner account and a Tailscale account. Only you can do that. Then start Stage 1.
