#!/bin/sh
# Restore the historical staging parent on the retained Docker volume.
# Run only after inspecting a pre-routing failure; never remove route evidence.
set -eu
test ! -e /root/.codex/tmp
test ! -L /root/.codex/tmp
test ! -e /upper/compression-staging
test ! -L /upper/compression-staging
python3 - <<'PY'
import csv, os, shutil
from pathlib import Path
tables=Path('/workspace/scratch/837e4400dd1d/study07-results/S07-R1/tables')
with (tables/'csv-chunk-manifest.csv').open() as f:
    products={r['product'] for r in csv.DictReader(f)}
assert products
for name in products:
    p=Path(name)
    assert not p.is_absolute() and '..' not in p.parts and name.endswith('.csv.gz')
    assert not os.path.lexists(tables/name)
    assert not os.path.lexists(tables/(name+'.committing'))
assert min(shutil.disk_usage('/lower').free,shutil.disk_usage('/upper').free)>5*1024**3
print('Pre-routing absence and physical 5 GiB capacity gate passed:',len(products),'products')
PY
mkdir -p /root/.codex
mkdir /upper/compression-staging
ln -s /upper/compression-staging /root/.codex/tmp
test "$(readlink -f /root/.codex/tmp)" = /upper/compression-staging
echo 'Historical staging parent restored on durable volume; frozen route and guards unchanged.'
