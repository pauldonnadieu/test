#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"
B="${AIOS_BIN:-${AIOS_ROOT:-/srv/aios}/bin}"
H="$C/hooks"

check FT.1 "the utility directory exists and is separate from the coaching tree" <<B
[ -d "$D/utility" ] || { echo "no $D/utility"; exit 1; }
B

check FT.2 "the free-tier credential is not reachable from the container" <<B
S="${AIOS_SECRETS:-${AIOS_ROOT:-/srv/aios}/secrets}"
hits=\$(grep -rlE '(GEMINI|GOOGLE_AI|OPENROUTER|GROQ|TOGETHER)[A-Z_]*(KEY|TOKEN)' "$D" "$C" 2>/dev/null)
[ -z "\$hits" ] || { echo "free-tier credential inside data or conf:\$hits"; exit 1; }
B

check FT.3 "the utility router refuses to read the coaching tree" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/utility" "\$T/data/goals" "\$T/data/daily"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t" AIOS_LANE=utility
printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "\$T/data/daily/check-ins.jsonl" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "utility lane was allowed to read daily/"; exit 1; }
B

check FT.4 "the utility router refuses to write the coaching tree" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/utility" "\$T/data/goals"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t" AIOS_LANE=utility
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "\$T/data/goals/health.md" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "utility lane was allowed to write goals/"; exit 1; }
B

check FT.5 "the utility lane still works inside its own directory" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/utility"
export AIOS_ROOT="\$T" AIOS_DATA="\$T/data" AIOS_TAINT="\$T/t" AIOS_LANE=utility
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "\$T/data/utility/shopping.md" \
  | bash "$H/write-guard.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -eq 0 ] || { echo "utility lane cannot write its own directory, which makes it useless"; exit 1; }
B

check FT.6 "the coaching layer never writes into utility/" <<B
hits=\$(grep -rln 'utility/' "${AIOS_SKILLS:-${AIOS_ROOT:-/srv/aios}/conf/skills}" 2>/dev/null | grep -v 'utility' || true)
[ -z "\$hits" ] || { echo "a coaching skill references utility/:\$hits"; exit 1; }
B
