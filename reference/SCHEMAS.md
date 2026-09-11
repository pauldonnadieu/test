# Data schemas

The contracts every part of the system reads and writes: the CLI, the rituals, the weekly review, and any app built later.

**Design rules.** Markdown for prose a human reads. JSONL for append-only event streams, because both a script and a model can parse them and they diff cleanly in git. No database (see `ARCHITECTURE.md` D13). Everything must be writable by hand, by the CLI, by the AIOS, and later by an app.

**Why these exist before there is an app.** The user wants a purpose-built interface later for time management, a Pomodoro timer, alarms and trend analysis. Defining the data now means the weekly review can do real analysis immediately from CLI-entered data, and the eventual app becomes a capture surface over a model that already works rather than a migration.

---

## 1. Goals

One file per goal, `context/goals/<slug>.md`. Five active, hard cap.

```yaml
---
trust: confirmed
source: intake-2026-09-11
created: 2026-09-11
sensitivity: personal
status: active | maintenance | paused | achieved | abandoned
revisit: 2026-12-01        # required when status is paused
---
```

Body sections, all of them:

- **Outcome.** What specifically is true when this is done.
- **Why it matters.** In the user's own words. This is what gets read back when motivation dips.
- **Timeframe.** Target date, and honesty about whether it is real or aspirational.
- **Current state.** Updated from check-ins.
- **Constraints.** What genuinely limits progress here.
- **Leading indicators.** What to watch weekly that moves before the outcome does.
- **Next action.** One thing, small enough to do this week.
- **Minimum viable version.** What counts as keeping this alive during a bad week.
- **Obstacles.** Known and anticipated.
- **Fallback.** What happens when the main strategy stalls.
- **History.** Append-only. Attempts, what happened, what was learned.

---

## 2. Daily check-in

`checkins/daily/YYYY-MM-DD.md`. Thirty seconds. The ground truth everything else runs on, so it must be short enough to survive a bad day.

```yaml
---
date: 2026-09-11
energy: 3          # 1-5
sleep_hours: 6.5
---
```

Then three short free-text fields: what actually moved that matters, what was intended and did not happen, anything unwritten on their mind. Plus one rotating question generated from current goals or a pattern being tested.

Never analysed in the moment. A check-in that turns into a conversation stops being thirty seconds and stops happening.

A missed day is fine and is itself data. Three consecutive misses is raised gently at the weekly review, never chased daily.

---

## 3. Time blocks

`time/YYYY-MM.jsonl`, append-only, one object per line.

```json
{"start":"2026-09-11T09:00:00+10:00","end":"2026-09-11T09:25:00+10:00","minutes":25,"kind":"focus","label":"side hustle: landing page","goal":"side-hustle","energy_before":4,"energy_after":3,"completed":true,"interruptions":2}
```

| Field | Notes |
|---|---|
| `kind` | `focus` `meeting` `admin` `break` `interrupt` `commute` |
| `label` | Free text, what it was |
| `goal` | Slug matching a file in `context/goals/`, or omitted |
| `energy_before` / `energy_after` | 1-5, both optional |
| `completed` | Did the block run to its intended end |
| `interruptions` | Count, optional |

Written by `aios time start` and `aios time stop`, or by hand, or later by an app's Pomodoro timer. A 25-minute `focus` block with `completed` is a finished pomodoro; nothing in the schema needs to know that.

**Keep logging light.** The failure mode of time tracking is that logging becomes the work. Partial data beats abandoned data.

---

## 4. Energy

`energy/YYYY-MM.jsonl`, append-only.

```json
{"at":"2026-09-11T14:30:00+10:00","level":2,"note":"post-lunch, office day","source":"self"}
```

`source` is `self` (a deliberate observation), `checkin` (written by the daily check-in), or `block` (captured at the end of a time block). All of it is self-reported; there is no wearable in this setup, so the only thing that makes this data exist is how fast it is to enter. One tap or one short command. Never a form.

---

## 5. Tasks

`tasks/active.md`, a plain checklist. Completed items move to `tasks/done/YYYY-MM.md` monthly.

```markdown
- [ ] Renew car registration `due:2026-09-20` `goal:household` `est:15m`
- [ ] Draft the pricing page `goal:side-hustle` `est:90m`
- [x] Book dentist `done:2026-09-10`
```

Inline tags, not front matter, so the file stays editable in any text field on a phone. `due`, `goal` and `est` are all optional.

This is deliberately not a task system. It is a list the AIOS reads and writes. Anything more capable belongs in the future app, reading this same file.

---

## 6. Notes and captures

`raw/notes/YYYY-MM-DD-HHMM.md`, one file per capture, provenance front matter per `policy/trust.md`.

Captures arriving through the CLI are user-authored, so `trust: confirmed`, but voice transcription is lossy. Mark `source: shortcut-capture` where relevant so the wiki lint treats transcription artefacts sceptically rather than compiling them as fact.

---

## 7. Weekly review

`checkins/weekly/YYYY-Www.md`. Generated from the week's check-ins, time and energy logs, run logs, goal files and decisions.

Sections, in order:

1. **What actually happened.** From the data, not impressions.
2. **Goal by goal.** Moved, stalled or drifting, with evidence for each verdict.
3. **The pattern.** One thing the week's data shows that a single day would not. This is the value of the whole exercise.
4. **The bottleneck.** The single biggest constraint right now. One, not a list.
5. **The intervention.** The smallest change likely to shift it, already prepared.
6. **What the AIOS got wrong.** Its own failures, honestly. Feeds the improvement loop.
7. **Next week.** What matters, what waits, what drops.

The review may conclude that nothing needs to change.

**What the time and energy data makes possible.** Once a few weeks exist, real claims become available: which times of day focus blocks actually complete, what office days cost, whether energy predicts completion better than intention does, which goals absorb time without moving. That is the trend analysis the future app would display; the analysis itself does not need an app, it needs the data.

---

## 8. Bottleneck analysis

Triggered when a goal has not moved for three consecutive weeks, or on request.

Work in order. Stop at the first that explains the evidence; do not assemble a comprehensive diagnosis.

1. Is the goal still right, or has it stopped mattering?
2. Is the strategy sound in principle?
3. Is it realistic given `context/constraints.md`?
4. Is there an environmental constraint, something about where or when?
5. Is there an energy or capacity constraint? Check `energy/` and `time/`.
6. Is there too much complexity in the plan?
7. Is there friction, small repeated costs that add up?
8. Is the task being avoided, and if so what specifically is uncomfortable?
9. Is there a recurring pattern across goals?
10. Are too many things being attempted at once?
11. Can the AIOS remove part of the problem outright rather than helping them through it?

Output: one named constraint, the evidence, and one intervention small enough to happen this week.

When the constraint is genuine, do not prescribe more discipline. Look for removal, reduction, automation, delegation, substitution, simplification, resequencing, or a temporary minimum viable version.

---

## 9. Self-sabotage protocol

Handle carefully. Done well this is the most valuable thing the system does. Done badly it is insulting and trust does not come back.

**Rules.** Never label behaviour as self-sabotage without evidence from check-ins; a hunch is not evidence. Never raise the same pattern more than once a month. Always pair it with an intervention, because diagnosis without a next step is just criticism.

**Procedure.**

1. Observe the pattern across at least three instances. Cite them.
2. Identify the trigger. What was consistently true beforehand.
3. Identify the immediate reward. Avoidance always pays something.
4. Identify the long-term cost.
5. Ask honestly whether the behaviour is rational given the circumstances. Often it is, and then it is a constraint problem, not a sabotage problem. **This step exists to stop the system pathologising sensible behaviour.**
6. Propose the smallest intervention.
7. Test for a defined period.
8. Measure. Write the result to `context/patterns.md` with provenance.

Patterns worth watching: procrastination, avoidance, perfectionism, excessive research, constantly changing strategy, novelty seeking, overengineering, unrealistic plans, all-or-nothing thinking, abandoning a system after one bad day, using low-value work to avoid high-value discomfort, repeatedly planning without building execution systems.

---

## 10. Decisions log

`decisions/log.md`, append-only, newest at the bottom.

```markdown
## 2026-09-11 Moved gym sessions to mornings on office days

**Why.** Four missed evening sessions in three weeks, all office days. Location, not motivation.
**Alternatives.** 20 minutes at home on office days; dropping to two sessions a week.
**Decided by.** User.
**Revisit.** 2026-10-11
```

Anything that changes how the system works, or a goal strategy, goes here. This is what makes reflection possible later.
