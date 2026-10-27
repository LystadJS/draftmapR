# Isolated final-archive restore rehearsal

Restore from the verified final ZIP on T7 Shield D: into a fresh D: directory, read back every extracted file, and import the archived runtime TAR into a separate Docker image. Mount only the restored scratch tree read-only in a separate validation container; never attach the live recovery volume. Restore the archived environment configuration, with network disabled and the original 12 GiB memory/swap, two CPU, and 6 GiB shared-memory limits. Check frozen runtime identity, receipt hashes and counts, graphics capabilities, and repository bundle integrity. Do not resume the completed study.

D: has no filename-case collisions for this archive. Original Linux file modes remain in ZIP metadata; the exFAT extracted copy will be exposed through a Linux read-only bind mount and executable access must be tested explicitly.

C: initially had 3,815,604,224 bytes free, insufficient for importing the complete runtime while preserving the 3 GiB reserve. Inactive Docker update downloads (4,206,254,933 bytes) were relocated from the exact temporary `DockerDesktopUpdates` folder to `D:/driftmapR-restore-rehearsal-support/DockerDesktopUpdates`. No installer was running from that folder. Files were preserved rather than deleted. C: subsequently had 8,011,862,016 bytes free. R temporary work, recovery archives, checkpoints, existing images and volumes were untouched.

Only safe verification metadata and tooling will be pushed publicly. Restored private operational records remain local on D:.

## Linux filesystem adjustment (2026-10-27)

The native exFAT restore passed read-back checks for 160,000 files but became prohibitively slow with large small-file directories. That task-owned extraction process was stopped; its incomplete directory remains preserved. A new 160 GiB ext4 filesystem image was created as a regular file at `D:/driftmapR-restore-rehearsal-support/restore-filesystem-20261027.ext4`, without formatting D: or modifying any existing archive. The image has 819,200 inodes and is mounted only in `driftmapr-linux-restore-20261027`, using loop-device access and the same 12 GiB memory/swap, two CPU, and 6 GiB shared-memory limits. Network remains disabled, the archived runtime image is unchanged, and no recovery volume is attached. Extraction will restore original Unix file modes and read back every payload. The restored scratch tree will be bind-mounted read-only before final gates.

## Durability gate

The Linux extraction's immediate read-back passed all 342,417 payloads, but the subsequent filesystem flush returned an I/O error. This invalidates an unqualified claim of durable restore completion. The runtime gate also failed because the intended study bind mount had not been established after the flush error; no study execution occurred. The image was unmounted, its loop handle reopened, and a non-modifying `e2fsck -fn` completed all five passes with exit 0. Persisted payloads must now be checked and any bad rehearsal copies repaired from the archive, followed by a successful flush, unmount, read-only remount and full hash pass. The verifier now requires the actual bind mount and a successful persisted-data verification receipt. Original archive and recovery data remain untouched.
