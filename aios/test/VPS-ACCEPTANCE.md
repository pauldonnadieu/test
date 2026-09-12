# VPS acceptance test

The things that can only be tested on the real machine. Run these when the VPS exists.

The sandbox dry run tests whether the documents can be followed. **This tests whether the
system is actually safe**, and it covers the two stages carrying the most security weight,
which the sandbox never touches.

Six parts. Four are automated; two need you, because they involve rebooting a machine and
destroying one.

---

## Part 1: the firewall, proved from outside

**Why this needs setup.** A machine cannot honestly test its own firewall. Connect to your own
public IP from the box and the packet never leaves; you get a pass that proves nothing. This
is the single easiest way to end up with a green suite on an exposed server.

Pick a vantage point with `checks/lib/probe-from-outside.sh`:

| Mode | What it needs | What it costs |
|---|---|---|
| `ssh` | Another machine you control | Nothing. Best answer |
| `hetzner` | A second VPS, destroyed after | About a cent an hour |
| `phone` | Your phone on mobile data, off wifi | Manual, two minutes, no infrastructure |
| `thirdparty` | An online port checker | **You disclose your server's IP and which ports you care about to a stranger.** Stated so the choice is deliberate |

A tailnet device is **not** a valid vantage point. Traffic from it may take the tailnet path, so
a refusal there proves nothing about the public internet.

```bash
export AIOS_PROBE_MODE=ssh AIOS_PROBE_SSH=you@other-box
export AIOS_EXT_PROBE='bash /srv/aios/checks/lib/probe-from-outside.sh $HOST $PORT'
./run-all.sh stage-01-host
```

**Criteria.** `HOST.1`, `HOST.2`, `HOST.3` all pass: ports 22, 80 and 443 refused from outside.
Any SKIP here is a fail; it means nobody has demonstrated the port is shut. `HOST.10` passes:
the box is on the user's timezone, not UTC.

---

## Part 2: the container boundary

Fully automated, nothing to set up:

```bash
./run-all.sh stage-02-container
```

**Criteria.** `CTR.1`-`CTR.14` all pass. Every one of them runs as the container user, not as
root, because that is the only identity whose limits matter.

The one to look at hardest is `CTR.2`: the agent cannot write its own `settings.json`. That
file registers the hooks and holds the deny rules. If the agent can edit it, it can remove
every constraint that binds it, and everything else in the suite is decoration.

The one most likely to fail on a first build is `CTR.12`: a non-interactive run succeeds
without prompting for authentication. If it fails, the credential is not on a persisted mount,
and the container is disposable exactly once.

---

## Part 3: the hooks actually refuse

Automated, and worth running separately because a hook that has only been seen to allow proves
nothing:

```bash
./run-all.sh stage-03-runtime
```

**Criteria.** `HK.1`-`HK.8` pass, including the four behaviour checks: the halt gate stops a
session, the write guard refuses both an escape via `../` and a trusted-tree write after a
quarantined read, and the danger guard refuses each named command.

Then check the other direction by hand, because a guard that refuses everything is also broken:
start a **new** session and confirm it can write to `review/` normally. If the taint marker
persists between sessions, the first research scan silently disables the weekly review for ever.

---

## Part 4: reboot

**Why.** This is the classic silent failure and nothing else catches it. A firewall rule added
but never persisted. A container with no restart policy. A Tailscale key that quietly expired. A
cron daemon running only because someone started it by hand. A timezone set for the session and
not for the system. The box looks perfect until it reboots, and it will reboot on a day nobody
is watching.

```bash
touch /srv/aios/ops/.reboot-marker
sudo reboot
# wait, reconnect over Tailscale
./run-all.sh stage-11-vps
```

**Criteria.** `RB0.1`-`RB0.5`. Firewall active and still denying, Tailscale connected, container
running with a restart policy, cron alive with its entries, timezone still correct, node key not
expiring within a fortnight. **Nothing may require a human to log in and fix it.**

**Do this before the system holds real data.** A reboot failure found in week one is an
afternoon. Found in month six, it is an afternoon plus however long the system was quietly dead.

---

## Part 5: cron actually fires, and the kill switch actually stops it

**Why.** `RUN.1`-`RUN.3` check that a run record is *fresh*, which is a proxy: they stay green
for 36 hours after cron dies. This is evidence instead.

```bash
( crontab -l; echo '* * * * * touch /srv/aios/ops/.cron-canary' ) | crontab -
sleep 150
./run-all.sh stage-11-vps
crontab -l | grep -v cron-canary | crontab -    # remove it again
```

**Criteria.** `CRON.1`-`CRON.3`. The canary fired; scripts set `PATH` or use absolute paths;
cron output is redirected somewhere readable.

`CRON.2` catches the most common scheduling bug there is: cron runs with a minimal `PATH` and no
login shell, so a script that works perfectly by hand fails at 3am with `docker: not found`.

Then, in the same sitting, prove the kill switch against a live schedule:

```bash
echo "acceptance test" > /srv/aios/data/ops/.halt
# wait for the next scheduled routine
./run-all.sh stage-09-safety
rm /srv/aios/data/ops/.halt
```

**Criteria.** `KS.1`-`KS.5`. The routine that should have run did not, and it left a record
saying it was halted rather than no record at all.

---

## Part 6: recovery from nothing

**The real acceptance test.** Everything else checks that the running system is healthy. This
checks the claim the whole backup design rests on: that you can get it all back.

**The user runs this, not Claude Code.** The scenario is the VPS being gone, and in that
scenario the thing that matters is whether the human can recover it.

1. Create a **second, fresh VPS**. Do not touch the original.
2. Bring only what a real disaster leaves you: the **rebuild package**, and the **secrets from
   the password manager**, not from the old box.
3. Follow `RESTORE.md`. Restore `data/` **and `conf/`** from snapshots.
4. Log in to Claude Code once, by hand. That step is in the procedure because it cannot be
   automated, and finding that out during a real recovery is worse than finding it out now.
5. Run the full suite on the rebuilt machine.
6. Destroy the second VPS.

**Criteria.**

- The rebuild completes **without reading anything off the original machine**. If you had to
  look at the old box, you have not tested recovery, you have tested copying.
- The suite scores the same on the rebuilt machine as on the original.
- The most recent check-in is present in the restored data.
- **`CLAUDE.md` and the skills are the current ones**, not the versions in the rebuild package
  from six months ago. This is what `BK.7` exists to guarantee and this is where you find out
  whether it does.
- **You did it yourself**, without Claude Code driving.
- Write down how long it took. That number is what you are actually buying with this design.

**Quarterly after the first time.** An untested backup is a hypothesis, and the hypothesis
decays as the system changes. Read the offline key at the same time.

---

## Things no check can cover

Listed so their absence is deliberate rather than an oversight.

| Property | Why not | What instead |
|---|---|---|
| The Anthropic account's password and second factor | Account-side. Nothing on the box can see it | Stage 0 attestation, dated. `RC.5` reports SKIP permanently |
| The data-training setting (30-day vs 5-year retention) | Account-side | Stage 0 attestation. `RC.6` reports SKIP permanently |
| The Hetzner and Google second factors | Account-side | Stage 0 attestations |
| Whether the offline backup key still exists and is readable | Only you know where it is | Read it, quarterly, with the restore drill |
| Whether `CLAUDE.md` gives *good* instructions | The harness checks shape, never judgement | The quarterly tier-3 read in `HUMAN-TASKS.md` |
| Whether the weekly review is any use | Same | Follow-through: do you do what it suggests? |

These are permanent SKIPs on purpose. The runner scores a SKIP as a failure, so the suite will
not read as fully green while they remain, which is the honest state of affairs, because nobody
has proven them.

---

## Order

1, 2, 3 and 5 first: cheap, automated, and they catch the most.
4 before real data goes in.
6 once the system is live and worth losing.

## What green means after all six

The firewall refuses from outside. The container cannot rewrite its own rules. The hooks have
been seen to refuse. The machine survives a reboot unattended. Cron genuinely fires and the
kill switch genuinely stops it. You personally rebuilt the whole thing from nothing, and what
came back knew everything it had learned.

That is as far as evidence goes here. What remains unproven is on the list above, and it stays
on the list.
