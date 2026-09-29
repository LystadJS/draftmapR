# driftmapR 0.0.7.9000: studentized joint-region study

**2026-09-10 — executable research implementation and independent calibration completed.**

The occurrence-jackknife studentized region improves primary small-unit coverage, with larger regions and lower movement detection. It does not establish generally calibrated inference: secondary null deficits remain, and only 2 of 80 rare-axis panels delivered a studentized region. The public confidence-region API remains unreleased. Earlier studies and public computational R code are preserved.

## What was implemented

The research engine recomputes the **full normalized PCA embedding and temporal Procrustes alignment** for every observed, bootstrap, and required delete-one fit. For Euclidean inputs this is also the classical-MDS geometry; this study does not cover arbitrary dissimilarities. All baselines register directly to the fixed observed reference R0, including inner deletions. No population quantity enters estimation or studentization. Population geometry enters only evaluation.

For multiplicities w summing to m paired measurement-column occurrences, let d_(-j) be the full estimate after deleting one occurrence of unit j. The engine computes each distinct required deletion once, with its original multiplicity as a weight:

    dbar = sum_j w_j d_(-j) / m
    S_J = (m - 1) / m * sum_j w_j (d_(-j) - dbar)(d_(-j) - dbar)'
    T_b = (d_b - d_hat)' inverse(S_J,b) (d_b - d_hat)
    C = {theta: (theta - d_hat)' inverse(S_J,observed)
                (theta - d_hat) <= quantile_type7(T_valid, 0.95)}

Leave-one Gram matrices divide by m-1. The covariance has no extra division by m or B. Required deletion failures invalidate the complete covariance; surviving deletions are never used alone. Positive finite covariance and minimum/maximum eigenvalue ratio >1e-8 are required. Delivery requires a valid observed covariance, at least 20 valid pivots, and at least 95% of planned B pivots (190 of 199). There is no ridge, tail clipping, fitted inflation, bias correction, or replacement draw. Jackknife-Wald is a separate control using the observed jackknife covariance and chi-square(2) cutoff, without a bootstrap-success gate.

Implementation and executable example: `driftmapR/data-raw/calibration-03/README.md`; mathematical contract: `method-specification.md`. Low-level functions include `study03_fit()`, `study03_jackknife()`, and `study03_studentized_region()`. They are research helpers in the full source checkout, not newly exported package functions. The current candidate supports two snapshots and one feature column per paired independent unit; grouped/dependent-unit extensions are not implemented here.

## Freeze and independent design

The complete scientific source, tests, analysis, and audits were frozen at commit **0ca7d5d298b9d12ebbef59788dc24f9866f09066**, UTC **2026-09-10T20:57:26.808189Z**, before fresh measurement generation. No scientific source or acceptance rule was changed after freezing. An orchestration-only wrapper parallelized the unchanged per-panel validator; serial/parallel fixture output files were byte-identical.

There are 800 independent outer panels: null and movement at m=20,40,160 with 120 panels per cell, plus 80 rare-axis panels at m=12. Every panel has 199 planned paired-unit bootstrap weight vectors, totaling **159,200 plans**. The generator has 18 fixed entities, two periods, three latent groups, 11 declared anchors, Gaussian paired units, noise SD .25 and temporal noise correlation .6; the rare-axis mechanism has probability .15. E015 is primary; E003 and E006 are secondary. Movement is fixed at .2 times study01's shifts before outcomes. Data streams start from L'Ecuyer-CMRG seed 260923; bootstrap seeds are 3400000+10000*case_index+dataset_id. Reserved seed 777/dataset999 fixtures are excluded from study denominators.

Truth is the full embedding/alignment functional of expected normalized Gram matrices, including sigma²H. The primary movement magnitude is .1358905; E006 is .1083539. The nominally latent-stable E003 has a small nonzero embedding target (.00007322), so its movement-scenario zero exclusion is not labeled a whole-map-null false positive. Each region is joint over dx/dy for one entity/time pair, with no simultaneous coverage claim across targets.

## Primary coverage and detection

All regular-case regions were delivered. Coverage counts and studentized 95% Wilson Monte Carlo intervals are:

| Scenario | m | Bootstrap Wald | Jackknife Wald | Studentized jackknife | Studentized MC interval |
|---|---:|---:|---:|---:|---:|
| Null | 20 | 103/120 (85.83%) | 105/120 (87.50%) | 112/120 (93.33%) | 87.39–96.58% |
| Null | 40 | 113/120 (94.17%) | 114/120 (95.00%) | 114/120 (95.00%) | 89.52–97.69% |
| Null | 160 | 117/120 (97.50%) | 115/120 (95.83%) | 116/120 (96.67%) | 91.74–98.70% |
| Movement | 20 | 100/120 (83.33%) | 101/120 (84.17%) | 111/120 (92.50%) | 86.36–96.00% |
| Movement | 40 | 106/120 (88.33%) | 107/120 (89.17%) | 113/120 (94.17%) | 88.45–97.15% |
| Movement | 160 | 112/120 (93.33%) | 114/120 (95.00%) | 113/120 (94.17%) | 88.45–97.15% |

At m20, studentized-minus-bootstrap-Wald coverage improved by **7.5 percentage points under the null** (paired MC interval +2.8 to +12.2) and **9.2 points under movement** (+4.0 to +14.4). At movement m40, the gain was 5.8 points (+1.6 to +10.0). These comparisons use the same 120 panels and the frozen paired-difference calculation.

The improvement costs region size and detection. The geometric mean of paired studentized/Wald area ratios was **2.06× for null m20**, **1.90× for movement m20**, and **1.40× for movement m40**. These are means of paired log-area ratios exponentiated, not ratios of unpaired average areas. Studentized mean cutoffs were 11.30/7.60/6.23 under null m20/40/160, versus the fixed Wald cutoff 5.991. Movement detection at the declared primary nonzero target was:

| m | Bootstrap Wald | Jackknife Wald | Studentized jackknife |
|---|---:|---:|---:|
| 20 | 74/120 (61.67%) | 68/120 (56.67%) | 40/120 (33.33%) |
| 40 | 103/120 (85.83%) | 100/120 (83.33%) | 93/120 (77.50%) |
| 160 | 120/120 (100.00%) | 120/120 (100.00%) | 120/120 (100.00%) |

At m20, the studentized detection rate fell by 28.3 points versus Wald (paired MC interval -36.4 to -20.2). Wald's higher detection accompanies poorer coverage, so this is not a comparison between two already size-calibrated tests. Merely replacing bootstrap covariance by observed jackknife covariance did not recover most of the small-unit improvement: null m20 coverage was 87.5% for jackknife-Wald and 93.3% after studentization. The mean jackknife covariance trace/outer variance trace was .996 under null m20 and .977 under movement m20, compared with .853/.839 for bootstrap covariance, but matching a mean covariance scale does not guarantee coverage.

Secondary behavior prevents a general calibration claim. Studentized null coverage was **109/120=90.83% for E006 at m40** (Wilson84.33–94.80%) and **110/120=91.67% for E003 at m160** (85.34–95.41%). These are pointwise diagnostics among multiple prespecified cells, not a multiplicity-adjusted test establishing a unique defect. At M120, nominal95% coverage has approximately 1.99 percentage-point MCSE; a primary interval containing95% is not proof of exact coverage or a universal minimum-unit threshold.

All five methods, three targets, cutoff tails, area summaries, errors, covariance ratios and paired contrasts are in the summary CSVs. The figures preserve the frozen plotting design.

## Rare-axis delivery and selection

| Method | Delivered / planned | Coverage among delivered | Covered delivery / all planned |
|---|---:|---:|---:|
| Bootstrap Wald | 18/80 | 16/18 (88.89%) | 16/80 (20.00%) |
| Bootstrap Mahalanobis | 18/80 | 16/18 (88.89%) | 16/80 (20.00%) |
| Bootstrap ball | 18/80 | 17/18 (94.44%) | 17/80 (21.25%) |
| Jackknife Wald | 43/80 | 33/43 (76.74%) | 33/80 (41.25%) |
| Studentized jackknife | 2/80 | 2/2 (100.00%) | 2/80 (2.50%) |

For the candidate, **2/2 coverage has Wilson interval 34.2–100%**; usable covered-region yield is only2.5%. It is not successful stress-case calibration. There were 43 geometrically available studentized regions before the95% draw-success gate. The explicitly relaxed diagnostic covered 41/43 and delivered 43/80, but was highly selected and could be enormous: E015 mean area53.43 versus median2.29, with mean cutoff 797.75. The two production-delivered regions had mean area4.65 and mean cutoff 73.30. Lowering the gate or clipping tails is not authorized by this study.

The observed rare count was zero in 10 panels and one in 27. These cause undefined observed fits or failed required observed deletions. Across the70 observed-valid panels, full-fit success shifted rare-unit multiplicity by +.313 (outer-panel MCSE .0236) versus the same panels' planned draws. Conditional on full-fit success, studentization shifted it by a further +.558 (MCSE .0284). Successful studentized draws had larger available full-fit error norms by .0121 (MCSE .00316) relative to all finite full-fit draws. Failures therefore select the resampling distribution; they are not computationally random losses. Error norms of undefined full fits cannot be observed. Paired contrasts use matched panels; means with different selected denominators must not be subtracted naively.

## Complete failure accounting

| Stage | Planned/required | Attempted | Successful | Failed after attempt | Unattempted |
|---|---:|---:|---:|---:|---:|
| Observed full fits | 800 | 800 | 790 | 10 | 0 |
| Full bootstrap fits | 159,200 | 157,210 | 154,710 | 2,500 | 1,990 |
| Observed deletions, distinct units and occurrences | 53,760 | 53,640 | 53,613 | 27 | 120 |
| Inner deletions, distinct required units | 6,791,686 | 6,757,739 | 6,754,019 | 3,720 | 33,947 |
| Inner deletions, occurrence-weighted counts | 10,698,240 | 10,644,360 | 10,640,640 | 3,720 | 53,880 |

All actual full-bootstrap failures and all 3,747 deletion failures are rare-axis first-period rank failures. Every failed deletion removed a multiplicity-one last rare unit. There were no covariance-only, nonfinite-pivot, or warning events. Full-valid bootstrap draws yielded150,990 valid studentized pivots per target and 3,720 additional failed studentizations per target. The **477,600 target/draw rows are three views of 159,200 planned draws**, not independent bootstrap experiments. All143,280 regular bootstrap plans succeeded in full fitting and studentization. Public audit recomputations are separate computational checks, not additional calibration observations.

## Validation and reproducibility

- Existing package: **2,622 assertions in 147 blocks passed**, with no failures/errors/warnings/skips; all four installed workflows executed.
- New study: **549 assertions in 43 blocks passed**, including normalization, duplicate occurrences, nonnull fixed-frame reconstruction, sample-mean covariance identity, failure invalidation, reproducibility/prefixes, singular geometry and delivery gates.
- Full checkpoint validation: **7,492,228 checks passed across 800 checkpoints** and 477,600 pivot rows. Independent expanded-occurrence scatter reconstruction used3,552 retained jackknives /696,504 occurrence vectors. Other scatter-to-covariance checks are accounting identities, not independent refits.
- Public audits: all 84 rows across 14 predeclared panels passed;2,786 public bootstrap attempts,2,627 physical-column deletion refits. Maximum vector difference 1.99e-14 and covariance difference 1.03e-15, below the frozen1e-9 tolerance; weights and streams agree exactly. Two physical deletion failures agreed with the research engine.
- R4.5.3; eight outer workers; full study execution including audits and collection took about 16.6 minutes. Seeds, frozen sources/hashes, panel checkpoints, raw aggregate ledgers, deletion events, tables, figures and runtime provenance are supplied. Raw measurement panels regenerate from the saved streams and frozen generator.

The supplied package-check logs document the current installable source build. Archived studies01/02 retain their original engines, results and validation. No public GitHub CI run, CRAN readiness, publication readiness, or verified maintainer identity is claimed; placeholder maintainer metadata remains a release task.

## Decision, roadmap and next target

This session's requested implementation and bounded calibration are complete. Approximate v0.1 progress is **80%**, a planning estimate, not an inferential validation score. The prototype still supports coordinate ingestion/alignment/movement, plotting, supplied-cluster assignment diagnostics, PCA/classical MDS, and reproducible paired-unit bootstrap refits. The new region remains research-only.

Next, freeze an independent replication focused on the E006 m40 and E003 m160 null deficits, with prespecified covariance/frame diagnostics and regular movement controls. Define explicit handling of sparse-unit non-delivery without fitting success thresholds or covariance multipliers on study03. Broader eigengap, anchor-contamination and dependence robustness must precede a calibrated confidence API. Then proceed to cluster refitting/stability and correspondence uncertainty, retaining unmatched and ambiguous mass. Consensus alignment, applications, cross-platform validation and release hardening remain open.
