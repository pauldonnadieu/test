# AIOS Build

Goals, in order, with a definition of done for each. Read `ARCHITECTURE.md` first for the shape and the reasoning.

---

## How to work

`WORKING.md` covers process in detail: sessions, plan mode, verification, adversarial review, context. Read it once before Stage 1. The essentials:

**Every stage ships an executable check.** Each `Done when` list below becomes a script under `verify/`, exiting non-zero on any failure. Write it alongside the work and iterate until it passes. A checklist a human reads leaves the user as the verification loop; a script closes the loop. These scripts persist afterwards as the security regression suite, so treat them as a deliverable rather than as build scaffolding.

**Show evidence, not assertions.** The script's output is the claim that a stage is done.

**One session per stage.** Context is the binding constraint. Start fresh, open with the stage goal rather than the whole document, and if the same mistake needs correcting twice, clear the context and restart with a sharper prompt.

**You own the how.** Each stage states an outcome and how to know it is achieved. The path is yours. Where this document describes a method it is offering a starting point, not a specification, and a better approach is a better approach.

**Verify rather than assume.** Tool versions, CLI flags, plan limits and provider behaviour drift. Anything specific here was true when written. Check before relying on it.

**Propose before anything large or hard to reverse.** A short plan, then build. Not a request for permission to proceed within a stage you have already been given.

**Say so when something looks wrong.** The decisions in `ARCHITECTURE.md` were made with incomplete information about this user's situation. If one is a poor fit for what you find, argue the case. They are context, not rules.

**Ask only where the answer changes the work.** Genuine ambiguity, or a choice that is the user's to make. Routine judgement calls are yours.

**Never weaken a constraint to make progress.** Constraints are marked as such and there are few of them. If one blocks the goal, the goal is blocked; say so and propose an alternative. Weakening a check so it passes is the one move that is never available.

**Write down what you decide.** `decisions/log.md`, append-only, with reasoning. This is what makes the reflection loop possible later.

---

## Stage 0: Ready to start

**Goal.** The accounts, credentials and recovery paths exist before anything is built on top of them.

**Done when.** Nothing to script here; this stage is a conversation. Hetzner and Tailscale accounts exist. An SSH keypair exists with a passphrase on the private key. The user can say, for each recovery credential the build will produce, where it will be stored.

**Constraint.** Generate nothing secret on the user's behalf without telling them exactly where it will live and how it is backed up.

**Worth knowing.** Only the user can create these accounts. This stage is a conversation, not a task.

---

## Stage 1: A host nobody can reach

**Goal.** A hardened Linux VPS that is invisible from the public internet and reachable only over Tailscale, with a break-glass path that does not depend on Tailscale working.

**Why this order.** Everything else runs on this. Hardening a machine that already holds personal data is worse than hardening an empty one.

**Done when** `verify/stage1-host.sh` passes. At minimum it checks:

- [ ] An external port scan finds nothing open
- [ ] SSH from the iPhone over Tailscale works
- [ ] SSH is key-only: no password auth, no root login
- [ ] Both UFW and the Hetzner Cloud Firewall default-deny inbound
- [ ] `ss -tulpn` shows no service bound to a public interface
- [ ] Unattended security upgrades are on
- [ ] `/srv/aios-data/` exists at 0700, owned by the AIOS user, as a local git repo with no remote
- [ ] A deliberate attempt to commit a fake API key is blocked by a pre-commit hook
- [ ] The user has used the Hetzner rescue console at least once and knows how to reach it

**Constraints.**

- Never disable a working access path before the replacement has been tested from the device that will use it. Lock-out here means the rescue console, and the user should have practised that before needing it.
- The git repository gets no remote. Ever. It exists for reversibility, not distribution.

**Decide with the user.** Region and instance size. A 2 vCPU / 4 GB shared instance is ample since the workload is API-bound, but confirm rather than assume.

**Worth knowing.** fail2ban earns its place only while public SSH is open. Once SSH is Tailscale-only it is another thing to maintain for no benefit; remove it rather than carry it.

---

## Stage 2: A disposable container holding durable data

**Goal.** Claude Code runs in a container that can be destroyed and rebuilt from source at any time, while everything personal survives on the host. A compromise of the container reaches `/data` and nothing else.

**Done when** `verify/stage2-container.sh` passes. At minimum it checks:

- [ ] `docker compose down && docker compose up -d` produces a working container with all data intact
- [ ] Claude Code answers a prompt from inside the container
- [ ] Claude Code authentication survives a rebuild, and how it does is written down
- [ ] From inside the container: no Docker socket, no host filesystem beyond `/data`, no path to host root, and `/etc/aios/secrets.env` is unreadable

**Constraints.**

- Non-root, with UID and GID matching the owner of `/srv/aios-data/`.
- No `--privileged`, no Docker socket mount, no host network mode, no host root mount.
- `no-new-privileges`, capabilities dropped to what is demonstrably needed, memory and CPU limits set.
- Only `/srv/aios-data/` is bind-mounted.
- Secrets are injected at runtime from a root-owned 0600 file outside the image. Never in the image, never in compose in plaintext, never inside `/data`.
- Base image and dependencies pinned to versions, never `latest`.

**Worth knowing.** Use plan mode for this stage: the security properties are the point and they are easy to get subtly wrong, so explore and plan before changing anything. When it is built, have a subagent in a fresh context try to break out of the container rather than grading your own isolation work.

Mismatched UIDs between the container user and the host directory owner is the most common way this stage goes wrong, and it presents as confusing permission errors rather than anything obvious. Set it explicitly. Claude Code authentication needs an interactive login the first time, which means a real terminal session rather than a script.

---

## Stage 3: A system the user can talk to from their phone

**Goal.** The AIOS exists as a working system with its operating instructions in place, reachable from the Claude iOS app, with every control that is supposed to stop it actually stopping it.

**Why this order.** Before connections and before scheduling, because a system that cannot be used cannot be evaluated, and a system that cannot be stopped should not be scheduled.

**Done when** `verify/stage3-core.sh` passes, plus the two things no script can check: the user holds a conversation with the AIOS from the Claude iOS app, and a tool call requiring approval prompts on the phone, executes when approved and is refused when denied.

At minimum the script checks:

- [ ] From a Remote Control session: `/etc/aios/secrets.env` unreadable, Docker socket unreachable, host root unreachable, and writes to `policy/` and `.claude/` blocked under the hook conditions
- [ ] A deliberate attempt to have a hook-blocked action approved from the phone still fails
- [ ] The kill switch works at all four layers, demonstrated not assumed
- [ ] An external port scan still finds nothing open
- [ ] `bin/aios` exists and every verb is read-only or append-only

**Worth knowing.** Plan mode earns its overhead here; this stage touches many files at once. When the hooks exist, have a subagent try to get a hook-blocked action approved from the phone. The session that wrote the hooks is the wrong thing to judge whether they hold.

**What needs to exist.** The filesystem layout from `ARCHITECTURE.md` Section 5. `CLAUDE.md` and the `policy/` files, drafted from `reference/` and adapted to what you find rather than copied. Hooks enforcing the destructive-action guards and the untrusted-content write guard. The `aios` CLI. Remote Control running inside the container under tmux, with a systemd unit so it survives reboots.

**Constraints.**

- Remote Control runs inside the container, never on the host. This is the boundary that contains an Anthropic account compromise.
- Default permission mode. Never `bypassPermissions`.
- `CLAUDE.md` loads on every session. Keep it short; detail belongs in `policy/`. If it passes roughly 150 lines, something is in the wrong file.
- Enforcement lives in hooks, not in prompts. Permission prompts do not defend against whoever holds the account, because they answer them.

**Decide with the user, before enabling Remote Control.** The Anthropic account becomes a credential that reaches the VPS. It needs a passkey or hardware key and no SMS second factor. Confirm this is done rather than assuming it.

**The kill switch, four independent layers.**

```
1. Pause         touch /srv/aios-data/.halt      scheduled runs check this first
2. Stop timers   systemctl stop aios-*.timer     interactive use continues
3. Full stop     docker compose down             data untouched
4. Cut remote    disableRemoteControl + revoke sessions
```

Layer 4 is for when the account rather than the machine is what is suspected. The user needs all four somewhere reachable from their phone without the AIOS.

---

## Stage 4: A system that knows who it is working for

**Goal.** The AIOS holds an accurate, specific picture of the user's goals, constraints, history and the people around them, with every claim marked as either something they confirmed or something you inferred.

**Why this matters more than any other stage.** Everything downstream is reasoning over this. A generic picture produces generic coaching, which is worse than none because it wastes the user's attention.

**Done when** the judgement calls below hold. `verify/stage4-context.sh` covers only the mechanical part: every file has valid provenance front matter, and active goals number five or fewer.

- [ ] The user reads `context/user.md` and the goal files and says the system understands their situation
- [ ] At least one thing in there mildly surprises them: true, but not previously articulated
- [ ] Every file carries provenance front matter, with `confirmed` and `inferred` used honestly
- [ ] Five or fewer active goals, each with a next action small enough to do this week

**How to run it.** An interview, not a form, and there is a documented pattern for exactly this: use `AskUserQuestion`, dig into the hard parts rather than the obvious ones, keep going until the ground is covered, write the result out, then **start a fresh session** to act on it so the implementation has clean context and a written artefact to work from.

 Cover who they are and the shape of a normal week; the goals across business, health, money, career, development, family and habits; the constraints, in specifics rather than adjectives, since "busy" is not a constraint but "no discretionary time between 6am and 8pm on weekdays" is; the history of what has repeatedly failed and how many times; the people who matter; and the lines the AIOS must never cross.

Then read it back and let them correct it. Log the corrections.

**Constraints.**

- Never invent a fact about the user. A gap stays a gap until they fill it.
- Their theory about why something failed is `inferred`, not `confirmed`, however confidently they state it.

---

## Stage 5: Rituals that survive a bad week

**Goal.** The daily check-in, daily brief, time and energy capture, and weekly review all exist and have proven they work by being used manually for a week.

**Why this order.** Automating a ritual that does not work manually just makes it fail on a schedule. The week of manual use is where you find out the check-in is too long or the brief says nothing useful.

**Done when** `verify/stage5-rituals.sh` passes, which checks that the data exists rather than that it is any good, plus the last item, which only the user can answer:

- [ ] Seven consecutive daily check-ins recorded
- [ ] At least a week of time blocks logged
- [ ] One weekly review produced
- [ ] The user read that weekly review voluntarily, without being reminded

**The bar for each.** The check-in is thirty seconds or it stops happening. The brief fits one screen and says nothing when there is nothing to say. The weekly review finds one pattern a single day could not show, names one bottleneck rather than a list, and is allowed to conclude that nothing needs changing.

**Constraints.**

- Time and energy are self-reported; there is no wearable here. Capture has to be one tap or one short command. A form is the same as no data.
- Nothing classified `sensitive` or above goes in the daily brief, since `aios brief` is readable from any device.

**Decide with the user at the end.** Which connection comes first. Calendar read-only is the highest signal per unit of risk. Email is valuable and is also the main prompt-injection vector, so it stays read-only for longer than feels necessary.

---

## Stage 6: Work that happens without being watched

**Goal.** The rituals run on a schedule, failures are visible rather than silent, and any failed run can be reconstructed afterwards.

**Done when** `verify/stage6-scheduling.sh` passes. At minimum it checks:

- [ ] A deliberately broken run can be replayed from `runs/` and the exact failing tool call identified
- [ ] The weekly audit runs unattended and reports
- [ ] A review of `runs/` finds no credentials, tokens or document contents

**What good looks like.** Scheduled work invokes `bin/aios` rather than embedding prompts in unit files, so there is one place logic lives. Unattended runs get an explicit tool allowlist rather than the full tool surface, because a job that reads `checkins/` and writes one file has no business being able to do more. Every run is bounded: retries with backoff, a time budget, a loop counter, and a clean logged failure when exhausted. Every outward action has backpressure ahead of it: validated inputs, a dry-run path, an explicit check that it actually worked.

**Constraints.**

- Never a silent failure.
- Structured events in logs, never payloads.
- The kill switch must already work (Stage 3) before anything is scheduled.

**Decide with the user first.** Scheduled-run authentication. Pro's limits will bind on a system running this many recurring jobs, and hitting them mid-week while nobody is watching is the failure mode. The options and their trade-offs are in `ARCHITECTURE.md` Section 8.

**Worth knowing.** Most incidents in systems like this are tool-call failures, context truncation and runaway loops rather than model errors. Instrument the tool boundary and the loop; instrumenting the prompt tells you little.

---

## Stage 7: Survivable

**Goal.** The entire system can be rebuilt from Google Drive plus the password manager, by someone who no longer has the original VPS, and this has been proven rather than assumed.

**Why this is not last.** A system holding this much irreplaceable personal context should not run for a week without a tested restore.

**Done when** `verify/stage7-recovery.sh` passes on the rebuilt machine, and:

- [ ] A fresh VPS was rebuilt from Drive and the password manager alone
- [ ] The restored AIOS answered a question using restored personal context
- [ ] `RECOVERY.md` was corrected based on what actually went wrong during that rebuild
- [ ] Backup failures alert; successes are silent
- [ ] The rebuild package has been explicitly scanned and contains no secrets and no personal data

**Constraints.**

- Google Drive receives encrypted data only.
- No decryption password is ever stored beside the data it unlocks.
- The rebuild package is safe unencrypted, which is only true if it has been checked rather than assumed.

**Worth knowing.** Plan mode before writing `RECOVERY.md`, because the procedure has to be right before it is tested rather than discovered during the test. Have a subagent read the rebuild package specifically looking for secrets and personal data; a fresh reader catches what a familiar one skims.

**The one step not to skip.** The recovery test on a real throwaway VPS, following `RECOVERY.md` literally and improvising nothing. Improvising is how a recovery document stays broken. Every step that turns out to be missing is the point of the exercise.

**Worth knowing.** A backup that has never been restored is a hypothesis. Hetzner snapshots are a convenience layer for whole-machine rollback, not a substitute for an independent encrypted copy.

---

## Stage 8: A system that improves itself without promoting itself

**Goal.** The AIOS proposes improvements to its own configuration, keeps its own memory clean, and reports when its tooling has moved, all as proposals the user approves.

**Done when** these hold. Not scriptable; the whole point is whether the output is worth anything:

- [ ] The system proposes a config change the user accepts on its merits, having judged it genuinely good rather than accepting it to be agreeable
- [ ] The first wiki lint surfaces a real contradiction
- [ ] The first research digest surfaces something the user would otherwise have missed

**Build order.** Reflection pass, then wiki lint, then archive sweep, then research agent. Each produces proposals in `proposals/`, never applied changes, until it has a track record the user trusts.

**Constraint, and it is the important one.** Self-improvement is never self-authorisation. The system may improve its methods, workflows and tooling. It may never treat "I would perform better with more privileges" as an argument for having them. If a control blocks a capability, the capability does not get built, or gets built differently, and the blocked attempt is logged.

---

## After v1

Not scheduled. `EXTENSIONS.md` covers the companion app, adding connections, device automation and a third backup layer. None of it should start until the core has run for a month in real daily use, because a month of check-ins and time logs tells you which of them is actually worth building.

---

## The whole-system definition of done

The build is complete when the stage criteria above all pass and the following hold. Demonstrated, not assumed.

**Nothing is reachable.** External scan clean. SSH key-only over Tailscale. Both firewalls default-deny. No service on a public interface. Rescue console tested.

**Nothing escalates.** Container non-root with matched UID, no socket, no host filesystem, resource-limited. A Remote Control session cannot read secrets, reach the Docker socket, or become host root. Hooks block destructive actions regardless of what is approved from a phone.

**Nothing leaks.** No secret inside `/data`. Secrets injected at runtime from outside the image. Pre-commit scanning proven with a deliberate test. Logs carry events, not contents. External content quarantined and enveloped.

**Nothing is lost.** Encrypted restic snapshots on Drive with keys held separately. Secrets encrypted independently. A full recovery performed on a fresh VPS and `RECOVERY.md` corrected from it.

**Nothing acts alone.** Every capability at level 0 or 1 at launch. High-risk actions confirmed explicitly. The kill switch works at four layers.

**And it is actually used.** Seven daily check-ins. A week of time blocks. A weekly review the user read because they wanted to.

That last line is the one that matters. The rest is what makes it safe to want.

**`verify/all.sh` runs every stage check and exits non-zero on any failure.** Wire it into the weekly audit in Stage 6. Every property above is something that can silently stop being true after an unrelated change months later, and a script is how that gets noticed.
