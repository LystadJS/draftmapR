# Study 05 analysis, execution, and dependence-extension contract

Status: design frozen; full runner/analysis implementation and evaluation pending.
This is binding specification, not a claim that the following outputs already
exist. See README.md and the exported 31-cell case plan for immutable factors,
seeds, generators, estimands, and budgets.

## 1. Primary reporting and comparison rules

Report the studentized candidate first for E015, followed by E003 and E006;
report all five methods and all cells without outcome-based selection. No
cell/target is dropped because of weak sample geometry or low delivery. The
principal target is theta_D, the full functional under the declared anchors.
Clean-target inclusion means that a theta_D region contains theta_C; it must
never be relabeled calibration of the clean-anchor estimator.

For each cell, target, method, and estimator frame save:

- N_planned; N_observed_available; N_region_delivered; N_covered among deliveries;
  N_zero_excluded among deliveries; all exclusive non-delivery counts.
- Delivery=N_delivered/N_planned; conditional coverage=N_covered/N_delivered;
  covered-delivery yield=N_covered/N_planned; detected-delivery yield and
  conditional zero-exclusion rate, separately. A non-delivery is not evidence
  that its unobserved region would or would not cover.
- The principal delivery/yield above is **study-evaluable** delivery, consistent
  with the inherited evaluator. Separately report computational candidate
  availability. If the observed candidate exists in R0 but evaluation registration
  into A fails, subsequent work is operationally blocked: candidate interval
  delivery is unknown/NA, study-evaluable delivery is FALSE, and coverage is
  unavailable. Never count this unknown candidate as a demonstrated computational
  failure. Save actual observed-fit failures versus evaluation-only blocks as
  separate subcounts of the first non-delivery category.
- Pointwise Wilson 95% intervals and binomial outer-panel MCSE for those ordinary
  proportions, with numerator/denominator retained. Zero denominators return NA.
- Area, cutoff, covariance eigenvalues, and their mean, median, SD, 10th/90th/95th
  percentiles and maximum among available/delivered regions, with finite counts.
  No tail clipping or replacement of nonfinite geometry by a large finite value.
- Mean dx/dy error, error covariance, component/Euclidean RMSE against theta_D,
  all over explicitly counted finite observed estimates. Report the same
  point diagnostics against theta_C separately as target sensitivity.
- Clean-target inclusion, distance between population targets, and the actual
  nonzero population target norms in anchor-change/movement cells. A latent-stable
  label is not a whole-map-null declaration.

Cells use independent outer panels. Within a panel, methods, targets, and frame
controls share data and weights; these are paired comparisons, not independent
replications. Retain both-method delivery cross-tabs, discordant coverage flags,
and common-delivery area/cutoff log ratios. Paired MCSE is SD(panel differences)
divided by sqrt(number of paired panels); report denominators and conditioning.
Zero observed discordances give no proof of equivalence. Cross-cell contrasts
use independent-panel MCSE, never falsely paired dataset IDs. No formal test
family, equivalence margin, universal minimum m, or automatic release decision
is introduced. This bounded design can expose large failures but cannot certify
nominal coverage across applications.

Do not pool these panels with study01–04. The study04 opposite-half covariance
benchmark is not repeated in this smaller-cell design. No covariance correction
may be estimated from the outer results and fed back into the candidate.

## 2. Covariance and frame diagnostics

Use the common population chart A for repeated-panel error summaries. For each
case/target compute empirical covariance of finite observed errors. Compare the
mean bootstrap covariance and the mean observed jackknife covariance with it:
trace ratios, generalized eigenvalue ratios, eigenvectors/orientation where
identified, covariance variability, and finite sample counts. Generalized ratios
require a finite positive-definite denominator with eigenvalue ratio >1e-8;
otherwise emit unavailable status and the actual eigenvalues, without a ridge.
Each ratio uses a matched cohort in numerator and denominator: finite observed
error AND availability of the covariance being compared. Recompute the empirical
error covariance in that same cohort. Report the all-observed error covariance
separately; comparing a selected covariance numerator with an unmatched error
cohort would confound covariance behavior and failure selection.
These are descriptive repeated-experiment diagnostics, not covariance estimates
available to an application.

For uncertainty of covariance ratios, delete one OUTER panel at a time from the
same finite cohort, recomputing both numerator and denominator. Use ordinary
outer-delete-one jackknife SE. Retain failed diagnostic deletions; do not silently
remove them. With fewer than 20 eligible outer panels, or any required diagnostic
delete-one failure, report the descriptive ratio but its SE as unavailable.
Covariance availability, observed-estimate availability, and region delivery are
separate cohorts; save each cohort definition/count explicitly. No covariance
ratio is treated as proof of pivot normality or exact covariance shape.

Retain the unchanged study04 direct population-reference frame diagnostic:
each successful full fit and each successful required deletion is individually
registered to A before rebuilding its occurrence covariance and pivots. This
reuses eigenfits but is not one global rotation of all replicates. Core and
frame calculations share weights. Registration failures and blocked dependencies
have separate ledgers; a diagnostic cannot rescue or invalidate a core fit.
Compare point agreement, covariance traces, areas, cutoffs, coverage, and
registration-matrix variation. Freeze tolerances at 1e-9 for independent numerical
comparisons; scientific delivery tolerances remain those of the candidate.

Add a **clean-anchor observed-point diagnostic only**: for each generated panel,
fit its normalized observed Grams using the fixed eight anchors and direct
population chart A. Attempt this even when declared-anchor fitting fails if its
input Grams are available. Record its separate attempted/success/failed/blocked
status and compare it with theta_C. It never rescues a core interval. There is
no clean-anchor bootstrap or clean-anchor studentized region in this budget.
Clean-target inclusion by the declared-anchor region does not supply one.

## 3. Geometry diagnostics and selection

Retain both periods' complete population spectra and their actual lambda2-lambda3
gaps. For every attempted observed/full-bootstrap/required deletion embedding,
retain at least lambda1, lambda2, lambda3; relative gaps; rank/boundary status;
selected projector when computed for the requested diagnostics; and warning/error
stage. Spectral failure must not erase a finite spectrum that was obtained.
Compare sample top-two projectors with the corresponding population projector
using Frobenius distance, and save principal-angle summaries. Projector distance
measures plane changes independently of coordinate orientation. An exact-tie
population has no unique projector target and is outside sampled calibration.

Retain the two centered anchor singular values, their ratio, the two singular
values/ratio of the Procrustes cross-product, anchor residual sum of squares,
matched count, reflection indicator, and reference identity for each attempted
registration/alignment. Failed stages retain whatever earlier quantities were
available. If detailed per-deletion eigenvectors are too costly, store the
specified scalar gaps/projector distances and full stage ledger; retain full
matrices for physical audit panels. This changes storage, not fitting.

Prespecified observed-gap strata use min_t ((lambda2-lambda3)/lambda1): unavailable,
<=1e-10, (1e-10,.01], (.01,.05], (.05,.2], >.2. Anchor conditioning strata use the
minimum centered-anchor/cross-product singular-value ratio over attempted core
stages: unavailable, <=1e-10, (1e-10,.01], (.01,.1], >.1. These bins are diagnostics,
not gates, and are post-data conditional cohorts. Always show every bin and the
unstratified planned-panel total. Do not claim conditional-stratum nominal coverage
from small selected cohorts.

At the draw level compare planned, full-fit-successful, and pivot-valid subsets
by distinct units, maximum multiplicity, observed rare count/multiplicity in the
sparse arm, and available error norms. Use within-panel differences then an
outer-panel mean/MCSE; do not pool draws as independent observations. Error norms
for undefined fits are unavailable, not zero. Keep failures attributable to
spectrum, reference registration, temporal alignment, required deletions,
covariance, pivots, and final geometry distinct.

The sparse sentinel retains the fixed rare-count bins 0,1,2,3,4+ and the rank-only
mechanism benchmark from study04. Separately labeled relaxed-fraction-gate
summaries may be retained under the same minimum-20 and valid-covariance rules;
they must never replace the production denominator or change its gate. They
remain sensitivity diagnostics rather than calibrated intervals.

## 4. Complete ledger and execution invariants

Before fitting, materialize every planned job, seed, and B weight-vector slot.
Retain exactly 1,640 outer rows and 326,360 draw rows, plus three target/pivot
views per draw. Target rows are not independent fits. Preserve RNG states and
integer multiplicities for every planned draw, including panels whose observed
fit fails. No successful-fit redraws or outcome-adaptive budgets are allowed.

Every stage retains planned/required, attempted, successful, failed after attempt,
and unattempted counts. For a deletion, multiplicity >0 defines a required
unique computation; a positive multiplicity also gives its represented occurrence
count. Deletion scatter uses those occurrences, not distinct-unit count. Zero
multiplicity units cannot have attempted/successful deletions. All remaining
required deletions continue after a failure in an available parent.

For each ledger, verify required=attempted+unattempted and
attempted=successful+failed, both by unique computations and represented unit
occurrences. Store all stage/warning/error messages. Keep observed fitting,
evaluation registration, observed deletion, bootstrap full fitting, inner
deletion, covariance, pivot, and region statuses separate. The exclusive final
candidate reasons must match `study05_nondelivery()` exactly. Design-level
population eligibility never masquerades as an observed fit failure.

Infrastructure failures (process interruption, storage, serialization, corrupted
checkpoint) are not statistical fitting failures. Stop, preserve the event, and
resume the original job/seed where possible. A completed checkpoint is reused
only after source, plan, job, seed, and content identity checks. Atomic temporary
files are kept separate from completed checkpoints; stale partial files are
preserved with hashes. Do not label a study complete until every planned job has
a valid checkpoint or an explicit unresolved infrastructure record. A partially
executed study cannot be summarized as if its completed subset were the frozen
sample. Record unknown lost CPU work separately from statistical counts.

Default concurrency is up to eight independent outer workers, serial inner
refits, explicit RNG streams, and mc.set.seed=FALSE; a serial fallback uses the
same jobs/streams. Parallel schedules cannot define randomization. The numerical
fit count and occurrence budgets are separate from diagnostic registrations.

## 5. Required pre-execution implementation validation

The current freeze includes design/generator/contract tests. Before evaluation,
implement and lock the runner, collector, all analyses, diagnostics, figures,
mechanical validator, and physical audit code. All of the following are required:

1. Verify generator marginal covariance algebra, exact analytic gaps, fixed
   clean/declared anchors and movement definitions, stationary AR(1) recursion,
   RNG preservation, stream metadata checks, and evaluation-default refusal.
2. Use seed779/dataset999 fixtures only to test full estimator integration,
   weighted-occurrence/physical expansion equivalence, direct-A refits, clean
   observed-point comparisons, and unsupported-dependence labeling. Changing
   fixture B for engineering must never mutate the exported evaluation plan.
3. Inject unavailable observed fits, failed required deletions, singular
   covariances, nonfinite pivots, and failed diagnostic registrations. Verify
   full planned denominators, no early-stop deletion bias, and failure isolation.
4. Validate completeness and duplicate detection for all output products,
   diagnostic strata, tiny/zero denominators, covariance ratio SE cohorts,
   target-sensitivity labeling, and resumed checkpoint identity.
5. Test serial/parallel reproducibility on fixtures and snapshot public R source
   identity. Public PCA/classical-MDS adapter checks use matched feature counts
   and normalized coordinates; the spectral-boundary warning/rejection difference
   is preserved, not silently treated as numerical equivalence.

For the evaluation audit, reserve **dataset1 of every cell** (31 panels).
Audit all B public bootstrap weights/streams/statuses/full vectors. Physically
expand observed and first two bootstrap-parent occurrence jackknives in the
observed and direct-A frames, including explicit unavailable-parent records.
Retain complete deletion values for audit panels; retain their full spectra and
registration matrices. Public metadata for the dependent arm must label the
intentional iid misspecification honestly. Numerical disagreement is an
implementation discrepancy requiring preservation and diagnosis, not an excuse
to replace a panel or tune a tolerance. Exact sample-boundary discrepancies due
to the public warn/research reject rule are separately classified.

Mechanically reconstruct every retained covariance, pivot, region, success gate,
unique/occurrence ledger identity, and planned combination, including the
candidate-unknown versus evaluation-blocked distinction. Full scientific
conclusions require both numerical validation and honest coverage/delivery
results; successful software tests are not evidence of nominal confidence.

## 6. Future dependence-valid extension contract — not implemented

A subsequent dependent-unit method must specify, before calibration:

- the ordered unit axis and why its order is scientifically meaningful;
- the stochastic assumptions (stationarity/mixing or an explicit dependence model);
- the resampling unit containing all entities and periods, with preserved pairing;
- block construction (fixed, circular, stationary/geometric, or model-based),
  block length and how it is chosen without evaluating coverage, boundary/wrap
  handling, output-length truncation, and retained block/start-index plans;
- a dependence-valid observed and inner studentizer (such as a fully specified
  block jackknife or long-run covariance estimator), its deletion normalization,
  fitting/frame rules, failure gates, and relevant tuning parameters;
- population target, weak-identification restrictions, reproducible streams,
  full non-delivery accounting, null/movement cases, and an independent budget.

Do not attach block draws to the existing iid delete-one covariance and call the
result validated. Do not select a block length, effective-m adjustment, covariance
multiplier, or alternative region on this study's coverage. A future extension
requires its own specification, implementation freeze, and fresh evaluation.
