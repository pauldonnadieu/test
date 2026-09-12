#!/usr/bin/env bash
# Proves the hook decision logic, both ways. A guard that has only ever been
# seen to allow proves nothing, and a guard that refuses everything is equally
# broken, so every case below asserts a specific expected verdict.
set -uo pipefail
ROOT=$(mktemp -d); export AIOS_ROOT="$ROOT" AIOS_DATA="$ROOT/data"
export AIOS_SECRETS="$ROOT/secrets"
mkdir -p "$ROOT"/data/{goals,review,reference,ops/proposals,untrusted-external/2026-09-01-page,utility} "$ROOT"/conf "$ROOT"/secrets
. "$(dirname "$0")/../../conf/hooks/guard-lib.sh"

pass=0; fail=0
want() { # want <allow|deny> <description> ; command via "$@" from index 3
  local expect="$1" desc="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  local got=allow; [ "$rc" -ne 0 ] && got=deny
  if [ "$got" = "$expect" ]; then pass=$((pass+1)); printf '  ok    %-6s %s\n' "$expect" "$desc"
  else fail=$((fail+1)); printf '  FAIL  wanted %s got %s: %s  [%s]\n' "$expect" "$got" "$desc" "$out"; fi
}

echo "write-guard: the data mount boundary"
export AIOS_TAINT="$ROOT/taint-a"
want allow "ordinary write inside the data mount"      guard_write "$AIOS_DATA/review/2026-W37.md"
want deny  "write to the config directory"             guard_write "$ROOT/conf/settings.json"
want deny  "escape via .. from inside the data mount"  guard_write "$AIOS_DATA/../conf/settings.json"
want deny  "escape via a deeper .. chain"              guard_write "$AIOS_DATA/goals/../../conf/hooks/write-guard.sh"
want deny  "write to the secrets path"                 guard_write "$ROOT/secrets/restic-password"
want deny  "absolute path outside everything"          guard_write "/etc/passwd"

echo "write-guard: the quarantine taint rule"
export AIOS_TAINT="$ROOT/taint-b"
want allow "clean session may write goals/"            guard_write "$AIOS_DATA/goals/health.md"
want allow "reading a quarantined file is permitted"   guard_read  "$AIOS_DATA/untrusted-external/2026-09-01-page/raw"
want deny  "tainted session may NOT write review/"     guard_write "$AIOS_DATA/review/2026-W37.md"
want deny  "tainted session may NOT write goals/"      guard_write "$AIOS_DATA/goals/health.md"
want deny  "tainted session may NOT write a proposal"  guard_write "$AIOS_DATA/ops/proposals/x.md"
want allow "tainted session MAY still write quarantine" guard_write "$AIOS_DATA/untrusted-external/2026-09-01-page/summary.md"

echo "write-guard: the taint marker is per session"
export AIOS_TAINT="$ROOT/taint-c"   # a new session, new marker
want allow "a NEW session may write review/ again"     guard_write "$AIOS_DATA/review/2026-W38.md"

echo "write-guard: the utility lane"
export AIOS_TAINT="$ROOT/taint-d" AIOS_LANE=utility
want allow "utility lane may write utility/"           guard_write "$AIOS_DATA/utility/shopping.md"
want deny  "utility lane may NOT write goals/"         guard_write "$AIOS_DATA/goals/health.md"
want deny  "utility lane may NOT write review/"        guard_write "$AIOS_DATA/review/2026-W37.md"
want deny  "utility lane may NOT read daily/"          guard_read  "$AIOS_DATA/daily/check-ins.jsonl"
want deny  "utility lane may NOT read goals/"          guard_read  "$AIOS_DATA/goals/health.md"
want allow "utility lane may read utility/"            guard_read  "$AIOS_DATA/utility/todo.md"
unset AIOS_LANE

echo "danger-guard"
want allow "an ordinary command"                       guard_bash "grep -r pattern /data/goals"
want deny  "rm -rf"                                    guard_bash "rm -rf /data/review"
want deny  "rm -rf inside a subshell"                  guard_bash "cd /tmp && (rm -rf /data)"
want deny  "restic forget"                             guard_bash "restic forget --keep-daily 7"
want deny  "restic prune"                              guard_bash "restic prune"
want deny  "docker"                                    guard_bash "docker ps"
want deny  "crontab"                                   guard_bash "crontab -l"
want deny  "chmod on conf"                             guard_bash "chmod 666 /srv/aios/conf/settings.json"
want deny  "a command naming the secrets path"         guard_bash "cat $AIOS_SECRETS/rclone.conf"
want allow "chmod on an ordinary data file"            guard_bash "chmod 644 /tmp/notes.md"

echo
printf 'hook logic: %d passed, %d failed\n' "$pass" "$fail"
rm -rf "$ROOT"
[ "$fail" -eq 0 ]
