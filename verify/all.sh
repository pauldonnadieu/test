#!/usr/bin/env bash
# Runs every stage check that applies and aggregates the scores.
#
# This is not build scaffolding. Every property these scripts test can
# silently stop being true after an unrelated change months later, so
# this is the security regression suite. Wire it into the weekly audit.

cd "$(dirname "$0")" || exit 1
rc=0
total_pass=0
total_all=0

for s in stage*.sh; do
  [ -f "$s" ] || continue
  echo "=== $s ==="
  out=$(bash "$s" 2>&1); s_rc=$?
  echo "$out"
  echo
  line=$(echo "$out" | grep -E '^SCORE ' | tail -1)
  if [ -n "$line" ]; then
    p=${line#SCORE }; p=${p%% *}
    total_pass=$((total_pass + ${p%%/*}))
    total_all=$((total_all + ${p##*/}))
  fi
  [ "$s_rc" -eq 0 ] || rc=1
done

echo "TOTAL ${total_pass}/${total_all}"
[ "$rc" -eq 0 ] && echo "ALL CHECKS PASS" || echo "NOT ALL CHECKS PASS"
exit $rc
