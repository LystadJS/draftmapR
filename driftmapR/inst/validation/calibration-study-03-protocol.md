# Study 03: finite-unit studentized joint regions

This directory contains an executable research implementation for the **full**
normalized PCA/classical-MDS plus temporal-Procrustes displacement estimator.
It is not a released confidence-region API. The public paired-unit engine and
studies 01 and 02 are unchanged. Read `method-specification.md` for the estimator,
occurrence jackknife, quadratic region, and limitations.

## Frozen independent design

This protocol is fixed before generating study-03 measurement panels. Technical
fixtures use seed 777 and dataset identifier 999; they are not study observations.
The freeze records source hashes and a UTC timestamp. A git commit records the
freeze before execution. All science, analysis, audit, and validation sources are
included, together with the unchanged study-01 generator/regions and study-02
linear-algebra kernel. Fresh seeds are generated only after this freeze.

| Case | Paired units m | Outer panels M | Bootstrap draws B |
|---|---:|---:|---:|
| Regular null | 20, 40, 160 | 120 at each m | 199 |
| Regular movement | 20, 40, 160 | 120 at each m | 199 |
| Rare-axis movement stress | 12 | 80 | 199 |

Total: **800 outer panels and 159,200 planned bootstrap weight vectors**.
There are 18 fixed entities, two periods, three latent groups, and 11 original
anchors E001:E005 and E007:E012. The primary target is E015; E003 and E006 are
secondary. Each region is joint over the two displacement components of one
entity. There is no simultaneous coverage claim across entities or time pairs.

The unchanged study-01 Gaussian generator supplies iid paired measurement units,
shared latent feature loadings, noise standard deviation 0.25, and across-time
noise correlation 0.6. Movement equals 0.2 times study-01 latent movement:
E006 moves (0.09, -0.06); E013:E018 move (-0.11, 0.08). This amplitude is set before
fresh outcomes, with no power tuning. The rare-axis case keeps the original
rare-unit probability 0.15 and its rank-instability mechanism. Its purpose is
failure selection, not a nominal-coverage benchmark for regular geometry.

Population truth is the **full embedding and alignment functional of the expected
normalized Gram matrices**, including the noise contribution sigma^2 H. It is
not bare latent movement. An entity with zero latent movement can have nonzero
population embedding displacement. Only the whole-map null is labeled type-I
error; zero exclusion under a nonzero population target is labeled power.

Data use L'Ecuyer-CMRG, Inversion, Rejection, master seed 260923 and successive
streams in case-major, dataset-major order. Bootstrap seeds equal
3400000 + 10000 * case_index + dataset_id. Streams and every planned integer weight
vector are retained. Eight outer workers use explicit streams, serial inner
refits, and `mc.set.seed=FALSE`. No replacement panels, successful-fit redraws,
optional stopping, or post-outcome changes to budgets are allowed.

## Candidate and comparisons

Every full observed, bootstrap, and required delete-one fit recomputes both
embeddings and temporal alignment and registers its baseline directly to the
fixed observed baseline R0. The covariance for a parent with m sample occurrences
is the exact occurrence-weighted ordinary jackknife, normalized by (m-1)/m.
Deleting one of w_j identical occurrences is computed once and receives weight
w_j; the number of distinct sampled units never substitutes for m. Leave-one
Gram matrices divide by m-1. There is no extra division of covariance by m or B.

The bootstrap pivot uses d_b - d_hat and the jackknife covariance **of that
bootstrap parent**. The observed ellipse uses the observed jackknife covariance
and the type-7 empirical 95th percentile of valid pivots. No ridge, clipping,
fitted inflation, recentering at the bootstrap mean, or bias correction is used.
Covariances must be finite, positive definite, with minimum/maximum eigenvalue
ratio strictly above 1e-8. Required failed deletions invalidate the covariance;
remaining required deletions are still attempted and recorded.

Five paired methods use the same datasets and planned bootstrap weights:

1. Existing full-estimator bootstrap covariance Wald ellipse.
2. Existing empirical Mahalanobis ellipse.
3. Existing bootstrap Euclidean ball.
4. Observed jackknife covariance with the chi-square(2) 95% cutoff.
5. The new bootstrap jackknife-studentized joint ellipse.

The first three preserve their study-01 implementation and numerical criteria.
The studentized ellipse requires a valid observed covariance, at least 20 valid
pivots, and at least 95% of B valid pivots (190 of 199). The first three apply the
same count/fraction gate to full bootstrap fits. Jackknife-Wald requires a valid
observed jackknife covariance and has **no bootstrap success gate**. Its `gate`
field follows observed-fit availability; `n_valid=NA` is intentional.

## Outcomes and complete failure accounting

The analysis reports delivered-region coverage, Wilson 95% intervals, binomial
outer-panel Monte Carlo standard errors, zero-exclusion probability, delivery
fraction, and covered-region yield over **all planned panels**. At M=120, a true
95% coverage rate has MCSE approximately 1.99 percentage points; the study can
detect material deficits but cannot establish precise universal 95% calibration.
Paired method contrasts use common delivered panels and panel-level standard
errors, with their paired denominator explicit. Region area and cutoff summaries
are retained; improved coverage through very large regions is not called a
cost-free improvement. Bias, RMSE, covariance traces and generalized eigenvalue
ratios are evaluated against repeated-panel errors.

Every panel, full bootstrap plan, target-specific covariance/pivot attempt, and
required deletion remains in the checkpoint. Unavailable observed fits retain
all B plans with `attempted=FALSE`. The ledger separates observed embedding,
evaluation registration, full bootstrap fit, observed/inner leaveout, covariance,
pivot, and delivery-gate failures. Both unique deletion counts and occurrence
multiplicities are retained, including successful, failed, and unattempted counts.
Warnings and failure messages are retained. A failed required deletion is never
removed to form a successes-only jackknife covariance.

Production coverage excludes undelivered regions from its conditional coverage
denominator and counts them as no covered delivery in yield. The separately
labeled relaxed analysis removes only the success-fraction delivery gate, never
the minimum count or covariance requirement. It is a selection diagnostic, not
a replacement primary result. Draw-level selection summaries compare distinct
unit counts, rare-unit multiplicity, and available full-estimator error norms
between valid/invalid full fits and valid/invalid studentized pivots. Inference
about these contrasts uses the outer panel as the independent replication unit;
pooled bootstrap rows are not treated as independent experiments. Error norms
cannot be observed for undefined full fits, which is reported as a limitation.

## Audits, validation, and execution

First two datasets in each case are predeclared public-engine audits (14 panels).
For every defined audited panel, public PCA point estimates and all B public
bootstrap vectors, weight vectors, streams, and statuses are compared with the
normalized-Gram kernel. Observed and first three bootstrap parent jackknives are
also reconstructed by physically expanded columns and direct-to-R0 PCA refits.
Unavailable observed fits receive an explicit status comparison and bootstrap
skip; they are not represented as attempted public bootstraps. Numerical vector
and covariance tolerance is 1e-9 after the declared normalization. All first-two
checkpoints retain inner leave-one values; other checkpoints retain covariance,
weighted mean/scatter, multiplicities, and the full deletion ledger.

The mechanical validator reconstructs every saved pivot, rotated covariance,
region, count, and delivery decision. Independent scatter reconstruction from
leave-one values is possible where those values are retained; elsewhere
scatter-to-covariance checks are bookkeeping identities, not independent refits.
Public-engine audits and physical-deletion tests provide separate numerical
evidence. Package tests, installed examples, and available R package checks are
run after analysis. Coverage itself is an outcome, never a software test gate.

From the package parent directory, using R with driftmapR 0.0.6.9000 installed:

```sh
Rscript driftmapR/data-raw/calibration-03/test.R
Rscript driftmapR/data-raw/calibration-03/run.R calibration03-output 8
Rscript driftmapR/data-raw/calibration-03/validate.R calibration03-output
Rscript driftmapR/data-raw/calibration-03/analyze.R calibration03-output
```

`run.R` refuses changed frozen sources and resumes only matching frozen
checkpoints. Source files, design, seeds, panel checkpoints, aggregate CSVs,
figures, runtime provenance, and validation logs accompany the delivery.
The installed public engine is retained as an exact source tarball. This bounded
study does not cover dependence between units, changing entities, arbitrary
anchors, general eigengap instability, or simultaneous inference. Even favorable
results do not by themselves establish an exact finite-sample or higher-order
coverage theorem, CRAN readiness, or a released confidence API.

For a short executable technical example, from the package parent directory:

```r
source('driftmapR/data-raw/calibration-03/run.R')
study03_load('driftmapR/data-raw/calibration-03')
RNGkind("L'Ecuyer-CMRG", 'Inversion', 'Rejection')
set.seed(777)                            # reserved demonstration stream
case <- study03_cases()[4, ]             # m=20 movement example
job <- list(case_id=case$case_id, case_index=case$case_index, m=case$m,
            dataset_id=999L, data_stream=.Random.seed, bootstrap_seed=777L)
fit <- study03_one(job, case, B=199L)
subset(fit$regions, entity=='E015' & method=='jackknife_studentized')
fit$observed_jackknife$covariance[[1]]     # covariance in observed chart
fit$studentization                      # every planned target/draw status
```

The returned region table provides center, covariance, cutoff, area, availability,
delivery gate, and study-only truth evaluations. The estimate and all resampling
calculations do not receive population truth; truth enters only evaluation.
The low-level `study03_jackknife()` and `study03_studentized_region()` helpers
accept centered paired-unit matrices/counts and estimate/covariance/pivot inputs,
respectively, without using the simulation generator.
