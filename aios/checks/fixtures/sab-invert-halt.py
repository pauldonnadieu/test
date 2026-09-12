# Sabotage: move the halt check AFTER the lock in lib-routine.sh.
# A halt check after the lock is a halt check that does not halt the run you
# are trying to stop, and it looks completely normal in a diff.
import sys
p = sys.argv[1]
s = open(p).read()
call = "  halt_check || { printf '%s halted, nothing run\\n' \"$name\"; return 0; }\n"
lock = ('  local lock="$AIOS_DATA/ops/.lock-$name"\n'
        '  exec 9>"$lock" || return 1\n'
        "  flock -n 9 || { printf '%s already running\\n' \"$name\"; return 0; }\n")
assert call in s, "halt call anchor not found"
assert lock in s, "lock anchor not found"
open(p, "w").write(s.replace(call, "").replace(lock, lock + call))
