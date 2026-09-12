#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Sunday, after the review. The audit gives the research a target.
run_routine audit docker exec -u aios aios claude -p \
  "Run the audit skill, then the research-scan skill. Write findings to ops/audit/ and the ledger." \
  --model sonnet --output-format json --permission-prompts none \
  --allowedTools "Read,Write,Edit,Glob,Grep"
