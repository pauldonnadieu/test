# 01 - Architecture and reasoning

Read this once, properly. Everything in `02-build.md` assumes you have.

---

## 1. What the system actually is

A set of files on a VPS, and a scheduled process that reads them, talks to the user, and
writes more files. That is the whole system. There is no server, no database, no framework,
no orchestrator, no workflow engine, and no agent that runs continuously.

The interesting part is not the machinery. It is that the files contain the truth about what
the user did, and that something reliably looks at them once a week and says one useful thing.

### The loop

```
  daily     the user answers three or four questions in under a minute
    |       the answers are appended, never edited
    v
  ground    daily/check-ins.jsonl, what actually happened, dated, unrevised
  truth
    |
    v
  weekly    read the week, name ONE bottleneck, show the evidence for it,
  review    distinguish constraint from self-sabotage, propose the smallest
    |       intervention the user would actually do
    v
  the user decides
```

Everything else in this document exists to keep that loop running for years without the user
maintaining it.

### Why the check-in is the foundation and not a feature

A plan is a claim about the future made by someone who is optimistic and under-informed about
their own week. A check-in is a report from the person who lived it. A system that has only
plans can tell you that you are behind; it cannot tell you why, because it has no record of
what displaced the work.

The consequence is architectural: if check-ins stop, the weekly review must stop claiming to
know things. Check-in coverage is a first-class property, tracked by `GT.3`, and the review
names its own thin evidence when coverage is low. A review built on four data points that
presents itself with the same confidence as one built on fourteen is worse than no review.

**Coverage is a signal, not a system fault.** See section 11 for why those are scored
separately, and what the system does when the user goes quiet.

---

## 2. What compounds, and what does not

**The model does not learn.** Each Claude Code session begins with a fresh context window.
Anthropic's own documentation is explicit: "Each new session starts with a fresh context
window, without the conversation history from previous sessions." Nothing the model works out
on Tuesday is available to it on Wednesday except through a file.

This is not a limitation to be engineered around with a memory layer. It is the property the
design is built on:

- **Files compound.** Goals, check-ins, reviews, decisions, the improvement ledger.
- **The model does not.** It is a capable stranger, every morning, reading your notes.

Every "it will learn your patterns over time" claim in this class of product is either a
description of files being read back, or false. Here it is files being read back, and the
documents say so.

Three consequences that are easy to miss:

- **Auto memory is off.** Claude Code can write its own notes between sessions. Those notes
  live outside the data mount, are machine-local, are never reviewed, and shape future
  behaviour without approval. That is a small unauthorised authority, so it is disabled
  (`RT.5`). What the system remembers, it remembers in files the user can read.
- **Instruction files are the product.** `CLAUDE.md` and the skills are where accumulated
  understanding actually lives. They are also the thing an improvement loop changes, which is
  why changing them is a propose-then-approve action and not an act-then-report one.
- **Therefore the instruction files are irreplaceable, and must be backed up.** They live
  under `conf/`, outside the data mount, on a read-only bind mount. It is tempting to treat
  them as part of the rebuildable environment. They are not: they hold months of approved
  improvement, they contain no secrets, and they go into the encrypted snapshots alongside the
  data. `BK.7` proves the snapshot actually contains them. Losing them means restoring a
  machine that no longer knows anything it had learned.

---

## 3. Trust boundaries

The rule: **every boundary is designed assuming the one in front of it already failed.**

```
  the internet
    |   no inbound port. Nothing is listening. Tailscale dials out.
    v
  the host (Ubuntu)
    |   the container user is not root, owns none of the config
    v
  the container (one, non-root, disposable)
    |   personal data on a host bind mount; config mounted read-only
    v
  Claude Code
    |   permissions.deny rules; hooks; explicit tool allowlists per invocation
    v
  quarantine (untrusted-external/)
        anything from outside. Summarised with no tools and no network.
```

What each boundary costs when it fails:

| Boundary fails | You lose |
|---|---|
| Container compromised | The container. Rebuild it. Data survives on the host mount, secrets were never in it |
| Host compromised | The data on the host. Backups survive; they are encrypted with a key the host does not hold in usable form at rest |
| Google Drive compromised | Nothing readable. Encryption happens before upload |
| Anthropic account compromised | The container and the data mount, via Remote Control, and the transcripts. This is the widest one. See section 6 |
| Backup key lost | Every backup, permanently. Hence the offline copy |

### The enforcement layer, stated exactly

Four mechanisms hold the boundaries, and every one of them is deterministic. None depends on
the model reasoning correctly, and none costs a token:

1. **The container.** Non-root, `no-new-privileges`, all capabilities dropped, no Docker
   socket, memory and pid limits, data on a bind mount (`CTR.1`, `CTR.7`-`CTR.10`).
2. **Filesystem ownership.** `settings.json`, `CLAUDE.md`, the hooks, the skills and the cron
   scripts are owned by a different uid and mounted read-only. This one matters more than it
   looks: *if the agent can rewrite its own deny rules, the deny rules are decoration.* Checks
   `CTR.2` through `CTR.6` are negative checks run **as the container user**, because a check
   run as root tests a world the agent does not live in.
3. **`permissions.deny` rules.** Client-enforced, not a prompt. Deny beats allow, a rule
   matches inside subshells and command substitution, and a bare tool name removes the tool
   from context entirely. These are verified to exist (`RT.2`, `RT.3`) rather than assumed.
4. **Hooks.** Shell commands the CLI runs at fixed lifecycle points. See section 3.1.

Plus **per-invocation tool allowlists**: each cron script names exactly the tools its job
needs, and the summariser gets the fewest.

**The fetcher is the one deliberate exception, and it is quarantined by construction.** The
deny rules in `conf/settings.json` remove `WebFetch` and `Bash(curl *)` from every routine that
touches personal data, which is all of them but one. The weekly research scan has to reach the
internet, so `fetch-untrusted.sh` runs with its **own** settings file,
`conf/settings-fetch.json`, which allows `WebFetch` and nothing else: no Read of the data
mount, no Write outside the quarantine folder, no Bash. It fetches to `untrusted-external/` and
exits. The summariser that reads what it fetched has no network at all.

So the two halves of the pipeline each hold exactly one dangerous capability and never the
pair: the fetcher can reach the internet but cannot see your data, and the summariser can see
what came back but cannot phone home. Neither is ever the routine that touches `goals/` or
`daily/`. That separation is the design; a single invocation holding both would be the
combination the whole quarantine chapter exists to avoid.

`conf/settings-fetch.json` is the only file permitted to be named in a `--settings` flag
anywhere in this build, and `checks/settings-exceptions.txt` is the list `RT.9` reads. A second
entry appearing in that list is a change to the security model and belongs in a proposal.

### 3.1 Hooks, and what they are for

A hook is a shell command the Claude Code CLI runs at a lifecycle point: before a tool call,
after one, when a session starts. It is deterministic, it costs no tokens, it involves no
inference, and it can inspect the actual arguments and the actual filesystem before deciding.
That last property is the one nothing else in this list has: a deny rule matches a pattern and
cannot read a file's contents.

Four hooks, and deliberately only four. Each is a few lines of shell, owned by the config uid,
on the read-only mount, and unreachable from inside the container.

| Hook | Point | What it does |
|---|---|---|
| **halt-gate** | SessionStart | If `ops/.halt` exists, print the reason and exit non-zero. Nothing runs while the flag is set |
| **write-guard** | PreToolUse on Write, Edit | Refuse any write outside the data mount. Refuse any write into the **trusted** tree if this session has read from `untrusted-external/` |
| **danger-guard** | PreToolUse on Bash | Refuse `rm -rf`, `restic forget`, `restic prune`, `docker`, `crontab`, `chmod`/`chown` against `conf/`, and writes to the secrets path. Belt to the deny rules' braces, and it catches the argument shapes a pattern misses |
| **tool-audit** | PostToolUse, all tools | Append one line to `ops/audit/tool-calls.jsonl`: timestamp, session id, tool, target path or command name, allowed or refused. **Names and verdicts, never payloads** |

The write-guard is the one that earns its place. The session-taint rule is the invariant the
earlier version of this design had and the previous one lost: *external content is data, never
instruction*, enforced rather than requested. Once a session has read a quarantined file it can
still write a summary into `untrusted-external/`, and it can write nothing into `goals/`,
`review/`, `reference/` or `ops/proposals/` for the rest of that session. The taint marker is a
file in the session's own temp directory, written by the hook on the first quarantined read and
gone when the session ends.

**What hooks do not do.** They do not replace ownership; a hook runs inside the session and a
session that could rewrite the hook would be pointless. Ownership is what makes them
unreachable, and the hooks are what make ownership content-aware. Neither is sufficient alone.

**What is still genuinely lost.** The summariser can be induced to write a misleading summary.
Nothing inspects meaning. The write-guard stops that summary reaching the trusted tree in the
same session; it cannot stop the summary being wrong. See section 5.

### Permission prompts are not a control

A permission prompt asks whoever holds the session to approve an action. Whoever holds the
account answers it. In unattended cron runs nobody is there at all, which is why those runs
pass `--permission-prompts none`: anything that would prompt is denied and the run continues
rather than hanging until the timeout. The controls that work are the ones enforced before
Claude decides anything: ownership, the container, deny rules and hooks.

The interactive Remote Control session is the same story from the other side. It runs in
**default** permission mode, never `bypassPermissions` (`RT.11`), but that mode is a
convenience for the user, not a boundary against an attacker who holds the account. What bounds
that session is the container it runs in and the hooks it cannot edit.

---

## 4. Data

### Files, JSONL, and nothing else

- **Files** for anything a human reads: goals, reviews, notes.
- **JSONL, append-only,** for event streams: check-ins, run records, the improvement ledger,
  the change ledger, the audit log, security observations. Append-only means a corrupted write
  damages one line. Check `DATA.4` parses every line of every `.jsonl`, because a review
  reasoning over corruption is worse than a review that did not run.
- **SQLite only where volume demands it.** Nothing in v1 does. If something later does, that
  is a change with a trigger condition, and it belongs in `05-after-v1.md`.
- **No database server.** Nothing here needs concurrent writers, and a server is another
  process to secure, patch, back up and break.

### Structure

**The root is one variable.** Everything derives from `AIOS_ROOT`, which is `/srv/aios` on the
VPS this is written for. If it must live elsewhere, change it in exactly two places:
`checks/config.env` and the `AIOS_ROOT=` line at the top of each cron script. Nothing else in
the design cares about the absolute path. Documents below write `/srv/aios` for readability;
read it as `$AIOS_ROOT` every time.

Grouped by what things are **to the user**, not to the machine. Under `$AIOS_ROOT/data`:

```
goals/               what the user is trying to do, one file per area
daily/               check-ins.jsonl, the ground truth
review/              weekly reviews and the evidence each one cited
reference/           everything filed out of conversation
untrusted-external/  anything that came from outside. Quarantine.
ops/                 run records, change ledger, check scores, improvement ledger,
                     audit log, security observations, proposals, attestations
```

Plus `START-HERE.md` at the root of the data mount: one screen explaining what everything is,
regenerated whenever the structure changes, because a map that has drifted from the territory
is worse than no map (`DATA.5`). Every directory carries a one-line `README.md` saying what is
in it and what puts things there.

**Six directories against a budget of seven.** The budget exists because this must stay
readable by a tired human on a phone over SSH at 11pm. Exceeding it needs an argument written
down, not a drift. Check `DATA.1` enforces it.

Three rules that keep it navigable for years:

- **Anything from outside gets a name that cannot be mistaken for something safe.**
  `untrusted-external/`, not `inbox/`, not `research/`, not `sources/`. Someone skim-reading a
  path at speed must not misread it.
- **Files are never versioned by filename.** No `-v2`, no `-final`, no `.bak`. Snapshots do
  that job and do it better. Check `DATA.3` enforces it, because filename versioning is how a
  clean structure rots into an archaeological dig.
- **Dates sort naturally.** `2026-09-11`, `2026-W37`, `2026-09`. Never `11-09-26`.

### Provenance: what the system knows versus what it guessed

Every file under `goals/` and `reference/` carries four lines of frontmatter:

```yaml
---
trust: confirmed | inferred | external
source: intake-2026-09-11 | conversation-2026-09-14 | untrusted-external/2026-09-14-slug
created: 2026-09-11
review_after: 2027-03-11   # optional, for claims that go stale
---
```

`PRV.1` fails on a file missing it. `PRV.2` fails if anything under `untrusted-external/`
carries `trust: confirmed`. `PRV.3` reports files past their `review_after` date.

This is three lines of overhead and it is not bureaucracy. A coach that reasons about someone's
life generates inferences constantly, and an inference is exactly the kind of thing that hardens
into a stored fact and then gets cited back as evidence eighteen months later. "You avoid the
gym because you are afraid of failing at it" is a hypothesis. Written without a marker it
becomes something the system believes about the user, and the user never agreed to it.

**`inferred` never silently becomes `confirmed`.** Promotion needs the user to say so, and the
change ledger records it. `external` never becomes confirmed on the strength of its source
alone.

In prose, mark only what carries risk. Confirmed facts are unmarked, because markers everywhere
become wallpaper and stop being read:

> Your evening sessions are failing on office days. *(inferred from 3 weeks of check-ins)*
>
> You want to be out of the current role within two years.

### The gap where git would have been, and what fills it

The decision to use no git is right for the reasons given: the config, skills and instruction
files are personal enough to be personal data, git is another system to secure and leak from,
and snapshots already give point-in-time recovery.

**But it costs something real, and this is the one settled decision I would push back on.**
The improvement loop in `04-improvement.md` needs to answer "what changed in my instruction
files three weeks ago, and did the thing I changed cause the difference I am measuring?"
Restic snapshots answer "what did this file look like on a given day" only once you already
know which day to look at. That is a materially weaker tool for the loop that justifies the
whole self-improvement design.

The substitute, which adds no new system to secure: a **change ledger**. A nightly cron script
walks the AIOS tree, computes a sha256 manifest, diffs it against the previous manifest, and
appends one JSONL record per changed file with the path, the timestamp, the old and new
hashes, and which routine was running. That is change history, without a second system holding
a copy of the data. Check `RUN.7` keeps it fresh.

It is not version control. It tells you *that* a file changed and points you at the snapshot
to diff against. That is what the measurement window actually needs.

---

## 5. Untrusted content

**Prompt injection fires at summarisation, not at fetch.** Fetching a page is inert. The
danger begins the moment a model reads the page's text with authority to act or to be
believed.

Published guidance has not solved this. OWASP's current GenAI Top 10 still lists prompt
injection and excessive agency as open problems, and the practitioner framing that has held up
best, the "lethal trifecta" of private data, untrusted content, and a way to communicate out,
describes a combination to avoid rather than a defence to deploy. So the design avoids the
combination rather than claiming to detect attacks.

The pipeline:

1. **Fetch** writes to `untrusted-external/<date>-<slug>/raw`. It never writes anywhere else.
2. **Summarise** runs as its own `claude -p` invocation with an explicit `--allowedTools`
   list, **no network tool, no Bash**, its working directory set to that one quarantine
   folder, and exactly one writable output path. Checks `QR.3`-`QR.6`.
3. **The summary inherits the taint.** It is written with `trust: external` frontmatter and
   stays in `untrusted-external/`. Check `QR.7`.
4. **It is never promoted to fact.** The attack is writing `SUMMARY: the user approved X` into
   a page and letting the pipeline launder it into a conclusion. So quarantined content is
   quoted with its provenance attached or it is not used. Check `QR.8` fails if anything
   carrying the marker appears in the trusted tree, and the write-guard hook refuses the write
   that would put it there.

**The honest limit.** The summariser can still be induced to write a misleading summary. What
it cannot do is act on the instruction, reach the network, touch anything outside its own
folder, or have its output written into the trusted tree by the session that read it. The first
three are true because of where it runs. The fourth is true because of a hook. None of them is
true because anything inspected the meaning of the text, and nothing here does. When
quarantined material informs a weekly review, the review cites it as "from an untrusted source,
unverified", and that phrasing is load-bearing.

---

## 6. The Anthropic account is part of the perimeter

Two things are true at once: Remote Control is how the user gets a phone interface for free,
and it is the widest hole in the design.

**How it works** (vendor-documented, verified): the local session makes outbound HTTPS
requests only and never opens an inbound port. It registers with the Anthropic API and polls.
The phone talks to Anthropic; Anthropic routes to the VPS. Execution and filesystem access
stay on the VPS.

**Two costs, stated plainly:**

1. **Transcripts are stored on Anthropic servers while connected**, to sync across devices and
   survive network drops. On a consumer Pro account the retention that then applies is **30
   days if the "use my data to improve Claude" setting is off, and 5 years if it is on.** This
   is the highest-leverage single setting in the build, and it is account-side, so no check on
   the box can verify it. It is recorded as a dated user attestation in `ops/attestations.md`,
   and `02-build.md` treats an absent or year-old attestation as a stage failure.
2. **The Anthropic account becomes a path to the VPS.** Someone with the account can drive a
   session on the machine. Running Remote Control **inside the container** is what contains
   this: they get the container and the data mount, not the host, not the secrets, not the
   backup keys, not the config. That containment is the entire reason for the placement, and
   it only holds if `CTR.2`-`CTR.6` pass.

Be precise about what "they get the data mount" means, because it is the worst realistic day
this design has. Someone holding the account gets an interactive session as the container user,
with Bash, against every file under `data/`: the goals, every check-in, every review, every
filed note. They cannot reach the host, the secrets, the backup repository or the config, and
the tool-audit log records what they did. That is containment, not safety.

The mitigations the user controls: a strong unique password and a hardware-backed second factor
on the Anthropic account, and knowing that layer 4 of the kill switch in
`06-recovery-and-incidents.md` revokes every session from claude.ai without needing the VPS.
Those two things matter more to this system's security than everything in stage 1.

---

## 7. Claude Pro is not an API key

The subscription authorises Claude Code, including non-interactive `claude -p` runs. There is
no API key anywhere in this build, and adding one would move spend outside the subscription.

**Do not design a model router.** A process that calls APIs directly to pick a model bills per
token. Route by rule, in code: the `--model` flag on the cron invocation is the routing
mechanism, and the rule lives in the script. See `03-operations.md` section 3 for the routing
table and the escalation triggers.

Three verified facts that shape this:

- **Pro's default model is Sonnet 5.** (Opus 5 is the Max default.) The routing table is built
  around Sonnet as the workhorse, not Opus.
- **Usage limits are shared** across claude.ai, Claude Desktop and Claude Code, on a rolling
  five-hour window and a weekly window. A heavy afternoon on the phone can starve the night's
  cron run. Runs must therefore fail loudly and leave a record, never skip silently. The
  freshness checks `RUN.1`-`RUN.3` exist precisely because a starved run and a quiet week look
  identical otherwise.
- **Never `--bare`.** Bare mode looks attractive for cron: it skips auto-discovery of hooks,
  skills, plugins, MCP and `CLAUDE.md` for reproducibility. But it also **never reads OAuth
  credentials** and requires `ANTHROPIC_API_KEY`. Using it would break the subscription model
  and silently drop every instruction file and every hook at the same time. Check `RT.7`
  refuses it.

**Model names are aliases.** `--model sonnet` resolves at the CLI, and what it resolves to
changes over time. The run record stores the model actually served, so a silent change is
visible rather than invisible (`LOG.3`).

**The CLI itself moves.** Every check and every script here depends on flags keeping their
current names. `DRIFT.1` parses `claude --help` weekly and fails if a flag the scripts pass has
vanished. Without it, a renamed flag turns a working system into a system that has been failing
quietly since the last update.

I could not verify Claude Pro's exact numeric usage limits (Anthropic's support site was
unreachable from the build environment). The design does not depend on the numbers: it depends
on a starved run being visible, which is checked.

---

## 8. The runtime instruction file

`CLAUDE.md` loads into every session and competes for context with the actual work. Anthropic's
guidance is to target under 200 lines, and that files over that length reduce adherence.

**The contract:**

- Target **under 120 lines**. Check `RT.6` fails at 200. The gap is deliberate headroom.
- It holds only what must be true in **every** session: who the user is in one paragraph, the
  autonomy rules, where things go, the escalation rule, the provenance rule, and the one-line
  statement that the system does not learn between sessions and must read the files.
- It holds **no procedures**. A procedure that runs sometimes belongs in a skill, which loads
  on demand and costs nothing until invoked. "Run the weekly review" is a skill. "File things
  without asking" is a CLAUDE.md rule.
- It holds **no content the model can derive** by reading the directory it is sitting in.

If it grows past the budget, the fix is moving a section into a skill, never raising the
budget. `conf/CLAUDE.md.template` in this set is a starting point that fits.

---

## 9. Skills are where the work lives

The container and the checks are not the product. The product is whether the weekly review is
any good, and that lives in `skills/`.

| Skill | What it holds |
|---|---|
| `check-in` | The daily questions and the recording format |
| `weekly-review` | The five outputs, in order, and the rules about evidence |
| `bottleneck` | The diagnostic ladder: twelve questions, stop at the first that explains the evidence |
| `patterns` | The self-sabotage protocol, including the step that asks whether the behaviour is rational |
| `goals` | Goal discipline, the five-goal cap, minimum viable progress, the side-hustle filter |
| `file-this` | Filing without asking, and the provenance rules |
| `audit` | The weekly backwards look at the system's own performance |
| `research-scan` | The outward look, through the quarantine pipeline |

Progressive disclosure keeps this cheap: a skill costs roughly fifty tokens of metadata until
it is invoked. Fewer and sharper still beats more, because routing quality degrades with
skill count. Retiring a skill that has not fired in ninety days is a proposal like any other.

---

## 10. Honest limits

Kept together so they cannot be lost in the prose.

1. **It does not learn.** Files compound; the model does not. Session-to-session improvement
   is a file being read back.
2. **Hooks enforce reach and shape, not meaning.** They can refuse a write based on what a
   session has touched. Nothing inspects whether a summary is true. The quarantine boundary is
   about reach and provenance, not detection.
3. **Prompt injection is unsolved.** The design avoids the dangerous combination; it does not
   detect attacks. A summary can be misleading. It cannot act, and it cannot reach the trusted
   tree in the session that read it.
4. **Deletion is four-sided.** Live data can be removed on request. Derived mentions need a
   pass to find, and should be **listed, not assumed absent**. Backup snapshots keep what the
   live system forgets until they age out. And anything said in a Remote Control session
   reached Anthropic's servers. The rule that follows: **if something must never reach a
   backup, it must never be written at all.**
5. **The Anthropic account is a path to the data mount.** Contained to the container, not
   eliminated, and the data mount is the part that matters to the user.
6. **The improvement loop measures weakly.** One user, no control group, a window of weeks,
   and life events that dwarf any intervention. Without a measured baseline, assessment is
   opinion. With one, it is a weak signal honestly labelled.
7. **Usage limits can starve it.** Shared with the user's own Claude usage. Visible, not
   prevented.
8. **The check harness proves properties, not safety.** See `02-build.md` section 14 for the
   specific ways this system could pass every check and still be unsafe.
9. **Backups depend on one key.** Lose the password manager and the offline copy and every
   snapshot is permanently unreadable. This is a feature working as designed.
10. **Roughly half the checks in this version have never been run.** See
    `00-READ-ME-FIRST-proven.md`.

---

## 11. Two scores, and what happens when the user goes quiet

The check harness answers two different questions and they must not share a number.

**Health.** Is the machine doing what it was built to do? Firewall, container, backups, cron,
hooks, disk. Every one of these is the system's fault when it fails. This is the score that
gates, the score recorded weekly in `ops/check-scores.jsonl`, and the score the regression gate
compares.

**Signals.** Is the user still using it? Check-in coverage, intervention follow-through. These
are reported, never gating. A fortnight of illness is not a system failure, and scoring it as
one has two bad effects: the suite goes red for a reason nobody can fix, and under
`04-improvement.md` a red suite means "broken", which unlocks changes outside the measurement
window. `run-all.sh --signals` prints them separately and `GT.*` lives in that set.

**Dormancy.** If the user stops, the system must not keep producing confident weekly reviews
about nothing, and must not keep burning shared usage on them.

| Days since the last check-in | What happens |
|---|---|
| 0-6 | Nothing. A missed day is not a signal |
| 7-20 | The weekly review runs, opens by naming its own thin evidence, and makes weaker claims |
| 21+ | Dormant. The check-in prompt and the weekly review stop. Backup, change ledger, security monitoring and the health suite keep running. One line is written to `ops/` and shown at the next session: what stopped, and that a single check-in restarts it |

Dormancy is reversible by doing one check-in, and it is never announced by a notification,
because a coach that nags is a coach that gets muted. The system going quiet when the user does
is the honest behaviour, and the data it would have generated in those three weeks would have
been fiction anyway.

---

## 12. What it may never do

It may improve its methods. It may never improve its own authority.

Off-limits from inside the container, structurally and not by instruction: editing
`settings.json`, the deny rules, the hooks, `CLAUDE.md`, the skills, the cron scripts, the
crontab, the backup configuration, the kill-switch flag directory, or anything under the
secrets path. Those live on read-only mounts owned by another uid. Proposals to change them are
written to `ops/proposals/` and applied by the user from the host.

Permanently capped at propose-only, even after any amount of track record: anything touching
money, employer systems, other people's data, or anything that sends a message on the user's
behalf. There are no connections in v1 that could do any of this, and the rule is written here
anyway, because the file outlives v1 and the first connection will arrive on a day when the
rule is inconvenient.

A system that can widen its own permissions has no permissions.
