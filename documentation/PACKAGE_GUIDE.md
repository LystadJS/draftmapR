# driftmapR: verified command guide

This guide describes the actual **0.0.8.9000** public API: **10 exported functions and three S3 methods**. The repository is named `LystadJS/draftmapR`; the R package and library name are `driftmapR`.

The package aligns repeated **two-dimensional** maps, measures movement relative to the alignment reference, matches supplied cluster labels, and performs a specific paired-measurement-unit bootstrap. It remains a development prototype. It does not provide calibrated confidence regions or significance tests.

## Verification performed on 2026-10-28

- Native Windows R 4.5.3: **2,619 expectations in 147 test blocks**, zero failures, errors, warnings or skips.
- All **nine manual topics containing executable examples** passed. Two other topics contain no example code; they were not counted as executed examples.
- A fresh installed-package [runnable tour](package-tour.R) exercised all 10 exports and `print()`, `summary()` and `plot()` methods. It recovered a known one-unit movement, agreed across PCA and classical-MDS workflows, rendered plots, and completed 20/20 illustrative bootstrap attempts.
- An independent 100-case randomized rotation/reflection/translation/scale experiment produced maximum spurious aligned drift **7.85e-15**, below the declared 1e-9 tolerance.
- `R CMD check --as-cran --no-manual`: **0 errors, 0 warnings, 1 NOTE**. The NOTE concerns the prototype maintainer placeholder/new-submission metadata and development version. Tests, examples, vignette building and vignette rebuilding passed. A PDF manual was not built because LaTeX was unavailable.

These checks establish observed engineering behavior on the exercised cases. They do not prove correctness for every possible input, guarantee inferential coverage, or establish CRAN readiness. Full logs and results are under [`validation/2026-10-28/package-api`](../validation/2026-10-28/package-api/). No frozen study or recovery artifact was modified to run these checks.

## Install and find help

Clone the repository, then start R in its top-level directory:

```sh
git clone https://github.com/LystadJS/draftmapR.git
cd draftmapR
```

```r
install.packages(c("ggplot2", "clue"))
install.packages("driftmapR", repos = NULL, type = "source")
library(driftmapR)
packageVersion("driftmapR")
getNamespaceExports("driftmapR")
help(package = "driftmapR")
?align_snapshots
args(bootstrap_drift)
```

R >= 4.1.0 is required. This is a source-directory installation, not a CRAN installation. `clue` has compiled code; compatible binary dependencies avoid needing a compiler on Windows. Installing directly from the source directory does not necessarily build HTML vignettes; the `.Rmd` files remain available in `driftmapR/vignettes/`, and `R CMD build` builds them when knitr, rmarkdown and Pandoc are available.

Run the tested complete tour from the repository root:

```sh
Rscript documentation/package-tour.R tour-output
```

It creates plots, movement and cluster tables, bootstrap tables, an RDS example fit and an invariance-check table in a new output directory.

## A complete coordinate workflow

Each row represents one entity in one period. `entity` and `time` are required; the default coordinate names are `x` and `y`.

```r
library(driftmapR)

first <- data.frame(
  entity = letters[1:5], time = 1,
  x = c(0, 3, 0, 2, 1), y = c(0, 0, 3, 2, 1)
)
truth <- first
truth$time <- 2
truth$x[5] <- truth$x[5] + 0.8
truth$y[5] <- truth$y[5] + 0.6

# Obscure the second map with an arbitrary coordinate transformation.
rotation <- matrix(c(0, 1, -1, 0), 2, byrow = TRUE)
second <- truth
second[c("x", "y")] <- sweep(
  as.matrix(truth[c("x", "y")]) %*% rotation, 2, c(7, -4), "+"
)

map <- drift_data(rbind(first, second), periods = 1:2)
validate_drift_data(map, check_overlap = TRUE, anchors = letters[1:4])
fit <- align_snapshots(map, anchors = letters[1:4])
movement <- measure_drift(fit)
movement
stopifnot(abs(movement$distance[movement$entity == "e"] - 1) < 1e-10)

print(fit)
summary(fit)
distance_to_anchor(fit, "a")
plot_drift_map(fit, labels = TRUE)
```

The known stable anchors have approximately zero movement; entity `e` moves one unit. In real data, anchor stability is an assumption supplied by the analyst. The package does not discover or certify stable anchors.

## Every exported function

### 1. `drift_data()` — construct the map object

```r
drift_data(data, periods = NULL, coords = c("x", "y"),
           original_data = NULL, embedding_metadata = list())
```

- `data`: a data frame with `entity`, `time` and exactly two selected coordinate columns. Extra metadata columns are retained.
- `periods`: the full expected schedule. Numeric and date-like times otherwise sort automatically; character times require an explicit order. All declared periods must occur somewhere in the data.
- `coords`: names of the two input coordinate columns; stored coordinates use canonical `x` and `y` names.
- `original_data` and `embedding_metadata`: optional retained information. Supplying these manually does not turn coordinate-only input into a supported bootstrap recipe.

Returns an unaligned S3 `<driftmap>` list. Duplicate entity-period keys, blank/missing IDs, or missing/nonfinite coordinates are rejected. Individual entities may be absent from some periods.

```r
map <- drift_data(rbind(first, second), periods = 1:2)
map$coordinates
map$settings$periods
```

### 2. `validate_drift_data()` — validate structure and geometry

```r
validate_drift_data(object, check_overlap = FALSE,
                    reference = c("previous", "first"),
                    anchors = NULL, rank_tol = 1e-10)
```

Returns the object invisibly if valid; otherwise raises an error. `check_overlap = TRUE` checks whether the specified reference and anchors permit identifiable alignment, including shared counts, noncollinearity and cross-covariance rank. `rank_tol` must lie strictly between zero and one.

```r
validate_drift_data(map, check_overlap = TRUE, reference = "previous",
                    anchors = letters[1:4])
```

### 3. `align_snapshots()` — remove coordinate-frame differences

```r
align_snapshots(object, reference = c("previous", "first"),
                scale = FALSE, anchors = NULL, rank_tol = 1e-10)
```

- `reference = "previous"`: align to the already aligned previous period. This may accumulate reference drift.
- `reference = "first"`: align every period to the first; adequate overlap with that first period is required.
- `scale = FALSE`: preserve coordinate units. `TRUE` also removes isotropic size differences and may absorb real expansion/contraction.
- `anchors = NULL`: fit using all shared entities. Otherwise use only shared members of the supplied character vector of IDs.
- Rotation, reflection and translation are allowed. At least three noncollinear fitting entities and full-rank cross-covariance are required.

Returns an updated `<driftmap>` with `$aligned` and `$transformations`. Transformations include rotations, translations, scale, determinant, RSS, RMSE, conditioning and fitting IDs. All points, including entrants, receive the fitted transformation. Raw coordinates remain unchanged. Re-aligning starts from raw coordinates and clears stored movement/bootstrap output.

```r
fit <- align_snapshots(map, reference = "previous", anchors = letters[1:4])
fit$transformations[c("time", "reference_time", "n_matched", "rss", "rmse")]
fit$transformations$rotation[[2]]
fit$transformations$translation[[2]]
```

### 4. `measure_drift()` — calculate adjacent displacement

```r
measure_drift(object)
```

Requires an aligned object. Returns a data frame with `entity`, `time_from`, `time_to`, `x_from`, `y_from`, `x_to`, `y_to`, `dx`, `dy` and `distance`. Distance is `sqrt(dx^2 + dy^2)` per interval, not speed. It is reference-relative geometric displacement, not a significance test.

Only immediately adjacent scheduled observations of the same entity are compared; missing observations are never bridged. Input metadata is not automatically joined into the movement table.

```r
movement <- measure_drift(fit)
movement[order(movement$distance, decreasing = TRUE), ]
fit$movement <- movement  # Optional explicit storage; the function does not mutate fit.
```

### 5. `distance_to_anchor()` — measure distance to a reference point

```r
distance_to_anchor(object, anchor)
```

`anchor` is either an entity ID present in every period or a finite numeric pair `c(x, y)` in aligned coordinates. Returns `entity`, `time`, `x`, `y`, `anchor_x`, `anchor_y` and `distance`.

```r
distance_to_anchor(fit, "a")
distance_to_anchor(fit, c(0, 0))
```

This measurement anchor is distinct from alignment fitting `anchors`. An entity used for distance measurement may move. Adjacent distance changes and uncertainty are not computed automatically.

### 6. `match_clusters()` — track supplied cluster labels

```r
match_clusters(object, cluster = "cluster", min_overlap = 1L,
                min_jaccard = 0, noise = NULL, diagnose_ties = TRUE)
```

Requires a supplied label column; it does not fit clusters. Alignment is optional. It maximizes shared-member overlap counts under one-to-one matching between adjacent periods.

- `cluster`: metadata-column name.
- `min_overlap`: positive integer minimum shared-member count.
- `min_jaccard`: candidate eligibility threshold in `[0, 1]`; denominators use entities present and assigned in both periods.
- `noise`: labels to exclude, such as `noise = 0`. Neither zero nor minus one is automatically excluded. Missing labels are unassigned.
- `diagnose_ties`: compute objective-loss margins. `FALSE` saves assignment work but leaves those diagnostics unknown (`NA`).

Returns an updated object with `$clusters` containing original labels, stable IDs (`C0001`, etc.) and status. Inspect `$diagnostics$cluster_matching` for registries, assignments, positive flows, overlap matrices and ambiguity. New/unmatched groups receive new IDs; identities do not revive across gaps. Split/merge candidate flags describe flows and can also arise from ordinary switching; they are not a probabilistic event model. Recomputing cluster identities clears stored bootstrap output.

```r
labels <- data.frame(
  entity = rep(letters[1:6], 2), time = rep(1:2, each = 6),
  x = rep(c(0, 1, 0, 4, 5, 4), 2), y = rep(c(0, 0, 1, 0, 0, 1), 2),
  cluster = rep(c("A", "B", "renamed_2", "renamed_1"), each = 3)
)
matched <- drift_data(labels) |> match_clusters()
matched$clusters
matched$diagnostics$cluster_matching$assignments
matched$diagnostics$cluster_matching$transitions
```

### 7. `embed_snapshots()` — construct maps from measurements or distances

```r
embed_snapshots(data, features = NULL, method = c("pca", "cmds"),
                periods = NULL, standardize = c("none", "first", "pooled", "period"),
                feature_weights = NULL, negative_eigen = c("error", "truncate"),
                eigen_tol = 1e-10)
```

For feature input, provide a long data frame with entity/time keys and explicitly select at least two numeric finite feature columns. Each period requires at least three entities and effective rank two. Both adapters center each snapshot. No values are imputed.

- `method = "pca"`: centered SVD scores. `"cmds"`: classical MDS.
- `standardize`: no SD scaling (`"none"`), first-period SDs, pooled entity-time SDs, or separate period SDs. Period scaling can absorb genuine dispersion change.
- `feature_weights`: nonnegative finite weights applied via square roots, without normalization. Named weights must match features exactly. Integer weights reproduce repeated feature columns.
- `negative_eigen`: for MDS, reject materially negative eigenvalues by default; `"truncate"` explicitly accepts an approximate representation with warnings/diagnostics.
- `eigen_tol`: relative spectral tolerance in `(0, 1)`. A tie at the second/third eigenvalue boundary warns because the selected plane is ambiguous.

Returns a new unaligned `<driftmap>` retaining original inputs, preprocessing, fits and spectra. Inspect `$diagnostics$embedding` and `$embedding_metadata`. Stored PCA models act on preprocessed/weighted features; do not call `predict(model, raw_data)` without applying that recipe.

```r
features <- rbind(first, truth)
names(features)[3:4] <- c("f1", "f2")
features$f3 <- 2 * features$f1
features$f4 <- 2 * features$f2
feature_names <- paste0("f", 1:4)

pca_fit <- embed_snapshots(features, feature_names, method = "pca") |>
  align_snapshots(anchors = letters[1:4])
mds_fit <- embed_snapshots(features, feature_names, method = "cmds") |>
  align_snapshots(anchors = letters[1:4])
measure_drift(pca_fit)
pca_fit$diagnostics$embedding
```

Classical MDS also accepts an ordered list of labeled `dist` objects or symmetric zero-diagonal dissimilarity matrices. Entity labels must be unique and row/column order must agree. Feature preprocessing arguments do not apply to distance input.

```r
distance_input <- lapply(split(features, features$time), function(d) {
  x <- as.matrix(d[feature_names])
  rownames(x) <- d$entity
  dist(x)
})
names(distance_input) <- c("before", "after")
distance_fit <- embed_snapshots(distance_input, method = "cmds") |>
  align_snapshots(anchors = letters[1:4])
```

### 8. `paired_unit_design()` — declare what may be resampled

```r
paired_unit_design(units, assumptions, strata = NULL)
```

`units` is a named character vector mapping every feature to a measurement-unit ID. Units must have equal numbers of features and there must be at least two units. `assumptions` is a nonblank substantive statement of independence/exchangeability; the package records it, but cannot validate it. Optional `strata` maps each unit ID to a stratum; sample counts within strata are retained and singleton strata are fixed.

Returns a `<driftmap_bootstrap_design>` declaration. A sampled unit's multiplicity is applied across all entities and periods, retaining temporal pairing and within-unit dependence. Arbitrary feature names do not imply exchangeability.

```r
design <- paired_unit_design(
  c(f1 = "A", f2 = "A", f3 = "B", f4 = "B"),
  assumptions = "Illustrative independent measurement blocks; not an empirical sampling claim."
)
```

### 9. `bootstrap_drift()` — refit paired measurement units

```r
bootstrap_drift(object, design, B = 999L, seed = 1L,
                preprocess = c("refit", "fixed"), keep = c("summary", "replicates"),
                probs = c(0.025, 0.5, 0.975), min_success = 0.95)
```

The object must be aligned and originally created by `embed_snapshots()` from feature data with all observed feature weights equal to one. Coordinate-only and distance-only maps are unsupported. The design must cover the original features exactly.

- `B`: attempted draws, including failures. Failed draws are recorded, never replaced.
- `seed`: nonnegative integer; planned L'Ecuyer-CMRG streams preserve caller RNG state and prefix reproducibility.
- `preprocess`: refit the declared recipe or use observed scale vectors. Embeddings are refitted in both modes.
- `keep`: summaries only, or retained replicate coordinates and movement. Plans/failures/diagnostics are always kept; summary mode still temporarily stores successful draws for exact quantiles.
- `probs`: unique increasing probabilities in `[0, 1]` for descriptive quantiles.
- `min_success`: minimum success fraction; at least two successes are also needed. Failed gates retain counts and return `NA` summaries.

Returns the object with a `$bootstrap` list. Start with a small pilot:

```r
result <- bootstrap_drift(pca_fit, design, B = 20, seed = 20261028,
                          keep = "replicates", min_success = 0.95)
result$bootstrap$attempts           # Every success/failure and its stage
result$bootstrap$warnings
result$bootstrap$summary            # Observed values, means, SDs, covariance, counts
result$bootstrap$quantiles          # Descriptive sample quantiles
result$bootstrap$coordinate_summary
result$bootstrap$replicates
result$bootstrap$settings
result$bootstrap$provenance
```

The tour's 20 attempts all succeeded. That tiny illustrative run is not an adequate uncertainty study. Summaries are conditional on successful computation; MCSE columns concern simulated means, not inferential SEs for the observed estimator. A positive lower quantile of a distance norm is not evidence of movement. There is no public calibrated confidence-region, p-value, cluster-stability or direction-inference API.

### 10. `plot_drift_map()` — plot positions and trajectories

```r
plot_drift_map(object, aligned = TRUE, trajectories = TRUE, labels = FALSE)
```

Returns a customizable ggplot. Default aligned plots require prior alignment; `aligned = FALSE` displays raw maps for comparison. `trajectories = FALSE` omits arrows. `labels = TRUE` labels latest observed positions; overlapping labels may be omitted. Arrows only connect adjacent scheduled observations, never gaps. Equal axis scaling preserves geometry.

```r
p <- plot_drift_map(fit, labels = TRUE)
p + ggplot2::theme_minimal()
ggplot2::ggsave("drift-map.png", p, width = 7, height = 5, dpi = 150)
plot_drift_map(map, aligned = FALSE)
```

## The three S3 methods

| Call | Result |
|---|---|
| `print(fit)` | Prints entity/period counts, alignment status and available cluster identity counts; returns the object invisibly. |
| `summary(fit)` | Returns a list of counts, periods, settings, alignment diagnostics and cluster-matching period summaries. |
| `plot(fit, ...)` | Delegates to `plot_drift_map()` and returns a ggplot; plotting options pass through `...`. |

There are no `tidy()` or `augment()` methods in the current namespace.

## Inspect and save results

| Object component | Contents |
|---|---|
| `$coordinates` | Original canonical coordinates and retained metadata |
| `$aligned` | Transformed coordinates, after alignment |
| `$transformations` | Explicit maps and fit diagnostics |
| `$settings` | Schedule and analysis choices |
| `$diagnostics` | Embedding and cluster-matching diagnostics |
| `$original_data`, `$embedding_metadata` | Retained feature/distance input and fitted recipes |
| `$clusters` | Stable IDs and original supplied labels, after matching |
| `$movement` | Initially NULL; optionally assign `measure_drift()` output |
| `$bootstrap` | Resampling output, after bootstrap |

```r
write.csv(measure_drift(fit), "movement.csv", row.names = FALSE)
saveRDS(result, "driftmap-fit.rds")
restored <- readRDS("driftmap-fit.rds")
```

## Interpretation and common mistakes

- Pure global translation/rotation/reflection can be removed; genuinely coherent whole-map movement is indistinguishable from a coordinate artifact without external constraints.
- Fitting all shared entities can absorb or redistribute real movement. Stable anchors define the reference assumption, not a verified truth.
- An entity missing at period 2 gets no movement estimate from period 1 directly to 3 when those are three scheduled periods.
- Supply an expected schedule to detect a wholly absent period. With no declared schedule, observed numeric times 1 and 3 are simply adjacent observed snapshots.
- Constant active features cannot be standardized; fewer than two identifiable dimensions or collinear alignment anchors cannot support the requested estimator.
- A two-dimensional truncation can discard meaningful structure. Alignment cannot restore lost dimensions or cure an ambiguous selected plane.
- Use `match_clusters()` before bootstrap if both are desired; matching again clears existing bootstrap results. Cluster matching describes supplied memberships, not fitted clusters or stability probabilities.
- Large bootstrap jobs are serial and can be expensive. Test a small `B` first and inspect attempts, failures and the summary gate before interpreting output.

## Roadmap names that do not exist yet

`cluster_stability()`, `plot_trajectory()`, `plot_cluster_transitions()`, `plot_drift_ranking()`, `tidy()` and `augment()` are not implemented public commands. Use `plot_drift_map()`/`plot()` for trajectories and ordinary data-frame operations for descriptive rankings. Consensus/generalized alignment, higher-dimensional maps, automatic cluster fitting, calibrated movement detection and specialized uncertainty plots are also absent. Research scripts under `data-raw/` are not additional supported package exports.
