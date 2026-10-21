.libPaths(c('C:/Users/John/AppData/Local/R/win-library/4.5', .libPaths()))
x <- yaml::read_yaml('driftmapR-git/.github/workflows/R-CMD-check.yaml')
steps <- x$jobs[[1]]$steps
stopifnot(length(x$jobs[[1]]$strategy$matrix$config) == 3)
a <- Filter(function(s) !is.null(s$uses) && grepl('setup-r-dependencies|check-r-package', s$uses), steps)
stopifnot(length(a) == 2, all(vapply(a, function(s) identical(s$with[['working-directory']], 'driftmapR'), logical(1))))
cat('YAML parsed; three-platform matrix and both package paths verified\n')
