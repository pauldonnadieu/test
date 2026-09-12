#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Nightly. No model: the output is fully determined by the input, so a model
# would buy nothing and add cost, latency and a failure mode.
#
# TWO paths, not one. conf/ holds CLAUDE.md and the skills, which is where
# months of approved improvement accumulate. Backing up data/ alone returns a
# machine with every check-in intact that has forgotten everything it learned.
export RESTIC_PASSWORD_FILE=/srv/aios/secrets/restic-password
export RESTIC_REPOSITORY="rclone:${AIOS_RCLONE_REMOTE:-gdrive}:aios-backup"
export RCLONE_CONFIG=/srv/aios/secrets/rclone.conf
run_routine backup restic backup \
  --tag aios --exclude-caches \
  "$AIOS_ROOT/data" "$AIOS_ROOT/conf"
