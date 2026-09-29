# Study 02: independent regular-null follow-up

Status: to be frozen after the retrospective diagnostics and implementation tests, before any follow-up panel is generated. This is a study-only protocol; no public confidence-region API is introduced.

## Question and separation of stages

Study 01 found E015 null coverage of 65/80 for both nominal 95% ellipses and 69/80 for the ball at 40 independent paired measurement units. All 15,920 null bootstrap attempts succeeded. Its original source, results and decisions remain unchanged. The new study asks whether finite unit counts, covariance variability, the bootstrap baseline frame, or nonlinear embedding/alignment account for the deficit. It does not estimate a correction factor from study 01.

Before freezing, audit the 80 old null panels: covariance reconstruction, covariance-to-outer-variance ratios, unit occupancy, and correlated 10/20/40-column prefixes of those same panels. These exploratory prefix/frame results are retrospective, not independent replication. Implementation fixtures use seed 777 and dataset ID 999 only.

The confirmation stage uses fresh L'Ecuyer-CMRG streams and a new bootstrap seed namespace. Its design, executable kernel, runner, audit, analysis and shared generator/region definitions are hashed before generating those panels. Checkpoints retain the frozen hashes and full data/draw stream states. No adaptive sample-size increases, draw replacement, covariance inflation, changed region cutoffs, or new primary targets are allowed after inspecting confirmation outcomes.

## Data-generating mechanism and target

Reuse the study-01 regular-null generator verbatim: 18 fixed entities in three groups, two periods, the same fixed latent layout, all latent displacements zero. Each independent measurement unit j has shared Gaussian two-dimensional loadings and temporally correlated Gaussian noise:

X_tj = Z l_j + 0.25 epsilon_tj, with Corr(epsilon_1j, epsilon_2j) = 0.6.

Units are independent and identically distributed. This study deliberately excludes movement, rare-axis and dependent-unit scenarios. It therefore cannot establish alternative coverage, power, robustness to dependent resampling units, or failure-selection behavior under rare structure.

Primary factor: m = 20, 40, 160, 640 units. Generate 240 independent raw panels at each m, 960 in total. All comparisons within a raw panel are paired. Multiple anchors, estimators, targets and bootstrap budgets do not increase the number of independent outer panels.

Use normalized Gram matrices C_t = H X_t X_t' H / m, H = I - 11'/18. Their population expectation is C_0 = (HZ)(HZ)' + 0.25^2 H, independent of m. Coordinates are the two leading eigenvectors multiplied by square roots of their eigenvalues. This equals the public unstandardized PCA geometry divided by sqrt(m). No feature standardization or Procrustes scaling is used. The population target is the displacement of this noisy population embedding after the specified temporal alignment; it is exactly (0,0), not a separately rescaled latent target.

## Anchors and frames

Both anchor sets have 11 entities and are chosen before confirmation outcomes:

- original: E001–E005 and E007–E012, the study-01 anchor set;
- spread: E001, E002, E003, E007, E008, E009, E010, E013, E014, E016, E017.

E015 is the primary target, E003 and E006 are secondary, separately reported. E003 is an anchor in both sets; E015 and E006 are nonanchors. The spread case changes which entities define alignment and therefore changes the estimator, although the null target remains zero. It is a diagnostic comparison, not a data-driven recommendation for choosing anchors.

Observed baseline coordinates are registered to the fixed population baseline using the selected anchors; period 2 is then aligned to that baseline. All transformations are rigid orthogonal fits allowing reflection. A common whole-result rotation leaves null region coverage unchanged. A separate baseline registration for each bootstrap draw can change the covariance of those vectors and is the frame effect being tested.

Three predeclared estimators:

1. `refit_plugin` (primary): full PCA-equivalent embedding refits; bootstrap baseline registered to the observed baseline; bootstrap period 2 aligned to its own registered baseline. This is the existing public bootstrap functional.
2. `refit_oracle` (diagnostic): same observed estimate; each bootstrap baseline registered directly to the population baseline, then period 2 aligned to it. The implementation uses orthogonal equivariance to rotate the entire plugin displacement, verified against a direct oracle refit. It does not align each period independently to its observed counterpart.
3. `tangent_oracle` (diagnostic): linear derivative of the full population Gram-to-displacement functional. Both observed and bootstrap estimates use this linear functional. It uses the true population eigensystem and has the same zero null target, but is a different, unavailable-in-practice estimator. Improved performance here does not validate the full estimator.

## Covariance and linearization checks

For each paired unit form E_j = (Hx_2j)(Hx_2j)' - (Hx_1j)(Hx_1j)'. Differentiate the leading eigenvalues and eigenvectors of C_0, retaining contributions from every discarded eigenspace. Leading eigenvalues must be separated; ties within discarded eigenspaces are allowed. Apply the analytic tangent of anchor centering and orthogonal Procrustes at the null. Denote the resulting target influence by phi_j. Its observed estimate is mean(phi_j); a bootstrap estimate is sum(w_j phi_j)/m.

The exact conditional covariance over all multinomial unit draws is

S_exact = sum_j (phi_j - mean(phi))(phi_j - mean(phi))' / m^2.

There is no division of empirical bootstrap covariance by B. Retain the embedding and alignment influences separately, reporting their covariance traces and the twice-cross-covariance trace; their sum must equal the total. Compare empirical tangent covariance at B=399 with S_exact to isolate finite-B covariance noise. Finite differences at h=1e-4 and h/2 validate the analytic derivative in reserved implementation fixtures only.

## Bootstrap budget, failures and candidate regions

Exactly 399 planned paired-unit draws per raw panel, shared across anchors and estimators. Primary results use all 399; a secondary paired diagnostic uses the fixed first 199 draws. No second resampling run is used for the prefix. Counts sum to m for every draw. Each draw records its full RNG stream and feature multiplicities.

Every anchor/estimator has a 399-row planned ledger with `attempted`, `success`, failure stage and message. An undefined observed estimator has no attempted bootstrap fits, but retains all planned ledger rows and all outer estimate/region placeholders. A failed draw remains failed and is never redrawn. An oracle-only registration failure never invalidates a valid plugin draw. Tangent and full estimators have their own success ledgers; their differing domains are not silently pooled. Record warnings. Unexpected runner/infrastructure errors stop the run and permit exact checkpoint resume, not scientific failure replacement.

Production delivery requires a defined observed estimator, at least 20 valid draws and at least 95% successful draws within the applicable budget. Reuse study-01 region code without modifications: 95% Wald ellipse with chi-square(2) cutoff; empirical Mahalanobis ellipse with type-7 95% quantile of uncentered bootstrap errors; and Euclidean ball with the analogous norm quantile. Ellipses require minimum/maximum covariance eigenvalue ratio greater than 1e-8; zero-radius balls are unavailable. These are experimental candidate regions, not bootstrap-t or calibrated confidence regions.

Report conditional coverage among delivered regions, delivery / 240 and covered-and-delivered / 240 (operational yield). Undelivered outcomes never become covered. Report geometry availability separately from the success gate. Retain actual failure counts even if all are zero; no rare-failure conclusions can be drawn from a regular-only follow-up.

## Analysis, precision and audits

Primary comparison: E015, original anchors, refit_plugin, B=399 across m. Other methods, anchors and targets are separately labeled paired diagnostics. Report exact denominators, Wilson 95% Monte Carlo intervals and binomial Monte Carlo standard errors. At true coverage .95 and M=240, MCSE is about 1.4 percentage points; this is a bounded study, not proof of exact nominal coverage. These Monte Carlo intervals quantify simulation precision, not uncertainty regions for entity displacement. No multiplicity-adjusted confirmatory hypothesis family is claimed.

Report mean bootstrap covariance / independent outer empirical covariance by trace and generalized eigenvalues, with delete-one-outer-panel jackknife MCSE for the trace ratio; outer mean displacement bias and RMSE; covariance variability and observed Mahalanobis statistics. Covariance comparisons use exactly matched observed-valid panels with finite bootstrap covariance, state their denominators and report delivered counts separately; this covariance diagnostic cohort is not silently described as the production coverage cohort. Deleting an outer panel recomputes both numerator and denominator. Ratios near one alone do not establish region coverage.

Within-panel contrasts use paired coverage indicators and their empirical standard error, with intersection denominators for conditional coverage and all 240 panels for delivery/yield. Compare plugin versus oracle baseline, full versus tangent, original versus spread anchors, and 199 versus 399 draws. Never calculate a difference standard error by treating these as independent samples. No fitted multiplicative covariance correction is evaluated on these same panels.

The fast study-only centered-Gram kernel is used to bound computation. Before running, test it against public PCA and bootstrap on reserved fixtures. During confirmation, the first three predeclared datasets at every m and both anchor sets (24 analyses) run the full public B=399 bootstrap using identical draw streams. Require all observed/replicate target vectors to agree within 1e-9 normalized units, identical weights/streams and exact success-ledger agreement, including direct public-coordinate oracle reconstruction. Any disagreement aborts the confirmation run for investigation; do not silently switch implementations.

Mechanical validation reconstructs all region outputs from saved vectors, reconciles every planned/attempted/success/failure denominator, validates count sums and stored seeds, verifies covariance decomposition and public audits, and checks frozen source identity. Retain all outputs and independent study-01 evidence.

## Seed and execution boundary

Settings are fixed in model.R: data master seed 260920; L'Ecuyer-CMRG / Inversion / Rejection; scenario-major m order followed by dataset IDs 1..240 and nextRNGStream between datasets. Bootstrap seed = 2400000 + m-index * 10000 + dataset ID. This namespace is disjoint from study 01 and the retrospective prefix bootstrap namespace. Four outer workers, serial draws within each panel, with mc.set.seed=FALSE because every stream is explicit. The frozen audited engine is driftmapR 0.0.5.9000, whose public R code is unchanged from 0.0.4.9000.

A git freeze commit and per-source hashes record the boundary. Results, mechanical validation and narrative may be added after execution; scientific source/analysis changes require a disclosed amendment. Regardless of outcomes, this null-only follow-up will not introduce a public confidence-region API.
