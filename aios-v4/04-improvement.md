# 04 - The improvement loop

The system improves its methods. It never improves its own authority.

**Stability is the default state.** Most weeks the correct outcome is no change, and "no change
this week" is a recorded outcome, not silence.

---

## 1. Why this needs a budget

A system that can change itself weekly, and is evaluated by itself, will drift. Each change
looks locally reasonable. Six months later nothing resembles what was built, nothing was ever
measured, and no one can say whether it got better, because two changes landed the same week
and life happened on top of both.

So the loop is deliberately slow:

- **One change at a time**, with a measurement window before the next.
- **At most one adoption per month**, unless something is broken. Broken means a health check
  is failing or a routine has stopped. It does not mean "I thought of something good", and it
  does not mean a **signal** moved: a fortnight of low check-in coverage is the user's life,
  not a fault, and it must not unlock the change budget. See `01-architecture.md` section 11.
- **Without a measured baseline, assessment is just opinion.** The baseline is
  `ops/check-scores.jsonl`, check-in coverage, and whether the last four interventions actually
  happened.

---

## 2. Sunday, in order

### 2a. Audit backwards

Looking only at what already happened:

- Did every routine run? What did the run records say?
- Did the weekly review name a bottleneck with evidence, or produce a list and a hedge?
- **Did the user do the last intervention?** If not, three weeks running, the interventions
  are wrong, not the user. That is the finding.
- What did the system file oddly, or have to be corrected on?
- What did the health score do? What is in `ops/security/alerts.md`?
- Is any attestation within thirty days of its first birthday?

Written to `ops/audit/YYYY-WW.md`. Honest about its own performance or it is worthless. An
audit that concludes "working well" every week is an audit that is not being run.

The procedure lives in `skills/audit/`.

### 2b. Research outwards, two modes

**Targeted.** Aimed at what the audit found. If the review keeps hedging on constraint versus
self-sabotage, look for better ways to make that call from a log. Narrow and driven by the
week's evidence.

**Open scan.** A deliberately undirected look at the landscape: Claude Code changes, model
changes, relevant tooling, for things the user did not know to look for. This is the mode that
catches the capability that would have been useful six weeks ago, and it is the one that gets
skipped first when the week is busy. It is scheduled for that reason.

Anything fetched goes through the quarantine pipeline (`01-architecture.md` section 5) and
keeps its `trust: external` marker into the scan notes. A model release note is still a page on
the internet.

**Grade the source.** Vendor documentation is authoritative about that vendor's product. A
practitioner writeup is one person's experience on a different workload. Marketing is marketing.
For a system holding this much personal data, six months of known failure modes usually beats
last week's release.

The procedure and the watchlist live in `skills/research-scan/`.

### 2c. Three outcomes, and only three

Every candidate from either mode ends as exactly one of:

| Outcome | What gets written |
|---|---|
| **Adopt** | A proposal in `ops/proposals/`, with what it changes, what it should improve, and how that will be measured |
| **Park** | The idea **plus a trigger condition**: the specific thing that would make it worth revisiting |
| **Reject** | The idea plus the reason, logged |

Parking without a trigger is just forgetting with extra steps. "Park until the check-in habit
has held for eight weeks" is a park. "Maybe later" is not.

Rejections are logged because the same idea will resurface in four months, and the reason it
was rejected is the most useful thing anyone can hand that future conversation.

All three go to `ops/improvement-ledger.jsonl`, one line each: date, mode, candidate, outcome,
reason, and the trigger if parked.

---

## 3. Adoption

Proposals are **propose-then-wait**. The user approves from the host; the container cannot
apply one itself.

An approved change is applied **alone**, then measured:

1. State the measurement before applying it. "This should raise check-in coverage" or "this
   should mean the review stops hedging on constraint versus self-sabotage".
2. Apply one change.
3. **Window: four weeks.** Long enough for a signal, short enough to remember the change.
4. Record the outcome in the ledger: improved, no effect, or made it worse.
5. **Made it worse is reverted**, and the reversion is logged. A change that survives only
   because reverting it is embarrassing is how systems rot.

Nothing else is adopted during the window unless something is broken.

---

## 4. What is being measured, and how weakly

The honest list:

| Signal | Strength |
|---|---|
| Check-in coverage (days recorded / days elapsed) | Strong. Mechanical, hard to fudge |
| Health score trend | Strong for system health. Says nothing about usefulness |
| Intervention follow-through (did the user do it?) | **The best signal available.** It measures whether the advice fit the actual life |
| Progress against stated goals | Weak. Self-reported, and the goals move |
| "Did life get better" | Not measurable here. Do not pretend otherwise |

**The limits, plainly.** One user. No control group. A four-week window against life events
that dwarf any intervention: one bad fortnight at work swamps every signal in the table. The
system cannot distinguish "the change worked" from "it was a good month".

So the loop is not science. It is a disciplined way of noticing, and it is worth running for
one reason: **intervention follow-through.** If the user does what the review suggests, four
weeks running, the review understands their capacity. If they do not, it does not, and nothing
else in this document is as informative as that one count.

---

## 5. Every proposal carries a test

A proposal without a test is a guess with formatting. Before a change is applied, the proposal
must say how anyone would know it worked, and how anyone would know it broke something else.

### 5a. The regression gate, mechanical, always runs

This part does not depend on the system's judgement at all, which is why it is the part that
can be trusted:

```bash
./run-all.sh --json > /tmp/before.json
# apply exactly one change
./run-all.sh --json > /tmp/after.json
./compare-scores.sh /tmp/before.json /tmp/after.json   # non-zero = revert
```

Any check that was passing and is now failing, skipping, **or missing**, reverts the change.
Not "weigh it up", revert. A change that breaks a property the system already had is not a
trade-off, it is a change that failed.

The missing case matters most: deleting the check that fails is the cheapest way to make a
change look safe, and the score would read 2/3 -> 2/2, which looks like nothing happened. The
gate treats a vanished check as a regression.

Without this gate, a skill edit that breaks the nightly run is invisible until the weekly
health check. That is up to seven days of a system that looks fine and is doing nothing.

### 5b. The change test, red first, or it proves nothing

The proposal also writes a test for the thing it is *trying to achieve*. And here is the whole
discipline in one rule:

**The test must be shown to fail before the change is applied.**

A test written by the same reasoning that wrote the change will pass, because it encodes the
same assumptions. A test that has never been seen to fail is decoration. So the sequence is:

1. Write the test **first**, against the stated intent.
2. Run it. **It must fail.** If it passes before the change, it is not testing the change:
   throw it away and write a better one, or conclude there was nothing to fix.
3. Apply the change.
4. Run it. It must pass.
5. Run the regression gate.

Record all of it in the proposal. "Failed before, passed after" is the only form of evidence
here worth the name.

### 5c. "No mechanical test possible" is a legitimate outcome

Rewording a check-in question cannot be unit-tested. Neither can a change to how the weekly
review argues. Forcing a test onto these produces theatre, and a fake test is worse than no
test because it gets believed.

When no mechanical test exists, the proposal says so **and names the observable signal
instead**: which number in `ops/` should move, in which direction, by when. Usually that is
check-in coverage or intervention follow-through. An unfalsifiable proposal, one where no
result would count as failure, is rejected on that ground alone.

### 5d. Test budget and retirement

Tests accumulate. A suite that grows every week becomes slow and noisy, and a noisy suite gets
ignored, at which point the whole harness is worse than nothing.

- A change test is **one-shot by default**. It lives in `ops/proposals/<name>/`, runs at steps
  2 and 4 above, and is discarded when the measurement window closes.
- It joins the permanent suite **only if it tests a property that must hold forever**. That is
  a separate decision, made deliberately, and it adds the ID to `checks/expected-ids.txt`.
- The permanent suite has a budget: **+3 checks per quarter**. Exceeding it needs an argument
  written down, exactly like the seven-directory budget.
- Retire a permanent check when the property it tests no longer matters. Retirement is a
  proposal like any other, never a quiet deletion, which the gate would catch anyway.

### 5e. A passing test is not permission

The system may write the test, run the test, and report the result. **It may not treat a green
test as approval to adopt.** You approve, from the host, as with every other proposal.

This is the line that matters. A system that writes its own tests, runs them, and acts on the
result has granted itself an approval mechanism, which is improving its own authority while
appearing to improve its methods. The test is evidence handed to you. It is not a decision.

---

## 6. What the loop may never do

- Change `settings.json`, the deny rules, **the hooks**, the crontab, the cron scripts, the
  backup configuration, or container flags. Structurally prevented, not merely prohibited.
- Widen its own autonomy, including moving a task from propose-then-wait to act-then-report.
- Promote an `inferred` claim to `confirmed` without the user saying so.
- Adopt a change without a stated measurement.
- Adopt two changes in one window.
- Delete or rewrite the audit history, the ledger, the audit log, or the check-in log.
- **Adopt a change on the strength of its own green test.** See 5e.
- **Edit a check to make it pass.** The only legitimate reason to change a check is that it
  tests the wrong property, and that is a proposal like any other. `checks/expected-ids.txt`
  exists so that a quietly removed check shows up as a failure rather than as a higher score.
- **Treat a signal as a fault** in order to unlock the change budget. Low check-in coverage is
  information about the user's fortnight. It is not permission to start changing things.

---

## 7. Self-healing, and its one hard limit

Recover from routine failures where it is safe to: retry a safe operation, clear a stale lock,
clean a temp directory, verify the recovery worked, record what happened. For anything higher
risk: diagnose, explain, recommend, wait for approval, execute, verify.

**Never self-heal by disabling the control that was doing its job.** A hook that blocked
something, a deny rule that refused a command, a check that went red: these are the system
working. Routing around one to make a task complete is the single move that is never available,
and the fact that a control is inconvenient is never evidence that it is wrong.

---

## 8. The record of a quiet week

```json
{"week":"2026-W38","audit":"ops/audit/2026-W38.md","adopted":null,
 "outcome":"no change","reason":"measurement window open on 2026-W36 change (check-in prompt reworded)",
 "health":"all green","checkin_coverage":"13/14"}
```

That is a good week. Most weeks should look like it.

A month of these in a row is not the loop failing. It is the loop working: nothing was broken,
nothing new was worth the disruption, and the system did not invent work to look busy. The week
to worry about is the one where something was adopted and nobody wrote down what it was
supposed to improve.
