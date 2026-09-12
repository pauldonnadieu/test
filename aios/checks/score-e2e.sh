#!/usr/bin/env bash
# Scores a cold-reader dry run against test/CRITERIA.md tier 1.
#
# Usage: score-e2e.sh <built-tree-root>
#
# The traps are things the documents warn about explicitly. A cold reader
# falling into one means the warning did not land, and the defect is in the
# writing rather than in the reader.
set -uo pipefail
R="${1:?usage: score-e2e.sh <built-tree-root>}"
fails=0
trap_fail() { printf 'TRAP   %-34s %s\n' "$1" "$2"; fails=$((fails+1)); }
trap_ok()   { printf 'ok     %-34s\n' "$1"; }

t() { # t <name> <grep-expression-that-should-find-NOTHING> [path]
  local name="$1" pat="$2" path="${3:-$R}"
  [ -e "$path" ] || { trap_ok "$name"; return; }
  local hits; hits=$(grep -rlE -e "$pat" "$path" 2>/dev/null | head -3)
  [ -z "$hits" ] && trap_ok "$name" || trap_fail "$name" "$hits"
}

t "no --bare"              '(^|[[:space:]])--bare([[:space:]]|$)'  "$R/bin"
t "no hardcoded API key"   'ANTHROPIC_API_KEY'                     "$R/bin"
t "no --dangerously-skip"  'dangerously-skip-permissions'          "$R/bin"
t "no bypassPermissions"   'bypassPermissions'                     "$R/bin"
t "no secrets in rebuild"  '(sk-[A-Za-z0-9_-]{16,}|-----BEGIN .*PRIVATE KEY|AIza[0-9A-Za-z_-]{20,})' "$R/rebuild"

[ -z "$(find "$R" -name '.mcp.json' 2>/dev/null)" ] && trap_ok "no .mcp.json" || trap_fail "no .mcp.json" "found"
[ -z "$(find "$R/data" -type f \( -name '*-v[0-9]*' -o -name '*.bak' -o -name '*final*' \) 2>/dev/null)" ] \
  && trap_ok "no filename versioning" || trap_fail "no filename versioning" "found"

# Hooks: ABSENT is the failure. Note the inversion from earlier versions of this
# set, where configured hooks were themselves a trap. A reader working from
# stale guidance will get this exactly backwards.
missing=""
for h in halt-gate write-guard danger-guard tool-audit; do
  [ -f "$R/conf/hooks/$h.sh" ] || missing="$missing $h"
done
[ -z "$missing" ] && trap_ok "all four hooks present" || trap_fail "all four hooks present" "missing:$missing"
grep -q 'write-guard' "$R/conf/settings.json" 2>/dev/null \
  && trap_ok "hooks registered" || trap_fail "hooks registered" "not in settings.json"

# conf/ in the backup: a restore without it returns a machine that has
# forgotten everything it learned.
# Match the restic PATH ARGUMENT, not the word in a comment. The original
# version of this check passed on a sabotaged file because backup.sh explains
# in prose why conf/ is included.
grep -qE '^[^#]*restic backup|^[^#]*"\$AIOS_ROOT/conf"' "$R/bin/backup.sh" 2>/dev/null \
  && grep -qE '^[^#]*\$AIOS_ROOT/conf' "$R/bin/backup.sh" 2>/dev/null \
  && trap_ok "conf/ is in the backup" \
  || trap_fail "conf/ is in the backup" "the backup covers data/ only; a restore would forget everything it learned"

# The utility lane must not be able to reach the coaching tree.
if [ -d "$R/data/utility" ]; then
  if [ -f "$R/conf/hooks/guard-lib.sh" ] && grep -q 'AIOS_LANE' "$R/conf/hooks/guard-lib.sh"; then
    trap_ok "utility lane is confined"
  else trap_fail "utility lane is confined" "no lane restriction in guard-lib.sh"; fi
fi

# The load-bearing one, and the only trap tested by BEHAVIOUR rather than by
# reading configuration: become the agent's uid and try the write.
if id aios >/dev/null 2>&1 && [ -f "$R/conf/settings.json" ]; then
  if sudo -n -u aios test -w "$R/conf/settings.json" 2>/dev/null; then
    trap_fail "agent uid cannot write settings.json" "IT CAN. Every rule binding it is decoration"
  else trap_ok "agent uid cannot write settings.json"; fi
else
  printf 'SKIP   %-34s %s\n' "agent uid cannot write settings.json" "no aios user here; an unrun check is not a pass"
  fails=$((fails+1))
fi

# Structure
n=$(find "$R/data" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
[ "$n" -ge 1 ] && [ "$n" -le 7 ] && trap_ok "1-7 data directories" || trap_fail "1-7 data directories" "found $n"
[ -d "$R/data/untrusted-external" ] && trap_ok "quarantine named unambiguously" \
  || trap_fail "quarantine named unambiguously" "no untrusted-external/"
[ -f "$R/conf/CLAUDE.md" ] && [ "$(wc -l < "$R/conf/CLAUDE.md")" -le 200 ] \
  && trap_ok "CLAUDE.md within budget" || trap_fail "CLAUDE.md within budget" "missing or over 200 lines"

echo
if [ "$fails" -eq 0 ]; then echo "VERDICT: PASS (tier 1). Attach the tier 2 defect list."; exit 0
else echo "VERDICT: FAIL. $fails trap(s) or structure checks failed."; exit 1; fi
