# Study 03 methodological review: finite-unit studentization

Status: specification review before independent calibration. No calibration result is assumed in this note.

## Candidate and estimand

Use a pointwise two-dimensional bootstrap studentized region for the **full** normalized PCA/classical-MDS plus temporal orthogonal-Procrustes displacement. The measurement unit is one matched feature column across every time period; all deletions and bootstrap draws preserve that pairing. Entities and anchor choices remain fixed.

For each observed dataset, let R0 be its first-period embedding. Freeze R0 as the common registration reference for all original, bootstrap, and delete-one fits in that dataset. Define G(P; R0) as follows: recompute both period embeddings from distribution P, temporally align the second to the first using the declared anchors, register the first directly to R0, then rotate the entire displacement vector into R0. The reference is fixed; embeddings and temporal alignment are refitted. Never independently align each period to its observed counterpart.

All jackknife fits register their baseline **directly to R0**. Registering an inner fit to its bootstrap parent and then to R0 is a different finite-sample procedure because Procrustes registration need not compose transitively after deformation. It must not silently substitute for this specification. The unchanged outer bootstrap can still match the public package engine.

Write the full observed estimate as d_hat = G(P_hat; R0). If A is the population baseline and B = R0, the target expressed in the observed chart is d_pop Q(A, B), where d_pop is the population full-estimator displacement. Registering all observed-chart quantities once to the population chart gives d_pop, because the unique nonsingular orthogonal registration satisfies Q(A, B) Q(B, A) = I. Translation cancels in displacement. For row-vector estimates, a common rotation Q changes covariance to Q' S Q. This argument applies to nonzero movement as well as the null; inverse-registration and covariance-equivariance tests should verify it numerically.

Population truth must include the embedding operator, centering, noise contribution to population eigenvalues, anchor choice, and temporal alignment. It is generally different from bare latent-coordinate movement. The observed reference is data-derived, so the procedure is an empirically calibrated candidate; these definitions alone establish neither second-order accuracy nor finite-sample coverage for the embedding functional.

## Exact occurrence jackknife

Let m be the number of paired measurement units and w_j their integer multiplicities in a parent dataset, with sum(w_j) = m. For the observed dataset all w_j = 1. For each j with w_j > 0, compute d_minus_j = G(P_(w-e_j); R0) by removing **one occurrence**, not the whole distinct unit.

The normalized leave-one Gram matrices divide their weighted sums by m - 1. The parent Gram matrices divide by m. The number of positive weights is a computational count and never replaces m in either denominator.

Define the occurrence-weighted leave-one mean and covariance:

    dbar_minus = sum_j w_j d_minus_j / m
    S_J(w) = (m - 1) / m * sum_j w_j
             (d_minus_j - dbar_minus)(d_minus_j - dbar_minus)'

Identical occurrences have identical delete-one results, so computing each positive-count deletion once and weighting by w_j is exactly equivalent to expanding the m occurrences. This is an exact computational reduction, not an infinitesimal-jackknife approximation. The covariance estimates sampling variance of the displacement estimator and receives no additional division by m.

Calculation oracle: for an ordinary bivariate sample mean, d_minus_j = (m d_hat - u_j)/(m - 1); substitution gives S_J = sample_covariance(u) / m. The same identity must hold for expanded duplicate samples. The finite-n Gaussian mean has a Hotelling statistic with cutoff 2(m - 1)/(m - 2) times an F(2, m - 2) quantile. That fact is a test fixture for scaling and quadratic forms, **not** the proposed cutoff for the nonlinear drift estimator. [NIST's Hotelling reference](https://www.itl.nist.gov/div898/handbook/pmc/section5/pmc543.htm).

## Studentized joint region

For each fixed planned bootstrap draw b, recompute the full d_b = G(P_b; R0) and its exact occurrence-jackknife covariance S_b = S_J(w_b). Form

    T_b = (d_b - d_hat)' S_b^(-1) (d_b - d_hat).

Use the prespecified empirical 0.95 quantile q of valid T_b values, with the quantile convention and success gate frozen before evaluation. The observed region is

    C = {theta : (theta - d_hat)' S_hat^(-1)
                    (theta - d_hat) <= q},
    S_hat = S_J(1, ..., 1).

Solve the positive-definite quadratic forms using stable linear algebra. The region area in two dimensions is pi * q * sqrt(det(S_hat)). Keep centering at d_hat and keep T_b centered at d_hat; subtracting the bootstrap mean would define another method. Do not import a fitted inflation factor, replace the bootstrap quantile by an F cutoff, clip large pivots, regularize singular covariances, or silently add bias correction.

Studentized bootstrap methods require a variance estimate for the observed statistic and for each bootstrap replicate; the official boot documentation explicitly distinguishes these inputs. The two-dimensional quadratic construction here extends that principle, while its performance for this full embedding estimator remains the study question. [Official boot.ci documentation](https://stat.ethz.ch/R-manual/R-devel/library/boot/help/boot.ci.html). The official empirical-influence documentation distinguishes ordinary delete-one jackknife from numerical infinitesimal and regression approximations; this candidate uses full ordinary delete-one refits. [Official empinf documentation](https://stat.ethz.ch/R-manual/R-devel/library/boot/html/empinf.html).

## Failure contract

- Preserve every planned outer dataset and every planned bootstrap draw; never redraw until success.
- A required observed leave-one failure makes the observed jackknife covariance unavailable. Do not estimate covariance from only the successful leave-one fits.
- A required positive-count bootstrap deletion failure makes that draw's studentized pivot unavailable. Record both its distinct deletion count and its occurrence multiplicity. Zero-count deletions are not required.
- Record embedding, rank, alignment, registration, leave-one, covariance, pivot, and region-gate failures separately. Preserve warning text, parent draw identifiers, failed deletion identifiers, and numerical diagnostics.
- A zero, nonfinite, or singular covariance is a failure, not zero uncertainty. Apply the frozen positive-definiteness/condition threshold consistently to observed and bootstrap covariances.
- Report planned, attempted, defined, gated, and delivered denominators explicitly. Conditional coverage among delivered regions and unconditional covered-region yield answer different questions. Keep the no-region outcome visible.
- If successful pivots alone determine q under a delivery gate, state that the quantile is conditional on those successful pivots. A high success fraction does not prove absence of failure-selection bias; compare failure rates and relevant unit-count diagnostics, and label a zero-failure finding as specific to the simulated cases.

## Required independent calibration evidence

Freeze code, protocol, source hashes, seed plan, cases, unit counts, outer sample sizes, bootstrap budgets, targets, tolerances, quantile convention, and failure gate before producing fresh evaluation data. Preserve earlier studies unchanged. Use genuinely fresh measurement panels, and use common planned bootstrap weights to compare the new method with full-estimator bootstrap-Wald and jackknife-Wald controls.

Report null coverage and zero-exclusion rate; report movement coverage and zero-exclusion power separately. Each region is joint over dx and dy for one entity/time pair, not simultaneous across entities. Use outer-dataset Monte Carlo standard errors and paired outer-dataset uncertainty for comparisons. Retain region area, cutoff distributions, covariance variation, failure ledgers, and computational cost. Large cutoffs or regions are outcomes to inspect rather than truncate.

Meaningful pre-freeze tests include: sample-mean covariance identity; expanded-versus-compressed multiplicities; m versus m-1 normalization under nonzero movement; direct fixed-reference non-null leave-one reconstruction; rigid rotation/reflection covariance equivariance; inverse registration of population and observed frames; failed observed deletion; failed bootstrap deletion with multiplicity greater than one; singular covariance; insufficient valid pivots; seed and failure-ledger reproducibility; and public-engine agreement for the unchanged full outer estimator.

Even successful bounded results would support only the tested iid paired-unit settings. Near-eigenvalue ties, rank instability, inappropriate anchors, dependent measurement units, changing entity sets, and sparse-unit failure selection remain distinct coverage risks unless included in the frozen design.
