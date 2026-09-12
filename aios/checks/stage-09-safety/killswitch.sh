#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
D="${AIOS_DATA:-${AIOS_ROOT:-/srv/aios}/data}"
B="${AIOS_BIN:-${AIOS_ROOT:-/srv/aios}/bin}"

check KS.1 "every routine consults the halt flag before it locks or works" <<B
# A routine satisfies this either by checking the flag inline, or by going
# through run_routine, which checks it first. Both are verified: the second
# only counts if lib-routine.sh really does halt BEFORE it locks, because a
# halt check after the lock is a halt check that does not halt the run you are
# trying to stop.
L="$B/lib-routine.sh"
[ -f "\$L" ] || { echo "no lib-routine.sh"; exit 1; }
lh=\$(grep -n 'halt_check' "\$L" | sed -n '2p' | cut -d: -f1)
ll=\$(grep -n 'flock' "\$L" | head -1 | cut -d: -f1)
[ -n "\$lh" ] && [ -n "\$ll" ] || { echo "lib-routine.sh has no halt check or no lock"; exit 1; }
[ "\$lh" -lt "\$ll" ] || { echo "lib-routine.sh checks the halt flag AFTER taking the lock"; exit 1; }
bad=""
for f in "$B"/*.sh; do
  [ -f "\$f" ] || continue
  case "\$(basename "\$f")" in lib-routine.sh) continue ;; esac
  grep -q 'claude -p\|restic\|run_routine' "\$f" || continue
  grep -q '\.halt\|run_routine' "\$f" || bad="\$bad \$(basename \$f):no-halt-path"
done
[ -z "\$bad" ] || { echo "\$bad"; exit 1; }
B

check KS.2 "a halted routine exits without doing work" <<B
T=\$(mktemp -d); mkdir -p "\$T/data/ops"
echo "probe" > "\$T/data/ops/.halt"
# AIOS_DATA must be unset as well as AIOS_ROOT, or the routine reads the real
# data mount and this check proves nothing about the temporary one.
out=\$(env -u AIOS_DATA AIOS_ROOT="\$T" bash "$B/lib-routine.sh" probe 2>&1); rc=\$?
rm -rf "\$T"
[ "\$rc" -eq 0 ] || { echo "a halted routine should exit cleanly, got \$rc: \$out"; exit 1; }
printf '%s' "\$out" | grep -qi halt || { echo "a halted routine left no trace: \$out"; exit 1; }
B

check KS.3 "the halt flag carries a reason" <<B
F="$D/ops/.halt"
[ -e "\$F" ] || exit 0
[ -s "\$F" ] || { echo "the halt flag is empty; write why it is set"; exit 1; }
B

check KS.4 "all four kill-switch layers are documented off the machine" <<B
A="$D/ops/attestations.md"
[ -f "\$A" ] || { echo "no attestations file"; exit 1; }
grep -qi 'kill switch' "\$A" || { echo "no attestation that the four layers are reachable from the phone"; exit 1; }
B

check KS.5 "the halt flag is honoured by the session hook, not only by cron" <<B
# Layer 1 must stop an INTERACTIVE session too. A halt that only stops the
# schedule leaves the widest path in, Remote Control, wide open.
C="${AIOS_CONF:-${AIOS_ROOT:-/srv/aios}/conf}"
grep -qF 'halt-gate.sh' "\$C/settings.json" 2>/dev/null || { echo "halt-gate is not registered at SessionStart"; exit 1; }
T=\$(mktemp -d); export AIOS_HALT="\$T/.halt"; echo "probe" > "\$AIOS_HALT"
printf '{}' | bash "\$C/hooks/halt-gate.sh" >/dev/null 2>&1
rc=\$?; rm -rf "\$T"
[ "\$rc" -ne 0 ] || { echo "the session hook allowed a session while halted"; exit 1; }
B
