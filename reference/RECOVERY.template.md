# RECOVERY

How to rebuild the AIOS from nothing. Fill in every `<>` placeholder during Stage 7, then verify by following it on a throwaway VPS.

**Assume the reader has only two things: access to Google Drive, and the password manager.** No VPS, no laptop state, no memory of how it was set up.

---

## Kill switch

Before anything else, if the system is running and misbehaving:

```
1. Pause         touch /srv/aios-data/.halt
2. Stop timers   systemctl stop aios-*.timer
3. Full stop     cd <compose dir> && docker compose down
4. Cut remote    disableRemoteControl setting, and revoke sessions at
                 claude.ai account settings
```

Use layer 4 when the Anthropic account rather than the VPS is what is suspected.

---

## What you need

| Item | Where it lives |
|---|---|
| Rebuild package | Google Drive, `<path>`, unencrypted |
| Encrypted data backup | restic repo on Google Drive, `<path>` |
| Encrypted secrets | Google Drive, `aios-secrets.enc` |
| restic repository password | Password manager, entry `<name>` |
| `aios-secrets.enc` passphrase | Password manager, entry `<name>` |
| Hetzner login | Password manager, entry `<name>` |
| Tailscale login | Password manager, entry `<name>` |
| Anthropic login | Password manager, entry `<name>` |
| Google account | Password manager, entry `<name>` |

Never store a decryption password beside the data it unlocks.

---

## Procedure

1. **Provision a VPS.** Hetzner, EU region, `<size>`, Ubuntu LTS, SSH key at creation.
2. **Base hardening.** Non-root admin user, key-only SSH, no root login, UFW default deny inbound, Hetzner Cloud Firewall matching.
3. **Tailscale.** Install on the host. Enrol. Verify access from the phone.
4. **Close public SSH** once Tailscale is verified.
5. **Install Docker, restic, rclone.**
6. **Retrieve the rebuild package** from Drive to `/opt/aios-rebuild/`.
7. **Restore secrets.** Download `aios-secrets.enc`, decrypt with the passphrase from the password manager, write to `/etc/aios/secrets.env`, `chmod 0600`, `chown root:root`.
8. **Configure rclone** for Google Drive using the restored credentials.
9. **Restore the data.** `restic restore` the chosen snapshot to `/srv/aios-data/`. Fix ownership and permissions: owned by the AIOS user, 0700.
10. **Build the container** from the Dockerfile. Confirm the container user's UID matches the owner of `/srv/aios-data/`.
11. **Start it.** `docker compose up -d`.
12. **Re-authenticate Claude Code.** `docker compose exec aios claude`, then `/login`. The stored credential does not survive a rebuild on a new machine.
13. **Restart Remote Control** inside the container, under tmux, via its systemd unit.
14. **Verify**, in this order: files present and readable; the AIOS answers a question using restored personal context; Remote Control connects from the phone; a permission prompt arrives and is honoured; the backup job runs and a test restore succeeds.
15. **Rotate anything that may have been exposed** if this recovery follows a suspected compromise, and work the incident procedure in `policy/security.md` rather than treating the rebuild as the fix.

---

## Verified

| Date | By | Outcome | Corrections made |
|---|---|---|---|
| | | | |

A recovery procedure that has never been executed is a hypothesis. Record every run here, including the steps that turned out to be missing.
