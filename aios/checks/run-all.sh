#!/usr/bin/env bash
# AIOS check runner.
#
#   ./run-all.sh                 every stage. Health score gates.
#   ./run-all.sh stage-04-data   one stage
#   ./run-all.sh --signals       user-behaviour signals, reported, never gating
#   ./run-all.sh --json          machine readable, for ops/check-scores.jsonl
#   ./run-all.sh --self-test     proves the runner scores correctly. Run first.
#
# Three rules the runner enforces so nobody has to remember them:
#   a SKIP scores as a failure
#   a check that crashes before emitting scores as a failure
#   a check that has vanished from the suite scores as a failure

set -uo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export AIOS_CHECKS="$HERE"

# Export config.env rather than merely sourcing it. Without `set -a` the
# variables are not in the environment of the check subprocesses, every check
# reports SKIP, and the suite can never go green on any machine. A cold reader
# found this the hard way in an earlier version; the comment stays.
if [ -f "$HERE/config.env" ]; then
  set -a; . "$HERE/config.env"; set +a
fi

MODE=health; JSON=0; FILTER=""; SELFTEST=0; SELFASSERT=0
for arg in "$@"; do
  case "$arg" in
    --signals)   MODE=signal ;;
    --json)      JSON=1 ;;
    --self-test) SELFTEST=1; SELFASSERT=1 ;;
    --self-test-raw) SELFTEST=1 ;;
    --all)       MODE=all ;;
    stage-*)     FILTER="$arg" ;;
    *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done


# --self-test: run the fixture suite and assert the runner scored it correctly.
# A runner nobody has checked is the one thing in this harness that cannot be
# caught by anything else, because every other result depends on it.
if [ "$SELFASSERT" = 1 ]; then
  obs=$("$0" --self-test-raw --json)
  want='"pass":1,"fail":1,"skip":1,"missing":2'
  rc=0
  if printf '%s' "$obs" | grep -qF "$want"; then
    echo "[PASS   ] runner scores pass, fail, skip-as-failure, crash and deletion correctly"
  else
    echo "[FAIL   ] runner mis-scored the fixtures"; echo "  expected to contain: $want"; echo "  got: $obs"; rc=1
  fi
  if printf '%s' "$obs" | grep -qF '"signals":"0/1"'; then
    echo "[PASS   ] a failing signal is counted separately and does not gate health"
  else
    echo "[FAIL   ] signal separation is wrong"; echo "  got: $obs"; rc=1
  fi
  empty=$("$0" stage-does-not-exist 2>/dev/null); erc=$?
  if [ "$erc" -ne 0 ]; then
    echo "[PASS   ] an empty run exits non-zero rather than reading as a perfect score"
  else
    echo "[FAIL   ] an empty run exited 0"; rc=1
  fi
  echo
  [ "$rc" -eq 0 ] && echo "SELF-TEST OK. The runner can be trusted to score the real suite." \
                  || echo "SELF-TEST FAILED. Do not trust any score this runner prints."
  exit "$rc"
fi

MANIFEST="$HERE/expected-ids.txt"
[ "$SELFTEST" = 1 ] && { HERE="$HERE/fixtures/selftest"; MANIFEST="$HERE/expected-ids.txt"; }

if [ ! -f "$MANIFEST" ]; then
  printf 'ERROR: no manifest at %s\n' "$MANIFEST" >&2
  printf 'The manifest is what makes a deleted check visible. Without it the\n' >&2
  printf 'suite cannot be trusted, so it refuses to report a score.\n' >&2
  exit 2
fi

# class_of <id> : health | signal | unknown
class_of() { awk -F'\t' -v id="$1" '$1==id {print $3; found=1} END{if(!found) print "unknown"}' "$MANIFEST"; }
stage_of() { awk -F'\t' -v id="$1" '$1==id {print $2}' "$MANIFEST"; }

RESULTS=$(mktemp); trap 'rm -f "$RESULTS"' EXIT

for dir in "$HERE"/stage-*/; do
  [ -d "$dir" ] || continue
  stage=$(basename "$dir")
  [ -n "$FILTER" ] && [ "$stage" != "$FILTER" ] && continue
  for script in "$dir"*.sh; do
    [ -f "$script" ] || continue
    # A check script that dies mid-way emits fewer IDs than the manifest lists
    # for its stage. The manifest pass below turns that into MISSING, which is
    # why a crash cannot quietly shrink the denominator.
    bash "$script" 2>/dev/null >>"$RESULTS"
  done
done

# Manifest pass: every ID the manifest expects for the stages we ran must have
# been emitted. Deleting the check that fails is the cheapest way to make a
# change look safe, and this is what stops it.
while IFS=$'\t' read -r id stage class; do
  [ -z "${id:-}" ] && continue
  case "$id" in \#*) continue ;; esac
  [ -n "$FILTER" ] && [ "$stage" != "$FILTER" ] && continue
  if ! cut -f2 "$RESULTS" | grep -qxF "$id"; then
    printf 'MISSING\t%s\t%s\tno result emitted: check deleted, renamed or crashed\n' \
      "$id" "expected in $stage" >>"$RESULTS"
  fi
done < "$MANIFEST"

pass=0; fail=0; skip=0; missing=0; sig_pass=0; sig_total=0
FAILED=""; PASSING=""; SEEN=""
while IFS=$'\t' read -r verdict id desc detail; do
  [ -z "${verdict:-}" ] && continue
  cls=$(class_of "$id")
  if [ "$cls" = signal ]; then
    sig_total=$((sig_total+1)); [ "$verdict" = PASS ] && sig_pass=$((sig_pass+1))
    [ "$MODE" = health ] && continue
  else
    [ "$MODE" = signal ] && continue
  fi
  SEEN="$SEEN $id"
  case "$verdict" in
    PASS)    pass=$((pass+1)); PASSING="$PASSING $id" ;;
    FAIL)    fail=$((fail+1));    FAILED="$FAILED $id" ;;
    SKIP)    skip=$((skip+1));    FAILED="$FAILED $id" ;;
    MISSING) missing=$((missing+1)); FAILED="$FAILED $id" ;;
  esac
  [ "$JSON" = 1 ] || printf '[%-7s] %-12s %s%s\n' "$verdict" "$id" "$desc" \
    "$([ -n "${detail:-}" ] && printf '\n            %s' "$detail")"
done < "$RESULTS"

total=$((pass+fail+skip+missing))

if [ "$JSON" = 1 ]; then
  printf '{"ts":"%s","mode":"%s","pass":%d,"fail":%d,"skip":%d,"missing":%d,"total":%d,"failed":"%s","passing":"%s","seen":"%s","signals":"%d/%d"}\n' \
    "$(date -Is)" "$MODE" "$pass" "$fail" "$skip" "$missing" "$total" \
    "$(printf '%s' "$FAILED" | sed 's/^ //')" \
    "$(printf '%s' "$PASSING" | sed 's/^ //')" \
    "$(printf '%s' "$SEEN" | sed 's/^ //')" "$sig_pass" "$sig_total"
else
  echo
  if [ "$MODE" = signal ]; then
    printf 'SIGNALS %d/%d  (reported, never gating)\n' "$pass" "$total"
  else
    printf 'HEALTH %d/%d   skip:%d missing:%d\n' "$pass" "$total" "$skip" "$missing"
    [ "$sig_total" -gt 0 ] && printf 'signals %d/%d  (run --signals for detail; these never gate)\n' "$sig_pass" "$sig_total"
  fi
  [ -n "$FAILED" ] && printf 'NOT PASSING:%s\n' "$FAILED"
fi

# An empty run is not a green run. Zero checks means the suite did not execute,
# which is a failure and not a perfect score.
[ "$total" -eq 0 ] && { [ "$JSON" = 1 ] || echo "ERROR: no checks ran"; exit 1; }
# Signals never gate.
[ "$MODE" = signal ] && exit 0
[ $((fail+skip+missing)) -eq 0 ]
