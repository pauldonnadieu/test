# Extensions

What to build after the AIOS core works, and how. Nothing here is part of v1. Everything here is guidance for Claude Code when the user says "now build X".

**One piece of advice governs this whole document:** nothing here is worth starting until the core has run for a month with real daily use. Not process discipline for its own sake. A month of check-ins and time logs tells you which of these is actually worth building, and guessing before that produces features nobody opens.

As with `BUILD.md`, what follows is goals and constraints. Where it describes an approach, that is a starting point and a better one is better.

---

## 1. The companion app

The largest extension and the one the user wants most.

### 1.1 What it is for

The AIOS cannot do four things, and no VPS can:

1. **Run a timer.** A Pomodoro countdown has to live on the device.
2. **Fire an alarm or chime.** A server in Germany cannot make a phone in Australia vibrate on a schedule. Only software on the handset can.
3. **Make capture fast.** Time and energy are self-reported here, with no wearable. That makes capture friction the binding constraint on whether the coaching data exists at all. A button is the difference between data and no data; a form is the difference between data and abandonment.
4. **Show a trend.** A chat surface can state a finding. It cannot let you scrub a week.

Everything else stays on the VPS. The app is a **capture and display surface**, not a second brain.

```
APP (phone)                    AIOS (VPS)
timers, alarms, chimes         the data of record
one-tap capture                goals, patterns, memory
task checkboxes                bottleneck analysis
trend views                    the weekly review
local offline state            the coaching
```

### 1.2 What it must not do

Scope discipline here is what makes it finishable. The app must not:

- become the source of truth (the VPS is; the app holds a local cache and a sync queue);
- replicate any coaching, analysis or reasoning (that is the AIOS's job and it is the whole point of the AIOS);
- include a chat interface (Remote Control already does that, better);
- hold any credential beyond a single revocable device token;
- store anything classified `sensitive` or above.

If a feature request would break one of these, it belongs in the AIOS, not the app.

### 1.3 Feature phases

Build in this order, ship each one before starting the next.

**Phase 1: capture.** The highest value and the smallest. Two screens.

- Time block: a big start button, a kind selector (`focus` `meeting` `admin` `break` `interrupt` `commute`), an optional label and goal, and a stop button. On stop, prompt for energy with five buttons.
- Energy: five buttons, nothing else. One tap, dismissed.

That is it. This alone feeds the weekly review with everything the coaching layer has been missing.

**Phase 2: Pomodoro.** A 25/5 timer over the same time-block record, with a local notification at the end of each interval. A completed 25-minute `focus` block with `completed: true` is a finished pomodoro; the data model already covers it and needs no new fields.

**Phase 3: tasks.** A checklist reading and writing `tasks/active.md`. Check, add, reorder. Nothing more; it is a list, not a task manager.

**Phase 4: trends.** Read-only views of what the weekly review already computes. Focus-block completion by hour of day. Energy across the week. Time by goal. Office days against everything else.

Phase 4 is deliberately last. The analysis does not need an app; it needs data. The weekly review can state these findings in prose from Phase 1 onward, and building the charts first would be building the display before there is anything to display.

### 1.4 Alarms, honestly

Worth knowing before anyone builds this. A local notification is fine for a Pomodoro chime. It is **not** a reliable alarm: iOS notifications respect silent mode and Focus modes unless the app has Apple's Critical Alerts entitlement, which requires a special request and is unlikely to be granted for a personal app. Android is more permissive but has its own battery-optimisation problems.

So: use the app for interval chimes, and the system Clock app for anything that has to wake someone up. Do not spend a week fighting the platform on this.

### 1.5 How it talks to the AIOS

This is the significant architectural decision, and it reverses something the core build deliberately avoided.

The core has **no listening service** on the VPS. Remote Control works by dialling out, which is why v1 has no open port and no inbound surface at all. The app cannot work that way: a Pomodoro timer needs to POST a completed block, not hold a conversation about it.

**So the app is the reason the HTTP API comes back.** That is a real cost and it should be paid deliberately, with the surface kept as small as it can be:

- **A data API, not an agent API.** CRUD over the schemas in `reference/SCHEMAS.md`. No chat, no streaming, no prompts, no tool execution. Roughly: POST a time block, POST an energy observation, GET and PATCH the task list, GET the brief, GET computed trends. That is a surface small enough to audit in an afternoon.
- **Bound to the Tailscale interface only.** Never `0.0.0.0`. Verify from outside the tailnet that it does not respond.
- **A per-device bearer token**, stored in `/etc/aios/` and never in `/srv/aios-data/`, revocable individually so a lost phone is one line deleted.
- **Runs in the container**, same user, same `/data` confinement as everything else.
- **Writes through the same validation** as the CLI. Ideally it calls `bin/aios` rather than touching files directly, so there is one write path and one set of rules, not two that drift.
- **Logged to `runs/`** like every other state change.

Anything beyond that list is scope creep and should be refused.

### 1.6 Offline first, non-negotiable

Tailscale will drop. The phone will be in a lift, on a plane, or out of coverage. A timer that fails when the network does is worse than no timer, because it loses the block that was in progress.

So the app owns local state and syncs opportunistically: every capture writes to a local store immediately and enters a sync queue; the queue drains when the API is reachable; conflicts resolve by append, since the schemas are append-only event streams and the ordering is carried in the timestamps rather than in arrival order. This is why the time and energy schemas are JSONL rather than a mutable document. That choice was made partly for this.

### 1.7 Technology

The user wants iOS first and Android eventually.

**Recommendation: React Native via Expo.** One codebase covers both platforms, local notifications are well supported, the ecosystem handles the build and distribution plumbing, it is TypeScript so Claude Code is highly effective in it, and most development does not require a Mac.

The alternatives, and why not: **native Swift and SwiftUI** gives the best timers, widgets and Live Activities, and would be the right call for iOS alone, but it doubles the work when Android arrives and requires a Mac throughout. **Flutter** is comparable to React Native here with a smaller advantage for Claude Code. **A PWA** is the wrong tool specifically because of the timers: iOS restricts background execution and web push in ways that make a reliable Pomodoro hard, which is the one thing this app exists to do.

**Prerequisites to flag before starting:** an Apple Developer account at roughly 99 USD per year is needed for TestFlight or for device installs that last longer than seven days. Android side-loading is free. Tailscale must be installed and set to always-on on any device running the app.

### 1.8 Done when

**Phase 1** is done when a week of time blocks and energy observations, captured entirely through the app, appears in the weekly review and produces a finding the user had not noticed. Not when the screens look right.

**Phase 2** is done when a pomodoro survives the phone being locked, the app being backgrounded, and the network dropping mid-block.

**Phase 3** is done when the user has run a week without opening `tasks/active.md` in any other way.

**Phase 4** is done when it shows the user something they disagree with, and the underlying data settles the argument.

**Every phase** ends with a lost-phone test: revoke the device token, confirm the app can no longer read or write anything, and confirm the AIOS still works.

---

## 2. Adding a connection

The AIOS reaching calendar, email, a task service or anything else. One at a time, each fully settled before the next.

**Goal.** The AIOS can use the connection for something specific and valuable, and a compromise of it reaches nothing beyond its own scope.

**Done when.** A data-flow record exists in `connections.md`; the credential is scoped to this one purpose and independently revocable; everything retrieved lands in `raw/untrusted/` with provenance; and the capability is at autonomy level 0 or 1.

**Before connecting anything, answer these in writing** and put the result in `connections.md`:

1. What data can it access?
2. What credentials does it receive, and where do they live?
3. What does it send externally?
4. Can it write or delete, or only read?
5. Can it trigger actions?
6. Can its access be narrowed?
7. Can the credential be revoked independently?
8. Does the provider retain data?
9. What happens if it is compromised?

**Then:**

- Start read-only. Not as a phase to move past quickly, as the default that has to be argued out of.
- Start at autonomy level 0 or 1 regardless of how safe it looks.
- Everything it retrieves lands in `raw/untrusted/` with provenance, and enters context inside an envelope. This is not optional and email is precisely why: it is the one input channel where an attacker can put arbitrary text in front of the agent at will.
- Record the data flow. Source, processing, storage, what reaches a model, what reaches a backup, retention.
- Never grant a connection a credential that also opens something else. One credential, one purpose, revocable alone.

**Suggested order,** if the user has no strong preference: calendar first, because it is the highest signal per unit of risk and it drives the brief. Email second and read-only for a long time. A task service probably never, given `tasks/active.md` already exists and a second source of truth costs more than it returns.

---

## 3. Shortcuts and device automation

Possible, not planned. Only worth building once the daily rituals are established, so the shortcuts get built around what actually happens rather than what was imagined.

- **iOS Shortcuts** has a built-in Run Script Over SSH action, so over Tailscale it needs no listening service. Gives Siri voice triggering, which makes voice capture while commuting viable.
- **Android** has no first-party equivalent; its automation apps are HTTP-shaped and would use the same API the companion app uses.

Both wrap `bin/aios` rather than reimplementing anything.

**If built:** a dedicated key per device, pinned by a forced command in `authorized_keys` with an allowlist wrapper that logs every invocation. A stolen phone then yields note capture, not a shell. Only read-only and append-only verbs are ever exposed.

Note that the companion app makes most of this redundant. If the app exists, shortcuts are worth it only for voice capture and for triggering from contexts the app cannot reach, such as a car Bluetooth connection.

---

## 4. A third backup layer

The core has two: encrypted restic snapshots on Google Drive, and Hetzner's whole-VPS snapshots. A third, offline, encrypted copy protects against the case where both cloud accounts are lost or compromised at once.

Simplest useful form: an encrypted external drive, updated by hand on a schedule the user will actually keep, holding a restic snapshot plus `aios-secrets.enc`. The encryption keys stay in the password manager, and ideally also on paper somewhere physical.

Do not build this before the primary restore has been tested. An untested third copy adds a false sense of security rather than actual redundancy.

---

## 5. Anything else

Run the question set before adding anything at all: what problem does this solve, can the existing system solve it, can a script solve it, what does it cost, what permissions does it need, what security risk does it add, what maintenance does it create, what happens when it fails, can it be removed easily, is the benefit measurable.

Every additional service is another attack surface, another credential, another configuration, another backup requirement and another failure mode. The system is supposed to reduce the user's load. Something that needs maintaining is load.
