# Load the immutable design and the separately frozen execution implementation.
study05_execution_load <- function(execution_dir) {
  execution_dir <- normalizePath(execution_dir)
  source(file.path(execution_dir, '../load.R'), local = .GlobalEnv)
  study05_load(file.path(execution_dir, '..'))
  for (name in c('geometry.R', 'core.R', 'accounting.R', 'covariance-analysis.R', 'analyze.R',
                 'validate.R', 'audit.R', 'runner.R')) {
    path <- file.path(execution_dir, name)
    if (file.exists(path)) source(path, local = .GlobalEnv)
  }
  invisible(execution_dir)
}
