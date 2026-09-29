# First bounded bootstrap calibration: initial results

Study date: 2026-09-10. Exact computational engine: driftmapR 0.0.4.9000,
commit 40278981ce680c64d758a00ef0191a2af0c6081f. Protocol and execution code were
frozen at commit d54eb707e7c3a00a631fb4c35a16d1baddd8f2db before generating study
outcomes. Delivery version 0.0.5.9000 adds research code/evidence; the public
computational engine is unchanged.

## Decision

The bounded study is executed and reproducible. **The candidate joint regions
are not calibrated well enough to become a public inference API.** This is a
statistical finding, separate from passing implementation tests. The package's
bootstrap output remains descriptive and conditional on computational success.

The study used 18 fixed entities, two periods, 11 fixed stable anchors, and one
prespecified primary target (E015). E003 and E006 were separate secondary
analyses. Six scenarios each used 80 independent datasets. The leading two
coordinates of the exact expected centered Gram matrix define population
truth; latent coordinates alone do not. Each observed baseline was registered
to the fixed population baseline once, and that same rotation was applied to
all of its bootstrap displacement vectors. No scaling was removed.

Three nominal 95% joint dx/dy regions were frozen: Wald ellipse, empirical
Mahalanobis-error ellipse, and Euclidean bootstrap-error ball. Every region
is centered at the observed displacement. Empirical regions retain bootstrap
bias and are not bootstrap-t. At least 20 valid draws and usable geometry are
required. The production policy additionally requires at least 190/199
successful attempts; the relaxed policy uses the same saved draws without
that success-fraction requirement.

## Primary target results

Coverage below is conditional on region delivery. Each ordinary row has 80
independent outer datasets; the rare-axis production row has only 26 delivered
regions from 80 attempts. All entries concern one entity-transition, not a
simultaneous family of entities.

| Scenario | Production delivery | Wald coverage | Empirical Mahalanobis coverage | Ball coverage |
|---|---:|---:|---:|---:|
| Whole-map null | 80/80 | 65/80 (81.25%) | 65/80 (81.25%) | 69/80 (86.25%) |
| Regular movement | 80/80 | 69/80 (86.25%) | 69/80 (86.25%) | 71/80 (88.75%) |
| Few independent units | 80/80 | 62/80 (77.50%) | 62/80 (77.50%) | 66/80 (82.50%) |
| High noise | 80/80 | 76/80 (95.00%) | 76/80 (95.00%) | 77/80 (96.25%) |
| Rare second axis | 26/80 | 19/26 (73.08%) | 19/26 (73.08%) | 21/26 (80.77%) |
| Dependent units, negative control | 80/80 | 18/80 (22.50%) | 17/80 (21.25%) | 22/80 (27.50%) |

Whole-map-null rejection is 18.75% for both ellipses and 13.75% for the ball,
against a nominal 5%. The corresponding coverage Wilson Monte Carlo intervals
are 71.34–88.29% and 77.03–92.15%. No bootstrap attempts failed in this scenario,
so success selection cannot explain this undercoverage. The higher-noise result
near 95% is limited evidence for that scenario, not a general validity result.
Between-unit independence is deliberately violated in the negative control.
Its poor coverage demonstrates the consequence of that misspecified design;
a clean computational ledger does not validate a sampling assumption.

At 80 datasets, nominal-95% coverage has MCSE about 2.44 percentage points.
Actual MCSE/Wilson intervals are saved for every scenario/target/method/policy.
The much smaller rare-axis delivered subset has substantially larger uncertainty.
No candidate or scenario was selected after outcomes; no cutoffs were retuned.

## Failure selection

All 480 outer attempts were retained. Twelve rare-axis datasets lacked a second
axis and had undefined observed estimators. The remaining 468 datasets received
exactly 199 bootstrap attempts, totaling **93,132**: **91,399 successes and 1,733
failures**. All 1,733 failures omitted every rare unit and failed at embedding;
there were no positive-rare-unit failures, setup errors, or replacement draws.

For rare-axis datasets, 68/80 observed estimators were defined, but only 26/80
passed the production success gate. None of the 39 observed-valid datasets with
K=1 or K=2 rare units passed. Successful bootstrap draws increased the average
rare-unit multiplicity from 2.381 to 2.623 across the same 68 datasets: paired
increase 0.242, MCSE 0.0226. This is an explicit change in the sampled unit mix.
The omission probability is (1-K/12)^12; the recorded failure rates are consistent
with this mechanism. Failed displacement vectors are undefined, never zeros.

Relaxing the gate delivered 68/80 regions. Conditional rare-axis coverage was
44/68 (64.71%) for both ellipses and 50/68 (73.53%) for the ball. Production
coverage-and-delivery yield, using all 80 outer attempts, was only 19/80 (23.75%)
and 21/80 (26.25%); relaxed yields were 55.00% and 62.50%. Yield is an operational
measure, not a coverage probability conditional on delivery.

Primary normalized vector bias changed from (0.0526, 0.0619) among all 68 defined
estimators to (0.0899, -0.0440) among the 26 production-gated estimators. Normalized
RMSE was 0.3769 versus 0.3952. These are selection contrasts with overlapping
cohorts and sizable Monte Carlo uncertainty, not an identified causal effect of
the gate and not evidence that the gate reduces bias or RMSE. Normalization
divides displacement by sqrt(m). Failures of observed estimation have no
fabricated error values.

## Separate post hoc diagnostic

After the frozen analysis, an independent review compared mean bootstrap
covariance with empirical repeated-dataset error covariance for E015. Their
trace ratio was 0.750 in the whole-map null, 0.791 in regular movement, 0.759
with few units, and 1.474 in high noise. This descriptive check supports
prioritizing covariance and finite-sample diagnostics. It does not identify
a single cause, justify a fitted correction factor, or change any region.
`diagnostics.R` reproduces this explicitly post hoc table. In the null,
orthogonally rotating all vectors and covariance matrices cannot change the
zero-target coverage event; registration within the estimator still needs
examination.

## Engineering evidence and limits

The 18 prespecified PCA/classical-MDS audit datasets used identical data and
unit draws. Observed validity, success ledgers, and all region decisions agreed;
maximum saved displacement-vector difference was below 1.3e-13. This equivalence
check does not add 18 independent coverage replications. Main execution plus
audit took approximately 224 seconds with four outer workers on the recorded
Linux environment; each bootstrap call was serial. This is a small-instance
runtime, not a scalability benchmark.

The cumulative archive contains the frozen protocol and source hashes, exact
streams/seeds, analytic targets, every outer checkpoint, full attempt ledgers,
fit diagnostics, selected target vectors, summary CSVs, PNG/PDF figures,
independent accounting checks, tests, and package-check logs. See
`data-raw/calibration-01/README.md` for reproduction. The source tarball follows
normal package conventions and excludes `data-raw`; use the full source tree
in the cumulative archive for the study scripts.

The next milestone is diagnosis of regular-null undercoverage with fresh seeds,
explicit covariance/frame checks, varying independent-unit counts and fixed
anchor geometry, followed by validation of any revised region construction.
Rare-axis and dependence issues require explicit sampling/identifiability
contracts; increasing B alone cannot fix them. Cluster refitting/stability,
changing overlap, selected anchors, first-reference chains, standardized
features, scaling, direction inference, and simultaneous entity regions remain
outside this first calibration study. CRAN/publication readiness is not claimed.

The frozen design follows the aims/data/estimands/methods/performance and Monte
Carlo reporting principles of [Morris, White and Crowther](https://arxiv.org/abs/1712.03198).
