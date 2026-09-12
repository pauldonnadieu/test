#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"
B="${AIOS_BIN:-${AIOS_ROOT:-/srv/aios}/bin}"
S="$C/settings.json"

check RT.1 "settings.json exists and is valid JSON" <<B
[ -f "$S" ] || { echo "no $S"; exit 1; }
python3 -c 'import json,sys; json.load(open("$S"))' 2>&1 || exit 1
B

check RT.2 "every required deny rule is present" <<B
missing=""
for rule in 'WebFetch' 'Bash(curl' 'Bash(wget' 'Bash(sudo' 'Bash(docker' 'Bash(crontab' 'Read('; do
  grep -qF "\$rule" "$S" || missing="\$missing \$rule"
done
[ -z "\$missing" ] || { echo "missing deny rules:\$missing"; exit 1; }
B

check RT.3 "at least five deny rules" <<B
n=\$(python3 -c 'import json;d=json.load(open("$S"));print(len(d.get("permissions",{}).get("deny",[])))')
[ "\$n" -ge 5 ] || { echo "only \$n deny rules"; exit 1; }
B

check RT.5 "auto memory is off" <<B
v=\$(python3 -c 'import json;print(json.load(open("$S")).get("autoMemoryEnabled","MISSING"))')
[ "\$v" = "False" ] || { echo "autoMemoryEnabled is \$v"; exit 1; }
B

check RT.4 "no .mcp.json anywhere under the root" <<B
hits=\$(find "${AIOS_ROOT:-/srv/aios}" -name '.mcp.json' 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check RT.6 "CLAUDE.md exists and is within its line budget" <<B
F="$C/CLAUDE.md"
[ -f "\$F" ] || { echo "no \$F"; exit 1; }
n=\$(wc -l < "\$F")
[ "\$n" -le 200 ] || { echo "CLAUDE.md is \$n lines, budget fails at 200"; exit 1; }
B

check RT.7 "no script uses --bare" <<B
hits=\$(grep -rln -- '--bare' "$B" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check RT.8 "no script sets ANTHROPIC_API_KEY for a Claude invocation" <<B
hits=\$(grep -rln 'ANTHROPIC_API_KEY' "$B" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check RT.9 "no script uses --dangerously-skip-permissions" <<B
hits=\$(grep -rln -- '--dangerously-skip-permissions' "$B" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B

check RT.10 "every --settings use is declared in settings-exceptions.txt" <<B
E="${AIOS_EXCEPTIONS:-$AIOS_CHECKS/settings-exceptions.txt}"
[ -f "\$E" ] || { echo "no exceptions file"; exit 1; }
undeclared=""
while IFS= read -r f; do
  grep -qxF "\$(basename "\$f")" "\$E" || undeclared="\$undeclared \$(basename "\$f")"
done < <(grep -rln -- '--settings' "$B" 2>/dev/null)
[ -z "\$undeclared" ] || { echo "undeclared --settings use:\$undeclared"; exit 1; }
B

check RT.11 "every model-calling script names an explicit --model" <<B
bad=""
while IFS= read -r f; do
  grep -q -- '--model' "\$f" || bad="\$bad \$(basename "\$f")"
done < <(grep -rln 'claude -p' "$B" 2>/dev/null)
[ -z "\$bad" ] || { echo "no --model in:\$bad"; exit 1; }
B

check RT.12 "no script requests bypassPermissions" <<B
hits=\$(grep -rln 'bypassPermissions' "$B" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
