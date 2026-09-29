# driftmapR development report: independent null follow-up

**Delivery version 0.0.6.9000 · 2026-09-10**

This update retains the executable coordinate, alignment, movement, plotting, supplied-cluster correspondence, PCA/classical-MDS and paired-unit bootstrap functions. It adds covariance, unit-count and frame-refitting diagnostics, followed by an independently seeded calibration study. Public computational R code is unchanged from 0.0.4.9000. Study 01 and its evidence remain intact.

The scientific source and analysis were frozen at commit `1c8efc10b27bd432aba80522eeba7c12f8db65e5`, on 2026-09-10 at 19:37:06 UTC, before any new study-02 panel was generated. The exact audited engine is 0.0.5.9000. Complete data and bootstrap stream states, unit-count matrices, failed-attempt placeholders, target vectors, region results, source hashes and public-engine audit results accompany this report.

## Retrospective diagnosis

Study 01's primary whole-map-null Wald coverage was 65/80 (81.25%). All null bootstrap draws succeeded, ruling out failure selection as the explanation in those panels. Reconstructed covariance and quantiles agreed with stored output. Mean distinct unit occupancy agreed with its exact multinomial expectation.

Mean bootstrap covariance trace was 0.7496 times independent outer empirical variance, with jackknife Monte Carlo SE 0.0916. Both generalized directional ratios were low, 0.7305 and 0.7723, so simple covariance misorientation was insufficient. Covariance estimates varied across panels (trace CV 0.270). The observed component bias was not clearly dominant relative to its Monte Carlo error. Retrospective shared-covariance and leave-one-panel-out diagnostics improved coverage but are unavailable procedures for a single application; no correction factor was fitted.

Reusing the same 80 old panels at correlated 10/20/40-unit prefixes found little change from replacing the bootstrap baseline registration by a population-frame oracle. At m=40, primary Wald coverage stayed 65/80 and the covariance ratio changed only from .749600 to .749591. The population tangent control reached 70/80 and covariance ratio .8243, still below nominal. Empirical B=199 tangent covariance was close to its exact conditional multinomial target (mean trace ratio .9870, outer MCSE .0081). These exploratory results motivated a fresh unit-count study; they were not treated as independent confirmation.

## Frozen follow-up design

There are 240 independent raw panels at each of m=20,40,160,640 measurement units: 960 independent outer panels. Each has 18 fixed entities, two periods and zero population displacement. Measurement units have shared Gaussian loadings, noise SD .25 and temporal noise correlation .6, independently across units. The generator is exactly study 01's regular null.

Coordinates use the leading two eigenpairs of `H X X' H / m`, equal to public unstandardized PCA coordinates divided by sqrt(m). Population truth comes from the noisy expected centered Gram matrix and is exactly zero displacement. Translation, rotation and reflection are aligned with no scaling. Two fixed sets of 11 anchors are compared within each panel: the original set and a set spread over all three groups. E015 is primary; E003 and E006 are separately reported secondary targets.

Each panel has exactly 399 paired-unit draws; the first 199 form a nested budget check. Both anchors share the draws. Three estimators are compared: the production-equivalent full refit with observed baseline registration; an oracle population-baseline refit with the same observed estimate; and a population-tangent estimator that changes both the observed and bootstrap functional. The latter two are diagnostic controls requiring population information, not deployable recommendations.

Three unchanged nominal 95% joint vector regions are evaluated: Wald ellipse, empirical Mahalanobis-error ellipse and Euclidean error ball. Production delivery requires at least 20 valid draws, at least 95% success and usable region geometry. Covariance is not divided by B. The empirical regions use uncentered bootstrap errors and are not bootstrap-t. No cutoffs, budgets, sample sizes, anchor sets or primary targets change after the freeze.

The tangent differentiates leading eigenscores using all discarded eigenspaces, then differentiates anchor centering and temporal Procrustes. For paired unit influences phi_j, the exact conditional multinomial covariance is `sum((phi_j - mean(phi)) %*% t(phi_j - mean(phi))) / m^2`. Embedding, alignment and twice-cross-covariance components are all retained. Analytic derivatives agree with finite differences at h=1e-4 and h/2 in reserved implementation fixtures.

Coverage Monte Carlo uncertainty uses independent raw panels. Wilson intervals and empirical Monte Carlo SEs accompany exact counts. Paired comparisons use within-panel differences and joint delivery; neither target entities nor bootstrap draws inflate the outer denominator. Near 95% with 240 panels, MCSE is about 1.4 percentage points. This bounded null-only design cannot establish general coverage, alternative coverage, power, rare-axis failure robustness, or a minimum sufficient unit count.

## Follow-up results

**Small-unit undercoverage replicated; the diagnostic results do not support a simple covariance multiplier or a baseline-frame fix.** Primary E015 results below use the full production-equivalent refit, original anchors and B=399. All 240 regions were delivered in every row, so conditional coverage equals covered-and-delivered yield here.

| Units | Wald coverage | 95% Monte Carlo interval | Empirical Mahalanobis | Euclidean ball |
|---:|---:|---:|---:|---:|
| 20 | 209/240 (87.08%) | 82.25–90.75% | 210/240 (87.50%) | 220/240 (91.67%) |
| 40 | 216/240 (90.00%) | 85.55–93.19% | 215/240 (89.58%) | 220/240 (91.67%) |
| 160 | 228/240 (95.00%) | 91.47–97.12% | 229/240 (95.42%) | 226/240 (94.17%) |
| 640 | 229/240 (95.42%) | 91.98–97.42% | 229/240 (95.42%) | 229/240 (95.42%) |

The primary Wald null-rejection rates were 12.92%, 10.00%, 5.00% and 4.58%. The first two coverage intervals lie below 95%. The larger-unit results are compatible with nominal coverage in this particular null setting; they do not establish a universal m threshold or validate all targets and scenarios. Study01's 81.25% m40 estimate was lower than the fresh 90.00%; its 80-panel Monte Carlo variation should not be mistaken for a fixed population deficit.

### Covariance scale is only part of the diagnosis

| Units | Mean bootstrap / outer covariance trace | Jackknife MCSE | Across-panel bootstrap trace CV | Mean observed squared Mahalanobis error |
|---:|---:|---:|---:|---:|
| 20 | 1.009 | 0.073 | 0.403 | 2.870 |
| 40 | 0.886 | 0.059 | 0.299 | 2.488 |
| 160 | 1.031 | 0.069 | 0.149 | 1.986 |
| 640 | 1.078 | 0.074 | 0.092 | 1.927 |

At m20, the mean covariance trace ratio is approximately one despite 87.08% coverage. At m40 it is .886, compared with .750 in the original smaller outer study. At m20 the observed Mahalanobis 95th percentile is 9.286, well above the Wald cutoff 5.991; it falls to 5.611 at m640. This pattern is consistent with finite-unit tail behavior and the interaction of the full refitted statistic with its random covariance estimate. It does not identify a universal scalar underestimation factor. Lower covariance variability at larger m is a diagnostic observation, not by itself a causal proof.

### Frames, linearization and draw budget

Changing the bootstrap baseline to the population frame changed primary Wald coverage by -0.42 percentage points at m20 and zero at the other unit counts. The largest absolute frame effect across all evaluated targets, anchors, budgets and region methods was .83 points. A common rotation of an entire result is exactly coverage-invariant at the null; the evaluated draw-specific refitting control is different and also had little effect here.

Original-anchor tangent Wald coverage was 94.17%, 94.17%, 96.25% and 95.42%. Its paired advantage over the full estimator was 7.08 percentage points at m20 (MCSE 1.66), 4.17 at m40 (MCSE 1.42), 1.25 at m160 (MCSE .72) and zero at m640. This supports investigating nonlinear finite-unit behavior of the full estimator. The control changes both the estimator and bootstrap functional and uses the true population spectrum; it is not a covariance-only repair or an available confidence procedure.

The empirical/exact conditional tangent covariance trace ratios ranged from .9946 to 1.0078 across unit counts, anchors and targets. Thus B=399 accurately estimated this diagnostic's conditional covariance on average. For primary original-anchor Wald coverage, increasing the same run's prefix from 199 to 399 draws changed coverage by +.83, 0, +.83 and +.42 percentage points. Increasing B had little effect on the small-unit deficit. The conclusion concerns this bounded budget comparison, not every possible bootstrap construction.

The exact covariance decomposition retains embedding, alignment and cross terms. For original-anchor E015 at m40, their mean traces are approximately .002483, .000088 and .000058, summing to .002628. The linear embedding contribution dominates this example. Dropping the cross term would be incorrect. The spread anchors did not provide a systematic small-unit coverage repair.

### Other targets and point estimation

E003 and E006 remain separate secondary analyses. E003's tangent Wald coverage at m40 with original anchors was only 91.67%; E006's empirical Mahalanobis coverage at m160 was 92.08%. These results limit any general claim that the tangent or a large-unit threshold is calibrated.

Primary full-estimator vector RMSE, in normalized coordinates, fell from .07398 at m20 to .05351, .02616 and .01302. Finite-run component means and their Monte Carlo SEs are reported for every target. They are not uniformly zero: E015's m640 dy mean was -.001796 (MCSE .000563), with a similar fluctuation in the population-tangent control. These multiple finite-run mean diagnostics do not establish a unique full-estimator bias mechanism or justify fitting a correction on the same panels.

## Execution, failures and provenance

All 960 observed panels were defined. All **383,040 unique paired-unit draw plans** were retained and succeeded for both anchor geometries and all three estimators. The diagnostic ledger contains 2,298,240 planned/attempted/successful estimator-anchor rows, not that many independent draws or datasets. All production regions were available and delivered. Consequently this regular-null study has no failure-selected subset; it cannot replace study01's rare-axis selection assessment.

The first three panels at each m and both anchor sets produced 24 full public PCA/bootstrap audits, with 9,576 additional public bootstrap attempts. Observed target vectors agreed within 3.22e-15 normalized units; plugin and oracle bootstrap vectors agreed within 1.03e-14. Counts, RNG streams and success ledgers matched exactly. These checks validate the study implementation's equivalence to the public engine, not statistical coverage. The primary run took 460.2 seconds with four outer workers; analysis/validation time is additional.

Scientific freeze: `1c8efc10b27bd432aba80522eeba7c12f8db65e5`. An analysis implementation addendum was committed at `42b3388d6569183c0529f480480202ddf082e11e`, while the study was running and before any follow-up outcomes were inspected. It supplied the protocol's already-prespecified full-versus-tangent paired contrast, which the original contrast function had omitted. No frozen file, data seed, estimator, cutoff or primary result was changed. The supplement is separate and has 17 dedicated passing assertions; the original frozen analysis remains executable.

## Decision and next development target

Keep all candidate confidence regions research-only. The full refitted estimator still undercovers at 20 and 40 units. The evidence points toward finite-unit behavior of that estimator and its covariance/shape calculation rather than baseline registration, failure selection or simply too few bootstrap draws. It does not identify one universally sufficient correction.

Next, specify an implementable finite-unit studentized joint displacement-vector candidate for the full estimator, including an observed-data influence or jackknife covariance calculation, any nested resampling, computational budget and independent failure accounting. Freeze an independent null-and-movement calibration against the unchanged candidates before choosing an inference API. Retain rare-axis failures and dependent-unit negative controls in broader validation. After inferential calibration, proceed to cluster refitting/stability with unmatched/ambiguous mass retained.

Overall v0.1 completion is approximately **75%**, a planning estimate rather than a test-count measure. Core prototype functionality and both requested bounded studies are executable. Consensus alignment, calibrated uncertainty, cluster refitting/stability, broader applications, cross-platform validation and release hardening remain open. The package is not CRAN- or publication-ready; placeholder author/maintainer identity still requires verified replacement before public release.

The cumulative archive contains the full source checkout, installable package, git history bundle, all fresh and retrospective outputs, complete prior study evidence, figures, validation logs, manual and vignettes. Reproduction commands are in `data-raw/calibration-02/README.md` and `analysis-addendum.md`. Standard R package tarballs omit `data-raw`; use the full archived checkout for study code and the historical0.0.5.9000 engine in an isolated library for exact reproduction. No local R execution is required to inspect the delivered results.
