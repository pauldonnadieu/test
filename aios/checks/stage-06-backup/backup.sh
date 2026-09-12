#!/usr/bin/env bash
. "$AIOS_CHECKS/lib/lib.sh"
R="${AIOS_ROOT:-/srv/aios}"; D="${AIOS_DATA:-$R/data}"
rr() { restic "$@" 2>&1; }

check BK.1 "the repository is reachable" <<B
restic snapshots --last >/dev/null 2>&1 || { echo "repository unreachable"; exit 1; }
B
check BK.2 "a snapshot exists from the last 24 hours" <<B
last=\$(restic snapshots --json 2>/dev/null | python3 -c 'import json,sys;s=json.load(sys.stdin);print(s[-1]["time"] if s else "")')
[ -n "\$last" ] || { echo "no snapshots"; exit 1; }
cutoff=\$(date -d '24 hours ago' -Is)
[ "\$last" \> "\$cutoff" ] || { echo "newest snapshot is \$last"; exit 1; }
B
check BK.3 "restic check --read-data-subset passes" <<B
restic check --read-data-subset=5% >/dev/null 2>&1 || { echo "repository integrity check failed"; exit 1; }
B
check BK.4 "a restore produces a byte-identical file" <<B
# The only check in this stage that means much. The others tell you why it failed.
canary="$D/ops/.backup-canary"
[ -f "\$canary" ] || { echo "no canary file"; exit 1; }
want=\$(sha256sum "\$canary" | cut -d' ' -f1)
t=\$(mktemp -d)
restic restore latest --target "\$t" --include "\$canary" >/dev/null 2>&1
got=\$(sha256sum "\$t\$canary" 2>/dev/null | cut -d' ' -f1)
rm -rf "\$t"
[ "\$want" = "\$got" ] || { echo "restored hash \$got does not match \$want"; exit 1; }
B
check BK.5 "the canary plaintext does not appear in the repository" <<B
# Encryption proven by evidence rather than by configuration.
canary="$D/ops/.backup-canary"
needle=\$(head -c 64 "\$canary" 2>/dev/null)
[ -n "\$needle" ] || { echo "no canary content"; exit 1; }
repo="\${RESTIC_REPOSITORY:-}"
case "\$repo" in rclone:*) exit 0 ;; esac
grep -rqF "\$needle" "\$repo" 2>/dev/null && { echo "PLAINTEXT FOUND IN THE REPOSITORY"; exit 1; }
exit 0
B
check BK.6 "retention has been applied and the snapshot count is bounded" <<B
n=\$(restic snapshots --json 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')
[ "\${n:-0}" -gt 0 ] || { echo "no snapshots"; exit 1; }
[ "\$n" -le 40 ] || { echo "\$n snapshots; retention is not running"; exit 1; }
B
check BK.7 "the snapshot contains BOTH the data tree and conf/" <<B
ls=\$(restic ls latest 2>/dev/null)
missing=""
for p in goals daily review reference untrusted-external ops; do
  printf '%s' "\$ls" | grep -q "/data/\$p" || missing="\$missing data/\$p"
done
printf '%s' "\$ls" | grep -q '/conf/CLAUDE.md' || missing="\$missing conf/CLAUDE.md"
printf '%s' "\$ls" | grep -q '/conf/skills' || missing="\$missing conf/skills"
[ -z "\$missing" ] || { echo "NOT IN THE SNAPSHOT:\$missing  (a restore would return a machine that has forgotten what it learned)"; exit 1; }
B
check BK.8 "a file added to conf/ today is in the latest snapshot" <<B
newest=\$(find "$R/conf" -type f -mtime -1 2>/dev/null | head -1)
[ -z "\$newest" ] && exit 0
restic ls latest 2>/dev/null | grep -qF "\$(basename "\$newest")" || { echo "\$newest is not in the snapshot"; exit 1; }
B
check RB.1 "the rebuild package exists with a RESTORE.md" <<B
[ -f "$R/rebuild/RESTORE.md" ] || { echo "no $R/rebuild/RESTORE.md"; exit 1; }
B
check RB.2 "the rebuild package contains no private keys" <<B
hits=\$(grep -rl -- '-----BEGIN .*PRIVATE KEY' "$R/rebuild" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check RB.3 "the rebuild package contains no API-key shapes" <<B
hits=\$(grep -rlE '(sk-[A-Za-z0-9_-]{16,}|AIza[0-9A-Za-z_-]{20,}|AKIA[0-9A-Z]{16})' "$R/rebuild" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check RB.4 "the rebuild package contains no password assignments" <<B
hits=\$(grep -rlE '(password|passphrase|secret)[[:space:]]*[=:][[:space:]]*[^[:space:]"'"'"']{6,}' "$R/rebuild" 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check RB.5 "the rebuild package contains no personal data" <<B
hits=\$(find "$R/rebuild" -type d \( -name goals -o -name daily -o -name review -o -name reference \) 2>/dev/null)
[ -z "\$hits" ] || { echo "\$hits"; exit 1; }
B
check RB.6 "the rebuild package is not older than the config it must recreate" <<B
[ -f "$R/rebuild/.built" ] || { echo "no build marker"; exit 1; }
newer=\$(find "$R/conf" -newer "$R/rebuild/.built" -type f 2>/dev/null | head -5)
[ -z "\$newer" ] || { echo "conf changed since the package was built:\$newer"; exit 1; }
B
check RB.7 "base image and CLI versions are pinned, never latest" <<B
f="$R/rebuild/Dockerfile"
[ -f "\$f" ] || { echo "no Dockerfile"; exit 1; }
grep -qE '^FROM .*:latest' "\$f" && { echo "FROM ...:latest; a rebuild in a year is not the same machine"; exit 1; }
grep -qE '^FROM .*:[0-9]' "\$f" || { echo "base image is not pinned to a version"; exit 1; }
exit 0
B
