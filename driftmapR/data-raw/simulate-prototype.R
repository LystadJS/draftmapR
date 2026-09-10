#!/usr/bin/env Rscript
# Reproduce the prototype's descriptive simulation and exported figures.
# Run from an installed package checkout:
#   Rscript data-raw/simulate-prototype.R ../simulation-output
# Uses only base/recommended R packages, driftmapR, and ggplot2.

if (!requireNamespace("driftmapR", quietly = TRUE) ||
    !requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install driftmapR and ggplot2 before running this script.", call. = FALSE)
}
library(driftmapR)
library(ggplot2)
arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments)) arguments[[1L]] else "../simulation-output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output_dir)) stop("Could not create output directory.")
output_dir <- normalizePath(output_dir, mustWork = TRUE)
set.seed(260910)

# Three separated clusters; 96 observations per period, 104 unique entities.
# Four entities disappear and four enter at each boundary. Cluster 3 moves;
# four members of cluster 1 have individual shifts. Membership is known truth.
registry <- data.frame(
  entity = sprintf("E%03d", seq_len(104L)),
  cluster = c(rep(seq_len(3L), each = 32L), 1L, 2L, 3L, 1L, 2L, 3L, 1L, 2L)
)
centers <- rbind(c(-3, -1), c(3, -1), c(0, 3))
base_coordinates <- centers[registry$cluster, , drop = FALSE] +
  matrix(rnorm(208L, sd = 0.38), ncol = 2L)
individual_movers <- sprintf("E%03d", 21:24)
stable_anchors <- sprintf("E%03d", c(1:12, 33:44))
registry$movement_group <- ifelse(
  registry$cluster == 3L, "Moving cluster",
  ifelse(registry$entity %in% individual_movers, "Individual movement", "Stable")
)
registry$is_known_stable_anchor <- registry$entity %in% stable_anchors
present <- list(1:96, c(1:92, 97:100), c(1:88, 97:104))
truth <- do.call(rbind, lapply(seq_len(3L), function(period) {
  indices <- present[[period]]
  points <- base_coordinates[indices, , drop = FALSE]
  cluster_move <- registry$cluster[indices] == 3L
  individual_move <- registry$entity[indices] %in% individual_movers
  points[cluster_move, ] <- sweep(points[cluster_move, , drop = FALSE], 2L,
                                  c(1, -0.5) * (period - 1L), "+")
  individual_offset <- list(c(0, 0), c(0.7, 0.55), c(1.1, 0.9))[[period]]
  points[individual_move, ] <- sweep(points[individual_move, , drop = FALSE], 2L,
                                     individual_offset, "+")
  data.frame(registry[indices, ], time = period, x = points[, 1L], y = points[, 2L],
             row.names = NULL)
}))

rotation <- function(degrees) {
  angle <- degrees * pi / 180
  matrix(c(cos(angle), sin(angle), -sin(angle), cos(angle)), nrow = 2L)
}
applied <- list(
  list(period = 1L, matrix = diag(2L), translation = c(0, 0)),
  list(period = 2L, matrix = rotation(78), translation = c(7, -4)),
  list(period = 3L, matrix = rotation(-48) %*% diag(c(-1, 1)),
       translation = c(-5, 6))
)
transformations <- do.call(rbind, lapply(applied, function(value) {
  inverse <- t(value$matrix)
  inverse_translation <- as.vector(-value$translation %*% inverse)
  data.frame(
    time = value$period, Q11 = value$matrix[1, 1], Q12 = value$matrix[1, 2],
    Q21 = value$matrix[2, 1], Q22 = value$matrix[2, 2],
    translation_x = value$translation[1], translation_y = value$translation[2],
    inverse_R11 = inverse[1, 1], inverse_R12 = inverse[1, 2],
    inverse_R21 = inverse[2, 1], inverse_R22 = inverse[2, 2],
    inverse_translation_x = inverse_translation[1],
    inverse_translation_y = inverse_translation[2], scale = 1,
    determinant = det(value$matrix)
  )
}))

# Derive ground-truth adjacent differences directly, independently of package
# movement functions. A returning entity has no bridge across a missing period.
truth_movement <- do.call(rbind, lapply(2:3, function(period) {
  previous <- truth[truth$time == period - 1L, ]
  current <- truth[truth$time == period, ]
  paired <- merge(previous, current, by = "entity", suffixes = c("_from", "_to"))
  data.frame(
    entity = paired$entity, time_from = period - 1L, time_to = period,
    true_dx = paired$x_to - paired$x_from, true_dy = paired$y_to - paired$y_from,
    true_distance = sqrt((paired$x_to - paired$x_from)^2 +
                           (paired$y_to - paired$y_from)^2),
    movement_group = paired$movement_group_to
  )
}))

write.csv(registry, file.path(output_dir, "entity_registry.csv"), row.names = FALSE)
write.csv(truth, file.path(output_dir, "true_coordinates.csv"), row.names = FALSE)
write.csv(truth_movement, file.path(output_dir, "true_movement.csv"), row.names = FALSE)
write.csv(transformations, file.path(output_dir, "true_transformations.csv"),
          row.names = FALSE)
saveRDS(applied, file.path(output_dir, "true_transformations.rds"), version = 3)
writeLines(stable_anchors, file.path(output_dir, "known_stable_anchors.txt"))

comparisons <- list()
models <- list()
raw_sets <- list()
metrics <- list()
metric_index <- 0L
run_index <- 0L
scenario_noise <- c(noiseless = 0, noisy = 0.025)
for (scenario in names(scenario_noise)) {
  noise_sd <- unname(scenario_noise[[scenario]])
  raw <- truth
  for (period in seq_len(3L)) {
    rows <- which(raw$time == period)
    clean <- as.matrix(truth[rows, c("x", "y")])
    perturbed <- clean + matrix(rnorm(length(clean), sd = noise_sd), ncol = 2L)
    transformed <- sweep(perturbed %*% applied[[period]]$matrix, 2L,
                          applied[[period]]$translation, "+")
    raw[rows, c("x", "y")] <- transformed
  }
  raw_sets[[scenario]] <- raw
  write.csv(raw, file.path(output_dir, paste0("raw_coordinates_", scenario, ".csv")),
            row.names = FALSE)
  object <- drift_data(raw, periods = 1:3)
  for (method in c("all_shared", "known_stable_anchors")) {
    elapsed <- system.time({
      fit <- if (method == "all_shared") {
        align_snapshots(object, reference = "previous", scale = FALSE)
      } else {
        align_snapshots(object, reference = "previous", scale = FALSE,
                        anchors = stable_anchors)
      }
      movement <- measure_drift(fit)
    })[["elapsed"]]
    comparison <- merge(movement, truth_movement,
                        by = c("entity", "time_from", "time_to"), sort = TRUE)
    comparison$scenario <- scenario
    comparison$method <- method
    comparison$noise_sd <- noise_sd
    comparison$distance_error <- comparison$distance - comparison$true_distance
    comparison$vector_error <- sqrt((comparison$dx - comparison$true_dx)^2 +
                                      (comparison$dy - comparison$true_dy)^2)
    if (nrow(comparison) != nrow(truth_movement)) {
      stop("Movement output failed to preserve the adjacent-period denominator.")
    }
    run_index <- run_index + 1L
    comparisons[[run_index]] <- comparison
    models[[paste(scenario, method, sep = "_")]] <- fit
    write.csv(fit$aligned,
              file.path(output_dir, paste0("aligned_", scenario, "_", method, ".csv")),
              row.names = FALSE)
    write.csv(comparison,
              file.path(output_dir, paste0("movement_", scenario, "_", method, ".csv")),
              row.names = FALSE)
    for (group in c("All entities", sort(unique(comparison$movement_group)))) {
      subset <- if (group == "All entities") comparison else
        comparison[comparison$movement_group == group, , drop = FALSE]
      metric_index <- metric_index + 1L
      metrics[[metric_index]] <- data.frame(
        scenario = scenario, method = method, movement_group = group,
        n_entity_transitions = nrow(subset), noise_sd = noise_sd,
        distance_bias = mean(subset$distance_error),
        distance_rmse = sqrt(mean(subset$distance_error^2)),
        vector_rmse = sqrt(mean(subset$vector_error^2)),
        max_vector_error = max(subset$vector_error),
        mean_true_distance = mean(subset$true_distance),
        mean_estimated_distance = mean(subset$distance),
        elapsed_seconds = elapsed, object_bytes = as.numeric(object.size(fit))
      )
    }
  }
}
comparison <- do.call(rbind, comparisons)
metrics <- do.call(rbind, metrics)
write.csv(comparison, file.path(output_dir, "movement_comparison.csv"), row.names = FALSE)
write.csv(metrics, file.path(output_dir, "simulation_metrics.csv"), row.names = FALSE)
saveRDS(models, file.path(output_dir, "simulation_models.rds"), version = 3)

# Essential numerical acceptance check for this deterministic known-truth case.
# Real applications do not automatically have known stable anchors.
exact <- comparison[comparison$scenario == "noiseless" &
                      comparison$method == "known_stable_anchors", ]
tolerance <- 1e-9
if (max(exact$vector_error) > tolerance) {
  stop(sprintf("Known-anchor movement recovery failed: max error %.3g > %.3g.",
               max(exact$vector_error), tolerance))
}
stable <- exact$true_distance == 0
if (any(exact$distance[stable] > tolerance)) {
  stop("Coordinate transformations created drift among known stationary entities.")
}

period_colors <- c("1" = "#536A7B", "2" = "#B87925", "3" = "#685791")
group_colors <- c("Stable" = "#7D8790", "Individual movement" = "#B87925",
                  "Moving cluster" = "#685791")
theme_simulation <- theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "#EBECEF", linewidth = 0.3),
        plot.title = element_text(face = "bold", size = 15),
        plot.subtitle = element_text(size = 11, color = "#555555"),
        strip.text = element_text(face = "bold"), legend.position = "top",
        plot.title.position = "plot", plot.caption = element_text(hjust = 0),
        plot.background = element_rect(fill = "white", color = NA))
export_plot <- function(graph, basename, width, height) {
  ggsave(file.path(output_dir, paste0(basename, ".png")), graph,
         width = width, height = height, dpi = 180, bg = "white")
  ggsave(file.path(output_dir, paste0(basename, ".pdf")), graph,
         width = width, height = height, bg = "white")
}
raw_plot_data <- raw_sets$noiseless
raw_plot_data$period <- factor(raw_plot_data$time, levels = 1:3)
raw_plot <- ggplot(raw_plot_data, aes(x = x, y = y, color = period)) +
  geom_point(aes(shape = movement_group), size = 2, alpha = 0.85) +
  facet_wrap(~period, nrow = 1) + coord_equal() +
  scale_color_manual(values = period_colors) +
  scale_shape_manual(values = c("Stable" = 16, "Individual movement" = 17,
                                "Moving cluster" = 15)) +
  labs(title = "Independent coordinates disguise the underlying trajectories",
       subtitle = "Three periods with rotation, reflection, translation, and known movement",
       x = "Raw coordinate 1", y = "Raw coordinate 2", color = "Period",
       shape = "Known generating group",
       caption = "Synthetic noiseless example. Axes use a common scale; 96 observed entities per period.") +
  theme_simulation
export_plot(raw_plot, "01_raw_unaligned", 12, 5.4)

aligned_data <- models$noiseless_known_stable_anchors$aligned
aligned_data$period <- factor(aligned_data$time, levels = 1:3)
aligned_plot <- ggplot(aligned_data, aes(x = x, y = y, color = period)) +
  geom_point(aes(shape = movement_group), size = 2, alpha = 0.85) +
  facet_wrap(~period, nrow = 1) + coord_equal() +
  scale_color_manual(values = period_colors) +
  scale_shape_manual(values = c("Stable" = 16, "Individual movement" = 17,
                                "Moving cluster" = 15)) +
  labs(title = "Stable anchors recover a common frame while preserving movement",
       subtitle = "Twenty-four known stationary entities define the reference frame",
       x = "Aligned coordinate 1", y = "Aligned coordinate 2", color = "Period",
       shape = "Known generating group",
       caption = "Synthetic noiseless example. Ground-truth cluster membership is supplied; clusters are not fitted.") +
  theme_simulation
export_plot(aligned_plot, "02_aligned_snapshots", 12, 5.4)

trajectory_plot <- plot_drift_map(models$noiseless_known_stable_anchors) +
  labs(title = "Aligned trajectories retain the individual and cluster shifts",
       subtitle = "Adjacent-period arrows; entrants and exits have no fabricated connections",
       caption = "Noiseless synthetic coordinates aligned on known stable anchors. No uncertainty intervals are estimated.") +
  theme_simulation
export_plot(trajectory_plot, "03_aligned_trajectories", 9, 6.6)

comparison_plot_data <- comparison
comparison_plot_data$scenario <- factor(comparison_plot_data$scenario,
                                        levels = c("noiseless", "noisy"),
                                        labels = c("No coordinate noise", "Coordinate noise SD = 0.025"))
comparison_plot_data$method <- factor(comparison_plot_data$method,
                                      levels = c("all_shared", "known_stable_anchors"),
                                      labels = c("All shared entities", "Known stable anchors"))
comparison_plot <- ggplot(comparison_plot_data,
                          aes(x = true_distance, y = distance, color = movement_group)) +
  geom_abline(slope = 1, intercept = 0, color = "#42464B", linetype = "dashed",
              linewidth = 0.5) +
  geom_point(aes(shape = movement_group), size = 2.1, alpha = 0.6) +
  facet_grid(scenario ~ method) +
  scale_color_manual(values = group_colors) +
  scale_shape_manual(values = c("Stable" = 16, "Individual movement" = 17,
                                "Moving cluster" = 15)) +
  scale_x_continuous(limits = c(-0.03, 1.25), breaks = c(0, 0.5, 1)) +
  scale_y_continuous(limits = c(-0.03, 1.25), breaks = c(0, 0.5, 1)) +
  coord_equal() +
  labs(title = "Reference choice determines how much true movement is retained",
       subtitle = "All-shared alignment absorbs part of the coordinated shift; fixed stable anchors preserve it",
       x = "True movement magnitude", y = "Estimated movement magnitude",
       color = "Known generating group", shape = "Known generating group",
       caption = paste("Dashed line: exact recovery. Points can overlap; all 184 adjacent entity transitions are included per panel.",
                       "One seeded realization per scenario; this is descriptive validation, not interval-coverage evidence.", sep = "\n")) +
  theme_simulation
export_plot(comparison_plot, "04_estimated_vs_truth", 10, 9)

writeLines(c(
  "driftmapR prototype simulation", "",
  "Seed: 260910. Three clusters; 104 unique entities; 96 observations per period.",
  "There are 184 adjacent entity transitions, with entrants and exits at each boundary.",
  "Four cluster-1 entities have individual shifts; cluster 3 moves as a whole.",
  "Raw coordinates apply known rotations/reflection/translations; the first map is the truth frame.",
  "Two coordinate-noise levels: 0 and 0.025. One seeded realization each.", "",
  "Alignment methods: all shared entities versus 24 known stationary anchors.",
  "Anchor choice is a substantive assumption, not a procedure to discover stable entities.",
  "The ordinary fit defines a compromise frame and can absorb coherent movement.",
  "Both approaches produce relative motion, and absolute whole-system translation or rotation",
  "cannot be distinguished from coordinate artifacts without external identifying information.", "",
  sprintf("Noiseless anchor max vector error: %.12g; required tolerance: %.3g.",
          max(exact$vector_error), tolerance),
  "Coordinate SD is a simulation parameter, not a confidence interval.",
  "No bootstrap, inferential detection, cluster fitting/matching, coverage study, or calibrated threshold is implemented.",
  "Elapsed time and object size are descriptive single-run measurements, not benchmarks.", "",
  "Files: true_coordinates / true_movement / true_transformations are independently generated truth.",
  "raw_coordinates_* and aligned_* are the supplied and fitted maps.",
  "movement_* and simulation_metrics.csv preserve all transition-level comparisons and group summaries.",
  "simulation_models.rds preserves the analysis objects and transformations.",
  "01: raw maps; 02: aligned snapshots; 03: arrows; 04: estimated versus true movement.",
  "Every figure is supplied as PNG and vector PDF.",
  "Reproduce: Rscript data-raw/simulate-prototype.R PATH_TO_OUTPUT_DIRECTORY"
), file.path(output_dir, "README.txt"))
writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
cat(sprintf("Simulation completed: %s\n", output_dir))
print(metrics[metrics$movement_group == "All entities", ], row.names = FALSE)
cat(sprintf("Noiseless anchor recovery passed (max vector error %.3g).\n",
            max(exact$vector_error)))
