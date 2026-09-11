# AIOS Build

The build itself. Read `ARCHITECTURE.md` first.

---

## How to use this

This is a build brief, not a script. It says what to build, in what order, and what must be true before moving on. It deliberately does not give every command, because the exact commands depend on current tool versions and on what the machine reports back.

1. **Build in stage order.** Each stage has an acceptance test. Do not start stage N+1 until stage N passes and you have told the user it passed.
2. **Stop at every STOP.** These are points where guessing wrong is expensive or irreversible.
3. **Verify, do not assume.** Versions, plan names, CLI flags and limits in this document may have drifted. Where it says verify, run the check.
4. **Never invent facts about the user.** Everything personal comes from the Stage 4 intake or the user directly.
5. **Log every decision** to `decisions/log.md`.
6. **Prefer deleting to adding.** If a stage seems to need a new service, say so and ask.

**If a stage's acceptance test cannot pass, do not proceed and do not weaken the test.** Report what is blocking. If a security requirement makes a capability impossible, the capability loses (P14). If following this document seems to require infrastructure it says not to add, that is a signal the design needs simplifying, not that the constraint needs lifting.

---

## Stage 0: Preparation

**STOP.** The user must create the Hetzner and Tailscale accounts themselves. Confirm they have a password manager in daily use, a Google account for backups with MFA and a hardware key or passkey where practical, and an SSH keypair with a passphrase on the private key.

Generate nothing secret on the user's behalf without telling them exactly where it will live and how it is backed up.

*Acceptance:* accounts exist, SSH key exists, the user can name where each recovery credential will be stored.

---

## Stage 1: The host

1. Provision the VPS. EU region, Ubuntu LTS, SSH key injected at creation, no password.
2. Create a non-root admin user with sudo, copy the key across.
3. Harden SSH: key auth only, no root login, no password auth. Do not disable the working path until the replacement is tested.
4. UFW: default deny inbound, allow outbound, allow SSH.
5. Hetzner Cloud Firewall: the same rules.
6. Enable unattended security upgrades.
7. Install Tailscale on the host, not in the container. Enrol the VPS, iPhone, Mac and PC.
8. Verify SSH over Tailscale from the iPhone.
9. **Only then** remove public SSH from both firewalls. Keep the Hetzner rescue console as break-glass and confirm the user knows how to reach it.
10. Create `/srv/aios-data/`, 0700, owned by the AIOS user. Initialise a local git repo with `.gitignore` and a pre-commit secret-scanning hook.

Host hardening is complete when all of these hold: key-only SSH, no root login, both firewalls default-deny, no service on a public interface (`ss -tulpn` and an external scan), unattended upgrades on, `/srv/aios-data/` at 0700. Install fail2ban only while public SSH is still open; once SSH is Tailscale-only it is unnecessary, so remove it rather than maintain it.

*Acceptance:* an external port scan shows nothing open. SSH from the iPhone over Tailscale works. A deliberate attempt to commit a fake API key is blocked by the pre-commit hook.

---

## Stage 2: The container

1. Write the Dockerfile in `/opt/aios-rebuild/`. Pin the base image to a version tag, never `latest`. Install Python, Node, Claude Code and the tools needed. Create a non-root user whose UID and GID match the owner of `/srv/aios-data/`. **Mismatched UIDs are the most common cause of a broken bind mount**; set this explicitly rather than relying on defaults.
2. Write `compose.yaml`: the bind mount, resource limits, `no-new-privileges:true`, dropped capabilities, restart policy, and an env file reference to `/etc/aios/secrets.env`.
3. Pin all dependencies. Commit the manifests to the rebuild package.
4. Build and start. Verify the container runs as the non-root user and can read and write `/data`.
5. Authenticate Claude Code inside the container. This needs an interactive run: `docker compose exec aios claude`, then `/login`, follow the URL, paste the code back. Note where the credential is stored, make sure it survives a container rebuild by placing it on the bind mount or a dedicated volume, and record how in RECOVERY.md.
6. Verify isolation from inside the container: no Docker socket, no host filesystem beyond `/data`, no route to host root, cannot read `/etc/aios/secrets.env`.

Container requirements, all mandatory: non-root with matched UID, no `--privileged`, no Docker socket mount, no host network mode, no host root filesystem mount, `no-new-privileges`, capabilities dropped to what is demonstrably needed, memory and CPU limits set so a runaway loop cannot take the host down, and only `/srv/aios-data/` bind-mounted.

*Acceptance:* `docker compose down && docker compose up -d` rebuilds a working container with data intact. Claude Code answers a prompt from inside it. Every isolation check in step 6 passes.

---

## Stage 3: Core AIOS and the interface

Where the system becomes usable. Before connections, deliberately (P4).

1. Create the filesystem layout from `ARCHITECTURE.md` Section 5.
2. Deploy the runtime files: `runtime/CLAUDE.md` to `/srv/aios-data/CLAUDE.md`, and `runtime/policy/*` plus `runtime/SCHEMAS.md` to `/srv/aios-data/policy/`. Deploy them as-is. Do not paraphrase them into something new.
3. Build the hooks in `.claude/hooks/`: PreToolUse guards on destructive commands, the untrusted-content write guard, and an audit-logging hook writing to `runs/`.
4. Build the `aios` CLI (`ARCHITECTURE.md` 6.3). Small verb set, every verb read-only or append-only.
5. **STOP.** Lock down the Anthropic account before enabling Remote Control: passkey or hardware key, no SMS second factor, unique password in the password manager. This is now a credential that reaches the VPS. Confirm with the user that it is done before continuing.
6. Start Remote Control inside the container: under tmux, in server mode, working directory `/data`, default permission mode, `--sandbox` on, capacity constrained, named. Wrap it in a systemd unit with restart-on-failure so it survives reboots and SSH disconnection. Connect from the iPhone via the QR code.
7. Verify the container boundary from a Remote Control session: cannot read `/etc/aios/secrets.env`, cannot reach the Docker socket, cannot escalate to host root, cannot write to `policy/` or `.claude/` under the hook conditions.
8. Build the kill switch (below) and test every layer before any scheduled run exists.

### The kill switch

Four layers, each usable independently, all tested before Stage 6.

1. **Pause:** `touch /srv/aios-data/.halt`. Every scheduled run checks for this first and exits. Cheapest, reversible.
2. **Stop scheduling:** `systemctl stop aios-*.timer`. Interactive use continues.
3. **Full stop:** `docker compose down`. Data untouched on the host.
4. **Cut the remote path:** the `disableRemoteControl` setting, plus revoking sessions from Anthropic account settings. Use this when the account rather than the VPS is what is suspected.

The user must have all four written somewhere reachable from their phone without the AIOS. Put them at the top of RECOVERY.md and in the password manager beside the recovery credentials.

*Acceptance:* the user holds a conversation with the AIOS from the Claude iOS app, and a tool call requiring approval prompts on the phone, is correctly executed when approved and correctly refused when denied. Every boundary check in step 7 passes. The kill switch works at all four layers. An external port scan still shows nothing open.

---

## Stage 4: Personalisation

**STOP.** This is the intake, and it is the highest-leverage hour in the whole build. Do not rush it and do not fill gaps with assumptions.

Conduct it as a conversation, not a form. Cover:

- **Who the user is.** Work, family, household, the shape of a normal week, what they are optimising for.
- **The goals.** Business and side hustle, health and fitness, financial, career, personal development, family, habits. For each: desired outcome, why it matters, timeframe, current state.
- **The constraints.** Time actually available, energy patterns across the day and week, money, physical capacity, commuting and office days, childcare, sleep. Be specific. "Busy" is not a constraint; "no discretionary time between 6am and 8pm on weekdays" is.
- **The history.** What has repeatedly failed, how many times, and what the user thinks went wrong. Capture their theory but mark it `inferred`, not `confirmed`.
- **The people.** Who matters, who depends on them, who they depend on.
- **The lines.** What the AIOS must never do, mention or touch.

Write to `context/` using the schemas in `policy/schemas.md`, with correct provenance front matter throughout. What the user asserted is `confirmed`. What you concluded is `inferred`, and the file should say so.

Then read it back as a summary and let them correct it. Log the corrections.

*Acceptance:* the user reads `context/user.md` and the goal files and says the system understands their situation. At least one thing in there mildly surprises them, in the sense of being true but previously unarticulated.

---

## Stage 5: The coaching loop

Build the rituals in this order, and run every one manually for at least a week before scheduling anything (P4). A ritual that does not survive a week of manual use is the wrong ritual; fix it before automating it.

1. **Daily check-in.** The ground truth everything else depends on. Thirty seconds, via `aios checkin` or a short exchange in the Claude app.
2. **Daily brief.** One screen, generated each morning.
3. **Time and energy logging.** `aios time start|stop` and `aios log energy N`. Keep it light. The failure mode of time tracking is that logging becomes the work.
4. **Weekly review.** The most valuable ritual in the system.
5. **Bottleneck analysis** and the **self-sabotage protocol**, as on-demand skills at first.

The content of each is defined in `runtime/CLAUDE.md`; the data formats in `runtime/SCHEMAS.md`.

**STOP** at the end of this stage and ask which connection comes first. Recommend calendar, read-only, via MCP. Email second and read-only for longer, because it is the main injection vector. Also worth asking here: whether sleep and energy should come from Apple Health rather than self-report, since automatic beats honest-but-forgotten.

*Acceptance:* seven consecutive daily check-ins recorded, at least one week of time blocks logged, one weekly review produced, and the user voluntarily read the weekly review rather than being reminded to.

---

## Stage 6: Scheduling and self-healing

**STOP.** Settle the scheduled-run authentication question first (`ARCHITECTURE.md` Section 8). Pro limits will bind on a system running this many recurring jobs.

1. systemd timers on the host calling `docker exec` into the container, invoking the `aios` CLI rather than embedding prompts in unit files. Not cron inside the container. Timers give logging, ordering and failure handling for free.
2. Every scheduled run: bounded retries with exponential backoff, a hard time budget, a loop counter, and a clean logged failure if exhausted. Never a silent failure.
3. Every run writes a structured record to `runs/`: trigger, tools called, what succeeded, what failed, what it produced. Structured events only, never payloads: no credentials, tokens, auth headers, full conversations, document contents or personal identifiers. Rotate at 90 days, then keep archived summaries.
4. The weekly `/audit` skill: are connections alive, are any skills broken, is anything failing repeatedly, does the wiki lint clean, are backups current, is disk fine.
5. Backpressure on every outward action: schema validation on inputs, a dry-run mode, an explicit success check on the result. Where a write target has multiple possible destinations, always pass the destination explicitly rather than relying on a default; silent misfiling is a common failure mode.
6. Prefer write-then-verify-and-correct over check-then-write wherever the read path is unreliable.

*Acceptance:* a deliberately broken run can be replayed from `runs/` and the exact failing tool call identified. The weekly audit runs unattended and reports.

---

## Stage 7: Backup and recovery

Not optional and not later. Until this passes, the system is one bad day from total loss.

1. Install restic and rclone on the host.
2. Configure rclone for Google Drive. The OAuth token is a secret: it goes in `/etc/aios/secrets.env`, never in `/srv/aios-data/`.
3. Initialise the restic repo on the Drive remote. Generate a strong repository password. **STOP** and confirm the user has stored it in the password manager and can reach it if both the VPS and their laptop are gone.
4. Back up essentially all of `/srv/aios-data/`. Exclude only obvious cache and regenerable material. Do not build an elaborate include list.
5. Retention: 7 daily, 4 weekly, 12 monthly. Prune on schedule.
6. Create `aios-secrets.enc`: the contents of `/etc/aios/secrets.env` plus anything else needed to operate, encrypted with `age` under a passphrase held only in the password manager. Upload to Drive. Regenerate whenever a secret changes.
7. Upload the rebuild package to Drive unencrypted, after explicitly scanning it for secrets and personal data. Do not assume it is clean; check.
8. Write `RECOVERY.md` from `runtime/RECOVERY.template.md`, assuming the reader has only Google Drive and the password manager.
9. **Run the recovery test.** Provision a throwaway VPS, follow RECOVERY.md exactly, improvise nothing, and write down every step that was missing or wrong. Fix RECOVERY.md, then destroy the test VPS.
10. Schedule backups via systemd timer. Alert on failure, not on success.

**Do not skip step 9.** A backup that has never been restored is a hypothesis.

*Acceptance:* a fresh VPS was rebuilt from Drive plus the password manager alone, the restored AIOS answered a question using restored personal context, and RECOVERY.md was corrected from what actually went wrong.

---

## Stage 8: The self-star loops

Only now. See `ARCHITECTURE.md` Section 7 for what each loop does.

Build in this order: the weekly reflection pass, the wiki lint, the monthly archive sweep, then the research agent. Every one produces proposals, never applied changes, until it has a track record the user trusts.

*Acceptance:* the system proposes a change to its own configuration that the user accepts on its merits, having judged it a genuinely good idea rather than accepting it to be agreeable.

---

## Beyond v1

Not scheduled. Revisit only with real usage data.

- **A purpose-built app** for timers, alarms, task checkboxes and capture ergonomics (`ARCHITECTURE.md` 6.4). The data schemas exist from Stage 3, so this is a UI over a working model rather than a migration.
- **Shortcuts or Android automation** (`ARCHITECTURE.md` 6.5), wrapping the verb CLI.
- **An offline backup copy**, as a third layer beside Drive and Hetzner snapshots.
- **More connections**, one at a time, each starting at draft-only.

---

## Acceptance checklist

The build is complete when every line is true and has been demonstrated, not assumed.

**Host and network**

- [ ] SSH key-only, no root login, no password auth
- [ ] UFW and Hetzner Cloud Firewall both default-deny inbound
- [ ] External port scan shows nothing open
- [ ] Tailscale is the only access path; public SSH removed
- [ ] Hetzner rescue console confirmed as break-glass
- [ ] Unattended security upgrades enabled
- [ ] No service bound to a public interface

**Container**

- [ ] Runs non-root, UID matched to the bind mount owner
- [ ] No privileged mode, no Docker socket, no host network, no host filesystem beyond `/data`
- [ ] Resource limits set
- [ ] Rebuilds cleanly with data intact
- [ ] Claude Code auth survives rebuild, and how is documented

**Data and secrets**

- [ ] `/srv/aios-data/` 0700, owned by the AIOS user
- [ ] Local git repo with no remote
- [ ] Pre-commit secret scanning verified with a deliberate test
- [ ] No secret anywhere inside `/srv/aios-data/`
- [ ] Secrets injected at runtime from a root-owned 0600 file outside the image
- [ ] Provenance front matter present and valid on every context, wiki, raw and memory file

**Isolation and trust**

- [ ] External content quarantined in `raw/untrusted/`, envelope convention in use
- [ ] PreToolUse hook blocks writes to `.claude/`, `CLAUDE.md` and `policy/` after untrusted reads
- [ ] Autonomy ladder recorded, every capability at level 0 or 1 at launch
- [ ] High-risk actions require explicit confirmation, tested
- [ ] A review of `runs/` finds no credentials or document contents

**Remote Control**

- [ ] Anthropic account protected with a passkey or hardware key, no SMS second factor
- [ ] Runs inside the container, not on the host
- [ ] Under tmux with a systemd unit, survives reboot and SSH disconnect
- [ ] Default permission mode, `--sandbox` on, capacity constrained, never `bypassPermissions`
- [ ] A session cannot read `/etc/aios/secrets.env`, reach the Docker socket, or escalate to host root, all verified
- [ ] Hooks block destructive actions regardless of phone approval, verified by a deliberate attempt
- [ ] `disableRemoteControl` documented in the kill switch procedure
- [ ] Highly-sensitive work has a documented local-only SSH path

**Backup and recovery**

- [ ] restic repo initialised on Drive via rclone
- [ ] Repository password in the password manager, confirmed retrievable
- [ ] `aios-secrets.enc` encrypted separately, key stored separately
- [ ] Rebuild package verified free of secrets and personal data
- [ ] Retention applied, pruning scheduled
- [ ] Backup failures alert; successes do not
- [ ] **Full recovery test performed on a fresh VPS and RECOVERY.md corrected from it**

**Use**

- [ ] `aios` CLI built, verbs read-only or append-only
- [ ] Scheduled runs invoke the CLI, not embedded prompts
- [ ] Conversation works from the Claude iOS app, approval correctly honoured and correctly refused
- [ ] Kill switch tested at all four layers
- [ ] Seven consecutive daily check-ins recorded
- [ ] One weekly review the user read voluntarily
