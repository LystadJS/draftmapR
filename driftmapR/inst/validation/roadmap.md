# Development roadmap

Version 0.0.3.9000; updated 2026-09-10.

| Milestone | State after this session | Acceptance gate |
|---|---|---|
| Essential landscape and prototype contract | Complete; full Phase 0 comparison remains open | Bound prior art and avoid novelty claims. |
| Skeleton and S3 data object | Implemented | Valid package layout, documented exports, key/schedule validation. |
| First alignment engine | Implemented | Transformation invariance; full-rank overlap; first/previous references; diagnostic reconstruction. |
| Initial movement and anchor distance | Implemented | Correct adjacent differences; no gap bridging; preserve time types. |
| First static visualization | Implemented | Plot stored coordinates without fitting; adjacent arrows; general labels. |
| Initial synthetic validation | Executable script provided | Three clusters/periods; motion and churn; truth/estimated comparison with anchor sensitivity. |
| Cluster correspondence | Implemented and tested | Maximum count overlap, preoptimization thresholds, exact canonical ties, objective margins, unmatched reasons, monotonic IDs, and observed-flow split/merge candidate diagnostics. |
| PCA/classical MDS adapters | Implemented and tested | Explicit preprocessing/weights, common schema, labeled distance input, retained models/spectra, rank/tie and negative-eigenvalue diagnostics. |
| Consensus/generalized alignment | Pending | Define incomplete-overlap objective, convergence, frame constraint, reference sensitivity, and numerical tests. |
| Bootstrap specification | Defined; proposed API remains unfrozen | Fixed entities, paired units, dependence declarations, preprocessing conditioning, common baseline frame, failure accounting, inference gates. |
| Bootstrap resampling engine | **Next implementation** | Serial reproducible paired-unit draws, complete refits, correct multiplicities, common vector frame, structured failures and conditional resampling summaries. |
| Bootstrap uncertainty/stability | Pending validation | Calibrated displacement-vector regions and null behavior; refitted clustering, unknown assignment mass, explicit denominators. |
| Simulation study | Pending | Many seeds and noise/separation levels; bias/RMSE, coverage, false/true positives, angular error, label accuracy/ARI, runtime and memory. |
| Applications | Pending | UN voting and at least one nonpolitical application with reproducible open data. |
| Hardening | Started, far from release | Cross-platform CI run, broader dimensions/edge cases where scoped, dependency audit, maintained examples, stable API, pkgdown, clean checks. |
| Publication | Deferred | Full landscape and alternative comparison, public package, validated uncertainty, complete empirical performance and applications. |

## Next concrete development target

Cluster correspondence is complete for supplied hard labels. The solver and
public API have independent exhaustive-oracle tests; synthetic split/merge
patterns are diagnostic cases, not an implemented probabilistic event model.

Implement the serial paired-measurement-unit resampling engine against
`bootstrap-specification.md`, starting with retained original feature data and
the tested PCA/classical-MDS adapters. Require an explicit scientific sampling
design, use shared multiplicities through time, orient each replicate baseline
without scaling, and refit temporal alignment. Return replicate vectors and
structured failures before adding inferential labels. Preserve caller RNG state
and test repeated draws, rank failures, and common-frame invariance.

Then run independent null/movement datasets to calibrate vector uncertainty and
cluster stability. Coordinate jitter, generic entity-row bootstrap, and positive
lower percentiles of displacement norms do not satisfy this gate. Supplied
dissimilarities need an explicit underlying-data/model resampler.

## Scope control

The executable prototype freezes only functions actually implemented. It does
not freeze the unimplemented v0.1 uncertainty/consensus API. Approximate overall
v0.1 progress is **55%**, a planning judgment based on remaining statistical and
engineering work, not a code-line or test-count measure. This session's narrower
prototype objective can be complete while v0.1 remains substantially unfinished.

Before public distribution replace the explicit placeholder author/maintainer
metadata with verified identity; confirm the copyright holder. No remote GitHub
CI execution or public repository is claimed by a local configuration file.
