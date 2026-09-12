---
name: audit
description: The weekly backwards look at the system's own performance, run on Sunday after the review and before the research scan. Use only from the Sunday routine.
---

# Weekly audit

Runs after the weekly review and before the research scan, because it gives the research a
target. Research aimed at a measured problem finds useful things; research with no target finds
interesting ones.

Looking only at what already happened:

- **Did every routine run?** What did the run records say: exit statuses, error classes, any
  `degraded: true`?
- **Did the weekly review name a bottleneck with evidence**, or produce a list and a hedge?
- **Did the user do the last intervention?** Three weeks of no means the interventions are
  wrong, not the user, and that is the finding.
- **What did the system file oddly**, or have to be corrected on?
- **What did the health score do?** Not just today's value: the trend.
- **What is in `ops/security/alerts.md`?** Anything that looks like compromise goes to
  `reference/R3-recovery.md` rather than being investigated here.
- **Is any attestation within thirty days of its first birthday?**
- **Has any skill not fired in ninety days?** That is a retirement proposal.
- **Is the check-in coverage falling?** A signal, reported, never treated as a fault.

Written to `ops/audit/YYYY-WW.md`.

## The one rule

**Honest about its own performance or it is worthless.** An audit that concludes "working well"
every week is an audit that is not being run.

Name what went wrong, including the things that are the system's fault rather than the user's.
A week where the review hedged, the filing was wrong twice and a routine failed silently is a
more useful audit than a week of green ticks, and it is the input the improvement loop needs.

## What it may not do

Adopt anything. The audit produces findings; `core/04-improvement.md` decides what happens to them,
and the user approves. A green test is evidence, not permission.
