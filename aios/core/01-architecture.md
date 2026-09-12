# 01 - Architecture

Read this once, properly. Everything else assumes you have.

Deeper material lives in `reference/`, loaded when the moment needs it. This file is the spine
and it is meant to be held in one session alongside the work.

---

## 1. What the system actually is

A set of files on a VPS, and scheduled processes that read them, talk to the user, and write
more files. That is the whole system. There is no server, no database, no framework, no
orchestrator, no workflow engine, and no agent that runs continuously.

The interesting part is not the machinery. It is that the files contain the truth about what
the user did, that something reliably looks at them once a week and says one useful thing, and
that it also looks forward and prepares what is coming.

### The two loops

```
  BACKWARD, the coach                     FORWARD, the chief of staff
  ------------------------                ----------------------------
  daily check-in, under a minute          what is approaching
       |                                       |
       v                                       v
  daily/check-ins.jsonl                   prepare it before it arrives
  ground truth, dated, unrevised          assemble the case for a decision
       |                                  notice what has gone quiet
       v                                       |
  weekly review: ONE bottleneck,               v
  the evidence, constraint vs             handed over already done,
  self-sabotage, the smallest             not handed back as a question
  intervention they would do
       |                                       |
       +------------------+--------------------+
                          v
                    the user decides
```

The backward loop is the one that must never break, because every judgement the forward loop
makes rests on knowing what actually happened rather than what was planned.

### Why the check-in is the foundation and not a feature

A plan is a claim about the future made by someone who is optimistic and under-informed about
their own week. A check-in is a report from the person who lived it. A system that has only
plans can tell you that you are behind; it cannot tell you why, because it has no record of
what displaced the work.

The consequence is architectural: if check-ins stop, the weekly review must stop claiming to
know things. Coverage is tracked (`GT.3`) and the review names its own thin evidence when
coverage is low. A review built on four data points that presents itself with the same
confidence as one built on fourteen is worse than no review.

**Coverage is a signal, not a system fault.** Section 10 says why those are scored separately.

---

## 2. What compounds, and what does not

**The model does not learn.** Each Claude Code session begins with a fresh context window.
Anthropic's documentation is explicit: "Each new session starts with a fresh context window,
without the conversation history from previous sessions." Nothing worked out on Tuesday is
available on Wednesday except through a file.

This is not a limitation to engineer around with a memory layer. It is the property the design
is built on:

- **Files compound.** Goals, check-ins, reviews, decisions, the improvement ledger.
- **The model does not.** It is a capable stranger, every morning, reading your notes.

Every "it learns your patterns over time" claim in this class of product is either a description
of files being read back, or false. Here it is files being read back, and the documents say so.

Three consequences that are easy to miss:

- **Auto memory is off** (`RT.5`). Claude Code can write its own notes between sessions. Those
  notes live outside the data mount, are machine-local, are never reviewed, and shape future
  behaviour without approval. That is a small unauthorised authority.
- **Instruction files are the product.** `CLAUDE.md` and the skills are where accumulated
  understanding actually lives. They are also what an improvement loop changes, which is why
  changing them is propose-then-approve and not act-then-report.
- **Therefore they are irreplaceable, and they are backed up.** `conf/` goes into the encrypted
  snapshots alongside `data/`, and `BK.7` proves the snapshot contains both. It is tempting to
  treat config as part of the rebuildable environment. It is not: it holds months of approved
  improvement, and restoring without it returns a machine that has forgotten everything it
  learned.

---

## 3. Trust boundaries

**Every boundary is designed assuming the one in front of it already failed.**

```
  the internet
    |   no inbound port. Nothing listens. Tailscale dials out.
    v
  the host (Ubuntu)
    |   the container user is not root and owns none of the config
    v
  the container (one, non-root, disposable)
    |   data on a host bind mount; config mounted read-only
    v
  Claude Code
    |   deny rules, four hooks, per-invocation tool allowlists
    v
  two quarantined lanes
        untrusted-external/  anything from outside
        utility/             the free-tier lane. See reference/R2.
```

| Boundary fails | You lose |
|---|---|
| Container compromised | The container and the data mount. Rebuild it; secrets were never in it |
| Host compromised | The data on the host. Backups survive, encrypted with a key the host does not hold in usable form at rest |
| Google Drive compromised | Nothing readable. Encryption happens before upload |
| Free-tier provider compromised | Your shopping list. Not your goals, check-ins or reviews |
| Anthropic account compromised | An interactive session on the container and the data mount, and the transcripts. The widest one |
| Backup key lost | Every snapshot, permanently. Hence the offline copy |

### Four enforcement layers, all deterministic

Nothing that guards this system depends on the model choosing well, and none of it costs a
token.

1. **The container.** Non-root, `no-new-privileges`, capabilities dropped, no Docker socket,
   memory and pid limits, data on a bind mount (`CTR.1`, `CTR.7`-`CTR.14`).
2. **Filesystem ownership.** `settings.json`, `CLAUDE.md`, the hooks, the skills and the cron
   scripts are owned by a different uid and mounted read-only. *If the agent can rewrite its own
   deny rules or its own hooks, both are decoration.* Checks `CTR.2`-`CTR.6` run **as the
   container user**, and the stage refuses to report at all if it cannot reach the container,
   because a negative check that cannot run is not a pass.
3. **`permissions.deny` rules.** Client-enforced, not a prompt. Deny beats allow, a rule matches
   inside subshells and command substitution, and a bare tool name removes the tool from context
   entirely (`RT.2`, `RT.3`).
4. **Four hooks.** Shell commands the CLI runs at fixed lifecycle points. Detail in
   `reference/R1-security.md`; the summary is below.

| Hook | Point | Refuses |
|---|---|---|
| `halt-gate` | SessionStart | Everything, while `ops/.halt` exists |
| `write-guard` | PreToolUse: Write, Edit, Read | Anything outside the data mount, including `../` escapes. Trusted-tree writes in a session that has read quarantine. Anything outside its lane, for the utility lane |
| `danger-guard` | PreToolUse: Bash | `rm -rf`, `restic forget`/`prune`, `docker`, `crontab`, `chmod`/`chown` on config, anything naming the secrets path |
| `tool-audit` | PostToolUse, all | Nothing. Appends one line per call: names and verdicts, never payloads |

The write-guard carries the invariant that matters: **external content is data, never
instruction**, enforced rather than requested. The decision logic lives in `conf/hooks/guard-lib.sh`
separately from the payload adapter, because the logic can be tested exhaustively anywhere and
the adapter depends on a CLI contract that moves. Both halves are checked (`HK.*`, `DRIFT.3`).

**Hooks do not replace ownership.** Ownership is what makes them unreachable; the hooks are what
make ownership content-aware. Neither is sufficient alone.

### Permission prompts are not a control

A prompt asks whoever holds the session to approve. Whoever holds the account answers it. In
unattended cron runs nobody is there at all, which is why those runs pass
`--permission-prompts none`: anything that would prompt is denied and the run continues rather
than hanging. The interactive session runs in **default** mode, never `bypassPermissions`
(`RT.12`), but that is a convenience for the user, not a boundary against someone holding the
account. What bounds that session is the container it runs in and the hooks it cannot edit.

---

## 4. Data

### Files, JSONL, and nothing else

- **Files** for anything a human reads.
- **JSONL, append-only,** for event streams: check-ins, run records, ledgers, the audit log,
  security observations. A corrupted write damages one line, and `DATA.4` parses every line of
  every `.jsonl`, because a review reasoning over corruption is worse than one that did not run.
- **SQLite only where volume demands it.** Nothing in v1 does.
- **No database server.** Nothing needs concurrent writers, and a server is another process to
  secure, patch, back up and break.

### Structure

Everything derives from `AIOS_ROOT`, which is `/srv/aios` here. Change it in `checks/config.env`
and the `AIOS_ROOT=` line of each cron script; nothing else cares about the absolute path.

Under `$AIOS_ROOT/data`:

```
goals/               what the user is trying to do, one file per area
daily/               check-ins.jsonl, the ground truth
review/              weekly reviews and the evidence each cited
reference/           everything filed out of conversation
untrusted-external/  anything that came from outside. Quarantine.
utility/             to-do, shopping, scratch. The free-tier lane, and nothing else.
ops/                 run records, ledgers, scores, audit log, security, proposals
```

Seven directories against a budget of seven (`DATA.1`). The budget exists because this must stay
readable by a tired human on a phone over SSH at 11pm. Exceeding it needs an argument written
down, not a drift. `START-HERE.md` at the root describes the lot in one screen and is
regenerated when anything moves (`DATA.5`); every directory carries a one-line README (`DATA.6`).

Three rules that keep it navigable for years:

- **Anything from outside gets a name that cannot be mistaken for something safe.**
  `untrusted-external/`, not `inbox/`, not `research/`. Someone skim-reading a path at speed must
  not misread it.
- **Files are never versioned by filename** (`DATA.3`). No `-v2`, no `-final`, no `.bak`.
  Snapshots do that job better, and filename versioning is how a clean structure rots into an
  archaeological dig.
- **Dates sort naturally.** `2026-09-11`, `2026-W37`. Never `11-09-26`.

### Provenance: what it knows versus what it guessed

Every file under `goals/` and `reference/` carries four lines of frontmatter:

```yaml
---
trust: confirmed | inferred | external
source: intake-2026-09-11 | conversation-2026-09-14 | untrusted-external/2026-09-14-slug
created: 2026-09-11
review_after: 2027-03-11   # optional, for claims that go stale
---
```

Checked by `PRV.1`-`PRV.3`. This is three lines of overhead and it is not bureaucracy. A coach
generates inferences constantly, and an inference is exactly the kind of thing that hardens into
a stored fact and gets cited back as evidence eighteen months later. "You avoid the gym because
you are afraid of failing at it" is a hypothesis. Unmarked, it becomes something the system
believes about someone who never agreed to it.

**`inferred` never silently becomes `confirmed`.** Promotion needs the user to say so and is a
propose-then-wait action. In prose, mark only what carries risk; confirmed facts stay unmarked,
because markers everywhere become wallpaper.

### The gap where git would have been

No git: the config, skills and instruction files are personal enough to count as personal data,
git is another system to secure and leak from, and snapshots already give point-in-time
recovery. **This remains the decision I am least comfortable with**, because the improvement loop
needs to answer "what changed three weeks ago, and did it cause the difference I am measuring?"

The substitute, which adds no new system: a **change ledger**. Nightly, `sha256sum` over the tree
plus `conf/`, diffed against the previous manifest, one JSONL record per changed file with the
path, timestamp and both hashes (`bin/change-ledger.sh`, `RUN.7`). It tells you *that* a file
changed and points you at the snapshot to diff against. That is what the measurement window
needs. It is not version control and the documents do not pretend it is.

---

## 5. Untrusted content, and the two lanes

**Prompt injection fires at summarisation, not at fetch.** Fetching a page is inert. The danger
begins when a model reads the text with authority to act or to be believed.

Published guidance has not solved this. The framing that has held up best, the "lethal trifecta"
of private data, untrusted content and a way to communicate out, describes a combination to
avoid rather than a defence to deploy. So the design avoids the combination rather than claiming
to detect attacks.

**The quarantine lane.** `fetch-untrusted.sh` holds exactly one dangerous capability: it reaches
the internet and cannot see your data. `summarise-untrusted.sh` holds the other: it reads what
came back and has no network and no Bash. Neither ever holds both, and neither is ever the
routine that touches `goals/` or `daily/`. The summary inherits the taint (`trust: external`),
stays in `untrusted-external/`, and `QR.8` fails if anything carrying the marker appears in the
trusted tree. The write-guard refuses the write that would put it there.

**The utility lane.** Free-tier models from other providers do low-stakes work so the Pro
subscription is spent where judgement is needed. The boundary is structural, not a judgement
about sensitivity, because sensitivity is a property of sentences rather than files: a check-in
mentioning the mortgage is financial, personal, and sits in `daily/`. Any rule requiring a
per-request decision will eventually decide wrong, silently, into a provider that trains on it.

So the lane reaches exactly two directories, `utility/` and `untrusted-external/`, and nothing
else exists to it. The router runs **on the host**, so the container never holds the credential.
Checked by `FT.1`-`FT.6`. Full treatment in `reference/R2-privacy-routing.md`, including the
honest note that a to-do list is still a portrait of a life over time.

**The limit, stated exactly.** A summariser can still be induced to write a misleading summary.
What it cannot do is act on the instruction, reach the network, touch anything outside its
folder, or have its output written into the trusted tree by the session that read it. The first
three are true because of where it runs. The fourth is true because of a hook. **None is true
because anything inspected the meaning of the text, and nothing here does.**

---

## 6. The Anthropic account is part of the perimeter

Remote Control is how the user gets a phone interface for free, and it is the widest hole in the
design. Both are true.

**How it works** (vendor-documented): the local session makes outbound HTTPS requests only and
never opens an inbound port. The phone talks to Anthropic; Anthropic routes to the VPS.
Execution and filesystem access stay on the VPS.

**Two costs, plainly:**

1. **Transcripts are stored on Anthropic servers while connected.** On a consumer Pro account
   the retention is **30 days with the "use my data to improve Claude" setting off, and 5 years
   with it on.** The single highest-leverage setting in the build, account-side, so no check on
   the box can see it. Recorded as a dated attestation; an absent or year-old one fails stage 0.
2. **The account is a path to the VPS.** Running Remote Control **inside the container** is what
   contains it, and the containment only holds if `CTR.2`-`CTR.6` pass.

Be precise about what that costs on the worst realistic day: someone holding the account gets an
interactive session as the container user, with Bash, against every file under `data/`. They do
not reach the host, the secrets, the backup repository, the config or the free-tier credential,
and `tool-audit` records what they did. **That is containment, not safety.**

The mitigations the user controls: a strong unique password and a hardware-backed second factor,
and knowing that kill-switch layer 4 revokes every session from claude.ai without needing the
VPS. Those matter more than everything in stage 1. See `reference/R3-recovery.md`.

---

## 7. Claude Pro is a hard constraint

The subscription authorises Claude Code, including non-interactive `claude -p` runs. **There is
no Anthropic API key anywhere in this build** (`RT.8`), and adding one would move spend outside
the subscription.

**Do not build a model router.** A process that calls APIs to pick a model bills per token. The
`--model` flag on the invocation is the routing mechanism and the rule lives in the script.

Three facts that shape the design:

- **Pro's default model is Sonnet.** The routing table is built around Sonnet as the workhorse,
  not Opus.
- **Usage limits are shared** across claude.ai, Desktop and Claude Code, on rolling five-hour and
  weekly windows. A heavy afternoon on the phone can starve the night's cron run, so runs fail
  loudly and leave a record rather than skipping silently (`RUN.1`-`RUN.5`).
- **Never `--bare`** (`RT.7`). It skips OAuth, demands an API key, and silently drops every
  instruction file, skill **and hook** at the same time.

`--model sonnet` is an alias resolved by the CLI, and what it resolves to changes. The run record
stores the model actually served (`LOG.3`), so a silent change is visible. The CLI itself moves
too: `DRIFT.1` parses `claude --help` weekly and fails if a flag the scripts pass has vanished,
because otherwise a rename turns a working system into one that has been failing quietly since
the last update.

Routing, escalation and cost efficiency: `reference/R2-privacy-routing.md`.

---

## 8. The runtime instruction file

`CLAUDE.md` loads into every session and competes with the actual work. Target **under 120
lines**; `RT.6` fails at 200, and the gap is deliberate headroom.

It holds only what must be true in **every** session: who the user is in one paragraph, the
autonomy rules, where things go, the escalation rule, the provenance rule, and the one line
saying the system does not learn between sessions and must read the files.

It holds **no procedures**. A procedure that runs sometimes belongs in a skill, which loads on
demand and costs nothing until invoked. It holds **no content the model can derive** by reading
the directory it is sitting in. If it grows past budget, move a section into a skill; never raise
the budget.

---

## 9. Skills are where the work lives

The container and the checks are not the product. The product is whether the weekly review is any
good and whether the preparation is any use, and that lives in `skills/`.

| Skill | What it holds |
|---|---|
| `check-in` | The daily questions and the recording format |
| `weekly-review` | The five backward outputs and the forward section |
| `bottleneck` | The diagnostic ladder: stop at the first question the evidence answers |
| `patterns` | The self-sabotage protocol, including the step that asks whether it was rational |
| `goals` | Goal discipline, the five-goal cap, minimum viable progress, the side-hustle filter |
| `prepare` | Something is coming: assemble what it needs before it arrives |
| `decide` | Build the case for a decision, and recommend |
| `horizon` | What is approaching, what has gone quiet, what is about to be forgotten |
| `file-this` | Filing without asking, with provenance |
| `audit` | The weekly backward look at the system's own performance |
| `research-scan` | The outward look, through the quarantine lane |

Progressive disclosure keeps this cheap: a skill costs roughly fifty tokens of metadata until
invoked. Fewer and sharper beats more, because routing quality degrades with skill count.
Retiring one that has not fired in ninety days is a proposal like any other.

---

## 10. Two scores, and going quiet

The harness answers two different questions and they must not share a number.

**Health** gates: firewall, container, backups, cron, hooks, disk, logs. Every failure here is
the system's fault. This is the score recorded weekly and compared by the regression gate.

**Signals** never gate: check-in coverage, intervention follow-through. `run-all.sh --signals`
prints them separately. A fortnight of illness is not a system failure, and scoring it as one has
two bad effects: the suite goes red for a reason nobody can fix, and a red suite means "broken"
in `04-improvement.md`, which unlocks changes outside the measurement window.

**Dormancy.** If the user stops, the system must not keep producing confident reviews about
nothing or keep burning shared usage on them.

| Days since the last check-in | What happens |
|---|---|
| 0-6 | Nothing. A missed day is not a signal |
| 7-20 | The review runs, opens by naming its own thin evidence, makes weaker claims |
| 21+ | Dormant. Check-in prompt and review stop. Backup, ledger, monitoring and health keep running. One line is written and shown at the next session |

Reversible by doing one check-in, never announced by a notification. A coach that nags is a coach
that gets muted, and the data those three weeks would have produced would have been fiction.

---

## 11. Honest limits

1. **It does not learn.** Files compound; the model does not.
2. **Hooks enforce reach and provenance, not meaning.** Nothing inspects whether a summary is
   true.
3. **Prompt injection is unsolved.** The design avoids the dangerous combination; it does not
   detect attacks.
4. **Deletion is four-sided.** Live data goes. Derived mentions are **listed, not assumed
   absent**. Snapshots keep what the live system forgets until they age out. Anything said in a
   Remote Control session reached Anthropic's servers. **If something must never reach a backup,
   it must never be written at all.**
5. **The Anthropic account is a path to the data mount.** Contained, not eliminated.
6. **Free tiers train on what they receive.** The utility lane confines that to a shopping list,
   and a shopping list is still a portrait of a life.
7. **The improvement loop measures weakly.** One user, no control group, life events that dwarf
   any intervention.
8. **Usage limits can starve it.** Visible, not prevented.
9. **The harness proves properties, not safety.** See `02-build.md` section 15.
10. **Backups depend on one key.** Lose the password manager and the offline copy and every
    snapshot is permanently unreadable. Working as designed.

---

## 12. What it may never do

It may improve its methods. It may never improve its own authority.

Off-limits from inside the container, structurally and not by instruction: `settings.json`, the
deny rules, the hooks, `CLAUDE.md`, the skills, the cron scripts, the crontab, the backup
configuration, the halt flag directory, the free-tier credential, and anything under the secrets
path. Those live on read-only mounts owned by another uid. Proposals go to `ops/proposals/` and
are applied by the user from the host.

Permanently capped at propose-only, regardless of track record: anything touching money,
employer systems, other people's data, or anything sent on the user's behalf. v1 has no
connection that could do any of it. The rule is here because the file outlives v1, and the first
connection will arrive on a day when the rule is inconvenient.

**A system that can widen its own permissions has no permissions.**
