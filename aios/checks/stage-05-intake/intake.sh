#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
# The mechanical part of the intake. Whether the picture is specific enough to
# be worth reasoning over is a human judgement, written into 02-build.md stage 5
# rather than pretended into a check.
check IN.1 "no goal file is still a template" <<B
hits=\$(grep -rl 'TEMPLATE - not yet filled in' "$D/goals" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check IN.2 "five or fewer active goals" <<B
n=\$(grep -rl '^status: active\$' "$D/goals" 2>/dev/null | wc -l)
[ "\$n" -le 5 ] || { echo "\$n active goals; the cap is five and overload is the failure that wrecks the others"; exit 1; }
[ "\$n" -ge 1 ] || { echo "no active goals"; exit 1; }
B
check IN.3 "every active goal has a next action and a stated capacity" <<B
bad=""
for f in \$(grep -rl '^status: active\$' "$D/goals" 2>/dev/null); do
  grep -qi '^## next action' "\$f" || bad="\$bad \$(basename \$f):no-next-action"
  grep -qi '^## capacity'    "\$f" || bad="\$bad \$(basename \$f):no-capacity"
done
[ -z "\$bad" ] || { echo "\$bad"; exit 1; }
B
