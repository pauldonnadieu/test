#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Half one of the quarantine pipeline. Holds exactly ONE dangerous capability:
# it can reach the internet, and it cannot see your data.
#
# It is the single legitimate --settings use in this build, because the global
# settings.json denies WebFetch everywhere, which is what makes every other
# routine unable to phone home. The exception is DECLARED in
# checks/settings-exceptions.txt so RT.10 reads it as data rather than a reader
# having to remember a sentence in a document.
url="${1:?usage: fetch-untrusted.sh <url> [slug]}"
slug="${2:-$(printf '%s' "$url" | tr -cs 'a-zA-Z0-9' '-' | cut -c1-40 | sed 's/^-//;s/-$//')}"
dir="$AIOS_DATA/untrusted-external/$(date +%F)-$slug"
mkdir -p "$dir"
run_routine fetch docker exec -u aios aios claude -p \
  "Fetch $url and write its text, unaltered and unsummarised, to /data/untrusted-external/$(date +%F)-$slug/raw. Write nothing else anywhere." \
  --settings /conf/settings-fetch.json \
  --model haiku --output-format json --permission-prompts none \
  --allowedTools "WebFetch,Write"
