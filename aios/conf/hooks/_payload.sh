#!/usr/bin/env bash
# Payload adapter. The one part of the hook layer that depends on the CLI's
# current contract rather than on shell semantics, so it is isolated here and
# kept small. DRIFT.3 checks it still matches the installed Claude Code.
#
# Reads the hook payload from stdin and exports:
#   HOOK_TOOL   the tool name
#   HOOK_PATH   the file path argument, when there is one
#   HOOK_CMD    the command string, when there is one
# Unknown or unparseable payload leaves these empty, and every guard fails
# closed on empty input rather than allowing.
read_payload() {
  local raw; raw=$(cat)
  if command -v jq >/dev/null 2>&1; then
    HOOK_TOOL=$(printf '%s' "$raw" | jq -r '.tool_name // .tool // empty' 2>/dev/null)
    HOOK_PATH=$(printf '%s' "$raw" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
    HOOK_CMD=$( printf '%s' "$raw" | jq -r '.tool_input.command // empty' 2>/dev/null)
  else
    HOOK_TOOL=$(printf '%s' "$raw" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    HOOK_PATH=$(printf '%s' "$raw" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    HOOK_CMD=$( printf '%s' "$raw" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  fi
  export HOOK_TOOL HOOK_PATH HOOK_CMD
}
# deny <reason> : refuse the tool call. Exit status 2 with the reason on stderr
# is the blocking convention; verify against the installed CLI at build time.
deny() { printf 'AIOS hook refused: %s\n' "$1" >&2; exit 2; }
