#!/bin/sh
# Detach only the known rehearsal filesystem; never delete data.
set -eu
device=$(findmnt -n -o SOURCE /tmp/restored)
test "$(blkid -s UUID -o value "$device")" = eb9d6f49-2906-47e8-9950-9661eee6fdec
if mountpoint -q /workspace/scratch; then
  test "$(stat -c %d /workspace/scratch)" = "$(stat -c %d /tmp/restored)"
  umount /workspace/scratch
fi
umount /tmp/restored
losetup -d "$device"
echo 'Rehearsal filesystem cleanly detached; image and recovery data preserved.'
