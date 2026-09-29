# driftmapR 0.0.8.9000 — independent secondary-null replication

**Study 04, completed 2026-09-11.** Neither selected secondary null deficit met
the frozen replication criterion in fresh data. The studentized region covered
377/400 E006 targets at m=40 and 379/400 E003 targets at m=160. Direct population
frame refitting left every primary candidate coverage decision unchanged.
Sparse-unit non-delivery persisted: only 8/120 panels delivered a studentized
region. This bounded result does not establish equivalence to 95% coverage or
justify a general confidence-region API.

## What was built and frozen

The study adds an executable diagnostic wrapper around the unchanged full
normalized PCA/classical-MDS and temporal-Procrustes estimator. Each observed,
bootstrap, and required deletion fit recomputes both maps and temporal alignment
in the same fixed observed reference R0. The occurrence jackknife uses

    dbar = sum_j w_j d_(-j) / m
    S_J = (m-1)/m * sum_j w_j (d_(-j)-dbar)(d_(-j)-dbar)'
    T_b = (d_b-d_hat)' inverse(S_J,b) (d_b-d_hat)

Each positive unit is deleted by one occurrence; its result represents w_j
identical deletions. The leaveout Gram denominator is m-1, and distinct sampled
unit count never substitutes for m. For an available parent fit, every required
deletion is attempted; one required failure invalidates its parent covariance. The observed ellipse uses
S_J,observed and the type-7 95th percentile of valid T_b. There is no fitted
inflation, ridge, clipping, bias correction, or successful-fit redraw.

The finite positive-definite covariance eigenvalue ratio must exceed 1e-8.
Studentized delivery requires an available observed covariance, at least 20
valid pivots, and at least 95% of all B plans valid: **190 of 199**. Jackknife-Wald
uses the same observed covariance with the chi-square(2) cutoff and no bootstrap
success gate. Bootstrap covariance Wald, empirical Mahalanobis, and Euclidean
ball remain paired controls. All public R/man/NAMESPACE files are unchanged
from the exact 0.0.7.9000 engine. New helpers remain in data-raw/calibration-04;
they are not newly exported confidence functions.

The complete scientific source, tests, analysis, audits, and validation were
frozen at **f4e462a6e4d219ee80a7586c714b817a1ea6910c**, UTC
**2026-09-11T02:29:10.282657Z**, before fresh measurement generation. The protocol
and source-hash record were saved before execution. All 34 frozen source and
dependency hashes still match. Earlier studies remain unchanged.

| Case | Paired units m | Fresh panels M | Draws per panel B |
|---|---:|---:|---:|
| Regular null | 40 | 400 | 199 |
| Regular null | 160 | 400 | 199 |
| Regular movement | 40 | 100 | 199 |
| Regular movement | 160 | 100 | 199 |
| Rare-axis movement stress | 12 | 120 | 199 |

Total: **1,120 panels and 222,880 planned weight vectors**. The unchanged model
has 18 entities, two periods, three latent groups, 11 anchors, noise SD 0.25,
temporal noise correlation 0.6, movement amplitude 0.2 times study01, and rare
unit probability 0.15. Truth is the full embedding/alignment functional of
expected normalized Gram matrices, including sigma squared H; it is not bare
latent movement. Regions are joint over dx/dy for one entity, not simultaneous
across entities or time pairs.

Fresh L'Ecuyer-CMRG streams start from master seed 260929; bootstrap seeds are
4400000 + 10000 times case_index + dataset_id. The independent stream audit
passed 44 grouped checks and found no reused complete starting state or
bootstrap seed against 2,240 earlier panels. Engineering seed 778/dataset 999
is excluded from study denominators. No outcomes were pooled across studies.

## The two primary replications

The frozen test family contains E006/null40 and E003/null160 only. Each exact
one-sided binomial test assesses delivered coverage below 0.95 at alpha 0.025;
Bonferroni-adjusted p-values are also reported. All 400 panels delivered in both
cells, so conditional coverage and covered-delivery yield coincide here.

| Endpoint | Historical study03 | Fresh coverage | Pointwise 95% Wilson interval | Raw p | Adjusted p |
|---|---:|---:|---:|---:|---:|
| E006, null m=40 | 109/120 (90.83%) | 377/400 (94.25%) | 91.52–96.14% | 0.27538 | 0.55077 |
| E003, null m=160 | 110/120 (91.67%) | 379/400 (94.75%) | 92.11–96.54% | 0.44089 | 0.88178 |

Neither test rejects nominal coverage. This does not prove that a deficit is
absent: the intervals still include modest undercoverage, and non-rejection is
not an equivalence test. The old selected observations are historical context,
not extra observations in the fresh denominator. The tests concern this exact
B=199 candidate, including its finite-bootstrap quantile variation.

| Endpoint | Bootstrap Wald | Empirical Mahalanobis | Euclidean ball | Jackknife-Wald | Studentized |
|---|---:|---:|---:|---:|---:|
| E006, null40 | 359/400 | 356/400 | 368/400 | 365/400 | 377/400 |
| E003, null160 | 374/400 | 373/400 | 372/400 | 374/400 | 379/400 |

These method comparisons are paired descriptive controls. In particular, the
studentized result does not validate the existing bootstrap-Wald ellipse: its
E006/null40 coverage was only 89.75%. The two fixed replication tests apply to
the studentized candidate, not to every displayed method or target.

## Covariance and frame findings

At E006/null40, mean bootstrap covariance trace was **0.864 times** the
repeated-panel error covariance trace; the observed jackknife ratio was
**0.947**. Their trace-ratio Monte Carlo SEs were 0.043 and 0.047. Jackknife-Wald
covered 91.25%, while studentization with the same observed covariance covered
94.25%; its mean cutoff was **7.734**, versus **5.991** for Wald. Thus improved
mean covariance scale alone did not account for the full coverage improvement.
Mean region area was 0.02408 for bootstrap-Wald, 0.02633 for jackknife-Wald, and
0.03456 for studentized regions.

At E003/null160, trace ratios were **0.981** for bootstrap covariance and
**1.002** for jackknife covariance, with SEs about 0.052. The jackknife generalized
eigenvalue ratios ranged from **0.871 to 1.218**, despite the near-unit trace
ratio. Studentization raised the mean cutoff to **6.252** and coverage from
93.50% for jackknife-Wald to 94.75%. Mean covariance trace agreement is therefore
not evidence of exact covariance shape or calibrated pivots.

The population-frame diagnostic registers every individual full fit and
deletion directly to the known population baseline A. It reuses the core
eigensystems through orthogonal equivariance, adding separate registration
operations and failure ledgers. It is not merely one rigid rotation of all
replicates by the observed Q0, and it is unavailable in an ordinary application.

**None of the 800 primary candidate coverage flags changed under direct-A
refitting.** Geometric mean paired area ratios, oracle/core, were approximately
1.000063 for E006/null40 and 1.000013 for E003/null160. These very small effects
give no evidence that frame refitting explains the previously selected null
deficits in this design. They do not establish universal frame invariance under
other anchors, movement, or spectral geometry. Zero empirical discordances also
make plug-in paired MC intervals collapse; that is not proof of equivalence.

The opposite-half empirical covariance diagnostic covered **379/400 (94.75%)
at both primary endpoints**. Each panel used covariance from the other 200
panels, with a frozen minimum of 190 finite donors and a chi-square(2) cutoff.
This is an unavailable repeated-experiment benchmark, not known true covariance
or a proposed replacement method. Shared donor covariance makes its pooled
coverage indicators dependent, so no naive binomial interval, MCSE, or test is
attached. Donor counts, matrices, spectra, and half-specific outcomes are saved.

## Movement controls

Every regular movement panel delivered a studentized region. The following
counts use 100 independent panels in each cell:

| Target | Coverage, m40 | Zero exclusion, m40 | Coverage, m160 | Zero exclusion, m160 |
|---|---:|---:|---:|---:|
| E015, moving group | 96/100 | 79/100 | 96/100 | 100/100 |
| E006, individual mover | 95/100 | 61/100 | 96/100 | 99/100 |
| E003, latent stable | 97/100 | 3/100 | 99/100 | 1/100 |

Known movement remains detectable, with the larger unit count improving
detection for the two substantial movers. M=100 gives a nominal-coverage MCSE
of about 2.18 percentage points, so these controls are not precise certification.
E003 has a small nonzero population embedding target even though its latent
position is stable; its movement-case zero exclusion is not labeled whole-map
null type-I error. The full table supplies all methods, areas, and intervals.

For E015 at m40, studentization increased geometric mean paired area by a factor
of 1.387 relative to bootstrap-Wald, while zero exclusion fell from 92/100 to
79/100. At m160 the area factor was 1.072 and both methods excluded zero in
100/100 panels. Coverage gains must be read alongside this size/detection tradeoff.

## Sparse-unit non-delivery and selection

For E015, the frozen precedence gives an exhaustive accounting:

| Candidate outcome | Panels / 120 |
|---|---:|
| Observed fit unavailable | 16 |
| Required observed deletion failed | 28 |
| Observed covariance invalid after successful deletions | 0 |
| Fewer than 20 valid pivots after those gates | 0 |
| Valid-pivot fraction below 95% | 68 |
| Final geometry unavailable after those gates | 0 |
| Delivered | 8 |

Observed rare-unit bins 0/1/2/3/4+ contained **16/28/32/32/12** panels. None of
the first four bins delivered a candidate region; 8 of the 12 panels with at
least four rare units delivered. This is explicit non-delivery, not missing
panels removed from the analysis. All targets and both frames have complete
separate outcome tables.

All eight delivered E015 regions covered truth, but **8/8 has a Wilson interval
of 67.56–100%**. Covered-delivery yield is only **8/120 = 6.67%**, with interval
3.42–12.61%. These selected regions had mean area **12.96**, mean cutoff
**191.34**, and zero movement detections. Sparse conditional coverage is not
evidence of useful, generally calibrated inference.

| Method | Delivered / planned | Covered / delivered | Covered delivery / planned |
|---|---:|---:|---:|
| Bootstrap Wald | 43/120 | 38/43 | 38/120 |
| Empirical Mahalanobis | 43/120 | 39/43 | 39/120 |
| Euclidean ball | 43/120 | 38/43 | 38/120 |
| Jackknife-Wald | 76/120 | 64/76 | 64/120 |
| Studentized | 8/120 | 8/8 | 8/120 |

The separately labeled relaxed-gate diagnostic had 76 geometrically available
candidate regions and covered 73/76. Their mean area was 12.27 versus median
3.08, with mean cutoff 354.78 and maximum 4668.82. It is a selected sensitivity
analysis; neither the production gate nor the tail was altered.

Sparse frame diagnostics also warn against extending the tiny regular-null
frame effects to all geometry. Direct population-frame refitting preserved every
sparse candidate delivery and coverage flag, but the relaxed-gate mean area rose
from 12.27 to 18.35 and its mean cutoff from 354.78 to 419.10. Among the eight
production deliveries, mean area changed from 12.96 to 13.39 and mean cutoff
from 191.34 to 217.18. These are selected, heavy-tailed descriptive comparisons.

Across the 104 observed-valid sparse panels, full-fit success shifted selected
rare multiplicity by **+0.263** relative to the same panels' planned draws
(outer-panel MCSE 0.019). Conditioning further on valid studentization shifted
it by another **+0.498** (MCSE 0.023). Available full-fit error norms increased
by **0.00826** (MCSE 0.00274) under this latter selection. Error norms of
undefined full fits cannot be observed; their missing values are not zero.
The uncertainty calculation uses outer panels, not pooled bootstrap rows.

The prespecified rank-only benchmark predicts about **5.85 deliveries per 120**:
given r observed rare units, K is Binomial(12,r/12), full fitting needs K at least
one, and complete deletion fitting needs K at least two. The 190-of-199 gate is
applied to that latter probability. This approximates the non-delivery mechanism
before other geometry failures; it does not estimate a new gate or prove coverage.

## Full failure accounting and numerical validation

| Core stage | Planned or required | Attempted | Successful | Failed after attempt | Unattempted |
|---|---:|---:|---:|---:|---:|
| Observed fits | 1,120 | 1,120 | 1,104 | 16 | 0 |
| Full bootstrap fits | 222,880 | 219,696 | 216,745 | 2,951 | 3,184 |
| Observed deletions | 101,440 | 101,248 | 101,220 | 28 | 192 |
| Inner distinct deletions | 12,801,784 | 12,755,383 | 12,750,622 | 4,761 | 46,401 |
| Inner occurrence-weighted deletions | 20,186,560 | 20,112,940 | 20,108,179 | 4,761 | 73,620 |

Each target has **211,984 valid pivots**: 199,000 regular and 12,984 sparse.
The 4,761 additional sparse studentization failures arise after a successful
full fit. All 2,951 full-fit failures and 4,789 required deletion failures are
first-period embedding/rank failures. There are no covariance-only failures,
nonfinite pivot failures, or warnings from the main core/deletion fits. Two
public-audit rows retain four expected warning messages: one failure-count
warning (21 or 23 failed replicates) and one summary-gate warning per panel.
These are not package-check warnings. The 668,640 target/draw rows per frame are three views
of 222,880 plans; they are not independent bootstrap experiments.

Every attempted population-reference registration succeeded. Its observed,
bootstrap, observed-deletion and inner-deletion attempt counts were respectively
1,104; 216,745; 101,220; and 12,750,622. Blocked registrations remain unattempted
in their own ledger. These additional registrations reuse core eigensystems;
their counts must not be added as new complete PCA fits or independent draws.

- Existing package: **2,622 assertions in 147 blocks**, and all four installed
  workflows passed without failures, errors, warnings, or skips.
- New study: **250 assertions in 30 blocks** passed before freezing, covering
  core identity, direct frame refits, weighted deletions, failure isolation,
  complete plans, covariance gates, diagnostic calculations, and audits.
- Mechanical reconstruction: **20,356,654 checks** across all 1,120 checkpoints;
  1,337,280 core/oracle pivot rows; 6,100 retained jackknives and 1,577,736
  independently expanded occurrence vectors. Other scatter identities are
  bookkeeping checks rather than independent refits.
- Public audits: **140 rows across all 10 predeclared panels**, all checks passed,
  including two explicit unavailable-parent skip records with no deletion attempt.
  They include 1,990 public bootstrap attempts and physical expanded-column
  full/deletion fits in both references. Maximum vector difference was
  9.93e-15; maximum covariance difference was 2.11e-15, below tolerance 1e-9.
- Independent Python review: **18,968 arithmetic checks** reconstructed coverage
  counts, Wilson intervals, MCSEs, primary p-values and opposite-half covariance
  calculations. No result was used to tune a candidate or threshold.
- Three final figures were generated by frozen R plotting code through Cairo
  PDF, then rendered with Poppler and fully decoded. Source hashes, seeds,
  ledgers, checkpoints, figures, audit scripts, and validation logs are retained.

Package build/check evidence accompanies the current source delivery. No remote
GitHub CI, CRAN readiness, publication readiness, or verified maintainer identity
is claimed. Placeholder author/maintainer metadata remains a release task.

## Execution interruptions and preservation

R 4.5.3 ran the study with eight outer workers. End-to-end time from the first
run start to completed table collection was **54.4 minutes**, including two
execution-session interruptions. The first resume retained 582 completed
checkpoints and recomputed only unfinished original jobs with their original
streams. The amount of uncheckpointed CPU work lost in that session is unknown.
The second interruption occurred after all 1,120 panels were checkpointed; its
resume performed table collection only. The final execution.txt duration of
7.35 minutes is that cached collection pass, not the entire simulation runtime.

All 582 initially protected files and all 1,120 subsequently protected files
retain identical SHA-256 values after completion. No planned panel was replaced,
no failure was redrawn to obtain success, and no completed result was discarded.
Statistical ledgers count unique planned jobs and draws once; interrupted CPU
work is not misrepresented as an additional independent replication. The runtime
and execution records distinguish these infrastructure events from estimator
failures. The environment's direct R PNG issue is handled by completed Cairo
PDFs and independently decoded PNGs, not claimed repaired.

## Decision and next milestone

The requested independent replication is complete. The two selected null
deficits did not replicate under the frozen criterion; covariance estimation
and studentization still matter, and frame refitting had negligible effects at
those endpoints. Sparse-unit non-delivery remains a practical limitation.
The inferential API release gate stays closed pending broader robustness.

Approximate progress toward v0.1 is **82%**, a planning estimate. Next, specify
and freeze a bounded robustness study across eigengap weakening and anchor
contamination, with an explicit dependence stress/extension contract and full
delivery accounting. Dependence-violating cases must not be presented as nominal
calibration of the iid unit bootstrap. Then implement cluster refitting and
correspondence uncertainty, retaining unmatched, ambiguous, and unavailable mass.
Consensus alignment, applications, cross-platform checks, full landscape work,
and release hardening remain open.

Reproduction uses the full checkout, the supplied exact 0.0.7.9000 public engine
in an isolated R library, and the commands in the frozen study-04 protocol.
Standard R source tarballs exclude data-raw; the development archive includes
every research source and checkpoint. The complete earlier cumulative archive
remains unchanged and separate; this delivery includes its checksum and compact
historical reports, with full current package source and Git history.
