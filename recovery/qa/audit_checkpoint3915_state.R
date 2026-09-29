#!/usr/bin/env Rscript
# Audit-only, base-R checks. This script DOES NOT source the frozen runner,
# regenerate inputs, fit models, resample, modify checkpoints, or launch controls.
# Adapted for local paths and native Windows R 4.5.3 inspection; not the pinned Linux runtime.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: audit_saved_state.R AUDIT_ROOT")
root <- normalizePath(args[[1]], mustWork = TRUE)
state <- file.path(root, "recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state")
sources <- file.path(root, "recovered/driftmapR-S07-R1-sources")
output <- file.path(root, "qa", "checkpoint3915-state")
checks <- list()
check <- function(name, passed, detail = "") {
  checks[[length(checks) + 1L]] <<- data.frame(check = name,
    passed = isTRUE(passed), detail = paste(detail, collapse = ";"))
}
seed_existed_before <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
seed_before <- if (seed_existed_before) get(".Random.seed", envir = .GlobalEnv) else NULL
cat(R.version.string, "\nPurpose: read-only saved-state audit; frozen scientific runtime not reproduced.\n")

# Syntax parsing is deliberately separate from executing this audit script.
rfiles <- sort(list.files(sources, pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE))
parsed <- lapply(rfiles, function(f) {
  error <- tryCatch({parse(file = f); ""}, error = function(e) conditionMessage(e))
  data.frame(path = substring(f, nchar(sources) + 2L), parsed = !nzchar(error), error = error)
})
parsed <- do.call(rbind, parsed)
write.csv(parsed, file.path(output, "r-source-parsing.csv"), row.names = FALSE)
check("Every recovered R source parses under inspection R runtime", all(parsed$parsed), nrow(parsed))
cat("Parsed source files:", nrow(parsed), "; successful:", sum(parsed$parsed), "\n")

# Authenticated frozen metadata are read as data, never executed.
lock <- readRDS(file.path(sources, "study07-recovery/implementation-freeze.rds"))
expected_identity <- lock$source_identity
expected_identity$freeze_id <- "S07-R1"
expected_identity$engineering <- FALSE
expected_identity$jobs <- NULL
expected_identity$freeze_sha256 <- lock$json_sha256
expected_identity$ready_for_recovery <- TRUE
check("Frozen metadata identify scientific R 4.5.3", identical(expected_identity$runtime$R_version, "4.5.3"))
plan <- read.csv(file.path(sources, "study07-specification/design/seed-plan.csv"), stringsAsFactors = FALSE, check.names = FALSE)
plan$key <- paste0(plan$case_id, "-", sprintf("%04d", plan$dataset_id))
check("Frozen plan has exactly 6480 unique jobs", nrow(plan) == 6480L && !anyDuplicated(plan$key))
ledger <- read.csv(file.path(output, "cache-ledger-for-r.csv"), stringsAsFactors = FALSE)
receipt_files <- sort(list.files(file.path(state, "verification-006"), pattern = "\\.rds$", full.names = TRUE))
receipt_keys <- sub("\\.rds$", "", basename(receipt_files))
check("Receipt filenames equal the frozen planned job grid", identical(sort(receipt_keys), sort(plan$key)))
plan_index <- match(receipt_keys, plan$key)
fields <- setdiff(names(plan), c("key", "data_stream"))
rows <- vector("list", length(receipt_files))
for (i in seq_along(receipt_files)) {
  file <- receipt_files[[i]]; key <- receipt_keys[[i]]
  object <- tryCatch(readRDS(file), error = function(e) e)
  if (inherits(object, "error")) {
    rows[[i]] <- data.frame(key = key, readable = FALSE, planned_job_match = FALSE,
      frozen_identity_match = FALSE, ledger_checkpoint_match = FALSE,
      md5_shape_valid = FALSE, driver_sha256 = "", ledger_comparison_applicable = FALSE, problem = conditionMessage(object))
    next
  }
  j <- object$job; idx <- plan_index[[i]]
  scalar_match <- !is.na(idx) && all(vapply(fields, function(field) {
    identical(as.character(j[[field]]), as.character(plan[[field]][[idx]]))
  }, logical(1)))
  stream_match <- !is.na(idx) && identical(paste(j$data_stream, collapse = ";"), plan$data_stream[[idx]])
  filenames <- object$files
  shape <- is.character(filenames) && length(filenames) == length(object$md5) &&
    !anyDuplicated(filenames) && all(grepl("^[a-f0-9]{32}$", object$md5))
  checkpoint_position <- which(endsWith(filenames, paste0("/S07-R1/checkpoints/", key, ".rds")))
  ledger_position <- match(key, ledger$key)
  checkpoint_ok <- length(checkpoint_position) == 1L && (is.na(ledger_position) ||
    identical(object$md5[[checkpoint_position]], ledger$checkpoint_md5[[ledger_position]]))
  rows[[i]] <- data.frame(key = key, readable = TRUE,
    planned_job_match = scalar_match && stream_match,
    frozen_identity_match = identical(object$identity, expected_identity),
    ledger_checkpoint_match = checkpoint_ok, md5_shape_valid = shape,
    driver_sha256 = object$driver_sha256, ledger_comparison_applicable = !is.na(ledger_position), problem = "")
}
receipts <- do.call(rbind, rows)
write.csv(receipts, file.path(output, "r-receipt-audit.csv"), row.names = FALSE)
for (field in c("readable", "planned_job_match", "frozen_identity_match", "ledger_checkpoint_match", "md5_shape_valid")) {
  check(paste("All input-verification receipts:", field), all(receipts[[field]]), if (field == "ledger_checkpoint_match") "6480 checkpoint references; 3916 applicable ledger comparisons" else sum(receipts[[field]]))
}
check("Exactly 3916 receipt-to-cache checkpoint hash comparisons", sum(receipts$ledger_comparison_applicable) == 3916L)
check("Receipts retain one uniform collector driver identity", length(unique(receipts$driver_sha256)) == 1L)
cat("Input-verification receipts read:", nrow(receipts), "; planned job matches:", sum(receipts$planned_job_match), "; frozen identity matches:", sum(receipts$frozen_identity_match), "\n")

# Cache contents are checked for shape and key consistency, not coverage/calibration.
cache_files <- sort(list.files(file.path(state, "compact-cache-005"), pattern = "\\.rds$", full.names = TRUE))
cache_rows <- vector("list", length(cache_files))
# The frozen producer assigns derivative_status from a population-level reference:
# study07-execution/R/diagnostics.R:40 and population.R:47-52.
# It contains case_id and entity, deliberately no dataset_id. Require that exact
# exception, and verify the reference is identical across datasets in each case.
full_components <- c("outer", "estimates", "regions", "selection_panel", "geometry_panel",
 "observed_geometry", "frame_variation_panel", "clean_points", "screen", "linear_regions",
 "analytic_regions", "linear_points", "decomposition_inputs", "covariance_inputs", "derivative_status")
derivative_references <- list()
derivative_references_consistent <- TRUE
derivative_tables_checked <- 0L
for (i in seq_along(cache_files)) {
  file <- cache_files[[i]]; key <- sub("\\.rds$", "", basename(file)); idx <- match(key, plan$key)
  object <- tryCatch(readRDS(file), error = function(e) e)
  if (inherits(object, "error")) {
    cache_rows[[i]] <- data.frame(key = key, readable = FALSE, table_shape_valid = FALSE,
      case_dataset_match = FALSE, tables = 0L, rows = 0L, problem = conditionMessage(object))
    next
  }
  shape <- is.list(object) && length(object) > 0L && !is.null(names(object)) &&
    !anyDuplicated(names(object)) && all(vapply(object, is.data.frame, logical(1)))
  expected_components <- if (is.na(idx)) character() else if (plan$pipeline[[idx]] == "full_estimator") full_components else "normal_regions"
  shape <- shape && identical(names(object), expected_components)
  identity_match <- shape && !is.na(idx) && all(vapply(names(object), function(component) {
    table <- object[[component]]
    case_match <- "case_id" %in% names(table) &&
      all(!is.na(table$case_id) & table$case_id == plan$case_id[[idx]])
    if (component == "derivative_status") {
      return(case_match && !("dataset_id" %in% names(table)) && "entity" %in% names(table))
    }
    case_match && "dataset_id" %in% names(table) &&
      all(!is.na(table$dataset_id) & table$dataset_id == plan$dataset_id[[idx]])
  }, logical(1)))
  if (shape && "derivative_status" %in% names(object)) {
    case_key <- plan$case_id[[idx]]
    derivative_tables_checked <- derivative_tables_checked + 1L
    if (is.null(derivative_references[[case_key]])) {
      derivative_references[[case_key]] <- object$derivative_status
    } else {
      derivative_references_consistent <- derivative_references_consistent &&
        identical(derivative_references[[case_key]], object$derivative_status)
    }
  }
  cache_rows[[i]] <- data.frame(key = key, readable = TRUE, table_shape_valid = shape,
    case_dataset_match = identity_match, tables = length(object),
    rows = if (shape) sum(vapply(object, nrow, integer(1))) else NA_integer_, problem = "")
}
cache_results <- do.call(rbind, cache_rows)
write.csv(cache_results, file.path(output, "r-cache-audit.csv"), row.names = FALSE)
check("Exactly 3916 readable compact caches", nrow(cache_results) == 3916L && all(cache_results$readable))
check("All compact caches have named data-frame components", all(cache_results$table_shape_valid))
check("Every cache table matches its planned panel or explicit population-level schema", all(cache_results$case_dataset_match))
check("All 480 population derivative tables identical within each of 9 cases", derivative_tables_checked == 480L && length(derivative_references) == 9L && derivative_references_consistent)
cat("Compact caches read:", nrow(cache_results), "; valid table structures:", sum(cache_results$table_shape_valid), "; matching case/dataset identities:", sum(cache_results$case_dataset_match), "\n")

seed_existed_after <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
seed_after <- if (seed_existed_after) get(".Random.seed", envir = .GlobalEnv) else NULL
check("Audit did not create or change an R random-number state", identical(seed_existed_before, seed_existed_after) && identical(seed_before, seed_after))
results <- do.call(rbind, checks)
write.csv(results, file.path(output, "r-audit-checks.csv"), row.names = FALSE)
writeLines(c(R.version.string, capture.output(sessionInfo()),
  "Inspection runtime only: no frozen collector or model code was executed.",
  "Receipt identity agreement is NOT a fresh hash check of referenced original input payloads.",
  "Cache structural agreement is NOT a calibration, coverage, or scientific readiness finding."),
  file.path(output, "r-audit-session.txt"))
print(results, row.names = FALSE)
if (!all(results$passed)) stop("Saved-state audit has failed checks; inspect CSV evidence.")
cat("EXECUTED SUCCESSFULLY: audit-only script completed; frozen scientific execution NOT performed.\n")
