#!/usr/bin/env bash
# Lints the document set against the harness: every check ID cited in prose must
# exist in the manifest, and every document cross-reference must resolve.
#
# Run it after editing any document. An earlier version of this set shipped four
# check IDs that were described in prose and never implemented, and a stale
# stage count, and nothing noticed until something like this was written.
set -uo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, os, sys
ids={l.split('\t')[0] for l in open('checks/expected-ids.txt') if l.strip() and not l.startswith('#')}
# Paths inside the AIOS data tree are not references to documents in this set.
DATA=('reference/business','reference/infra','reference/decisions','reference/patterns.md')
docs=[os.path.join(dp,fn) for dp,_,fns in os.walk('.') for fn in fns
      if fn.endswith('.md') and '/fixtures' not in dp and '/.git' not in dp]
id_re=re.compile(r'`([A-Z][A-Z0-9]{1,6}\.[0-9]{1,2})`')
ref_re=re.compile(r'`((?:core|reference|test|checks|conf|bin|skills)/[A-Za-z0-9._/-]+)`')
bad=0
for d in sorted(docs):
    t=open(d).read()
    miss=sorted(m for m in set(id_re.findall(t)) if m not in ids and not m.startswith('SELF.'))
    if miss: print(f"CITED BUT NOT IN THE MANIFEST  {d}: {' '.join(miss)}"); bad+=1
    unres=sorted(m for m in set(ref_re.findall(t))
                 if not m.startswith(DATA) and m!='checks/config.env'
                 and not os.path.exists(m.rstrip('/')))
    if unres: print(f"REFERENCE DOES NOT RESOLVE    {d}: {' '.join(unres)}"); bad+=1
print(f"{len(docs)} documents, {len(ids)} manifest IDs, {bad} problem(s)")
sys.exit(1 if bad else 0)
PY
