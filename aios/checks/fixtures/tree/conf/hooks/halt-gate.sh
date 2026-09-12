#!/usr/bin/env bash
# SessionStart. Layer 1 of the kill switch.
# While the flag exists, nothing starts. Removing the file resumes everything.
set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd); . "$HERE/_payload.sh"
AIOS_ROOT="${AIOS_ROOT:-/srv/aios}"
FLAG="${AIOS_HALT:-$AIOS_ROOT/data/ops/.halt}"
if [ -e "$FLAG" ]; then
  reason=$(head -c 400 "$FLAG" 2>/dev/null)
  deny "halted$([ -n "$reason" ] && printf ': %s' "$reason"). Remove $FLAG to resume."
fi
exit 0
