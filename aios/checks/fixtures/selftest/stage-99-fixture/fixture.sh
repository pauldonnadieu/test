#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
check SELF.1 "a check that should pass" <<'B'
true
B
check SELF.2 "a check that should fail" <<'B'
echo "the value was 7, expected 3"; false
B
skip SELF.3 "a check that cannot run here" "no vantage point"
check SELF.6 "a failing SIGNAL, which must not gate health" <<'B'
false
B
