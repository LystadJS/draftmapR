# driftmapR

**Executable development prototype, version 0.0.8.9000.** Embed repeated feature
data with PCA or classical MDS, align 2-D maps, inspect transformations, measure
relative entity movement, and match supplied cluster identities through time. The API is a
prototype contract, not yet a stable v0.1 release.

## Why align repeated maps?

Independently computed low-dimensional coordinates can rotate, reflect, or
translate even when the underlying configuration is unchanged. Comparing their
raw coordinates would attribute that arbitrary frame change to the entities.
`driftmapR` fits an explicit Procrustes transformation before measuring movement.

This does not recover absolute movement. If every entity really translates
together, that change is mathematically indistinguishable from a translated
coordinate system. Estimates are relative to the entities used for alignment.
Known stable alignment anchors can define an external reference; assuming their
stability is the analyst's responsibility.

## Install

R 4.1 or newer is required. This package is not on CRAN. From the parent of the
unpacked `driftmapR` source directory:

```r
install.packages(c("ggplot2", "clue"))
install.packages("driftmapR", repos = NULL, type = "source")
library(driftmapR)
```

Alternatively install the supplied `driftmapR_0.0.8.9000.tar.gz` using
`install.packages("driftmapR_0.0.8.9000.tar.gz", repos = NULL, type = "source")`.
driftmapR contains no compiled code. Its nonstandard runtime dependencies are
ggplot2 and clue; clue includes compiled code and depends on the recommended
cluster package. Other imports ship with R.

## Runnable example

```r
library(driftmapR)

first <- data.frame(
  entity = letters[1:5], time = 1,
  x = c(0, 3, 0, 2, 1), y = c(0, 0, 3, 2, 1)
)
truth_second <- first
truth_second$time <- 2
truth_second$x[5] <- truth_second$x[5] + 0.8
truth_second$y[5] <- truth_second$y[5] + 0.6

# A 90-degree row-vector rotation plus arbitrary translation.
rotation <- matrix(c(0, 1, -1, 0), nrow = 2, byrow = TRUE)
raw_second <- truth_second
xy <- as.matrix(truth_second[c("x", "y")]) %*% rotation
xy <- sweep(xy, 2, c(7, -4), "+")
raw_second[c("x", "y")] <- xy

map <- drift_data(rbind(first, raw_second), periods = 1:2)
fit <- align_snapshots(map, reference = "previous", anchors = letters[1:4])
movement <- measure_drift(fit)
movement                          # entity e moves 1 unit; anchors ~0
stopifnot(abs(movement$distance[movement$entity == "e"] - 1) < 1e-10)
fit$transformations[c("time", "reference_time", "n_matched", "rss")]
fit$transformations$rotation[[2]]  # explicit raw-to-aligned rotation
distance_to_anchor(fit, "a")
plot_drift_map(fit, labels = TRUE)
```

## Implemented contract

| Function / result | Behavior |
|---|---|
| `drift_data()` | Validates keys, schedule, finite coordinates, and exactly two dimensions; retains extra columns and optional original-data metadata. |
| `embed_snapshots()` | PCA/classical-MDS adapters; explicit feature schema, scaling and weights; retained original inputs, models, spectra and diagnostics. |
| `validate_drift_data()` | Validates object structure; optionally tests overlap and identifiable alignment geometry. |
| `align_snapshots()` | Previous or first reference; translation, rotation, reflection; optional isotropic scaling; optional fitting anchors. |
| `object$aligned` | All transformed points, including entrants. |
| `object$transformations` | Time/reference, counts, RSS, radial RMSE, normalized discrepancy, scale, determinant, conditioning, and list columns for rotations/translations/fitting IDs. |
| `measure_drift()` | Adjacent-period displacement components and Euclidean distance as a tidy data frame. |
| `distance_to_anchor()` | Distance to an observed entity or fixed aligned-coordinate pair. |
| `match_clusters()` | Maximum-overlap one-to-one correspondence, stable IDs, eligibility thresholds, exact deterministic ties, and assignment diagnostics. |
| `object$clusters` | Supplied labels plus stable identities; unassigned observations retain missing IDs. |
| `object$diagnostics$cluster_matching` | Registry, links/unmatched reasons, positive flows, pair denominators, overlap and eligible-score matrices. |
| `plot_drift_map()` / `plot()` | Descriptive positions, adjacent arrows, period colors/shapes, and optional latest-position labels. |
| `paired_unit_design()` / `bootstrap_drift()` | Declared paired units, reproducible full refits, failure ledger, and conditional resampling summaries. |
| `print()` / `summary()` | Compact object and fit summaries. |

`measure_drift()` returns a table; it does not change its input. Assign
`fit$movement <- measure_drift(fit)` if the table should travel with the object.
Original coordinates are never overwritten. Re-aligning starts from the raw
coordinates and clears any stored movement/bootstrap output.

## Rules that affect interpretation

- Only adjacent **scheduled** periods are compared. No trajectory bridges an
  entity's missing observation. No coordinates are imputed.
- Numeric and date times sort automatically. Character times require an explicit
  `periods` order. To detect an entirely absent period, supply the expected
  schedule: observations at times 1 and 3 with `periods = 1:3` raise an error.
  Without that schedule, 1 and 3 are consecutive observed snapshots.
- Each comparison needs at least three noncollinear fitting entities and
  nonsingular cross-covariance. Sparse maps can be ingested but cannot be aligned
  unless they satisfy that condition. Shared anchors may differ by pair.
- `scale = FALSE` preserves common units. `scale = TRUE` removes isotropic size
  differences and can therefore absorb real expansion/contraction.
- Previous reference uses the **already aligned** previous map and may accumulate
  reference drift. First reference requires enough overlap with the first map.
- Movement is displacement per interval, not speed. A nonzero value is not a
  significance test. All-shared fitting can redistribute real cluster movement
  into the rest of the map; the simulation quantifies this limitation.
- Keeping a `cluster` column alone does not match identities; call `match_clusters()`.

## Cluster correspondence

```r
library(driftmapR)
labels <- data.frame(
  entity = rep(letters[1:6], 2), time = rep(1:2, each = 6),
  x = rep(c(0, 1, 0, 4, 5, 4), 2), y = rep(c(0, 0, 1, 0, 0, 1), 2),
  cluster = rep(c("A", "B", "renamed_2", "renamed_1"), each = 3)
)
matched <- drift_data(labels) |> match_clusters()
matched$clusters
matched$diagnostics$cluster_matching$assignments
stopifnot(identical(matched$clusters$cluster_id[1:6],
                    matched$clusters$cluster_id[7:12]))
```

Matching uses entity membership, so coordinate alignment is optional. It
maximizes total overlap counts over one-to-one links between adjacent periods.
`min_overlap` and `min_jaccard` filter candidate links before optimization;
Jaccard denominators use shared entities assigned in both periods. Original
labels remain intact. Missing labels and explicitly supplied `noise` labels do
not contribute to matching. Label zero is a valid cluster unless excluded.

New/unmatched clusters receive fresh IDs; identities never revive across gaps.
Deterministic lexicographic tie resolution makes row-shuffled input reproducible.
An `edge_margin` of zero means an equally optimal correspondence omits that link;
positive margins are objective contrasts, not confidence measures. Optional
`diagnose_ties = FALSE` leaves these diagnostics explicitly missing.

Positive flows with multiple destinations/sources receive split/merge candidate
flags. Ordinary entity switching can create the same pattern. These flags do
not identify latent split/merge events, and the one-to-one model does not
propagate an identity to several descendants. See the correspondence vignette
and `inst/validation/cluster-correspondence.md` for the exact contract.

## PCA and classical-MDS adapters

```r
measurements <- rbind(first, truth_second)
names(measurements)[3:4] <- c("measurement_a", "measurement_b")
feature_map <- embed_snapshots(
  measurements, features = c("measurement_a", "measurement_b"), method = "pca"
)
feature_fit <- align_snapshots(feature_map, anchors = letters[1:4])
measure_drift(feature_fit)
feature_fit$diagnostics$embedding

# The same Euclidean geometry has equivalent PCA and classical-MDS maps,
# up to arbitrary axis orientation, when the retained plane is identified.
mds_map <- embed_snapshots(
  measurements, features = c("measurement_a", "measurement_b"), method = "cmds"
)
```

Every snapshot is centered. `standardize = "none"` preserves common feature
units; `"first"` uses first-period sample SDs, `"pooled"` uses all entity-time
rows, and `"period"` recalibrates each period. The last option can absorb real
dispersion changes. Features must be explicitly selected, numeric, finite, and
observed throughout the common schema. No missing values are imputed. Cluster
labels supplied as extra metadata remain available to `match_clusters()`.

`method = "cmds"` also accepts a list of labeled `dist` objects or symmetric,
zero-diagonal dissimilarity matrices. Provide `periods`, or use list names as
the ordered schedule. Materially negative Gram eigenvalues raise an error by
default. `negative_eigen = "truncate"` explicitly accepts an approximate map
with a warning and negative-inertia diagnostics; no additive correction is
implemented. Both adapters reject insufficient rank and warn when the second
and third eigenvalues tie at the 2-D truncation boundary. Such ambiguity cannot
be removed by rotating a fitted map.

`feature_weights` applies square-root weights without normalization, so integer
weights reproduce feature-column multiplicities. Original input, feature order,
raw centers, scale vectors, per-period fits, and spectra are retained. The
stored PCA model acts on scaled/weighted features, so predicting from raw data
requires that preprocessing first. See the embedding vignette for runnable
distance-list and multiplicity examples.

## Paired measurement-unit bootstrap

`bootstrap_drift()` refits PCA/classical-MDS embeddings and temporal alignment
using the same sampled measurement-unit multiplicities across all periods.
Declare exchangeable, independent units (or strata of units) explicitly:

```r
# A complete four-feature, two-block example.
a <- c(-2, -1, 0, 1, 3)
b <- c(0, 2, -1, 1, 0)
d <- data.frame(entity = rep(letters[1:5], 2), time = rep(1:2, each = 5),
                f1 = rep(a, 2), f2 = rep(b, 2),
                f3 = rep(2 * a, 2), f4 = rep(2 * b, 2))
fit <- embed_snapshots(d, paste0("f", 1:4)) |> align_snapshots()
design <- paired_unit_design(
  c(f1 = "unit_A", f2 = "unit_A", f3 = "unit_B", f4 = "unit_B"),
  assumptions = "Illustrative independent measurement blocks; not an empirical sampling claim."
)
resampled <- bootstrap_drift(fit, design, B = 20, seed = 42, keep = "replicates")
resampled$bootstrap$summary
resampled$bootstrap$attempts
resampled$bootstrap$draws[[1]]
```

Units may contain one feature or equal-width feature blocks. Optional strata
retain their original sample sizes. Ordinary fixed covariates are not
automatically exchangeable; without a sampling model this is feature-choice
sensitivity. This engine requires original feature data and observed feature
weights equal to one. Coordinate-only/distance-only bootstrap, general data
resamplers, and cluster refitting remain deferred.

Each replicate baseline is oriented to the observed baseline **without scaling**;
subsequent raw maps follow the observed temporal alignment recipe, including
anchors and optional temporal scaling. Entity-time availability stays fixed.
Rank failure, an ambiguous retained-plane boundary, or alignment failure excludes
the entire replicate. Exactly `B` attempts are made; failures are never redrawn.
The attempt ledger and available partial diagnostics remain inspectable.

Summaries require at least two complete successes and the declared success
fraction (`min_success = 0.95` by default). Otherwise estimates are `NA` with
explicit status/counts. Successful-draw means, covariance, sample quantiles, and
Monte Carlo SEs are **conditional resampling summaries**, not calibrated
confidence intervals. A positive lower quantile of displacement norms does not
establish movement. Existing supplied cluster correspondence is retained, but
no bootstrap cluster stability is computed.

Each attempt has a saved L'Ecuyer-CMRG stream. One isolated R process constructs
the draw plan so the caller's entire RNG state, including Box-Muller cached
normals, remains untouched; all embedding/alignment refits execute serially.
Increasing `B` preserves earlier draws. `keep = "summary"` reduces returned
size, but exact quantiles currently require temporary storage of successful
coordinate/movement draws in both modes. Start with a small pilot for large
panels; dense MDS and repeated fits can be expensive.

See the paired-bootstrap vignette and `inst/validation/bootstrap-specification.md`
for the implemented contract and remaining inference/calibration requirements.

## Development and checks

From the parent of the source directory:

```r
install.packages(c("testthat", "roxygen2", "knitr", "rmarkdown"))
roxygen2::roxygenise("driftmapR")
testthat::test_local("driftmapR")
```

```sh
R CMD build driftmapR
R CMD check --no-manual driftmapR_0.0.7.9000.tar.gz
R CMD INSTALL driftmapR_0.0.7.9000.tar.gz
Rscript driftmapR/data-raw/simulate-prototype.R simulation-output
Rscript driftmapR/data-raw/simulate-clusters.R cluster-simulation-output
Rscript driftmapR/data-raw/simulate-embeddings.R embedding-simulation-output
Rscript driftmapR/data-raw/simulate-bootstrap.R bootstrap-simulation-output
```

HTML vignette building requires Pandoc. The packaged manual pages do not.
The `.github/workflows` check configuration targets Linux, Windows, and macOS
using [r-lib's standard actions](https://github.com/r-lib/actions/tree/v2/examples).
Remote CI has not run; no remote repository has been created or published.
`DESCRIPTION` deliberately uses a marked prototype maintainer placeholder;
replace it with verified author/maintainer details before public release.

## First bounded calibration study

The six-scenario study completed **480 independent datasets and 93,132 main
bootstrap attempts**, using 199 attempted draws per defined observed estimator.
Three nominal 95% joint vector-region candidates were specified before outcomes.
For primary target E015, whole-map-null coverage was **81.25%** for the Wald and
empirical Mahalanobis ellipses and **86.25%** for the Euclidean error ball.
In the rare-axis stress, only **26/80 datasets** delivered production-gated
regions; successful draws overrepresented rare measurement units.

These findings do **not** establish calibrated inference. Candidate regions
remain research helpers under `data-raw/calibration-01/`; no confidence-region
API is exported. The package's bootstrap summaries remain descriptive and
conditional on successful computation. Undercoverage also occurred with no
failed draws, so lowering the success gate cannot explain or repair all results.

The cumulative development archive includes the frozen protocol, source/seed
fingerprints, every outer checkpoint, full attempt ledgers, numerical PCA/MDS
audits, summary tables, and PNG/PDF figures. See
`inst/validation/calibration-study-01.md` and the study README for results and
exact-engine reproduction. The original run used 0.0.4.9000; 0.0.5.9000 adds
study code and documentation without changing the public computational engine.

## Independent regular-null follow-up

Version 0.0.6.9000 adds a frozen follow-up with **960 independent panels and
383,040 paired-unit draws**. At 20, 40, 160 and 640 units, primary Wald coverage
was **87.08%, 90.00%, 95.00% and 95.42%** (240 panels each). All draws succeeded.
Oracle baseline refitting scarcely changed coverage. At 20 units, average
bootstrap covariance matched outer variance while coverage remained low;
a uniform covariance multiplier is therefore not justified by these results.
Population-tangent controls improved small-unit coverage but require oracle
information and do not validate a deployable uncertainty procedure.

The larger-unit null results do not establish a minimum sufficient sample size,
alternative coverage or general inferential validity. The public confidence API
remains gated. All 24 full public PCA/bootstrap audits agreed numerically with
the faster study-only Gram implementation. See
`inst/validation/calibration-study-02.md`, the frozen protocol and the disclosed
analysis addendum under `data-raw/calibration-02/`. The exact study engine was
0.0.5.9000; current public R code is unchanged.

## Not implemented

Consensus/generalized alignment; cluster fitting/stability;
calibrated bootstrap confidence regions; inferential detection; direction
uncertainty; anchor-distance change convenience output; higher dimensions;
specialized transition/ranking plots; applications; large simulation sweeps.
UMAP, graph-layout, and Bayesian adapters remain deferred.

The package is **not CRAN-ready or R Journal-ready**. The essential landscape
review in `inst/validation/landscape-review.md` documents existing alternatives;
`vegan` already covers much pairwise Procrustes functionality. This prototype
claims an integration workflow, not a new alignment method.

See `inst/validation/methodology.md`, `inst/validation/roadmap.md`, and the
getting-started vignette for implementation details and next milestones.


## Finite-unit studentization and null/movement calibration

Version 0.0.7.9000 adds an executable research occurrence-jackknife studentized
joint region for the full normalized PCA/temporal-alignment estimator. Each
observed, bootstrap, and leave-one fit refits the embeddings and temporal
alignment into the same observed reference. Failed required deletions invalidate
the whole covariance; all plans and failures remain visible.

The frozen study includes **800 independent panels and 159,200 planned draws**.
Primary studentized null coverage at 20/40/160 units was 93.33/95.00/96.67%;
movement coverage was 92.50/94.17/94.17%. Small-unit gains came with larger regions
and lower detection. E006 null40 remained at 90.83%, and rare-axis delivery was
only **2/80**. These results do not support a general calibrated confidence API.

See `inst/validation/calibration-study-03.md` for complete results and
`data-raw/calibration-03/README.md` for the runnable candidate and frozen protocol.
Use the full checkout from the development archive: standard R source tarballs
exclude `data-raw`. Exact study reproduction uses the retained 0.0.6.9000 public
engine; the 0.0.7.9000 delivery adds research code and evidence without changing
public computational R code or exports.

## Independent secondary replication and frame diagnostics

Version 0.0.8.9000 adds study-04 research code for an independent replication of
E006/null40 and E003/null160. The frozen design has 400 panels per null cell,
100 per movement-control cell at the same unit counts, and 120 rare-axis panels:
1,120 panels and 222,880 planned bootstrap draws. The two primary coverage tests
use a fixed Bonferroni family of two; all other comparisons are descriptive.

`study04_one()` returns the unchanged study-03 result plus a separate `frame`
diagnostic. Each diagnostic full fit and deletion registers directly to the
known population baseline, with its own registration failures. This unavailable
reference is a sensitivity check, not an application-ready correction. An
opposite-half empirical covariance benchmark retains donor counts and does not
assign independent-binomial uncertainty to panels sharing donor covariance.
Sparse-unit tables separate undefined observations, required-deletion failures,
invalid covariance, insufficient pivots, failed delivery gates, and deliveries.

The complete protocol is `data-raw/calibration-04/README.md`, also included as
`inst/validation/calibration-study-04-protocol.md`. Use the full source archive
for research scripts; standard R source tarballs exclude `data-raw`. Exact study
reproduction pins the supplied **0.0.7.9000** public engine in a separate R
library. The current **0.0.8.9000** package has identical public computational
R code and exports. The study helpers are not newly exported confidence APIs.

The completed independent replication covered **377/400 (94.25%)** E006/null40
targets and **379/400 (94.75%)** E003/null160 targets. Neither selected deficit
replicated under the frozen test criterion; this is not an equivalence result.
Frame refitting changed no candidate coverage decisions. Regular movement
remained detectable, but only **8/120** sparse panels delivered a candidate
region. See `inst/validation/calibration-study-04.md` for covariance diagnostics,
movement controls, full failure accounting, and numerical validation. The
confidence-region release gate remains closed pending broader robustness.

## Study 05 design freeze: robustness evaluation pending

The next robustness design reserves **31 cells, 1,640 panels, and 326,360
bootstrap draws** across retention-boundary eigengaps, three anchor-change
amplitudes, movement controls, AR(1) unit-dependence stress, and sparse support.
The executable generator, analytic targets, reserved streams, engineering tests,
and failure-accounting contract are frozen under `data-raw/calibration-05/`.

**No reserved study05 evaluation data have been generated.** Its runner and full
analysis implementation require a separate implementation freeze before execution.
The declared-anchor and clean-anchor targets are distinct; correlated-unit cases
deliberately stress the unchanged iid bootstrap. Exact eigenvalue boundary ties
are analytic identification fixtures, not calibration panels. See
`inst/validation/calibration-study-05-protocol.md` and
`inst/validation/calibration-study-05-analysis-contract.md` for the full contract.
