# Additional disposable cleanup — 2026-10-24

A broader search covered web/code/shader caches, application temporary locations, diagnostics, previews and Docker build-cache accounting. Exact cache roots were resolved and checked for reparse points before file deletion; locked files were skipped. The cleanup receipt preserves per-directory accounting. Profiles, messages, settings, installed dependencies, Docker images/volumes, recovery archives and checkpoints were retained.

Physical free space increased to approximately 3.88 GB. This remains roughly 0.42 GB below the unchanged 4 GiB resume threshold, without allowing for further output growth. The remaining inspected temporary candidates do not close that gap; active swap and locked files were retained. Docker build cache is almost entirely shared with retained images and provides negligible private reclaimable capacity.

The same compression process remains paused_for_capacity. No resume request, restart, rerouting or limit change was performed. Five products are published and the sixth remains preserved in progress; final compression and independent audits remain pending. Additional safe disposable storage or user-provided capacity is required before continuation.
