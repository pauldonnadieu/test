#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Nightly, after the backup. No model: sha256sum, sort and diff.
# This is what fills the gap where git would have been. It tells you THAT a
# file changed, when, and in what context, and points you at the snapshot to
# diff against. That is what the four-week measurement window actually needs.
LEDGER="$AIOS_DATA/ops/change-ledger.jsonl"
STATE="$AIOS_DATA/ops/.manifest-sha256"
ledger_run() {
  local new; new=$(mktemp)
  find "$AIOS_DATA" "$AIOS_ROOT/conf" -type f \
       ! -path "*/ops/logs/*" ! -path "*/ops/runs/*" ! -name '.manifest-sha256' \
       -exec sha256sum {} + 2>/dev/null | sort -k2 > "$new"
  if [ -f "$STATE" ]; then
    diff "$STATE" "$new" | awk -v ts="$(date -Is)" '
      /^< /{old[$3]=$2} /^> /{nw[$3]=$2}
      END{for(p in nw) printf "{\"ts\":\"%s\",\"path\":\"%s\",\"old\":\"%s\",\"new\":\"%s\"}\n",
          ts, p, (p in old ? old[p] : "absent"), nw[p]
          for(p in old) if(!(p in nw)) printf "{\"ts\":\"%s\",\"path\":\"%s\",\"old\":\"%s\",\"new\":\"deleted\"}\n", ts, p, old[p]}'
  fi
  mv "$new" "$STATE"
}
run_routine change-ledger bash -c "$(declare -f ledger_run); AIOS_DATA=$AIOS_DATA AIOS_ROOT=$AIOS_ROOT STATE=$STATE ledger_run >> $LEDGER"
