# Execution addendum 1: omitted paired tangent comparison

Recorded after the scientific freeze while the fixed study was running, before any independent study-02 coverage or covariance outcomes were inspected. The original protocol, source hashes, estimators, cutoffs, data seeds and checkpoints remain unchanged.

The frozen protocol explicitly requires a paired full-versus-tangent coverage comparison. Code review found that `study02_paired_contrasts()` implemented plugin-versus-oracle frame comparisons but omitted that additional predeclared estimator contrast. All individual tangent estimates, regions, coverage and covariance summaries were already implemented and are unaffected.

A separate `supplemental-analysis.R` computes the missing predeclared `refit_plugin` to `tangent_oracle` contrast from the unchanged saved region rows, with the same paired Monte Carlo SE and joint-delivery/full-outer denominator rules. The output is `tangent-contrasts-summary.csv`. Reserved deterministic fixtures verify its pairing and missing-delivery accounting. The supplemental code is committed separately with this addendum; no original frozen file is modified. This is an analysis implementation completion, not a new method, fitted correction or post-outcome hypothesis.

The development report will disclose this addendum alongside the original freeze commit. All primary analysis and mechanical validation remain exactly reproducible from the original frozen code. A passing supplemental test is not evidence of nominal coverage.
