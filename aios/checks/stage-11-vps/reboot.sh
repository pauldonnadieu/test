#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
CN="${AIOS_CONTAINER:-aios}"
# Reboot persistence. The classic silent failure: a firewall rule added but
# never persisted, a container with no restart policy, a Tailscale key that
# quietly expired, a cron daemon running only because someone started it by
# hand. The box looks perfect until it reboots, and it reboots on a day nobody
# is watching. NOTHING here may require a human to log in and fix it.
check RB0.1 "the firewall is active after a reboot" <<B
ufw status 2>/dev/null | grep -qi '^Status: active' || { echo "ufw is not active"; exit 1; }
B
check RB0.2 "Tailscale reconnected on its own" <<B
tailscale status >/dev/null 2>&1 || { echo "tailscale did not reconnect"; exit 1; }
B
check RB0.3 "the container is running with a restart policy" <<B
p=\$(docker inspect "$CN" --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
case "\$p" in always|unless-stopped) ;; *) echo "restart policy is '\$p'"; exit 1 ;; esac
docker inspect "$CN" --format '{{.State.Running}}' 2>/dev/null | grep -q true || { echo "not running"; exit 1; }
B
check RB0.4 "cron is alive and holds its entries" <<B
pgrep -x cron >/dev/null 2>&1 || pgrep -x crond >/dev/null 2>&1 || { echo "no cron daemon"; exit 1; }
[ "\$(crontab -l 2>/dev/null | grep -c aios)" -ge 1 ] || { echo "no aios crontab entries"; exit 1; }
B
check RB0.5 "the timezone survived the reboot" <<B
have=\$(timedatectl show -p Timezone --value 2>/dev/null)
[ "\$have" = "\${AIOS_TZ:-}" ] || { echo "timezone is \$have, expected \${AIOS_TZ:-unset}"; exit 1; }
B
check CRON.1 "cron genuinely fires" <<B
# RUN.1-3 check that a record is FRESH, which stays green for 36 hours after
# cron dies. This is evidence instead.
M="${AIOS_DATA:-/srv/aios/data}/ops/.cron-canary"
[ -f "\$M" ] || { echo "no canary; add a minutely canary entry, wait, and re-run"; exit 1; }
age=\$(( ( \$(date +%s) - \$(stat -c %Y "\$M") ) / 60 ))
[ "\$age" -le 10 ] || { echo "the canary last fired \${age} minutes ago"; exit 1; }
B
check CRON.2 "scripts set PATH or use absolute paths" <<B
# The most common scheduling bug there is: cron runs with a minimal PATH and no
# login shell, so a script that works by hand fails at 3am with docker: not found.
bad=""
for f in "${AIOS_BIN:-/srv/aios/bin}"/*.sh; do
  [ -f "\$f" ] || continue
  grep -q '^PATH=' "\$f" || grep -q '/usr/bin/\|/usr/local/bin/' "\$f" || bad="\$bad \$(basename \$f)"
done
[ -z "\$bad" ] || { echo "no PATH and no absolute paths in:\$bad"; exit 1; }
B
check CRON.3 "cron output goes somewhere readable" <<B
# cron mails output by default, and on a box with no mail transport that means
# it is discarded. A routine that fails at 3am into nothing is a routine that
# failed silently.
out=\$(crontab -l 2>/dev/null)
[ -n "\$out" ] || { echo "no crontab"; exit 1; }
bad=""
while IFS= read -r line; do
  case "\$line" in ''|'#'*|'PATH='*|'SHELL='*|'MAILTO='*) continue ;; esac
  printf '%s' "\$line" | grep -q '>>\|> ' || bad="\$bad [\$line]"
done <<< "\$out"
[ -z "\$bad" ] || { echo "entries with no output redirection:\$bad"; exit 1; }
B

check RC.1 "Remote Control runs inside the container, never on the host" <<B
pgrep -af 'claude.*remote' 2>/dev/null | grep -qv docker && { echo "a remote-control process is running on the HOST; a compromised account would reach the host, not just the container"; exit 1; }
docker exec "${AIOS_CONTAINER:-aios}" pgrep -af 'claude' >/dev/null 2>&1 || { echo "no claude process inside the container"; exit 1; }
B
skip RC.5 "the Anthropic account has a hardware-backed second factor" "account-side; permanently a stage 0 attestation"
skip RC.6 "the data-training setting is off" "account-side; permanently a stage 0 attestation"
skip GD.1 "the Google Drive backend is reachable with its own second factor" "account-side; permanently a stage 0 attestation"
