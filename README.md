# driftmapR

Development R package **0.0.8.9000** for aligning repeated two-dimensional maps, measuring relative movement, matching supplied cluster labels, and paired-measurement-unit bootstrap refits.

The package source is in [driftmapR/](driftmapR/). The repository is named `draftmapR`; the R package is named `driftmapR`.

## Use the package

From this repository's root, in R:

```r
install.packages(c("ggplot2", "clue"))
install.packages("driftmapR", repos = NULL, type = "source")
library(driftmapR)
help(package = "driftmapR")
```

Read the [complete command guide](documentation/PACKAGE_GUIDE.md) for all 10 public functions, three S3 methods, arguments, outputs, and limitations. Run the [synthetic-data tour](documentation/package-tour.R) with `Rscript documentation/package-tour.R tour-output`.

## Verified engineering status

On 2026-10-28, native Windows R 4.5.3 passed **2,619 expectations in 147 test blocks**, with no failures, errors, warnings or skips. All nine executable manual-example topics and an installed-package tour covering every export and S3 method passed. A 100-case coordinate-invariance experiment passed. A fresh `R CMD check --as-cran --no-manual`, including vignette rebuilding, returned **0 errors, 0 warnings, 1 NOTE** for prototype maintainer/new-submission/version metadata. The PDF manual was not built.

See [verification evidence and reproduction instructions](validation/2026-10-28/package-api/README.md). These checks do not establish calibrated inferential coverage or CRAN readiness. Bootstrap summaries remain descriptive.

## Recovery and scientific evidence

Recovery provenance and dated operational evidence remain in [recovery/](recovery/). Consult the latest dated completion and preservation records rather than treating earlier partial-checkpoint counts as current execution status. Historical documents remain historical evidence; this API verification did not rerun the frozen scientific study or alter recovery payloads.

Git versions package code, recovery scripts, compact evidence, and source identities. Large scientific/runtime archives and preserved payloads remain outside Git. GitHub alone is not a complete scientific-data backup. Conversation exports are not published here.
