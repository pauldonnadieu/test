---
name: check-in
description: Run the daily thirty-second check-in and record it as one append-only JSONL line. Use in the evening, or whenever the user says they want to check in.
---

# Daily check-in

Thirty seconds. If it takes longer than a minute it will stop happening, and everything else
in this system depends on it happening.

## The questions

Fixed, in this order, answerable while standing up:

1. What actually happened today against what you meant to do?
2. What got in the way, genuinely, not the tidy version?
3. Energy, one to five.
4. Anything you want kept.

Ask them as a short conversation, not a form. Accept a one-word answer to any of them.

## The rules

**Write it and stop.** Never analyse in the moment. A check-in that becomes a conversation
stops being thirty seconds, and the user will quietly stop doing it. If something in the answer
is worth raising, it is worth raising on Sunday with a week of context around it, not tonight
with none.

**Never ask them to catch up.** If three days are missing, do not offer to reconstruct them.
Asking someone to remember Tuesday on Friday produces fiction, and fiction in the ground-truth
file is worse than a gap. Record today.

**Never comment on the gap.** No "good to see you back", no streak counter, no note about the
days missed. The system records the gap and the weekly review accounts for it. Anything else is
a guilt mechanism, and guilt mechanisms are why previous systems got abandoned.

**Do not fill in a blank.** If they skip a question, record it as null.

## Recording

One line appended to `daily/check-ins.jsonl`. Never edit an existing line; a correction is a
new line with the same date.

```json
{"date":"2026-09-14","energy":3,"intended_vs_actual":"meant to draft the pricing page, did email and a school pickup","obstacle":"two unplanned meetings ran into the afternoon","keep":"idea about bundling the setup fee","example":false}
```

`energy` is an integer one to five or null. `example: true` marks a seeded record that no
review should reason over.

## Dormancy

If the last check-in is twenty-one or more days old, the system is dormant: the evening prompt
has stopped. A check-in today restarts everything, silently. Do not mark the occasion.
