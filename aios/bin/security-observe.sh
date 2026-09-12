#!/usr/bin/env bash
set -uo pipefail
AIOS_ROOT=/srv/aios
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
. "$AIOS_ROOT/bin/lib-routine.sh"
# Nightly. No model. Deterministic diff against yesterday.
#
# The distinction from the weekly health check is the whole point: the harness
# proves a CONFIGURATION is correct on Sunday. This notices a BEHAVIOUR change
# on Wednesday. A new listening socket, a new account, or a tenfold jump in
# outbound traffic look like nothing in a config check and like everything here.
OBS="$AIOS_DATA/ops/security/observations.jsonl"
ALERTS="$AIOS_DATA/ops/security/alerts.md"
observe() {
  mkdir -p "$(dirname "$OBS")"
  local listening users keys out
  listening=$(ss -tlnH 2>/dev/null | awk '{print $4}' | sort -u | tr '\n' ',' )
  users=$(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}' | sort | tr '\n' ',')
  keys=$(sha256sum ~/.ssh/authorized_keys 2>/dev/null | cut -d' ' -f1)
  out=$(cat /sys/class/net/*/statistics/tx_bytes 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo 0)
  printf '{"ts":"%s","listening":"%s","users":"%s","authorized_keys":"%s","outbound_bytes":%s}\n' \
    "$(date -Is)" "$listening" "$users" "${keys:-none}" "${out:-0}" >> "$OBS"

  # Diff against the previous observation. Changes are alerts, not log lines.
  local prev cur
  prev=$(tail -2 "$OBS" | head -1); cur=$(tail -1 "$OBS")
  [ "$prev" = "$cur" ] && return 0
  for field in listening users authorized_keys; do
    local a b
    a=$(printf '%s' "$prev" | sed -n "s/.*\"$field\":\"\([^\"]*\)\".*/\1/p")
    b=$(printf '%s' "$cur"  | sed -n "s/.*\"$field\":\"\([^\"]*\)\".*/\1/p")
    [ "$a" != "$b" ] && printf -- '- [ ] %s  %s changed\n      was: %s\n      now: %s\n' \
      "$(date -Is)" "$field" "$a" "$b" >> "$ALERTS"
  done
  # Outbound volume: an order of magnitude above yesterday is worth a look.
  # This is the only thing in the whole design that would notice exfiltration,
  # whether from a runaway fetcher or a session someone else is driving.
  local pa pb
  pa=$(printf '%s' "$prev" | sed -n 's/.*"outbound_bytes":\([0-9]*\).*/\1/p')
  pb=$(printf '%s' "$cur"  | sed -n 's/.*"outbound_bytes":\([0-9]*\).*/\1/p')
  if [ -n "$pa" ] && [ -n "$pb" ] && [ "$pa" -gt 0 ] 2>/dev/null; then
    [ "$pb" -gt $((pa * 10)) ] 2>/dev/null && \
      printf -- '- [ ] %s  outbound bytes jumped from %s to %s\n' "$(date -Is)" "$pa" "$pb" >> "$ALERTS"
  fi
  return 0
}
run_routine security-observe bash -c "$(declare -f observe); OBS=$OBS ALERTS=$ALERTS AIOS_DATA=$AIOS_DATA observe"
