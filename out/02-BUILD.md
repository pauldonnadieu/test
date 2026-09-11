# AIOS Build

Eight goals in order. Each states an outcome, how to know it is met, and the constraints that hold. Read `01-ARCHITECTURE.md` first.

---

## How to work

**You own the how.** These are outcomes, not instructions. Where a method is described it is a starting point and a better one is better.

**Every stage ships an executable check.** Each `Done when` list becomes a script under `/opt/aios-verify/`, exiting non-zero on any failure. Write it alongside the work. A checklist a human reads leaves the user as the verification loop; a script closes the loop. These scripts are not scaffolding, they are the ongoing health check.

**Show evidence, not assertions.** The script's output is the claim that a stage is done.

**One session per stage.** Context is the binding constraint. Open with the stage goal, not the whole document. If the same mistake needs correcting twice, clear the context and restart with a sharper prompt rather than accumulating failed approaches.

**Use plan mode** where a wrong approach is expensive: the container boundary, the core build, the recovery procedure.

**Let something else grade security work.** A subagent in a fresh context sees the result and the criteria, not the reasoning that produced them. Use one to try to break out of the container, to get past the hooks, and to find secrets in the rebuild package. Tell it to report only gaps that affect correctness; a reviewer asked for problems will invent them.

**Never weaken a check to make it pass.** The one move that is never available. If a check blocks the goal, the goal is blocked; say so.

**Verify rather than assume.** Tool versions, CLI flags and plan limits drift. Anything specific here was true when written.

**Record decisions** in `decisions/log.md`, append-only, with reasoning.

---

## The check harness

```bash
# /opt/aios-verify/lib.sh
set -uo pipefail
_PASS=0; _FAIL=0; _SKIP=0; _FAILED=(); _SKIPPED=()

check() {                      # check <name> <description>, body on stdin
  local name="$1" desc="$2" out rc
  out=$(bash 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    _PASS=$((_PASS+1)); printf '[PASS] %-30s %s\n' "$name" "$desc"
  else
    _FAIL=$((_FAIL+1)); _FAILED+=("$name")
    printf '[FAIL] %-30s %s\n' "$name" "$desc"
    [ -n "$out" ] && printf '       %s\n' "$out" | head -5
  fi
}

skip() {                       # a skip is never a pass; an unrun check is an unknown
  _SKIP=$((_SKIP+1)); _SKIPPED+=("$1")
  printf '[SKIP] %-30s %s\n' "$1" "$2"
}

summary() {
  local total=$((_PASS+_FAIL+_SKIP))
  echo; echo "SCORE ${_PASS}/${total} $1"
  [ ${#_FAILED[@]} -gt 0 ] && echo "FAILED: ${_FAILED[*]}"
  [ ${#_SKIPPED[@]} -gt 0 ] && echo "SKIPPED: ${_SKIPPED[*]}"
  [ "$_FAIL" -eq 0 ] && [ "$_SKIP" -eq 0 ]
}
```

**Why a score and not pass/fail.** A binary gate tells the agent it failed. A score tells it whether it is getting closer, which is something a loop can work against. The printed `SCORE` line also survives into the transcript, where a silent exit code does not.

**Negative checks are worth more than positive ones.** Proving a firewall is configured is weak. Proving a connection is actually refused is strong. Check the property, not the config that should produce it.

`/opt/aios-verify/all.sh` runs every stage script and prints a total. It becomes part of the weekly audit.

---

## Stage 1: A host nobody can reach

**Goal.** A hardened VPS invisible from the public internet, reachable only over Tailscale, with a break-glass path that does not depend on Tailscale.

**Done when `verify/stage1-host.sh` passes.** At minimum:

- [ ] An external port scan from another machine finds nothing open
- [ ] SSH is key-only: no password auth, no root login
- [ ] UFW and the Hetzner Cloud Firewall both default-deny inbound
- [ ] Nothing is listening on a non-loopback, non-Tailscale address
- [ ] Unattended security upgrades are enabled
- [ ] `/srv/aios-data/` is 0700 and not root-owned
- [ ] SSH from the iPhone over Tailscale works
- [ ] You have used the Hetzner rescue console once and know how to reach it

**Constraint.** Never disable a working access path before the replacement has been tested from the device that will use it. Lock-out means the rescue console, so rehearse it before you need it.

**Worth knowing.** fail2ban earns its place only while public SSH is open. Once SSH is Tailscale-only, remove it rather than maintain it.

---

## Stage 2: A disposable container holding durable data

**Goal.** Claude Code runs in a container that can be destroyed and rebuilt from source at any time, while everything personal survives on the host. Compromise of the container reaches `/data` and nothing else.

**Done when `verify/stage2-container.sh` passes.** At minimum:

- [ ] `docker compose down && docker compose up -d` rebuilds a working container with data intact
- [ ] The container runs as a non-root user whose UID matches the owner of `/srv/aios-data/`
- [ ] From inside: no Docker socket, no host filesystem beyond `/data`, no path to host root
- [ ] From inside: `/etc/aios/secrets.env` is unreadable
- [ ] Resource limits are set, so a runaway loop cannot take the host down
- [ ] Claude Code answers a prompt from inside the container
- [ ] Claude Code authentication survives a rebuild, and how is written down

**Constraints.** No `--privileged`, no Docker socket mount, no host network mode, no host root mount. `no-new-privileges`, capabilities dropped to what is demonstrably needed. Base image and dependencies pinned to versions, never `latest`, with machine-readable manifests in the rebuild package.

**Worth knowing.** Mismatched UIDs between the container user and the host directory owner is the most common failure here and it presents as confusing permission errors. Set it explicitly. Claude Code needs an interactive login the first time, so that step needs a real terminal.

---

## Stage 3: A system you can talk to from your phone

**Goal.** The AIOS exists with its operating instructions in place, reachable from the Claude iOS app, and every control that is meant to stop it actually stops it.

**Done when `verify/stage3-core.sh` passes,** plus two things no script can check: you hold a conversation from the Claude app, and a tool call requiring approval prompts on the phone, runs when approved and is refused when denied.

At minimum the script checks:

- [ ] A Remote Control session cannot read `/etc/aios/secrets.env`, reach the Docker socket, or become host root
- [ ] A hook blocks a write to `policy/` or `.claude/` in a session that has read from `quarantine/`
- [ ] A deliberate attempt to have a hook-blocked action approved from the phone still fails
- [ ] All four kill switch layers work
- [ ] No inbound port is open
- [ ] `bin/aios` exists and every verb is read-only or append-only
- [ ] The full directory layout exists, including `projects/`, and the hygiene lint runs

**What needs to exist.** The layout from `01-ARCHITECTURE.md` §5. `CLAUDE.md` and the `policy/` files, written from `03-OPERATING.md`. Hooks for destructive commands and the quarantine write guard. The `aios` CLI. Remote Control inside the container under tmux with a systemd unit.

**Before enabling Remote Control:** the Anthropic account gets a passkey or hardware key and no SMS second factor. It is now a credential that reaches the VPS. Confirm this is done rather than assuming.

**Constraints.** Remote Control runs inside the container, never on the host. Default permission mode, never `bypassPermissions`. `CLAUDE.md` loads every session, so keep it short; if it passes roughly 150 lines something belongs in `policy/` or a skill instead.

**The kill switch.** Four layers, each usable alone, all tested before anything is scheduled.

```
1. Pause         touch /srv/aios-data/.halt      scheduled runs check this first
2. Stop timers   systemctl stop aios-*.timer     interactive use continues
3. Full stop     docker compose down             data untouched
4. Cut remote    disableRemoteControl + revoke sessions at claude.ai
```

Layer 4 is for when the account rather than the machine is suspect. Keep all four somewhere reachable from your phone without the AIOS.

---

## Stage 4: A system that knows who it is working for

**Goal.** The AIOS holds an accurate, specific picture of your goals, constraints, history and the people around you, with every claim marked as confirmed by you or inferred by it.

**Why this matters more than any other stage.** Everything downstream reasons over this. A generic picture produces generic coaching, which is worse than none because it wastes your attention.

**Run it as an interview, not a form.** Use `AskUserQuestion`. Dig into the hard parts rather than the obvious ones. Keep going until covered, write the result out, then **start a fresh session** to act on it so the implementation has clean context and a written artefact.

Cover: the shape of a normal week; goals across business, health, money, career, development, family and habits; constraints in specifics rather than adjectives, because "busy" is not a constraint and "no discretionary time between 6am and 8pm on weekdays" is; what has repeatedly failed and how many times; who matters and who depends on you; and the lines it must never cross.

**Done when** these hold. `verify/stage4-context.sh` covers only the mechanical part: valid provenance front matter on every file, five or fewer active goals.

- [ ] You read `context/user.md` and the goal files and say it understands your situation
- [ ] At least one thing there mildly surprises you: true, but not previously articulated
- [ ] Every goal has a next action small enough to do this week
- [ ] Your theory about why something failed is recorded as `inferred`, not `confirmed`

**Constraint.** Never invent a fact. A gap stays a gap until you fill it.

---

## Stage 5: Rituals that survive a bad week

**Goal.** Daily check-in, daily brief, time and energy capture, and the weekly review all exist and have proven they work by being used manually for a week.

**Why manual first.** Automating a ritual that does not work manually just makes it fail on a schedule. The manual week is where you find out the check-in is too long or the brief says nothing useful.

**Done when `verify/stage5-rituals.sh` passes,** which checks the data exists rather than that it is good, plus the last item, which only you can answer:

- [ ] Seven consecutive daily check-ins recorded
- [ ] At least a week of time blocks logged
- [ ] One weekly review produced
- [ ] You read that review voluntarily, without being reminded
- [ ] Over that week you filed nothing by hand: everything you mentioned in conversation ended up in the right place on its own

**Constraints.** Time and energy are self-reported; there is no wearable here, so capture must be one tap or one short command. A form is the same as no data. Nothing classified sensitive or above goes in the daily brief, because `aios brief` is readable from any device.

---

## Stage 6: Work that happens without being watched

**Goal.** The rituals run on a schedule, failures are visible rather than silent, and any failed run can be reconstructed afterwards.

**Done when `verify/stage6-scheduling.sh` passes.** At minimum:

- [ ] A deliberately broken run can be replayed from `runs/` with the failing step identified
- [ ] A review of `runs/` finds no credentials, tokens or document contents
- [ ] The halt flag actually stops a scheduled run
- [ ] Backup and audit failures produce an alert; successes are silent

**What good looks like.** systemd timers on the host calling into the container, invoking `bin/aios` rather than embedding prompts in unit files. Every run bounded: retries with backoff, a time budget, a loop counter, then a clean logged failure. Unattended runs get an explicit tool allowlist rather than the full surface. Structured events in logs, never payloads. Rotate `runs/` at 90 days.

**Add security monitoring here, separate from health checks.** Failed logins, new user accounts, new listening ports, unexpected processes, and large outbound transfers. That last one is what a runaway scraper or a compromised agent looks like.

**Decide first.** Pro's limits will bind if the schedule is heavy. Keep scheduled work small, and put any bulk summarisation on a free tier rather than eating the allowance with it.

---

## Stage 7: Survivable

**Goal.** The whole system can be rebuilt from Google Drive plus your password manager, by someone who no longer has the original VPS, and this has been proven rather than assumed.

**Why not last.** A system holding this much irreplaceable context should not run a week without a tested restore.

**Done when `verify/stage7-recovery.sh` passes on the rebuilt machine, and:**

- [ ] A fresh VPS was rebuilt from Drive and the password manager alone
- [ ] The rebuild followed `RECOVERY.md` literally, improvising nothing
- [ ] Every missing or wrong step was corrected in `RECOVERY.md`
- [ ] The restored system answered a question using restored personal context
- [ ] The rebuild package was scanned and contains no secrets and no personal data
- [ ] An offline copy of the critical keys exists, away from both Google and Hetzner

**Also write here:** the secret rotation procedure. What to rotate, in what order, and the rule that a leaked secret is compromised regardless of how briefly it was exposed. You do not want to improvise that at 11pm.

**Do not skip the restore test.** A backup that has never been restored is a hypothesis. Improvising during the test is how a recovery document stays broken; every step that turns out to be missing is the point of the exercise.

---

## Stage 8: A system that improves without promoting itself

**Goal.** The weekly audit and weekly research run, both produce proposals, and nothing changes unless it is shown to be worth it.

**Done when:**

- [ ] One weekly audit has produced measured baselines you did not have before
- [ ] One weekly research digest has parked something with a trigger condition rather than adopting or dismissing it
- [ ] One proposed change has been trialled, measured, and either kept or reverted on the evidence
- [ ] At least one week has correctly concluded that nothing should change

**Constraint, and it is the important one.** Self-improvement is never self-authorisation. It may improve its methods, workflows, skills and tooling. It may never treat "I would perform better with more access" as an argument for having it. If a control blocks a capability, the capability does not get built, or gets built differently, and the blocked attempt is logged.

Mechanics in `03-OPERATING.md` §7.

---

## Whole-system definition of done

Demonstrated, not assumed.

**Nothing is reachable.** External scan clean. Key-only SSH over Tailscale. Both firewalls default-deny. Rescue console rehearsed.

**Nothing escalates.** Container non-root with matched UID, no socket, no host filesystem, resource-limited. Remote Control cannot read secrets or become host root. Hooks block regardless of what is approved from a phone.

**Nothing leaks.** No secret inside `/data`. Secrets injected at runtime from outside the image. Logs carry events, not contents. External content quarantined and enveloped.

**Nothing is lost.** Encrypted snapshots on Drive with keys held separately and offline. A full recovery performed on a fresh VPS with `RECOVERY.md` corrected from it.

**Nothing acts alone.** Every capability at draft-only at launch. High-risk actions confirmed explicitly. Kill switch works at four layers.

**And it is used.** Seven check-ins. A week of time blocks. A weekly review you read because you wanted to.

That last line is the one that matters. The rest is what makes it safe to want.
