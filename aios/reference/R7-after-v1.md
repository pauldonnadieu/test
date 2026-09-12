# R7 - After v1

Everything here is deferred. Each item has a **trigger condition**: the specific thing that would
make it worth doing. Parking without a trigger is forgetting with extra steps.

Read this when you are tempted to add something. Most of the time the answer is that it already
has a home here and a condition that has not been met.

---

## Time, sleep and the shape of the day

**What.** Two or three extra fields in the daily check-in: hours slept, and one line on where the
day's hours actually went. Not a tracker, not an app, not a timer.

**Why not yet.** The user's decision: add it once the habit itself has held. That is the right
order. A system that captures more than the user sustains gets abandoned with more of their life
inside it, and the first thing to prove is that the under-a-minute version survives a bad month.

**What v1 gives up, honestly.** The finding that makes this class of system worth running looks
like "all evenings, all office days" (see `R6`). That inference needs to know when things
happened and what the day contained. Without a time signal the review pattern-matches on prose,
which works for recurring language and less well for recurring circumstances. **Expect reviews
that name themes accurately and are weaker at naming causes.**

**Trigger.** Two consecutive reviews naming "I can see this keeps happening and I cannot see what
it has in common" as the limiting factor.

---

## The daily brief

**What.** One screen in the morning: what is on today that needs preparation and the preparation
already done, the one thing that matters most, anything approaching, anything awaiting approval,
anything it got wrong yesterday.

**Why not yet.** It needs to know what is in the day, which without a calendar means the user
telling it, which is a second daily interaction competing with the check-in. Two daily
touchpoints is how you end up with neither. The anticipatory function it used to carry now lives
in `skills/horizon/` and the review's forward section, so the *capability* is not deferred, only
the daily delivery of it.

**Trigger.** Coverage above twelve of fourteen for eight consecutive weeks, **and** the user
saying unprompted that they wanted to know something in the morning that the system knew. Both.

---

## The phone app

**What.** A small React Native app via Expo: timers, alarms, local notifications, fast capture.
The division of labour is the point: **the phone owns timers, alarms and capture; the VPS owns
data, memory and analysis.** A phone that holds the data becomes a second source of truth, and
two sources of truth is none.

**No Mac needed.** Expo's cloud build service compiles signed iOS builds on their own
infrastructure. A macOS VM is legally grey and practically painful; that path avoids it.

**What it does cost.** An Apple Developer Program membership, around USD 99/year, for anything
installed beyond a development build's short expiry. Roughly a third of the entire annual running
budget, so it is a real decision and not a footnote.

**Trigger.** The check-in habit fails *specifically because* opening the Claude app is too much
friction, demonstrated in the check-in log rather than assumed.

**Do not build it earlier because it sounds like the interesting part.** It is the interesting
part. That is the problem, and `skills/patterns/` has a name for it.

---

## Connections: calendar, then maybe email

**Why v1 has neither.** A connection is a permanent inbound flow of untrusted content into a
system holding the most sensitive data in the user's life. Every calendar invite is
attacker-controlled text with a title, a description and a location field. That is the
untrusted-content problem arriving daily and automatically.

**Trigger (calendar).** Three consecutive reviews naming "I don't know what was actually in your
week" as the limiting factor on the analysis. Then: read-only, through the quarantine lane,
treated as untrusted from the moment it lands, never promoted to fact. Note that the time-capture
item above is the cheaper answer to the same problem and should be tried first.

**Trigger (email).** None yet. The highest-volume untrusted-content firehose available and the
least necessary for the loop. If it ever happens it is a fresh design with its own threat model.

**Whatever arrives, it arrives at propose-only.** The permanent cap on money, employer systems,
other people's data and messages sent on the user's behalf is not waived by a connection existing.

---

## Local models

**What.** A small local model for mechanical work: parsing a check-in into fields, classifying
where a note goes. Work that never leaves the machine at all.

**Why not yet.** A 4 GB VPS has no room alongside the container, restic and everything else, and
Haiku already does this inside the subscription at no marginal cost.

**Trigger.** Either repeated `error_class: usage_limit` failures in the run records, which is
evidence rather than a hunch, or a genuine requirement that some category of data never leave the
machine. The second is the stronger reason.

**If it happens, the shape.** A larger VPS, roughly double the cost, which is a budget
conversation first. The model serves over localhost only, never a port. It becomes a **fourth
routing tier** below haiku in `R2` section 3, taking exactly the work that is fully mechanical
and language-shaped. It does **not** take the weekly review: a small local model doing the
judgement work would be a worse system that felt more private. And it gets its own row in the
data-class table, because "never leaves the machine" is a genuinely different guarantee and
should be written down as one.

---

## SQLite

**Trigger.** A single JSONL file passes roughly 100 MB, or the weekly review spends real time
parsing rather than thinking. Neither is close; years of check-ins are a few megabytes. When it
happens, SQLite replaces one file, not the architecture: files stay the interface for anything a
human reads.

---

## Push notifications

**Trigger.** Same as the phone app, and probably the same project.

**The caution.** A coach that nags is a coach that gets muted, and a muted system is a dead one.
The v1 stance, that the user opens the app, is not only a limitation: it is also what keeps the
check-in a choice rather than an obligation, which may be why it survives where previous systems
did not. Prove that wrong with the log before changing it.

---

## A third backup layer

**What.** An encrypted external drive holding a restic snapshot plus the encrypted secrets.
Protects against losing both cloud accounts at once.

**Trigger.** The primary restore drilled successfully twice. An untested third copy adds false
confidence rather than redundancy, and the offline key copy already covers the worst case.

---

## Multiple users

Not a future version. A different system. Everything here assumes one person, one threat model,
one set of goals, and instruction files personalised enough to count as personal data. A second
user changes the security model, the data model and the review, which is another way of saying
it is a rewrite.

---

## Rejected, with reasons

Kept because the same ideas resurface and the reason is the most useful thing to hand that future
conversation.

| Idea | Why not |
|---|---|
| **A custom model router** | Calling an API to pick a model bills outside the subscription. `--model`, set by rule in the script, is the mechanism. Settled unless the billing model changes |
| **git for config and skills** | Another system to secure and leak from, holding files personal enough to count as personal data. Snapshots give point-in-time recovery, the change ledger gives change history, and `conf/` is in the backup. Still the decision I am least comfortable with |
| **An orchestration framework** | Claude Code is the runtime. A framework adds a dependency, a failure mode and an upgrade treadmill to a system whose main virtue is that it is files and cron |
| **A web dashboard** | An inbound port, in a design whose first property is that nothing is listening. The data is files; read them over SSH |
| **Vector search over the notes** | The corpus is small enough for grep for years. Revisit when grep is genuinely too slow, which is measurable and not a feeling |
| **A model in a deterministic routine** | The ledger, the backup, the sweep and the observations are shell. A model adds cost, latency and a failure mode and buys nothing |
| **MCP servers** | In a `-p` session they connect with no trust dialog and no prompt. Each is a new trust relationship and a new supply chain |
| **Letting the system edit its own permissions after "enough trust"** | There is no amount of trust that makes this safe, because the property being protected is that compromise is contained. A system that can widen its own permissions has no permissions |
