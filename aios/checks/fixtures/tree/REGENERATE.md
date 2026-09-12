# The fixture tree

A complete, correct AIOS tree. `fixtures/sabotage-test.sh` copies it, breaks exactly one
property, and asserts that the matching check goes red.

Two files are deliberately **not** shipped and are created when you first use it:

```bash
touch rebuild/.built                     # RB.6 compares conf/ mtimes against this
```

`rebuild/.built` is a timestamp, so a shipped one would be stale on arrival and `RB.6` would
fail for the wrong reason. Run artefacts (`data/ops/.lock-*`, `data/ops/logs/*`,
`data/ops/.cli-version`) are never committed: they are residue from running the suite, they
would make the fixture non-deterministic, and `LOG.4` would eventually fail on them.
