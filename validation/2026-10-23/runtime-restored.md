# Runtime review restoration after temporary cleanup

Removed only two inactive Docker updater staging/patch directories under Windows Temp, reclaiming 4,404,318,208 bytes (4.10 GiB). No recovery archives, checkpoint files, installed Docker files or Docker volumes were deleted. Cleanup evidence was pushed in 5d8f1cd.

Docker's Windows API remained stalled after capacity recovery. The supported restart command also stalled. Docker Desktop processes and only its WSL distribution were restarted after confirming the two recovery containers had no active R/Python workload. The existing collection container then failed startup with a stale nonempty cgroup. It is retained, not deleted.

Replacement container: `driftmapr-collection-20261023`, ID `7792346f7281db9b506a4ce5310502e045baa5205bbd07d85f2e017c51687b27`. It uses the same verified runtime image, read-only linked lower base, read-only validation scripts and durable `driftmapr-continuation-20261021` volume. Limits remain 12 GiB memory/swap combined, 2 CPUs and 6 GiB shared memory. The unified overlay was remounted with the saved recipe. Docker now reports server 29.9.2; this is distinct from the frozen scientific runtime inside the image.

The original review was restored without overwriting an existing destination. Runtime SHA-256 is exactly `015efb8a028c350f35f0e957e2e55d53145d7abe013289f01a61b36ef41b9cc0`. The passed partial receipt remains intact: panel 3916, s07_normal_mean_m160-1436, through chunk 258468. This supersedes the prior unconfirmed-restoration note. Scientific completion is not claimed.
