# Complete runnable tour of the exported driftmapR 0.0.8.9000 API.
# Install driftmapR first, then run: Rscript documentation/package-tour.R output-dir
library(driftmapR)
args <- commandArgs(TRUE)
output <- if (length(args)) args[1] else file.path(tempdir(), "driftmapR-tour")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
output <- normalizePath(output, winslash = "/")
expected_exports <- c("align_snapshots", "bootstrap_drift", "distance_to_anchor",
  "drift_data", "embed_snapshots", "match_clusters", "measure_drift",
  "paired_unit_design", "plot_drift_map", "validate_drift_data")
stopifnot(identical(sort(getNamespaceExports("driftmapR")), sort(expected_exports)))

# 1. Known movement, obscured by rotation and translation.
first <- data.frame(entity = letters[1:5], time = 1,
                    x = c(0, 3, 0, 2, 1), y = c(0, 0, 3, 2, 1))
truth <- first
truth$time <- 2
truth$x[5] <- truth$x[5] + 0.8
truth$y[5] <- truth$y[5] + 0.6
rotation <- matrix(c(0, 1, -1, 0), 2, byrow = TRUE)
second <- truth
second[c("x", "y")] <- sweep(as.matrix(truth[c("x", "y")]) %*% rotation,
                              2, c(7, -4), "+")
map <- drift_data(rbind(first, second), periods = 1:2)
validate_drift_data(map, check_overlap = TRUE, anchors = letters[1:4])
fit <- align_snapshots(map, reference = "previous", anchors = letters[1:4])
fit_first <- align_snapshots(map, reference = "first", anchors = letters[1:4])
movement <- measure_drift(fit)
stopifnot(abs(movement$distance[movement$entity == "e"] - 1) < 1e-10,
          max(movement$distance[movement$entity != "e"]) < 1e-10,
          isTRUE(all.equal(movement, measure_drift(fit_first))))
print(fit)
info <- summary(fit)
stopifnot(info$n_entities == 5L, info$aligned)
fit$movement <- movement # Explicit storage: measure_drift() itself does not mutate fit.
anchor_distance <- distance_to_anchor(fit, "a")
fixed_distance <- distance_to_anchor(fit, c(0, 0))
stopifnot(all(anchor_distance$distance[anchor_distance$entity == "a"] == 0),
          nrow(fixed_distance) == 10L)
write.csv(movement, file.path(output, "movement.csv"), row.names = FALSE)
ggplot2::ggsave(file.path(output, "aligned-map.png"), plot_drift_map(fit, labels = TRUE),
                width = 7, height = 5, dpi = 120)
ggplot2::ggsave(file.path(output, "raw-map.png"), plot_drift_map(map, aligned = FALSE),
                width = 7, height = 5, dpi = 120)
ggplot2::ggsave(file.path(output, "s3-plot.png"), plot(fit, trajectories = FALSE),
                width = 7, height = 5, dpi = 120)

# 2. Supplied clusters: labels change, membership does not.
labels <- data.frame(entity = rep(letters[1:6], 2), time = rep(1:2, each = 6),
  x = rep(c(0, 1, 0, 4, 5, 4), 2), y = rep(c(0, 0, 1, 0, 0, 1), 2),
  cluster = rep(c("A", "B", "renamed_2", "renamed_1"), each = 3))
matched <- match_clusters(drift_data(labels), min_overlap = 1, min_jaccard = 0)
stopifnot(identical(matched$clusters$cluster_id[1:6], matched$clusters$cluster_id[7:12]))
write.csv(matched$diagnostics$cluster_matching$assignments,
          file.path(output, "cluster-assignments.csv"), row.names = FALSE)

# 3. Original feature input: both adapters, scaling, weights, and distance-list MDS.
features <- rbind(first, truth)
names(features)[3:4] <- c("f1", "f2")
features$f3 <- 2 * features$f1
features$f4 <- 2 * features$f2
feature_names <- paste0("f", 1:4)
pca_fit <- embed_snapshots(features, features = feature_names, method = "pca") |>
  align_snapshots(anchors = letters[1:4])
mds_fit <- embed_snapshots(features, features = feature_names, method = "cmds") |>
  align_snapshots(anchors = letters[1:4])
stopifnot(max(abs(measure_drift(pca_fit)$distance - measure_drift(mds_fit)$distance)) < 1e-8)
standardized <- embed_snapshots(features, feature_names, standardize = "first")
weighted <- embed_snapshots(features, feature_names, feature_weights = c(1, 1, 0, 0))
validate_drift_data(standardized)
validate_drift_data(weighted)
distance_input <- lapply(split(features, features$time), function(d) {
  x <- as.matrix(d[feature_names]); rownames(x) <- d$entity; stats::dist(x)
})
names(distance_input) <- c("before", "after")
distance_fit <- embed_snapshots(distance_input, method = "cmds") |>
  align_snapshots(anchors = letters[1:4])
stopifnot(max(abs(measure_drift(distance_fit)$distance - measure_drift(pca_fit)$distance)) < 1e-8)

# 4. Paired measurement-unit bootstrap: illustrative assumptions, not a confidence test.
design <- paired_unit_design(c(f1 = "A", f2 = "A", f3 = "B", f4 = "B"),
  assumptions = "Illustrative independent measurement blocks; not an empirical sampling claim.")
resampled <- bootstrap_drift(pca_fit, design, B = 20, seed = 20261028,
                            keep = "replicates", min_success = 0.95)
stopifnot(nrow(resampled$bootstrap$attempts) == 20L)
print(resampled$bootstrap$attempts)
print(resampled$bootstrap$summary)
write.csv(resampled$bootstrap$attempts, file.path(output, "bootstrap-attempts.csv"), row.names = FALSE)
write.csv(resampled$bootstrap$summary, file.path(output, "bootstrap-summary.csv"), row.names = FALSE)
saveRDS(resampled, file.path(output, "example-fit.rds"))
stopifnot(inherits(readRDS(file.path(output, "example-fit.rds")), "driftmap"))

# 5. Independent known-truth invariance experiment (engineering, not coverage calibration).
set.seed(20261028)
invariance <- vapply(seq_len(100L), function(i) {
  angle <- runif(1, -pi, pi)
  rot <- matrix(c(cos(angle), -sin(angle), sin(angle), cos(angle)), 2)
  if (i %% 2L == 0L) rot <- rot %*% diag(c(-1, 1))
  scale_factor <- runif(1, 0.3, 3)
  moved <- first; moved$time <- 2
  moved[c("x", "y")] <- sweep(scale_factor * as.matrix(first[c("x", "y")]) %*% rot,
                               2, runif(2, -20, 20), "+")
  max(measure_drift(align_snapshots(drift_data(rbind(first, moved)), scale = TRUE))$distance)
}, numeric(1))
stopifnot(max(invariance) < 1e-9)
write.csv(data.frame(run = seq_along(invariance), maximum_spurious_drift = invariance),
          file.path(output, "invariance-checks.csv"), row.names = FALSE)
writeLines(c("All 10 exports and all 3 S3 methods exercised successfully.",
             "Known target movement recovered: 1 unit; stable anchors approximately zero.",
             "PCA, feature MDS, and distance-list MDS movement magnitudes agreed.",
             "20 bootstrap attempts executed; summaries are descriptive, not confidence limits.",
             paste("100 randomized coordinate-only transformations; max apparent drift:",
                   format(max(invariance), digits = 16))), file.path(output, "tour-summary.txt"))
cat("Package tour and known-truth checks passed. Output:", output, "\n")
