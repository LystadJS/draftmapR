#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
script <- sub("^--file=", "", commandArgs(FALSE)[grepl("^--file=", commandArgs(FALSE))][1L])
source_dir <- dirname(normalizePath(script))
output_dir <- if (length(args)) args[1L] else "calibration-validation"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
options(testthat.edition = 3)
results <- testthat::test_dir(file.path(source_dir, "tests"), reporter = "summary", stop_on_failure = FALSE)
table <- as.data.frame(results)
saveRDS(results, file.path(output_dir, "study-test-results.rds"))
table$result <- NULL
write.csv(table, file.path(output_dir, "study-test-results.csv"), row.names = FALSE)
counts <- data.frame(test_blocks = nrow(table), expectations = sum(table$nb),
  passed = sum(table$passed), failed = sum(table$failed), errors = sum(table$error),
  warnings = sum(table$warning), skipped = sum(table$skipped))
write.csv(counts, file.path(output_dir, "study-test-summary.csv"), row.names = FALSE)
print(counts)
if (any(counts[c("failed", "errors", "warnings", "skipped")] > 0)) stop("Study helper validation failed.")
