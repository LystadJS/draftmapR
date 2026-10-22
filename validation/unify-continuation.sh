#!/bin/sh
# One-time migration after the failed validator has exited. Preserve upper data.
set -eu
root=/workspace/scratch/837e4400dd1d
test ! -e /upper/unified
mkdir /upper/unified /upper/work-unified
cp -a "$root/r-runtime" /upper/unified/r-runtime
for d in study07-specification study07-execution study07-recovery study07-results study07-r1-operations; do
  umount "$root/$d"
done
mv /upper/results /upper/unified/study07-results
mv /upper/ops /upper/unified/study07-r1-operations
mount -t overlay overlay -o lowerdir=/lower/837e4400dd1d,upperdir=/upper/unified,workdir=/upper/work-unified "$root"
for d in study07-specification study07-execution study07-recovery; do
  mount --bind "/lower/837e4400dd1d/$d" "$root/$d"
  mount -o remount,bind,ro "$root/$d"
done
python3 - <<'PY'
from pathlib import Path
import os
root=Path('/workspace/scratch/837e4400dd1d')
a=root/'study07-r1-operations/atomic-rename-probe-20261022'
b=root/'study07-results/atomic-rename-probe-20261022'
with a.open('xb') as f:
    f.write(b'atomic rename probe\n');f.flush();os.fsync(f.fileno())
os.rename(a,b)
assert b.read_bytes()==b'atomic rename probe\n'
os.rename(b,a)
print('Cross-directory atomic rename passed; probe retained in operations')
PY
