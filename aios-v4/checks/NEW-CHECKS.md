# New checks

Every check added in this version, with what it proves and **how to break it**.

The previous version's checks carry over unchanged and are already in `expected-ids.txt`.
Everything below has to be added to that manifest, or the manifest check will report the suite
as incomplete, which is the manifest working.

## The rule that governs this file

**A check that has only ever been seen to pass proves nothing.** Every entry below has a "break
it" column, and none of these checks should be trusted until it has been observed failing on
the broken case. This is the same discipline that found the five defects in the previous
version, and it is the only reason any of the old checks are believed.

None of the checks below has been run anywhere. See `00-READ-ME-FIRST-proven.md`.

## Scoring

Health checks gate. Signal checks do not. `run-all.sh` prints and scores them separately, and
`GT.*` moves into the signals set in this version. A fortnight of low check-in coverage is
information about the user's life and must not turn the health suite red, both because it is
not a fault and because a red suite unlocks the change budget in `04-improvement.md`.

---

## Stage 1: host

| ID | Proves | Break it by |
|---|---|---|
| `HOST.10` | The host timezone is the user's configured value, not UTC | Set the box to UTC while `AIOS_TZ` says otherwise |
| `DSK.1` | Free disk is above 20% and above 2 GB | `fallocate` a large file and re-run |
| `DSK.2` | Docker logging is capped: a `max-size` and `max-file` are set on the running container | Recreate the container with the default json-file driver and no limits |
| `DSK.3` | The restic cache directory is below its configured ceiling | Set the ceiling to 1 MB and re-run |

`HOST.10` reads the timezone from `config.env` and compares with `timedatectl`. Without it,
every schedule in `03-operations.md` fires at the wrong hour on a box nobody has told, and
nothing about the resulting behaviour looks like a bug.

---

## Stage 2: container

| ID | Proves | Break it by |
|---|---|---|
| `CTR.11` | The Claude Code credential path is on a bind mount, not the container filesystem | Move the home directory back into the image and re-run |
| `CTR.12` | A non-interactive `claude -p` succeeds without prompting for authentication | Remove the credential from the mounted home and re-run |
| `CTR.13` | Memory and pid limits are in force on the **running** container | Recreate it without `--memory` and `--pids-limit` |

`CTR.12` is the one that matters. It is the difference between a container that is disposable
and one that is disposable once, and it is the check most likely to catch a real problem on a
first build.

Run `CTR.11` by reading the container's mount table, not the compose file. A compose file
describes an intention; the mount table describes what happened.

---

## Stage 3: runtime, hooks and drift

| ID | Proves | Break it by |
|---|---|---|
| `HK.1` | All four hooks exist at the expected paths | Delete one |
| `HK.2` | All four are registered in `settings.json` at the right lifecycle points | Remove a registration, leaving the file in place |
| `HK.3` | None is writable by the container user | `chmod 666` one and re-run as the container user |
| `HK.4` | **halt-gate refuses** when the flag exists | Create the flag, start a session, expect a non-zero exit |
| `HK.5` | **write-guard refuses** a write outside `/data`, including via `../` | Attempt a write to `/conf/settings.json` and to `/data/../conf/settings.json` |
| `HK.6` | **write-guard refuses** a trusted-tree write after a quarantined read | In one session, read from `untrusted-external/`, then attempt a write to `review/` |
| `HK.7` | **danger-guard refuses** each of its named commands | Attempt `rm -rf`, `restic forget`, `docker ps`, `crontab -l` |
| `HK.8` | tool-audit is appending, and contains **no payloads** | Run a session, then grep the audit log for the content of a file that was read |
| `RT.11` | The Remote Control invocation uses default permission mode | Add `--permission-mode bypassPermissions` and re-run |
| `RT.12` | Every `--settings` use is listed in `settings-exceptions.txt` | Add a second script passing `--settings` |
| `DRIFT.1` | Every flag the scripts pass still appears in `claude --help` | Add `--nonexistent-flag` to a script |
| `DRIFT.2` | The CLI version is recorded, and a change since last week is reported | Edit the recorded version and re-run |

`HK.4` through `HK.7` are the important ones, and they are behaviour checks rather than
configuration checks. A hook that is present, registered and broken fails open, which is the
exact failure the hooks were added to prevent. **Do not accept "the hook exists" as evidence
that the hook works.**

`HK.5` must include the `../` case explicitly. A naive prefix match on `/data` accepts
`/data/../conf/settings.json`, and that is the bug an attacker would find first. Resolve with
`realpath` before comparing.

`HK.6` needs the taint marker to be per-session. Check that a **new** session can write to
`review/` normally: if the marker persists, the first research scan disables writing for ever
and the system quietly stops producing reviews.

`DRIFT.2` is advisory rather than gating: a CLI version change is not a failure, it is a
prompt to read the release notes before the next scan.

---

## Stage 4: structure and provenance

| ID | Proves | Break it by |
|---|---|---|
| `DATA.5` | `START-HERE.md` exists and names exactly the directories that exist | Create a directory without regenerating it |
| `PRV.1` | Every file under `goals/` and `reference/` has valid provenance frontmatter | Add a file with none |
| `PRV.2` | Nothing under `untrusted-external/` carries `trust: confirmed` | Set one and re-run |
| `PRV.3` | Files past their `review_after` date are reported | Backdate one |

`PRV.3` reports rather than fails. A stale claim is a thing to look at, not a broken machine.

---

## Stage 5: intake

| ID | Proves | Break it by |
|---|---|---|
| `IN.1` | No file under `goals/` still carries the `TEMPLATE` marker | Restore a template |
| `IN.2` | Five or fewer goals are `active` | Mark a sixth active |
| `IN.3` | Every active goal has a next action and a stated capacity | Remove one |

These three are the mechanical part of stage 5. The part that matters, whether the picture is
specific enough to be worth reasoning over, is a human judgement and is written in
`02-build.md` stage 5 rather than pretended into a check.

---

## Stage 6: backup coverage

| ID | Proves | Break it by |
|---|---|---|
| `BK.7` | The latest snapshot's file list contains every top-level `data/` directory **and every file in `conf/`** | Add an exclude for `conf/` and take a new snapshot |
| `BK.8` | A file added to `conf/` today appears in tonight's snapshot | Add one and check before the run, expecting failure |
| `BK.9` | The snapshot count is bounded by the retention policy | Disable `forget` for a fortnight |
| `RB.6` | Nothing in `conf/` or the Dockerfile is newer than the rebuild package's last build | Edit a skill and re-run |

`BK.7` is the correction this version exists for as much as any other. The previous version
backed up `data/` only, which meant a restore returned a machine with every check-in intact and
no memory of anything it had learned. Losing months of approved instruction-file improvement is
a silent, total loss of the thing `01-architecture.md` section 2 calls the actual product.

`RB.6` catches the other half of the same problem: a current restore onto a year-old
environment.

---

## Stage 7: quarantine retention

| ID | Proves | Break it by |
|---|---|---|
| `QR.9` | No raw fetch under `untrusted-external/*/raw` is older than 30 days | Backdate one |

---

## Stage 8: run records and logs

| ID | Proves | Break it by |
|---|---|---|
| `LOG.1` | **No run record contains model output.** Records carry metadata fields only | Add an `output` field with prose and re-run |
| `LOG.2` | Nothing under `ops/` matches a secret shape: `sk-`, `-----BEGIN`, `password=`, a long base64 run | Plant an `sk-` string in a log |
| `LOG.3` | Every run record names the model actually served | Remove the field |
| `LOG.4` | No log under `ops/logs/` is older than 30 days | Backdate one |

`LOG.1` is a correction, not an addition. The previous version's wrapper tailed 2000 characters
of model output into a file that lives inside the backup, which meant conversation content
accumulating for ever somewhere nobody thought of as holding conversation content. Keep the
diagnostic value where it is useful, in a dated log with a 30-day life, and keep the permanent
record to metadata.

`LOG.2` uses broad patterns deliberately. A false positive costs a minute; a false negative
puts a credential in an artefact that gets backed up for twelve months.

---

## Stage 9: kill switch and monitoring

| ID | Proves | Break it by |
|---|---|---|
| `KS.1` | Every cron script checks the halt flag **before** its lock and before any work | Remove the line from one script |
| `KS.2` | With the flag set, a scheduled routine exits without running | Set it and invoke a routine directly |
| `KS.3` | With the flag set, a session refuses to start | Set it and run `claude -p` |
| `KS.4` | The flag file records a reason | Create an empty flag |
| `KS.5` | The four layers are documented somewhere off the machine, as an attestation | Remove the attestation line |
| `MON.1` | The nightly observation script ran within 36 hours | Disable it for two nights |
| `MON.2` | A new listening socket is reported in `alerts.md` | `nc -l` on a loopback port overnight, or simulate against a fixture |
| `MON.3` | A new local user is reported | `useradd` a test user |
| `MON.4` | A changed `authorized_keys` is reported | Append a comment line |
| `MON.5` | Outbound bytes well above the recent norm are reported | Feed the check a fixture with a tenfold jump |

`KS.1` matters more than it reads. A halt check after the lock, or after the work has begun, is
a halt check that does not halt the run you are trying to stop.

`MON.2` to `MON.5` are diffs against yesterday, not thresholds. They should be built and tested
against fixtures first, because waiting overnight to find out whether a check works is how
checks end up untested.

**`MON.5` is the only thing in the entire design that would notice exfiltration**, whether from
a runaway fetcher or a session someone else is driving. It is worth getting right even though
it is the noisiest of the five.

---

## Manifest and totals

Add every ID above to `checks/expected-ids.txt`. The manifest check exists so that a quietly
deleted check reads as `FAIL MANIFEST` rather than as a higher score, and adding checks without
adding IDs defeats it from the other direction.

Note that this version adds roughly forty checks at once, which is well outside the +3 per
quarter budget in `04-improvement.md` section 5d. That budget governs the **running** system,
where check growth is drift. A version change that closes known gaps is a different act, and
the budget applies again from the next green baseline.
