# What is proven, and what is not

Read this before trusting anything else in this set.

**The harness has been tested hard. The system has never existed.** Those are different
statements and conflating them is the failure this document exists to prevent. A reader who takes
a green sandbox run as an acceptance test has been misled by the packaging.

---

## The rule everything here follows

**A check that has only ever been seen to pass proves nothing.** Every entry in the first table
was deliberately broken and observed to catch it. Everything in the last table is a
specification, and specifications are claims.

---

## Tier 1: proven, both ways, in this environment

127 assertions across five suites. Each was run against a correct case **and** a deliberately
broken one, and each asserts a specific expected verdict rather than merely "did not crash".

| Suite | What it proves | Result |
|---|---|---|
| `run-all.sh --self-test` | The runner scores a pass, a fail, a **SKIP as a failure**, a crashed check as MISSING, and a deleted check as MISSING. An empty run exits non-zero. A failing signal does not gate health | 3/3, and confirmed to go red when `skip` was sabotaged to score as a pass |
| `fixtures/hooks-test.sh` | The hook decision logic: the data-mount boundary including two `../` escape shapes, the quarantine taint rule, the taint marker expiring with the session, and the utility lane in both directions | **29/29** |
| `fixtures/hook-adapters-test.sh` | Payload parsing, the block verdict, the halt reason being quoted, and the audit log recording names while a planted canary string in a command does **not** appear in it | **15/15** |
| `fixtures/sabotage-test.sh` | Every check testable without a VPS, each against a specific sabotage | **75/75 caught** |
| `compare-scores.sh` | The regression gate: no change, a fix, a break, a **deleted failing check** (2/3 reading as 2/2), and a newly added check | **5/5** |

The sabotage suite covers structure, provenance, runtime configuration, all four hooks, the
free-tier lane, run-record hygiene, routine freshness, the kill switch including **the halt check
being moved after the lock**, monitoring, quarantine, attestations, intake and the rebuild
package.

### Three real defects found by running rather than reading

Recorded because they are the argument for writing the harness before the prose.

1. **The container checks passed for the wrong reason.** Every negative check in stage 2 reads a
   non-zero exit as proof the agent cannot do something. With no Docker daemon, `docker exec`
   itself fails, so all of them passed on a machine with no container at all. The result was
   indistinguishable from a system with no boundary. The stage now refuses to report unless it
   can first prove it can reach the container.
2. **The regression gate missed the case it exists for.** It caught a *passing* check that
   vanished, but the cheat being described is deleting a check that was already *failing*, so the
   score reads 2/3 to 2/2. It now treats any vanished ID as a regression, whatever its previous
   verdict.
3. **Two kill-switch checks were wrong.** One demanded an inline halt check from scripts that
   correctly delegate to `run_routine`; it now verifies the ordering inside the library instead.
   The other leaked the real `AIOS_DATA` into its own fixture and so tested nothing.

---

## Tier 2: what a full suite run looks like here, and why it is not green

```
HEALTH 91/133   skip:20 missing:0
signals 2/3
```

Nothing is MISSING, which is the important part: every check in the manifest ran. The 42 that do
not pass are the ones that need a real machine: no firewall, no Tailscale, no Docker daemon, no
restic repository, no cron, no Remote Control. Twenty report SKIP, which the runner scores as a
failure, **correctly**, because nobody has proven those properties.

This is what an honest score looks like in a sandbox, and a set that reported green here would be
lying to you.

---

## Tier 3: never run anywhere

| What | Why not | Where it becomes provable |
|---|---|---|
| **Stage 1** `HOST.1`-`HOST.10`, `DSK.*` | No firewall, no Tailscale. `HOST.1`-`HOST.3` need a vantage point outside the machine, which no sandbox provides | On the VPS, `test/VPS-ACCEPTANCE.md` part 1 |
| **Stage 2** `CTR.1`-`CTR.14` | No Docker daemon. The *uid* half of the boundary is proven by the hook fixtures; the container half is not | Part 2 |
| **OAuth persistence** `CTR.11`, `CTR.12` | Needs a real subscription login and a real rebuild. **The likeliest single cause of a stalled first build** | Part 2, and `HUMAN-TASKS.md` H16-H17 |
| **Backup** `BK.1`-`BK.8` | No restic repository and no Drive backend. The *logic* is exercised by the rebuild-package sabotages; the repository behaviour is not | Stage 6, then part 6 |
| **Reboot, cron, Remote Control** `RB0.*`, `CRON.*`, `RC.1` | None of it exists in a sandbox | Parts 4 and 5 |
| **The recovery drill** | Needs a second machine and a real rehearsal | Part 6 |
| **The free-tier provider call** | The *confinement* is proven (`FT.1`-`FT.6`); the provider call itself has never been made | Stage 10, on the real box |
| **The hook payload adapter** | The decision logic is proven exhaustively. The parsing depends on a CLI contract that was not verified against a live installation | Stage 3. Verify against the installed CLI's hook documentation |
| **The six attestations** | Account-side. No check on any machine can verify them, only that somebody wrote them down and when | Never. Permanently a human statement |

---

## Tier 4: the documents themselves

**Nobody has read this version cold.** An earlier version of this document set was given to two
cold Claude Code sessions with no conversation history and no ability to ask questions; both
built from it and both found real defects, including one that would have made the harness
impossible to pass on any machine. **That result does not transfer.** This version has a
different structure, three new skills, five new reference documents and a harness that did not
previously exist.

`test/E2E-PROCEDURE.md` is how that gets fixed, and it is now a sharper test than it was: the
harness already exists, so the cold reader is being asked to configure and satisfy it rather than
write it, and a stall is therefore almost certainly a writing defect.

**Run it twice before the real build.** Two runs separate "the documents are ambiguous" from
"that run went oddly".

---

## The honest summary

The **harness** has been tested hard: 127 assertions, every one of them watched failing on
purpose before being trusted to pass, and three real defects found in the process.

The **documents** have not been read by a stranger.

The **system** has never existed. Stage 1, the container, the backup destination, cron, Remote
Control and recovery are specifications for checks, not results from them.

A green run in a sandbox means the documents can be followed and the harness works. It does not
mean the machine is safe. Only `test/VPS-ACCEPTANCE.md`, run on the real box, can say that.
