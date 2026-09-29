# ChatGPT project context

This directory is a local mirror of the ChatGPT project “driftmapR Package”.

- Treat every file under `sources/` as read-only reference material.
- Do not edit, rename, move, or delete synced project files.
- These files may be replaced the next time a task is created from this ChatGPT project.


## Project instructions

# PURPOSE

This Project is the dedicated development workspace for **`driftmapR`**, an R package for aligning repeated low-dimensional representations through time, matching cluster identities across periods, measuring entity-level movement, and quantifying uncertainty in apparent longitudinal drift.

The package must solve a **general statistical/software problem**, not a UN-specific one. UN voting will be a flagship application, but APIs, terminology, tests, simulations, and documentation must remain domain-general.

Goals:

1. Build a substantial package suitable for a computational statistics/data science CV.
2. Reach CRAN-quality engineering standards.
3. Create a credible basis for an **R Journal** article if the contribution proves sufficiently novel.
4. Keep normal use feasible on an ordinary laptop; no GPUs, clusters, or distributed computing.

# CORE PROBLEM

Repeated embeddings \(Z_1,\ldots,Z_T\) are not directly comparable because independently generated coordinate systems may rotate, reflect, translate, or scale even when underlying entities have not meaningfully moved.

`driftmapR` should distinguish **coordinate artifact** from **statistically supported movement**.

Version 0.1 should focus on:

1. temporal alignment;
2. cluster-label correspondence;
3. movement/drift measurement;
4. bootstrap uncertainty and stability.

Do not turn v0.1 into a general dimensionality-reduction framework.

# V0.1 SCOPE

Support:

* PCA-generated coordinates;
* classical MDS-generated coordinates;
* user-supplied coordinates;
* orthogonal/generalized Procrustes alignment;
* first-period, previous-period, and consensus references where defensible;
* changing entity sets across periods;
* cluster-label matching by assignment optimization;
* displacement vectors, movement magnitude, and anchor-distance change;
* bootstrap uncertainty and cluster stability;
* tidy outputs and ggplot2 visualizations.

Defer UMAP adapters, graph-layout adapters, Bayesian posterior adapters, animations, nonlinear manifold alignment, and probabilistic split/merge models unless clearly justified.

# MATHEMATICAL FOUNDATION

For repeated coordinates \(Z_t\in\mathbb{R}^{n_t\times d}\), estimate transformations such as:

$$
R_t^*=\arg\min_R \|Z_{ref}-Z_tR\|_F^2,\qquad R^T R=I.
$$

Where appropriate include translation and optional scaling:

$$
Z_t^*=s_tZ_tR_t+b_t.
$$

For entity \(i\):

$$
\Delta_{it}=Z^*_{it}-Z^*_{i,t-1}, \qquad D_{it}=\|\Delta_{it}\|_2.
$$

Use resampling to estimate uncertainty in movement, direction where identifiable, and cluster membership. Do not make inferential claims without a defined resampling or probabilistic basis.

# SIMULATION & VALIDATION

Simulation is mandatory. Create known-truth scenarios for:

* no true movement;
* global rotation/reflection only;
* selected entities moving;
* whole-cluster movement;
* entity cluster switching;
* cluster split/merge;
* missing/new entities;
* increasing noise;
* varying cluster separation.

Evaluate movement bias/RMSE, interval coverage, false- and true-positive movement detection, angular error where relevant, cluster-matching accuracy, Adjusted Rand Index, cluster stability, runtime, and memory.

Core requirement: **pure coordinate transformations must not appear as entity drift after alignment.**

# PACKAGE API

Prefer a small coherent API and one primary S3 class, tentatively `<driftmap>`.

Candidate functions:

```r
drift_data()
validate_drift_data()
embed_snapshots()
align_snapshots()
match_clusters()
cluster_stability()
measure_drift()
bootstrap_drift()
distance_to_anchor()
plot_drift_map()
plot_trajectory()
plot_cluster_transitions()
plot_drift_ranking()
```

Potential methods: `print()`, `summary()`, `plot()`, `tidy()`, `augment()`.

# SOFTWARE ENGINEERING

Develop production-quality R package software, not disconnected scripts.

Default stack:

* R with tidyverse conventions and native pipe `|>`;
* `usethis`, `devtools`, `roxygen2`, `testthat`;
* `ggplot2`, `pkgdown`;
* Git/version control and CI where useful.

Prefer lightweight dependencies and base R linear algebra where practical. Do not use Rcpp unless profiling demonstrates a real bottleneck.

Target ordinary use around 50–1000 entities, 10–500 original variables, and 2–20 periods.

# DOCUMENTATION

Maintain README, roxygen documentation, package-level and mathematical-methodology documentation, getting-started and simulation/validation vignettes, an applied case-study vignette, NEWS/changelog, and reproducibility information.

# APPLICATIONS

Use synthetic data for tests/examples where possible.

Use UN voting later as a flagship application showing which countries occupy similar multivariate voting positions and which exhibit statistically supported movement. Keep geopolitical labels and policy assumptions outside package internals.

Include at least one second, non-political application before publication claims about generality.

# CRAN / R JOURNAL

Treat CRAN quality as an engineering milestone. Before submission require a clean `R CMD check`, strong documentation, comprehensive tests, reproducible examples, dependency review, stable API, package website, and documented methodology.

For an R Journal paper, establish the software gap through current comparison with relevant packages and literature. Potential framing:

**driftmapR: Alignment and Uncertainty Quantification for Longitudinal Low-Dimensional Representations**

Do not claim novelty without evidence. If another package already solves the intended problem comprehensively, narrow or modify the contribution.

# DEVELOPMENT PHASES

1. **Landscape/specification:** review competing methods/packages; define gap, API, math, simulations.
2. **Package skeleton:** metadata, tests, Git/CI, S3 class.
3. **Alignment engine:** transformations, reference strategies, incomplete overlap.
4. **Movement engine:** displacement, magnitude, direction, anchor distance.
5. **Cluster correspondence:** stable labels and transitions.
6. **Bootstrap uncertainty:** movement and cluster stability.
7. **Simulation study:** controlled validation and failure cases.
8. **Visualization:** drift maps, trajectories, transitions, rankings.
9. **Applications:** UN voting plus a second general example.
10. **Hardening:** tests, docs, benchmarks, edge cases, CRAN checks.
11. **Publication preparation:** only after software maturity and demonstrated contribution.

# WORKING RULES

Treat this as active software development. When asked to continue:

* inspect existing files/code;
* run tests and simulations;
* fix errors;
* create complete scripts/files;
* validate outputs;
* continue through the next logical task.

Do not repeatedly stop for confirmation on routine reversible choices. Ask only when a decision materially changes statistical validity, architecture, or scope.

Never report tests, simulations, CRAN checks, benchmarks, or features as completed unless actually executed.

For corrected R code, provide complete runnable scripts rather than fragments.

At the end of substantial work report:

* **Completed**
* **QA / unresolved**
* **Progress**
* **Next development target**

# SUCCESS CRITERIA

A meaningful CV milestone requires a coherent working API, documented alignment mathematics, tested cluster matching and movement estimation, bootstrap uncertainty, simulation validation, useful visualizations, automated tests, a reproducible repository, and a complete README/vignette.

A credible R Journal submission additionally requires a demonstrated software gap, public package availability, comparison with relevant alternatives, validated methods, performance characterization, and compelling general-use applications.
