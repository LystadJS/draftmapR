# Development roadmap

Version 0.0.8.9000; updated 2026-09-11.

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
| Bootstrap specification | Paired-unit contract implemented; extensions remain unfrozen | Fixed entities, paired units, dependence declarations, preprocessing conditioning, common baseline frame, failure accounting, inference gates. |
| Bootstrap resampling engine | Implemented and tested | Serial reproducible paired-unit draws, complete refits, correct multiplicities, common vector frame, structured failures and conditional resampling summaries. |
| Bootstrap uncertainty/stability | Full-refit studentized candidate implemented; selected secondary deficits did not replicate; sparse-unit non-delivery remains | Broader independently frozen robustness before confidence exports; refitted clustering, unknown assignment mass, explicit denominators. |
| Simulation study | Four studies complete; study05 robustness design frozen, evaluation pending | Independent implementation freeze, full planned denominators, geometry/dependence diagnostics, and untouched evaluation before broader uncertainty claims. |
| Applications | Pending | UN voting and at least one nonpolitical application with reproducible open data. |
| Hardening | Started, far from release | Cross-platform CI run, broader dimensions/edge cases where scoped, dependency audit, maintained examples, stable API, pkgdown, clean checks. |
| Publication | Deferred | Full landscape and alternative comparison, public package, validated uncertainty, complete empirical performance and applications. |

## Next concrete development target

Cluster correspondence is complete for supplied hard labels. The solver and
public API have independent exhaustive-oracle tests; synthetic split/merge
patterns are diagnostic cases, not an implemented probabilistic event model.

The first bounded calibration study is complete: six scenarios, 480 independent
datasets, 93,132 main bootstrap attempts, three prespecified joint regions, and
18 numerical PCA/MDS audit cases. Coverage and failure selection were evaluated
against analytic population-embedding targets. No candidate supports promotion
to a calibrated confidence API: the primary whole-map-null rejection rate was
18.75% for both ellipses and 13.75% for the ball, despite no failed draws.

The independent follow-up is now complete: 960 raw panels at 20/40/160/640
units, 383,040 paired-unit draws and 24 full public-engine audits. Primary Wald
null coverage was 87.08/90.00/95.00/95.42%. Oracle baseline registration made
little difference; mean covariance scale alone was insufficient to explain
small-unit undercoverage. Population-tangent controls improved coverage but
use unavailable population information. Large-unit null agreement is not a
release gate for general uncertainty and does not define a universal minimum m.

Study03 is complete: an exact occurrence-jackknife studentized joint region for
the full refitted estimator, frozen before 800 independent panels and 159,200
planned draws. Primary null coverage at m20/40/160 was 93.33/95.00/96.67%;
movement coverage was 92.50/94.17/94.17%. Small-unit coverage improved through
larger regions, with lower movement detection. E006 null m40 still covered
109/120 and E003 null m160 covered 110/120. Rare-axis production delivered only
2/80 studentized regions. The inference release gate remains closed.

Study04 independently replicated those selected endpoints using 1,120 fresh
panels and 222,880 planned draws. E006/null40 covered 377/400 and E003/null160
covered 379/400; neither deficit met the frozen replication criterion. This is
not an equivalence test. Covariance diagnostics still distinguish covariance
scale from studentization; direct population-frame refitting changed no candidate
coverage decisions. Sparse delivery remained only 8/120, with all 112
non-deliveries assigned explicit causes. Broad uncertainty release remains closed.

Study05 now freezes a bounded robustness design: 31 cells, 1,640 panels, and
326,360 planned draws across retention-boundary gap weakening, graded anchor
change, movement, AR(1) unit-dependence stress, and sparse support. Its generator,
analytic targets, reserved streams, and accounting helpers are tested. No reserved
evaluation panels have been generated. Computational candidate availability is
kept distinct from evaluation-only blocking; declared/clean-anchor targets remain
separate and exact boundary ties are analytic fixtures outside calibration.

Next, implement and validate the runner, collector, diagnostics, full analysis,
and audits against the frozen study05 contract, lock that implementation, and
then run the untouched plan. Dependence-violating cases remain separate from
nominal iid-unit calibration. Do not tune gates, covariance multipliers, budgets,
or candidate definitions on completed studies or engineering coverage outcomes.

Then implement explicit cluster refitting and same-period/temporal matching,
retaining unknown mass from ties, unmatched clusters, and missing labels.
General data-resampler callbacks and weighted base estimators need separate
contracts. Profile memory and dense-MDS cost before claiming large-panel support.

## Scope control

The executable prototype freezes only functions actually implemented. It does
not freeze the unimplemented v0.1 uncertainty/consensus API. Approximate overall
v0.1 progress is **83%**, a planning judgment based on remaining statistical and
engineering work, not a code-line or test-count measure. This session's narrower
prototype objective can be complete while v0.1 remains substantially unfinished.

Before public distribution replace the explicit placeholder author/maintainer
metadata with verified identity; confirm the copyright holder. No remote GitHub
CI execution or public repository is claimed by a local configuration file.
