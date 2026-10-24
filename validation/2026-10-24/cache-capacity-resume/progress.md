# Guarded compression resumed — 2026-10-24

Disposable cached content and old diagnostic dumps were removed with exact path containment and reparse-point checks; locked files were skipped. The two cleanup receipts record approximately 3.02 GB of physical capacity recovered, raising free space from approximately 1.57 GB to 4.58 GB. Application profiles, messages, settings, installed dependencies and all study recovery data were preserved.

The existing explicit owned-process resume helper accepted capacity above its unchanged 4 GiB threshold. The supervisor then confirmed child_state=running, resume_required=false and no paused reason. The same R PID 319 and compressor PID 383 continue; no restart or rerouting was performed. The supervisor retains its 3 GiB disk floor, 3 GiB pinned-memory reserve, 12 GiB container limit and two CPUs. Frozen code hashes remain unchanged. Public evidence redacts the live control token.

All 6,480 panel journal entries remain preserved. Compression is running; gzip completion, frozen analysis and independent audits remain pending. Available space permits continuation but does not guarantee enough capacity for all remaining outputs. The unchanged guard will pause again if necessary.
