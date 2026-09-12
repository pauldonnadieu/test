# R6 - One week, worked end to end

**Everything in this document is invented.** The person does not exist. It is here because no
amount of specification shows what "a bottleneck with evidence" actually reads like, and a cold
reader who has seen one good week will build a better system than one who has only seen rules.

Read it once before writing any skill output. Do not copy the details; copy the shape.

---

## Monday to Sunday: the check-ins

```jsonl
{"date":"2026-09-07","energy":2,"intended_vs_actual":"meant to draft the pricing page. Did email, then a deploy that broke.","obstacle":"the deploy. Three hours I had not planned for.","keep":null,"example":false}
{"date":"2026-09-08","energy":3,"intended_vs_actual":"pricing page draft, about half.","obstacle":"office day, left at 6, no evening left in me.","keep":"idea: charge setup separately from the monthly","example":false}
{"date":"2026-09-09","energy":4,"intended_vs_actual":"finished the draft. Good day.","obstacle":"nothing much.","keep":null,"example":false}
{"date":"2026-09-10","energy":2,"intended_vs_actual":"meant to send it to two people for feedback. Didn't.","obstacle":"office day. Told myself I'd do it at home and then didn't open the laptop.","keep":null,"example":false}
{"date":"2026-09-11","energy":3,"intended_vs_actual":"still haven't sent it. Rewrote the opening instead.","obstacle":"honestly not sure. Kept finding things to fix.","keep":null,"example":false}
{"date":"2026-09-12","energy":4,"intended_vs_actual":"family day, no work planned, none done. Good.","obstacle":"n/a","keep":null,"example":false}
{"date":"2026-09-13","energy":3,"intended_vs_actual":"tidied the repo. Did not send the page.","obstacle":"none I can name.","keep":null,"example":false}
```

Seven of seven. Note what is *not* here: no analysis, no commentary on the gap between intent and
action, no encouragement. That is the check-in doing its job and stopping.

---

## The review it produces

> # 2026-W37
>
> ## The bottleneck
>
> The pricing page has been finished since Wednesday and has not been sent to anyone.
>
> ## The evidence
>
> - 10 Sep: "meant to send it to two people for feedback. Didn't."
> - 11 Sep: "still haven't sent it. Rewrote the opening instead." and "kept finding things to fix."
> - 13 Sep: "tidied the repo. Did not send the page."
>
> Three days, three different substitute tasks, all of them lower value than the thing being
> substituted for. The draft was done on the 9th on a high-energy day, so this is not capacity.
>
> ## Constraint or self-sabotage
>
> **Self-sabotage, and I am reasonably confident.** *(inferred)*
>
> The distinguishing evidence is the 11th: energy 3, no obstacle named, and the time went into
> rewriting something already finished. A constraint shows up as the same obstacle across
> different attempts; here the obstacles are different every time and none of them is an
> obstacle, which is the pattern. Compare the 8th, where "office day, left at 6" is a real
> constraint with a real mechanism.
>
> The specific shape is perfectionism used as avoidance: the rewriting is not improving the page,
> it is postponing the moment someone reads it. This is the third instance in six weeks of a
> finished thing not being shown to anyone (see `reference/patterns.md`, entry from 2026-W33).
>
> ## The intervention
>
> Send it to one person, not two, on Monday, before 9am, with the subject line already written:
> "Rough pricing page, 5 min read, tell me what's confusing."
>
> I have drafted that email into `reference/business/pricing-feedback-draft.md`. It needs a name
> in the To field and nothing else.
>
> One person rather than two because your capacity file says Monday mornings are your only
> uninterrupted hour and I would rather not spend it choosing recipients. Before 9am because
> every day this week that the work survived to the evening, it did not happen.
>
> ## What I got wrong last week
>
> Last week I suggested blocking two hours on Thursday for outreach. You did not do it, and the
> check-in for the 10th says why: Thursday is an office day and you get home at six. That was a
> suggestion made against an idealised week rather than the one in your capacity file. This is
> the second time I have proposed something on an office evening. I have added a line to
> `goals/business.md` so I stop doing it.
>
> ## Coming up
>
> - The quarterly restore drill is due in eleven days. It takes about an hour and needs a second
>   VPS. Worth putting in the calendar now rather than discovering it on a Sunday.
> - `goals/health.md` has not been mentioned in a check-in for nineteen days. Not raising it as a
>   failure, just noting it has gone quiet.
> - Two attestations reach twelve months on 2026-10-04.

Three things about that review are the whole point. The bottleneck is **one thing**, not a list.
Every claim points at a dated line. And the intervention is **already prepared**, so what is
handed over is a finished thing with one blank in it, not a task.

---

## The audit, the same evening

> # Audit 2026-W37
>
> - All eight routines ran. Backup on the 11th was `degraded: true`, fell back to sonnet on an
>   opus limit, recovered the next night.
> - The review named one bottleneck with three dated citations. Good.
> - **Last week's intervention did not happen.** That is two of the last four. Both failures were
>   scheduled on office evenings, which is a pattern in my own advice rather than in the user's
>   behaviour, and I have corrected it in the goal file.
> - Filing: one correction. A note about the deploy went to `reference/business/` and belonged in
>   `reference/infra/`.
> - Health 129/129. Signals 7/7 coverage.
> - Nothing in `alerts.md`.
> - `skills/decide/` has not fired in 61 days. Not yet a retirement candidate at 90.

An audit that says "working well" every week is an audit that is not being run. This one names
its own failure in the third bullet, and that bullet is worth more than the rest combined.

---

## A proposal, through its whole life

> # Proposal: send-by-default framing in the weekly review
>
> Date: 2026-09-14   Source: weekly audit
>
> ## What it changes
> The intervention section of `skills/weekly-review/` gains one line: when the bottleneck is a
> finished thing not being shown to anyone, the intervention must name a single recipient and a
> time before 9am.
>
> ## What it should improve
> Intervention follow-through, currently 2 of the last 4. Specifically, it should stop
> interventions being scheduled into hours the capacity file says do not exist.
>
> ## The test
> - [x] Written **before** the change: `ops/proposals/send-by-default/test.sh` greps the last
>       four reviews for an intervention scheduled after 18:00 on a day marked as an office day.
> - [x] **Ran it before. It FAILED.** 2 of 4 reviews matched.
> - [x] Applied the change.
> - [ ] Ran it after. Pending: needs four more reviews.
>
> ## Regression gate
> - [x] `./compare-scores.sh before.json after.json` exits 0. No regressions.
>
> ## Rollback
> Delete the added line from the skill. One step.
>
> ## Measurement window
> Opens 2026-09-14, closes 2026-10-12. Nothing else adopted while it is open.

Note that the test **failed first**. A test written by the same reasoning that wrote the change
will pass, because it encodes the same assumptions, and a test never seen to fail is decoration.

Four weeks later, the outcome line:

```json
{"week":"2026-W41","adopted":"send-by-default","outcome":"improved",
 "evidence":"follow-through 4/4 since; test passes on the last four reviews","reverted":false}
```

---

## And a quiet week, which is what most should look like

> # Audit 2026-W38
>
> All routines ran. Review named a bottleneck with evidence. The intervention happened. Health
> green. Coverage 13/14.
>
> Nothing to adopt: the 2026-W37 measurement window is open until 2026-10-12.

```json
{"week":"2026-W38","audit":"ops/audit/2026-W38.md","adopted":null,"outcome":"no change",
 "reason":"measurement window open on send-by-default","health":"all green","checkin_coverage":"13/14"}
```

**That is a good week.** Nothing was broken, nothing new was worth the disruption, and the system
did not invent work to look busy. A month of these in a row is the loop working, not failing. The
week to worry about is the one where something was adopted and nobody wrote down what it was
supposed to improve.
