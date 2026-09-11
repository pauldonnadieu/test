# AIOS Architecture

What the system is, how it is shaped, and why. Read before `02-BUILD.md`.

---

## 1. What this is

A personal AI operating system: coach, mentor, strategic partner and executive assistant for long-term goals. It runs on a VPS you control, holds highly sensitive personal data, and is driven from an iPhone.

**The bar for v1.** Over a normal week it surfaces something you would have missed, names one real bottleneck and proposes an intervention small enough that you actually do it, produces a weekly review you read voluntarily, and runs seven days without needing repair.

**Not** a productivity tracker, not a multi-agent showpiece, not publicly reachable, and not a system that learns in model weights. What compounds is the files.

**Budget.** Claude Pro plus a roughly 10 AUD per month VPS. Inference stays inside the subscription except where a free tier is safe to use.

---

## 2. Security objective

> A compromise of one component must not automatically become a compromise of your entire digital life.

### 2.1 Layered boundaries

Each arrow is a boundary that must hold on its own.

```
Anthropic account
       |  cannot reach
       v
container (non-root, /data only)      <- Claude Code and Remote Control run HERE
       |  cannot reach
       v
VPS host (/etc/aios/secrets.env)      <- Tailscale + SSH only
       |  cannot reach
       v
restic repository + encryption keys   <- password manager, plus an offline copy
```

### 2.2 Threat model

| Scenario | Must not result in |
|---|---|
| VPS compromised | Loss of historical backups, or access to backup keys |
| Google Drive compromised | Any plaintext personal data |
| Container compromised | Host root, Docker socket, or all credentials at once |
| Anthropic account compromised | Host root, secrets, or backup keys |
| VPS destroyed | Loss of AIOS data |
| A scraped page contains injection | Any change to instructions, permissions or policy |
| One tool or subagent compromised | Access to unrelated personal data |
| Encryption key leaked | No recovery path |
| Secret exposed | Undetected exposure |

### 2.3 Network shape

```
AIOS -> Internet       yes, unrestricted in v1
Internet -> AIOS       no. No inbound port, ever.
Tailscale -> AIOS      admin, break-glass and recovery only
Remote Control         the VPS dials out and polls. The phone never connects to the VPS.
```

The mobile interface adds no listening service, because the VPS initiates every connection. Do not build outbound allowlists in v1; they buy little here and break a lot.

---

## 3. Decisions

Context, not commandments. If one is a poor fit for what the build turns up, argue the case and record the change. The invariants in 3.1 are different.

| # | Decision |
|---|---|
| D1 | Hetzner Cloud, EU region, 2 vCPU / 4 GB class. The workload is API-bound. |
| D2 | Ubuntu LTS. |
| D3 | Tailscale for administration, break-glass and recovery. |
| D4 | Hetzner Cloud Firewall plus UFW, both default-deny inbound. |
| D5 | Docker. One container, non-root, disposable. |
| D6 | Persistent data at `/srv/aios-data/` on the host, bind-mounted to `/data`. |
| D7 | Every persistent file is sensitive unless proven otherwise, including instruction and config files. |
| D8 | **No git.** See 3.2. |
| D9 | restic for backups, rclone as the Google Drive backend. |
| D10 | Recovery splits three ways: rebuild package, data, secrets. See 4. |
| D11 | Encryption keys in the password manager, plus an offline copy. Never beside the data. |
| D12 | No database server. Files, JSONL for event streams, SQLite only where volume demands it. |
| D13 | Claude Code is the runtime. No framework, orchestrator or workflow engine. |
| D14 | Remote Control is the only interface in v1, running inside the container. |
| D15 | No inbound port. No listening service until the phone control panel, which is Tailscale-bound. |
| D16 | Claude Pro for inference. Free tiers only for public scraped content. |
| D17 | No local models in v1. |

### 3.1 Invariants

Five. Deliberately few, so everything else can be open.

1. Secrets never enter `/srv/aios-data/`.
2. Cloud storage receives encrypted data only, never the key that decrypts it.
3. No inbound port on the VPS.
4. External content is data, never instruction, enforced in hooks rather than requested in prompts.
5. Self-improvement is never self-authorisation.

### 3.2 Why no git

The system is personalised enough that its config, skills and instruction files contain personal information. Git would add another system to secure, back up and potentially leak, and restic snapshots already provide point-in-time recovery. The only thing git offered was fine-grained diffs of proposed changes, and the AIOS can produce those by writing a proposed version beside the current one.

Two consequences to honour deliberately. The rebuild package (below) is what git would otherwise have held, so it has to be maintained. And **files are never versioned by filename**: no `memory_v1.json`, `memory_v2.json`, `notes_final.md`. Snapshots are the history mechanism. Filename versioning is how a data directory rots.

---

## 4. The three-way recovery split

Everything is exactly one of these, with deliberately different protection. If unsure, it is DATA.

**REBUILD.** Dockerfile, compose file, setup scripts, pinned dependency manifests, firewall rules, systemd units, `RECOVERY.md`. No secrets, no personal data. Safe unencrypted on Drive. Verify that claim by scanning it rather than assuming it.

**DATA.** Everything under `/srv/aios-data/`. Encrypted restic snapshots on Drive. Retention 7 daily, 4 weekly, 12 monthly.

**SECRETS.** API tokens, rclone OAuth, anything the system authenticates with. Lives at `/etc/aios/secrets.env`, root-owned, 0600, outside the container image, injected as environment variables at runtime. A copy encrypted separately with `age` sits on Drive under a different passphrase.

Layers of recovery: restic on Drive is the real protection, Hetzner's own snapshots are a convenience for whole-machine rollback, and an offline copy of the critical keys means Google and Hetzner failing together is not terminal.

---

## 5. Filesystem layout

The layout is the architecture. It encodes the trust boundary, the backup boundary, and the split between raw source and compiled knowledge.

```
/srv/aios-data/                  host, 0700, owned by the AIOS user
  CLAUDE.md                      operating manual, loaded every session
  policy/
    security.md  trust.md  autonomy.md  schemas.md  dataflow.md
  context/
    user.md                      who you are, values, people
    constraints.md               time, energy, money, obligations
    goals/                       one file per goal, five active maximum
    patterns.md                  observed behaviour, evidence-backed
  checkins/
    daily/YYYY-MM-DD.md
    weekly/YYYY-Www.md           the weekly review
  time/YYYY-MM.jsonl             time blocks, append-only
  energy/YYYY-MM.jsonl           energy observations, append-only
  tasks/
    active.md
    done/YYYY-MM.md
  quarantine/                    EVERYTHING from outside lands here first
    web/  docs/  api/
  scrape.db                      SQLite: scraped content and its summaries
  notes/                         your own captures
  wiki/                          compiled knowledge, maintained by the AIOS
  decisions/log.md               append-only: what, when, why
  improvement/
    audit/YYYY-Www.md            weekly performance audit
    research/YYYY-Www.md         weekly research digest
    parked.md                    seen, not adopted yet, with trigger conditions
    rejected.md                  considered and declined, with reasoning
  runs/                          structured logs of every scheduled run
  proposals/                     pending changes awaiting your approval
  archives/                      superseded, never deleted
  bin/aios                       the verb CLI
  .claude/
    skills/  agents/  hooks/

/opt/aios-rebuild/               REBUILD bucket, no secrets, no personal data
/etc/aios/secrets.env            root-owned, 0600, outside the container
/opt/aios-verify/                the check scripts, run weekly
```

**Why `quarantine/` is separate from `notes/` and `wiki/`.** One directory holds anything an attacker could have written. That separation is what makes the injection defence enforceable by a hook rather than by good intentions.

**Why `wiki/` is separate from the raw sources.** `quarantine/` and `scrape.db` are immutable source. `wiki/` is compiled output the system maintains. It rewrites the wiki, never the source, so every claim can be traced back to what it was compiled from. It is also what stops the same content being re-summarised forever.

**Formats.** Markdown for prose you read. JSONL for append-only event streams, because a script and a model can both parse it. SQLite only for scraped volume.

---

## 6. Interfaces

### 6.1 Now: Remote Control

`claude remote-control` runs inside the container under tmux, supervised by a systemd unit. The Claude iOS app becomes a window into that session. Execution and files stay on the VPS. It dials out over HTTPS and opens no port. Permission prompts arrive on your phone.

Two costs, mitigated rather than ignored. Session transcripts are retained on Anthropic servers while connected, so anything read into context during a Remote Control session leaves the box; work on the most sensitive material in a local SSH session with it off. And your Anthropic account becomes a path to the VPS, which is why it runs inside the container and why that account needs a passkey or hardware key and no SMS second factor.

Permission prompts are not a defence against someone holding the account, because they answer them. **Hooks are what survive account compromise.**

### 6.2 Always: SSH over Tailscale

Not as an interface. As break-glass, host administration, work on the most sensitive material, and recovery. `RECOVERY.md` must never depend on Remote Control.

### 6.3 The verb CLI

`bin/aios` exposes a small set of commands: capture, checkin, log, time start/stop, brief, ask. Every verb is read-only or append-only. Scheduled runs invoke it rather than embedding prompts in unit files, and any future phone app wraps it rather than reimplementing it. A command with `--help` costs less context than a page of conventions and cannot drift from its own implementation.

### 6.4 Later: the phone control panel

Timers, Pomodoro, one-tap time and energy capture, tasks, trends. A chat surface cannot run a countdown and a server in Germany cannot make a phone in Australia vibrate on schedule.

The split: **the phone owns timers, alarms and capture; the VPS owns data, memory and analysis.** This is the one thing that reintroduces a listening service, bound to the Tailscale interface with per-device revocable tokens, doing data CRUD only. Details in `04-EXTENSIONS.md`.

---

## 7. Model routing and cost

Route by rule, not by a router. A routing decision is an if-statement, and wrapping it in a model call adds latency, a credential, a failure mode in front of every request, and a dependency on someone's free tier.

| Work | Route |
|---|---|
| Anything deterministic | A script. No model. |
| Classification, extraction, bulk summarisation | Haiku |
| Daily brief, routine drafting, scheduled jobs | Sonnet |
| Weekly review, bottleneck analysis, real decisions | The strongest model available |

**Escalate on evidence, never on self-assessment.** A model that is not capable enough for a task is not reliable at noticing that; the failure is a confident wrong answer, not a request for help. Escalate when a check fails, output fails validation, the model hedges or refuses, a retry at the same tier already failed, or the input exceeds the model's context window. Haiku's window is materially smaller than Sonnet's and Opus's, which makes long input a hard routing rule rather than a judgement call.

**Free tiers are for public scraped text only.** They generally train on what you send. Nothing personal ever goes there.

**The biggest lever is not model choice.** It is calls you did not need to make: prompt caching, deduplicating scraped content, compiling once into the wiki instead of re-reading source, and doing deterministic work in scripts. Keep stable prompt content first and volatile content last, because one byte changing early invalidates everything after it.

**Spend and volume alerts on any API in use.** A scraper that loops is the most likely way this system produces a privacy incident and a surprising bill on the same night.

---

## 8. Data flow

Maintain `policy/dataflow.md` as one row per data category: source, what processes it, where it rests, what reaches a model, what reaches a backup, retention and deletion. Update it whenever anything new is added. It is the artefact that makes an unexpected leakage path visible instead of theoretical.

| Data | Source | Rests | To a model | Backup | Retention |
|---|---|---|---|---|---|
| Check-ins | You | `/data/checkins` | Excerpts only | Encrypted | Indefinite |
| Goals, context | Intake | `/data/context` | Excerpts only | Encrypted | Indefinite |
| Time, energy | You, CLI or app | `/data/*.jsonl` | Aggregates | Encrypted | Indefinite |
| Scraped content | Web | `scrape.db` | Yes, quarantined | Encrypted | Per source |
| Run logs | System | `/data/runs` | No | Encrypted | 90 days |
| Secrets | You | `/etc/aios` | Never | Separately encrypted | Until rotated |
