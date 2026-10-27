# Isolated restore rehearsal passed (2026-10-27)

The final archive on T7 Shield D: was restored into a new Linux filesystem image, and the restored runtime and completion receipts passed validation. The original archive, recovery checkpoints, live recovery volume and original runtime were not modified. The study was not resumed, and full scientific audits were not rerun.

## Verified results

- Archive SHA-256 matched `a4d22658f4debf82ca0b49fbac3151d28bd729eb96e48ffe7835ceb1bcc300c7` before extraction.
- All **342,417 payload files** were extracted and hashed. After repairing the writeback issue below, the image was detached, reopened through a read-only loop device, and all 342,417 files independently matched their manifest SHA-256 values. Original Unix file modes were restored.
- Non-modifying `e2fsck -fn` passed all five phases after reopening. The final image was cleanly detached.
- The imported archived runtime runs **R 4.5.3**. The frozen specification, implementation, installed estimator and numerical-runtime verification script passed against the actual read-only restored tree.
- All **162 system packages** exactly match the archived graphics-recovery inventory. A new Cairo PNG rendered successfully.
- The final audit, recovery-final audit, recovery audit and execution-complete receipts exactly match their previously verified hashes. The passed receipts agree on **6,480 panels** and **1,313,520 draws**.
- Repository history was cloned from the archived bundle at `4a02e291749f7c62b937c01962f360682c0643e0`; `git fsck --full` passed.
- Memory/swap remained 12 GiB, CPU capacity two CPUs, and shared memory 6 GiB. Network was disabled, the restored study was read-only for runtime validation, and no live recovery volume was attached.

## Failures fixed

The native exFAT copy became very slow with large small-file directories. It was stopped after at least 160,000 verified files and remains preserved as an incomplete copy. A new 160 GiB ext4 image on D: provided a Linux filesystem without reformatting the external drive.

Immediate read-back of the ext4 extraction passed, but the subsequent flush returned an I/O error. The rehearsal was therefore not accepted. The image was unmounted and reopened, and a persisted-data comparison identified **21 damaged rehearsal copies**. Those copies were replaced from the unchanged archive, explicitly flushed, and followed by the complete read-only verification described above. The initial runtime attempt also failed because the study bind mount had not been established after the flush error; the gate now checks the actual mount and requires the persisted-verification receipt. No original recovery data was repaired or altered.

The exact underlying cause of the transient loop-image writeback error was not established. New write/fsync, final flush, filesystem checks, full read-only hashes, and a separate clean reopen/receipt smoke check all subsequently passed. Do not accept cached read-back alone as durability evidence.

## Preserved artifacts and reopening

- Verified filesystem image: `D:/driftmapR-restore-rehearsal-support/restore-filesystem-20261027.ext4`.
- Safe runtime receipt: `D:/driftmapR-restore-rehearsal-support/restore-runtime-verification.json`.
- Independent durable payload receipt: `D:/driftmapR-restore-rehearsal-support/persisted-restore-verification.json`.
- Restored repository: `D:/driftmapR-restore-rehearsal-support/repository`.
- Both rehearsal containers are stopped; the imported image is retained. The original collection container was left running.
- The incomplete exFAT copy and relocated disposable Docker update downloads are retained on D:.

The tested read-only reopening procedure, using the retained container and its existing mounts, is:

```powershell
docker start driftmapr-linux-restore-20261027
docker exec driftmapr-linux-restore-20261027 sh /validation/mount-restored-rehearsal-readonly.sh
docker exec -w /tmp driftmapr-linux-restore-20261027 python3 /validation/verify-linux-restored-runtime.py
docker exec driftmapr-linux-restore-20261027 sh /validation/unmount-restored-rehearsal.sh
docker stop driftmapr-linux-restore-20261027
```

Check each command's exit status before advancing. The mount helper checks this image's filesystem UUID, selects an available loop device and mounts read-only. The unmount helper checks the same UUID and device identity before detaching. The final archive remains the authoritative preservation source. This rehearsal is complete; any future study execution is a separate task requiring its existing scientific gates.
