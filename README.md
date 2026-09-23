<div align="center">

# driftmapR

### Longitudinal alignment, correspondence, and movement for repeated low-dimensional representations

**When a map moves, did the system change?**

![R >= 4.1](https://img.shields.io/badge/R-%3E%3D%204.1-276DC3?logo=r&logoColor=white)
![Version](https://img.shields.io/badge/version-0.0.3.9000-65457E)
![Lifecycle](https://img.shields.io/badge/lifecycle-experimental-orange)
![License](https://img.shields.io/badge/license-MIT-8D1732)
![Status](https://img.shields.io/badge/status-active%20development-555555)

`driftmapR` aligns repeated low-dimensional maps through time, preserves cluster identity across periods, and measures entity-level movement after removing arbitrary coordinate-frame changes.

</div>

---

> [!IMPORTANT]
> **Development status:** this repository currently contains the executable **0.0.3.9000 prototype**. Alignment, movement measurement, PCA/classical-MDS adapters, supplied-label cluster correspondence, diagnostics, and descriptive plotting are implemented. Bootstrap uncertainty, inferential movement detection, cluster stability, and consensus/generalized alignment are development targets, not current package capabilities.

## Why `driftmapR`?

A PCA map, classical MDS configuration, latent-space representation, or other low-dimensional map is not a fixed coordinate system.

If the same underlying structure is estimated again later, the new coordinates may rotate, reflect, translate, or change isotropic scale even when the entities themselves have not meaningfully moved.

That creates the package's central problem:

> **Observed coordinate movement is not automatically substantive movement.**

`driftmapR` first establishes a defensible common coordinate frame and only then measures longitudinal change.

| Question | Current component |
|---|---|
| Did the coordinate frame move? | Orthogonal Procrustes alignment |
| Which entities moved after alignment? | Displacement and Euclidean movement |
| Did cluster labels merely change names? | Assignment-based correspondence |
| How trustworthy is the geometry? | Explicit fit, overlap, spectral, and ambiguity diagnostics |
| How uncertain is the estimated movement? | **Not yet implemented; resampling design is specified** |

## Where it fits

```mermaid
flowchart LR
    A[Repeated feature data] --> B[PCA or classical MDS]
    B --> C[Temporal alignment]
    H[User-supplied coordinates] --> C
    C --> D[Cluster correspondence]
    D --> E[Entity movement]
    E --> F[Diagnostics and interpretation]
    F -. future .-> G[Resampling and uncertainty]
```

`driftmapR` sits between **representation generation** and **longitudinal interpretation**. It is not intended to become a general dimensionality-reduction framework.

## Core statistical problem

For repeated coordinate matrices

\[
Z_t \in \mathbb{R}^{n_t \times 2},
\]

independently estimated coordinate systems are not directly comparable. For row-vector coordinates, orthogonal Procrustes alignment estimates

\[
R_t^*
=
\arg\min_R
\left\|
Z_{\mathrm{ref}} - Z_tR
\right\|_F^2,
\qquad
R^\top R = I.
\]

With translation and optional isotropic scaling,

\[
Z_t^* = s_t Z_tR_t^* + b_t.
\]

For entity \(i\), adjacent-period displacement and magnitude are

\[
\Delta_{it}=Z^*_{it}-Z^*_{i,t-1},
\qquad
D_{it}=\|\Delta_{it}\|_2.
\]

The core invariant is:

> **A pure coordinate transformation should not appear as entity drift after alignment.**

## Current capabilities

| Function | Purpose |
|---|---|
| `drift_data()` | Construct and validate repeated 2-D coordinate data |
| `validate_drift_data()` | Check object structure and optional alignment geometry |
| `embed_snapshots()` | Generate independent PCA or classical-MDS maps |
| `align_snapshots()` | Align maps to the previous or first period |
| `match_clusters()` | Match supplied hard-cluster labels across adjacent periods |
| `measure_drift()` | Compute adjacent-period displacement and movement magnitude |
| `distance_to_anchor()` | Measure aligned distance to an entity or fixed coordinate |
| `plot_drift_map()` | Plot aligned positions and adjacent movement |
| `print()`, `summary()`, `plot()` | S3 methods for `<driftmap>` objects |

### Alignment

The current engine supports:

- rotation and reflection;
- translation;
- optional isotropic scaling;
- `reference = "previous"` or `"first"`;
- changing entity sets;
- optional analyst-supplied stable anchors;
- rejection of insufficient, collinear, or numerically unstable overlap;
- retained transformations and fit diagnostics.

### Embedding adapters

Current adapters support:

- centered PCA;
- classical multidimensional scaling from features;
- classical MDS from labeled distance objects or dissimilarity matrices;
- explicit feature selection and weighting;
- several standardization conventions;
- retained preprocessing and spectral diagnostics.

### Cluster correspondence

`match_clusters()` treats period-specific labels as arbitrary identifiers and solves a one-to-one assignment problem using shared-entity overlap.

It retains:

- original labels;
- persistent bookkeeping IDs;
- assignments and unmatched states;
- overlap and Jaccard diagnostics;
- deterministic tie handling;
- candidate split/merge diagnostics.

These are descriptive correspondence diagnostics, not probabilities that two latent clusters are the same.

## Installation

The package is not on CRAN. In the current repository layout, the R package is stored in the `driftmapR/` subdirectory.

```r
install.packages("remotes")
remotes::install_github(
  "LystadJS/draftmapR",
  subdir = "driftmapR"
)

library(driftmapR)
```

Because the repository is currently private, GitHub authentication is required for installation from GitHub.

## Minimal workflow

This example creates a genuine one-unit movement for entity `e`, then applies a 90-degree rotation and arbitrary translation to the second raw map. Four known-stable entities define the fitting frame.

```r
library(driftmapR)

first <- data.frame(
  entity = letters[1:5],
  time = 1,
  x = c(0, 3, 0, 2, 1),
  y = c(0, 0, 3, 2, 1)
)

truth_second <- first
truth_second$time <- 2
truth_second$x[5] <- truth_second$x[5] + 0.8
truth_second$y[5] <- truth_second$y[5] + 0.6

rotation <- matrix(
  c(0, 1, -1, 0),
  nrow = 2,
  byrow = TRUE
)

raw_second <- truth_second
xy <- as.matrix(truth_second[c("x", "y")]) %*% rotation
xy <- sweep(xy, 2, c(7, -4), "+")
raw_second[c("x", "y")] <- xy

map <- drift_data(
  rbind(first, raw_second),
  periods = 1:2
)

fit <- align_snapshots(
  map,
  reference = "previous",
  anchors = letters[1:4]
)

movement <- measure_drift(fit)

movement
stopifnot(
  abs(movement$distance[movement$entity == "e"] - 1) < 1e-10
)

fit$transformations[
  c("time", "reference_time", "n_matched", "rss")
]

distance_to_anchor(fit, "a")
plot_drift_map(fit, labels = TRUE)
```

## Cluster correspondence example

```r
library(driftmapR)

first <- data.frame(
  entity = letters[1:8],
  time = 1,
  x = c(0, 1, 0, 1, 4, 5, 4, 5),
  y = rep(c(0, 0, 1, 1), 2),
  cluster = rep(c("A", "B"), each = 4)
)

second <- transform(
  first,
  time = 2,
  cluster = rep(c("Y", "X"), each = 4)
)

matched <- drift_data(
  rbind(first, second)
) |>
  match_clusters()

matched$clusters
matched$diagnostics$cluster_matching$assignments
```

Matching uses shared entity membership, not coordinate proximity, so cluster correspondence can be performed independently of Procrustes alignment.

## Interpretation guardrails

Alignment solves a geometric comparability problem. It does **not** create substantive comparability when the underlying data, preprocessing, entities, or measurement process are not comparable.

```text
Observed coordinate change
        |
        +-- coordinate-system artifact
        |      rotation / reflection / translation / arbitrary scale
        |
        +-- representation instability
        |      noise / preprocessing / truncation / weak dimensions
        |
        +-- relative structural movement
               change remaining after the chosen alignment
```

Important consequences:

- movement is relative to the chosen fitting frame;
- an entirely coherent global translation or rotation cannot be separated from coordinate artifact without external constraints;
- using moving entities to fit the transformation can absorb some genuine shared movement;
- `scale = TRUE` can absorb genuine expansion or contraction;
- previous-period alignment can accumulate reference-frame error;
- missing periods are not bridged and coordinates are not imputed;
- a nonzero displacement is not a significance test;
- cluster assignment margins are objective contrasts, not confidence measures.

## Validation and research status

The current source includes deterministic tests and synthetic validation scripts for geometry, embeddings, and cluster correspondence. The package remains a development prototype.

| Area | Current repository status |
|---|---|
| Repeated 2-D coordinate ingestion | Implemented |
| PCA adapter | Implemented |
| Classical-MDS adapter | Implemented |
| Previous-period alignment | Implemented |
| First-period alignment | Implemented |
| Changing entity sets | Supported |
| Stable-anchor fitting | Supported |
| Movement measurement | Implemented |
| Anchor distance | Implemented |
| Supplied-label cluster matching | Implemented |
| Descriptive plotting | Implemented |
| Bootstrap design specification | Documented |
| Bootstrap engine / intervals | **Not implemented** |
| Cluster stability under resampling | **Not implemented** |
| Consensus/generalized alignment | **Not implemented** |
| Automatic inferential movement detection | **Not implemented** |
| CRAN release | Not submitted |

The bootstrap specification deliberately rejects interpreting a positive lower percentile of a displacement norm as automatic evidence of movement. Any later inferential workflow must first define a defensible sampling design and demonstrate calibration.

## Repository guide

| Location | Contents |
|---|---|
| [`DESCRIPTION`](driftmapR/DESCRIPTION) | Package metadata and dependency contract |
| [`R/`](driftmapR/R/) | Package implementation |
| [`tests/testthat/`](driftmapR/tests/testthat/) | Unit and regression tests |
| [`vignettes/getting-started.Rmd`](driftmapR/vignettes/getting-started.Rmd) | End-to-end introduction |
| [`vignettes/embedding-adapters.Rmd`](driftmapR/vignettes/embedding-adapters.Rmd) | PCA and classical-MDS workflows |
| [`vignettes/cluster-correspondence.Rmd`](driftmapR/vignettes/cluster-correspondence.Rmd) | Cluster-label matching |
| [`inst/validation/methodology.md`](driftmapR/inst/validation/methodology.md) | Mathematical methodology |
| [`inst/validation/bootstrap-specification.md`](driftmapR/inst/validation/bootstrap-specification.md) | Planned resampling contract |
| [`inst/validation/landscape-review.md`](driftmapR/inst/validation/landscape-review.md) | Related methods and software |
| [`inst/validation/roadmap.md`](driftmapR/inst/validation/roadmap.md) | Development roadmap |
| [`data-raw/simulate-prototype.R`](driftmapR/data-raw/simulate-prototype.R) | Alignment/movement simulation |
| [`data-raw/simulate-clusters.R`](driftmapR/data-raw/simulate-clusters.R) | Cluster-correspondence simulation |
| [`data-raw/simulate-embeddings.R`](driftmapR/data-raw/simulate-embeddings.R) | Embedding simulation |
| [`NEWS.md`](driftmapR/NEWS.md) | Development history |

## Scope

### Current prototype

- repeated two-dimensional representations;
- PCA, classical MDS, or supplied coordinates;
- orthogonal Procrustes alignment;
- changing entity sets;
- analyst-supplied alignment anchors;
- cluster-label correspondence;
- displacement, movement magnitude, and anchor distance;
- descriptive plotting and diagnostics.

### Planned for later development

- bootstrap movement uncertainty and cluster stability;
- consensus/generalized alignment where statistically defensible;
- broader simulation calibration and failure accounting;
- richer trajectory, transition, and ranking plots;
- applied case studies;
- CRAN hardening.

### Deliberately deferred

- UMAP-specific adapters;
- graph-layout adapters;
- nonlinear manifold alignment;
- Bayesian posterior adapters;
- probabilistic split/merge models;
- GPU or distributed computation.

## Example applications

The package is domain-general. Potential uses include repeated maps of:

- organizations or institutions;
- countries or voting behavior;
- customers, brands, or products;
- ecological communities;
- survey or perceptual spaces;
- network latent positions;
- other repeatedly estimated low-dimensional systems.

UN voting is a possible flagship application, not a package assumption.

## Design principles

1. **Geometry before interpretation** — remove arbitrary coordinate-frame changes before discussing movement.
2. **Explicit estimands** — distinguish displacement, magnitude, anchor distance, and cluster correspondence.
3. **Visible limitations** — do not convert descriptive output into unsupported inference.
4. **Domain-general internals** — package APIs and tests should not depend on one application.
5. **Laptop-scale computation** — ordinary use should remain feasible without specialized hardware.

## Citation

Formal citation metadata will be finalized before a stable release. Until then, cite the repository and the exact package version or commit used in an analysis.

---

<div align="center">

### Geometry first. Movement second. Inference only when justified.

</div>
