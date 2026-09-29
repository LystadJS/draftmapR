# Load research dependencies without executing any calibration runner.
study05_load <- function(source_dir) {
  source_dir <- normalizePath(source_dir)
  source(file.path(source_dir, '../calibration-04/run.R'), local = .GlobalEnv)
  study04_load(file.path(source_dir, '../calibration-04'))
  for (name in c('model.R', 'contract.R')) {
    source(file.path(source_dir, name), local = .GlobalEnv)
  }
  invisible(source_dir)
}

# Every R source used by the design or inherited numerical implementation.
study05_r_files <- function(source_dir) {
  local <- list.files(source_dir, pattern = '\\.[Rr]$', recursive = TRUE)
  inherited <- unlist(lapply(sprintf('../calibration-%02d', 1:4), function(p)
    file.path(p, list.files(file.path(source_dir, p), pattern = '\\.[Rr]$', recursive = TRUE))))
  public <- file.path('../../R', list.files(file.path(source_dir, '../../R'), pattern = '\\.[Rr]$'))
  sort(unique(c(local, inherited, public)))
}
