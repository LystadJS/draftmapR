# driftmapR

**Executable development prototype, version 0.0.3.9000.** Embed repeated feature
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

Alternatively install the supplied `driftmapR_0.0.3.9000.tar.gz` using
`install.packages("driftmapR_0.0.3.9000.tar.gz", repos = NULL, type = "source")`.
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

## Bootstrap design status

`inst/validation/bootstrap-specification.md` defines a **future**, fixed-entity
resampling workflow. Its first built-in design will draw exchangeable
measurement units or equal-width blocks with the same multiplicities across
periods, refit embeddings, establish a common baseline frame without scaling,
and repeat temporal alignment. A scientifically justified sampling design must
be supplied; ordinary fixed covariates are not automatically exchangeable.
Coordinate-only input does not supply a bootstrap model.

The specification also covers preprocessing conditioning, cluster refitting,
failed draws, reproducible RNG, and simulation calibration. It explicitly
rejects interpreting a positive lower percentile of displacement norms as
evidence of movement. `bootstrap_drift()` is **not implemented**; the adapters
and feature weights do not produce intervals or uncertainty estimates.

## Development and checks

From the parent of the source directory:

```r
install.packages(c("testthat", "roxygen2", "knitr", "rmarkdown"))
roxygen2::roxygenise("driftmapR")
testthat::test_local("driftmapR")
```

```sh
R CMD build driftmapR
R CMD check --no-manual driftmapR_0.0.3.9000.tar.gz
R CMD INSTALL driftmapR_0.0.3.9000.tar.gz
Rscript driftmapR/data-raw/simulate-prototype.R simulation-output
Rscript driftmapR/data-raw/simulate-clusters.R cluster-simulation-output
Rscript driftmapR/data-raw/simulate-embeddings.R embedding-simulation-output
```

HTML vignette building requires Pandoc. The packaged manual pages do not.
The `.github/workflows` check configuration targets Linux, Windows, and macOS
using [r-lib's standard actions](https://github.com/r-lib/actions/tree/v2/examples).
Remote CI has not run; no remote repository has been created or published.
`DESCRIPTION` deliberately uses a marked prototype maintainer placeholder;
replace it with verified author/maintainer details before public release.

## Not implemented

Consensus/generalized alignment; cluster fitting/stability;
bootstrap resampling and intervals; inferential detection; direction
uncertainty; anchor-distance change convenience output; higher dimensions;
specialized transition/ranking plots; applications; large simulation sweeps.
UMAP, graph-layout, and Bayesian adapters remain deferred.

The package is **not CRAN-ready or R Journal-ready**. The essential landscape
review in `inst/validation/landscape-review.md` documents existing alternatives;
`vegan` already covers much pairwise Procrustes functionality. This prototype
claims an integration workflow, not a new alignment method.

See `inst/validation/methodology.md`, `inst/validation/roadmap.md`, and the
getting-started vignette for implementation details and next milestones.
