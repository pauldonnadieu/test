# R1 - Security model

Loaded when you are building, changing or auditing a boundary. `core/01-architecture.md` has the
summary; this has the reasoning and the detail.

---

## 1. The objective, stated once

> A compromise of one component must not automatically become a compromise of the user's entire
> digital life.

Not "the system cannot be compromised". That claim would be false and would make every other
claim here untrustworthy. The objective is containment, and containment is measurable: for each
component, what does an attacker get, and what do they still not have?

---

## 2. Threat model

| Scenario | Must not result in |
|---|---|
| Container compromised | Host root, the secrets, the backup keys, the config, or the free-tier credential |
| Host compromised | Loss of historical backups, or usable backup keys at rest |
| Google Drive compromised | Any plaintext personal data |
| Free-tier provider compromised or reading everything | Anything from `goals/`, `daily/`, `review/`, `reference/` |
| Anthropic account compromised | Host root, secrets, backup keys, or the ability to rewrite the rules |
| A fetched page contains injection | Any change to instructions, permissions or policy; any action at all |
| A secret leaks | Undetected exposure, or no rotation path |
| The VPS is destroyed | Loss of data, or loss of what the system had learned |
| A routine runs away | The host becoming unusable, or an unnoticed outbound flood |
| The user makes a mistake | An irreversible one, without a written way back |

That last row is deliberate. The system defends against the human as well as the model, and a
user should not need to be a security expert to operate it safely.

---

## 3. The four layers, in detail

### 3.1 The container

Non-root, `--cap-drop ALL`, `--security-opt no-new-privileges`, no Docker socket, memory and pid
limits, restart policy. Data and home on host bind mounts; config read-only; bin and secrets not
mounted at all.

**Why limits are a security control and not a tuning knob:** a runaway loop on a 4 GB box takes
down the backup, the cron daemon and the container at once. `CTR.13` checks them on the *running*
container, because a compose file describes an intention and `docker inspect` describes what
happened.

### 3.2 Ownership

`conf/`, `bin/` and `secrets/` are owned by a different uid from the container user, with modes
that deny it write access.

**This is the load-bearing step of the whole design.** If the agent can rewrite `settings.json`
it can delete every deny rule and every hook registration that binds it, and everything else is
decoration. `CTR.2`-`CTR.6` are negative checks run as the container user.

**And they are gated.** Each asks "can the agent do X?" and reads a non-zero exit as proof it
cannot. If the daemon is absent or the container is not running, all of them pass for the wrong
reason and the result is indistinguishable from a system with no boundary at all. So the stage
refuses to report unless it can first prove it can reach the container. This was a real defect
found by running the suite rather than reading it.

### 3.3 Deny rules

Client-enforced, not a prompt. Deny beats allow. A rule matches inside subshells and command
substitution, so they hold against `cd /tmp && curl ...` and `$(curl ...)`. A bare tool name
removes the tool from context entirely, which is stronger than refusing it.

Minimum set: `WebFetch` bare, `Bash(curl *)`, `Bash(wget *)`, `Bash(sudo *)`, `Bash(docker *)`,
`Bash(crontab *)`, and `Read(...)` for the secrets path.

### 3.4 Hooks

Shell commands the CLI runs at fixed lifecycle points. Deterministic, no inference, no tokens.
They are the only mechanism here that can refuse based on **what a file contains or what a
session has already done**, rather than on what something is named.

**The split, and why it matters.** `guard-lib.sh` holds the decisions and `_payload.sh` holds the
parsing. The decisions can be tested exhaustively on any machine and have been: 29 cases covering
path escapes, the taint lifecycle and the lane restriction, each asserting a specific expected
verdict rather than merely "did not crash". The adapter depends on a CLI contract that moves, so
it is small, isolated, and checked by `DRIFT.3`.

**The three rules for anyone editing them:**

1. **Resolve before deciding.** `realpath -m` and then compare. A prefix match on `/data` accepts
   `/data/../conf/settings.json`, and that is the first thing anyone probing this will try. There
   is a fixture for exactly this case.
2. **Fail closed.** If a guard cannot determine the answer, it denies. A guard that allows on
   error can be switched off by breaking it.
3. **The taint marker is per session.** Written to the session's own temp directory on the first
   quarantined read, gone when the session ends. **A marker that persisted between sessions would
   silently disable the weekly review for ever**, because the first research scan would poison
   every session after it. `HK.6` checks the refusal and the fixture checks that a new session
   recovers.

**What the audit hook is for.** A design without hooks has no per-tool-call trail, which means
that after an incident the honest answer to "what did it do?" is "we do not know". `tool-audit`
writes one line per call: time, session, lane, tool, and the target path or command **name**.
Never arguments, never file contents. `HK.9` plants a canary string in a command and fails if it
appears in the log, because this file lives inside the backup and must not become a transcript
archive by accident.

---

## 4. What each layer does not do

| Layer | Does not |
|---|---|
| Container | Stop anything that holds the Anthropic account from acting as the container user |
| Ownership | Stop the agent doing anything it likes inside `data/` |
| Deny rules | Read a file's contents, or leave a trail |
| Hooks | Judge whether text is true, or survive `--bare`, which drops them entirely |
| All four | Help at all if the account has a weak password |

The last row is why `HUMAN-TASKS.md` H8 is where it is.

---

## 5. Subagents: the question, and the answer

A subagent runs in an isolated context and returns only a summary. That is an appealing shape for
the summariser: the quarantined text would never enter the main session's context at all, only a
short result, which narrows both the injection surface and the context cost.

**It is worth doing, and it is not a substitute for the current design.** The isolation is about
context, not privilege: a subagent still runs with tools the parent grants, so the reason the
summariser is safe stays what it is now, which is that it has no network, no Bash, a pinned
working directory and one writable path. A subagent that inherited the parent's tools would be
strictly worse than the separate `claude -p` invocation used today, because it would be harder to
see what it could reach.

So: **if adopted, it is a context improvement layered on top of the existing confinement, never a
replacement for it, and the allowlist checks `QR.3`-`QR.4` must still pass against however it is
invoked.** Treat it as a proposal with a red-first test like anything else.

---

## 6. Claude Code capabilities deliberately not used

Recorded so their absence is a decision rather than an oversight, and so the open scan does not
rediscover them monthly.

| Capability | Why not | What would change it |
|---|---|---|
| MCP servers | In a `-p` session, servers in a `.mcp.json` connect with no trust dialog and no prompt. Every one is a new trust relationship and a new supply chain | A specific need that nothing here can meet, with its own threat model written first |
| `--bare` | Demands an API key, moving spend outside the subscription, and silently drops `CLAUDE.md`, skills and hooks together | Nothing. This one is settled |
| Auto memory | Machine-local notes, never reviewed, shaping behaviour without approval | Nothing. What it remembers, it remembers in files you can read |
| Plugins | Bundles skills, agents, hooks and MCP config into one installable unit. Attractive for reproducibility, and it is also a single object that can carry an MCP server in | Revisit if the rebuild package becomes hard to maintain by hand |
| `/loop`, scheduled tasks | Session-scoped, need an open session, and expire. They cannot schedule an unattended box | Nothing for scheduling. Fine for interactive use |

---

## 7. Two operational rules that are not technology

**Never claim security without verification.** Not "the system is secure" but "the firewall
refuses 22, 80 and 443 from a vantage point outside the tailnet, checked on this date". Every
security claim in this document set points at a check ID or is labelled as unproven, and
`00-PROVEN.md` is the index of which is which.

**Never disable a control to make a task work.** If a control blocks something, determine why,
find a safer route, and if a change is genuinely needed, propose it. "The system is preventing me
from doing this" is never a justification, and a control being inconvenient is not evidence that
it is wrong.
