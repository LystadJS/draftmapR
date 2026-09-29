# Study 05: bounded eigengap and anchor robustness — DESIGN FREEZE

This freezes the design, data generator, seed allocation, engineering tests, and
analysis/failure-accounting contract. **No reserved evaluation panel has been
generated or analyzed. The study runner, result collector, and full analysis
implementation are the next implementation milestone.** Their code must be
validated on engineering fixtures and hash-locked before any reserved draw.
Neither implementation work nor its tests may retune this design.

The target remains the study03 full normalized PCA/classical-MDS and temporal
Procrustes estimator, with its occurrence-jackknife studentized joint region.
The study04 public engine is pinned at driftmapR **0.0.7.9000**; current package
0.0.8.9000 has identical public computational R code. Earlier studies, their
seeds, and their results are unchanged. The candidate is research code; this
study cannot by itself authorize a general calibrated confidence API.

## Motivation and scope

Study04's selected null deficits did not replicate under its fixed criterion
(E006/null40: 377/400; E003/null160: 379/400). That result is not an equivalence
finding. Its regular designs had small frame-refitting effects, while sparse
studentized delivery was only 8/120. This follow-up changes identifiable
population geometry and the anchor definition in prespecified ways, while
keeping the candidate, gates, and draw budget unchanged. Historical results
motivate this design; they will not be pooled with fresh observations.

For a leading two-dimensional eigenspace, the relevant retention-boundary gap
is lambda2 minus lambda3. A rotation within the selected plane does not remove
error from selecting a different plane. The dependence of subspace perturbation
bounds on this gap is supported by Yu, Wang, and Samworth's theorem 2
(https://arxiv.org/html/1405.0680v1). Exact lambda2=lambda3 leaves the selected
population plane nonunique: a deterministic numerical basis does not repair
that statistical target. Exact ties are analytic sentinels only, outside the
sampled calibration design.

## Fixed bounds

| Arm | Factors | Cells | Panels per cell | Planned panels |
|---|---|---:|---:|---:|
| Main iid grid | g=1,.1,.01; a=0,.25,.5; m=40,160; no focal movers | 18 | 60 | 1,080 |
| Movement controls | g=1,.01; a=0,.5; m=40,160 | 8 | 40 | 320 |
| Dependence stress | g=1,.01; m=40,160; a=0; no focal movers; rho=.5 | 4 | 40 | 160 |
| Sparse support sentinel | Unchanged rare-axis movement generator; m=12 | 1 | 80 | 80 |
| **Total** | **B=199 in every panel** | **31** | | **1,640** |

There are **326,360 planned paired-unit bootstrap weight vectors**, irrespective
of observed fitting failure. At most 156,960 observed leave-one-occurrence
requirements and 31,235,040 inner occurrence requirements arise; multiplicity
reuse reduces distinct computations but never changes the estimator's m.
All planned fits, including unattempted fits, remain represented in the ledger.
Runtime depends on hardware and failures; the statistical budget cannot change
in response to interim coverage or delivery. Interruptions may resume the same
jobs and streams; no failed panel or draw is replaced.

The main-grid cells with a=0 are whole-map nulls. **Cells with a>0 are anchor-change
cases, not whole-map nulls**, even when no focal mover is added. The dependence
arm has a whole-map null data target but violates the iid-unit resampling
contract. Combined anchor contamination and serial dependence, multiple
contamination fractions/directions, additional rho values, changing entity sets,
and higher embedding dimensions are outside this bounded design.

Nominal-coverage Monte Carlo SE is 2.81 percentage points for M=60, 3.45 for M=40,
and 2.44 for M=80, before conditioning on delivery. Those bounds support detection
of substantial robustness problems, not precise certification near 95%.

## Population geometry and changes

There are 18 fixed entities, two periods, and three latent groups, as before.
Let Z be the centered original study01 first-period two-dimensional layout and
let s1 >= s2 be the nonzero eigenvalues of Z Z'. Retain the original x/y axes
for all movement definitions; contamination does not depend on PCA sign choices.
Construct u3 by projecting sin(k sqrt(2))+cos(k sqrt(3)), k=1,...,18, off the
constant vector and both columns of Z, normalizing it, and fixing its largest
absolute component to be positive (first index breaks ties).

For signal-gap fraction g, define

    L1 = [Z, sqrt((1-g)*s2) u3].

The first-period population Gram is C1=L1 L1'+sigma^2 H, with sigma=.25 and
H=I-11'/18. Its signal-relative retention gap is g. The actual relative gap is
**(lambda2-lambda3)/lambda2 = g*s2/(s2+sigma^2)**. Save absolute gaps and relative
gaps normalized by lambda1 and lambda2 for both periods. Changes in period two
may alter its spectrum; the nominal g labels the baseline, not both periods.
No sample gap creates a new success gate.

Declared anchors remain E001:E005 and E007:E012. Three predeclared anchors,
**E002, E004, E008**, receive the coherent second-period shift

    a * sqrt(mean(rowSums(Z^2))) * (.6, -.8, 0).

The RMS is fixed from the original rank-two Z, so it does not increase with the
added third signal. The contamination fraction is 3/11; a changes displacement
amplitude, not fraction. The clean diagnostic anchors always exclude those
three entities, leaving the same eight anchors even at a=0.

In movement controls, also shift E006 by (.09,-.06,0) and E013:E018 by
(-.11,.08,0). Center the resulting L2 across entities. C2=L2 L2'+sigma^2 H.
For the sparse sentinel, use the unchanged study03 rare-axis model: q=.15,
m=12, movement_scale=.2, sigma=.25; its absent rare direction can make observed
or deleted fits unavailable. Its nominal g/a fields are not substantive factors.

## Generator and dependence contract

One unit contains its complete feature column across all entities and both
periods. For the Gaussian arms, draw three loading rows F and independent
first/innovation noise rows E1 and E2. Each row is iid across columns in the iid
arms. The same F is used in both periods, and temporal noise correlation remains
rho_time=.6:

    X1 = H (L1 F + sigma E1)
    X2 = H (L2 F + sigma (.6 E1 + sqrt(1-.6^2) E2)).

For dependence stress, **each row** of F, E1, and E2 is independently stationary
Gaussian AR(1) over ordered unit index j, with rho=.5, U1~N(0,1), and
Uj=rho U(j-1)+sqrt(1-rho^2) epsilon_j. This preserves every unit's marginal law,
so the expected Gram target stays unchanged, while units become dependent.
There is no random-intercept/common-shock substitution for this AR(1) design.

The candidate deliberately retains iid paired-unit draws and the same
occurrence jackknife. Its metadata must explicitly state that the AR(1) arm is
unsupported misspecification stress; the inherited study03 iid-generating-law
assumption string cannot be reused unmodified for these panels. Pairing across
periods remains intact; it does not preserve dependence across units.

For this zero-mean separable Gaussian model, the exact finite-m variance
inflation for Gram entries is

    VIF_Gram = 1 + 2 sum_{h=1}^{m-1} (1-h/m) rho^(2h).

Save m/VIF_Gram only as a Gram diagnostic. It is not an effective sample size
substitution for the nonlinear displacement estimator, its deletion denominator,
or region cutoff. No dependence correction or block-bootstrap support is
implemented by this study. The full future extension contract is in
`analysis-contract.md`; it must be frozen separately before any block-method
calibration. Official multivariate block-bootstrap options are documented at
https://stat.ethz.ch/R-manual/R-devel/library/boot/html/tsboot.html.

## Estimands and unchanged region

For each case, compute the top-two population representation of C1 and C2 and
apply the full alignment functional. A denotes the fixed population baseline
chart. The primary target theta_D uses the declared 11 anchors. The clean-anchor
target theta_C uses the fixed eight anchors, in the same A chart. Save both
three-target vectors and theta_D-theta_C. The latter is **anchor-definition
sensitivity**, not automatically isolated contamination bias. Embedding deformation
can affect a latent-stable entity's target even when its anchor membership is
unchanged. Coverage of theta_C by a theta_D region is target-sensitivity evidence,
not a test of calibration for theta_D.

Targets remain E015 (primary reporting target), E003, and E006. Each region is
joint over dx/dy for one entity, with no simultaneous cross-entity/time guarantee.
Use normalized Grams X X'/m; full observed, bootstrap, and required deletion fits
recompute both embeddings and temporal alignment. All candidate fits use the
same fixed observed baseline R0. For multiplicities w_j summing to m,

    dbar = sum_j w_j d_(-j)/m
    S_J = (m-1)/m * sum_j w_j (d_(-j)-dbar)(d_(-j)-dbar)'
    T_b = (d_b-dhat)' inverse(S_J,b) (d_b-dhat).

Each deletion removes one occurrence; leaveout normalization is m-1. Every
required deletion of an available parent is attempted. One required failure
invalidates that parent's covariance. The observed ellipse uses S_J,observed
and the type-7 95th percentile of valid T_b. Covariance minimum/maximum
eigenvalue ratio must exceed 1e-8. Delivery needs at least 20 valid pivots and
at least 95% of B=199 valid: **190/199**. Numerical spectral/anchor tolerances
remain 1e-10 in the research kernel. No ridge, effective-m substitution,
clipping, fitted inflation, reference selection, or post hoc gate is permitted.
The public adapter warns at boundary ties; the research kernel rejects them.
That existing difference must remain explicit in public audit comparisons.

## Analysis, diagnostics, and non-delivery

All results are **prespecified descriptive robustness evidence**. There is no
new significance-test family, equivalence test, outcome-based selection, or
automatic release rule. Report all cells, all three targets, and all five
paired methods: bootstrap-Wald, empirical Mahalanobis, Euclidean ball,
jackknife-Wald, and jackknife-studentized. Compare coverage, delivery, covered
and delivered yield, region size/cutoffs, bias/RMSE, and zero exclusion. Report
Wilson 95% intervals and outer-panel MCSE with each actual denominator; a zero
denominator means unavailable, never a successful result.

Covariance, per-fit population-frame, clean-anchor point, spectral, conditioning,
and failure-selection diagnostics are specified in `analysis-contract.md`.
Regions target theta_D; theta_C inclusion is separately labeled. Zero exclusion
is type-I error only for a whole-map null. Dependence-null exclusions are
misspecification stress results, not iid calibration. No sample eigengap or
anchor-condition threshold can remove panels from the principal denominator.

Use exhaustive study-operational non-delivery precedence:

1. Observed estimator/evaluation unavailable (retain separate fit and evaluation status).
2. Any required observed deletion unavailable.
3. Observed covariance invalid after successful deletions.
4. Fewer than 20 valid pivots.
5. Valid-pivot fraction below .95.
6. Final region geometry unavailable.
7. Delivered.

The inherited study evaluator blocks subsequent work if registration into A
fails, even when the observed candidate fit exists in R0. Retain separate
`observed_core_fit_available`, `evaluation_registration_available`, and
`evaluation_only_block` flags. In an evaluation-only block,
`candidate_region_delivered` is **NA (not computed)** and
`study_evaluable_region_delivered` is FALSE. Split the first reason into actual
observed-fit failure and evaluation-only blocking in the reported accounting.
Do not describe unavailable evaluation as demonstrated computational failure
of the candidate interval. The principal planned-panel yield is explicitly
study-evaluable yield; the separate candidate availability table retains unknowns.

Population target non-identification is a separate design-level status, never
an observed sampling failure. Exact-tie fixtures have no planned evaluation
panels and cannot enter a coverage denominator. Every planned positive-gap
case must pass deterministic population-target eligibility before freezing.
Sparse outcomes also retain rare-count bins 0,1,2,3,4+ and the exact count.
Full-fit and deletion failures, blocked attempts, covariance and pivot failures,
warnings, and computational interruptions are retained separately.

## Reproducibility and remaining implementation gate

Reserve L'Ecuyer-CMRG / Inversion / Rejection streams from master **261003**, in
the exact order exported by `study05_cases()` and then ascending dataset ID.
Bootstrap scalar seeds are **5400000+10000*case_index+dataset_id**. Reserve states
without generating measurements or bootstrap weights. Engineering uses only
seed **779**, dataset **999**, and explicit fixture metadata; it cannot be
included in study denominators. Generator defaults reject reserved evaluation
jobs. Any future explicit evaluation authorization is permitted only after the
runner, collector, full analysis, audits, and validation are hash-locked.

From the package parent directory, with the recorded public engine installed:

```sh
Rscript driftmapR/data-raw/calibration-05/test.R study05-test-evidence.rds
Rscript driftmapR/data-raw/calibration-05/plan.R calibration05-plan
# freeze.R creates immutable design records; it refuses an existing freeze.
Rscript driftmapR/data-raw/calibration-05/freeze.R study05-test-evidence.rds
```

`plan.R` exports only the case plan, reserved states, analytic population objects,
analytic eligibility/spectrum/anchor diagnostics, and bounds. There is no
study05 evaluation CLI in this design release. Follow-on implementation must
retain this frozen plan verbatim, complete the engineering/public audits listed
in the contract, freeze its own code, and only then execute reserved panels.
Any scientific design amendment must be named and separately frozen before
outcomes, with the original design retained. Coverage and delivery outcomes
are never software-test acceptance criteria.
