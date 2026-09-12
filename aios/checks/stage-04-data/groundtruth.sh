#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
F="$D/daily/check-ins.jsonl"
# SIGNALS, not health. These measure whether the user is using the system,
# which is information about a fortnight of their life and not a fault in the
# machine. Scoring them as faults turns illness into a red suite, and a red
# suite unlocks the change budget in 04-improvement.md.
check GT.1 "the check-in file exists" <<B
[ -f "$F" ] || { echo "no check-in file"; exit 1; }
B
check GT.2 "a check-in was recorded today or yesterday" <<B
last=\$(tail -1 "$F" 2>/dev/null | sed -n 's/.*"date":"\([0-9-]*\)".*/\1/p')
[ -n "\$last" ] || { echo "no dated check-ins"; exit 1; }
y=\$(date -d yesterday +%F 2>/dev/null || date -v-1d +%F)
[ "\$last" \> "\$y" ] || [ "\$last" = "\$y" ] || { echo "last check-in was \$last"; exit 1; }
B
check GT.3 "at least ten check-ins in the last fourteen days" <<B
c=0
for i in \$(seq 0 13); do
  d=\$(date -d "-\$i day" +%F 2>/dev/null || date -v-\${i}d +%F)
  grep -q "\"date\":\"\$d\"" "$F" 2>/dev/null && c=\$((c+1))
done
[ "\$c" -ge 10 ] || { echo "\$c of the last 14 days; the weekly review will name its own thin evidence"; exit 1; }
B
