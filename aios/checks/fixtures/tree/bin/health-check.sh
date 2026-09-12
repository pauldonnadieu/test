#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Weekly, forever. No model.
# These checks are not build scaffolding. Every property they test can silently
# stop being true months later, and the score is RECORDED rather than merely
# read, because the trend is the signal.
run_routine health-check bash -c \
  "$AIOS_ROOT/checks/run-all.sh --json >> $AIOS_DATA/ops/check-scores.jsonl"
