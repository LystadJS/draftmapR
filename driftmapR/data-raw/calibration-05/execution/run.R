#!/usr/bin/env Rscript
script <- sub('^--file=', '', commandArgs(FALSE)[grepl('^--file=', commandArgs(FALSE))][1L])
execution_dir <- dirname(normalizePath(script))
source(file.path(execution_dir, 'load.R')); study05_execution_load(execution_dir)
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) || length(args) > 2L) stop('Usage: Rscript run.R OUTPUT_DIRECTORY [workers=8]')
study05_main(execution_dir, args[1L], if (length(args) == 2L) as.integer(args[2L]) else 8L)
