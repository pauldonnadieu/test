# What changed in this version, and why

This set replaces the previous one. It keeps its structure, its voice and its discipline, and
changes about a quarter of its content.

Three sources fed the review: the original policy documents, the second version with its
folder layout and kill switch, and the third version with its check harness and its honesty
about evidence. The third version was much the best piece of engineering writing of the three,
and the narrowing that made it good also cut several things that were not scope creep.

Recorded here so none of it has to be re-derived in six months.

---

## Corrections: defects in the previous version

These are not additions. They are things that were wrong.

### `conf/` was not backed up

restic covered `/srv/aios/data`. `CLAUDE.md` and the skills live in `/srv/aios/conf` and change
every time a proposal is approved. The rebuild package was supposed to carry them, but nothing
required regenerating it when conf changed and no check tested its freshness.

The consequence: restore six months in and you get every check-in intact and a machine that has
forgotten everything it learned. The architecture calls the instruction files the thing that
actually compounds, and then did not protect them.

**Fixed:** `conf/` is a second path in the backup. `BK.7` proves the snapshot contains it.
`BK.8` proves a file added today appears tonight. `RB.6` fails if the rebuild package is older
than the config it is supposed to be able to recreate.

### Claude Code authentication versus a disposable container

Stage 2 required proving the container could be destroyed and recreated. The subscription
credential lives in the container user's home directory. If that directory is inside the image,
every rebuild needs an interactive login, which cron cannot perform.

The second version had this as an explicit done-criterion and the third dropped it. It is the
likeliest single cause of a first build stalling.

**Fixed:** the home directory is a bind mount. `CTR.11` checks the credential path is
persisted, `CTR.12` checks a non-interactive run succeeds without prompting, and
`HUMAN-TASKS.md` H16 and H17 make the login and the rebuild-without-login an explicit human
step.

### Run records carried model output into the backup

The routine wrapper tailed 2000 characters of model output into `ops/runs/*.jsonl`. That output
can contain anything the session was discussing, `ops/` is inside the backup, and the result is
personal content accumulating for ever in a file nobody thinks of as personal content. The
second version explicitly checked run logs for credentials and document contents and rotated
them at 90 days; the third did neither, and had no retention limit at all.

**Fixed:** run records hold metadata only, including the model actually served and an
`error_class` derived by pattern match. Full output goes to a dated log under `ops/logs/`, mode
0600, deleted after 30 days. `LOG.1` to `LOG.4` check all of it.

### No timezone step

Schedules are specified in local time and stated as "not UTC". A fresh Hetzner box is UTC.
Nothing set the timezone and nothing checked it, so every routine would fire eight to eleven
hours out, silently, with nothing about the behaviour looking like a bug.

**Fixed:** stage 1 sets it, `HOST.10` checks it, and the reboot test checks it survives.

### Check-in coverage was scored as a system fault

`GT.3` failed below ten check-ins in fourteen days and sat in the gating suite. A holiday or a
fortnight of illness therefore turned the suite red. Worse, the improvement loop treats a red
suite as "broken", which unlocks changes outside the measurement window: a bad fortnight in the
user's life would have licensed the system to start changing itself.

**Fixed:** two scores. Health gates; signals are reported and never gate. `GT.*` moved to
signals, and `04-improvement.md` says explicitly that a moving signal is not broken.

### Nothing proved the backup contained what it should

`BK.*` proved a snapshot existed and restored. An excluded path would have backed up nothing,
silently, and no check would have noticed.

**Fixed:** `BK.7` reads the snapshot's file list.

### The `--settings` exception lived in prose

The fetcher legitimately passes `--settings`, and the check for that flag was described as
excluding it: "the fetcher is not one of them". A cold reader cannot apply a rule written that
way, and a second exception could be added without anything noticing.

**Fixed:** `checks/settings-exceptions.txt` holds exactly one entry. `RT.12` fails on a second.

---

## Restored: present in earlier versions, missing from the last one

### Hooks, and the invariant they carried

The second version made "external content is data, never instruction, enforced in hooks rather
than requested in prompts" one of five invariants. The third removed hooks entirely, and was
honest that this weakened the quarantine boundary to reach rather than inspection.

Hooks are deterministic shell commands run by the CLI at lifecycle points. They cost no tokens
and make no model call, which was the objection worth answering. They are the only mechanism in
this design that can refuse an action based on what a file contains rather than what it is
named.

**Restored, narrowly:** four hooks. A halt gate, a write guard with the session-taint rule, a
destructive-command guard, and a tool-call audit log. Eight checks, four of which are behaviour
checks, because a hook that has only been seen to allow proves nothing.

The audit log is a side benefit worth naming: the previous version stated plainly that having
no hooks meant no per-tool-call audit trail. There is one now, and it is what you read first
when something looks wrong.

### The kill switch

The second version had four layers. The third had none: no halt flag, no procedure, and no
written response to the one scenario it named as the widest hole in the design. Nothing in the
set told you how to stop it.

**Restored:** four layers, checked by `KS.1`-`KS.5`, with layer 1 honoured by every cron script
before its lock and by the SessionStart hook. Layer 4, revoking sessions at claude.ai, is the
only response to a suspected account compromise and the only layer that works without the VPS.

### Secret rotation and incident response

Both were in the original documents in detail. Neither survived into the third version, in a
design that names account compromise as its largest residual risk.

**Restored:** `06-recovery-and-incidents.md`, a new document. Rotation in the order that does
not lock you out, with the restic-specific warning that a rotation done wrong destroys your
history. Incident response with the sequence people get backwards: stop before you diagnose.

### Security monitoring, distinct from health checks

The second version asked for failed logins, new accounts, new listening ports and large
outbound transfers. The third checked configuration weekly and never watched behaviour: the
harness proves a port is shut on Sunday, and nothing notices a socket opening on Wednesday.

**Restored:** a nightly deterministic diff, no model, into `ops/security/`. `MON.5`, the
outbound-volume check, is the only thing in the entire design that would notice exfiltration.

### The intake

The second version had an interview stage with a memorable done-criterion: at least one thing
in the result mildly surprises the user. The third reduced goal files to TEMPLATE placeholders
and never specified how they get filled, despite everything downstream reasoning over them.

**Restored as stage 5**, with `IN.1`-`IN.3` for the mechanical part and the human judgements
written down rather than pretended into checks.

### The coaching layer

This is the largest restoration by volume and the most important by value.

The third version kept the five outputs of the weekly review and dropped the self-sabotage
protocol, the bottleneck ladder, goals versus projects versus systems, the five-goal cap,
minimum viable progress, the health-and-family framing, the side-hustle filter and the persona.
It specified the machine carefully and said almost nothing about the work.

**Restored as eight skills**, which is where the architecture already said procedures belong
and where they cost nothing until invoked. The two that matter most:

- `bottleneck`: the twelve-question ladder, stopping at the first question the evidence
  answers, and the instruction not to assemble a comprehensive diagnosis.
- `patterns`: the self-sabotage protocol, including step 5, which asks honestly whether the
  behaviour was rational. That step exists to stop the analysis pathologising sensible
  behaviour, and it should fail the sabotage hypothesis more often than it confirms it.

### Provenance and trust levels

The original memory policy distinguished confirmed, inferred and external, and forbade an
inference silently becoming a fact. The third version reduced this to one binary: quarantined,
or not.

**Restored** in minimal form: four lines of frontmatter on `goals/` and `reference/`, inline
marking for inferences in prose, and `PRV.1`-`PRV.3`. For a system that generates inferences
about someone's motivations constantly, this is the difference between a hypothesis and a
belief the user never agreed to.

### Smaller restorations

`START-HERE.md` and per-directory READMEs. Resource limits with a check behind them rather than
a passing mention. Dependency pinning in the rebuild package. UID matching on the data mount,
flagged in the second version as the most common failure in that stage. The Hetzner rescue
console rehearsed before it is needed. The permanent propose-only cap on money, employer
systems, other people's data and messages sent on the user's behalf, which belongs in a file
that outlives v1 even though v1 has no connection that could do any of it.

---

## New: absent from all three previous versions

### `HUMAN-TASKS.md`

None of the three versions consolidated what only a person can do. The third had a careful
story for the unattended build and no complementary story for the attended one.

Twenty-nine items, in build order, with what each costs and what to click, plus the rule Claude
Code follows when one blocks it: do the rest of the stage, record the block, move on, never
fabricate your way past it.

### Disk management

Absent from all three. Nothing managed the restic cache, JSONL growth, docker logs or raw
quarantine fetches, and nothing checked free space. A full disk stops the backup and cron
simultaneously and looks like nothing at all, and on a 4 GB box it is the most likely mundane
failure of the lot.

`DSK.1`-`DSK.3`, plus a 30-day sweep of raw fetches and 30-day log rotation.

### Runtime drift

Every check and script here depends on CLI flags keeping their names. A renamed flag turns a
working system into one that has been failing quietly since the last update, with the checks
still passing.

`DRIFT.1` parses `claude --help` weekly. `DRIFT.2` records the CLI version and reports a
change, advisory rather than gating.

### Dormancy

Nothing in any version described what happens when the user goes quiet. The system would have
kept producing confident weekly reviews about nothing and kept burning shared usage on them.

Three bands: nothing under a week, thin-evidence warnings from seven days, dormant at
twenty-one. Reversible by one check-in, and never announced by a notification, because a coach
that nags is a coach that gets muted.

### Attestation expiry, surfaced

The check fails on an attestation older than twelve months, which is right, but it would have
fired on a Sunday a year later with no context. The weekly review now names one within thirty
days of its first birthday.

### The quarterly human read

All three versions acknowledged that nothing automated can judge whether `CLAUDE.md` is any
good or whether the reviews are useful. None of them scheduled anyone to look. It is now a
recurring item in `HUMAN-TASKS.md`.

---

## Deliberately parked, not dropped

The previous version silently lost these. They are now in `05-after-v1.md` with explicit
trigger conditions, at the user's decision, because they are more personal data captured more
often and the habit itself has not yet been proven.

**Sleep, and the shape of the day.** The honest cost is stated in that document: the finding
that makes this class of system worth running looks like "all evenings, all office days", and
that inference needs to know when things happened. Without it the reviews will name themes
accurately and be weaker at naming causes. Trigger: two consecutive reviews naming that blind
spot as the limiting factor.

**The daily brief.** The proactive half of the system. Trigger: coverage above twelve of
fourteen for eight weeks, and the user saying unprompted that they wanted to know something in
the morning that the system knew. Both conditions.

---

## Unchanged, and worth saying so

No git. No connections in v1. No local models. No framework. No database server. No inbound
port. Remote Control inside the container. Route by rule, never a model router. The three-way
recovery split. The regression gate, and the rule that a test must be seen to fail before the
change is applied. One adoption a month. A skipped check is a failure.

All of it survives review. The third version got the hard parts right, and this one is an
argument with its omissions rather than with its design.

---

## What this version has not earned

The previous set was read cold by two Claude Code sessions and both found real defects. This
set adds a stage, three documents, eight skills and roughly forty checks, and **nobody has read
it cold**. The two-run result does not transfer.

The new checks have never been executed anywhere. Every one of them is a specification with a
"break it" column, and none should be trusted until it has been watched failing.

`00-READ-ME-FIRST-proven.md` says which is which. Read it before believing any of this.
