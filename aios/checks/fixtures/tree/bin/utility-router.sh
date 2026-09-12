#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# The free-tier lane. Low-stakes utility work on someone else's allowance, so
# the Pro subscription is spent on the work that needs judgement.
#
# THIS SCRIPT RUNS ON THE HOST, NOT IN THE CONTAINER, and that is the point:
# the container never holds the free-tier credential. A compromise of the
# container reaches the data mount and does not reach this key.
#
# The boundary is structural rather than a judgement about sensitivity.
# Sensitivity is a property of sentences, not files: a check-in mentioning the
# mortgage is financial, personal, and sits in daily/. Any rule that needs
# something to decide "is this sensitive" per request will eventually decide
# wrong, silently, into a provider that trains on it. So this lane can reach
# exactly two directories and nothing else exists to it.
#
# What it may touch:   utility/ (to-do, shopping, scratch)  untrusted-external/
# What it may not:     goals/ daily/ review/ reference/ ops/
#
# Honest note that belongs next to the code: a to-do list is still a portrait
# of a life over time, and free tiers train on what they receive. This lane is
# opt-in per item, not a default destination.
export AIOS_LANE=utility
KEY_FILE="${AIOS_FREE_KEY_FILE:-$AIOS_ROOT/secrets/free-tier-key}"
[ -r "$KEY_FILE" ] || { echo "no free-tier credential at $KEY_FILE" >&2; exit 1; }

prompt="${1:?usage: utility-router.sh <prompt>}"
case "$prompt" in
  *"$AIOS_DATA/goals"*|*"$AIOS_DATA/daily"*|*"$AIOS_DATA/review"*|*"$AIOS_DATA/reference"*|*"$AIOS_DATA/ops"*)
    echo "refused: the utility lane may not reference the coaching tree" >&2; exit 1 ;;
esac

# The provider call itself is deliberately a single, replaceable function.
# Free tiers change their terms, their models and their endpoints far faster
# than anything else in this design, so the blast radius of that churn is kept
# to these few lines. R2 names the current provider and how to verify it still
# has a free tier before relying on it.
call_free_tier() {
  local key; key=$(cat "$KEY_FILE")
  curl -sS --max-time 60 \
    -H "content-type: application/json" \
    -H "x-goog-api-key: $key" \
    -d "$(python3 -c 'import json,sys;print(json.dumps({"contents":[{"parts":[{"text":sys.argv[1]}]}]}))' "$1")" \
    "https://generativelanguage.googleapis.com/v1beta/models/${AIOS_FREE_MODEL:-gemini-flash-latest}:generateContent" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["candidates"][0]["content"]["parts"][0]["text"])' 2>/dev/null
}
run_routine utility bash -c "$(declare -f call_free_tier); KEY_FILE=$KEY_FILE call_free_tier \"\$1\"" _ "$prompt"
