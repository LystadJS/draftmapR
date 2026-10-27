#!/bin/sh
# Run only inside the dedicated rehearsal container with loop-device access.
set -eu
image=/rehearsal-output/restore-filesystem-20261027.ext4
test -f "$image"
if mountpoint -q /tmp/restored; then
  echo 'Rehearsal filesystem is already mounted; refusing to replace it.' >&2
  exit 1
fi
test -e /dev/loop-control || mknod /dev/loop-control c 10 237
for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  test -e "/dev/loop$n" || mknod "/dev/loop$n" b 7 "$n"
done
device=$(losetup --read-only --find --show "$image")
test "$(blkid -s UUID -o value "$device")" = eb9d6f49-2906-47e8-9950-9661eee6fdec
mkdir -p /tmp/restored
mount -t ext4 -o ro,noload "$device" /tmp/restored
mount --bind /tmp/restored/rehearsal/scratch /workspace/scratch
mount -o remount,bind,ro /workspace/scratch
printf '%s\n' "$device" > /rehearsal-output/restore-loop-device.txt
echo 'Verified rehearsal filesystem mounted read-only; study execution was not resumed.'
