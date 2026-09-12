#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"
S="$C/settings.json"
H="$C/hooks"

check HK.1 "all four hooks exist" <<B
missing=""
for h in halt-gate write-guard danger-guard tool-audit; do
  [ -f "$H/\$h.sh" ] || missing="\$missing \$h"
done
[ -z "\$missing" ] || { echo "missing hooks:\$missing"; exit 1; }
B

check HK.2 "all four are registered in settings.json" <<B
missing=""
for h in halt-gate write-guard danger-guard tool-audit; do
  grep -qF "\$h.sh" "$S" || missing="\$missing \$h"
done
[ -z "\$missing" ] || { echo "not registered:\$missing"; exit 1; }
B

check HK.3 "no hook is writable by anyone but its owner" <<B
bad=""
for f in "$H"/*.sh; do
  m=\$(stat -c '%a' "\$f")
  case "\$m" in *[2367]|*[2367]?) bad="\$bad \$(basename \$f):\$m" ;; esac
done
[ -z "\$bad" ] || { echo "group or world writable:\$bad"; exit 1; }
B

check HK.4 "the halt gate refuses a session while the flag is set" <<B
T=\$(mktemp -d); export AIOS_HALT="\$T/.halt"; echo "check probe" > "\$AIOS_HALT"
printf '{}' | bash "$H/halt-gate.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "halt-gate allowed a session while halted"; exit 1; }
B

check HK.5 "the write guard refuses an escape out of the data mount" <<B
T=\$(mktemp -d); mkdir -p "\$T/data" "\$T/conf"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "\$T/data/../conf/settings.json" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "write-guard allowed a write to conf/ via .."; exit 1; }
B

check HK.6 "the write guard refuses a trusted-tree write after a quarantined read" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/review" "\$T/data/untrusted-external/p"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t"
echo x > "\$T/data/untrusted-external/p/raw"
printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "\$T/data/untrusted-external/p/raw" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "\$T/data/review/x.md" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "tainted session was allowed to write review/"; exit 1; }
B

check HK.7 "the write guard still allows an ordinary write" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/review"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "\$T/data/review/x.md" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -eq 0 ] || { echo "write-guard refuses everything, which is equally broken"; exit 1; }
B

check HK.8 "the danger guard refuses each of its named commands" <<B
allowed=""
for c in "rm -rf /data" "restic prune" "docker ps" "crontab -l"; do
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "\$c" \
    | bash "$H/danger-guard.sh" >/dev/null 2>&1 && allowed="\$allowed [\$c]"
done
[ -z "\$allowed" ] || { echo "allowed:\$allowed"; exit 1; }
B

check HK.9 "the audit log records names and never payloads" <<B
T=\$(mktemp -d); export AIOS_AUDIT="\$T/a.jsonl"
printf '{"tool_name":"Bash","tool_input":{"command":"grep -r CANARYSTRING /data"}}' \
  | bash "$H/tool-audit.sh" >/dev/null 2>&1
if grep -q CANARYSTRING "\$T/a.jsonl" 2>/dev/null; then rm -rf "\$T"; echo "audit captured command arguments"; exit 1; fi
[ -s "\$T/a.jsonl" ] || { rm -rf "\$T"; echo "audit wrote nothing"; exit 1; }
rm -rf "\$T"
B
