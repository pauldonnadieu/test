#!/usr/bin/env bash
# PreToolUse on Write, Edit and Read. The load-bearing hook.
# Guards paths in both directions: nothing leaves the data mount, the utility
# lane stays in its lane, and a session that has read quarantined content
# cannot write into the trusted tree for the rest of that session.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/_payload.sh"; . "$HERE/guard-lib.sh"
read_payload
[ -n "${HOOK_PATH:-}" ] || exit 0          # no path argument, nothing to guard
case "${HOOK_TOOL:-}" in
  Read|read_file|NotebookRead)
      reason=$(guard_read  "$HOOK_PATH") || deny "$reason" ;;
  Write|Edit|NotebookEdit|MultiEdit)
      reason=$(guard_write "$HOOK_PATH") || deny "$reason" ;;
esac
exit 0
