#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Nightly retention. No model.
# A full disk stops the backup and cron simultaneously and looks like nothing
# at all, so the two fastest-growing things get a life span.
sweep() {
  find "$AIOS_DATA/untrusted-external" -mindepth 2 -name raw -type f -mtime +30 -delete 2>/dev/null
  find "$AIOS_DATA/untrusted-external" -mindepth 1 -type d -empty -delete 2>/dev/null
  find "$AIOS_DATA/ops/logs" -type f -mtime +30 -delete 2>/dev/null
  local pct; pct=$(df --output=pcent "$AIOS_ROOT" | tail -1 | tr -dc '0-9')
  [ "${pct:-0}" -gt 80 ] && printf -- '- [ ] %s  disk at %s%%\n' "$(date -Is)" "$pct" \
    >> "$AIOS_DATA/ops/security/alerts.md"
  return 0
}
run_routine sweep bash -c "$(declare -f sweep); AIOS_DATA=$AIOS_DATA AIOS_ROOT=$AIOS_ROOT sweep"
