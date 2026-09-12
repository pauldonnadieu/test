#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
CN="${AIOS_CONTAINER:-aios}"; CU="${AIOS_CONTAINER_USER:-aios}"
R="${AIOS_ROOT:-/srv/aios}"
# EVERY negative check here runs AS THE CONTAINER USER, via docker exec -u.
# A check run as root tests a world the agent does not live in, and would pass
# on a system where the agent can rewrite everything that binds it.
dex() { docker exec -u "$CU" "$CN" "$@" 2>&1; }

# GATE. Every negative check below asks "can the agent do X?" and treats a
# non-zero exit as proof that it cannot. If the docker daemon is absent or the
# container is not running, EVERY ONE OF THEM passes for the wrong reason, and
# the result is indistinguishable from a system with no boundary at all. So the
# stage refuses to report anything until it has proved it can reach the
# container. This is the single easiest way to get a green suite on an
# unprotected machine, and it is why the gate is here rather than assumed.
if ! docker exec -u "$CU" "$CN" true >/dev/null 2>&1; then
  for id in CTR.1 CTR.2 CTR.3 CTR.4 CTR.5 CTR.6 CTR.7 CTR.8 CTR.9 CTR.10 CTR.11 CTR.12 CTR.13 CTR.14; do
    skip "$id" "container boundary" "cannot reach container '$CN' as user '$CU'; a negative check that cannot run is not a pass"
  done
  exit 0
fi

check CTR.1 "the agent process is not uid 0" <<B
id=\$(docker exec -u "$CU" "$CN" id -u 2>&1) || { echo "\$id"; exit 1; }
[ "\$id" != "0" ] || { echo "container user is root"; exit 1; }
B
for n in 2:/conf/settings.json 3:/conf/CLAUDE.md 4:/conf/hooks/write-guard.sh; do
  id="CTR.${n%%:*}"; path="${n#*:}"
  check "$id" "the container user cannot write $path" <<B
out=\$(docker exec -u "$CU" "$CN" sh -c 'printf "" >> '"$path"' 2>&1')
rc=\$?
[ "\$rc" -ne 0 ] || { echo "the agent can write $path, so every rule binding it is decoration"; exit 1; }
B
done
check CTR.5 "the container user cannot read the secrets path" <<B
out=\$(docker exec -u "$CU" "$CN" sh -c 'cat /secrets/* 2>&1'); rc=\$?
[ "\$rc" -ne 0 ] || { echo "secrets are readable from inside the container"; exit 1; }
B
check CTR.6 "the secrets path is not mounted at all" <<B
docker inspect "$CN" --format '{{range .Mounts}}{{.Destination}} {{end}}' 2>/dev/null | grep -q secrets \
  && { echo "the secrets directory is mounted into the container"; exit 1; }
exit 0
B
check CTR.7 "no docker socket inside" <<B
docker exec -u "$CU" "$CN" test -S /var/run/docker.sock 2>/dev/null \
  && { echo "the docker socket is inside the container"; exit 1; }
exit 0
B
check CTR.8 "all capabilities dropped" <<B
c=\$(docker inspect "$CN" --format '{{.HostConfig.CapDrop}}' 2>/dev/null)
printf '%s' "\$c" | grep -qi 'all' || { echo "CapDrop is \$c"; exit 1; }
B
check CTR.9 "no-new-privileges is set" <<B
o=\$(docker inspect "$CN" --format '{{.HostConfig.SecurityOpt}}' 2>/dev/null)
printf '%s' "\$o" | grep -q 'no-new-privileges' || { echo "SecurityOpt is \$o"; exit 1; }
B
check CTR.10 "the data mount is a bind mount from the host" <<B
docker inspect "$CN" --format '{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}}{{"\n"}}{{end}}' 2>/dev/null \
  | grep -q "^bind:$R/data:" || { echo "data is not a host bind mount; the container is not disposable"; exit 1; }
B
check CTR.11 "the Claude Code credential lives on a persisted mount" <<B
docker inspect "$CN" --format '{{range .Mounts}}{{.Destination}} {{end}}' 2>/dev/null \
  | grep -q "/home/$CU" || { echo "the home directory is inside the image, so every rebuild needs an interactive login"; exit 1; }
B
check CTR.12 "a non-interactive run succeeds without prompting for auth" <<B
out=\$(docker exec -u "$CU" "$CN" claude -p 'reply with the single word ok' --model haiku --output-format json --permission-prompts none 2>&1)
printf '%s' "\$out" | grep -qi 'login\|not authenticated\|api key' && { echo "authentication is not persisted: \$out"; exit 1; }
[ -n "\$out" ] || { echo "no output from a non-interactive run"; exit 1; }
B
check CTR.13 "memory and pid limits are in force on the running container" <<B
m=\$(docker inspect "$CN" --format '{{.HostConfig.Memory}}' 2>/dev/null)
p=\$(docker inspect "$CN" --format '{{.HostConfig.PidsLimit}}' 2>/dev/null)
[ "\${m:-0}" -gt 0 ] || { echo "no memory limit"; exit 1; }
[ "\${p:-0}" != "0" ] && [ -n "\$p" ] || { echo "no pid limit"; exit 1; }
B
check CTR.14 "the data mount is owned by the container user's uid" <<B
huid=\$(stat -c %u "$R/data")
cuid=\$(docker exec -u "$CU" "$CN" id -u 2>/dev/null)
[ "\$huid" = "\$cuid" ] || { echo "host owns data as \$huid, container user is \$cuid; this presents as confusing permission errors"; exit 1; }
B
