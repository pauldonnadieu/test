# 04 - The improvement loop

The system improves its methods. It never improves its own authority.

**Stability is the default state.** Most weeks the correct outcome is no change, and "no change
this week" is a recorded outcome, not silence.

---

## 1. Why this needs a budget

A system that can change itself weekly, and is evaluated by itself, will drift. Each change looks
locally reasonable. Six months later nothing resembles what was built, nothing was measured, and
no one can say whether it got better, because two changes landed the same week and life happened
on top of both.

So the loop is deliberately slow:

- **One change at a time**, with a measurement window before the next.
- **At most one adoption per month**, unless something is broken. Broken means a **health** check
  is failing or a routine has stopped. It does not mean "I thought of something good", and
  crucially it does not mean a **signal** moved: a fortnight of low coverage is the user's life,
  not a fault, and it must not unlock the change budget.
- **Without a measured baseline, assessment is just opinion.** The baseline is
  `ops/check-scores.jsonl`, check-in coverage, and whether the last four interventions happened.

---

## 2. Sunday, in order

### 2a. Audit backwards

Did every routine run, and what did the records say? Did the review name a bottleneck with
evidence, or produce a list and a hedge? **Did the user do the last intervention?** What did the
system file oddly? What did the health score do, and what is in `alerts.md`? Is any attestation
near its first birthday? Has any skill not fired in ninety days?

Written to `ops/audit/YYYY-WW.md`. **Honest about its own performance or it is worthless.** An
audit that concludes "working well" every week is an audit that is not being run.

Procedure: `skills/audit/`.

### 2b. Research outwards, two modes

**Targeted**, aimed at what the audit found. **Open scan**, a deliberately undirected look at the
landscape, which is the mode that catches the thing that would have been useful six weeks ago and
the one that gets skipped first when the week is busy. It is scheduled for that reason.

Everything fetched goes through the quarantine lane and keeps its `trust: external` marker into
the scan notes. A model release note is still a page on the internet.

Watchlist, source grading, and the separate procedure for evaluating a **runtime capability**
rather than a tool: `reference/R4-currency.md`.

### 2c. Three outcomes, and only three

| Outcome | What gets written |
|---|---|
| **Adopt** | A proposal in `ops/proposals/`, from `test/PROPOSAL-TEMPLATE.md` |
| **Park** | The idea **plus a trigger condition**: the specific thing that would make it worth revisiting |
| **Reject** | The idea plus the reason |

Parking without a trigger is forgetting with extra steps. "Park until the check-in habit has held
for eight weeks" is a park; "maybe later" is not. Rejections are logged because the same idea
resurfaces in four months and the reason is the most useful thing to hand that conversation.

All three go to `ops/improvement-ledger.jsonl`.

---

## 3. Adoption

Proposals are **propose-then-wait**. The user approves from the host; the container cannot apply
one itself.

An approved change is applied **alone**, then measured: state the measurement before applying;
apply one change; **window of four weeks**, long enough for a signal and short enough to remember
the change; record the outcome as improved, no effect, or made it worse; and **made it worse is
reverted**, with the reversion logged. A change that survives only because reverting it is
embarrassing is how systems rot.

Nothing else is adopted during the window unless something is broken.

---

## 4. What is being measured, and how weakly

| Signal | Strength |
|---|---|
| Check-in coverage | Strong. Mechanical, hard to fudge |
| Health score trend | Strong for system health. Says nothing about usefulness |
| Intervention follow-through | **The best signal available.** It measures whether the advice fit the actual life |
| Preparation actually used | Good, and new. Did the prepared thing get used, or redone? |
| Progress against stated goals | Weak. Self-reported, and the goals move |
| "Did life get better" | Not measurable here. Do not pretend otherwise |

**The limits, plainly.** One user. No control group. A four-week window against life events that
dwarf any intervention: one bad fortnight at work swamps every signal in the table. The system
cannot distinguish "the change worked" from "it was a good month".

So the loop is not science. It is a disciplined way of noticing, and it is worth running for one
reason: **intervention follow-through.** If the user does what the review suggests, four weeks
running, the review understands their capacity. If they do not, it does not, and nothing else here
is as informative as that one count.

---

## 5. Every proposal carries a test

### 5a. The regression gate, mechanical, always runs

```bash
./run-all.sh --json > before.json
# apply exactly one change
./run-all.sh --json > after.json
./compare-scores.sh before.json after.json   # non-zero means revert
```

Any check that was passing and is now failing or skipping is a regression. **So is any check that
has vanished, whatever its previous verdict.** Deleting a check that was already failing is the
cheapest way to hide it: the score reads 2/3 to 2/2 and looks like nothing happened. The gate
treats any vanished ID as a regression, and it has been tested against exactly that scenario.

Not "weigh it up", revert. A change that breaks a property the system already had is not a
trade-off; it is a change that failed.

### 5b. The change test, red first, or it proves nothing

**The test must be shown to fail before the change is applied.** A test written by the same
reasoning that wrote the change will pass, because it encodes the same assumptions, and a test
that has never been seen to fail is decoration.

Write the test first. Run it: **it must fail.** If it passes before the change, it is not testing
the change, so throw it away or conclude there was nothing to fix. Apply the change. Run it: it
must pass. Run the regression gate. "Failed before, passed after" is the only evidence here worth
the name, and it is the same rule the harness itself was built under.

### 5c. "No mechanical test possible" is a legitimate outcome

Rewording a check-in question cannot be unit-tested. Neither can a change to how the review
argues. Forcing a test onto these produces theatre, and a fake test is worse than no test because
it gets believed. When none exists, name the observable signal instead: which number in `ops/`
should move, in which direction, by when. An unfalsifiable proposal, one where no result would
count as failure, is rejected on that ground alone.

### 5d. Test budget and retirement

A change test is **one-shot by default**, living in `ops/proposals/<name>/` and discarded when
the window closes. It joins the permanent suite **only if it tests a property that must hold
forever**, which is a separate, deliberate decision that adds the ID to `expected-ids.txt`. The
permanent suite grows by at most **+3 per quarter**; exceeding it needs an argument written down.
Retirement is a proposal like any other, never a quiet deletion, which the gate would catch.

### 5e. A passing test is not permission

The system may write the test, run it, and report the result. **It may not treat a green test as
approval to adopt.** A system that writes its own tests, runs them, and acts on the result has
granted itself an approval mechanism, which is improving its own authority while appearing to
improve its methods. The test is evidence handed to you. It is not a decision.

---

## 6. What the loop may never do

- Change settings, deny rules, **the hooks**, the crontab, the cron scripts, the backup
  configuration, the free-tier credential, or container flags. Structurally prevented.
- Widen its own autonomy, including moving a task from propose-then-wait to act-then-report.
- Promote an `inferred` claim to `confirmed` without the user saying so.
- Adopt without a stated measurement, or adopt two changes in one window.
- Delete or rewrite the audit history, the ledgers, the audit log, or the check-in log.
- **Adopt on the strength of its own green test.**
- **Edit a check to make it pass.** The only legitimate reason to change a check is that it tests
  the wrong property, and that is a proposal like any other.
- **Treat a signal as a fault** to unlock the change budget.

---

## 7. The record of a quiet week

```json
{"week":"2026-W38","audit":"ops/audit/2026-W38.md","adopted":null,
 "outcome":"no change","reason":"measurement window open on 2026-W36 change (check-in prompt reworded)",
 "health":"all green","checkin_coverage":"13/14"}
```

That is a good week, and most weeks should look like it. A month of them in a row is not the loop
failing. It is the loop working: nothing was broken, nothing new was worth the disruption, and
the system did not invent work to look busy. The week to worry about is the one where something
was adopted and nobody wrote down what it was supposed to improve.
