#!/usr/bin/env bash
# Probes a port from somewhere that is NOT this machine.
#
# A box cannot honestly test its own firewall. Connect to your own public IP
# from the box and the packet never leaves: you get a pass that proves nothing,
# and that is the single easiest way to end up with a green suite on an exposed
# server. A tailnet device is not a valid vantage point either, because traffic
# from it may take the tailnet path.
#
# Usage: probe-from-outside.sh <host> <port>
# Mode comes from AIOS_PROBE_MODE: ssh | hetzner | phone | thirdparty
set -uo pipefail
host="${1:?host}"; port="${2:?port}"
mode="${AIOS_PROBE_MODE:-}"

case "$mode" in
  ssh)
    # Best answer. Costs nothing and the vantage point is genuinely elsewhere.
    target="${AIOS_PROBE_SSH:?set AIOS_PROBE_SSH=user@other-box}"
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" \
      "timeout 8 bash -c '</dev/tcp/$host/$port' 2>&1 || echo refused" ;;
  hetzner)
    # A second VPS, destroyed after. About a cent an hour.
    target="${AIOS_PROBE_SSH:?set AIOS_PROBE_SSH for the throwaway box}"
    ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" \
      "timeout 8 bash -c '</dev/tcp/$host/$port' 2>&1 || echo refused" ;;
  phone)
    echo "MANUAL: from your phone on mobile data with wifi OFF, try to reach $host:$port." >&2
    echo "Record the result as an attestation. This mode cannot answer automatically." >&2
    exit 1 ;;
  thirdparty)
    # You disclose your server's IP and which ports you care about to a stranger.
    # Stated so the choice is deliberate rather than accidental.
    echo "MANUAL: use an online port checker for $host:$port, having accepted the disclosure." >&2
    exit 1 ;;
  *)
    echo "AIOS_PROBE_MODE is not set to ssh, hetzner, phone or thirdparty" >&2
    exit 1 ;;
esac
