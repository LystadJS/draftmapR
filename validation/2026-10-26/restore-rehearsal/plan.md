# Isolated final-archive restore rehearsal

Restore from the verified final ZIP on T7 Shield D: into a fresh D: directory, read back every extracted file, and import the archived runtime TAR into a separate Docker image. Mount only the restored scratch tree read-only in a separate validation container; never attach the live recovery volume. Restore the archived environment configuration, with network disabled and the original 12 GiB memory/swap, two CPU, and 6 GiB shared-memory limits. Check frozen runtime identity, receipt hashes and counts, graphics capabilities, and repository bundle integrity. Do not resume the completed study.

D: has no filename-case collisions for this archive. Original Linux file modes remain in ZIP metadata; the exFAT extracted copy will be exposed through a Linux read-only bind mount and executable access must be tested explicitly.

C: initially had 3,815,604,224 bytes free, insufficient for importing the complete runtime while preserving the 3 GiB reserve. Inactive Docker update downloads (4,206,254,933 bytes) were relocated from the exact temporary `DockerDesktopUpdates` folder to `D:/driftmapR-restore-rehearsal-support/DockerDesktopUpdates`. No installer was running from that folder. Files were preserved rather than deleted. C: subsequently had 8,011,862,016 bytes free. R temporary work, recovery archives, checkpoints, existing images and volumes were untouched.

Only safe verification metadata and tooling will be pushed publicly. Restored private operational records remain local on D:.
