#!/usr/bin/env Rscript
# After installing this checkout:
# Rscript data-raw/simulate-embeddings.R ../embedding-simulation-output
# This is deterministic geometric validation, not a bootstrap analysis.
if (!requireNamespace("driftmapR", quietly = TRUE) ||
    !requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install driftmapR and ggplot2 before running this script.", call. = FALSE)
}
library(driftmapR)
library(ggplot2)
if (!exists("embed_snapshots", envir = asNamespace("driftmapR"), inherits = FALSE)) {
  stop("Install the version of driftmapR containing embed_snapshots().", call. = FALSE)
}
arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments)) arguments[[1L]] else "../embedding-simulation-output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
seed <- 260912L
set.seed(seed)

# Eight measured coordinates span exactly two dimensions. The loading has
# orthonormal rows, so Euclidean feature distances equal latent distances.
loading <- t(qr.Q(qr(matrix(rnorm(16L), nrow = 8L))))
features <- sprintf("feature_%02d", 1:8)
colnames(loading) <- features
entity <- sprintf("E%03d", 1:111)
cluster <- c(rep(c("A", "B", "C"), each = 33L), rep("C", 12L))
centres <- rbind(A = c(-3, 0), B = c(1, 3), C = c(3, -2))
latent_initial <- centres[cluster, , drop = FALSE] +
  matrix(rnorm(length(entity) * 2L, sd = 0.45), ncol = 2L)
rownames(latent_initial) <- entity
colnames(latent_initial) <- c("truth_x", "truth_y")
individual_movers <- entity[c(5L, 12L, 40L, 52L)]
anchor_ids <- setdiff(entity[1:66], individual_movers)
availability <- list(1:99, c(1:93, 100:105), c(1:87, 100:111))
angles <- c(0, pi / 3, -pi / 2)
offsets <- rbind(rep(0, 8L), seq(-2, 2, length.out = 8L),
                 seq(3, -1, length.out = 8L))
rotations <- lapply(seq_along(angles), function(period) {
  a <- angles[period]
  rotation <- matrix(c(cos(a), -sin(a), sin(a), cos(a)), nrow = 2L)
  if (period == 3L) rotation <- rotation %*% diag(c(-1, 1))
  rotation
})
truth <- do.call(rbind, lapply(1:3, function(period) {
  index <- availability[[period]]
  xy <- latent_initial[index, , drop = FALSE]
  is_cluster_mover <- cluster[index] == "C"
  is_individual_mover <- entity[index] %in% individual_movers
  xy[is_cluster_mover, ] <- sweep(xy[is_cluster_mover, , drop = FALSE],
                                  2L, (period - 1L) * c(-0.8, 0.65), "+")
  xy[is_individual_mover, ] <- sweep(xy[is_individual_mover, , drop = FALSE],
                                     2L, (period - 1L) * c(0.55, -0.35), "+")
  data.frame(entity = entity[index], time = period, cluster = cluster[index],
             movement_group = ifelse(is_cluster_mover, "Moving cluster",
                                     ifelse(is_individual_mover, "Individual movers", "Stable")),
             truth_x = xy[, 1L], truth_y = xy[, 2L], stringsAsFactors = FALSE)
}))
rownames(truth) <- NULL
input <- do.call(rbind, lapply(1:3, function(period) {
  rows <- truth[truth$time == period, ]
  # Rotation/reflection within the same feature plane plus feature translation
  # are imposed nuisances; their known values are retained in the truth RDS.
  x <- as.matrix(rows[c("truth_x", "truth_y")]) %*%
    rotations[[period]] %*% loading
  x <- sweep(x, 2L, offsets[period, ], "+")
  data.frame(rows[c("entity", "time", "cluster", "movement_group")], x,
             check.names = FALSE)
}))
rownames(input) <- NULL
truth_movement <- do.call(rbind, lapply(2:3, function(period) {
  before <- truth[truth$time == period - 1L, ]
  after <- truth[truth$time == period, ]
  shared <- intersect(before$entity, after$entity)
  before <- before[match(shared, before$entity), ]
  after <- after[match(shared, after$entity), ]
  dx <- after$truth_x - before$truth_x
  dy <- after$truth_y - before$truth_y
  data.frame(entity = shared, time_from = period - 1L, time_to = period,
             cluster = after$cluster, movement_group = after$movement_group,
             truth_dx = dx, truth_dy = dy, truth_distance = sqrt(dx^2 + dy^2))
}))

models <- list()
comparison <- list()
map_rows <- list()
diagnostics <- list()
for (method in c("pca", "cmds")) {
  raw <- embed_snapshots(input, features = features, method = method)
  fit <- align_snapshots(raw, anchors = anchor_ids, scale = FALSE)
  models[[method]] <- fit
  estimated <- measure_drift(fit)
  matched <- merge(estimated, truth_movement,
                    by = c("entity", "time_from", "time_to"), sort = TRUE)
  stopifnot(nrow(matched) == nrow(truth_movement))
  matched$method <- method
  matched$absolute_error <- abs(matched$distance - matched$truth_distance)
  comparison[[method]] <- matched
  diag <- fit$diagnostics$embedding
  diag$method <- method
  diagnostics[[method]] <- diag
  for (view in c("Raw embedding", "Aligned embedding")) {
    coordinates <- if (view == "Raw embedding") fit$coordinates else fit$aligned
    coordinates <- coordinates[c("entity", "time", "x", "y")]
    coordinates <- merge(coordinates, truth[c("entity", "time", "cluster", "movement_group")],
                           by = c("entity", "time"), sort = TRUE)
    coordinates$method <- toupper(method)
    coordinates$view <- view
    map_rows[[paste(method, view)]] <- coordinates
  }
}
comparison <- do.call(rbind, comparison)
diagnostics <- do.call(rbind, diagnostics)
map_rows <- do.call(rbind, map_rows)
rownames(comparison) <- rownames(diagnostics) <- rownames(map_rows) <- NULL
map_rows$view <- factor(map_rows$view, levels = c("Raw embedding", "Aligned embedding"))
map_rows$time <- factor(map_rows$time)

checks <- list()
record_check <- function(name, error, tolerance = 1e-8) {
  if (!is.finite(error) || error > tolerance) {
    stop(name, " failed: error ", format(error), " exceeds ", format(tolerance))
  }
  checks[[length(checks) + 1L]] <<- data.frame(
    check = name, maximum_absolute_error = error, tolerance = tolerance, passed = TRUE)
}
for (method in c("pca", "cmds")) {
  values <- comparison[comparison$method == method, ]
  record_check(paste0(method, "_known_movement"), max(values$absolute_error))
  record_check(paste0(method, "_stable_entities"),
               max(values$distance[values$movement_group == "Stable"]))
}
for (period in 1:3) {
  matrices <- lapply(models, function(fit) {
    coordinates <- fit$coordinates[fit$coordinates$time == period, ]
    as.matrix(stats::dist(coordinates[c("x", "y")]))
  })
  record_check(paste0("pca_cmds_distance_equivalence_period_", period),
               max(abs(matrices$pca - matrices$cmds)))
}
methods_compared <- merge(comparison[comparison$method == "pca", ],
                           comparison[comparison$method == "cmds", ],
                           by = c("entity", "time_from", "time_to"))
record_check("pca_cmds_movement_equivalence",
             max(abs(methods_compared$distance.x - methods_compared$distance.y)))

# No-motion control: a fixed entity configuration receives only known global
# rotation, reflection and translation, then each snapshot is independently fit.
control <- do.call(rbind, lapply(1:3, function(period) {
  x <- latent_initial[1:99, ] %*% rotations[[period]] %*% loading
  x <- sweep(x, 2L, offsets[period, ], "+")
  data.frame(entity = entity[1:99], time = period, x, check.names = FALSE)
}))
control_models <- lapply(c("pca", "cmds"), function(method) {
  fit <- embed_snapshots(control, features, method = method) |> align_snapshots()
  record_check(paste0(method, "_no_motion_isometry"), max(measure_drift(fit)$distance))
  fit
})
names(control_models) <- c("pca", "cmds")

# Integer multiplicities are a deterministic algebra check. No resampling has
# occurred, and this does not estimate uncertainty.
weights <- c(2, 0, 1, 3, 1, 0, 2, 1)
expanded_index <- rep(seq_along(features), times = weights)
duplicated <- input[c("entity", "time")]
expanded_features <- sprintf("replicated_%02d", seq_along(expanded_index))
for (j in seq_along(expanded_index)) {
  duplicated[[expanded_features[j]]] <- input[[features[expanded_index[j]]]]
}
weighted_models <- list()
for (method in c("pca", "cmds")) {
  weighted <- embed_snapshots(input, features, method = method, feature_weights = weights)
  expanded <- embed_snapshots(duplicated, expanded_features, method = method)
  weighted_models[[method]] <- weighted
  for (period in 1:3) {
    a <- weighted$coordinates[weighted$coordinates$time == period, c("x", "y")]
    b <- expanded$coordinates[expanded$coordinates$time == period, c("x", "y")]
    record_check(paste0(method, "_integer_weight_equivalence_period_", period),
                 max(abs(as.matrix(stats::dist(a)) - as.matrix(stats::dist(b)))))
  }
}

# Distance input uses labeled, observed-entity matrices. It should reproduce
# Euclidean feature-input cMDS despite different input representations.
dissimilarities <- lapply(1:3, function(period) {
  rows <- input[input$time == period, ]
  x <- as.matrix(rows[features])
  rownames(x) <- rows$entity
  stats::dist(x)
})
distance_model <- embed_snapshots(dissimilarities, method = "cmds", periods = 1:3)
for (period in 1:3) {
  a <- distance_model$coordinates[distance_model$coordinates$time == period, c("x", "y")]
  b <- models$cmds$coordinates[models$cmds$coordinates$time == period, c("x", "y")]
  record_check(paste0("cmds_distance_input_equivalence_period_", period),
               max(abs(as.matrix(stats::dist(a)) - as.matrix(stats::dist(b)))))
}
checks <- do.call(rbind, checks)

map_plot <- ggplot(map_rows, aes(x, y)) +
  geom_path(aes(group = entity), colour = "grey65", linewidth = 0.3, alpha = 0.45) +
  geom_point(aes(colour = time, shape = cluster), size = 1.7, alpha = 0.8) +
  facet_grid(method ~ view) + coord_equal() +
  scale_colour_brewer(palette = "Dark2", name = "Period") +
  labs(title = "Independent embeddings and temporal alignment",
       subtitle = "Rank-2 geometry in 8 features; 99 observations per period; specified stable anchors",
       x = "Coordinate 1", y = "Coordinate 2", shape = "Supplied cluster",
       caption = "PCA and classical MDS choose separate baseline orientations. Axes carry no substantive labels.") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")
movement_plot <- ggplot(comparison, aes(truth_distance, distance, colour = movement_group)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey50", linewidth = 0.4) +
  geom_point(alpha = 0.55, size = 2) + facet_wrap(~method) + coord_equal() +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(title = "Known movement survives embedding and alignment",
       subtitle = "Exact rank-2 construction; overplotting reflects identical imposed movement within groups",
       x = "Known Euclidean movement", y = "Estimated aligned movement",
       caption = "Idealized geometric validation, with no noise, bootstrap intervals or coverage claims.") +
  theme_bw(base_size = 11) + theme(legend.position = "bottom")
for (extension in c("png", "pdf")) {
  ggsave(file.path(output_dir, paste0("embedding-maps.", extension)), map_plot,
          width = 10, height = 8, dpi = 160)
  ggsave(file.path(output_dir, paste0("embedding-movement-truth.", extension)), movement_plot,
          width = 10, height = 5, dpi = 160)
}
write.csv(input, file.path(output_dir, "feature-input.csv"), row.names = FALSE)
write.csv(truth, file.path(output_dir, "latent-truth.csv"), row.names = FALSE)
write.csv(truth_movement, file.path(output_dir, "known-movement.csv"), row.names = FALSE)
write.csv(comparison, file.path(output_dir, "estimated-versus-known-movement.csv"), row.names = FALSE)
write.csv(diagnostics, file.path(output_dir, "embedding-diagnostics.csv"), row.names = FALSE)
write.csv(checks, file.path(output_dir, "validation-checks.csv"), row.names = FALSE)
write.csv(map_rows, file.path(output_dir, "map-coordinates.csv"), row.names = FALSE)
saveRDS(list(seed = seed, initial_latent = latent_initial, loading = loading,
              rotations = rotations, offsets = offsets, availability = availability,
              anchors = anchor_ids, individual_movers = individual_movers,
              feature_weights = weights), file.path(output_dir, "generating-truth.rds"), version = 3)
saveRDS(list(main = models, no_motion = control_models, weighted = weighted_models,
              distances = distance_model), file.path(output_dir, "embedding-models.rds"), version = 3)
summary <- c(
  "driftmapR PCA/classical-MDS deterministic simulation",
  paste("Package version:", as.character(utils::packageVersion("driftmapR"))),
  paste("Seed:", seed),
  "99 observations per period; 111 unique entities; 3 periods; 3 supplied clusters; 8 features.",
  "Known truth: one moving cluster, four individual movers, stable anchors, exits and entrants.",
  "The feature matrix has exactly rank two after centering and uses an isometric loading.",
  "Known raw-space rotations, reflection and translations are retained in generating-truth.rds.",
  paste("Checks passed:", nrow(checks)),
  paste("Maximum absolute numerical discrepancy:", format(max(checks$maximum_absolute_error), digits = 8)),
  "Tolerance: 1e-8 in the small, well-conditioned units used in this simulation.",
  "This validates geometry and data flow, not robustness to noise or inferential coverage.",
  "Multiplicity checks verify algebra only; no bootstrap engine or uncertainty intervals are implemented."
)
writeLines(summary, file.path(output_dir, "simulation-summary.txt"))
writeLines(capture.output(sessionInfo()), file.path(output_dir, "session-info.txt"))
cat(paste(summary, collapse = "\n"), "\n")
cat("Outputs:", output_dir, "\n")
