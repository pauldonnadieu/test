#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
B="${AIOS_BIN:-${AIOS_ROOT:-/srv/aios}/bin}"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
# Every check and script here is a claim about a CLI that ships updates. When a
# flag is renamed the scripts keep running, the checks keep passing, and the
# property quietly stops being true.
check DRIFT.1 "every flag the scripts pass still exists in claude --help" <<B
h=\$(claude --help 2>&1) || { echo "cannot run claude --help"; exit 1; }
missing=""
for flag in \$(grep -rho -- '--[a-z][a-z-]*' "$B"/*.sh | sort -u); do
  case "\$flag" in --tag|--exclude-caches|--target|--include|--json|--last|--keep-daily|--read-data-subset|--max-time|--output) continue ;; esac
  printf '%s' "\$h" | grep -q -- "\$flag" || missing="\$missing \$flag"
done
[ -z "\$missing" ] || { echo "flags no longer in the CLI:\$missing"; exit 1; }
B
check DRIFT.2 "the CLI version is recorded and a change is reported" <<B
V="$D/ops/.cli-version"
now=\$(claude --version 2>&1 | head -1) || exit 0
if [ -f "\$V" ]; then
  was=\$(cat "\$V")
  [ "\$was" = "\$now" ] || echo "note: CLI moved from \$was to \$now; read the release notes before the next scan"
fi
printf '%s' "\$now" > "\$V" 2>/dev/null
exit 0
B
check DRIFT.3 "the hook payload adapter matches the installed CLI" <<B
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"
[ -f "\$C/hooks/_payload.sh" ] || { echo "no payload adapter"; exit 1; }
grep -q 'tool_name' "\$C/hooks/_payload.sh" || { echo "the adapter does not read a tool name"; exit 1; }
B
