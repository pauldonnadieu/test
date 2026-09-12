# The harness

Not documentation. The executable half of this set, and it runs for as long as the system exists.

```bash
./run-all.sh --self-test        # FIRST, always. Proves the runner before you trust a score
cp config.env.example config.env && "$EDITOR" config.env
./run-all.sh                    # health. Gates
./run-all.sh --signals          # user behaviour. Reported, never gates
./run-all.sh stage-04-data      # one stage
./run-all.sh --json             # for ops/check-scores.jsonl
```

## Three rules the runner enforces so nobody has to remember them

A **SKIP scores as a failure**: an unrun check is an unknown, and an unknown is not a pass.
A check that **crashes** before emitting scores as MISSING.
A check that has **vanished** from the suite scores as MISSING, which is what stops a quiet
deletion reading as a higher score.

## Proving the harness itself

Everything here has been watched failing on purpose before being trusted to pass. Re-run these
after changing anything in `checks/` or `conf/hooks/`:

```bash
./run-all.sh --self-test                 # the runner: 3 assertions, plus its own negative control
bash fixtures/hooks-test.sh              # hook decision logic: 29 cases
bash fixtures/hook-adapters-test.sh      # payload parsing and audit hygiene: 15 cases
bash fixtures/sabotage-test.sh           # every testable check against a real sabotage: 75 cases
./score-e2e.sh fixtures/tree             # the cold-reader scorer, positive control
```

`fixtures/tree/` is a complete, correct AIOS tree. `fixtures/sabotage-test.sh` copies it, breaks
exactly one property, and asserts that the matching check goes red. **If you add a check, add its
sabotage.** A check with no negative control is a claim.

## config.env

`run-all.sh` **exports** these rather than merely sourcing them. Without that, no check
subprocess sees any of them, every check reports SKIP, and the suite can never go green on any
machine. That was a real defect found by a cold reader, and the comment stays in the script.

## Adding a check

1. Write it in the right `stage-*/` file, using `check <ID> <description>` with the body on stdin.
2. Add the ID to `expected-ids.txt` with its stage and its class (`health` gates, `signal` does
   not).
3. **Add a sabotage to `fixtures/sabotage-test.sh` and watch the check fail.**
4. Remember the budget: +3 permanent checks per quarter, per `core/04-improvement.md`.

## Never

**Never edit a check to make it pass.** The only legitimate reason to change one is that it tests
the wrong property, and that is a proposal like any other. Fix the property, not the check.
