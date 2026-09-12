#!/usr/bin/env bash
# PostToolUse on every tool. Names and verdicts, never payloads.
# This is the log you read first when something looks wrong, and it is the
# per-tool-call trail that a design without hooks cannot have.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); . "$HERE/_payload.sh"
AIOS_ROOT="${AIOS_ROOT:-/srv/aios}"
LOG="${AIOS_AUDIT:-$AIOS_ROOT/data/ops/audit/tool-calls.jsonl}"
mkdir -p "$(dirname "$LOG")" 2>/dev/null || exit 0
read_payload
# The target is a path or a command NAME. Never arguments, never file contents:
# this log lives inside the backup and must not become a transcript archive.
target="${HOOK_PATH:-}"
[ -z "$target" ] && [ -n "${HOOK_CMD:-}" ] && target=$(printf '%s' "$HOOK_CMD" | awk '{print $1}')
printf '{"ts":"%s","session":"%s","lane":"%s","tool":"%s","target":"%s"}\n' \
  "$(date -Is)" "${AIOS_SESSION:-unknown}" "${AIOS_LANE:-main}" "${HOOK_TOOL:-unknown}" \
  "$(printf '%s' "$target" | tr -d '"\\' | cut -c1-200)" >> "$LOG" 2>/dev/null
exit 0
