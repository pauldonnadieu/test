#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
# HOST.1-3 probe from OUTSIDE. A box cannot honestly test its own firewall:
# connect to your own public IP from the box and the packet never leaves, so
# you get a pass that proves nothing. Hairpin routing is the single easiest way
# to end up with a green suite on an exposed server. Point the probe at another
# machine, never at this one, and never at a tailnet device.
for p in 22 80 443; do
  id="HOST.$(( p == 22 ? 1 : p == 80 ? 2 : 3 ))"
  if [ -z "${AIOS_EXT_PROBE:-}" ]; then
    skip "$id" "port $p refused from outside" "AIOS_EXT_PROBE unset: nobody has proven this port is shut"
  else
    HOST="${AIOS_PUBLIC_IP:-}" PORT="$p" check "$id" "port $p refused from outside" <<B
out=\$(HOST="${AIOS_PUBLIC_IP:-}" PORT="$p" bash -c "\$AIOS_EXT_PROBE" 2>&1)
printf '%s' "\$out" | grep -qi 'refused\|filtered\|timed out\|closed' || { echo "port $p answered: \$out"; exit 1; }
B
  fi
done

check HOST.4 "nothing is listening on a wildcard address" <<B
hits=\$(ss -tlnH 2>/dev/null | awk '{print \$4}' | grep -E '^(0\.0\.0\.0|\*|\[::\]):' || true)
[ -z "\$hits" ] || { echo "wildcard listeners: \$hits"; exit 1; }
B
check HOST.5 "sshd accepts neither passwords nor root" <<B
c=\$(sshd -T 2>/dev/null)
printf '%s' "\$c" | grep -qi '^passwordauthentication no' || { echo "password auth is on"; exit 1; }
printf '%s' "\$c" | grep -qiE '^permitrootlogin (no|prohibit-password)' || { echo "root login permitted"; exit 1; }
B
check HOST.6 "the host firewall defaults to deny incoming" <<B
ufw status verbose 2>/dev/null | grep -qi 'deny (incoming)' || { echo "ufw is not default-deny"; exit 1; }
B
check HOST.7 "unattended upgrades are enabled" <<B
grep -rqs 'Unattended-Upgrade::.*"1"\|APT::Periodic::Unattended-Upgrade "1"' /etc/apt/apt.conf.d/ || { echo "unattended-upgrades off"; exit 1; }
B
check HOST.8 "Tailscale is connected" <<B
tailscale status >/dev/null 2>&1 || { echo "tailscale not connected"; exit 1; }
B
check HOST.9 "the Tailscale node key is not expiring within a fortnight" <<B
exp=\$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["Self"].get("KeyExpiry",""))' 2>/dev/null)
[ -z "\$exp" ] && exit 0
cutoff=\$(date -d '+14 days' -Is 2>/dev/null)
[ "\$exp" \> "\$cutoff" ] || { echo "node key expires \$exp"; exit 1; }
B
check HOST.10 "the host timezone is the user's, not UTC" <<B
want="\${AIOS_TZ:-}"
[ -n "\$want" ] || { echo "AIOS_TZ is not set in config.env"; exit 1; }
have=\$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
[ "\$have" = "\$want" ] || { echo "timezone is \$have, expected \$want; every schedule here is local time"; exit 1; }
B
check DSK.1 "free disk is above 20% and above 2 GB" <<B
R="\${AIOS_ROOT:-/srv/aios}"
pct=\$(df --output=pcent "\$R" 2>/dev/null | tail -1 | tr -dc '0-9')
avail=\$(df --output=avail -BM "\$R" 2>/dev/null | tail -1 | tr -dc '0-9')
[ "\${pct:-100}" -le 80 ] || { echo "disk \${pct}% used"; exit 1; }
[ "\${avail:-0}" -ge 2048 ] || { echo "only \${avail}MB free"; exit 1; }
B
check DSK.2 "docker logging is capped" <<B
m=\$(docker inspect aios --format '{{.HostConfig.LogConfig.Config}}' 2>/dev/null)
printf '%s' "\$m" | grep -q 'max-size' || { echo "no max-size on the container log driver"; exit 1; }
B
