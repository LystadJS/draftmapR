# Run after installing driftmapR. These are resampling summaries, not confidence
# intervals or a significance test. The sampling assumption is part of the model.
library(driftmapR)

set.seed(260914L)
entity <- sprintf("E%02d", 1:12)
positions <- cbind(seq(-2, 2, length.out = 12), rnorm(12))
features <- sprintf("f%02d", 1:8)
# Four independently generated measurement units, each with two columns.
loadings <- lapply(1:4, function(i) diag(2) + matrix(rnorm(4, sd = 0.18), 2))
panel <- do.call(rbind, lapply(1:3, function(period) {
  latent <- positions
  latent[12, ] <- latent[12, ] + (period - 1) * c(0.35, -0.2)
  measured <- do.call(cbind, lapply(loadings, function(x) latent %*% x))
  colnames(measured) <- features
  data.frame(entity, time = period, measured, check.names = FALSE)
}))
design <- paired_unit_design(
  units = stats::setNames(rep(paste0("unit", 1:4), each = 2), features),
  assumptions = paste(
    "Simulated measurement units have independently and identically generated",
    "loading matrices. Both columns and all entities/periods within a unit",
    "remain dependent; entities and observed availability are conditioned on."
  )
)
fit <- embed_snapshots(panel, features = features, method = "pca") |>
  align_snapshots(anchors = entity[1:11])
result <- bootstrap_drift(fit, design, B = 20L, seed = 914L,
                          keep = "replicates")
result$bootstrap$summary
result$bootstrap$attempts

# Norm quantiles describe the empirical distribution among successful draws.
# Their lower endpoint must not be interpreted as evidence against zero drift.
result$bootstrap$quantiles
stopifnot(nrow(result$bootstrap$attempts) == 20L,
          all(result$bootstrap$attempts$success))
