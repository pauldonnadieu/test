# What is proven, and what is not

Read this before trusting anything else in this set.

**Roughly half of the checks in this version have never been run anywhere, and they include
the ones carrying the most security weight.** That is not a defect in the work; it is a
consequence of writing the documents before the machine exists, compounded by this version
adding a block of new checks that no one has yet executed. It is stated first because a reader
who takes a green sandbox run as an acceptance test has been misled by the packaging.

## How the three tiers differ

| Tier | Meaning |
|---|---|
| **Proven** | Observed passing on a correct case **and** failing on a deliberately broken one |
| **Carried forward** | Proven in the previous version of this set, unchanged here |
| **Never run** | Specified only. No evidence of any kind |

A check that has only ever been seen to pass proves nothing. That is the whole reason for the
distinction.

## Carried forward: proven in the previous version, unchanged

| What | How it was proven |
|---|---|
| **The runner** (`run-all.sh`) | Fixtures: a passing check, a failing one, a skipping one, and one that dies before printing anything. Confirms a SKIP scores as a failure, a crashed check scores as a failure, and an empty run exits non-zero |
| **The manifest** (`expected-ids.txt`) | A check removed from the suite is reported as `FAIL MANIFEST` rather than quietly raising the score |
| **Stage 3** runtime config | Correct fixture passes; removing a deny rule, oversizing `CLAUDE.md`, and adding `--bare` each caught |
| **Stage 4** structure | Correct fixture passes; a `notes-v2.bak` and a corrupted JSONL line each caught |
| **Stage 6** backup | Against a **real restic repository**: init, backup, forget/prune, `check --read-data-subset`, restore. Then broken three ways: live file diverged from the snapshot, canary planted in plaintext in the repo, an `sk-` key placed in the rebuild package. All three caught |
| **Stage 7** quarantine | Correct fixture passes; granting the summariser network access, granting it Bash, an untagged summary, and quarantined content laundered into the trusted tree all caught |
| **Stage 8** routines | The cron `PATH` check caught a script calling `docker` with no `PATH` set |
| **The uid boundary** (`CTR.2`-`CTR.6` logic) | With a **real second unix user**: root-owned mode 644 refuses the write; `chmod 666` is caught. The write probe leaves the file byte-identical, verified |
| **The regression gate** (`compare-scores.sh`) | Four scenarios, including a check *deleted* to hide a failure, where the score reads 2/3 -> 2/2 and looks like nothing happened |
| **The e2e scorer** (`score-e2e.sh`) | Positive control, negative control with six planted sabotages, and a no-build control |
| **The docs lint** (`lint-docs.sh`) | Found three real problems on its first run: a check cited but absent from the manifest, a stale stage count, and a `CLAUDE.md` budget that disagreed with the config |

## Carried forward: the documents survived a cold reader

**Two cold Claude Code sessions**, each given only the previous version of these documents and
told to build, with no conversation history and no ability to ask questions. Both passed: nine
traps clean, six structure checks clean, no violations. 22 and 16 minutes; $6.23 and $4.63.

They found five real defects, all since fixed:

1. **`run-all.sh` sourced `config.env` without exporting it**, so every check subprocess saw
   none of the configuration and reported SKIP regardless of how carefully the file was filled
   in. The suite could never have gone green on any machine.
2. **The change ledger was assigned a model** in the routing table while the architecture
   described it as pure sha256 diffing. Some routines now explicitly use no model at all.
3. **The global deny rules made the weekly research scan impossible.** The fetcher now runs
   under its own settings file holding exactly one dangerous capability, and the summariser
   holds the other; neither holds both.
4. **`CTR.2`-`CTR.4` passed host paths to `docker exec`**, testing paths that do not exist
   inside the container.
5. **`CTR.10` hardcoded `/data`** rather than reading the configured mount point.

**That cold-reader result does not transfer to this version.** These documents have changed
substantially: a new stage, a new document, eight skills, and roughly forty new checks. Nobody
has read this version cold. `test/E2E-PROCEDURE.md` is how you fix that, and it should be run
before the real build, not after.

## Never run: new in this version

Everything below is specified and nothing below has been executed. The specifications are in
`checks/NEW-CHECKS.md`, each with the way to break it so that it can be proven rather than
assumed.

| What | Why it is here | Evidence status |
|---|---|---|
| **Hooks** `HK.1`-`HK.8` | Restores content-dependent enforcement and a per-tool-call audit trail | None. Write them, break them, then trust them |
| **Kill switch** `KS.1`-`KS.5` | The previous version had no way to stop the system | None |
| **Security monitoring** `MON.1`-`MON.5` | Configuration was checked weekly; behaviour was never watched | None |
| **Disk** `DSK.1`-`DSK.3` | A full disk kills backups and cron at once, silently | None |
| **Log hygiene** `LOG.1`-`LOG.4` | The previous version tailed model output into a backed-up file | None |
| **Provenance** `PRV.1`-`PRV.3` | Stops an inference becoming a stored fact | None |
| **Intake** `IN.1`-`IN.3` | The stage everything downstream reasons over had no stage | None |
| **Runtime drift** `DRIFT.1`-`DRIFT.2` | The checks trust CLI flags that can be renamed underneath them | None |
| **Backup coverage** `BK.7`-`BK.9` | Nothing proved the snapshot contained the paths that matter | None |
| **Auth persistence** `CTR.11`-`CTR.12` | A disposable container that needs an interactive login is not disposable | None |
| **Timezone** `HOST.10` | A fresh box is UTC and every schedule here is local time | None |

## Never run: and cannot be, here

| What | Why not | When it can be |
|---|---|---|
| **All of stage 1** `HOST.1`-`HOST.10` | No firewall, no Tailscale in a sandbox. `HOST.1`-`HOST.3` need a vantage point outside the machine | On the VPS, per `test/VPS-ACCEPTANCE.md` part 1 |
| **Container flags** `CTR.1`, `CTR.7`-`CTR.13` | No Docker daemon in a sandbox. The *uid* half of stage 2 is proven; the container half is not | On the VPS, part 2 |
| **All of stage 11** | Reboot persistence, cron genuinely firing, Remote Control placement, the Google Drive backend | On the VPS, parts 3, 4 and the Drive setup |
| **The recovery drill** | Needs a second machine and a real disaster rehearsal | On the VPS, part 5 |
| **The five attestations** | Account-side. No check on any machine can verify them, only that somebody wrote them down and when | Never. Permanently a human statement |

## The honest summary

The **tooling carried forward** has been tested hard: every part of the old harness has been
seen to fail on purpose before being trusted to pass.

The **tooling added in this version** has not been tested at all. Treat every check in the
"never run" table as a claim, not a result, until you have broken it yourself.

The **documents** were read by two strangers, but they read a different version of them.

The **system itself** has never existed.

A green run in a sandbox means the documents can be followed and the harness works. It does
not mean the machine is safe. Only `test/VPS-ACCEPTANCE.md`, run on the real box, can say that.
