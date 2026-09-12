#!/usr/bin/env bash
# The regression gate. Mechanical, and therefore the part of the improvement
# loop that can be trusted without judgement.
#
#   ./run-all.sh --json > before.json
#   # apply exactly one change
#   ./run-all.sh --json > after.json
#   ./compare-scores.sh before.json after.json   # non-zero means revert
#
# Any check that was passing and is now failing, skipping, OR MISSING is a
# regression. The missing case matters most: deleting the check that fails is
# the cheapest way to make a change look safe, and the score would read
# 2/3 -> 2/2, which looks like nothing happened.

set -uo pipefail
[ $# -eq 2 ] || { echo "usage: compare-scores.sh before.json after.json" >&2; exit 2; }
for f in "$1" "$2"; do [ -f "$f" ] || { printf 'no such file: %s\n' "$f" >&2; exit 2; }; done

field() { sed -n 's/.*"'"$2"'":"\([^"]*\)".*/\1/p' "$1"; }

before_passing=$(field "$1" passing)
before_seen=$(field "$1" seen)
after_passing=$(field "$2" passing)
after_seen=$(field "$2" seen)

# A check that was passing and no longer is.
broke=""
for id in $before_passing; do
  printf '%s\n' $after_seen | grep -qxF "$id" || continue
  printf '%s\n' $after_passing | grep -qxF "$id" || broke="$broke $id"
done

# A check that existed before and has gone, WHATEVER its previous verdict.
# Deleting a check that was already failing is the cheapest way to hide the
# failure: the score reads 2/3 -> 2/2 and looks like nothing happened. So the
# gate treats any vanished check as a regression, not only a passing one.
vanished=""
for id in $before_seen; do
  printf '%s\n' $after_seen | grep -qxF "$id" || vanished="$vanished $id"
done

fixed=""
for id in $after_passing; do
  printf '%s\n' $before_passing | grep -qxF "$id" || fixed="$fixed $id"
done

[ -n "$fixed" ]    && printf 'now passing that was not:%s\n' "$fixed"
[ -n "$broke" ]    && printf 'REGRESSION, was passing and now is not:%s\n' "$broke"
[ -n "$vanished" ] && printf 'REGRESSION, has VANISHED from the suite:%s\n' "$vanished"

if [ -n "$broke$vanished" ]; then
  echo
  echo "REVERT. A change that breaks a property the system already had is not a"
  echo "trade-off to weigh up, it is a change that failed."
  exit 1
fi
echo "no regressions"
