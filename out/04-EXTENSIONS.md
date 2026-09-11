# AIOS Extensions

What to build after the core works. Nothing here is v1.

**One piece of advice governs the document:** none of this is worth starting until the core has run a month in real daily use. A month of check-ins and time logs tells you which of these is actually worth building. Guessing beforehand produces features nobody opens.

---

## 1. The phone control panel

### 1.1 Why it exists

Four things the AIOS cannot do and no VPS can:

1. **Run a timer.** A Pomodoro countdown lives on the device.
2. **Fire a chime.** A server in Germany cannot make a phone in Australia vibrate on schedule.
3. **Make capture fast.** Time and energy are self-reported with no wearable, so capture friction decides whether the coaching data exists at all. A button is the difference between data and no data; a form is the difference between data and abandonment.
4. **Show a trend.** A chat surface can state a finding. It cannot let you scrub a week.

```
PHONE                          VPS
timers, alarms, chimes         the data of record
one-tap capture                goals, patterns, memory
task checkboxes                bottleneck analysis
trend views                    the weekly review
local offline state            the coaching
```

### 1.2 What it must not do

Scope discipline is what makes it finishable. It must not become the source of truth, replicate any coaching or analysis, include a chat interface (Remote Control already does that better), hold any credential beyond one revocable device token, or store anything classified sensitive or above.

A feature request that breaks one of these belongs in the AIOS, not the app.

### 1.3 Build phases

Ship each before starting the next.

**Phase 1: capture.** Highest value, smallest. Two screens. A time block with a big start button, a kind selector (focus, meeting, admin, break, interrupt, commute), an optional label and goal, a stop button, and five energy buttons on stop. Plus a standalone energy screen: five buttons, one tap, dismissed. That alone feeds the weekly review with everything the coaching layer has been missing.

**Phase 2: Pomodoro.** A 25/5 timer writing the same time-block record, with a local notification at each interval. A completed 25-minute focus block is a finished pomodoro; the data model already covers it.

**Phase 3: tasks.** A checklist reading and writing `tasks/active.md`. Check, add, reorder. It is a list, not a task manager.

**Phase 4: trends.** Read-only views of what the weekly review already computes. Focus-block completion by hour. Energy across the week. Time by goal. Office days against everything else.

Phase 4 is deliberately last. The analysis does not need an app, it needs data, and the weekly review can state these findings in prose from Phase 1 onward.

### 1.4 Alarms, honestly

A local notification is fine for a Pomodoro chime. It is **not** a reliable alarm: iOS notifications respect silent and Focus modes without Apple's Critical Alerts entitlement, which a personal app will not get. Android is more permissive but has its own battery-optimisation problems. Use the app for interval chimes and the system Clock app for waking up. Do not spend a week fighting the platform.

### 1.5 How it talks to the AIOS

This reverses something the core deliberately avoided, so pay it consciously.

The core has **no listening service**. Remote Control dials out, which is why v1 has no inbound surface at all. The app cannot work that way: a timer needs to POST a completed block, not hold a conversation about one.

So the app is why an HTTP API returns. Keep the surface as small as it can be:

- **A data API, not an agent API.** CRUD over the existing schemas. No chat, no streaming, no prompts, no tool execution. POST a time block, POST an energy observation, GET and PATCH the task list, GET the brief, GET computed trends. Auditable in an afternoon.
- **Bound to the Tailscale interface only.** Never `0.0.0.0`. Verify from outside the tailnet that it does not respond.
- **A per-device bearer token**, in `/etc/aios/` and never in `/srv/aios-data/`, revocable individually so a lost phone is one line deleted.
- **Runs in the container**, same user, same `/data` confinement.
- **Writes through `bin/aios`** rather than touching files directly, so there is one write path and one set of rules rather than two that drift.
- **Logged to `runs/`** like every other state change.

Anything beyond that list is scope creep and should be refused.

### 1.6 Offline first, non-negotiable

Tailscale will drop. The phone will be in a lift or out of coverage. A timer that fails when the network does is worse than no timer, because it loses the block in progress.

Every capture writes to a local store immediately and enters a sync queue. The queue drains when the API is reachable. Conflicts resolve by append, because the time and energy schemas are append-only event streams and ordering lives in the timestamps rather than in arrival order. That choice was made partly for this.

### 1.7 Technology, with no Mac

**Expo and React Native.** One codebase for iOS and Android, local notifications well supported, TypeScript so Claude Code is effective in it.

**You do not need a Mac.** Expo's cloud build service compiles signed iOS apps on their own macOS infrastructure, so you develop on Windows or Linux and never touch one. Android builds locally on anything. A macOS VM is legally grey and practically painful; do not go there. Verify current free-tier build limits before relying on them.

Alternatives, and why not: native Swift gives the best widgets and timers and would win for iOS alone, but doubles the work at Android and needs a Mac throughout. A PWA is wrong specifically because of the timers, since iOS restricts background execution and web push in ways that make a reliable Pomodoro hard, which is the one thing this exists to do.

**Prerequisites to flag:** an Apple Developer account, roughly 99 USD a year, for TestFlight or device installs lasting beyond seven days. Tailscale always-on on any device running the app.

### 1.8 Done when

**Phase 1** is done when a week of blocks and energy captured entirely through the app appears in the weekly review and produces a finding you had not noticed. Not when the screens look right.

**Phase 2** is done when a pomodoro survives the phone locking, the app backgrounding and the network dropping mid-block.

**Phase 3** is done when you have run a week without opening `tasks/active.md` any other way.

**Phase 4** is done when it shows you something you disagree with and the underlying data settles the argument.

**Every phase** ends with a lost-phone test: revoke the device token, confirm the app can no longer read or write, confirm the AIOS still works.

---

## 2. The scraping pipeline

Sources and volume are yours to define. The security shape is fixed regardless of what you scrape, and it is in `03-OPERATING.md` §5. The summary here is what the pipeline looks like structurally.

```
fetch  ->  quarantine (scrape.db, raw, enveloped, provenance)
       ->  summarise  (no tools, no write access beyond its own row)
       ->  summary    (still external-trust, never promoted to fact)
       ->  compile    (into wiki/, on demand, with citation back to source)
```

**Three properties to preserve as it grows.**

Quarantine survives the whole pipeline, not just the landing. The taint does not wash off at the summarisation step.

The summariser has no tools. A successful injection can then produce bad text, which is recoverable, rather than take an action, which may not be.

Compile once. The wiki layer exists so the same content is never re-summarised, which is both the cost lever and the context-rot defence.

**Storage.** SQLite in `/data`, not a database server, until SQLite actually breaks. A server is a service, a credential, a backup requirement and a failure mode.

**Volume discipline.** Bulk summarisation is the single most likely thing to exhaust a Pro allowance. Put it on a free tier, which is safe for public scraped text and unsafe for anything personal. Rate-limit the fetcher. Alert on outbound volume, because a scraper that loops looks exactly like exfiltration.

---

## 3. Adding a connection

One at a time, each fully settled before the next.

**Answer in writing before connecting anything,** and put the result in `policy/dataflow.md`: what data can it reach, what credentials does it receive and where do they live, what does it send out, can it write or delete or only read, can it trigger actions, can its access be narrowed, can the credential be revoked independently, does the provider retain data, what happens if it is compromised.

**Then:** start read-only as the default that has to be argued out of, not a phase to pass through quickly. Start at autonomy level 0 or 1 regardless of how safe it looks. Everything retrieved lands in quarantine with provenance and enters context enveloped. One credential, one purpose, revocable alone.

---

## 4. A third backup layer

The core has two: encrypted snapshots on Drive, and Hetzner's whole-machine snapshots. A third, offline, protects against losing or having both cloud accounts compromised at once.

Simplest useful form: an encrypted external drive holding a restic snapshot plus the encrypted secrets file, updated on a schedule you will actually keep. Keys stay in the password manager and ideally on paper somewhere physical.

Do not build this before the primary restore has been tested. An untested third copy adds false confidence rather than redundancy.

---

## 5. Anything else

Run the question set before adding anything: what problem does this solve, can the existing system solve it, can a script solve it, what does it cost, what permissions does it need, what security risk does it add, what maintenance does it create, what happens when it fails, can it be removed easily, is the benefit measurable.

Every additional service is another attack surface, another credential, another configuration, another backup requirement and another failure mode. The system exists to reduce your load. Something that needs maintaining is load.
