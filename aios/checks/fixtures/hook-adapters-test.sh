#!/usr/bin/env bash
# Proves the hook adapters: payload parsing, the block verdict, and that the
# audit log records names and never content.
set -uo pipefail
H=$(cd "$(dirname "$0")/../../conf/hooks" && pwd)
ROOT=$(mktemp -d)
export AIOS_ROOT="$ROOT" AIOS_DATA="$ROOT/data" AIOS_SECRETS="$ROOT/secrets"
export AIOS_AUDIT="$ROOT/data/ops/audit/tool-calls.jsonl"
mkdir -p "$ROOT"/data/{goals,review,ops,untrusted-external/p,utility} "$ROOT"/conf "$ROOT"/secrets

pass=0; fail=0
run() { # run <expect 0|2> <desc> <hook> <payload>
  local want="$1" desc="$2" hook="$3" payload="$4" out rc
  out=$(printf '%s' "$payload" | bash "$H/$hook" 2>&1); rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass+1)); printf '  ok    exit %s  %s\n' "$rc" "$desc"
  else fail=$((fail+1)); printf '  FAIL  wanted %s got %s: %s [%s]\n' "$want" "$rc" "$desc" "$out"; fi
}

echo "halt-gate"
export AIOS_HALT="$ROOT/data/ops/.halt"
run 0 "no flag, session starts" halt-gate.sh '{}'
echo "investigating odd review output" > "$AIOS_HALT"
run 2 "flag set, session refused" halt-gate.sh '{}'
printf '%s' "$(printf '%s' '{}' | bash "$H/halt-gate.sh" 2>&1)" | grep -q "investigating odd review" \
  && { pass=$((pass+1)); echo "  ok    the refusal quotes the reason from the flag file"; } \
  || { fail=$((fail+1)); echo "  FAIL  refusal did not quote the reason"; }
rm -f "$AIOS_HALT"

echo "write-guard, via payload"
export AIOS_TAINT="$ROOT/t1"
run 0 "Write inside the data mount" write-guard.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$AIOS_DATA/review/x.md\"}}"
run 2 "Write escaping via .." write-guard.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$AIOS_DATA/../conf/settings.json\"}}"
run 0 "a tool call with no path is not our business" write-guard.sh \
  '{"tool_name":"Glob","tool_input":{"pattern":"**/*.md"}}'
export AIOS_TAINT="$ROOT/t2"
run 0 "Read of quarantined content is allowed" write-guard.sh \
  "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$AIOS_DATA/untrusted-external/p/raw\"}}"
run 2 "and the same session is then refused a review write" write-guard.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$AIOS_DATA/review/x.md\"}}"

echo "danger-guard, via payload"
run 0 "an ordinary command" danger-guard.sh '{"tool_name":"Bash","tool_input":{"command":"ls -la /data"}}'
run 2 "rm -rf"               danger-guard.sh '{"tool_name":"Bash","tool_input":{"command":"rm -rf /data/review"}}'
run 2 "docker"               danger-guard.sh '{"tool_name":"Bash","tool_input":{"command":"docker ps -a"}}'

echo "tool-audit"
printf '%s' "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$AIOS_DATA/goals/health.md\"}}" | bash "$H/tool-audit.sh"
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"grep -r mortgage /data/daily/check-ins.jsonl"}}' | bash "$H/tool-audit.sh"
if [ -s "$AIOS_AUDIT" ]; then pass=$((pass+1)); echo "  ok    the audit log was written"
else fail=$((fail+1)); echo "  FAIL  nothing was logged"; fi
if grep -q '"tool":"Read"' "$AIOS_AUDIT"; then pass=$((pass+1)); echo "  ok    it records the tool name"
else fail=$((fail+1)); echo "  FAIL  no tool name recorded"; fi
if grep -q 'mortgage' "$AIOS_AUDIT"; then
  fail=$((fail+1)); echo "  FAIL  THE AUDIT LOG CAPTURED COMMAND CONTENT"
else pass=$((pass+1)); echo "  ok    it records the command NAME and not its arguments"; fi
if [ "$(grep -c . "$AIOS_AUDIT")" = 2 ]; then pass=$((pass+1)); echo "  ok    one line per tool call"
else fail=$((fail+1)); echo "  FAIL  wrong line count"; fi

echo
printf 'hook adapters: %d passed, %d failed\n' "$pass" "$fail"
rm -rf "$ROOT"
[ "$fail" -eq 0 ]
