# Docker repair and dependency reconstruction, 2026-10-21

Docker Desktop 4.66.0 failed on inaccessible stale AF_UNIX socket reparse points in LocalAppData/Docker/run and LocalAppData/docker-secrets-engine. Individual socket rename failed. With the failed backend stopped, both parent directories were quarantined together and recreated. Backups ending .stale-20261021 and .stale-20261021-second remain beside their originals. No images, volumes, settings or credentials were deleted; no factory reset was performed. Both directories had been inspected (run contained sockets; secrets-engine contained only engine.sock). Docker now reports server 29.3.0.

Reference for the observed failure class: https://github.com/docker/desktop-feedback/issues/448. Repair success is established by the local server response, not by that report.

The PyPI NumPy 2.3.5 cp312 manylinux_2_27/2_28 x86_64 wheel contains _multiarray_umath.cpython-312-x86_64-linux-gnu.so SHA256 ba96467ae494babaf7c3458b09cc03c4200c2e10010860d80e452ffb8b01c8cd, exactly matching S07-I1. Other dependencies and runtime gates remain to be validated. No study panels resumed.
