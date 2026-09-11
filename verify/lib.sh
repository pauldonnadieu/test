#!/usr/bin/env bash
# Shared harness for AIOS verification scripts.
#
# Every check emits one line. The last lines are an objective score and,
# on failure, the names of what failed. That score is what the /goal
# evaluator reads out of the transcript, so it must be printed on every
# run, pass or fail.
#
# Usage:
#   source "$(dirname "$0")/lib.sh"
#   check name "human description" <<'TEST'
#   ...shell that exits 0 for pass...
#   TEST
#   summary stage1-host

set -uo pipefail

_PASS=0
_FAIL=0
_SKIP=0
_FAILED_NAMES=()
_SKIPPED_NAMES=()

# check <name> <description> ; body on stdin
check() {
  local name="$1" desc="$2" out rc
  out=$(bash 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    _PASS=$((_PASS + 1))
    printf '[PASS] %-32s %s\n' "$name" "$desc"
  else
    _FAIL=$((_FAIL + 1))
    _FAILED_NAMES+=("$name")
    printf '[FAIL] %-32s %s\n' "$name" "$desc"
    if [ -n "$out" ]; then
      printf '       %s\n' "$out" | head -5
    fi
  fi
}

# skip <name> <reason> - for checks that cannot run in this context.
# A skip is never a pass. It is counted and named so it cannot hide.
skip() {
  _SKIP=$((_SKIP + 1))
  _SKIPPED_NAMES+=("$1")
  printf '[SKIP] %-32s %s\n' "$1" "$2"
}

# summary <stage-name> - prints the score and exits non-zero on any
# failure or skip. Exit 0 means every check ran and every check passed.
summary() {
  local stage="$1" total=$((_PASS + _FAIL + _SKIP))
  echo
  echo "SCORE ${_PASS}/${total} ${stage}"
  if [ "${#_FAILED_NAMES[@]}" -gt 0 ]; then
    echo "FAILED: ${_FAILED_NAMES[*]}"
  fi
  if [ "${#_SKIPPED_NAMES[@]}" -gt 0 ]; then
    echo "SKIPPED: ${_SKIPPED_NAMES[*]}"
  fi
  [ "$_FAIL" -eq 0 ] && [ "$_SKIP" -eq 0 ]
}
