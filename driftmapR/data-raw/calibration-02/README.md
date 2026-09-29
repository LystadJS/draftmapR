# Reproducing calibration study 02

This directory contains research helpers, not exported package inference functions. Read `protocol.md` and `retrospective-findings.md` first. The package's paired-unit bootstrap API is unchanged. Candidate joint regions remain experimental regardless of this regular-null follow-up.

The cumulative development archive includes the exact engine source `study01-historical/driftmapR_0.0.5.9000.tar.gz`, the study-01 evidence, all study-02 checkpoints, raw stream plans, plots, tables and validation logs. Use an isolated R library containing driftmapR **0.0.5.9000**. Both the study-only Gram kernel and public-engine audit run against this frozen version. R 4.5.3 with ggplot2, clue, testthat and roxygen2 was used. No new package runtime dependencies are introduced.

```sh
R CMD INSTALL --library=/absolute/engine-library driftmapR_0.0.5.9000.tar.gz
export R_LIBS=/absolute/engine-library
# From the source package root:
Rscript -e 'testthat::test_dir("data-raw/calibration-02/tests")'
# Exact fresh-study reproduction; a matching directory resumes exact checkpoints.
Rscript data-raw/calibration-02/run.R /absolute/followup-output 4
Rscript data-raw/calibration-02/analyze.R /absolute/followup-output
Rscript data-raw/calibration-02/validate.R /absolute/followup-output
# Optional retrospective diagnostic, using ONLY old study-01 null panels:
Rscript data-raw/calibration-02/diagnose.R /absolute/study01-output /absolute/prefix-output 4
Rscript data-raw/calibration-02/analyze.R /absolute/prefix-output 80 10,20,40 199
```

The runner verifies scientific-source hashes in `freeze.rds` before generating data and verifies checkpoint identity before resuming. Do not edit a frozen method or overwrite checkpoints to run a different design. The complete source snapshot travels with outputs; study-01 `model.R` and `regions.R` are referenced verbatim. Serial resampling occurs within four independent outer workers. For systems without fork support, use one worker.

`seed-plan.rds` contains every raw panel's complete RNG state; each checkpoint retains all bootstrap RNG streams and feature-count matrices. The checkpoint's `panels[[anchor]]$values[[estimator]]` is an array with dimensions bootstrap draw × target × displacement component, with targets E015/E003/E006 and components dx/dy. Coordinates use public PCA units divided by sqrt(m). All failed vectors are NA and every planned attempt has a ledger row. `attempted=FALSE` distinguishes planned but unrun draws following undefined observed fits. No attempts are replaced.

`regions.csv` and `coverage-summary.csv` include both nested budgets and all three experimental methods. `covariance-summary.csv` uses the maximum budget; `tangent-summary.csv` compares empirical and exactly computed conditional tangent covariances. `contrasts-summary.csv` retains the within-panel pairing. Public PCA checks are in `audit.csv`. Counts of independent raw panels always use 240 per unit-count case, not the number of anchor/estimator/target evaluations.

The study tests verify numerical algorithms and accounting. They do not assert that simulated coverage must reach 95%; calibration outcomes are scientific results, not unit-test pass conditions. No R installation is needed to read the delivered report, CSVs, figures or logs.
