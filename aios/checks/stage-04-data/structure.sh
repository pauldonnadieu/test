#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"

check DATA.1 "at most seven top-level data directories" <<B
n=\$(find "$D" -maxdepth 1 -mindepth 1 -type d | wc -l)
[ "\$n" -ge 1 ] && [ "\$n" -le 7 ] || { echo "found \$n top-level directories"; exit 1; }
B

check DATA.2 "the quarantine directory is named unambiguously" <<B
[ -d "$D/untrusted-external" ] || { echo "no $D/untrusted-external"; exit 1; }
B

check DATA.3 "no filename-versioned files" <<B
hits=\$(find "$D" -type f \( -name '*-v[0-9]*' -o -name '*_v[0-9]*' -o -name '*final*' -o -name '*.bak' -o -name '*copy*' \) 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check DATA.4 "every .jsonl parses, line by line" <<B
bad=""
while IFS= read -r f; do
  n=0
  while IFS= read -r line; do
    n=\$((n+1))
    [ -z "\$line" ] && continue
    printf '%s' "\$line" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null || bad="\$bad \$f:\$n"
  done < "\$f"
done < <(find "$D" -type f -name '*.jsonl' 2>/dev/null)
[ -z "\$bad" ] || { echo "unparseable:\$bad"; exit 1; }
B

check DATA.5 "START-HERE.md names exactly the directories that exist" <<B
M="$D/START-HERE.md"
[ -f "\$M" ] || { echo "no START-HERE.md"; exit 1; }
missing=""
for d in \$(find "$D" -maxdepth 1 -mindepth 1 -type d -printf '%f\n'); do
  grep -q "\$d" "\$M" || missing="\$missing \$d"
done
[ -z "\$missing" ] || { echo "not described in START-HERE.md:\$missing"; exit 1; }
B

check DATA.6 "every data directory carries a README" <<B
missing=""
for d in \$(find "$D" -maxdepth 1 -mindepth 1 -type d); do
  [ -f "\$d/README.md" ] || missing="\$missing \$(basename \$d)"
done
[ -z "\$missing" ] || { echo "no README.md in:\$missing"; exit 1; }
B
