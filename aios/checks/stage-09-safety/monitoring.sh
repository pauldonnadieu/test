#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
OBS="$D/ops/security/observations.jsonl"

check MON.1 "the nightly security observation ran within 36 hours" <<B
[ -f "$OBS" ] || { echo "no observations file"; exit 1; }
now=\$(date +%s); then=\$(stat -c %Y "$OBS")
age=\$(( (now - then) / 3600 ))
[ "\$age" -le 36 ] || { echo "last observation was \${age}h ago"; exit 1; }
B

check MON.2 "observations record listening sockets, users and keys" <<B
last=\$(tail -1 "$OBS" 2>/dev/null)
for k in listening users authorized_keys outbound_bytes; do
  printf '%s' "\$last" | grep -q "\"\$k\"" || { echo "no \$k field in the latest observation"; exit 1; }
done
B

check MON.3 "unreviewed security alerts are surfaced, not buried" <<B
A="$D/ops/security/alerts.md"
[ -f "\$A" ] || exit 0
n=\$(grep -c '^- \[ \]' "\$A" 2>/dev/null || echo 0)
[ "\$n" -le 10 ] || { echo "\$n unreviewed alerts have accumulated"; exit 1; }
B

check MON.4 "a changed authorized_keys is reported, not just recorded" <<B
A="$D/ops/security/alerts.md"
prev=\$(tail -2 "$OBS" 2>/dev/null | head -1 | sed -n 's/.*"authorized_keys":"\([^"]*\)".*/\1/p')
cur=\$(tail -1 "$OBS" 2>/dev/null | sed -n 's/.*"authorized_keys":"\([^"]*\)".*/\1/p')
[ -z "\$prev" ] && exit 0
[ "\$prev" = "\$cur" ] && exit 0
grep -q 'authorized_keys changed' "\$A" 2>/dev/null || { echo "the key file changed and no alert was raised"; exit 1; }
B

check MON.5 "a large jump in outbound bytes is reported" <<B
# The only thing in this whole design that would notice exfiltration, whether
# from a runaway fetcher or a session someone else is driving. Noisy by nature,
# and worth keeping anyway.
A="$D/ops/security/alerts.md"
prev=\$(tail -2 "$OBS" 2>/dev/null | head -1 | sed -n 's/.*"outbound_bytes":\([0-9]*\).*/\1/p')
cur=\$(tail -1 "$OBS" 2>/dev/null | sed -n 's/.*"outbound_bytes":\([0-9]*\).*/\1/p')
[ -z "\$prev" ] || [ -z "\$cur" ] && exit 0
[ "\$prev" -eq 0 ] 2>/dev/null && exit 0
if [ "\$cur" -gt \$((prev * 10)) ] 2>/dev/null; then
  grep -q 'outbound bytes jumped' "\$A" 2>/dev/null || { echo "outbound volume jumped from \$prev to \$cur and no alert was raised"; exit 1; }
fi
exit 0
B
