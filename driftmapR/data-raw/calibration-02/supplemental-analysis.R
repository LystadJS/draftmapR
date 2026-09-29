#!/usr/bin/env Rscript
# Execution addendum: produce the full-refit versus population-tangent paired
# contrasts already specified in the frozen protocol. Frozen files are unchanged.

study02_tangent_contrasts <- function(regions) {
  if (!exists("study02_paired_difference", mode = "function")) {
    stop("Source the frozen analyze.R before this supplemental analyzer.", call. = FALSE)
  }
  keys <- c("m", "anchor", "estimator", "entity", "budget", "method")
  required <- c(keys, "dataset_id", "delivered", "covered")
  if (!is.data.frame(regions) || !all(required %in% names(regions))) {
    stop("Regions are missing required paired-contrast columns.", call. = FALSE)
  }
  levels <- c("refit_plugin", "tangent_oracle")
  selected <- regions[regions$estimator %in% levels, , drop = FALSE]
  if (!all(levels %in% selected$estimator) || anyNA(selected[c(keys, "dataset_id", "delivered")]) ||
      anyNA(selected$covered[selected$delivered])) {
    stop("Full-refit and tangent rows require complete keys and delivered outcomes.", call. = FALSE)
  }
  rows <- list()
  for (g in study02_groups(selected, setdiff(keys, "estimator"))) {
    a <- g[g$estimator == levels[1], , drop = FALSE]
    b <- g[g$estimator == levels[2], , drop = FALSE]
    if (anyDuplicated(a$dataset_id) || anyDuplicated(b$dataset_id) ||
        !setequal(a$dataset_id, b$dataset_id)) {
      stop("Full-refit and tangent contrasts require identical unique dataset keys.", call. = FALSE)
    }
    b <- b[match(a$dataset_id, b$dataset_id), , drop = FALSE]
    both <- a$delivered & b$delivered
    outcomes <- list(
      conditional_coverage_joint_delivery = list(a$covered[both], b$covered[both]),
      delivery = list(a$delivered, b$delivered),
      operational_yield = list(a$delivered & !is.na(a$covered) & a$covered,
                               b$delivered & !is.na(b$covered) & b$covered))
    for (metric in names(outcomes)) {
      result <- study02_paired_difference(outcomes[[metric]][[1]], outcomes[[metric]][[2]])
      meta <- a[1L, keys, drop = FALSE]
      meta$estimator <- "paired"
      rows[[length(rows) + 1L]] <- data.frame(meta,
        comparison_dimension = "estimator", level_from = levels[1], level_to = levels[2],
        metric = metric, n_outer = nrow(a), n_joint_delivered = sum(both),
        as.list(result), stringsAsFactors = FALSE, row.names = NULL)
    }
  }
  do.call(rbind, rows)
}

study02_supplemental_analyze <- function(output_dir) {
  path <- file.path(output_dir, "regions.csv")
  if (!file.exists(path)) stop("Missing completed-study regions.csv.", call. = FALSE)
  regions <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  result <- study02_tangent_contrasts(regions)
  utils::write.csv(result, file.path(output_dir, "tangent-contrasts-summary.csv"),
    row.names = FALSE, na = "")
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript supplemental-analysis.R output_dir")
  script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
  source(file.path(dirname(normalizePath(script)), "analyze.R"))
  study02_supplemental_analyze(args[1L])
}
