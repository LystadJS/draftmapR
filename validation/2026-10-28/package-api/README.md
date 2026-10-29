# Package API verification — 2026-10-28

Executed against driftmapR 0.0.8.9000 with native Windows R 4.5.3. No package computation code was changed during this verification. The accompanying commit adds a command guide, reproducible validation scripts, and corrects stale README claims.

## Results

- Full testthat suite: 2,619 expectations, 147 blocks; zero failures, errors, warnings, or skips (`test-results.csv`).
- Nine executable manual-example topics passed (`manual-examples.csv`); two topics contained no example code.
- Installed-package tour: all 10 exports and three S3 methods exercised; known movement recovered; PCA and two classical-MDS input routes agreed; plots rendered; 20/20 bootstrap attempts succeeded (`tour-summary.txt`, `bootstrap-attempts.csv`).
- Independent randomized invariance experiment: 100 rotations/reflections/translations/scalings, maximum apparent drift 7.850462293418876e-15, tolerance 1e-9 (`invariance-checks.csv`).
- Fresh R CMD check with `--as-cran --no-manual`: 0 errors, 0 warnings, 1 NOTE (`00check.log`). Tests, examples, built vignettes and rebuilt vignettes passed.

The NOTE records the placeholder maintainer, new submission, and development version. No LaTeX installation was available, so PDF manual generation was excluded. These results do not prove correctness for every input, inferential calibration, or CRAN readiness. The 20-attempt bootstrap is a small API demonstration, not a scientific precision recommendation. Frozen study data and recovery archives were untouched.

## Reproduce

From the repository root, install the package and development dependencies in a suitable R library. The audit expects an existing output directory and the path to the library containing the installed package:

```sh
R CMD INSTALL --library=/path/to/library driftmapR
Rscript validation/audit-package-api.R . /path/to/library /path/to/existing-audit-output
Rscript documentation/package-tour.R /path/to/tour-output
```

For the package check, with Pandoc available:

```r
rcmdcheck::rcmdcheck("driftmapR", args = c("--no-manual", "--as-cran"),
                    check_dir = "check-output", error_on = "never")
```

Local dependencies included testthat 3.3.2, pkgload 1.5.3, ggplot2 4.0.3, clue 0.3-68, knitr 1.51, rmarkdown 2.31, roxygen2 8.1.1, rcmdcheck 1.4.0, and Pandoc 3.10. LC_ALL=C was used to avoid an unrelated Windows startup locale warning. The check log's initial absolute local path was replaced with a descriptive label; check results were not edited.

See [the full command guide](../../../documentation/PACKAGE_GUIDE.md) and [runnable tour](../../../documentation/package-tour.R). Historical evidence elsewhere in this repository remains dated evidence rather than a substitute for this execution.
