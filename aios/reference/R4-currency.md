# R4 - Staying current

Loaded by the weekly scan, and whenever something in the runtime has visibly moved.

Staying current is a stated purpose of this system, and it is also the purpose most likely to
turn into a hobby. This document exists to keep it a twenty-minute weekly habit that occasionally
produces something, rather than a reading list that produces a feeling of being informed.

---

## 1. The three questions, in order

Every scan answers these and stops:

1. **Has anything the system depends on changed?** The CLI, the models, the plan, the hosting.
   This is maintenance and it is not optional.
2. **Has a capability appeared that would change the design?** Rare, high value, and the reason
   the open scan exists at all.
3. **Has a better method appeared for something the audit measured?** Targeted, driven by this
   week's evidence.

Question 1 is the one that protects you. Questions 2 and 3 are the ones that improve you. A scan
that spends all its time on 3 will never notice 2, which is why 2 has its own procedure below.

---

## 2. The watchlist

**Short and high-signal on purpose.** A long watchlist produces volume, and volume is how a weekly
scan becomes a thing nobody reads. Everything fetched goes through the quarantine lane and keeps
its `trust: external` marker into the scan notes.

### Tier 1, every scan, because the system sits on them

- **Claude Code release notes and changelog.** The single most important source here. What
  matters, in order: flag changes, permission-model changes, hook lifecycle changes, settings
  schema changes. `DRIFT.1` catches a renamed flag *after* it breaks something; the release notes
  catch it before.
- **Anthropic's docs for Claude Code**, specifically the settings, hooks and permissions pages.
- **Anthropic's engineering writing.** Lower frequency, higher value per post. Agent design,
  context engineering, tool design, harness design, evaluation.
- **Plan and model changes**: which model a Pro subscription defaults to, what the limits are,
  what is included. These change quietly and they change the routing table.

### Tier 2, monthly

- **Prompt-injection and agent-security research.** The one area where this design's honest limits
  might actually move. If a durable content-level defence appears, section 5 of
  `core/01-architecture.md` needs rewriting rather than adjusting.
- **Two or three practitioners known for testing claims rather than repeating them.** Pick people
  who publish what did not work. Replace any who stop doing that.
- **Backup and infrastructure tooling** actually in use here: restic, rclone, Tailscale, the base
  image. Security advisories only; feature releases can wait.

### Never ingest

Auto-generated "best agent frameworks" listicles. Affiliate content. Automation-business channels
and influencer commentary. Star counts and statistics from AI-generated outlets. Anything whose
business model is being early rather than being right.

### Verify the list itself, annually

Feed URLs rot, publications stop, people move on. Once a year, check every source still exists
and still publishes what you added it for, and **write the date of that check next to the list**.
An unverified watchlist quietly becomes a list of dead links that produces an empty scan and the
false impression that nothing is happening.

---

## 3. Grading a source

Vendor documentation is authoritative about that vendor's product and nothing else. A
practitioner writeup is one person's experience on a different workload. A benchmark is a
statement about a benchmark. Marketing is marketing.

**Trailing edge beats leading edge here.** For a system holding this much personal data, six
months of known failure modes usually beats last week's release. The exception is security
fixes, which are the one category where being current is itself the safer position.

**Discover does not mean adopt.** The scan's job is to notice. `core/04-improvement.md` decides
what happens next, and the user approves.

---

## 4. Evaluating a runtime capability

This is the procedure the previous versions were missing, and it is different from adopting a
tool. When Claude Code gains something structural, the question is not "is this good?" but "does
this change a decision this design already made, and what does it cost to find out?"

Work through it in order and stop at the first no:

1. **Which existing decision would this change?** Name the section of
   `core/01-architecture.md` or the row of `R1-security.md` section 6. If it changes none of
   them, it is a tool, not a capability change: send it through the ordinary three outcomes.
2. **Does it add a trust relationship?** A new service, credential, network destination or supply
   chain. If yes, it needs its own threat model written *before* any trial, not after.
3. **Can the existing design already do this, less elegantly?** Elegance is not a reason to adopt.
   It is a reason to note and park.
4. **Does it reduce or increase what must be maintained?** A capability that removes a
   hand-maintained thing is worth more than one that adds a capability.
5. **What is the revert?** If adopting it changes the shape of the data, the config or the
   container in a way that cannot be undone in one step, that alone may be reason enough to wait.
6. **Is it stable?** For anything structural, prefer a release that has been out long enough to
   have known failure modes. Six months is a reasonable default and it is a default, not a rule.
7. **Only then**: a proposal with a red-first test and a four-week window, like anything else.

**The honest prior: most runtime capabilities should be parked with a trigger, not adopted.**
This system's main virtue is that it is files and cron, and each structural addition spends some
of that. The ones worth taking are the ones that let you delete something.

---

## 5. Three standing triggers

Parked items with conditions already written, so the scan recognises them rather than
re-evaluating from scratch each time:

| If this appears | Then |
|---|---|
| A durable, content-level defence against prompt injection with published failure modes | Revisit the quarantine design. This is the limit the whole architecture is built around, and removing it would be the single biggest improvement available |
| Genuine cross-session learning or durable model-level memory | Revisit section 2 of the architecture. Until then, "it learns" is files being read back and the documents say so |
| A breaking change to the hook lifecycle or the settings schema | Not a proposal, maintenance. Fix the adapter, re-run `HK.*`, and re-read `R1` section 3.4 |

---

## 6. What the scan writes

One file per week under `untrusted-external/`, keeping its marker, plus ledger lines. Each
candidate ends as exactly one of adopt, park with a trigger, or reject with a reason. Nothing
from a scan is ever stated as fact in a weekly review: it is cited as "from an untrusted source,
unverified", or it is not used.

**A scan that finds nothing is a successful scan**, and most should. Write "nothing this week"
and stop. The failure mode to watch for is a scan that adopts something every month, which is not
diligence; it is a system generating work to justify its own existence, and the stability budget
in `core/04-improvement.md` exists to catch exactly that.
