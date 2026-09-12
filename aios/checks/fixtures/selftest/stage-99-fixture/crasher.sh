#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
# Dies before emitting anything. SELF.4 is in the manifest, so the runner must
# report it MISSING rather than silently shrinking the denominator.
exit 3
check SELF.4 "never reached" <<'B'
true
B
