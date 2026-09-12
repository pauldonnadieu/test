#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Evening, daily. The foundation: everything the weekly review knows, it knows
# from here. Thirty seconds or it stops happening.
run_routine check-in docker exec -u aios aios claude -p \
  "Run the check-in skill. Ask the four questions, record one JSONL line, and stop. Do not analyse." \
  --model sonnet --output-format json --permission-prompts none \
  --allowedTools "Read,Write,Edit,Glob,Grep"
