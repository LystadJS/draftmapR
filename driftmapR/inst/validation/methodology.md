# Implemented mathematics and prototype contract

Version 0.0.3.9000; 2026-09-10. Alignment/movement mathematics are unchanged.

## Estimand

The output is descriptive movement relative to a selected reference map and
fitting entities. The model removes global translation, rotation, reflection,
and optionally isotropic scaling. Those degrees of freedom cannot simultaneously
be treated as recoverable global substantive motion without external information.
Unrelated/nonisometric changes between independently fitted embeddings are not
resolved by this rigid/similarity transformation.

## Alignment

For each source time t and reference r, join observed entities by their exact IDs.
If `anchors` is supplied, restrict fitting to the shared subset. Let X and Y be
the source and reference fitting matrices; subtract their separate column means.

With `crossprod(Xc, Yc) = U D V^T`, the unrestricted orthogonal least-squares
solution is `R = U V^T`. For optional scale use
`s = sum(diag(D)) / sum(Xc^2)`; otherwise `s = 1`. The translation is
`b = mean(Y) - s * mean(X) %*% R`. Transform every source point with
`z_aligned = s * z_raw %*% R + b`, including entities absent from the reference.
No determinant correction is applied: reflections are allowed.

For numerical conditioning the implementation separately scales centered X and
Y by their maximum absolute elements before forming the cross-product. The
rotation is unchanged and the scale expression restores those factors.
Transformations are applied using centered arithmetic, mathematically equivalent
to the stored affine expression. The first map is an unchanged identity frame.

This is the established Procrustes problem, also implemented by
[vegan](https://vegandevs.github.io/vegan/reference/procrustes.html). Normalization
and default scaling differ between interfaces; comparisons must use the same
objective, fitting entities, centering, and scaling choices.

## Identifiability and numerical policy

Require at least 3 fitting entities. In two dimensions both centered fitting
matrices and their cross-covariance must have smallest/largest singular-value
ratio greater than `rank_tol` (default 1e-10). This deliberately rejects
near-degenerate fits whose orientation would be unstable. A nonsingular source
and target alone do not guarantee nonsingular cross-covariance. Error messages
include the compared periods. Overflow, underflow to zero target spread, and
nonfinite transformation/results raise errors; arbitrary numerical repairs are
not applied. Ordinary-scale invariant tests use 1e-10 tolerance, comfortably
above double-precision rounding accumulated over small matrix operations.

Raw-to-reference rotation/translation list columns are directly reusable.
`singular_values` contain values of the **normalized** cross-covariance, only
for rank diagnostics; they are not singular values on the original coordinate
scale. `condition_number` is the normalized cross-covariance singular-value
ratio. RSS uses original reference coordinate units. RMSE is sqrt(RSS/n_matched),
not a residual standard-error estimator with degrees-of-freedom adjustment.
Disparity is RSS / sum(centered_target^2). The identity row uses zero matched
count, zero RSS, and missing RMSE/disparity/conditioning.

## Time and changing entities

`previous` fits raw t to already aligned t-1. `first` fits raw t to unchanged
first-period coordinates. Matching need not use a common intersection across all
times; each pair must independently satisfy count/rank conditions. A later map
can therefore be connected by a chain of overlap even when it has too little
overlap with the first. Chaining can accumulate alignment error and reference
changes. There is no generalized/consensus reference in this implementation.

The explicit `periods` vector is the complete expected schedule and can encode
irregular intervals. Missing declared periods are errors. No frequency is guessed
from numeric gaps. No dates are converted to arbitrary categorical order.

## Movement and anchor distance

For an entity present in adjacent scheduled maps, delta is the aligned coordinate
difference and distance its Euclidean norm. A numerically scaled hypotenuse
avoids unnecessary overflow when computing a norm. The returned table keeps the
original time class. It omits transitions lacking either endpoint and never
bridges a missing observation. Durations are not used to normalize displacement.

`distance_to_anchor()` reports Euclidean distance to a fixed coordinate or to an
entity observed in every period. An entity anchor can itself move; it is not
implicitly a registration anchor. Anchor-distance change and directional
uncertainty are not computed.

## Object and downstream invalidation

The primary S3 class is `driftmap`. Raw and aligned tables have exactly two
canonical numeric coordinate columns with explicit entity/time/index keys.
`drift_data()` permits caller-supplied original data and metadata without
interpreting them. `embed_snapshots()` populates these slots through the explicit
PCA/classical-MDS contract below. Movement and bootstrap slots remain available for later results.
Measurement returns tables and does not implicitly mutate objects. Re-alignment
replaces transforms/aligned data and clears stored movement and bootstrap values.
`match_clusters()` populates the cluster membership table and its diagnostics;
original labels remain in the raw coordinate table. Matching leaves geometric
alignment/movement unchanged and clears bootstrap output. Re-alignment retains
membership-based correspondence because it does not depend on coordinate values.
See `cluster-correspondence.md` for the separate assignment objective.

## Implemented embedding adapters

Let X_t be the entity-by-feature matrix, H_t its centering operator, S_t the
diagonal matrix of declared sample SDs (identity without standardization), and
W the diagonal matrix of nonnegative feature weights. The geometry is
A_t = H_t X_t S_t^-1 W^1/2. Weights are shared across periods and not normalized.
Integer weights reproduce repeated columns; zero-weight columns have no
geometric effect and receive scale one. This algebra does not imply a sampling
distribution. Raw centers and reference SDs are stored separately from the
`prcomp` model, which acts on scaled/weighted input.

PCA uses `stats::prcomp`, retaining score columns U_2 D_2. Stored Gram eigenvalues
are squared singular values from the complete SVD spectrum; implicit zero
eigenvalues beyond min(n_t, p) are omitted. The model's component variances use
divisor n_t - 1. First-period scaling uses that period's SDs for every map;
pooled scaling uses all observed entity-time rows with equal row weight. Period
scaling recalibrates separately and can erase substantive dispersion changes.
Every fit centers on its own entities, so absolute feature means are outside
the movement estimand.

For classical MDS, B_t = -0.5 H_t (D_t elementwise squared) H_t. A symmetric
eigendecomposition supplies coordinates V_2 Lambda_2^1/2. The kernel normalizes
distances by their maximum before squaring and restores physical units after
decomposition. Unrepresentable spectra or coordinates raise errors with
rescaling advice. Matrices must be finite, nonnegative, hollow, symmetric to
floating-point tolerance, and labeled consistently. Packed `dist` objects are
validated before conversion to prevent recycling malformed values. For Euclidean
feature distances, B_t = A_t A_t^T, so identified PCA/MDS planes are equivalent
up to an orthogonal transformation.

Two eigenvalues must exceed `eigen_tol` times the largest absolute eigenvalue.
MDS eigenvalues below the negative of that threshold are material negatives:
default handling errors; explicit truncation warns and uses the two leading
positive axes. No Cailliez/Lingoes correction is implemented. The full spectrum,
material positive/negative counts, negative fraction of absolute inertia,
retained positive/absolute inertia, and MDS pairwise-distance RMSE quantify the
approximation. Tiny negative roundoff contributes to the negative fraction but
not the material count. Fractions use the full spectrum.

The normalized gap (lambda_2 - lambda_3) / max(abs(lambda)) diagnoses truncation
instability. A boundary tie warns; a tie between retained axes alone does not,
because the complete plane remains identified. This is a numerical diagnostic,
not an inferential eigengap test. Discarded dimensions or unrelated changes in
the fitted plane cannot be repaired by temporal alignment. Each period needs
at least three entities and effective rank two; downstream overlap constraints
are checked separately.

The implementation follows the documented
[PCA](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prcomp.html) and
[classical scaling](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/cmdscale.html)
geometry. See `bootstrap-specification.md` for the separate, unimplemented
resampling design and calibration requirements.

## Limits of this validation stage

No bootstrap, interval coverage, false-positive rate, power, or inferential
movement detection is reported. A single reproducible synthetic demonstration
and deterministic unit tests establish central executable behavior, not broad
statistical calibration. Known stable anchors in that demonstration are supplied
by simulation truth; their exact recovery cannot be generalized to unknown real
anchors. The all-shared fit is included to expose this distinction.
