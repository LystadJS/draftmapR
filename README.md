# driftmapR

Recovered development package **0.0.8.9000**, with source provenance and partial scientific-checkpoint recovery.

The package is in [`driftmapR/`](driftmapR/). It is byte-identical to the 188-file package vendored in the verified S07 source archives. It includes alignment, movement measurement, supplied-label correspondence, PCA/classical-MDS adapters, and serial paired-measurement-unit bootstrap refits. Inferential coverage has not been established.

Prior native Windows R 4.5.3 package verification recorded 2,619 passing expectations in 147 test blocks, with zero test failures/errors/warnings/skips. Those tests were executed during initial recovery, not rerun for every archive batch. There is no fresh full R CMD check or completed scientific simulation claim.

Recovery status and exact missing files: [`recovery/README.md`](recovery/README.md), [`recovery/MISSING_ARTIFACTS.md`](recovery/MISSING_ARTIFACTS.md). All four checkpoint deltas and all R1 input archives are recovered. Saved execution remains 3,915 committed panels plus one partial panel out of 6,480 planned. Earlier original/raw archives remain missing.

This repository versions package code, recovery scripts, evidence, exact source identities, and four compact source/audit archives. Large scientific/runtime archives and extracted data remain in the local consolidated checkpoint. GitHub does **not** contain those large binary payloads; the source identities and missing/recovered indexes identify them. Conversation exports are not published here.

The existing `documentation/` and `validation/` directories are historical artifacts from the earlier 0.0.3.9000 repository. They are retained for provenance and do not establish current package validation. The original Git history is preserved.

See [`recovery/GIT_WORKFLOW.md`](recovery/GIT_WORKFLOW.md) for the continuing commit/push procedure.
