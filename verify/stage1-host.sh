#!/usr/bin/env bash
# Worked example. Stage 1: a host nobody can reach.
#
# This is a starting point, not the finished check. Add a check for every
# line in the stage's "Done when" list, and for anything you discover
# during the build that could silently regress later.
#
# Run on the VPS as a user with sudo.

source "$(dirname "$0")/lib.sh"

check ssh-no-password "SSH rejects password authentication" <<'TEST'
sudo sshd -T 2>/dev/null | grep -qx 'passwordauthentication no'
TEST

check ssh-no-root "SSH rejects root login" <<'TEST'
sudo sshd -T 2>/dev/null | grep -Eqx 'permitrootlogin (no|prohibit-password)'
TEST

check ufw-default-deny "UFW default-denies inbound" <<'TEST'
sudo ufw status verbose 2>/dev/null | grep -q 'Default: deny (incoming)'
TEST

check unattended-upgrades "Unattended security upgrades are enabled" <<'TEST'
systemctl is-enabled unattended-upgrades.service >/dev/null 2>&1
TEST

check data-dir-perms "/srv/aios-data is 0700 and not root-owned" <<'TEST'
[ "$(stat -c '%a' /srv/aios-data)" = "700" ] && [ "$(stat -c '%U' /srv/aios-data)" != "root" ]
TEST

check git-no-remote "The data repo has no git remote" <<'TEST'
[ -z "$(git -C /srv/aios-data remote 2>/dev/null)" ]
TEST

check secret-canary "A pre-commit hook blocks a planted fake secret" <<'TEST'
cd /srv/aios-data || exit 1
trap 'rm -f .verify-canary; git reset -q HEAD .verify-canary 2>/dev/null' EXIT
printf 'AKIAIOSFODNN7EXAMPLE\nsk-ant-api03-not-a-real-key\n' > .verify-canary
git add -f .verify-canary 2>/dev/null
# The commit MUST fail. If it succeeds, secret scanning is not working.
! git commit -q -m 'verify: canary, should never land' 2>/dev/null
TEST

check no-public-listeners "No service is bound to a non-loopback, non-Tailscale address" <<'TEST'
# Anything listening outside 127.0.0.0/8 and the Tailscale 100.64/10 range.
bad=$(sudo ss -Hltn 2>/dev/null | awk '{print $4}' \
  | grep -Ev '^(127\.|\[::1\]|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)' || true)
[ -z "$bad" ] || { echo "listening: $bad"; exit 1; }
TEST

# An external scan cannot be run from the host it is scanning. Do it from
# another machine and record the result, or this stays a SKIP and the
# stage does not pass.
if [ -n "${AIOS_EXTERNAL_SCAN_CLEAN:-}" ]; then
  check external-scan "An off-host port scan found nothing open" <<'TEST'
[ "$AIOS_EXTERNAL_SCAN_CLEAN" = "1" ]
TEST
else
  skip external-scan "run nmap from another machine, then re-run with AIOS_EXTERNAL_SCAN_CLEAN=1"
fi

summary stage1-host
