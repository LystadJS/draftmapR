# First bounded bootstrap calibration study

These scripts evaluate candidate joint displacement-vector regions. They are
research code outside the exported package API. The public bootstrap still
returns descriptive resampling summaries; this study does not automatically
turn them into confidence procedures.

Read `protocol.md` before interpreting any result. The analytic population
embedding, fixed common evaluation gauge, three candidate regions, six
scenarios, 80 independent datasets per scenario, 199 attempts per valid
observed fit, two delivery policies, and seeds were specified before outcomes.
The negative control deliberately violates between-unit independence.

## Reproduce

From the extracted cumulative archive root, with the recorded R dependencies:

```sh
# Exact engine used for the original study (included as historical source):
R CMD INSTALL bootstrap-engine-v0.0.4.9000/driftmapR_0.0.4.9000.tar.gz
Rscript driftmapR/data-raw/calibration-01/run-tests.R calibration-validation
Rscript driftmapR/data-raw/calibration-01/run.R calibration-output 4
Rscript driftmapR/data-raw/calibration-01/analyze.R calibration-output
Rscript driftmapR/data-raw/calibration-01/validate.R calibration-output
# Separate, explicitly post hoc covariance/analytic-context diagnostics:
Rscript driftmapR/data-raw/calibration-01/diagnostics.R calibration-output
```

The execution uses the public `bootstrap_drift()` API. Parallel scheduling is
only across independent outer datasets; each bootstrap call is serial. The
number of workers can be changed without changing the frozen dataset streams
or bootstrap seeds. Set BLAS thread counts to one when parallelizing datasets.
A fresh run with a different R/package/source fingerprint must use a fresh
output directory; checkpoint resumption refuses mismatching frozen inputs.

## Evidence files

- `frozen-design.rds`, `source-hashes-before-run.csv`, copied source files,
  `seed-plan.rds/csv`, and `session-info.txt` identify the frozen run.
- `population-targets.rds` contains analytic Gram matrices, spectra, aligned
  population coordinates, and true registered displacements.
- `checkpoints/pca/` retains every outer result, including failures, the exact
  data stream, unit counts and draw streams, warnings, all available bootstrap
  fit diagnostics, observed estimates, and the three targets' successful vectors.
- `checkpoints/cmds/` retains the 18 prespecified paired numerical audit cases.
- `outer-results.csv` has all 480 attempted datasets. `bootstrap-attempts.csv`
  has exactly 199 records per completed bootstrap call, with no replacement.
- `estimates.csv` has three target rows per defined observed estimator.
  `regions.csv` has all dataset/target/method/policy combinations, even when no
  estimator or region can be delivered. Unavailable decisions are `NA`.
- `bootstrap-vectors.csv` has three target rows per successful attempt in the
  fixed population gauge. Failed vectors have no rows; they are not zeros.
- Summary CSVs and PNG/PDF figures distinguish conditional coverage, delivery,
  operational coverage-and-delivery yield, and selection in rare-unit counts.
- `pca-mds-audit.csv` compares matching data and bootstrap draws. This is a
  numerical check, not an independent calibration replication.

Generated input panels are reconstructed exactly with `calibration_generate()`
from each saved job stream; the generator does not depend on scheduling.
Population targets are noisy population-embedding functionals, not bare latent
movement. A latent-stable entity need not be a population null when other
entities move. The whole-map null alone supports null-rejection interpretation.

Failure selection contrasts do not identify a causal effect of conditioning:
failed vectors are undefined. The first study's 80 independent outer datasets
per scenario give limited Monte Carlo precision. No method is promoted to a
validated public confidence procedure on the basis of this bounded grid.
