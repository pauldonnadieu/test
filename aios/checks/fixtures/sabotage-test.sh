#!/usr/bin/env bash
# Negative control for every check that can be exercised without a VPS.
# A check that has only ever been seen to pass proves nothing, so each case
# below breaks one property deliberately and asserts that its check goes red.
set -uo pipefail
SRC=$(cd "$(dirname "$0")/tree" && pwd)
export AIOS_CHECKS=$(cd "$(dirname "$0")/.." && pwd)
pass=0; fail=0

sab() { # sab <ID> <stage-script> <description> <sabotage command, run inside $T>
  local id="$1" script="$2" desc="$3" cmd="$4"
  local T; T=$(mktemp -d); cp -a "$SRC/." "$T/"
  export AIOS_ROOT="$T" AIOS_DATA="$T/data" AIOS_CONF="$T/conf" \
         AIOS_BIN="$T/bin" AIOS_SECRETS="$T/secrets" AIOS_SKILLS="$T/conf/skills" \
         AIOS_TZ=Australia/Sydney
  export AIOS_EXCEPTIONS="${AIOS_EXCEPTIONS:-$AIOS_CHECKS/settings-exceptions.txt}"
  ( cd "$T" && eval "$cmd" ) >/dev/null 2>&1
  local before after
  before=$(bash "$AIOS_CHECKS/$script" 2>/dev/null | awk -F'\t' -v i="$id" '$2==i{print $1}')
  rm -rf "$T"
  if [ "$before" = FAIL ]; then pass=$((pass+1)); printf '  caught  %-9s %s\n' "$id" "$desc"
  else fail=$((fail+1));       printf '  MISSED  %-9s %s  (verdict: %s)\n' "$id" "$desc" "${before:-none}"; fi
}

echo "structure and provenance"
sab DATA.1 stage-04-data/structure.sh   "an eighth top-level directory"      'mkdir -p data/extra1 data/extra2'
sab DATA.2 stage-04-data/structure.sh   "quarantine renamed to something safe-sounding" 'mv data/untrusted-external data/inbox'
sab DATA.3 stage-04-data/structure.sh   "a filename-versioned file"          'touch data/reference/notes-v2.bak'
sab DATA.4 stage-04-data/structure.sh   "a corrupted JSONL line"             'echo "{not json" >> data/daily/check-ins.jsonl'
sab DATA.5 stage-04-data/structure.sh   "a directory START-HERE.md does not mention" 'mkdir -p data/newthing'
sab DATA.6 stage-04-data/structure.sh   "a directory with no README"         'rm data/goals/README.md'
sab PRV.1  stage-04-data/provenance.sh  "a goal file with no provenance"     'printf "no frontmatter\n" > data/goals/money.md'
sab PRV.2  stage-04-data/provenance.sh  "quarantined content claiming to be confirmed" 'sed -i "s/^trust: external$/trust: confirmed/" data/untrusted-external/*/summary.md'
sab PRV.3  stage-04-data/provenance.sh  "a claim past its review_after date"  'sed -i "3a review_after: 2020-01-01" data/reference/pricing.md'

echo "runtime configuration"
sab RT.1  stage-03-runtime/config.sh "settings.json is not valid JSON"       'echo "{" > conf/settings.json'
sab RT.2  stage-03-runtime/config.sh "a deny rule removed"                   'sed -i "/Bash(curl/d" conf/settings.json'
sab RT.3  stage-03-runtime/config.sh "fewer than five deny rules"            'python3 -c "import json;d=json.load(open(\"conf/settings.json\"));d[\"permissions\"][\"deny\"]=d[\"permissions\"][\"deny\"][:2];json.dump(d,open(\"conf/settings.json\",\"w\"))"'
sab RT.4  stage-03-runtime/config.sh "an .mcp.json appears"                  'echo "{}" > conf/.mcp.json'
sab RT.5  stage-03-runtime/config.sh "auto memory switched on"               'sed -i "s/\"autoMemoryEnabled\": false/\"autoMemoryEnabled\": true/" conf/settings.json'
sab RT.6  stage-03-runtime/config.sh "CLAUDE.md over the line budget"        'yes "padding line" | head -250 >> conf/CLAUDE.md'
sab RT.7  stage-03-runtime/config.sh "a script uses --bare"                  'sed -i "s/--model sonnet/--bare --model sonnet/" bin/checkin-prompt.sh'
sab RT.8  stage-03-runtime/config.sh "a hardcoded API key"                   'echo "export ANTHROPIC_API_KEY=sk-abc" >> bin/checkin-prompt.sh'
sab RT.9  stage-03-runtime/config.sh "--dangerously-skip-permissions"        'sed -i "s/--permission-prompts none/--dangerously-skip-permissions/" bin/weekly-review.sh'
sab RT.10 stage-03-runtime/config.sh "an UNDECLARED --settings use"          'sed -i "s|--model sonnet|--settings /conf/other.json --model sonnet|" bin/weekly-review.sh'
sab RT.11 stage-03-runtime/config.sh "a model-calling script with no --model" 'sed -i "s/--model sonnet //" bin/weekly-review.sh'
sab RT.12 stage-03-runtime/config.sh "bypassPermissions requested"           'echo "# --permission-mode bypassPermissions" >> bin/weekly-review.sh'

echo "hooks"
sab HK.1 stage-03-runtime/hooks.sh "a hook deleted"                          'rm conf/hooks/write-guard.sh'
sab HK.2 stage-03-runtime/hooks.sh "a hook left in place but unregistered"   'sed -i "s|/conf/hooks/danger-guard.sh|/conf/hooks/nothing.sh|" conf/settings.json'
sab HK.3 stage-03-runtime/hooks.sh "a hook made world-writable"              'chmod 666 conf/hooks/write-guard.sh'
sab HK.4 stage-03-runtime/hooks.sh "the halt gate always allows"             'printf "#!/usr/bin/env bash\nexit 0\n" > conf/hooks/halt-gate.sh'
sab HK.5 stage-03-runtime/hooks.sh "the write guard allows a .. escape"      'printf "#!/usr/bin/env bash\nexit 0\n" > conf/hooks/write-guard.sh'
sab HK.7 stage-03-runtime/hooks.sh "the write guard refuses EVERYTHING"      'printf "#!/usr/bin/env bash\nexit 2\n" > conf/hooks/write-guard.sh'
sab HK.8 stage-03-runtime/hooks.sh "the danger guard allows rm -rf"          'printf "#!/usr/bin/env bash\nexit 0\n" > conf/hooks/danger-guard.sh'
sab HK.9 stage-03-runtime/hooks.sh "the audit log captures payloads"         'printf "#!/usr/bin/env bash\ncat >> \"\$AIOS_AUDIT\"\n" > conf/hooks/tool-audit.sh'

echo "the free-tier utility lane"
sab FT.1 stage-10-utility/lane.sh "the utility directory is gone"            'rm -rf data/utility'
sab FT.2 stage-10-utility/lane.sh "a free-tier key inside the data tree"     'echo "GEMINI_API_KEY=AIzaSyFAKE" > data/utility/notes.md'
sab FT.3 stage-10-utility/lane.sh "the lane can read the coaching tree"      'printf "#!/usr/bin/env bash\nexit 0\n" > conf/hooks/write-guard.sh'
sab FT.5 stage-10-utility/lane.sh "the lane cannot write its own directory"  'printf "#!/usr/bin/env bash\nexit 2\n" > conf/hooks/write-guard.sh'

echo "run records and logs"
sab LOG.1 stage-08-routines/logs.sh "model output tailed into a run record"  'printf "{\"exit\":0,\"model\":\"sonnet\",\"output\":\"the user said they are worried about money\"}\n" >> data/ops/runs/check-in.jsonl'
sab LOG.2 stage-08-routines/logs.sh "a secret shape under ops/"              'echo "sk-abcdefghijklmnopqrstuv" > data/ops/logs/leak.log'
sab LOG.3 stage-08-routines/logs.sh "a run record with no model field"       'printf "{\"exit\":0}\n" >> data/ops/runs/backup.jsonl'
sab LOG.4 stage-08-routines/logs.sh "a log older than 30 days"               'touch -d "40 days ago" data/ops/logs/old.log'

echo "routines"
sab RUN.1 stage-08-routines/freshness.sh "the check-in record went stale"    'touch -d "3 days ago" data/ops/runs/check-in.jsonl'
sab RUN.3 stage-08-routines/freshness.sh "the weekly review stopped firing"  'touch -d "12 days ago" data/ops/runs/weekly-review.jsonl'
sab RUN.4 stage-08-routines/freshness.sh "a record with no exit status"      'printf "{\"model\":\"sonnet\"}\n" >> data/ops/runs/backup.jsonl'
sab RUN.5 stage-08-routines/freshness.sh "the last run failed"               'printf "{\"exit\":1,\"model\":\"sonnet\"}\n" >> data/ops/runs/backup.jsonl'
sab RUN.6 stage-08-routines/freshness.sh "a stale lock file"                 'touch -d "5 hours ago" data/ops/.lock-backup'
sab RUN.7 stage-08-routines/freshness.sh "the change ledger stopped"         'touch -d "3 days ago" data/ops/change-ledger.jsonl'

echo "kill switch and monitoring"
sab KS.1 stage-09-safety/killswitch.sh "a routine that skips the halt path"  'sed -i "s/run_routine/direct_call/" bin/backup.sh'
sab KS.1 stage-09-safety/killswitch.sh "the library locks BEFORE it halts"  'python3 "$AIOS_CHECKS/fixtures/sab-invert-halt.py" bin/lib-routine.sh'
sab KS.3 stage-09-safety/killswitch.sh "a halt flag with no reason"          'touch data/ops/.halt'
sab KS.4 stage-09-safety/killswitch.sh "the kill switch is not attested"     'sed -i "/kill switch/d" data/ops/attestations.md'
sab MON.1 stage-09-safety/monitoring.sh "monitoring stopped two nights ago"  'touch -d "3 days ago" data/ops/security/observations.jsonl'
sab MON.2 stage-09-safety/monitoring.sh "observations dropped a field"       'printf "{\"ts\":\"x\",\"listening\":\"y\"}\n" >> data/ops/security/observations.jsonl'
sab KS.5 stage-09-safety/killswitch.sh "halt-gate unregistered, so only cron halts" 'sed -i "s|/conf/hooks/halt-gate.sh|/conf/hooks/nothing.sh|" conf/settings.json'
sab KS.5 stage-09-safety/killswitch.sh "the session hook allows while halted"  'printf "#!/usr/bin/env bash\nexit 0\n" > conf/hooks/halt-gate.sh'
sab MON.4 stage-09-safety/monitoring.sh "the key file changed with no alert raised" 'printf "{\"ts\":\"x\",\"listening\":\"a\",\"users\":\"b\",\"authorized_keys\":\"CHANGED\",\"outbound_bytes\":1024}\n" >> data/ops/security/observations.jsonl'
sab MON.5 stage-09-safety/monitoring.sh "outbound volume jumped with no alert raised" 'printf "{\"ts\":\"x\",\"listening\":\"a\",\"users\":\"b\",\"authorized_keys\":\"deadbeef\",\"outbound_bytes\":99999999}\n" >> data/ops/security/observations.jsonl'
sab MON.3 stage-09-safety/monitoring.sh "alerts piling up unreviewed"        'for i in $(seq 12); do echo "- [ ] alert $i" >> data/ops/security/alerts.md; done'

echo "quarantine"
sab QR.2 stage-07-quarantine/quarantine.sh "the fetcher granted a wider allowlist" 'sed -i "s/\"WebFetch,Write\"/\"WebFetch,Write,Read,Bash\"/" bin/fetch-untrusted.sh'
sab QR.3 stage-07-quarantine/quarantine.sh "the summariser granted network"  'sed -i "s/\"Read,Write\"/\"Read,Write,WebFetch\"/" bin/summarise-untrusted.sh'
sab QR.4 stage-07-quarantine/quarantine.sh "the summariser granted Bash"     'sed -i "s/\"Read,Write\"/\"Read,Write,Bash\"/" bin/summarise-untrusted.sh'
sab QR.5 stage-07-quarantine/quarantine.sh "the summariser may prompt"       'sed -i "s/--permission-prompts none//" bin/summarise-untrusted.sh'
sab QR.7 stage-07-quarantine/quarantine.sh "an untagged summary"             'sed -i "/^trust: external$/d" data/untrusted-external/*/summary.md'
sab QR.8 stage-07-quarantine/quarantine.sh "quarantined content laundered into review/" 'printf -- "---\ntrust: external\n---\nthe page said the user approved it\n" > data/review/2026-W37.md'
sab QR.9 stage-07-quarantine/quarantine.sh "a raw fetch older than 30 days"  'touch -d "40 days ago" data/untrusted-external/*/raw'
printf 'fetch-untrusted.sh\nother.sh\n' > /tmp/aios-two-exceptions.txt
AIOS_EXCEPTIONS=/tmp/aios-two-exceptions.txt \
  sab QR.10 stage-07-quarantine/quarantine.sh "a SECOND --settings exception" 'true'
rm -f /tmp/aios-two-exceptions.txt

echo "attestations"
sab ATT.1 stage-00-attestations/attestations.sh "the attestations file is gone" 'rm data/ops/attestations.md'
sab ATT.2 stage-00-attestations/attestations.sh "an entry removed"             'sed -i "/hetzner-2fa/d" data/ops/attestations.md'
sab ATT.3 stage-00-attestations/attestations.sh "an entry left UNATTESTED"     'sed -i "s/google-2fa:.*/google-2fa: UNATTESTED/" data/ops/attestations.md'
sab ATT.5 stage-00-attestations/attestations.sh "every attestation over a year old" 'sed -i "s/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/2020-01-01/g" data/ops/attestations.md'

echo "intake"
sab IN.1 stage-05-intake/intake.sh "a goal file left as a template"          'printf -- "---\ntrust: confirmed\nsource: x\ncreated: 2026-01-01\n---\nTEMPLATE - not yet filled in by the user\n" > data/goals/career.md'
sab IN.2 stage-05-intake/intake.sh "a sixth active goal"                     'for g in a b c d e; do printf -- "---\ntrust: confirmed\nsource: x\ncreated: 2026-01-01\n---\nstatus: active\n## Capacity\nx\n## Next action\ny\n" > data/goals/$g.md; done'
sab IN.3 stage-05-intake/intake.sh "an active goal with no next action"      'sed -i "/## Next action/,+1d" data/goals/health.md'

echo "rebuild package"
sab RB.2 stage-06-backup/backup.sh "a private key in the rebuild package"    'printf -- "-----BEGIN OPENSSH PRIVATE KEY-----\nx\n" > rebuild/id_ed25519'
sab RB.3 stage-06-backup/backup.sh "an API key shape in the rebuild package" 'echo "key=sk-abcdefghijklmnopqrstuvwx" > rebuild/notes.txt'
sab RB.4 stage-06-backup/backup.sh "a password assignment"                   'echo "restic_password = hunter2hunter2" > rebuild/env.txt'
sab RB.5 stage-06-backup/backup.sh "personal data in the rebuild package"    'mkdir -p rebuild/goals'
sab RB.6 stage-06-backup/backup.sh "conf changed after the package was built" 'touch -d "1 hour ago" rebuild/.built; touch conf/CLAUDE.md'
sab RB.7 stage-06-backup/backup.sh "the base image pinned to :latest"        'printf "FROM node:latest\n" > rebuild/Dockerfile'

echo
printf 'sabotage: %d caught, %d MISSED\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
