---
name: file-this
description: File something the user mentioned into the right place without asking, with provenance. Use whenever conversation produces something worth keeping.
---

# Filing

**The user never files anything.** Filing happens as a side effect of conversation, at
act-then-report autonomy, with no permission prompt.

## The rule about asking

When unsure where something goes, **put it in the most likely place and say so in one line.**
Do not ask.

"I put that under `reference/business/pricing.md`" is correct.
"Where would you like me to put this?" is a design failure.

Asking is the exact mental load this system exists to remove. Misfiling is cheap: the file is
findable by grep, the change ledger records it, and the weekly audit surfaces anything odd. A
wrong guess corrected in one sentence costs less than a question that interrupts, and far less
than a thought that never got written down.

## Provenance, on every file

```yaml
---
trust: confirmed | inferred | external
source: conversation-2026-09-14 | intake-2026-09-11 | untrusted-external/2026-09-14-slug
created: 2026-09-14
review_after: 2027-03-14   # optional, for claims that go stale
---
```

`confirmed` is something the user said. `inferred` is something the system worked out.
`external` is anything that came from outside.

**An inference never silently becomes a fact.** Promotion to `confirmed` requires the user to
say so, and it is a propose-then-wait action, not an act-then-report one. This matters more
than it looks: "you avoid the gym because you are afraid of failing at it" is a hypothesis, and
written without a marker it becomes something the system believes about someone who never
agreed to it.

## What happens automatically

| The user says | What to do |
|---|---|
| Something they are worried about | File it with provenance. Raise it on Sunday if it recurs |
| A goal is done, or dead | Move it to achieved or abandoned, with the date and the reason |
| A fact about themselves | Update `goals/` or `reference/`, marked `confirmed` |
| Something contradicting a stored fact | Flag the contradiction. Never silently overwrite |
| A decision, in passing | Append it with the reasoning |
| A passing thought | `reference/`, under the most likely area |

## Constraints

**Report tidily, do not narrate.** One line. A running commentary on every write is noise.

**Never version by filename.** No `-v2`, no `-final`, no `.bak`. Snapshots are the history.

**Depth is a cost.** Put a new kind of thing in an existing directory before inventing one.
Seven top-level entries is the budget and going over it needs an argument, not a preference.

**Regenerate `START-HERE.md`** whenever the structure changes. A map that has drifted is worse
than no map.

**Archive, never delete**, except on an explicit request to forget, which follows
`core/03-operations.md` section 7 and must be honest about all four places the thing lives.

**Never file into the trusted tree in a session that has read quarantined content.** The
write-guard hook will refuse it anyway; know why rather than being surprised.
