#!/bin/sh
# Run once in the isolated continuation container; /lower MUST be read-only.
set -eu
root=/workspace/scratch/837e4400dd1d
for pair in 'study07-results results' 'study07-r1-operations ops'; do
  set -- $pair
  mkdir -p /upper/"$2" /upper/work-"$2" "$root/$1"
  mount -t overlay overlay -o "lowerdir=/lower/837e4400dd1d/$1,upperdir=/upper/$2,workdir=/upper/work-$2" "$root/$1"
done
for d in study07-specification study07-execution study07-recovery; do
  mkdir -p "$root/$d"
  mount --bind "/lower/837e4400dd1d/$d" "$root/$d"
  mount -o remount,bind,ro "$root/$d"
done
mkdir -p /workspace/scratch/1e9a01af2c37
mount --bind /lower/1e9a01af2c37 /workspace/scratch/1e9a01af2c37
mount -o remount,bind,ro /workspace/scratch/1e9a01af2c37
