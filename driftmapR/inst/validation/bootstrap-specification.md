# Bootstrap resampling specification

Design version 1; reviewed 2026-09-10. **Specification only:** this release does
not implement `bootstrap_drift()`, intervals, significance tests, or bootstrap
cluster stability. The PCA/classical-MDS adapters supply reproducible inputs and
fit metadata for the next implementation milestone.

## 1. Target and required design

The target is fixed-entity movement in a two-dimensional, population-derived
representation, relative to declared fitting entities, preprocessing, and
alignment rules. Coordinate rotation/reflection/translation are nuisance
degrees of freedom; global substantive movement in those directions is not
separately identifiable. Optional temporal similarity scaling removes another
degree of freedom. This specification is a package design, not a claim that a
generic bootstrap consistently estimates that target.

Every run must declare its sampling units, dependence structure, target,
availability conditioning, and preprocessing rule. Coordinates alone cannot
provide those declarations. Acceptable designs differ:

| Design | What varies | Interpretation and initial scope |
|---|---|---|
| Paired measurement units | Exchangeable columns or independent, equal-width blocks; identical multiplicities at every period | First built-in design planned; fixed entities, uncertainty over sampled measurement units |
| User data-resampler | Repeated observations or fitted measurement-model realizations | Planned extension; callback must preserve declared keys and temporal dependence |
| Entity-row bootstrap | Entities used to estimate a projection | Deferred; requires a fitted-projection target and prediction for every original entity, including omitted entities |
| Arbitrary coordinate jitter | Chosen perturbations | Sensitivity experiment only unless an explicit, validated observation model justifies it |

Fixed named covariates such as height and income are not automatically
exchangeable. Resampling them without a sampling model measures feature-choice
sensitivity, not measurement uncertainty. Similarly, copying supplied cluster
labels through draws cannot estimate clustering uncertainty. PCA bootstrap
methods already exist; their existence does not establish validity for this
package's fixed-entity longitudinal estimand.
[Fisher et al., original bootstrap-PCA research](https://arxiv.org/abs/1405.0922).

## 2. First built-in design: paired measurement units

Let each unit contain measurements for all observed entities and all periods.
Units are assumed independent and identically distributed, or independent and
identically distributed within declared strata with fixed stratum sample counts. Dependence
within a unit, including across entities and time, remains intact. For `m`
units, sample `m` unit indices with replacement once per replicate and reuse
that draw across every period. Equal-width blocks retain all their columns.
Unequal-width blocks, moving time blocks, and changing measurement schemas are
deferred until their weighting and population targets are specified.

Duplicate sampled columns are intentional multiplicities. The implemented
adapters can represent them exactly through `feature_weights`, applied as square
roots without normalization. Equal-width sampled blocks give their multiplicity
to every constituent feature. If columns are explicitly expanded, give each
occurrence a unique internal name and retain its original unit/feature ID. Never
deduplicate them. Keep the effective column count (sum of multiplicities) and
original coordinate units fixed. For
centered, unscaled features, the underlying moment is the entity Gram matrix
`X_t %*% t(X_t) / p`; the finite-`p` coordinate convention multiplies its leading
eigenvalues by the original `p`. This makes the sampling target explicit instead
of silently changing distances with the draw size. Standardized features define
a different moment and must record that choice.

Observed entity-time availability and the declared schedule remain fixed. Do
not fill absent entities, bridge gaps, resample periods, or infer a missingness
mechanism. Results are conditional on this availability pattern. Dependence
between separate units invalidates ordinary unit sampling; a scientifically
chosen block/model callback is required. Block size is not a cosmetic tuning
choice, and a short series of 2–20 maps alone does not justify a generic temporal
bootstrap. [Shao and Politis, block-bootstrap calibration](https://arxiv.org/abs/1204.1035).

## 3. Refit recipe and adapter requirements

Store original feature data or labeled dissimilarities; entity/time order;
feature names and order; retained dimension; complete preprocessing parameters;
and per-period fit/diagnostics. Do not infer a resampling design merely because
an adapter retained these inputs.

Two preprocessing modes will be explicit in the future bootstrap API:

- `refit`: recompute the same declared preprocessing recipe within each draw.
  If the recipe fits on the first period or a pooled population, recompute it
  there and apply it to all periods exactly as for the observed analysis.
- `fixed`: reuse observed preprocessing parameters; this targets uncertainty
  conditional on that calibration and must be labeled accordingly.

The embedding is refitted in either mode. With pure feature resampling and
unchanged values/rows, per-feature centering and scaling can coincide in these
modes; a measurement-model callback need not. Repeated features inherit the
correct occurrence-level calibration. Feature filtering, imputation, and
data-selected anchors cannot be silently held fixed while claiming full
pipeline uncertainty. They need an explicit conditional target or refit recipe.

PCA uses SVD, retains loadings, centering/scaling, component variances and rank.
Constant columns cannot be standardized. Signs of individual axes are
arbitrary. [R `prcomp` documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html).

Classical MDS rebuilds distances from each resampled feature matrix. A supplied
distance matrix requires an explicit resampler of its underlying observations
or a validated model; independently bootstrapping its cells is disallowed.
Retain its spectrum and negative-eigenvalue diagnostics. This release implements
no additive correction: materially negative eigenvalues error by default, with
warned positive-spectrum truncation available explicitly. Future correction
settings would need to be recorded and repeated. R's optional correction changes
the dissimilarities. [R `cmdscale` documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/cmdscale.html).

Centered PCA scores and classical MDS from the same Euclidean feature distances
must agree up to orthogonal transformation for an identified retained subspace;
this is a numerical cross-check, not a coverage argument. Record the gap between
the second and third eigenvalues: a near-tie at that boundary makes the selected
plane unstable. A tie inside the retained plane concerns orientation instead.
Bootstrap behavior around eigenvalue ties needs particular care.
[Hall et al., eigenvalue-bootstrap research](https://arxiv.org/abs/0906.2128).

## 4. Common reference frame and replicate pipeline

For every attempted replicate:

1. Draw data; validate keys, schedule, schema, finite values, and multiplicities.
2. Refit preprocessing and two-dimensional embeddings according to the recipe.
3. Fit the replicate's first map to the observed first map using a recorded,
   full-rank set of baseline entities. Apply translation and unrestricted
   orthogonal rotation/reflection, **without scaling**, to establish its frame.
4. Align later raw replicate maps to that replicate's aligned previous or first
   map using the observed temporal settings, including anchors and optional
   temporal scaling. Never align each later map directly to its observed
   counterpart; that changes the temporal estimator.
5. Measure adjacent displacement; optionally refit clusters and correspondence.
6. Save results or a structured failure record with replicate, stage, period,
   warning/error, overlap count, and available rank/spectrum diagnostics.

The baseline orientation step must also transform all baseline points. Its
entities default to the first-period intersection of the declared alignment
anchors, or all baseline entities if no anchors were declared; insufficient
rank/count is a failure. This extra step expresses vectors in an observed
coordinate convention; it does not recover absolute geographic or substantive
directions. Leaving replicate baseline orientation arbitrary creates spurious
component/direction uncertainty. Scaling this orientation fit would instead
remove genuine replicate size variation.

## 5. Summaries, cluster stability, and failure policy

Initially return replicate `dx`, `dy`, `distance`, coordinate covariance,
quantiles, valid/attempted counts, and failure rates as **resampling summaries**.
The norm is nondifferentiable at zero. Because bootstrap norms are normally
positive, a positive lower percentile of distance does not prove movement.
Do not implement that rule. Direction is undefined at zero and unstable near
zero; angular summaries require a recorded magnitude/identifiability gate.

Future inference should begin with displacement-vector regions calibrated in
simulation. Projection of a valid vector region onto the norm can then include
zero when appropriate. Simultaneous regions or multiplicity adjustment need a
declared family of entity-period comparisons; two separate marginal intervals
are not automatically a joint region. No automatic significance field or
confidence-coverage label is permitted before these choices pass calibration.

Cluster stability requires a refit callback with recorded settings and RNG.
Save both within-replicate temporal correspondence and same-period matching to
the observed labels. These answer different questions. Treat assignment ties,
unmatched groups, and noise/unclassified labels explicitly as unknown rather
than silently resolving them into certainty. Stability proportions retain
unknown mass and report all denominators; pairwise co-clustering is an optional
label-invariant diagnostic. Neither provides posterior membership probabilities
or probabilistic split/merge evidence.

Attempt exactly `B` draws; never redraw failures to reach a success quota.
Report successful-draw summaries as conditional on computational success. A
provisional 95% minimum-success gate may suppress summaries but cannot repair
selection bias, even above that threshold. Store all reasons. Failed boundaries
invalidate later chained results; the first implementation should mark that
replicate failed as a whole for a common denominator.

## 6. Proposed interface and acceptance gates

Nonexecutable API sketch, **not exported or frozen**:

```r
bootstrap_drift(object, design, B = 999L, seed = 1L,
                preprocess = c("refit", "fixed"),
                cluster_fun = NULL, keep = c("summary", "replicates"))
```

`design` must contain a resampler or declared unit/block mapping, sampling
assumptions, target, dependence handling, and conditioning statements. Callback
contract: `(original_data, replicate_id, settings)` returns validated replicate
data plus draw metadata; RNG is managed by the caller. Save seed, RNG kind,
per-draw streams, package/R versions, and recipe hashes; preserve caller RNG
state. Serial execution is the initial default. `B = 999` is a starting budget,
not a precision guarantee; report Monte Carlo precision and benchmark first.
Use small pilots and retain summaries by default; dense MDS has quadratic
storage and cubic eigendecomposition cost in entity count, so the full
1000-entity × 20-period target may need smaller exploratory budgets.

Before inference: test repeatability, multiplicities, dependence preservation,
PCA/MDS equivalence, arbitrary frame transformations, missing/new entities,
rank failures, and cluster ties. Run independent simulated datasets across
null/moving entities and clusters, noise, overlap, eigengaps, separation, and
misspecified dependence. Report bias/RMSE, region coverage, null rejection,
power, angular error, stability/ARI, failures, time, and memory. Calculate
Monte Carlo uncertainty at the independent-dataset level. Freeze each generator
and target before evaluation; a passing deterministic adapter test does not
constitute bootstrap validation.
