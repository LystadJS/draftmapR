# driftmapR 0.0.8.9000

* Added the study05 design freeze: 31 cells and 1,640 reserved panels spanning
  eigengap weakening, anchor changes, movement, dependence stress, and sparse
  support. Passed 526 engineering assertions. No study05 evaluation outcomes
  have been generated; runner/analysis implementation requires a second freeze.
* Froze and completed an independent replication of two secondary null endpoints,
  with 1,120 null, movement-control, and rare-axis panels and 222,880
  paired-unit bootstrap plans. The estimator and its delivery gates are unchanged.
* Added per-fit population-reference sensitivity diagnostics, independently
  reconstructed occurrence covariances, and separate registration failures.
* Added opposite-half empirical covariance benchmarks with explicit donor
  accounting; shared donor covariance is not treated as independent binomial
  coverage evidence.
* Added sparse-unit non-delivery decomposition by observed rare count and a
  prespecified rank-only mechanism benchmark. No success gate is relaxed.
* Passed 250 new study assertions before freezing. Public computational R code
  and exports are unchanged; confidence-region helpers remain research-only.
* Fresh studentized coverage was 377/400 for E006/null40 and 379/400 for
  E003/null160: neither deficit replicated under the prespecified criterion.
  Frame refitting changed no candidate coverage decisions. This is not evidence
  of universal calibration or equivalence to nominal coverage.
* Sparse candidate delivery was 8/120, with 16 undefined observations, 28
  observed deletion failures, and 68 valid-pivot-fraction gate failures.
  Retained all 222,880 plans and complete core/registration/deletion ledgers.
* Passed 20,356,654 mechanical checks, all 140 public-audit rows, and 18,968
  independent arithmetic checks. Current evidence and updated roadmap are in
  inst/validation/calibration-study-04.md.

# driftmapR 0.0.7.9000

* Implemented an exact occurrence-weighted delete-one jackknife for full
  normalized embedding and temporal-alignment refits, with a common observed
  reference for all inner and outer fits and complete deletion failure ledgers.
* Implemented a research studentized joint displacement region using each
  bootstrap parent's jackknife covariance; added jackknife-Wald as a control.
* Froze and ran 800 independent null/movement/rare-axis panels with 159,200
  planned paired-unit draws. Primary small-unit coverage improved with larger
  regions and lower movement detection; secondary null deficits remain.
* Rare-axis studentized delivery was only 2/80. Retained all undefined observed
  fits, full-fit failures, required deletion failures, and success-gate outcomes.
* Passed 549 study assertions and 7,492,228 mechanical checks; all 14 public
  engine audit panels agreed numerically. Preserved all previous study evidence.
* Public R code and exports are unchanged. Confidence-region functions remain
  research helpers until broader independent calibration supports release.

# driftmapR 0.0.6.9000

* Diagnosed study-01 null undercoverage using independent covariance reconstruction,
  multinomial unit occupancy, correlated unit-count prefixes, frame controls and
  an analytic population tangent with exact conditional bootstrap covariance.
* Froze and ran an independent follow-up: 960 raw panels, 383,040 paired-unit
  draws, two anchor geometries, three estimators and nested 199/399-draw budgets.
* Primary Wald null coverage at 20/40/160/640 units was 87.08/90.00/95.00/95.42%.
  Oracle baseline refitting made little difference; mean covariance scale alone
  did not explain undercoverage. Candidate confidence regions remain research-only.
* Verified the study kernel against 24 full public PCA/bootstrap analyses with
  identical streams; preserved independent oracle failure accounting and all
  scientific sources, seed plans, checkpoints and denominators.
* Disclosed a separate pre-outcome analysis addendum completing the already
  prespecified full-versus-tangent paired contrast. Original frozen code and
  study-01 evidence remain unchanged. Public R code and exports are unchanged.

# driftmapR 0.0.5.9000

* Completed the first bounded joint displacement-vector calibration study:
  six prespecified scenarios, 80 independent datasets each, 199 bootstrap
  attempts per defined observed estimator, and 18 paired PCA/MDS audit cases.
* Added analytic population-embedding targets, fixed evaluation gauges, three
  experimental region constructions, and independent helper/accounting tests.
* Retained all outer failures and exactly 93,132 main bootstrap attempts;
  separated conditional coverage, delivery, operational yield, and selection.
* Found undercoverage in the whole-map null and other scenarios. Rare-axis
  rank failures and success gates altered unit/dataset composition. No candidate
  is promoted to calibrated inference; research helpers are not public exports.
* Public embedding, alignment, cluster, and bootstrap engine code is unchanged
  from 0.0.4.9000. Updated evidence and the development roadmap.

# driftmapR 0.0.4.9000

* Added `paired_unit_design()` and a serial `bootstrap_drift()` engine for
  declared exchangeable measurement units or equal-width blocks, with optional
  strata and identical sampled multiplicities across periods.
* Refits preprocessing/embeddings and temporal alignment; establishes every
  replicate's baseline in the observed frame without scaling.
* Added independent L'Ecuyer-CMRG streams and isolated draw planning that leaves
  caller RNG state, including cached Box-Muller normals, untouched.
* Attempts exactly B draws; preserves failed stages, periods, counts, messages,
  warnings, and available spectral/alignment diagnostics without retrying failures.
* Added conditional means, covariance, type-7 quantiles, Monte Carlo mean SEs,
  success gates, provenance, and optional raw replicate retention.
* Added independent draw/refit/summary tests and a reproducible paired-unit pilot.
* Original feature data with unit observed weights are required. General
  resamplers, cluster refitting/stability, and calibrated confidence regions
  remain unimplemented; sample quantiles are not inferential confidence limits.

# driftmapR 0.0.3.9000

* Added `embed_snapshots()` for centered PCA and classical MDS from repeated
  numeric features, and classical MDS from labeled dissimilarity snapshots.
* Retains original inputs, Gram spectra, fitted models, and preprocessing;
  reports retained inertia, truncation-boundary ties, and MDS reconstruction.
* Added common or period-specific standardization and explicit feature weights
  that reproduce column multiplicities without adding dependencies.
* Non-Euclidean dissimilarities error by default; explicit truncation warns and
  reports negative inertia. Rank-deficient two-dimensional maps are rejected.
* Added independent adapter/kernel tests, a reproducible high-dimensional
  simulation, and a runnable embedding vignette.
* Defined fixed-entity bootstrap targets, paired resampling units, common frames,
  failure accounting, and future calibration gates. The resampling engine and
  inferential intervals remain unimplemented.

# driftmapR 0.0.2.9000

* Added `match_clusters()` for one-to-one correspondence between supplied labels
  in adjacent snapshots, maximizing shared-entity overlap counts.
* Added deterministic lexicographic tie resolution and per-selected-link
  alternative-optimum objective margins using the established `clue` solver.
* Added stable IDs, unmatched reasons, noise/missing-label handling, candidate
  split/merge flow diagnostics, matrices, and per-period denominators.
* Thresholds apply before optimization; clusters with no shared evidence never
  inherit identities, and identifiers never revive across an absent period.
* Added independent exhaustive-oracle assignment tests, public API regressions,
  a reproducible cluster simulation, and a correspondence vignette.
* Original labels, alignment, and geometric movement remain unchanged by cluster
  matching. No bootstrap uncertainty or statistical split/merge model is implied.

# driftmapR 0.0.1.9000

* Initial executable development prototype for repeated user-supplied 2-D maps.
* Added a validated `driftmap` object with extensible data/results/settings slots.
* Added previous- and first-reference orthogonal Procrustes fitting using base-R
  SVD, including reflection, translation, optional scale, anchors, and entity churn.
* Added explicit fitted transformations, fit counts, residuals, and rank checks.
* Added adjacent-interval movement tables and entity/fixed anchor distances.
* Added descriptive ggplot2 maps and S3 print/summary/plot methods.
* Added invariant/known-truth unit tests, a reproducible three-period simulation,
  documentation, and a cross-platform CI configuration.
* No cluster correspondence or inferential uncertainty is implemented.
