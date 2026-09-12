#!/usr/bin/env bash
# PreToolUse on Bash. Belt to the deny rules' braces: it sees the resolved
# argument string, so it catches shapes a name pattern misses.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/_payload.sh"; . "$HERE/guard-lib.sh"
read_payload
[ -n "${HOOK_CMD:-}" ] || exit 0
reason=$(guard_bash "$HOOK_CMD") || deny "$reason"
exit 0
