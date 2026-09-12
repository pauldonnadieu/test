#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
A="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}/ops/attestations.md"
# The five entries are a MINIMUM, not a definition. Edit this list to match what
# actually matters about your setup.
ENTRIES="anthropic-2fa data-training-off restic-password-offline google-2fa hetzner-2fa"

check ATT.1 "the attestations file exists" <<B
[ -f "$A" ] || { echo "no $A"; exit 1; }
B
check ATT.2 "every required entry is present" <<B
missing=""
for e in $ENTRIES; do grep -q "\$e" "$A" 2>/dev/null || missing="\$missing \$e"; done
[ -z "\$missing" ] || { echo "missing:\$missing"; exit 1; }
B
check ATT.3 "no entry is still unfilled" <<B
hits=\$(grep -n 'UNATTESTED\|TODO' "$A" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check ATT.4 "every entry carries an ISO date" <<B
bad=""
while IFS= read -r line; do
  case "\$line" in ''|'#'*|'|'*) continue ;; esac
  printf '%s' "\$line" | grep -q '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || bad="\$bad [\$line]"
done < <(grep -E "\$(printf '%s|' $ENTRIES | sed 's/|$//')" "$A" 2>/dev/null)
[ -z "\$bad" ] || { echo "no date on:\$bad"; exit 1; }
B
check ATT.5 "the newest attestation is less than 12 months old" <<B
newest=\$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$A" 2>/dev/null | sort | tail -1)
[ -n "\$newest" ] || { echo "no dates at all"; exit 1; }
cutoff=\$(date -d '12 months ago' +%F 2>/dev/null || date -v-12m +%F)
[ "\$newest" \> "\$cutoff" ] || { echo "newest attestation is \$newest"; exit 1; }
B
check ATT.6 "an attestation within 30 days of expiry is surfaced, not sprung" <<B
soon=\$(date -d '11 months ago' +%F 2>/dev/null || date -v-11m +%F)
old=\$(grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$A" 2>/dev/null | sort | head -1)
[ -n "\$old" ] || exit 0
[ "\$old" \> "\$soon" ] || echo "note: an attestation from \$old expires within 30 days"
exit 0
B
