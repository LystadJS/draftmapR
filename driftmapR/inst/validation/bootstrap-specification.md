# Bootstrap resampling specification

Design version 2; implemented subset reviewed 2026-09-11. The serial paired-unit
engine is implemented in version 0.0.4.9000. It returns conditional resampling
summaries with reproducible draws and complete failure accounting. Calibrated
confidence regions, significance tests, general data resamplers, and bootstrap
cluster stability remain unimplemented. Sections 1–5 define the statistical
design; sections 6–7 distinguish the executable contract and future extensions.

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
| Paired measurement units | Exchangeable columns or independent, equal-width blocks; identical multiplicities at every period | Implemented first built-in design; fixed entities, variation over sampled measurement units |
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

Two preprocessing modes are explicit in the paired-unit bootstrap API:

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
Report successful-draw summaries as conditional on computational success. The default
95% minimum-success gate suppresses summaries but cannot repair
selection bias, even above that threshold. Store all reasons. Failed boundaries
invalidate later chained results; the first implementation should mark that
replicate failed as a whole for a common denominator.

## 6. Executable interface and deferred extensions

Implemented paired-unit API:

```r
paired_unit_design(units, assumptions, strata = NULL)
bootstrap_drift(object, design, B = 999L, seed = 1L,
                preprocess = c("refit", "fixed"),
                keep = c("summary", "replicates"),
                probs = c(0.025, 0.5, 0.975), min_success = 0.95)
```

The current `design` is a `paired_unit_design()` declaration: named feature-to-unit
mapping, required scientific assumptions, and optional named unit-to-stratum
mapping. It covers the exact original feature schema. All blocks have equal
width; observed feature weights must equal one. Within-stratum sample counts
are fixed; singleton strata do not vary. Weighted base estimators and general
callbacks are deferred. The object must already contain a valid PCA/classical-MDS
feature embedding and temporal alignment. Preflight reconstructs the aligned
recipe in the observed baseline frame and rejects incompatible data or settings.

Future callback extension, not exported or implemented:

A callback design must contain a resampler plus sampling
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

## 7. Implemented execution and acceptance boundary

The draw plan uses one L'Ecuyer-CMRG stream per attempt. Streams advance from
the pre-draw state, so extending B preserves earlier draws and computational
failures cannot change subsequent random draws. Unit/stratum ordering uses
locale-independent radix sorting. One isolated base-R process creates the plan;
all embedding/alignment refits then run serially in the caller. This avoids
changing caller RNG state, including the Box-Muller cached normal value that
ordinary seed restoration cannot preserve. Stream and generator behavior follow
[R's stream documentation](https://stat.ethz.ch/R-manual/R-devel/library/parallel/html/RngStream.html)
and [R's RNG state documentation](https://stat.ethz.ch/R-manual/R-devel/library/base/html/Random.html).

Every attempt retains unit counts, feature multiplicities, its stream, success
status, stage/period, warning/error messages, and available fitting diagnostics.
Rank deficiency, alignment failure, or a second/third eigenvalue tie invalidates
the whole replicate. The observed recipe must also have an identified retained
plane. No partial boundaries are counted as successful. Original supplied cluster
correspondence remains unchanged; no bootstrap cluster stability is computed.

Movement summaries contain observed values, conditional means, sample SDs,
displacement covariance, and Monte Carlo SEs of replicate means. Coordinate
summaries include 2-D covariance. Type-7 sample quantiles are stored separately.
These are not confidence limits. Summaries require at least two successful
replicates and the selected success fraction. Otherwise target keys/counts
remain with NA estimates and explicit status. Unrepresentable summary moments
receive a per-target numerical-failure status without changing replicate counts.
A lowered threshold is an explicit choice to inspect a distribution conditional
on stronger selection; it does not fix that selection.

`keep = "summary"` omits raw coordinate/movement draws from the returned object;
exact quantiles still require temporary storage of successful draws. Draw plans,
diagnostics, and failure records are retained in either mode. A serialized-recipe
MD5 fingerprint, package/R versions, settings, and assumptions support auditing;
this fingerprint is not a security claim. General cross-platform bitwise
numerical equality is not promised.

The current tests and pilot verify execution, paired multiplicities, common
frames, RNG preservation, and failure accounting. Confidence-region coverage,
null rejection, power, and cluster stability remain future validation gates.


## Calibration study 01 evidence (2026-09-10)

The first bounded screening study is complete (480 independent datasets;
93,132 main attempts), but its candidates do not pass the inference acceptance
boundary. E015 whole-map-null coverage was 81.25% for both tested ellipses and
86.25% for the Euclidean error ball; there were no fit failures in that scenario.
Rare-axis selection affected both successful bootstrap unit composition and
which outer datasets passed the production gate. Thus computational success
and descriptive quantiles must remain distinct from calibrated inference.
See `calibration-study-01.md` and the unchanged frozen protocol. The next gate
is diagnosis and independent validation of regular-null vector uncertainty;
cluster stability and confidence exports remain deferred.


### Independent regular-null follow-up

The prespecified follow-up used 960 independent panels across 20/40/160/640
units and 399 fixed paired-unit draws per panel. Primary Wald coverage was
87.08/90.00/95.00/95.42%; all draws succeeded. Oracle baseline registration did
not remove small-unit undercoverage, and average covariance agreement alone
was insufficient. Population-tangent diagnostics use known population structure
and are not implementable uncertainty estimates for an unknown application.
See `calibration-study-02.md` for Monte Carlo intervals and limitations.

These findings do not change the implemented resampling contract or authorize
confidence labels for bootstrap summaries. The next inference milestone is an
explicit finite-unit studentized candidate for the full refitted estimator,
followed by an independent null-and-movement calibration with failure accounting.


## Study 03 finite-unit studentized candidate

The executable research candidate uses full paired-unit delete-one refits for the
observed covariance and for each full bootstrap estimate. Every baseline is
registered directly to the same observed reference; embedding and temporal
alignment are recomputed. For parent multiplicities w summing to m, delete one
occurrence and use S_J=(m-1)/m times the occurrence-weighted centered scatter.
Computing each distinct deletion once with weight w_j is exactly equivalent to
expanding the sample; distinct unit count does not replace m.

The joint ellipse is centered at the observed displacement with its jackknife
covariance. Its cutoff is the type-7 95th percentile of bootstrap quadratic
pivots, each using that bootstrap parent's jackknife covariance and displacement
minus the observed displacement. Covariances require eigenvalue ratio >1e-8;
there is no ridge, extra division by m or B, bias correction, or fitted inflation.
A failed required deletion invalidates the entire parent covariance. Production
delivery also requires at least 20 pivots and 95% of planned B valid pivots.

Study03 is frozen at 0ca7d5d298b9d12ebbef59788dc24f9866f09066 before fresh
measurements. It compares five methods on 800 null/movement/stress panels with
199 bootstrap plans each. See studentized-region-specification.md for the
mathematics, calibration-study-03-protocol.md for the complete contract, and
calibration-study-03.md for empirical results and the inference release gate.
The implementation is research code under data-raw/calibration-03; the package
still does not export a calibrated confidence-region function.

## Study 04 independent secondary-null replication

The unchanged candidate and gates were frozen at
f4e462a6e4d219ee80a7586c714b817a1ea6910c before 1,120 fresh panels and 222,880
planned draws. The independent primary endpoints covered 377/400 E006/null40
and 379/400 E003/null160 targets; neither rejected nominal coverage under the
frozen two-test family. Non-rejection does not establish equivalence or general
calibration. Direct population-frame refitting changed no candidate coverage
decisions, while covariance and finite-unit studentization remained relevant.

Regular movement remained detectable. Sparse production delivery was 8/120:
16 observed fits unavailable, 28 required observed-deletion failures, and 68
valid-pivot-fraction gate failures. The eight covered deliveries do not justify
confidence claims given strong selection, large regions, and zero detections.
Sparse frame diagnostics showed sensitivity in region size despite unchanged
coverage decisions. See calibration-study-04.md and its frozen protocol for
all denominators, diagnostics, and validation.

These results do not amend the resampling contract or promote a confidence API.
The next gate is independently frozen robustness across weaker eigengaps and
anchor contamination, with dependence violations explicitly separated from
nominal iid-unit calibration. Cluster refitting/correspondence uncertainty
follows the core robustness milestone; it must retain unavailable assignment mass.

## Study 05 robustness design freeze; evaluation pending

The study05 design reserves 31 cells, 1,640 panels, and 326,360 bootstrap draws
across retention-boundary eigengap weakening, graded shifts of three declared
anchors, movement controls, stationary AR(1) unit-dependence stress, and sparse
support. Its generator and accounting helpers passed 526 engineering assertions.
No reserved evaluation measurements or bootstrap weights have been generated.
The runner, collector, complete analysis, and audits require a separate validated
implementation freeze before executing the reserved plan.

The unchanged candidate targets the declared-anchor population functional.
The fixed clean-anchor functional and its inclusion by a candidate region are
separately labeled target-sensitivity diagnostics. Exact boundary ties are
analytic non-identification fixtures outside the sampled design. Correlated-unit
cases intentionally violate the iid resampling contract; their Gaussian Gram
variance-inflation diagnostic never replaces m in the candidate estimator.
Computational candidate availability and evaluation-only blocking remain distinct.
See calibration-study-05-protocol.md and calibration-study-05-analysis-contract.md
for the frozen analysis, dependence-extension requirements, and full accounting.
