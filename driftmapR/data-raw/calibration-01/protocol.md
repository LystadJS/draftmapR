# Calibration study 01: frozen design

Protocol date: 2026-09-10. Study engine: driftmapR 0.0.4.9000, source commit
40278981ce680c64d758a00ef0191a2af0c6081f. This is a bounded screening study,
not certification of nominal confidence coverage or a package inference API.

## Aim and budget

Evaluate three prespecified nominal-95% joint displacement-vector regions and
quantify selection associated with failed bootstrap fits and the 95% success
gate. Run 80 independently generated datasets in each of six scenarios (480
outer attempts). Every observed-fit-valid dataset gets exactly 199 bootstrap
attempts; no failed outer dataset or bootstrap replicate is replaced. Maximum
main budget: 95,520 refits. PCA is the primary engine. Refit the first three
preselected datasets per scenario using classical MDS with identical draws as a
numerical-equivalence audit, not another independent coverage experiment.

The outer dataset is the independent Monte Carlo unit. E015 is the primary
entity-transition; E003 and E006 are prespecified secondary targets. At 80
independent datasets, binomial MCSE near 95% is about 2.44 percentage points,
before exclusions. No selection of methods/scenarios or threshold tuning after
inspection of calibration results. Implementation bugs may be corrected only
with a recorded amendment and unchanged scientific design.

## Data-generating mechanisms

All scenarios use 18 fixed entities, three groups of six, and two periods.
Baseline group centers are (-1.4,0), (1.3,0), and (0,1.6), with deterministic
jitter 0.3*(sin(1.7*k), cos(2.3*k)), k=1,...,18. Except in the whole-map null,
E006 moves by (0.45,-0.30) and E013:E018 move by (-0.55,0.40). Anchors are E001:E005
and E007:E012. All entities remain observed; overlap variation is outside this
first experiment.

| Scenario | Units m | Noise SD | Special design |
|---|---:|---:|---|
| regular_null | 40 | 0.25 | All latent positions unchanged. |
| regular_movement | 40 | 0.25 | Individual and group movement. |
| few_units | 12 | 0.25 | Same movement, fewer independent units. |
| high_noise | 40 | 1.00 | Same movement, larger measurement noise. |
| rare_axis | 12 | 0.25 | Rare second-axis signal/noise, probability q=0.15. |
| dependent_units | 40 | 0.25 | Cross-unit correlation 0.50; intentionally misspecified negative control. |

Each unit is one measurement column, paired across periods. In regular cases,
X_tj = Z_t l_j + sigma*epsilon_tj, with l_j ~ N(0,I2), shared across periods.
Entity errors are independent within a period and have correlation 0.6 across
periods for the same entity/unit. In the dependent-unit case, loadings and errors
combine shared and unit-specific Gaussian terms using square-root weights for
correlation 0.5. Marginal moments are unchanged but the independence assumption
of ordinary unit resampling is intentionally violated.

In rare_axis, X_tj = z_x,t*a_j + R_j/sqrt(q)*(z_y,t*b_j + sigma*epsilon_tj), with
independent standard-normal a_j,b_j and R_j ~ Bernoulli(q), paired across time.
The same marginal second moment is retained because E[R_j/q]=1. Omitting all
rare units removes both second-axis signal and noise, producing a genuine rank
failure. Record the observed rare-unit count K and rare-unit multiplicity in
every planned draw. The probability of omitting all rare units is (1-K/m)^m;
other numerical/identifiability failures are recorded separately. Failed
vectors are undefined and must never be imputed as zero.

## Estimand and evaluation frame

Use unstandardized, centered PCA and temporal previous-reference alignment with
scale=FALSE and the fixed anchor set. For each scenario and period, the exact
population centered Gram matrix is

G_t = m * (Z_ct Z_ct^T + sigma^2 H), H = I - 11^T/n.

Construct the leading two population coordinates from G_t and apply the same
temporal alignment functional. This is the population embedding target. It is
not simply sqrt(m)*Z_t when sigma>0. In moving scenarios a latent-stable entity
need not have zero population-embedding displacement; only regular_null is used
for null-rejection claims.

For each observed dataset, fit its baseline to the fixed population baseline
using anchors and an orthogonal transformation WITHOUT scaling. Rotate the
observed displacement and every bootstrap displacement by this SAME rotation.
Compare them with the fixed population displacement. Do not refit individual
bootstrap results directly to population truth. This evaluates registered
relative movement and includes sampling variation in the observed baseline
registration; it does not identify absolute physical directions.

Report bias/RMSE divided by sqrt(m) to keep population-moment coordinate units
comparable across scenarios. Candidate regions themselves use original embedding
units, with areas optionally divided by m for reporting.

## Frozen region candidates

Let d_hat be observed displacement, d_b successful bootstrap displacements, and
S their ordinary sample covariance (divisor n_valid-1, NOT S/n_valid). All
regions are centered at d_hat. At least 20 valid replicates are required.

1. Wald ellipse: (theta-d_hat)' S^-1 (theta-d_hat) <= chi-square_2(0.95).
2. Empirical Mahalanobis-error ellipse: replace the chi-square cutoff with the
   type-7 0.95 quantile of (d_b-d_hat)' S^-1 (d_b-d_hat). Errors are uncentered
   around d_hat; S remains fixed within the outer dataset.
3. Euclidean bootstrap-error ball: ||theta-d_hat|| <= the type-7 0.95 quantile
   of ||d_b-d_hat||.

The latter two are nonstudentized bootstrap-error regions, not bootstrap-t.
Ellipses are unavailable when min(eigen(S))/max(eigen(S)) <= 1e-8 or computed covariance is
nonfinite. Malformed/nonfinite input vectors are rejected explicitly; failed
draws must already be represented in the separate attempt ledger. A zero-radius ball is reported unavailable rather than treated as
certain coverage. These are evaluation candidates, not newly exported package
confidence procedures. Regions are joint in dx/dy for ONE entity-transition;
there is no familywise/simultaneous claim across entities or periods.

## Denominators and selection analysis

Evaluate every candidate under two fixed policies using the SAME saved draws:
relaxed (at least 20 successes and valid region geometry) and production
(additionally n_valid/199 >= 0.95). Production is the primary policy.

Retain counts for all outer attempts, observed-fit successes, bootstrap success,
region computability, and region delivery. Report:

- Conditional coverage and zero exclusion among delivered regions, with binomial
  MCSE and Wilson intervals at the outer-dataset level.
- Coverage-and-delivery divided by ALL outer attempts, labeled operational yield,
  not confidence coverage. Report region-delivery fraction separately.
- Observed vector bias/RMSE over all observed-fit-valid datasets versus the
  production-gate subset; no fabricated errors for observed-fit failures.
- In rare_axis, mean rare-unit multiplicity over all planned draws versus only
  successful draws, and original K before/after the production gate.
- Failure stages/reasons, observed and population eigengaps, runtime, and retained
  object size. These are selection contrasts, not identified causal effects.

Primary and secondary target results remain separate. Any across-target average
must first be formed within dataset before computing Monte Carlo uncertainty.
The study does not calibrate cluster stability, angle intervals, scale=TRUE,
first-reference chains, standardized features, data-selected anchors, changing
availability, or other population mechanisms.

## Execution safeguards and evidence

Dataset streams start from L'Ecuyer-CMRG seed 260915 (Inversion normals,
Rejection sampling) and advance with nextRNGStream in scenario-major order.
Bootstrap seed = 1400000 + 1000*scenario_id + dataset_id. Outer parallelism may
change scheduling only; each public bootstrap call retains its serial draw order.

Save the protocol and source hashes before calibration outcomes are generated.
Freeze generators, target construction, region formulas, seeds/streams, budgets,
and analysis rules. Verify helpers independently, including analytic Gram
moments and region rotation/scale invariance. Checkpoint every outer result with
its seed/stream and attempt ledger. Record actual completion and all failures;
no replacement or success-quota sampling. Numeric PCA/MDS equivalence is an
engineering check, not independent evidence of coverage.

Planning/reporting follows the original simulation-study guidance in
[Morris, White and Crowther](https://arxiv.org/abs/1712.03198). Candidate region
formulas above are fully specified for evaluation; no theoretical validity is
borrowed from a generic bootstrap reference.
