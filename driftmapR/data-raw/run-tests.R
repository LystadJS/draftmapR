#!/usr/bin/env Rscript
# Run from the parent of the source tree:
# Rscript driftmapR/data-raw/run-tests.R driftmapR validation-output
args <- commandArgs(trailingOnly = TRUE)
package_dir <- if (length(args) >= 1L) args[[1L]] else "."
output_dir <- if (length(args) >= 2L) args[[2L]] else "validation-output"
if (!file.exists(file.path(package_dir, "DESCRIPTION"))) {
  stop("The package directory must contain DESCRIPTION.", call. = FALSE)
}
if (!requireNamespace("testthat", quietly = TRUE)) {
  stop("Install testthat before running validation.", call. = FALSE)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(output_dir)) stop("Could not create validation output directory.")
results <- testthat::test_local(package_dir, reporter = "summary", stop_on_failure = FALSE)
table <- as.data.frame(results)
saveRDS(results, file.path(output_dir, "test-results.rds"))
table$result <- NULL
write.csv(table, file.path(output_dir, "test-results.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
counts <- data.frame(test_blocks = nrow(table), expectations = sum(table$nb),
                     passed = sum(table$passed), failed = sum(table$failed),
                     errors = sum(table$error), warnings = sum(table$warning),
                     skipped = sum(table$skipped))
write.csv(counts, file.path(output_dir, "test-summary.csv"), row.names = FALSE)
print(counts)
if (any(counts[c("failed", "errors", "warnings", "skipped")] > 0)) {
  stop("Validation has unresolved failures, errors, warnings, or skipped tests.", call. = FALSE)
}
