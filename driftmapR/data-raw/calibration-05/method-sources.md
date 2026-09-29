# Study 05: verified methodological source notes

Verified 2026-09-11. These notes support the design rationale; they supply no numerical tuning thresholds and contain no study evaluation results.

## Eigenspace separation

**Primary paper:** Yu, Y., Wang, T., and Samworth, R. J., *A useful variant of the Davis–Kahan theorem for statisticians*, author manuscript, arXiv:1405.0680v1 (2014; journal publication 2015).

- Author-deposited full text: <https://arxiv.org/html/1405.0680v1>
- Stable record: <https://arxiv.org/abs/1405.0680>
- Theorem 2 bounds the distance between selected eigenspaces by a matrix perturbation norm divided by a strictly positive population boundary eigengap. For the leading two-dimensional subspace, the relevant finite boundary is lambda2 minus lambda3. Separation between lambda1 and lambda2 is not required to identify their joint subspace. This supports studying boundary-gap weakening separately from rotations within an already selected plane.
- The theorem also allows an orthogonal registration of the estimated eigenvectors. Such registration controls orientation within a plane; it cannot generally remove error from estimating a different plane.

**Project algebraic deduction, not an additional theorem quoted from the paper:** if lambda1 > lambda2 = lambda3, the top-two projector is not uniquely determined by the matrix. The second selected direction can be any unit vector in the tied eigenspace. A deterministic numerical eigenvector convention does not establish a unique population statistical estimand. Exact boundary ties therefore require explicit target non-identification accounting, separate from numerical fitting failure and separate from nonzero but weak gaps. A tie strictly within the selected top-two space has a different implication: the basis is nonunique while the full selected plane can remain unique.

**Official implementation context:** R `stats::prcomp` uses an SVD of centered/scaled data and documents arbitrary component signs, including differences between builds. This supports treating orientation as a registration issue rather than measured movement. The documentation does not establish validity of the study's confidence regions.

<https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html>

## Dependence and paired resampling

**Official documentation:** R `boot::boot` treats a matrix/data-frame row as one multivariate observation and passes common indices, frequencies, or weights to the statistic. A correctly assembled row can therefore contain all periods of a paired unit.

<https://stat.ethz.ch/R-manual/R-devel/library/boot/html/boot.html>

**Official documentation:** R `boot::tsboot` accepts multivariate series and provides fixed-length, geometric-length, and model-based resampling. Its contract explicitly includes block length, series length, and boundary/end-correction choices. The documentation cites Künsch (1989) and Politis and Romano (1994).

<https://stat.ethz.ch/R-manual/R-devel/library/boot/html/tsboot.html>

These sources support distinguishing ordinary resampling of paired units from dependence-preserving resampling of consecutive multivariate units. A future block procedure must specify the ordered resampling axis, multivariate unit content, block construction and length, boundary treatment, and consistent studentization. Preserving all periods inside each sampled unit is necessary for longitudinal pairing; it does not itself preserve dependence between different units.

**Project algebraic deduction demonstrating the limitation of iid resampling:** for a scalar stationary sequence with autocovariances gamma(h),

Var(mean(X[1:m])) = [m gamma(0) + 2 sum((m-h) gamma(h), h=1,...,m-1)] / m^2.

An ordinary iid empirical resample has conditional mean variance equal to its empirical marginal variance divided by m. It contains no lag-autocovariance terms. Thus ordinary iid resampling is not a generally dependence-valid bootstrap. It can still coincide in special cases, and dependence need not always cause undercoverage. The dependence arm should be interpreted as a deliberately unsupported stress test, not as validation of a block bootstrap or a universal forecast of failure direction.

The statement above is an elementary finite-sample variance calculation, not an application of a block-bootstrap consistency theorem to the full nonlinear PCA/alignment estimator. Dividing a sample size by a scalar effective-sample-size factor is not justified as a correction for this estimator by the sources reviewed here.

## Anchor contamination and target definition

**Project algebraic deduction:** after centering the matched anchors, orthogonal Procrustes minimizes the anchor residual sum of squares. Changing anchor coordinates changes the centering and cross-product used by that objective. Consequently a population fit using contaminated anchors can have a different alignment and displacement target from a fit using known clean anchors. This is a distinction between estimands, even if the sampling uncertainty about each estimator were measured correctly.

The design should distinguish coverage of the full estimator's own population target from displacement relative to a clean-anchor target. A clean-anchor refit is a diagnostic estimator with its own target and failure ledger; it is not a post hoc repair of a failed candidate interval.

## Access limits

The author-deposited eigenspace paper and the official R pages above were read. The publisher pages for Künsch, *The Jackknife and the Bootstrap for General Stationary Observations* (1989), DOI <https://doi.org/10.1214/aos/1176347265>, and Politis and Romano, *The Stationary Bootstrap* (1994), DOI <https://doi.org/10.1080/01621459.1994.10476870>, were inaccessible in this session. Their results are not represented here as independently inspected. They remain background references identified in the verified official `tsboot` documentation.

No external paper reviewed here proves finite-sample calibration of the full driftmapR studentized region, particularly under weak identification, changing anchor targets, or serial unit dependence.
