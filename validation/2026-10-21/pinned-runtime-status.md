# Pinned Linux runtime validation: incomplete

Archive identity passed: SHA256 and size match the historical receipt; all five archived numerical files and all 52 installed driftmapR engine files match the S07-I1 freeze MD5 values. All 11 package versions match (R normalizes clue's DESCRIPTION version 0.3-68 to 0.3.68). These checks read the archive without extracting or executing it. The initial auditor compared the unnormalized version spelling; that auditor issue was corrected and the complete audit rerun successfully.

Execution is blocked. Starting the installed Docker Desktop did not produce a Linux engine. Its host log reported: `initializing Inference manager ... dockerInference ... The file cannot be accessed by the system`. No Docker reset, socket deletion or global settings changes were performed. Only the docker-desktop WSL distribution was previously listed. Restore a working Linux execution host before attempting the gate.

The recovered archive does not include four externally pinned binaries:

- `/usr/lib/x86_64-linux-gnu/blas/libblas.so.3.12.0`
- `/usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3.12.0`
- `python3.12` from Python 3.12.14
- `_multiarray_umath.cpython-312-x86_64-linux-gnu.so` from NumPy 2.3.5

Exact expected hashes are in pinned-runtime-audit.json. Matching version labels alone is insufficient. These may be recovered from the original environment or reproduced and compared; their absence from this archive is not proof that they are unavailable everywhere. Restore the archived R runtime under `/workspace/scratch/837e4400dd1d` so its wrapper and frozen numeric paths retain their identities. Other shared-library dependencies must also resolve when Linux is available.

`validation/verify-pinned-linux.sh` calls the original design, implementation/runtime and manifest gates with bytecode writes disabled. It has not been executed here. Use a read-only source copy, leave frozen guards and manifests unchanged, and capture its output and exit code. A successful runtime gate is necessary before validating the later R1 binding and resumption state; it alone does not prove the restored study is ready to resume. No reserved panels were generated or resumed.

CI is separate: all three hosted checks on current source 0.0.8.9000 passed. This does not substitute for the pinned 0.0.7.9000 study engine.
