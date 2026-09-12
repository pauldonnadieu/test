#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Sunday evening. The output the whole system exists to produce.
run_routine weekly-review docker exec -u aios aios claude -p \
  "Run the weekly-review skill against this week's check-ins, goals and the previous review." \
  --model sonnet --output-format json --permission-prompts none \
  --allowedTools "Read,Write,Edit,Glob,Grep"
