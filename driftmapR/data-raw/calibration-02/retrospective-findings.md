# Diagnosis before the independent study-02 freeze

These analyses reuse study-01 outcomes and are exploratory. They are not new confirmation data and do not change the original study's results.

## Covariance reconstruction

For primary E015 in the 80 original regular-null panels, the mean bootstrap covariance trace was 0.7496 times the independent outer empirical covariance trace (delete-one-panel jackknife MCSE 0.0916). The generalized directional ratios were 0.7305 and 0.7723: the discrepancy was broadly present in both directions, not merely a rotated covariance ellipse. Bootstrap covariance-trace CV was 0.270. Mean observed squared Mahalanobis error was 3.040 and its empirical 95th percentile 8.768, compared with the Wald cutoff 5.991.

Observed mean displacement was (0.005, -0.042) in the original coordinate units, with component Monte Carlo SEs (0.031, 0.028). These outcomes do not isolate a dominant systematic bias. Replacing individual covariances by the across-panel average raised retrospective Wald coverage from 81.25% to 90%; using a leave-one-panel-out outer covariance gave 93.75%. Those diagnostic covariance estimates use other simulated panels and are not deployable replacements or fitted corrections.

All 240 target/panel covariance and quantile reconstructions agreed with stored study-01 results within numerical tolerances. Mean distinct bootstrap unit count was 25.4747 versus multinomial expectation 25.4707. All null draws succeeded. No defect was found in paired sampling, multiplicities, covariance divisor, or region reconstruction; failure selection cannot explain this null deficit. The factor m/(m-1)=1.0256 at m=40 is too small to explain a trace ratio near .75 by itself.

## Prefix and frame diagnostic

Regenerated only the existing 80 study-01 regular-null panels and used their first 10, 20, or 40 measurement columns. The m=40 bootstrap reused its original seed and all 80 stored unit-count matrices, coverage outcomes and normalized region areas agreed. Prefix datasets are correlated with one another and with the already-inspected study; counts below are descriptive.

Primary E015, original anchors, B=199:

| Unit count | Full plugin Wald coverage | Full oracle-frame coverage | Population-tangent coverage |
|---|---:|---:|---:|
| 10 | 63/80 (78.75%) | 64/80 (80.00%) | 66/80 (82.50%) |
| 20 | 65/80 (81.25%) | 65/80 (81.25%) | 69/80 (86.25%) |
| 40 | 65/80 (81.25%) | 65/80 (81.25%) | 70/80 (87.50%) |

At m=40, changing the bootstrap baseline from observed to population barely changed the covariance ratio: 0.749600 to 0.749591. A common rotation of the whole result cannot change null coverage; the audit additionally checked the distinct operation of draw-specific frame refitting. This result does not support baseline registration as the principal cause in this setting.

The tangent covariance ratio was 0.8243 at m=40. Undercoverage persists after replacing nonlinear embedding/alignment by a population derivative, so nonlinear refitting alone is not a sufficient explanation. Finite-unit distributional effects, random covariance estimation, and variation in the finite set of 80 outer panels remain plausible contributors. The prefixes do not establish a monotonic unit-count trend in mean covariance ratios.

With the spread anchors at m=40, full plugin Wald coverage was 69/80 and tangent coverage 71/80; the full covariance ratio remained 0.7648. Anchor geometry can affect the estimator but did not remove the deficit in these inspected panels. The spread choice remains a prespecified diagnostic factor for the fresh study, not a selected cure.

For the m=40 tangent control, empirical B=199 covariance trace divided by the exact conditional multinomial covariance trace averaged 0.9870 (outer MCSE 0.0081) with original anchors and 0.9872 (MCSE 0.0091) with spread anchors. Thus finite-B covariance estimation is close to its exact conditional target in these panels, while that conditional target itself can differ from outer sampling variance.

No regular-prefix observed or bootstrap fits failed. The complete prefix/frame outputs, exact tangent covariance components, paired contrasts and covariance review accompany the delivery.

## Decision at freeze

Retain all three unchanged candidate regions; introduce no covariance multiplier. Use independent panels across a wider m range with paired oracle-frame and population-tangent controls, exact conditional tangent covariance, and nested B=199/399 budgets. The fresh study will quantify Monte Carlo precision and separate these mechanisms without reusing the original outcomes as confirmation. No public confidence API will be released on the basis of this null-only study.
