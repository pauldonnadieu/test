#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"

check LOG.1 "no run record contains model output" <<B
bad=""
while IFS= read -r f; do
  grep -qE '"(output|tail|stdout|response|text|content)"[[:space:]]*:' "\$f" && bad="\$bad \$f"
done < <(find "$D/ops/runs" -type f -name '*.jsonl' 2>/dev/null)
[ -z "\$bad" ] || { echo "run records carrying output:\$bad"; exit 1; }
B

check LOG.2 "nothing under ops/ matches a secret shape" <<B
hits=\$(grep -rlE '(sk-[A-Za-z0-9_-]{16,}|-----BEGIN [A-Z ]*PRIVATE KEY|password[[:space:]]*=[[:space:]]*[^[:space:]]|AKIA[0-9A-Z]{16})' "$D/ops" 2>/dev/null)
[ -z "\$hits" ] || { echo "possible secret in:\$hits"; exit 1; }
B

check LOG.3 "every run record names the model actually served" <<B
bad=""
while IFS= read -r f; do
  while IFS= read -r line; do
    [ -z "\$line" ] && continue
    printf '%s' "\$line" | grep -q '"model"' || bad="\$bad \$f"
  done < "\$f"
done < <(find "$D/ops/runs" -type f -name '*.jsonl' 2>/dev/null)
[ -z "\$bad" ] || { echo "records with no model field:\$bad"; exit 1; }
B

check LOG.4 "no log under ops/logs is older than 30 days" <<B
old=\$(find "$D/ops/logs" -type f -mtime +30 2>/dev/null)
[ -z "\$old" ] || { echo "\$old"; exit 1; }
B
