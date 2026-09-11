# 05 - After v1

Everything here is deferred. Each item has a **trigger condition**: the specific thing that
would make it worth doing. Parking without a trigger is forgetting with extra steps.

Read this when you are tempted to add something to v1. Most of the time the answer is that it
already has a home here and a condition that has not been met.

---

## Time, sleep and the shape of the day

**What.** Two or three extra fields in the daily check-in: hours slept, and a one-line
description of where the day's hours actually went (office or home, meetings or focus, what
displaced what). Not a tracker, not an app, not a timer. One more line, answered while
standing up.

**Why it is not in v1.** The user has chosen to add this once the habit itself has held. That
is the right order and worth stating why rather than treating it as a delay: a system that
captures more than the user sustains gets abandoned with more of their life inside it, and the
first thing to prove is that the thirty-second version survives contact with a bad month.

**What v1 gives up by not having it.** This is the honest cost, and it is real. The finding
that makes this class of system worth running looks like "four missed sessions in three weeks,
all evenings, all office days: the pattern is location, not motivation". That inference needs
to know *when* things happened and *what the day contained*. Without any time signal the weekly
review can pattern-match on prose alone, which works for recurring language and not for
recurring circumstances. Expect the reviews to name themes accurately and to be weaker at
naming causes.

**Trigger.** Two consecutive weekly reviews name "I can see that this keeps happening and I
cannot see what it has in common" as the limiting factor. At that point the cost of the extra
line is obviously less than the cost of the blind spot, and the habit has survived long enough
to take it.

---

## The daily brief

**What.** One screen in the morning: what is on today that needs preparation and the
preparation already done; the one thing that matters most and why; anything approaching that
becomes a problem if ignored; anything awaiting approval; anything it got wrong yesterday and
has corrected. No motivation, no summary of its own activity. If there is nothing worth saying,
one line saying so.

**Why not in v1.** The brief is the proactive half of the system and v1 is deliberately
retrospective. It is also the half that needs to know what is in the day, which without a
calendar connection means the user telling it, which is a second daily interaction competing
with the check-in. Two daily touchpoints is how you end up with neither.

**Trigger.** The check-in habit has held above twelve of fourteen days for eight consecutive
weeks, **and** the user has said unprompted that they wanted to know something in the morning
that the system knew. Both conditions, not either.

---

## The phone app

**What.** A small React Native app via Expo: timers, alarms, local notifications, fast capture.
The division of labour is the point: **the phone owns timers, alarms and capture; the VPS owns
data, memory and analysis.** A phone that tries to hold the data becomes a second source of
truth, and two sources of truth is none.

**No Mac is not a blocker.** Expo's cloud build service compiles signed iOS builds on their own
macOS infrastructure. The free tier includes a limited number of iOS builds per month, which is
ample for a personal app that ships rarely. A macOS VM is legally grey and practically painful;
the cloud build path avoids it entirely.

**What it does still cost.** An Apple Developer Program membership (USD 99/year) for anything
installed beyond a development build's short expiry. That is roughly a third of the entire
annual running budget, so it is a real decision and not a footnote.

**Trigger.** The daily check-in habit fails *specifically because* opening the Claude app is
too much friction, and that has been demonstrated in the check-in log, not assumed. If
coverage is fine, the app is a project, not a need.

**Do not build it earlier because it sounds like the interesting part.** It is the interesting
part. That is the problem.

---

## Connections: calendar and email

**What.** Read-only calendar to know what the week actually contained. Email is a much larger
step.

**Why v1 has neither.** A connection is a permanent inbound flow of untrusted content into a
system that holds the most sensitive data in the user's life. Every calendar invite is
attacker-controlled text with a title, a description and a location field. That is the
untrusted-content problem arriving daily and automatically, and `01-architecture.md` section 5
is honest that the defence is about reach and provenance, not detection.

**Trigger (calendar).** Three consecutive weekly reviews name "I don't know what was actually
in your week" as the limiting factor on the analysis. Then: read-only, through the quarantine
pipeline, treated as untrusted from the moment it lands, never promoted to fact. Note that the
time-capture item above is the cheaper answer to the same problem and should be tried first.

**Trigger (email).** None yet. Email is the highest-volume untrusted-content firehose available
and the least necessary for the loop. If it ever happens, it is a fresh design with its own
threat model, not an extension of this one.

**Whatever the connection, it arrives at propose-only.** The cap in `03-operations.md` section
4 on money, employer systems, other people's data and messages sent on the user's behalf is not
waived by a connection existing.

---

## Android

**Trigger.** The user carries an Android device as a primary phone.

Expo builds for both, so this is mostly free once the app exists. The reason to note it is that
it should not influence any v1 decision. Nothing in the current design is iOS-specific except
the choice of Remote Control client, which is available on both.

---

## Local models

**What.** A small local model for mechanical work: parsing a check-in into fields, classifying
where a note goes.

**Why not in v1.** A 4 GB VPS has no room for a useful model alongside everything else, and
Haiku already does this work inside the subscription at no marginal cost. Adding a local model
buys independence the system does not currently need, at the cost of memory it does not have.

**Trigger.** Either the Pro subscription stops covering the routine load, visible as repeated
usage-limit failures in the run records rather than as a hunch, or a genuine requirement
appears that some category of data must never leave the machine. The second is a stronger
reason than the first.

**If it happens**, the VPS needs more memory, and that is a budget conversation before it is a
technical one.

---

## SQLite

**Trigger.** A single JSONL file passes roughly 100 MB, or the weekly review spends real time
parsing rather than thinking.

Neither is close. Years of daily check-ins are a few megabytes. When it does happen, SQLite
replaces one file, not the architecture: files stay the interface for anything a human reads.

---

## Push notifications

**What.** The system reaching out rather than waiting to be opened.

Remote Control can send push notifications to the phone when a long task finishes or a decision
is needed. That is not a reminder system, and using it as one would be a misuse of a mechanism
built for something else.

**Trigger.** Same as the phone app, and probably the same project.

**The design caution.** A coach that nags is a coach that gets muted, and a muted system is a
dead one. The v1 stance, the user opens the app, is not only a limitation. It is also the thing
that keeps the daily check-in a choice rather than an obligation, which may be why it survives
where previous systems did not. Prove that wrong with the log before changing it.

---

## A third backup layer

**What.** An encrypted external drive holding a restic snapshot plus the encrypted secrets,
updated on a schedule you will actually keep. Protects against losing both cloud accounts at
once.

**Trigger.** The primary restore has been drilled successfully twice. An untested third copy
adds false confidence rather than redundancy, and the offline key copy already covers the
worst case that matters.

---

## Multiple users

Not a future version. A different system. Everything here assumes one person, one threat model,
one set of goals, and instruction files personalised enough to count as personal data. Adding a
second user changes the security model, the data model and the review, which is another way of
saying it is a rewrite.

---

## Rejected, with reasons

Kept because the same ideas will resurface and the reason is the most useful thing to hand that
future conversation.

| Idea | Why not |
|---|---|
| **A custom model router** | Calling APIs directly to pick a model bills outside the Pro subscription. `--model`, set by rule in the cron script, is the routing mechanism. Settled, and should not be revisited without the billing model changing |
| **git for config and skills** | Another system to secure and leak from, holding files personal enough to count as personal data. Snapshots give point-in-time recovery; the change ledger gives change history. This remains the decision I am least comfortable with, and the ledger plus backing up `conf/` is the compensation |
| **An orchestration framework** | Claude Code is the runtime. A framework on top adds a dependency, a failure mode and an upgrade treadmill to a system whose main virtue is that it is files and cron |
| **A web dashboard** | An inbound port, in a design whose first property is that nothing is listening. The data is files; read them over SSH |
| **Vector search over the notes** | The corpus is small enough for grep for years. Revisit when grep is genuinely too slow, which is a measurable condition and not a feeling |
| **A model in a deterministic routine** | The change ledger, the backup and the security observations are shell. Putting a model in any of them adds cost, latency and a failure mode and buys nothing |
| **Letting the system edit its own permissions after "enough trust"** | There is no amount of trust that makes this safe, because the property being protected is that compromise is contained. A system that can widen its own permissions has no permissions |
