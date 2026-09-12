#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"

check PRV.1 "every goals/ and reference/ file has provenance frontmatter" <<B
bad=""
while IFS= read -r f; do
  case "\$(basename "\$f")" in README.md) continue ;; esac
  head -6 "\$f" | grep -q '^trust: \(confirmed\|inferred\|external\)\$' || bad="\$bad \$f"
done < <(find "$D/goals" "$D/reference" -type f -name '*.md' 2>/dev/null)
[ -z "\$bad" ] || { echo "missing or invalid trust::\$bad"; exit 1; }
B

check PRV.2 "nothing in quarantine claims to be confirmed" <<B
hits=\$(grep -rl '^trust: confirmed\$' "$D/untrusted-external" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check PRV.3 "no claim is past its review_after date" <<B
today=\$(date +%F); stale=""
while IFS= read -r f; do
  d=\$(sed -n 's/^review_after: \([0-9-]*\)\$/\1/p' "\$f" | head -1)
  [ -n "\$d" ] && [ "\$d" \< "\$today" ] && stale="\$stale \$f(\$d)"
done < <(find "$D" -type f -name '*.md' 2>/dev/null)
[ -z "\$stale" ] || { echo "past review_after:\$stale"; exit 1; }
B
