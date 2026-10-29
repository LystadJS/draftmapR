# Fresh package engineering validation, independent of frozen scientific data.
args <- commandArgs(TRUE)
stopifnot(length(args) %in% 3:4)
repo <- normalizePath(args[1], winslash = "/")
lib <- normalizePath(args[2], winslash = "/")
out <- normalizePath(args[3], winslash = "/")
.libPaths(c(lib, .libPaths()))
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
dir.create(file.path(out, "examples"), showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), file.path(out, "session-info.txt"))
package <- file.path(repo, "driftmapR")
if (length(args) == 3L || args[4] != "examples-only") {
  cat("Running the complete testthat suite\n")
  res <- testthat::test_local(package, reporter = "summary", stop_on_failure = FALSE)
  tab <- as.data.frame(res)
  tab <- tab[, !vapply(tab, is.list, logical(1)), drop = FALSE]
  write.csv(tab, file.path(out, "test-results.csv"), row.names = FALSE)
} else tab <- read.csv(file.path(out, "test-results.csv"))
totals <- colSums(tab[, c("nb", "failed", "skipped", "error", "warning", "passed")])
print(totals)
stopifnot(sum(tab$failed) == 0L, !any(tab$error), sum(tab$warning) == 0L,
          sum(tab$skipped) == 0L)
cat("Running every manual-page example\n")
library(driftmapR)
rd <- list.files(file.path(package, "man"), "\\.Rd$", full.names = TRUE)
example_rows <- lapply(rd, function(path) {
  code <- file.path(out, "examples", sub("\\.Rd$", ".R", basename(path)))
  tools::Rd2ex(path, out = code)
  if (!file.exists(code)) return(data.frame(topic = sub("\\.Rd$", "", basename(path)),
                                           status = "no example code"))
  grDevices::pdf(file.path(out, "examples", sub("\\.Rd$", ".pdf", basename(path))))
  tryCatch(sys.source(code, envir = new.env(parent = globalenv())),
           finally = grDevices::dev.off())
  data.frame(topic = sub("\\.Rd$", "", basename(path)), status = "passed")
})
write.csv(do.call(rbind, example_rows), file.path(out, "manual-examples.csv"), row.names = FALSE)
exports <- sort(getNamespaceExports("driftmapR"))
writeLines(exports, file.path(out, "exports.txt"))
writeLines(c(paste("Test blocks:", nrow(tab)), capture.output(totals),
             paste("Manual topics:", length(rd)), paste("Exports:", length(exports))),
           file.path(out, "engineering-summary.txt"))
cat("Engineering suite and all manual examples passed\n")
