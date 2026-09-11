# 06 - Recovery and incidents

The kill switch, secret rotation, and what to do when something is wrong.

Read this before you need it. Every procedure here exists because composing it at 11pm, while
worried, is how people make the second mistake.

---

## 1. The kill switch

Four layers. Each works on its own. All four are tested in stage 9, and all four belong
somewhere you can reach from your phone **without the AIOS**, because a kill switch you can
only reach through the thing you are trying to stop is not a kill switch.

| # | Layer | Command | What keeps running |
|---|---|---|---|
| 1 | **Pause** | `touch /srv/aios/data/ops/.halt` | The container. Nothing schedules, nothing starts a session |
| 2 | **Stop timers** | comment out the crontab entries | Interactive use, if you still want it |
| 3 | **Full stop** | `docker stop aios` | Nothing. Data untouched on the host mount |
| 4 | **Cut remote** | revoke sessions at claude.ai, disable Remote Control | The machine, unreachable from the phone |

**Layer 1 is the one you will use.** Write the reason into the flag file:
`echo "investigating odd review output" > ops/.halt`. Every cron script checks it before doing
anything, and the SessionStart hook refuses to start a session while it exists. Remove the file
to resume; nothing else is needed.

**Layer 4 is the one that matters most and the one nobody rehearses.** It is the only response
to a suspected Anthropic account compromise, and it is the only layer that works when you
cannot reach the VPS at all. It is done from any browser, at claude.ai, using the account
password and second factor. If you cannot do this from your phone right now, without looking
anything up, that is a gap in the handover rather than a gap in the design.

**Order of use, when you do not yet know what is wrong:** 1, then 4, then 3. Pause first
because it is instant and reversible. Cut the remote second because the account is the widest
path in. Stop the container third, once you have decided this is an incident rather than a
puzzle.

---

## 2. Secret rotation

Assume every secret will eventually leak. The point of writing the order down is that rotating
in the wrong order can lock you out of the machine you are trying to secure.

**The rule that applies before any of it: a secret that was exposed is compromised, regardless
of how briefly, regardless of whether you think anyone saw it.** There is no such thing as
rotating it later because it was probably fine.

### What exists, and what each one reaches

| Secret | Reaches | Where it lives |
|---|---|---|
| Anthropic account credentials | An interactive session on the container and the data mount | The user's head and password manager |
| SSH private key | The host, as the admin user | The user's laptop and phone |
| Tailscale auth | The tailnet, and so the host | Host, and the Tailscale console |
| restic password | Every backup, past and present | Password manager and the offline copy |
| rclone OAuth token | The Drive folder holding ciphertext | `secrets/`, on the host |
| Hetzner account | The machine itself, and the console | The user's head and password manager |

### The order

Rotate outward-in, and never remove an access path before its replacement is tested.

1. **Establish a second way in first.** Confirm the Hetzner console works before touching SSH
   or Tailscale. This is the step people skip and the reason lockouts happen during rotations
   rather than during attacks.
2. **Anthropic account.** Change the password, re-enrol the second factor, revoke all sessions.
   Then re-authenticate Claude Code inside the container once, by hand, as in
   `HUMAN-TASKS.md` H16. Everything scheduled is broken until you do, which is correct and
   visible: the run records will say `error_class: auth`.
3. **SSH key.** Add the new public key, confirm you can log in with it from the device that
   will use it, then remove the old one. In that order, never the reverse.
4. **Tailscale.** Rotate the node key or re-enrol the device. Keep the console path open while
   you do.
5. **rclone token.** Re-run the OAuth flow. The repository and its password are unchanged, so
   nothing needs re-encrypting.
6. **restic password.** This one is different and is why it is last. Changing it does not
   re-encrypt existing snapshots; restic adds a new key to the repository. **Keep the old key
   until you are certain every snapshot you still want is readable with the new one.** Then
   remove the old key, and update both the password manager and the offline copy. A restic
   rotation that loses the old password before the new one is proven is a rotation that
   destroys your history.
7. **Hetzner account.** Password and second factor. Update the console password in the
   password manager, because it is the break-glass path for everything above.

Record what you rotated and when in `ops/`, without recording the values.

---

## 3. Suspected compromise

Signs worth acting on, all of which appear in `ops/security/alerts.md` or in the audit log:

- A listening socket that was not there yesterday.
- A new local user account, or a changed `authorized_keys`.
- Sustained outbound traffic well above the daily norm.
- A tool-call audit entry for something no routine does.
- A session in the Anthropic account you did not start.
- Config files with a modification time nobody can explain.
- The system doing something that was never approved.

### The sequence

**Stop before you diagnose.** This is the order people get backwards, and investigating a live
compromise from inside it is how evidence gets destroyed and how the attacker watches you work.

1. **Pause.** Kill switch layer 1.
2. **Cut the remote.** Layer 4. Revoke every session at claude.ai. If the account is the
   suspect, this is the only step that matters and everything else can wait five minutes.
3. **Stop the container.** Layer 3.
4. **Do not clean up.** No deleting suspicious files, no reinstalling, no tidying. You are
   preserving the only evidence you will ever have.
5. **Assume every credential the compromised component could reach is exposed**, and use the
   table in section 2 to decide which. A compromised container reaches the data mount and the
   Anthropic session, not the host, not the secrets, not the backup key. That distinction is
   the entire return on the container boundary, and it is worth being precise about rather than
   panicking across all of it.
6. **Preserve what you can read safely.** Copy `ops/audit/`, `ops/security/` and
   `ops/runs/` off the box, over Tailscale, to somewhere else.
7. **Decide: host, or container?** If only the container is suspect, destroy and rebuild it;
   that is what disposable is for. **If the host cannot be ruled out, rebuild the VPS.** Do not
   attempt to clean an untrusted host. You have a tested recovery path precisely so that this
   is a two-hour decision rather than a week of uncertainty.
8. **Rotate**, per section 2.
9. **Restore from a snapshot taken before the earliest sign.** The change ledger tells you when
   files started changing in ways nobody authorised, which is what makes "before" a date rather
   than a guess.
10. **Run the full suite on the rebuilt machine** before putting it back into service.
11. **Write down what happened and what allowed it**, in `ops/`. Then fix that, not the
    symptom.

**Do not skip step 11 because the system is working again.** A rebuild that does not answer how
it got in is a rebuild you will be doing again.

---

## 4. Recovery from nothing

The VPS is gone. This is the scenario the whole backup design exists for, and the procedure
lives in `RESTORE.md` inside the rebuild package, not here, because here is on the machine that
no longer exists.

What you bring:

- The **rebuild package** from Google Drive. Unencrypted, because it contains no secrets.
- The **secrets** from the password manager, and the **restic password** from the password
  manager or the offline copy.
- Nothing from the old box. If you had to look at the old box, you did not test recovery, you
  tested copying.

The shape, in the order `RESTORE.md` walks:

```
new VPS -> Linux -> timezone -> Tailscale -> firewall -> Docker -> restic + rclone
        -> restore data/ and conf/ from the snapshot
        -> restore secrets from the password manager
        -> build the container from the pinned Dockerfile
        -> log in to Claude Code once, by hand
        -> run the full suite
```

**Write down how long it took.** That number is what this design actually buys you, and it is
the only honest answer to "how bad would it be if the machine died".

Quarterly, per `HUMAN-TASKS.md` H28, on a second VPS, with the original untouched. An untested
backup is a hypothesis, and the hypothesis decays as the system changes.

---

## 5. The bad days, ranked

Written down so the response is a decision already made rather than one taken while worried.

| What happened | First move | Then |
|---|---|---|
| A routine stopped | Read the run record | Usually the halt flag, a lock file, or a usage limit |
| The container is unhealthy | Destroy and recreate it | Nothing is lost. This is routine |
| A check went red | Fix the property, never the check | If you cannot, it is a proposal, not an edit |
| Backups failing for weeks | Check disk, then throttling | Do not stop backing up to fix pruning |
| Locked out | Tailscale from another device | Then the Hetzner console |
| Odd output, no other signs | Pause, read the audit log | Most of these are a bad prompt, not an attack |
| Signs of compromise | Section 3, in order | Stop before you diagnose |
| Anthropic account suspect | Layer 4, immediately | The only layer that works without the VPS |
| Host gone | Section 4 | You rehearsed this a quarter ago |
| Backup key lost and offline copy gone | Nothing | Every snapshot is permanently unreadable. This is the design working as specified, and the reason the offline copy is an attestation |
