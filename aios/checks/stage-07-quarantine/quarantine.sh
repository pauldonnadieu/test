#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
B="${AIOS_BIN:-${AIOS_ROOT:-/srv/aios}/bin}"
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"

check QR.1 "the quarantine directory exists" <<B
[ -d "$D/untrusted-external" ] || { echo "no quarantine directory"; exit 1; }
B
check QR.2 "the fetcher writes only into the quarantine" <<B
grep -q 'untrusted-external' "$B/fetch-untrusted.sh" || { echo "the fetcher does not target the quarantine"; exit 1; }
grep -qE '\-\-allowedTools "WebFetch,Write"' "$B/fetch-untrusted.sh" || { echo "the fetcher's allowlist is wider than WebFetch and Write"; exit 1; }
B
check QR.3 "the summariser is granted no network tool" <<B
a=\$(grep -o -- '--allowedTools "[^"]*"' "$B/summarise-untrusted.sh")
printf '%s' "\$a" | grep -qi 'webfetch\|websearch' && { echo "the summariser can reach the network: \$a"; exit 1; }
exit 0
B
check QR.4 "the summariser is granted no Bash" <<B
a=\$(grep -o -- '--allowedTools "[^"]*"' "$B/summarise-untrusted.sh")
printf '%s' "\$a" | grep -q 'Bash' && { echo "the summariser has Bash: \$a"; exit 1; }
exit 0
B
check QR.5 "the summariser runs with prompts disabled" <<B
grep -q -- '--permission-prompts none' "$B/summarise-untrusted.sh" || { echo "prompts are not disabled"; exit 1; }
B
check QR.6 "the summariser's working directory is pinned to one folder" <<B
grep -q -- '-w "\$dir"' "$B/summarise-untrusted.sh" || { echo "no working directory pin"; exit 1; }
B
check QR.7 "every summary carries its provenance marker" <<B
bad=""
while IFS= read -r f; do
  head -6 "\$f" | grep -q '^trust: external\$' || bad="\$bad \$f"
done < <(find "$D/untrusted-external" -name 'summary.md' 2>/dev/null)
[ -z "\$bad" ] || { echo "untagged summaries:\$bad"; exit 1; }
B
check QR.8 "nothing carrying the marker exists in the trusted tree" <<B
hits=\$(grep -rl '^trust: external\$' "$D/goals" "$D/review" "$D/reference" "$D/daily" 2>/dev/null)
[ -z "\$hits" ] || { echo "quarantined content laundered into the trusted tree:\$hits"; exit 1; }
B
check QR.9 "no raw fetch is older than 30 days" <<B
old=\$(find "$D/untrusted-external" -name raw -type f -mtime +30 2>/dev/null)
[ -z "\$old" ] || { echo "\$old"; exit 1; }
B
check QR.10 "the fetcher's settings exception is declared" <<B
E="${AIOS_EXCEPTIONS:-$AIOS_CHECKS/settings-exceptions.txt}"
grep -qx 'fetch-untrusted.sh' "\$E" 2>/dev/null || { echo "the one legitimate --settings use is not declared"; exit 1; }
n=\$(grep -cv '^#' "\$E" 2>/dev/null)
[ "\$n" -le 1 ] || { echo "\$n --settings exceptions; a second one is a change to the security model"; exit 1; }
B
