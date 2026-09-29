# Study 04: independent replication of secondary null deficits

This is a prespecified research replication of the unchanged full-estimator
finite-unit jackknife-studentized joint region from study 03. The public package
engine and frozen studies 01–03 remain unchanged. No confidence API is promoted
by this study. This protocol, every scientific source, tests, analysis, and
validation are frozen by hashes and a UTC timestamp before generating fresh
measurement panels; a git commit records that freeze before execution.

## Questions and fixed design

Study 03's secondary studentized null coverage was 109/120 for E006 at m=40 and
110/120 for E003 at m=160. These selected observations motivate two independent
replications; they are not pooled with the new results or treated as established
deficits. The estimator, anchors, target order, region rules, and B remain fixed.

| Case | Paired units m | Independent panels M | Bootstrap draws B |
|---|---:|---:|---:|
| Regular null | 40 | 400 | 199 |
| Regular null | 160 | 400 | 199 |
| Regular movement | 40 | 100 | 199 |
| Regular movement | 160 | 100 | 199 |
| Rare-axis movement stress | 12 | 120 | 199 |

There are **1,120 planned panels and 222,880 planned bootstrap weight vectors**.
Targets are E015, E003, E006; each region is joint over two components of one
entity's displacement, with no simultaneous coverage claim. The two primary
replication endpoints are E006/null40 and E003/null160. All remaining endpoints,
method contrasts, and diagnostics are descriptive and reported in full.
Checkpoint `target_role` retains the study-03 metadata so core output remains
identical; exported tables add `study04_target_role` for this replication's
two primary endpoints. The protocol's declarations govern all new tests.

The unchanged generator has 18 fixed entities, two periods, three latent groups,
11 anchors E001:E005 and E007:E012, iid paired measurement units, Gaussian noise
SD 0.25, and across-period noise correlation 0.6. Movement is 0.2 times the
study-01 movement: latent E006 movement (0.09, -0.06), E013:E018 (-0.11, 0.08).
Rare-unit probability remains 0.15. Population truth is the full normalized
PCA/classical-MDS and temporal-alignment functional of the expected Gram
matrices, including sigma^2 H, rather than the bare latent movement. A latent
stable entity can have nonzero embedding displacement. Zero exclusion under
the whole-map null is type-I error; under nonzero population truth it is power.

Data streams use L'Ecuyer-CMRG / Inversion / Rejection, master seed **260929**, in
case-major, dataset-major order. Bootstrap seeds are **4400000 + 10000 times
case_index + dataset_id**. All streams and integer weight vectors are retained.
Eight outer workers use explicit streams and mc.set.seed=FALSE, serial inner
refits, and atomic checkpoints. Engineering fixtures use only seed **778** and
dataset **999**. No fresh study seed is evaluated before freezing. There are no
replacement panels, successful-fit redraws, outcome-dependent budget changes,
optional stopping, fitted inflation, threshold tuning, or post hoc primary cells.

At true 95% coverage and M=400, binomial Monte Carlo SE is 1.09 percentage points;
M=100 controls have 2.18-point SE. These are bounded studies, not certification.

## Unchanged candidate

See ../calibration-03/method-specification.md for the full definition. Every
observed, bootstrap, and required leave-one-occurrence fit recomputes both
embeddings and temporal alignment and registers the baseline directly to the
fixed observed baseline R0. For a parent with m sample occurrences and unique
unit multiplicities w_j, each positive unit is deleted once computationally,
its leaveout estimate d_(-j) represents w_j identical deletions, and

    d_bar = sum_j w_j d_(-j) / m
    S_JK = (m-1)/m sum_j w_j (d_(-j)-d_bar)(d_(-j)-d_bar)'

The leaveout Gram denominator is m-1. The occurrence count m is never replaced
by the number of distinct sampled units. A required failed deletion invalidates
the parent covariance; every remaining required deletion is still attempted.

For each valid bootstrap parent, T_b = (d_b-d_hat)' S_JK,b^{-1}(d_b-d_hat).
The observed ellipse uses S_JK,obs and the type-7 95th percentile of valid T_b.
The finite positive-definite covariance eigenvalue ratio must exceed 1e-8.
Delivery requires valid observed geometry, at least 20 valid pivots, and at least
95% of all B plans valid (190 of 199). No ridge, bias correction, or recentering
is introduced. Five unchanged paired methods are retained: bootstrap covariance
Wald, empirical Mahalanobis, Euclidean ball, jackknife-Wald, and studentized.
The first three gate on full bootstrap fits; jackknife-Wald has no bootstrap gate.

## Primary replication analysis

For each of the two fixed primary endpoints, compute an exact one-sided
binomial test of delivered-region coverage against 0.95, alternative less.
Bonferroni alpha is **0.025 for each of the two tests**, regardless of whether
another endpoint is untestable. If no region is delivered, the endpoint is
untestable, not a pass. The estimand is conditional coverage among deliveries;
every result also reports delivery and covered-delivery yield over all planned
panels. Failures cannot count as successful coverage. At 400 deliveries the
test rejects at at most 370 covered; non-rejection does not establish calibration.
The exact test and family adjustment follow the base-R definitions in
[binom.test](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/binom.test.html)
and [p.adjust](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html).

Report pointwise Wilson 95% intervals and binomial outer-panel Monte Carlo SE
for ordinary coverage, with the denominator explicit; include rejection rates,
area, cutoffs, bias, RMSE, and paired common-delivery method contrasts. Previous
counts are historical context only. Other method/target/frame contrasts are
exploratory descriptions without multiplicity-adjusted efficacy claims.

## Covariance and frame diagnostics

Compare bootstrap and observed jackknife covariance against the covariance of
repeated-panel full-estimator errors in the common population evaluation frame:
trace ratios, generalized eigenvalue ratios, and variability are reported.
Jackknife-Wald versus studentized holds observed covariance fixed and changes
the cutoff; bootstrap-Wald versus jackknife-Wald changes the covariance with
the same chi-square(2) cutoff. Neither comparison alone proves causation.

An unavailable-in-practice **fixed population-reference refit** is a paired
diagnostic. For each successful core fit, register that fit's aligned baseline
directly to population baseline A and rotate its displacement by that fit's
registration Q_b. Do the same separately for every successful required deletion,
then reconstruct the full occurrence jackknife and bootstrap pivots. Orthogonal
equivariance permits reusing the eigendecompositions, with independent physical
PCA checks. This differs from merely rotating all draws once by observed Q0.
Core and diagnostic observed point estimates, evaluated in A, must agree; their
resampling covariance and pivots may differ. Report paired coverage, covariance,
cutoff, area, and frame-rotation variation. Rigid transformations obey Q' S Q.

Oracle registration failures have separate ledgers and never invalidate a core
fit. If core fitting fails, the oracle registration is blocked and unattempted;
it is not an independent oracle-fit failure. This reused diagnostic therefore
covers the core-defined computational domain, not a separately rescued estimator.
Actual successful core leaveouts are registered even if the oracle parent or
observed registration fails; pivots still require an available observed oracle
point. Required unavailable registrations invalidate oracle covariance.

For the two regular-null cells only, a second unavailable diagnostic uses
**external empirical covariance with cross-fitting**. Split dataset IDs 1:200
and 201:400. Each panel uses the ordinary sample covariance of finite observed
full-estimator vectors from the opposite half, in A. Require at least 190 of 200
donors and the same finite positive-definite eigenvalue-ratio gate. Use the
chi-square(2) 95% cutoff with the original point estimate and truth; do not
estimate or tune inflation. Report both halves, donor counts, covariance trace
and eigenvalues, region counts, and coverage rates. The covariance remains
estimated from a finite donor sample, and a chi-square cutoff remains a shape
approximation. Because many panels share donor covariance, pooled indicators
are not iid: no pooled binomial CI, MCSE, or hypothesis test is assigned to
this diagnostic. It does not replace any candidate or primary analysis.

## Complete non-delivery and selection accounting

Preserve every planned panel, B full-fit plan, three target-specific pivot rows,
and each required deletion. Three target rows are not three independent fits.
Separate planned, attempted, successful, failed, and unattempted counts for
observed fits, full bootstrap fits, unique deletions, occurrence multiplicities,
covariances, pivots, and final delivery. Retain warnings and error messages.
For each candidate panel/target use mutually exclusive non-delivery precedence:

1. Observed estimate unavailable.
2. Any required observed deletion unavailable.
3. Observed covariance invalid.
4. Fewer than 20 valid pivots.
5. Valid fraction below 0.95.
6. Final region geometry unavailable.
7. Delivered.

For sparse units, report these counts by fixed observed rare-unit bins
**0, 1, 2, 3, 4+**, plus exact rare count in panel tables. Report conditional
coverage, delivery, covered-delivery yield, and clearly labeled relaxed-gate
selection diagnostics. A relaxed candidate never relaxes covariance validity
or the minimum count. Compare selected and rejected draw unit counts, rare
multiplicities, and available full-estimator error norms, using outer panels
as independent units for contrast uncertainty. Undefined full-fit error norms
cannot be observed and are explicitly missing, not zero. No inference about
conditional coverage is made from a tiny number of sparse deliveries.

A fixed rank-only mechanism benchmark accompanies the empirical counts. Given
r observed rare units, K resampled rare occurrences follow Binomial(12, r/12).
Full fitting needs K at least one; every required deletion needs K at least two.
Thus the rank-only valid-pivot probability is P(K >= 2), with observed r >= 2,
and the 190-of-199 delivery probability is its binomial upper tail. Averaging
over R distributed Binomial(12, .15) predicts about 5.85 deliveries among 120
panels before other geometric failures. This is a mechanism approximation,
not a fitted success threshold or a coverage claim.

## Validation and execution

The first two panels in each case are fixed public-engine audits (10 panels).
Compare all B public bootstrap weights, streams, statuses, and full vectors to
the core kernel. Physically expanded public PCA refits independently check
observed and first three bootstrap parent leaveouts in both references, using
vector/covariance tolerance 1e-9. Undefined audited panels retain explicit
unavailable/skip records. Inner deletion values are retained for all first-two
panels; other panels retain full ledgers, multiplicities, covariances, weighted
means, and scatter. The validator reconstructs every pivot, covariance relation,
region, gate, and accounting identity and independently expands retained values.
Package tests, examples, and available R package checks run before delivery.
Coverage is an outcome and never a software-test gate.

With the frozen public engine driftmapR 0.0.7.9000 installed, from the package
parent directory:

```sh
Rscript driftmapR/data-raw/calibration-04/test.R
Rscript driftmapR/data-raw/calibration-04/run.R calibration04-output 8
Rscript driftmapR/data-raw/calibration-04/validate.R calibration04-output 8
Rscript driftmapR/data-raw/calibration-04/analyze.R calibration04-output
```

The archive includes source, freeze, seed plan, checkpoints, full tables,
diagnostics, figures, audits, validation, and runtime provenance. This design
does not establish coverage for dependent units, arbitrary anchors, changing
entities, generic spectral instability, or simultaneous inference, and does
not supply an exact finite-sample theorem or release-ready confidence API.
