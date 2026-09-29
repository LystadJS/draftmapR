#!/usr/bin/env Rscript
# Independent mechanical reconciliation; this does not establish calibration.

study02_validation_key <- function(x, columns) do.call(paste, c(x[columns], sep = "\r"))

study02_same_table <- function(a, b, keys, tolerance = 1e-10) {
  if (!is.data.frame(a) || !is.data.frame(b) || !setequal(names(a), names(b)) ||
      nrow(a) != nrow(b) || anyDuplicated(study02_validation_key(a, keys)) ||
      anyDuplicated(study02_validation_key(b, keys)) ||
      !setequal(study02_validation_key(a, keys), study02_validation_key(b, keys))) return(FALSE)
  b <- b[match(study02_validation_key(a, keys), study02_validation_key(b, keys)), names(a), drop = FALSE]
  rownames(a) <- rownames(b) <- NULL
  # CSV round trips change integer storage and all-NA column types.
  all(vapply(names(a), function(column) {
    x <- a[[column]]; y <- b[[column]]
    if (!identical(is.na(x), is.na(y))) return(FALSE)
    use <- !is.na(x)
    if (!any(use)) return(TRUE)
    if (is.numeric(x) && is.numeric(y)) {
      return(isTRUE(all.equal(as.numeric(x[use]), as.numeric(y[use]),
                              tolerance = tolerance, check.attributes = FALSE)))
    }
    identical(as.character(x[use]), as.character(y[use]))
  }, logical(1)))
}

study02_validate_result <- function(result, B = result$B, budgets = result$budgets,
                                    regenerate_tangent = TRUE) {
  checks <- character()
  check <- function(label, condition) {
    if (!isTRUE(condition)) stop(label, call. = FALSE)
    checks <<- c(checks, label)
  }
  job <- result$job; m <- job$m
  check("planned draw budget", identical(as.integer(result$B), as.integer(B)) &&
          identical(as.integer(result$budgets), as.integer(budgets)) && all(budgets <= B))
  check("unit multiplicities", is.matrix(result$weights) &&
          identical(dim(result$weights), c(as.integer(B), as.integer(m))) &&
          all(is.finite(result$weights)) && all(result$weights >= 0) &&
          all(result$weights == floor(result$weights)) && all(rowSums(result$weights) == m))
  check("retained draw streams", is.matrix(result$streams) &&
          identical(dim(result$streams), c(as.integer(B), 7L)) && !anyNA(result$streams) &&
          !anyDuplicated(apply(result$streams, 1L, paste, collapse = ";")))
  # Restore RNG state after replaying the saved independent draw streams.
  old_kind <- RNGkind(); had_seed <- exists(".Random.seed", .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", .GlobalEnv, inherits = FALSE)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, .GlobalEnv)
    else if (exists(".Random.seed", .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection"); set.seed(job$bootstrap_seed)
  stream <- .Random.seed
  replay <- matrix(0L, B, m); correct_streams <- TRUE
  for (b in seq_len(B)) {
    correct_streams <- correct_streams && identical(as.integer(result$streams[b, ]), stream)
    assign(".Random.seed", stream, .GlobalEnv)
    replay[b, ] <- tabulate(sample.int(m, m, replace = TRUE), nbins = m)
    stream <- parallel::nextRNGStream(stream)
  }
  check("independent stream replay and no redraw", correct_streams &&
          identical(unname(replay), unname(result$weights)))
  anchors <- c("original", "spread")
  estimators <- c("refit_plugin", "refit_oracle", "tangent_oracle")
  entities <- c("E015", "E003", "E006")
  check("planned anchor panels", setequal(names(result$panels), anchors))
  for (anchor in anchors) {
    p <- result$panels[[anchor]]
    check(paste(anchor, "estimator set"), setequal(names(p$estimates), estimators) &&
            setequal(names(p$values), estimators) && setequal(names(p$success), estimators))
    check(paste(anchor, "paired full point estimates"), identical(p$estimates$refit_plugin,
                                                                  p$estimates$refit_oracle))
    for (estimator in estimators) {
      label <- paste(anchor, estimator)
      ok <- p$success[[estimator]]; observed_ok <- p$observed_ok[[estimator]]
      val <- p$values[[estimator]]; point <- p$estimates[[estimator]]
      check(paste(label, "complete success ledger"), is.logical(ok) && length(ok) == B &&
              !anyNA(ok) && is.logical(observed_ok) && length(observed_ok) == 1L && !is.na(observed_ok))
      check(paste(label, "array dimensions"), identical(dim(val), c(as.integer(B), 3L, 2L)) &&
              identical(dim(point), c(3L, 2L)))
      check(paste(label, "success and failure vectors"), all(is.finite(val[ok, , , drop = FALSE])) &&
              all(is.na(val[!ok, , , drop = FALSE])) &&
              if (observed_ok) all(is.finite(point)) else all(is.na(point)) && !any(ok))
      f <- result$failures[result$failures$anchor == anchor &
                              result$failures$estimator == estimator, , drop = FALSE]
      check(paste(label, "planned attempt accounting"), nrow(f) == B &&
              identical(f$replicate_id, seq_len(B)) && identical(f$success, ok) &&
              all(f$attempted == observed_ok) && all(!f$success | f$attempted) &&
              identical(as.character(f$stage), as.character(p$stages[[estimator]])) &&
              all(f$stage[ok] == "ok") && all(nzchar(f$message[!ok])))
      e <- result$estimates[result$estimates$anchor == anchor &
                             result$estimates$estimator == estimator, , drop = FALSE]
      check(paste(label, "estimate rows and primary gate"), nrow(e) == 3L &&
              identical(as.character(e$entity), entities) && all(e$observed_success == observed_ok) &&
              all(e$passes_gate == (observed_ok && sum(ok) >= 20L && mean(ok) >= .95)) &&
              isTRUE(all.equal(unname(as.matrix(e[c("dx", "dy")])), unname(point), tolerance = 1e-12)))
      for (budget in budgets) for (j in seq_along(entities)) {
        use <- which(ok[seq_len(budget)])
        draws <- matrix(val[use, j, ], ncol = 2L)
        expected <- calibration_regions(if (observed_ok) as.numeric(point[j, ]) else c(0, 0),
                                         draws, c(0, 0))
        gate <- observed_ok && length(use) >= 20L && length(use) / budget >= .95
        if (!observed_ok) {
          expected$available <- FALSE; expected$reason <- "observed_fit_failed"
          expected$covered <- expected$rejects_zero <- NA
        }
        expected$gate <- gate; expected$delivered <- expected$available & gate
        expected$covered[!expected$delivered] <- NA
        expected$rejects_zero[!expected$delivered] <- NA
        got <- result$regions[result$regions$anchor == anchor &
                  result$regions$estimator == estimator & result$regions$entity == entities[j] &
                  result$regions$budget == budget, names(expected), drop = FALSE]
        check(paste(label, budget, entities[j], "joint region reconstruction"),
              study02_same_table(expected, got, "method", tolerance = 1e-11))
      }
    }
  }
  tc <- result$tangent_covariance
  tangent_anchors <- anchors[vapply(result$panels[anchors], function(p) p$observed_ok[["tangent_oracle"]], logical(1))]
  check("tangent covariance key completeness", if (!length(tangent_anchors)) is.null(tc) || nrow(tc) == 0L
        else is.data.frame(tc) && nrow(tc) == 3L * length(tangent_anchors) &&
          setequal(tc$anchor, tangent_anchors) &&
          !anyDuplicated(study02_validation_key(tc, c("anchor", "entity"))))
  if (length(tangent_anchors)) check("tangent covariance additive decomposition",
          all(is.finite(as.matrix(tc[5:ncol(tc)]))) &&
          max(abs(tc$total_trace - tc$embedding_trace - tc$alignment_trace - tc$cross_trace)) < 1e-10 &&
          max(abs(tc$total_trace - tc$exact_var_dx - tc$exact_var_dy)) < 1e-10)
  if (regenerate_tangent && length(tangent_anchors)) {
    g <- study02_generate(job); model <- g$model
    for (anchor in tangent_anchors) {
      unit <- lapply(seq_len(m), function(j) study02_tangent(
        tcrossprod(g$X[[2L]][, j]) - tcrossprod(g$X[[1L]][, j]), model$spectrum,
        model$anchors[[anchor]]))
      for (k in seq_along(entities)) {
        row <- model$target_rows[k]
        matrices <- lapply(c("full", "embedding", "alignment"), function(component)
          do.call(rbind, lapply(unit, function(x) x[[component]][row, ])))
        centered <- lapply(matrices, function(x) sweep(x, 2L, colMeans(x), "-"))
        covariance <- crossprod(centered[[1L]]) / m^2
        expected <- c(covariance[1, 1], covariance[2, 2], covariance[1, 2],
          sum(centered[[2L]]^2) / m^2, sum(centered[[3L]]^2) / m^2,
          2 * sum(centered[[2L]] * centered[[3L]]) / m^2, sum(diag(covariance)))
        got <- tc[tc$anchor == anchor & tc$entity == entities[k], 5:ncol(tc)]
        check(paste(anchor, entities[k], "exact conditional unit covariance"),
              isTRUE(all.equal(unname(as.numeric(got)), expected, tolerance = 1e-11)))
      }
    }
  }
  data.frame(check = checks, passed = TRUE, stringsAsFactors = FALSE)
}

study02_validate <- function(output_dir, expected_m = c(20L, 40L, 160L, 640L),
                             M = 240L, B = 399L, budgets = c(199L, 399L)) {
  output_dir <- normalizePath(output_dir)
  log <- list()
  add <- function(name, passed, detail = "") {
    log[[length(log) + 1L]] <<- data.frame(check = name, passed = isTRUE(passed), detail = detail)
  }
  read <- function(name) utils::read.csv(file.path(output_dir, name),
     stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("NA", ""))
  # Preserve empty diagnostic message strings during ledger reconciliation.
  read_table <- function(name) {
    x <- read(paste0(name, ".csv"))
    for (column in intersect(c("message", "reason"), names(x))) x[[column]][is.na(x[[column]])] <- ""
    x
  }
  freeze <- readRDS(file.path(output_dir, "frozen-design.rds"))
  seeds <- readRDS(file.path(output_dir, "seed-plan.rds"))
  paths <- list.files(file.path(output_dir, "checkpoints"), "[.]rds$", full.names = TRUE)
  n <- length(expected_m) * M
  add("independent panel denominator", length(paths) == n && length(seeds) == n)
  seed_keys <- vapply(seeds, function(j) paste(j$m, j$dataset_id, sep = "/"), character(1))
  planned <- expand.grid(m = expected_m, dataset_id = seq_len(M))
  add("planned unique independent dataset keys", !anyDuplicated(seed_keys) &&
        setequal(seed_keys, paste(planned$m, planned$dataset_id, sep = "/")))
  add("distinct independent data streams", !anyDuplicated(vapply(seeds,
       function(j) paste(j$data_stream, collapse = ";"), character(1))))
  add("distinct bootstrap seeds", !anyDuplicated(vapply(seeds, `[[`, integer(1), "bootstrap_seed")))
  if (identical(as.integer(expected_m), study02_settings()$m) && M == study02_settings()$M) {
    add("prespecified fresh master stream and bootstrap namespace", identical(seeds, study02_jobs()))
  }
  seed_csv <- read("seed-plan.csv")
  expected_seed_csv <- do.call(rbind, lapply(seeds, function(j) data.frame(m = j$m,
    dataset_id = j$dataset_id, bootstrap_seed = j$bootstrap_seed,
    data_stream = paste(j$data_stream, collapse = ";"))))
  add("CSV and RDS seed plan agreement", study02_same_table(expected_seed_csv, seed_csv, c("m", "dataset_id")))
  copied <- file.path(output_dir, "source", "calibration-02", freeze$files)
  add("frozen source snapshot hashes", all(file.exists(copied)) &&
        identical(unname(tools::md5sum(copied)), freeze$md5))
  manifest_path <- file.path(output_dir, "source-hashes-before-run.csv")
  if (file.exists(manifest_path)) {
    manifest <- read("source-hashes-before-run.csv")
    add("saved source hash manifest", identical(as.character(manifest$file), freeze$files) &&
          identical(as.character(manifest$md5), freeze$md5))
  }
  tables <- c("outer", "regions", "estimates", "failures", "tangent_covariance", "audit")
  rows <- setNames(lapply(tables, function(x) vector("list", length(paths))), tables)
  for (i in seq_along(paths)) {
    r <- readRDS(paths[i]); label <- sprintf("m%04d/%03d", r$job$m, r$job$dataset_id)
    index <- match(paste(r$job$m, r$job$dataset_id, sep = "/"), seed_keys)
    add(paste(label, "frozen job identity"), !is.na(index) && identical(r$job, seeds[[index]]) &&
          identical(r$freeze, freeze))
    result <- tryCatch(study02_validate_result(r, B, budgets), error = function(e) e)
    if (inherits(result, "error")) add(paste(label, "checkpoint reconciliation"), FALSE, conditionMessage(result))
    else for (j in seq_len(nrow(result))) add(paste(label, result$check[j]), result$passed[j])
    for (name in tables) rows[[name]][[i]] <- r[[name]]
  }
  aggregates <- lapply(rows, function(x) do.call(rbind, x))
  keys <- list(outer = c("m", "dataset_id"),
    estimates = c("m", "dataset_id", "anchor", "estimator", "entity"),
    regions = c("m", "dataset_id", "anchor", "estimator", "entity", "budget", "method"),
    failures = c("m", "dataset_id", "anchor", "estimator", "replicate_id"),
    tangent_covariance = c("m", "dataset_id", "anchor", "entity"),
    audit = c("m", "dataset_id", "anchors"))
  for (name in tables) add(paste(name, "CSV checkpoint reconciliation"),
    study02_same_table(aggregates[[name]], read_table(name), keys[[name]]))
  outer <- aggregates$outer; regions <- aggregates$regions; estimates <- aggregates$estimates
  failures <- aggregates$failures; audit <- aggregates$audit
  add("all planned ledger rows", nrow(failures) == n * 2L * 3L * B)
  add("all planned observed estimate rows", nrow(estimates) == n * 2L * 3L * 3L)
  add("all planned region rows", nrow(regions) == n * 2L * 3L * 3L * length(budgets) * 3L)
  add("exact bounded weighted refits", all(outer$B == B) && all(outer$n_unique_weighted_refits == B))
  add("preselected public engine audits", nrow(audit) == length(expected_m) * min(3L, M) * 2L &&
        all(audit$dataset_id %in% seq_len(min(3L, M))) && all(audit$passed) &&
        all(audit$B == B) && all(audit$n_attempted == B) && all(audit$streams_identical) &&
        all(audit$failure_ledger_identical) && all(audit$oracle_ledger_identical) &&
        all(audit$max_feature_count_diff == 0) && all(audit$max_estimate_abs_diff <= audit$tolerance) &&
        all(audit$max_plugin_vector_abs_diff <= audit$tolerance) &&
        all(audit$max_oracle_vector_abs_diff <= audit$tolerance))
  structural <- tryCatch(study02_validate_analysis(outer, estimates, regions, failures,
                         expected_outer = M, expected_m = expected_m, budgets = budgets), error = function(e) e)
  add("aggregate independent denominator checks", !inherits(structural, "error"),
      if (inherits(structural, "error")) conditionMessage(structural) else "")
  summaries <- list(coverage = study02_coverage_summary(outer, estimates, regions),
    covariance = study02_covariance_summary(estimates, regions[regions$budget == max(budgets), ]),
    errors = study02_error_summary(estimates), contrasts = study02_paired_contrasts(regions),
    attempts = study02_attempt_summary(failures, budgets),
    tangent = study02_tangent_summary(aggregates$tangent_covariance, regions, outer, max(budgets)))
  summary_keys <- list(coverage = c("m", "anchor", "estimator", "entity", "budget", "method"),
    covariance = c("m", "anchor", "estimator", "entity", "budget"),
    errors = c("m", "anchor", "estimator", "entity", "cohort"),
    contrasts = c("m", "anchor", "estimator", "entity", "budget", "method",
                  "comparison_dimension", "level_from", "level_to", "metric"),
    attempts = c("m", "anchor", "estimator", "budget"),
    tangent = c("m", "anchor", "entity", "budget"))
  for (name in names(summaries)) add(paste(name, "summary reconstruction"),
     study02_same_table(summaries[[name]], read(paste0(name, "-summary.csv")), summary_keys[[name]]))
  answer <- do.call(rbind, log)
  write.csv(answer, file.path(output_dir, "mechanical-validation.csv"), row.names = FALSE)
  writeLines(c(sprintf("%d mechanical checks; %d passed; %d failed.", nrow(answer),
     sum(answer$passed), sum(!answer$passed)),
     "Passing verifies accounting and numerical reconstruction, not nominal coverage."),
     file.path(output_dir, "mechanical-validation.txt"))
  if (!all(answer$passed)) stop("Mechanical validation failed; inspect mechanical-validation.csv.", call. = FALSE)
  invisible(answer)
}

study02_validation_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) != 1L) stop("Usage: Rscript validate.R /absolute/completed-study-output", call. = FALSE)
  script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script))
  source(file.path(source_dir, "run.R"), local = .GlobalEnv)
  study02_load(source_dir)
  source(file.path(source_dir, "analyze.R"), local = .GlobalEnv)
  result <- study02_validate(args[1L])
  cat(nrow(result), "mechanical checks passed.\n")
}
if (sys.nframe() == 0L) study02_validation_main()
