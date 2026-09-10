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
