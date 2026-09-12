#!/usr/bin/env bash
# Shared shape for every scheduled routine. Sourced, or invoked directly with a
# routine name to test the halt path.
#
# Three things about this file are deliberate and none of them is style:
#
#  1. The halt check comes FIRST, before the lock and before any work. A halt
#     check after the lock is a halt check that does not halt the run you are
#     trying to stop.
#  2. The run record holds METADATA ONLY. Model output can contain anything the
#     session was discussing, ops/ is inside the backup, and a run log that
#     accumulates transcripts for ever is a leak nobody thinks of as one.
#     Full output goes to a dated log with a 30-day life.
#  3. A non-zero exit is never swallowed. A wrapper that hides failures produces
#     a log full of successes and a system full of gaps.

set -uo pipefail
AIOS_ROOT="${AIOS_ROOT:-/srv/aios}"
AIOS_DATA="${AIOS_DATA:-$AIOS_ROOT/data}"
RUNS="$AIOS_DATA/ops/runs"
LOGS="$AIOS_DATA/ops/logs"
HALT="$AIOS_DATA/ops/.halt"

halt_check() {
  if [ -e "$HALT" ]; then
    printf 'halted: %s\n' "$(head -c 200 "$HALT" 2>/dev/null)"
    return 1
  fi
  return 0
}

# classify_error <text> : a small, fixed vocabulary rather than free text, so a
# month of run records can be counted rather than read.
classify_error() {
  case "$1" in
    *"usage limit"*|*"rate limit"*|*"quota"*)        echo usage_limit ;;
    *"not authenticated"*|*"login"*|*"OAuth"*|*401*) echo auth ;;
    *"timed out"*|*timeout*)                         echo timeout ;;
    *"No space left"*|*ENOSPC*)                      echo disk_full ;;
    *)                                               echo other ;;
  esac
}

# run_routine <name> <command...>
run_routine() {
  local name="$1"; shift
  mkdir -p "$RUNS" "$LOGS"
  halt_check || { printf '%s halted, nothing run\n' "$name"; return 0; }

  local lock="$AIOS_DATA/ops/.lock-$name"
  exec 9>"$lock" || return 1
  flock -n 9 || { printf '%s already running\n' "$name"; return 0; }

  local start out rc model err log
  start=$(date -Is)
  log="$LOGS/$name-$(date +%F).log"
  out=$("$@" 2>&1); rc=$?
  printf '%s\n' "$out" >> "$log"; chmod 600 "$log" 2>/dev/null

  model=$(printf '%s' "$out" | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  [ -z "$model" ] && model="${AIOS_MODEL:-none}"
  err=""
  [ "$rc" -ne 0 ] && err=$(classify_error "$out")

  printf '{"start":"%s","end":"%s","routine":"%s","exit":%d,"model":"%s","error_class":"%s","degraded":%s}\n' \
    "$start" "$(date -Is)" "$name" "$rc" "$model" "$err" "${AIOS_DEGRADED:-false}" >> "$RUNS/$name.jsonl"
  return "$rc"
}

# Invoked directly: used by KS.2 to prove the halt path without running work.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  name="${1:-probe}"
  run_routine "$name" true
  exit $?
fi
