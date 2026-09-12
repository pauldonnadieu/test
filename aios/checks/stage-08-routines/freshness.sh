#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
R="$D/ops/runs"
# Freshness is the whole stage. A routine that stopped firing and a quiet week
# look identical unless something checks the clock, which is why a usage limit
# starving the night's run shows up as a failure rather than as nothing.
fresh() { # fresh <file> <max hours>
  [ -f "$1" ] || { echo "no $1"; return 1; }
  local age=$(( ( $(date +%s) - $(stat -c %Y "$1") ) / 3600 ))
  [ "$age" -le "$2" ] || { echo "last record was ${age}h ago, budget ${2}h"; return 1; }
}
check RUN.1 "the check-in record is fresh within 36 hours" <<B
$(declare -f fresh); fresh "$R/check-in.jsonl" 36
B
check RUN.2 "the backup record is fresh within 36 hours" <<B
$(declare -f fresh); fresh "$R/backup.jsonl" 36
B
check RUN.3 "the weekly review record is fresh within 9 days" <<B
$(declare -f fresh); fresh "$R/weekly-review.jsonl" 216
B
check RUN.4 "every run record carries an explicit exit status" <<B
bad=""
while IFS= read -r f; do
  while IFS= read -r l; do
    [ -z "\$l" ] && continue
    printf '%s' "\$l" | grep -q '"exit"' || bad="\$bad \$f"
  done < "\$f"
done < <(find "$R" -name '*.jsonl' 2>/dev/null)
[ -z "\$bad" ] || { echo "records with no exit status:\$bad"; exit 1; }
B
check RUN.5 "the most recent run of each routine succeeded" <<B
bad=""
for f in "$R"/*.jsonl; do
  [ -f "\$f" ] || continue
  rc=\$(tail -1 "\$f" | sed -n 's/.*"exit":\([0-9-]*\).*/\1/p')
  [ "\${rc:-1}" = "0" ] || bad="\$bad \$(basename \$f .jsonl)(exit \$rc)"
done
[ -z "\$bad" ] || { echo "last run failed:\$bad"; exit 1; }
B
check RUN.6 "no stale lock files" <<B
old=\$(find "$D/ops" -name '.lock-*' -mmin +120 2>/dev/null)
[ -z "\$old" ] || { echo "\$old"; exit 1; }
B
check RUN.7 "the change ledger is current" <<B
L="$D/ops/change-ledger.jsonl"
[ -f "\$L" ] || { echo "no change ledger"; exit 1; }
age=\$(( ( \$(date +%s) - \$(stat -c %Y "\$L") ) / 3600 ))
[ "\$age" -le 36 ] || { echo "the ledger has not run for \${age}h"; exit 1; }
B
check RUN.8 "a crontab entry exists for every routine script" <<B
missing=""
for s in checkin-prompt backup change-ledger security-observe sweep weekly-review audit-scan health-check; do
  crontab -l 2>/dev/null | grep -q "\$s" || missing="\$missing \$s"
done
[ -z "\$missing" ] || { echo "not scheduled:\$missing"; exit 1; }
B
