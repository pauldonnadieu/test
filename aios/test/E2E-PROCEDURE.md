# End-to-end dry run

## What this tests

Not the scripts. **The documents.**

These documents exist to be handed to a cold Claude Code session on a fresh box. Until one
actually is, their only reader has been their author, who cannot fall into the gaps because he
knows what they say. This procedure supplies the stranger.

Every place the cold reader guesses, stalls, invents a path, or falls into a trap the documents
explicitly warn about is a **writing defect**. The output is a defect list, not a grade.

**This version has not been read cold.** The previous one was, twice, and both runs found real
defects. This version restructured the whole set into a spine plus seven reference documents,
added three skills and a free-tier lane, and replaced a specification of the harness with a
working one, so that result does not transfer. Run this before the real build, not after.

## What the session is given, and denied

**Given:** a clean directory containing `aios/` (the documents, `core/`, `reference/`, `skills/`,
`conf/`, `bin/` and `checks/`) and `brief.md`. Nothing else.

**Note what is different about this version.** The harness already exists and is already proven
against fixtures. The cold reader is not being asked to write it, only to configure it, run it,
and build a system that passes it. That makes this a much sharper test of the documents than it
was before: a stalled build is now almost certainly a writing defect rather than a missing script.

**Denied:**

- Conversation history. It is a separate process with an empty context window.
- The ability to ask. `--permission-prompts none` removes `AskUserQuestion`, so ambiguity must
  go to `ASSUMPTIONS.md`, where it can be counted. An agent that can ask produces a clean build
  and hides the defect.
- Hints. `brief.md` says what to build and where the docs are. It does not explain the design.

**Not used: `--bare`.** It looks right for a reproducible test, but it demands
`ANTHROPIC_API_KEY` and strips `CLAUDE.md`, skills and hooks, which is both the trap the docs
warn about and the removal of the thing under test.

**Stage 5 cannot run here.** The intake needs a person. Expect it recorded as blocked in
`ops/blocked.md`, and treat a run that fabricates a life instead as a serious failure rather
than as initiative.

## Sandbox substitutions

| Real system | Stand-in here | Coverage |
|---|---|---|
| Container, non-root user | A **real unix user** `aios`, real chown/chmod | **Genuine.** The privilege boundary is real, so the load-bearing half of stage 2 is truly tested |
| Container flags (cap-drop, no-new-privs, socket, limits) | none | **UNTESTABLE** |
| OAuth persistence across a rebuild | none | **UNTESTABLE**. This is the likeliest real-world failure and the sandbox cannot see it |
| Hetzner firewall, UFW, Tailscale | none | **UNTESTABLE**, all of stage 1 |
| Hooks | **Genuine.** Hooks are CLI-level and run here | The behaviour checks `HK.4`-`HK.9` are real in this sandbox |
| restic to Google Drive | restic to a local directory repo | Encryption, retention, coverage and the restore drill genuine; Drive throttling not |
| cron | scripts invoked directly, once | Script correctness genuine; scheduling not. The halt check is genuine |
| Security observations | Genuine against fixtures, not against a real week | Partial |
| Remote Control, phone | none | **UNTESTABLE** |

**No simulated passes.** Untestable properties print `UNTESTABLE` and are never counted as
passes. A faked firewall green would be believed, which is worse than no result at all.

Note that the hooks are genuinely testable here, which makes this dry run considerably more
valuable than it was for the previous version. The enforcement layer added in this version can
be proven in a sandbox; the container flags underneath it still cannot.

## Running it

**`run-e2e.sh` is not shipped and has to be written.** It is thirty lines of orchestration and
it is deliberately not in the set, because it belongs to whoever is running the test rather than
to the system under test. What it must do:

1. Create a disposable machine or container, a real unix user `aios`, and `/srv/aios`.
2. Copy in `aios/` and `brief.md`, and nothing else.
3. Spawn a cold `claude -p` session with `--permission-prompts none` and the brief, twice.
4. Capture the artefacts listed below into `test/results/<timestamp>-run<n>/`.
5. Detect a usage-limit error in the transcript and write `STARVED.txt` if it finds one.
6. Run `checks/score-e2e.sh` against each built tree.

Root is required: it creates the `aios` user and writes `/srv/aios`. Both are disposable.

The `aios` user matters more than it looks: `score-e2e.sh` reports its most important trap as a
SKIP without one, because the agent-uid write test has to become that user to mean anything.

### Two runs, not one

Agent behaviour varies between runs. One sample cannot separate "the documents are ambiguous"
from "that run went oddly".

- A defect in **both** runs is a documentation defect. Fix the document.
- A defect in **one** run is probably variance. Note it, act later if it recurs.

### Do not edit the documents mid-run

The point is to observe a cold reader failing. Patching the document the moment it stumbles
destroys the sample and produces a document that has been tuned to one run.

## Reading a result

Results land in `test/results/<timestamp>-run<n>/`:

| File | What it tells you |
|---|---|
| `score.txt` | The verdict and the defect list. Start here |
| `ASSUMPTIONS.md` | **The most valuable artefact.** Each line is a place the docs under-specified |
| `SUBSTITUTIONS.md` | What it could not do here, and what it did instead |
| `blocked.md` | What it could not do because a human was needed. Stage 5 should be here |
| `HANDOVER.md` | What it believed it finished |
| `tree.txt` | What it actually built |
| `session.json` | Full transcript, plus cost |
| `STARVED.txt` | Present only if a usage limit interrupted the run |

### A starved run is not a failed run

Claude Pro's limits are shared with the user's own Claude usage. A run that hits one looks
exactly like a build that stopped halfway. `run-e2e.sh` detects the limit error and writes
`STARVED.txt`. **Discard that run and re-run later.** Scoring a starved run as a documentation
defect teaches precisely the wrong lesson.

## Acting on the output

1. Read `ASSUMPTIONS.md` first. Each entry names the document that should have answered it.
2. For each trap violation, ask why the warning did not land. The answer is usually that the
   warning is in a document the reader had no reason to open at that moment, which is a
   placement problem more often than a wording one.
3. Read `blocked.md` and check that everything in it is genuinely a human task, and that
   nothing was invented instead.
4. Fix the documents. Re-run. The defect count should fall.
5. Anything only the VPS can test stays untested until the VPS exists. Say so; do not let a
   green sandbox run stand in for it.

## What a pass here does not mean

Stage 1, the container flags and the OAuth persistence are never exercised in this sandbox, and
between them they carry most of the security weight and the single likeliest cause of a stalled
build. A green run means the documents survived a cold reader on a machine with no firewall, no
container, and no real backup destination.

It is the cheapest test that tells the truth. It is not the acceptance test.
