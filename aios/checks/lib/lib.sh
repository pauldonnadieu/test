#!/usr/bin/env bash
# AIOS check library. Sourced by every check script.
#
# Contract: a check script sources this file, calls `check` or `skip` once per
# check ID it owns, and exits. It never decides the overall verdict; run-all.sh
# does that, by comparing emitted IDs against checks/expected-ids.txt.
#
# Emitted line format, tab separated:
#   VERDICT <TAB> ID <TAB> DESCRIPTION <TAB> DETAIL
# VERDICT is PASS, FAIL or SKIP. A SKIP is scored as a failure by the runner:
# an unrun check is an unknown, and an unknown is not a pass.

set -uo pipefail

_emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4-}"; }

# check <ID> <description>   body on stdin
# The body's exit status decides the verdict. Its output becomes the detail on
# failure, truncated, so a FAIL line names the path or value that was wrong.
check() {
  local id="$1" desc="$2" out rc
  out=$(bash 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    _emit PASS "$id" "$desc" ""
  else
    _emit FAIL "$id" "$desc" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
  fi
}

# skip <ID> <description> <reason>
# Use only where the property genuinely cannot be observed from here. The
# runner scores it as a failure, which is the honest state of an unproven claim.
skip() { _emit SKIP "$1" "$2" "${3:-not testable in this environment}"; }

# require <var> ... : skip-friendly guard for checks that need configuration.
# Returns non-zero if any named variable is unset or empty.
require() {
  local v
  for v in "$@"; do
    [ -n "${!v:-}" ] || { printf '%s is not set in config.env' "$v"; return 1; }
  done
}
