#!/usr/bin/env Rscript
# Reproducible deterministic cluster-correspondence validation.
# After installing this checkout: Rscript data-raw/simulate-clusters.R OUTPUT
# Dependencies: driftmapR, ggplot2, and base/recommended R packages.

if (!requireNamespace("driftmapR", quietly = TRUE) ||
    !requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install driftmapR and ggplot2 before running this script.", call. = FALSE)
}
library(driftmapR)
library(ggplot2)
if (!exists("match_clusters", envir = asNamespace("driftmapR"), inherits = FALSE)) {
  stop("The installed driftmapR must include match_clusters().", call. = FALSE)
}
arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments)) arguments[[1L]] else "../cluster-simulation-output"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output_dir)) stop("Could not create output directory.")
output_dir <- normalizePath(output_dir, mustWork = TRUE)
set.seed(260911)

# Each fixture supplies its labels. There is no newly fitted clustering model.
make_input <- function(ids, labels) {
  do.call(rbind, lapply(seq_along(ids), function(period) {
    n <- length(ids[[period]])
    stopifnot(length(labels[[period]]) == n)
    data.frame(entity = ids[[period]], time = period,
               x = seq_len(n) / max(n, 1L), y = rnorm(n, sd = 0.2),
               cluster = labels[[period]], stringsAsFactors = FALSE)
  }))
}
make_expected <- function(period, current, previous = NA_character_) {
  data.frame(period_index = period, cluster_original = current,
             previous_original = previous, stringsAsFactors = FALSE)
}
two_period <- function(ids_from, ids_to, labels_from, labels_to,
                       previous, current) {
  list(input = make_input(list(ids_from, ids_to), list(labels_from, labels_to)),
       expected = make_expected(2L, current, previous))
}

ids12 <- sprintf("E%02d", 1:12)
fixtures <- list(
  label_permutation = two_period(ids12, ids12, rep(c("A", "B", "C"), each = 4L),
                                 rep(c("Y", "Z", "X"), each = 4L),
                                 c("A", "B", "C"), c("Y", "Z", "X")),
  entity_switching = two_period(ids12, ids12, rep(c("A", "B"), each = 6L),
                                c(rep("X", 5L), "Y", "X", rep("Y", 5L)),
                                c("A", "B"), c("X", "Y")),
  split = two_period(letters[1:8], letters[1:8], rep("A", 8L),
                     c(rep("X", 6L), rep("Y", 2L)), c("A", NA), c("X", "Y")),
  merge = two_period(letters[1:8], letters[1:8], c(rep("A", 6L), rep("B", 2L)),
                     rep("X", 8L), "A", "X"),
  entrants_exits = two_period(letters[1:6], letters[c(1:3, 7:9)],
                              rep(c("A", "B"), each = 3L),
                              rep(c("X", "Y"), each = 3L), c("A", NA), c("X", "Y")),
  exact_tie = two_period(letters[1:4], letters[1:4], c("A", "A", "B", "B"),
                         c("X", "Y", "X", "Y"), c("A", "B"), c("X", "Y")),
  no_shared_entities = two_period(letters[1:4], letters[5:8],
                                  c("A", "A", "B", "B"), c("X", "X", "Y", "Y"),
                                  c(NA, NA), c("X", "Y")),
  assignment_conflict = two_period(letters[1:13], letters[1:13],
                                   c(rep("A", 9L), rep("B", 4L)),
                                   c(rep("X", 5L), rep("Y", 4L), rep("X", 4L)),
                                   c("B", "A"), c("X", "Y"))
)

# Five periods, 96 observations each, 136 unique entities. The imposed labels
# include exchange of four entities in each direction, a 20/12 split, a merge,
# and clusters observed only among new entities. Coordinates are irrelevant to
# overlap matching and deliberately carry no inferential role in this example.
entity <- function(i) sprintf("E%03d", i)
a_after_switch <- c(1:28, 61:64)
b_after_switch <- 29:60
ids <- list(1:96, 1:96, c(1:88, 97:104), c(1:88, 105:112),
            c(1:64, 105:136))
labels <- list(
  rep(c("A_1", "B_1", "C_1"), each = 32L),
  ifelse(ids[[2L]] %in% a_after_switch, "raw_20",
         ifelse(ids[[2L]] %in% b_after_switch, "raw_30", "raw_10")),
  ifelse(ids[[3L]] %in% 1:20, "part_1",
         ifelse(ids[[3L]] %in% c(21:28, 61:64), "part_2",
                ifelse(ids[[3L]] %in% b_after_switch, "part_3",
                       ifelse(ids[[3L]] %in% 65:88, "part_4", "part_5")))),
  ifelse(ids[[4L]] %in% a_after_switch, "merge_1",
         ifelse(ids[[4L]] %in% b_after_switch, "merge_2",
                ifelse(ids[[4L]] %in% 65:88, "merge_3", "merge_4"))),
  ifelse(ids[[5L]] %in% a_after_switch, "final_2",
         ifelse(ids[[5L]] %in% b_after_switch, "final_4",
                ifelse(ids[[5L]] %in% 105:112, "final_1", "final_3")))
)
fixtures$five_period_panel <- list(
  input = make_input(lapply(ids, entity), labels),
  expected = rbind(
    make_expected(2L, c("raw_20", "raw_30", "raw_10"), c("A_1", "B_1", "C_1")),
    make_expected(3L, paste0("part_", 1:5), c("raw_20", NA, "raw_30", "raw_10", NA)),
    make_expected(4L, paste0("merge_", 1:4), c("part_1", "part_3", "part_4", NA)),
    make_expected(5L, paste0("final_", 1:4), c("merge_4", "merge_1", NA, "merge_2"))
  )
)

# Independent exhaustive search is intentionally limited to these small known-
# truth matrices. Each row selects one positive edge or remains unmatched.
# It does not call the package's assignment solver or consume its chosen edges.
brute_optimum <- function(weights) {
  best <- -Inf
  count <- 0L
  walk <- function(row, used, value) {
    if (row > nrow(weights)) {
      if (value > best) { best <<- value; count <<- 1L }
      else if (value == best) count <<- count + 1L
      return(invisible(NULL))
    }
    walk(row + 1L, used, value)
    choices <- setdiff(which(weights[row, ] > 0L), used)
    for (column in choices) {
      walk(row + 1L, c(used, column), value + weights[row, column])
    }
    invisible(NULL)
  }
  walk(1L, integer(), 0)
  list(objective = best, n_optimal = count)
}

all_metrics <- list()
all_checks <- list()
all_flows <- list()
models <- list()
counter <- 0L
for (scenario in names(fixtures)) {
  fixture <- fixtures[[scenario]]
  scenario_dir <- file.path(output_dir, scenario)
  dir.create(scenario_dir, showWarnings = FALSE)
  fit <- drift_data(fixture$input) |> match_clusters()
  models[[scenario]] <- fit
  membership <- fit$clusters
  diagnostics <- fit$diagnostics$cluster_matching
  write.csv(fixture$input, file.path(scenario_dir, "input.csv"), row.names = FALSE)
  write.csv(fixture$expected, file.path(scenario_dir, "expected_correspondence.csv"), row.names = FALSE)
  write.csv(membership, file.path(scenario_dir, "memberships.csv"), row.names = FALSE)
  for (component in c("registry", "assignments", "transitions", "periods")) {
    if (!is.data.frame(diagnostics[[component]])) {
      stop("Missing diagnostic table: ", component)
    }
    write.csv(diagnostics[[component]], file.path(scenario_dir, paste0(component, ".csv")),
              row.names = FALSE)
  }
  saveRDS(fit, file.path(scenario_dir, "model.rds"), version = 3)
  saveRDS(diagnostics, file.path(scenario_dir, "diagnostics.rds"), version = 3)
  # Retain exact dimension names in RDS; long CSV permits ordinary inspection.
  for (kind in c("overlap_matrices", "score_matrices")) {
    values <- diagnostics[[kind]]
    saveRDS(values, file.path(scenario_dir, paste0(kind, ".rds")), version = 3)
    for (j in seq_along(values)) {
      value <- values[[j]]
      if (is.matrix(value)) {
        long <- as.data.frame(as.table(value), stringsAsFactors = FALSE)
        names(long) <- c("cluster_from", "cluster_to", "value")
        write.csv(long, file.path(scenario_dir, sprintf("%s_%02d.csv", kind, j)),
                  row.names = FALSE)
      }
    }
  }
  for (period in seq.int(2L, length(unique(fixture$input$time)))) {
    previous <- membership[membership$period_index == period - 1L, ]
    current <- membership[membership$period_index == period, ]
    from <- unique(previous[c("cluster_original", "cluster_id")])
    to <- unique(current[c("cluster_original", "cluster_id")])
    from <- from[order(from$cluster_original), ]
    to <- to[order(to$cluster_original), ]
    shared <- merge(previous[c("entity", "cluster_original")],
                    current[c("entity", "cluster_original")], by = "entity",
                    suffixes = c("_from", "_to"))
    overlap <- table(factor(shared$cluster_original_from, levels = from$cluster_original),
                     factor(shared$cluster_original_to, levels = to$cluster_original))
    optimum <- brute_optimum(overlap)
    selected <- outer(from$cluster_id, to$cluster_id, `==`)
    objective <- sum(overlap[selected])
    if (any(selected & overlap == 0L)) stop("A zero-overlap identity was preserved.")
    flow <- as.data.frame(as.table(overlap), stringsAsFactors = FALSE)
    names(flow) <- c("cluster_from", "cluster_to", "n_overlap")
    flow$selected <- as.vector(selected)
    flow$scenario <- scenario
    flow$boundary <- paste0("Period ", period - 1L, " to ", period)
    flow$from_id <- from$cluster_id[match(flow$cluster_from, from$cluster_original)]
    flow$to_id <- to$cluster_id[match(flow$cluster_to, to$cluster_original)]
    from_degree <- rowSums(overlap > 0L)
    to_degree <- colSums(overlap > 0L)
    flow$split_candidate <- flow$n_overlap > 0L &
      from_degree[match(flow$cluster_from, from$cluster_original)] > 1L
    flow$merge_candidate <- flow$n_overlap > 0L &
      to_degree[match(flow$cluster_to, to$cluster_original)] > 1L
    expected <- fixture$expected[fixture$expected$period_index == period, ]
    observed_parent <- from$cluster_original[match(to$cluster_id, from$cluster_id)]
    expected_parent <- expected$previous_original[match(to$cluster_original, expected$cluster_original)]
    correct <- ifelse(is.na(expected_parent), is.na(observed_parent),
                      !is.na(observed_parent) & observed_parent == expected_parent)
    checks <- data.frame(scenario = scenario, period_index = period,
                         cluster_original = to$cluster_original,
                         expected_previous = expected_parent,
                         observed_previous = observed_parent, passed = correct,
                         stringsAsFactors = FALSE)
    diag_period <- diagnostics$periods[diagnostics$periods$time_to == period, ]
    if (nrow(diag_period) != 1L) stop("Missing period diagnostic row.")
    counter <- counter + 1L
    all_flows[[counter]] <- flow
    all_checks[[counter]] <- checks
    all_metrics[[counter]] <- data.frame(
      scenario = scenario, period_index = period, n_entities_from = nrow(previous),
      n_entities_to = nrow(current), n_shared_entities = nrow(shared),
      n_clusters_from = nrow(from), n_clusters_to = nrow(to),
      n_expected_correspondences = nrow(checks), correspondence_errors = sum(!correct),
      n_matched = sum(selected), n_new = sum(!to$cluster_id %in% from$cluster_id),
      n_unmatched_previous = sum(!from$cluster_id %in% to$cluster_id),
      observed_objective = objective, exhaustive_objective = optimum$objective,
      n_optimal_assignments = optimum$n_optimal,
      package_objective = diag_period$objective_overlap,
      package_ambiguous = diag_period$has_ambiguous_assignment,
      n_split_candidate_sources = sum(from_degree > 1L),
      n_merge_candidate_destinations = sum(to_degree > 1L),
      stringsAsFactors = FALSE
    )
  }
}
metrics <- do.call(rbind, all_metrics)
checks <- do.call(rbind, all_checks)
flows <- do.call(rbind, all_flows)
write.csv(metrics, file.path(output_dir, "simulation_metrics.csv"), row.names = FALSE)
write.csv(checks, file.path(output_dir, "correspondence_checks.csv"), row.names = FALSE)
write.csv(flows, file.path(output_dir, "independent_overlap_cells.csv"), row.names = FALSE)
saveRDS(models, file.path(output_dir, "simulation_models.rds"), version = 3)
writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))

# Fail visibly while preserving exported diagnostics if any acceptance gate fails.
stopifnot(all(checks$passed), all(metrics$observed_objective == metrics$exhaustive_objective),
          all(metrics$package_objective == metrics$exhaustive_objective),
          all(metrics$package_ambiguous == (metrics$n_optimal_assignments > 1L)))

theme_simulation <- theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank(), plot.title = element_text(face = "bold", size = 15),
        strip.text = element_text(face = "bold"), legend.position = "bottom",
        axis.text.x = element_text(angle = 35, hjust = 1),
        plot.title.position = "plot", plot.caption = element_text(hjust = 0, size = 10),
        plot.background = element_rect(fill = "white", color = NA))
heatmap <- function(data, facet, title, subtitle, caption, columns) {
  data$panel <- data[[facet]]
  ggplot(data, aes(x = cluster_to, y = cluster_from)) +
    geom_tile(aes(fill = n_overlap), color = "white", linewidth = 0.8) +
    geom_tile(data = data[data$selected, ], fill = NA, color = "#1E2530", linewidth = 1) +
    geom_text(aes(label = ifelse(n_overlap > 0L, n_overlap, "")), size = 3.7, color = "#142C3E") +
    facet_wrap(~panel, scales = "free", ncol = columns) +
    scale_fill_gradient(low = "#F2F4F6", high = "#91BCCB", name = "Shared entities") +
    labs(title = title, subtitle = subtitle, x = "Current supplied cluster label",
         y = "Previous supplied cluster label", caption = caption) + theme_simulation
}
export_plot <- function(graph, name, width, height) {
  ggsave(file.path(output_dir, paste0(name, ".png")), graph, width = width, height = height,
         dpi = 180, bg = "white")
  ggsave(file.path(output_dir, paste0(name, ".pdf")), graph, width = width, height = height,
         bg = "white")
}
main_plot <- heatmap(
  flows[flows$scenario == "five_period_panel", ], "boundary",
  "Shared membership preserves identities across relabeling and turnover",
  "Five periods; 96 observations per period; dark outlines show the selected one-to-one correspondence",
  paste("Cells count entities observed and labeled in both periods; zero-overlap cells cannot inherit an identity.",
        "Multiple positive cells can reflect switching, splitting, or merging; these counts do not identify the cause.",
        "Entirely new clusters have no outlined cell. No clustering model or uncertainty interval is fitted.", sep = "\n"),
  2L)
export_plot(main_plot, "01_five_period_overlap", 12, 9.2)
fixture_flows <- flows[flows$scenario != "five_period_panel", ]
fixture_flows$scenario <- factor(fixture_flows$scenario, levels = names(fixtures)[1:8],
                                 labels = c("Label permutation", "Entity switching", "Split",
                                            "Merge", "Entrants and exits", "Exact tie",
                                            "No shared entities", "Global assignment conflict"))
fixture_plot <- heatmap(
  fixture_flows, "scenario", "Controlled cases expose what one-to-one correspondence can establish",
  "Each outlined assignment passes an independent exhaustive maximum-overlap check",
  paste("In the exact tie, either full matching has equal overlap; the documented label order selects one reproducibly.",
        "A split preserves one parent identity; a merge preserves one predecessor. These are bookkeeping decisions.",
        "The conflict example chooses 4 + 4 shared entities over the locally largest edge of 5.", sep = "\n"), 4L)
export_plot(fixture_plot, "02_synthetic_correspondence_cases", 13, 8.3)

writeLines(c(
  "driftmapR cluster-correspondence synthetic validation", "",
  "Seed: 260911. Eight small deterministic fixtures plus a five-period panel.",
  "The panel contains 96 observations per period and 136 unique entity identifiers.",
  "Coordinates are supplied for the data object; matching uses shared labeled membership only.",
  "All fixture labels and expected parent correspondences are specified independently of the solver.",
  "The exhaustive reference enumerates positive-edge partial assignments on small overlap matrices.", "",
  sprintf("Passed correspondence checks: %d of %d.", sum(checks$passed), nrow(checks)),
  sprintf("Verified maximum-overlap objectives and ambiguity flags at %d adjacent boundaries.", nrow(metrics)),
  "A unique optimum need not establish substantive continuity; a tie means the objective cannot distinguish alternatives.",
  "New identities reflect unmatched clusters, including no overlap or assignment competition; they are not inferred births.",
  "A lost identity is not resurrected after an absent period. Split/merge flags describe overlap topology only.",
  "The switching fixture intentionally has both kinds of candidate flag without a generating split or merge.",
  "No bootstrap, inferential uncertainty, clustering fit, or probabilistic split/merge model is implemented.", "",
  "Each scenario directory holds input, truth, memberships, assignments, transitions, period diagnostics,",
  "exact matrix RDS files, inspectable matrix CSV files, the model, and all diagnostics.",
  "The root contains checks, numerical summaries, independent overlap cells, models, figures, and sessionInfo.",
  "Figures are available as PNG and PDF. Counts describe these fixed fixtures, not population-level performance.",
  "Reproduce: Rscript data-raw/simulate-clusters.R PATH_TO_OUTPUT_DIRECTORY"
), file.path(output_dir, "README.txt"))
cat(sprintf("Cluster simulation completed: %s\n", output_dir))
print(metrics, row.names = FALSE)
cat(sprintf("Passed %d correspondence checks across %d boundaries.\n", nrow(checks), nrow(metrics)))
