# Atomic publication repair

The first partial validator exited 1 after 33,417 seconds. It passed the original input catalog and committed raw/JSON prefix checks, traversed the 3,915 committed panels, then failed publishing the partial panel JSON with EXDEV (invalid cross-device link). No partial success receipt was produced and the handoff correctly refused collection.

Cause: results and operational state were separate overlay mounts. The unchanged adapter writes a JSON temporary under state and atomically renames it into results; that operation requires one mount/filesystem. The earlier assembly topology violated this requirement.

Repair: preserved the failed process receipt and full log, unmounted the separate overlays after the child exited, moved their small writable upper trees into a single upper root on the same durable volume, and mounted one overlay at the original workspace root. The verified runtime was copied from the container image into this upper root before mounting; original recovered lower files remain read-only. Frozen source directories remain read-only bind mounts. A probe successfully renamed a file from operations into results and back; its bytes were verified and the probe retained.

The mount recipe now uses the unified overlay. The handoff exports text evidence using docker exec cat because docker cp cannot resolve the in-container overlay mounts. Partial supervision no longer displays an inherited historical driver-phase value. The collector and scientific source code are unchanged. Validation must be rerun and pass before collection starts; the previous traversal is not treated as partial-panel success. Capacity limits remain unchanged.
