# Proposal: <short name>

Date: <YYYY-MM-DD>   Source: <weekly audit | targeted research | open scan>

## What it changes
One paragraph. Exactly one change.

## What it should improve
Stated before doing anything. Specific enough that it could turn out wrong.

## The test

- [ ] Test written **before** the change: `ops/proposals/<name>/test.sh`
- [ ] **Ran it before. It FAILED.** Paste the output:
  ```
  ```
  If it passed here, it is not testing this change. Throw it away.
- [ ] Applied the change.
- [ ] **Ran it after. It PASSED.** Paste the output:
  ```
  ```

### If no mechanical test is possible
Say so, and name the observable signal instead:

- Number: <e.g. check-in coverage, intervention follow-through>
- Direction: <up | down>
- By when: <date, normally four weeks>
- What result would count as FAILURE: <if nothing would, this proposal is rejected>

## Regression gate

- [ ] `./run-all.sh --json > before.json` (taken **before** the change)
- [ ] `./run-all.sh --json > after.json`
- [ ] `./compare-scores.sh before.json after.json` exits 0. Paste the summary:
  ```
  ```

Non-zero means revert. Not discuss, revert.

## Rollback
The exact steps to undo this, written before it is applied. If it cannot be cleanly undone,
say so here; that alone may be reason enough to reject it.

## Measurement window
Opens: <date>   Closes: <date, normally four weeks later>
Nothing else is adopted while this window is open, unless something is broken.

Broken means a **health** check is failing or a routine has stopped. A signal moving, such as
low check-in coverage during a hard fortnight, is not broken and does not open the budget.

## Outcome (filled in when the window closes)
- [ ] Improved   - [ ] No effect   - [ ] Made it worse -> reverted on <date>

Recorded in `ops/improvement-ledger.jsonl`.

---
**This proposal is not self-approving.** A green test is evidence handed to the user. The user
decides, from the host. The container cannot apply this.
