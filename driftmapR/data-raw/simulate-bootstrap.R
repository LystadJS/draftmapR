#!/usr/bin/env Rscript
# Installed-package pilot: Rscript data-raw/simulate-bootstrap.R ../bootstrap-simulation-output
# This validates computation and accounting on one generator; it does not
# estimate confidence-region coverage, power, or frequentist calibration.
if (!requireNamespace("driftmapR", quietly = TRUE) ||
    !requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install driftmapR and ggplot2 before running this script.", call. = FALSE)
}
library(driftmapR)
library(ggplot2)
if (!exists("bootstrap_drift", envir = asNamespace("driftmapR"), inherits = FALSE)) {
  stop("Install the version containing bootstrap_drift().", call. = FALSE)
}
arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments)) arguments[[1L]] else "../bootstrap-simulation-output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
seed <- 260914L
set.seed(seed)
n_units <- 12L
features <- sprintf("f%02d", seq_len(n_units * 2L))
units <- stats::setNames(rep(sprintf("unit%02d", 1:n_units), each = 2L), features)
entity <- sprintf("E%03d", 1:61)
cluster <- c(rep(c("A", "B", "C"), each = 20L), "C")
centers <- rbind(A = c(-2, 0), B = c(1, 2.5), C = c(2, -1.5))
initial <- centers[cluster, ] + matrix(rnorm(122L, sd = 0.4), ncol = 2L)
anchor_ids <- entity[1:24]
individual_movers <- entity[31:35]
availability <- list(1:60, c(1:59, 61L), c(1:58, 61L))
# The complete unit (loadings + entity errors + period errors) is generated iid.
loadings <- lapply(1:n_units, function(i) diag(2) + matrix(rnorm(4L, sd = 0.3), 2L))
paired_errors <- lapply(1:n_units, function(i) matrix(rnorm(122L, sd = 0.035), ncol = 2L))
period_errors <- lapply(1:n_units, function(i) lapply(1:3, function(t) {
  matrix(rnorm(122L, sd = 0.012), ncol = 2L)
}))
truth <- do.call(rbind, lapply(1:3, function(period) {
  index <- availability[[period]]
  latent <- initial[index, , drop = FALSE]
  moving_cluster <- cluster[index] == "C"
  moving_individual <- entity[index] %in% individual_movers
  latent[moving_cluster, ] <- sweep(latent[moving_cluster, , drop = FALSE],
                                   2L, (period - 1L) * c(-0.35, 0.25), "+")
  latent[moving_individual, ] <- sweep(latent[moving_individual, , drop = FALSE],
                                      2L, (period - 1L) * c(0.15, -0.3), "+")
  data.frame(entity = entity[index], time = period, cluster = cluster[index],
             movement_group = ifelse(moving_cluster, "Moving cluster",
                                     ifelse(moving_individual, "Individual mover", "Stable")),
             latent_x = latent[, 1L], latent_y = latent[, 2L])
}))
panel <- do.call(rbind, lapply(1:3, function(period) {
  rows <- truth[truth$time == period, ]
  index <- match(rows$entity, entity)
  latent <- as.matrix(rows[c("latent_x", "latent_y")])
  measured <- do.call(cbind, lapply(1:n_units, function(i) {
    latent %*% loadings[[i]] + paired_errors[[i]][index, ] +
      period_errors[[i]][[period]][index, ]
  }))
  colnames(measured) <- features
  data.frame(rows[c("entity", "time", "cluster", "movement_group")],
             measured, check.names = FALSE)
}))
rownames(panel) <- rownames(truth) <- NULL
design <- paired_unit_design(
  units,
  assumptions = paste(
    "The generator draws each complete two-feature unit independently from",
    "the same loading-and-error distribution. Entity errors are shared over",
    "time within a unit. Entity identities, availability and latent trajectories",
    "are fixed; all within-unit dependence is preserved."
  )
)
B <- 80L
bootstrap_seed <- 140926L
results <- list()
timings <- list()
for (method in c("pca", "cmds")) {
  fit <- embed_snapshots(panel, features, method = method, standardize = "first") |>
    align_snapshots(anchors = anchor_ids)
  set.seed(999L)
  caller_seed <- .Random.seed
  elapsed <- system.time({
    results[[method]] <- bootstrap_drift(fit, design, B = B, seed = bootstrap_seed,
                                        keep = "replicates")
  })[["elapsed"]]
  stopifnot(identical(caller_seed, .Random.seed))
  timings[[method]] <- data.frame(run = method, B = B, elapsed_seconds = elapsed)
}

checks <- list()
record <- function(name, condition, discrepancy = NA_real_, tolerance = NA_real_) {
  checks[[length(checks) + 1L]] <<- data.frame(
    check = name, passed = isTRUE(condition), discrepancy = discrepancy,
    tolerance = tolerance, stringsAsFactors = FALSE)
  if (!isTRUE(condition)) stop("Pilot check failed: ", name, call. = FALSE)
}
record("PCA attempts exactly B", nrow(results$pca$bootstrap$attempts) == B)
record("MDS attempts exactly B", nrow(results$cmds$bootstrap$attempts) == B)
record("PCA all main-pilot draws succeed", all(results$pca$bootstrap$attempts$success))
record("MDS all main-pilot draws succeed", all(results$cmds$bootstrap$attempts$success))
record("Shared unit draws across adapters",
       identical(results$pca$bootstrap$draws, results$cmds$bootstrap$draws))
norm_comparison <- merge(
  results$pca$bootstrap$replicates,
  results$cmds$bootstrap$replicates,
  by = c("replicate_id", "entity", "time_from", "time_to"), suffixes = c("_pca", "_cmds"))
error <- max(abs(norm_comparison$distance_pca - norm_comparison$distance_cmds))
record("PCA/MDS resampled distance equivalence", error < 1e-8, error, 1e-8)
observed_movement <- measure_drift(results$pca)
observed_groups <- truth[c("entity", "time", "movement_group")]
names(observed_groups)[2] <- "time_to"
group_comparison <- merge(observed_movement, observed_groups,
                           by = c("entity", "time_to"))
group_means <- stats::aggregate(distance ~ movement_group, group_comparison, mean)
group_distance <- stats::setNames(group_means$distance, group_means$movement_group)
record("Known individual movers remain separated from stable entities",
       group_distance[["Individual mover"]] > 5 * group_distance[["Stable"]])
record("Known moving cluster remains separated from stable entities",
       group_distance[["Moving cluster"]] > 5 * group_distance[["Stable"]])
record("Entry and disappearance preserve adjacent availability",
       nrow(observed_movement) == 118L &&
         !any(observed_movement$entity == "E061" & observed_movement$time_from == 1L) &&
         any(observed_movement$entity == "E061" & observed_movement$time_from == 2L) &&
         !any(observed_movement$entity == "E059" & observed_movement$time_from == 2L) &&
         nrow(results$pca$bootstrap$replicates) == B * 118L)

refit <- bootstrap_drift(results$pca, design, B = 12L, seed = bootstrap_seed,
                         keep = "replicates", preprocess = "refit")
fixed <- bootstrap_drift(results$pca, design, B = 12L, seed = bootstrap_seed,
                         keep = "replicates", preprocess = "fixed")
error <- max(abs(as.matrix(refit$bootstrap$replicates[c("dx", "dy", "distance")]) -
                  as.matrix(fixed$bootstrap$replicates[c("dx", "dy", "distance")])))
record("Fixed/refit geometry equivalence for pure feature resampling", error < 1e-8, error, 1e-8)
repeat_result <- bootstrap_drift(results$pca, design, B = 12L, seed = bootstrap_seed,
                                 keep = "replicates")
record("Repeated seed reproduces retained replicate values",
       identical(refit$bootstrap$replicates, repeat_result$bootstrap$replicates))
record("Prefix streams do not depend on total B",
       identical(refit$bootstrap$draws, results$pca$bootstrap$draws[seq_len(12L)]))

# An unchanged measurement panel has no temporal movement in any draw.
null_first <- panel[panel$time == 1, ]
null_panel <- rbind(null_first, transform(null_first, time = 2L),
                    transform(null_first, time = 3L))
null_fit <- embed_snapshots(null_panel, features) |> align_snapshots(anchors = anchor_ids)
null_result <- bootstrap_drift(null_fit, design, B = 20L, seed = 501L,
                               keep = "replicates")
error <- max(null_result$bootstrap$replicates$distance)
record("Paired draws preserve the unchanged-map null", error < 1e-8, error, 1e-8)

# Two independent single-feature units yield rank-one maps whenever one unit
# is selected twice. This is an intentionally inadequate design for 2-D fits.
set.seed(1140L)
failure_loadings <- matrix(rnorm(4L), nrow = 2L)
failure_values <- initial[1:60, ] %*% failure_loadings
colnames(failure_values) <- features[1:2]
failure_first <- data.frame(entity = entity[1:60], time = 1L,
                             failure_values, check.names = FALSE)
failure_panel <- rbind(failure_first, transform(failure_first, time = 2L),
                        transform(failure_first, time = 3L))
failure_design <- paired_unit_design(
  stats::setNames(c("u1", "u2"), features[1:2]),
  assumptions = paste(
    "The two single-feature units have independently sampled standard-normal",
    "loading vectors. Their values remain paired over entities and periods.",
    "This deliberately small unit sample is a rank-failure stress test."
  )
)
failure_fit <- embed_snapshots(failure_panel, features[1:2]) |> align_snapshots()
failure_result <- bootstrap_drift(failure_fit, failure_design, B = 40L, seed = 114L,
                                  keep = "replicates")
attempts <- failure_result$bootstrap$attempts
record("Rank-failure experiment still attempts exactly 40", nrow(attempts) == 40L)
record("Rank-failure experiment contains successes and failures",
       any(attempts$success) && any(!attempts$success))
record("Failures retain stage and message",
       all(nzchar(attempts$stage[!attempts$success])) &&
         all(nzchar(attempts$message[!attempts$success])))
record("Success gate suppresses failed-design estimates",
       all(is.na(failure_result$bootstrap$summary$mean_distance)))
record("Failed-design valid draws remain inspectable",
       nrow(failure_result$bootstrap$replicates) > 0L)

main <- results$pca$bootstrap
selected <- c("E010", "E032", "E045")
cloud <- main$replicates[main$replicates$entity %in% selected &
                          main$replicates$time_from == 1, ]
observed <- measure_drift(results$pca)
observed <- observed[observed$entity %in% selected & observed$time_from == 1, ]
labels <- c(E010 = "E010: stable", E032 = "E032: individual mover", E045 = "E045: moving cluster")
cloud$entity <- factor(labels[cloud$entity], levels = labels)
observed$entity <- factor(labels[observed$entity], levels = labels)
cloud_plot <- ggplot(cloud, aes(x = dx, y = dy)) +
  geom_hline(yintercept = 0, colour = "grey85", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "grey85", linewidth = 0.3) +
  geom_point(colour = "#176B87", size = 1.6, alpha = 0.48) +
  geom_point(data = observed, shape = 4, colour = "#B64827", size = 3.8, stroke = 1.1) +
  facet_wrap(~entity, nrow = 1, scales = "free") +
  labs(title = "Unit resampling preserves movement while varying its estimated vector",
       subtitle = "80 PCA refits; blue points are successful draws; orange crosses are observed estimates",
       x = "Aligned displacement dx", y = "Aligned displacement dy",
       caption = "Period 1 to 2. Panels use different axis ranges. Conditional resampling clouds are not confidence regions.") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0))
ggsave(file.path(output_dir, "bootstrap-vector-clouds.png"), cloud_plot,
       width = 11, height = 4.3, dpi = 180, bg = "white")
ggsave(file.path(output_dir, "bootstrap-vector-clouds.pdf"), cloud_plot,
       width = 11, height = 4.3, bg = "white")
attempt_plot_data <- rbind(
  data.frame(run = "Main PCA: 12 two-feature units", results$pca$bootstrap$attempts),
  data.frame(run = "Main MDS: 12 two-feature units", results$cmds$bootstrap$attempts),
  data.frame(run = "Rank stress test: 2 single-feature units", attempts)
)
attempt_plot_data$outcome <- ifelse(attempt_plot_data$success, "Successful", "Failed")
attempt_plot <- ggplot(attempt_plot_data, aes(x = run, fill = outcome)) +
  geom_bar(width = 0.6) + coord_flip() +
  scale_fill_manual(values = c(Successful = "#176B87", Failed = "#B64827")) +
  labs(title = "Failed draws remain in the denominator",
       subtitle = "Exactly the requested attempts; no replacement draws",
       x = NULL, y = "Attempted replicates", fill = NULL,
       caption = "The rank stress test suppresses numerical summaries when its success rate misses the declared gate.") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "top",
        plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0))
ggsave(file.path(output_dir, "bootstrap-attempt-accounting.png"), attempt_plot,
       width = 10, height = 4, dpi = 180, bg = "white")
ggsave(file.path(output_dir, "bootstrap-attempt-accounting.pdf"), attempt_plot,
       width = 10, height = 4, bg = "white")

write.csv(panel, file.path(output_dir, "measurement-panel.csv"), row.names = FALSE)
write.csv(truth, file.path(output_dir, "latent-generator-truth.csv"), row.names = FALSE)
write.csv(main$summary, file.path(output_dir, "pca-resampling-summary.csv"), row.names = FALSE)
write.csv(main$coordinate_summary, file.path(output_dir, "pca-coordinate-summary.csv"), row.names = FALSE)
write.csv(main$quantiles, file.path(output_dir, "pca-resampling-quantiles.csv"), row.names = FALSE)
write.csv(main$replicates, file.path(output_dir, "pca-movement-replicates.csv"), row.names = FALSE)
write.csv(group_means, file.path(output_dir, "observed-movement-by-generator-group.csv"), row.names = FALSE)
write.csv(attempt_plot_data, file.path(output_dir, "all-main-and-stress-attempts.csv"), row.names = FALSE)
write.csv(norm_comparison[c("replicate_id", "entity", "time_from", "time_to", "distance_pca", "distance_cmds")],
          file.path(output_dir, "pca-mds-norm-comparison.csv"), row.names = FALSE)
write.csv(do.call(rbind, timings), file.path(output_dir, "timing.csv"), row.names = FALSE)
write.csv(do.call(rbind, checks), file.path(output_dir, "pilot-checks.csv"), row.names = FALSE)
saveRDS(list(seed = seed, bootstrap_seed = bootstrap_seed, panel = panel, truth = truth,
             loadings = loadings, paired_errors = paired_errors, period_errors = period_errors,
             units = units, design = design, results = results,
             failure_loadings = failure_loadings,
             failure_result = failure_result, null_result = null_result),
        file.path(output_dir, "bootstrap-pilot.rds"), compress = "xz")
writeLines(c(
  "# Paired-unit bootstrap computational pilot", "",
  paste0("Generator seed: ", seed, "; main bootstrap seed: ", bootstrap_seed, "."),
  "Twelve independently generated two-feature units; 3 periods; 3 clusters;",
  "60, 60 and 59 observed entities, including disappearance and entry.",
  "One cluster and five individual entities move; 24 declared anchors are stable.", "",
  "The latent CSV records generator positions. Their Euclidean units differ from",
  "the fitted standardized feature metric; it is not a distance-coverage target.",
  "The pilot checks numerical equivalence, paired dependence, reproducibility,",
  "unchanged-map drift, and failure accounting. It does not estimate bias,",
  "confidence coverage, power, or rejection rates across independent datasets.", "",
  paste0(length(checks), " computational checks passed."),
  paste0("Rank stress test: ", sum(attempts$success), "/", nrow(attempts),
         " successful draws; all attempts retained and gated summaries suppressed."),
  "The stress test has only two independently generated single-feature units;",
  "it is an accounting check and provides no calibrated inference.", "",
  "Reproduce from the installed package with:",
  "Rscript data-raw/simulate-bootstrap.R ../bootstrap-simulation-output"
), file.path(output_dir, "README.md"))
writeLines(capture.output(sessionInfo()), file.path(output_dir, "session-info.txt"))
cat(length(checks), "computational checks passed. Outputs:", output_dir, "\n")
