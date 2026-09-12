# R3 - Recovery, rotation and incidents

Read this before you need it. Every procedure here exists because composing it at 11pm, while
worried, is how people make the second mistake.

---

## 1. The kill switch

Four layers. Each works alone. All four belong somewhere reachable from the phone **without the
AIOS**, because a kill switch you can only reach through the thing you are trying to stop is not
a kill switch. That placement is a stage 0 attestation (`KS.4`).

| # | Layer | Command | What keeps running |
|---|---|---|---|
| 1 | **Pause** | `echo "why" > /srv/aios/data/ops/.halt` | The container. Nothing schedules, no session starts |
| 2 | **Stop timers** | comment out the crontab entries | Interactive use, if you still want it |
| 3 | **Full stop** | `docker stop aios` | Nothing. Data untouched on the host mount |
| 4 | **Cut remote** | revoke sessions at claude.ai, disable Remote Control | The machine, unreachable from the phone |

**Layer 1 is the one you will use.** Write the reason into the flag; `KS.3` fails on an empty one,
because a flag with no reason becomes a flag nobody dares remove. Every routine checks it before
locking or doing any work, and the SessionStart hook refuses to start a session while it exists.
Delete the file to resume; nothing else is needed.

**Layer 4 matters most and is the one nobody rehearses.** It needs no VPS and no Tailscale, and it
is the only response to a suspected Anthropic account compromise. If you cannot do it from your
phone right now without looking anything up, that is a gap in the handover.

**Order when you do not yet know what is wrong: 1, then 4, then 3.** Pause first because it is
instant and reversible. Cut the remote second because the account is the widest path in. Stop the
container third, once you have decided this is an incident rather than a puzzle.

---

## 2. Secret rotation

Assume every secret will eventually leak. The point of writing the order down is that rotating in
the wrong order can lock you out of the machine you are trying to secure.

**The rule that applies before any of it: a secret that was exposed is compromised, regardless of
how briefly and regardless of whether you think anyone saw it.** There is no "probably fine".

### What exists, and what each one reaches

| Secret | Reaches | Lives |
|---|---|---|
| Anthropic account | An interactive session on the container and the data mount | The user's head, password manager |
| SSH private key | The host, as the admin user | Laptop and phone |
| Tailscale auth | The tailnet, and so the host | Host, Tailscale console |
| restic password | Every backup, past and present | Password manager **and offline** |
| rclone OAuth token | The Drive folder holding ciphertext | `secrets/` on the host |
| Free-tier API key | Your shopping list, and a small bill at worst | `secrets/` on the host |
| Hetzner account | The machine itself, and the console | The user's head, password manager |

### The order

1. **Establish a second way in first.** Confirm the Hetzner console works before touching SSH or
   Tailscale. This is the step people skip, and it is why lockouts happen during rotations rather
   than during attacks.
2. **Anthropic account.** Change the password, re-enrol the second factor, revoke all sessions.
   Then re-authenticate Claude Code inside the container once, by hand. Everything scheduled is
   broken until you do, which is correct and visible: the run records will read
   `error_class: auth`.
3. **SSH key.** Add the new public key, confirm you can log in with it **from the device that will
   use it**, then remove the old one. In that order, never the reverse.
4. **Tailscale.** Rotate the node key or re-enrol the device, keeping the console path open.
5. **rclone token.** Re-run the OAuth flow. The repository and its password are unchanged, so
   nothing needs re-encrypting.
6. **Free-tier key.** Revoke and reissue. Nothing depends on continuity.
7. **restic password. This one is different and it is why it is last.** Changing it does not
   re-encrypt existing snapshots; restic adds a new key to the repository. **Keep the old key
   until you have confirmed every snapshot you still want is readable with the new one.** Then
   remove the old key and update both the password manager and the offline copy. A restic
   rotation that loses the old password before the new one is proven destroys your history.
8. **Hetzner account.** Password and second factor, then update the console password in the
   password manager, because it is the break-glass path for everything above.

Record what you rotated and when in `ops/`, without recording the values.

---

## 3. Suspected compromise

Signs worth acting on, most of which appear in `ops/security/alerts.md` or `ops/audit/`:

a listening socket that was not there yesterday; a new local user or a changed `authorized_keys`;
sustained outbound traffic well above the norm; a tool-call audit entry for something no routine
does; a session in the Anthropic account you did not start; config files with a modification time
nobody can explain; the system doing something that was never approved.

### The sequence

**Stop before you diagnose.** This is the order people get backwards, and investigating a live
compromise from inside it is how evidence gets destroyed and how the attacker watches you work.

1. **Pause.** Layer 1.
2. **Cut the remote.** Layer 4. If the account is the suspect this is the only step that matters
   and everything else can wait five minutes.
3. **Stop the container.** Layer 3.
4. **Do not clean up.** No deleting suspicious files, no reinstalling, no tidying. You are
   preserving the only evidence you will ever have.
5. **Assume every credential the compromised component could reach is exposed**, and use the table
   in section 2 to decide which. A compromised container reaches the data mount and the Anthropic
   session; it does not reach the host, the secrets, the backup key or the free-tier key. That
   distinction is the entire return on the container boundary and it is worth being precise about
   rather than panicking across all of it.
6. **Preserve what you can read safely.** Copy `ops/audit/`, `ops/security/` and `ops/runs/` off
   the box over Tailscale.
7. **Decide: host, or container?** If only the container is suspect, destroy and rebuild it; that
   is what disposable is for. **If the host cannot be ruled out, rebuild the VPS.** Do not attempt
   to clean an untrusted host. You have a tested recovery path precisely so this is a two-hour
   decision rather than a week of uncertainty.
8. **Rotate**, per section 2.
9. **Restore from a snapshot taken before the earliest sign.** The change ledger tells you when
   files started changing in ways nobody authorised, which is what makes "before" a date rather
   than a guess.
10. **Run the full suite on the rebuilt machine** before putting it back into service.
11. **Write down what happened and what allowed it.** Then fix that, not the symptom.

**Do not skip step 11 because the system is working again.** A rebuild that does not answer how it
got in is a rebuild you will be doing again.

---

## 4. Recovery from nothing

The VPS is gone. The procedure lives in `RESTORE.md` **inside the rebuild package**, not here,
because here is on the machine that no longer exists.

What you bring: the **rebuild package** from Drive, unencrypted because it contains no secrets;
the **secrets** from the password manager; the **restic password** from the password manager or
the offline copy. Nothing from the old box. **If you had to look at the old box, you did not test
recovery, you tested copying.**

```
new VPS -> Linux -> timezone -> Tailscale -> firewall -> Docker -> restic + rclone
        -> restore data/ AND conf/ from the snapshot
        -> restore secrets from the password manager
        -> build the container from the pinned Dockerfile
        -> log in to Claude Code once, by hand
        -> run the full suite
```

Two steps in that list are the ones people forget and both are here deliberately. **`conf/` comes
back too**, or you have restored a machine that has forgotten everything it learned. And **the
login cannot be automated**, so finding that out during a real recovery is worse than finding it
out now.

**Write down how long it took.** That number is what this design actually buys you, and it is the
only honest answer to "how bad would it be if the machine died".

Quarterly, on a second VPS, with the original untouched. Read the offline key at the same time.
An untested backup is a hypothesis, and the hypothesis decays as the system changes.

---

## 5. The bad days, ranked

| What happened | First move | Then |
|---|---|---|
| A routine stopped | Read the run record | Usually the halt flag, a stale lock, or a usage limit |
| The container is unhealthy | Destroy and recreate it | Nothing is lost. This is routine |
| A check went red | Fix the property, never the check | If you cannot, it is a proposal, not an edit |
| Backups failing for weeks | Check disk, then throttling | Do not stop backing up to fix pruning |
| Disk full | `sweep.sh`, then look at what grew | Backup and cron both stop, and neither says why |
| Locked out | Tailscale from another device | Then the Hetzner console |
| Odd output, no other signs | Pause, read the audit log | Most of these are a bad prompt, not an attack |
| Signs of compromise | Section 3, in order | Stop before you diagnose |
| Anthropic account suspect | Layer 4, immediately | The only layer that works without the VPS |
| Host gone | Section 4 | You rehearsed this a quarter ago |
| Backup key and offline copy both lost | Nothing | Every snapshot is permanently unreadable. This is the design working as specified, and the reason the offline copy is an attestation |
