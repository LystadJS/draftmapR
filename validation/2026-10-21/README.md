# Runtime and package tests: 2026-10-21

Executed on Windows 11 with R 4.5.3, ggplot2 4.0.2, clue 0.3.68 and testthat 3.3.2. All 2,619 expectations in 147 blocks passed, with zero failures, errors, warnings or skips. See package-tests.log and test-results.csv. The initial sandbox run could not pass R's access checks for the existing user library; the successful run used the same installed packages with normal library access and locale C.

This validates editable package 0.0.8.9000 on the current Windows runtime. It does not validate the frozen Linux study runtime (installed package 0.0.7.9000), external BLAS/LAPACK identity or continuation of reserved simulation streams. WSL lists only docker-desktop; the Docker Linux engine is unavailable. No scientific panels were generated or resumed.

Next engineering step: activate the recovered R CMD check workflow at the repository root and point it at the nested driftmapR package. The existing workflow under driftmapR/.github/workflows is not a root workflow. Preserve the recovered package source unchanged.
