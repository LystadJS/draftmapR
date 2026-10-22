#!/bin/sh
# Run once in the isolated continuation container; /lower MUST be read-only.
set -eu
root=/workspace/scratch/837e4400dd1d
test ! -e /upper/ops # Migrate an old two-overlay volume with unify-continuation.sh.
mkdir -p /upper/unified /upper/work-unified
if test ! -d /upper/unified/r-runtime; then
  cp -a "$root/r-runtime" /upper/unified/r-runtime
fi
mount -t overlay overlay -o lowerdir=/lower/837e4400dd1d,upperdir=/upper/unified,workdir=/upper/work-unified "$root"
for d in study07-specification study07-execution study07-recovery; do
  mkdir -p "$root/$d"
  mount --bind "/lower/837e4400dd1d/$d" "$root/$d"
  mount -o remount,bind,ro "$root/$d"
done
mkdir -p /workspace/scratch/1e9a01af2c37
mount --bind /lower/1e9a01af2c37 /workspace/scratch/1e9a01af2c37
mount -o remount,bind,ro /workspace/scratch/1e9a01af2c37
