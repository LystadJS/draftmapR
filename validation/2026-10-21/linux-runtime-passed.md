# Reconstructed Linux runtime: gates passed

2026-10-21: Ubuntu 24.04 image sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac, archived R 4.5.3 at /workspace/scratch/837e4400dd1d/r-runtime, exact BLAS/LAPACK hashes, official python-build-standalone 20260825 stripped Python 3.12.14, and PyPI NumPy 2.3.5 cp312 manylinux wheel reproduce the frozen runtime identities. Download identities are recorded separately. Rejected candidate Python builds are retained locally and are not used.

The unchanged S07-D1 and S07-I1 gates passed, followed by the unchanged S07-R1 gate (freeze e3edea53e346ce6ab1f966b8a9e6fcda6025bd1ca4e8d24a90be4ba297eba3b4). Sources were mounted read-only and Python bytecode writes disabled. Logs: frozen-linux-gates.log, frozen-r1-gate.log, reconstructed-linux-session.log. This supersedes the earlier blocked runtime status; it does not establish study completion or continuation-state readiness.

Local image driftmapr-runtime-verified:20261021 is sha256:41116d3337899e987908e191f135ae878abf60a7aed803522c81c8edcce3f1c6. It contains reconstructed dependencies, not study data. The validation container is driftmapr-runtime-validation. Dockerfile.pinned-runtime records the system image/library recipe; the restored runtime and binary downloads remain outside Git. Image and container are local, not pushed to a registry.

Reconstruction: build Dockerfile.pinned-runtime; extract driftmapR-study06-pinned-runtime.tar.gz in /workspace/scratch/837e4400dd1d; extract python-3.12.14-20260825.tar.gz under /opt/frozen; install the hash-recorded NumPy wheel with that Python; link python3 to /opt/frozen/python/bin/python3.12. Mount recovered driftmapR-S07-R1-sources read-only as /sources and validation read-only as /validation. Set PYTHONDONTWRITEBYTECODE=1 and S07_SOURCE_ROOT=/sources, then run /validation/verify-pinned-linux.sh and the archived Rscript-local /sources/study07-recovery/scripts/verify.R. Never replace the frozen guard or its expected hashes.

Official Python release: https://github.com/astral-sh/python-build-standalone/releases/tag/20260825.
