args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
input <- read.csv(file.path(root, "qa/r1-01-member-identities.csv"), stringsAsFactors = FALSE)
state <- file.path(root, "recovered/driftmapR-S07-R1-checkpoint3915-014/pinned-workspace/study07-r1-operations/resumable-collection-state/verification-006")
identities <- new.env(hash = TRUE, parent = emptyenv())
files <- list.files(state, pattern = "\\.rds$", full.names = TRUE)
stopifnot(length(files) == 6480L)
for (path in files) {
  receipt <- readRDS(path)
  stopifnot(length(receipt$files) == length(receipt$md5))
  for (i in seq_along(receipt$files)) {
    key <- sub("^.*?/S07-R1/", "", receipt$files[[i]])
    value <- receipt$md5[[i]]
    if (exists(key, identities, inherits = FALSE)) stopifnot(identical(get(key, identities), value))
    assign(key, value, identities)
  }
}
input$receipt_path <- sub("^study07-results/S07-R1/", "", input$original_path)
input$referenced <- vapply(input$receipt_path, exists, logical(1), envir = identities, inherits = FALSE)
input$matches <- vapply(seq_len(nrow(input)), function(i) {
  input$referenced[[i]] && identical(input$md5[[i]], get(input$receipt_path[[i]], identities))
}, logical(1))
write.csv(input, file.path(root,"qa/r1-01-receipt-bindings.csv"), row.names = FALSE)
administrative <- c("draw-plans-complete.txt", "execution-identity.rds", "job-manifest.csv", "seed-plan.rds", "source-binding.rds", "source-preflight.csv")
stopifnot(setequal(input$receipt_path[!input$referenced], administrative), all(input$matches[input$referenced]))
cat("PASS:", sum(input$referenced), "recovered member MD5 identities match latest input receipts.\n")
cat("Six administrative files are not referenced by per-job receipts; their archive and Recovery009 member hashes passed separately.\n")
cat("Read-only identity binding; no scientific code executed and no scientific conclusions verified.\n")
print(sessionInfo())
