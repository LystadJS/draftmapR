#!/usr/bin/env Rscript
# Study-only runner. The original public engine is audited, never modified.
study02_capture <- function(expr) {
  warnings <- character()
  value <- tryCatch(withCallingHandlers(expr, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart('muffleWarning')
  }), error = function(e) e)
  list(ok = !inherits(value, 'error'), value = value,
       message = if (inherits(value, 'error')) conditionMessage(value) else '',
       warnings = paste(warnings, collapse = ' | '))
}

study02_one <- function(job, generated = study02_generate(job), B = 399L,
                        budgets = c(199L, 399L)) {
  started <- proc.time()[3L]
  g <- generated; model <- g$model; m <- job$m
  targets <- model$target_rows; ids <- model$target_ids
  methods <- study02_settings()$estimators
  design <- driftmapR::paired_unit_design(g$unit_map,
    assumptions = 'Independent identically distributed Gaussian measurement units paired across both periods and all entities.')
  plan <- getFromNamespace('bootstrap_draw_plan', 'driftmapR')(design, g$features, B, job$bootstrap_seed)
  weights <- do.call(rbind, lapply(plan$draws, function(d) d$feature_weights[g$features]))
  streams <- do.call(rbind, lapply(plan$draws, `[[`, 'rng_stream'))
  stopifnot(all(rowSums(weights) == m))
  C <- lapply(g$X, function(x) tcrossprod(x) / m)
  obs_points <- study02_capture(lapply(C, study02_points))
  unit_D <- study02_capture(lapply(seq_len(m), function(j)
    study02_differential(tcrossprod(g$X[[2L]][, j]) -
      tcrossprod(g$X[[1L]][, j]), model$spectrum)))
  panels <- list(); tangent_covariance <- list()
  for (anchor in names(model$anchors)) {
    anchors <- model$anchors[[anchor]]
    observed <- if (obs_points$ok) study02_capture(study02_align_points(
      obs_points$value[[1L]], obs_points$value[[2L]], model$population_points, anchors)) else obs_points
    tangent <- if (unit_D$ok) study02_capture(lapply(unit_D$value, function(D)
      study02_alignment_tangent(model$population_points, D, anchors))) else unit_D
    estimates <- setNames(rep(list(matrix(NA_real_, 3L, 2L)), 3L), methods)
    values <- setNames(lapply(methods, function(x) array(NA_real_, c(B, 3L, 2L))), methods)
    success <- setNames(lapply(methods, function(x) rep(FALSE, B)), methods)
    stages <- setNames(lapply(methods, function(x) rep('observed_fit', B)), methods)
    messages <- setNames(lapply(methods, function(x) rep(observed$message, B)), methods)
    if (observed$ok) {
      estimates$refit_plugin <- observed$value$displacement[targets, , drop = FALSE]
      estimates$refit_oracle <- estimates$refit_plugin
    }
    if (tangent$ok) {
      phi <- do.call(rbind, lapply(tangent$value, function(t) as.vector(t$full[targets, , drop = FALSE])))
      estimates$tangent_oracle <- matrix(colMeans(phi), 3L, 2L)
      weighted <- weights %*% phi / m
      values$tangent_oracle <- array(weighted, c(B, 3L, 2L))
      success$tangent_oracle[] <- TRUE
      stages$tangent_oracle[] <- 'ok'; messages$tangent_oracle[] <- ''
      emb <- do.call(rbind, lapply(tangent$value, function(t) as.vector(t$embedding[targets, , drop = FALSE])))
      ali <- do.call(rbind, lapply(tangent$value, function(t) as.vector(t$alignment[targets, , drop = FALSE])))
      for (j in seq_along(ids)) {
        cols <- c(j, j + 3L)
        pc <- sweep(phi[, cols, drop = FALSE], 2L, colMeans(phi[, cols, drop = FALSE]), '-')
        ec <- sweep(emb[, cols, drop = FALSE], 2L, colMeans(emb[, cols, drop = FALSE]), '-')
        ac <- sweep(ali[, cols, drop = FALSE], 2L, colMeans(ali[, cols, drop = FALSE]), '-')
        S <- crossprod(pc) / m^2
        tangent_covariance[[length(tangent_covariance) + 1L]] <- data.frame(m=m,
          dataset_id=job$dataset_id, anchor=anchor, entity=ids[j],
          exact_var_dx=S[1L,1L], exact_var_dy=S[2L,2L], exact_cov_dx_dy=S[1L,2L],
          embedding_trace=sum(ec^2)/m^2, alignment_trace=sum(ac^2)/m^2,
          cross_trace=2*sum(ec*ac)/m^2, total_trace=sum(diag(S)))
      }
    } else {
      stages$tangent_oracle[] <- 'tangent_fit'; messages$tangent_oracle[] <- tangent$message
    }
    panels[[anchor]] <- list(observed=if(observed$ok) observed$value else NULL,
      observed_ok=setNames(c(observed$ok,observed$ok,tangent$ok),methods),
      estimates=estimates, values=values, success=success, stages=stages, messages=messages,
      warnings=c(observed=observed$warnings,tangent=tangent$warnings))
  }
  for (b in seq_len(B)) {
    points <- study02_capture(lapply(g$X, function(x)
      study02_points(tcrossprod(sweep(x,2L,sqrt(weights[b,]),'*'))/m)))
    for (anchor in names(panels)) {
      p <- panels[[anchor]]
      if (!p$observed_ok['refit_plugin']) next
      fitted <- if(points$ok) study02_capture(study02_boot_points(points$value[[1L]],
        points$value[[2L]], p$observed, model$population_points, model$anchors[[anchor]])) else points
      for (estimator in c('refit_plugin','refit_oracle')) {
        estimator_ok <- fitted$ok && (estimator=='refit_plugin' || fitted$value$oracle_success)
        p$success[[estimator]][b] <- estimator_ok
        p$stages[[estimator]][b] <- if(estimator_ok) 'ok' else if(!points$ok) 'embedding' else if(fitted$ok) 'oracle_registration' else 'alignment'
        p$messages[[estimator]][b] <- if(fitted$ok && !estimator_ok) fitted$value$oracle_error else fitted$message
        if(estimator_ok) p$values[[estimator]][b,,] <- fitted$value[[
          if(estimator=='refit_plugin') 'plugin' else 'oracle']][targets,,drop=FALSE]
      }
      if(nzchar(fitted$warnings)) p$warnings <- c(p$warnings, setNames(fitted$warnings,paste0('draw_',b)))
      panels[[anchor]] <- p
    }
  }
  result <- list(job=job, panels=panels, weights=weights, streams=streams,
    tangent_covariance=do.call(rbind,tangent_covariance), B=B, budgets=budgets)
  tables <- study02_tables(result)
  result[names(tables)] <- tables
  result$outer <- data.frame(m=m,dataset_id=job$dataset_id,stage=job$stage,
    observed_success=all(vapply(panels,function(p)all(p$observed_ok),logical(1))),
    B=B,n_unique_weighted_refits=B,bootstrap_seed=job$bootstrap_seed,
    elapsed_seconds=unname(proc.time()[3L]-started))
  result
}

study02_tables <- function(result) {
  regions <- estimates <- failures <- list()
  job <- result$job
  ids <- study02_settings()$targets
  for(anchor in names(result$panels)) {
    p <- result$panels[[anchor]]
    for(estimator in names(p$estimates)) {
      ok <- p$success[[estimator]]
      failures[[length(failures)+1L]] <- data.frame(m=job$m,dataset_id=job$dataset_id,
        anchor=anchor,estimator=estimator,replicate_id=seq_len(result$B),attempted=p$observed_ok[[estimator]],success=ok,
        stage=p$stages[[estimator]],message=p$messages[[estimator]])
      estimates[[length(estimates)+1L]] <- data.frame(m=job$m,dataset_id=job$dataset_id,
        anchor=anchor,estimator=estimator,entity=ids,dx=p$estimates[[estimator]][,1L],
        dy=p$estimates[[estimator]][,2L],observed_success=p$observed_ok[[estimator]],
        passes_gate=sum(ok)>=20L && mean(ok)>=.95)
      for(budget in result$budgets) for(j in seq_along(ids)) {
        use <- which(ok & seq_len(result$B)<=budget)
        draws <- matrix(p$values[[estimator]][use,j,],ncol=2L)
        point <- as.numeric(p$estimates[[estimator]][j,])
        defined <- p$observed_ok[[estimator]] && all(is.finite(point))
        reg <- calibration_regions(if(defined)point else c(0,0),draws,c(0,0))
        if(!defined) {
          reg$available <- FALSE;reg$reason <- 'observed_fit_failed'
          reg$covered <- reg$rejects_zero <- NA
        }
        gate <- defined && length(use)>=20L && length(use)/budget>=.95
        reg$gate <- gate;reg$delivered <- reg$available & gate
        reg$covered[!reg$delivered] <- NA;reg$rejects_zero[!reg$delivered] <- NA
        regions[[length(regions)+1L]] <- cbind(data.frame(m=job$m,dataset_id=job$dataset_id,
          anchor=anchor,estimator=estimator,entity=ids[j],budget=budget),reg)
      }
    }
  }
  list(regions=do.call(rbind,regions), estimates=do.call(rbind,estimates),
       failures=do.call(rbind,failures))
}

study02_load <- function(source_dir) {
  source(file.path(source_dir,'..','calibration-01','model.R'),local=.GlobalEnv)
  source(file.path(source_dir,'..','calibration-01','regions.R'),local=.GlobalEnv)
  for(name in c('kernel.R','model.R','audit.R'))
    if(file.exists(file.path(source_dir,name))) source(file.path(source_dir,name),local=.GlobalEnv)
}

study02_collect <- function(paths, output_dir) {
  tables <- c('outer','regions','estimates','failures','tangent_covariance','audit')
  for(name in tables) {
    rows <- lapply(paths,function(path)readRDS(path)[[name]])
    table <- do.call(rbind,rows)
    if(!is.null(table)) write.csv(table,file.path(output_dir,paste0(name,'.csv')),row.names=FALSE)
  }
}

study02_main <- function(args=commandArgs(trailingOnly=TRUE)) {
  if(!length(args)) stop('Usage: Rscript run.R /absolute/output [workers=4]')
  script <- sub('^--file=','',commandArgs(FALSE)[grepl('^--file=',commandArgs(FALSE))][1L])
  source_dir <- dirname(normalizePath(script));study02_load(source_dir)
  output_dir <- normalizePath(args[1L],mustWork=FALSE)
  workers <- if(length(args)>1L)as.integer(args[2L]) else 4L
  settings <- study02_settings()
  stopifnot(as.character(utils::packageVersion('driftmapR'))==settings$engine_version)
  freeze <- readRDS(file.path(source_dir,'freeze.rds'))
  current <- unname(tools::md5sum(file.path(source_dir,freeze$files)))
  if(!identical(current,freeze$md5))stop('Frozen scientific source changed; do not run.')
  dir.create(file.path(output_dir,'checkpoints'),recursive=TRUE,showWarnings=FALSE)
  jobs <- study02_jobs()
  seed_path <- file.path(output_dir,'seed-plan.rds')
  if(file.exists(seed_path)&&!identical(readRDS(seed_path),jobs))stop('Existing seed plan differs.')
  saveRDS(jobs,seed_path)
  write.csv(do.call(rbind,lapply(jobs,function(j)data.frame(m=j$m,dataset_id=j$dataset_id,
    bootstrap_seed=j$bootstrap_seed,data_stream=paste(j$data_stream,collapse=';')))),
    file.path(output_dir,'seed-plan.csv'),row.names=FALSE)
  saveRDS(freeze,file.path(output_dir,'frozen-design.rds'))
  for(relative in freeze$files) {
    target <- file.path(output_dir,'source','calibration-02',relative)
    dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    if(!file.copy(file.path(source_dir,relative),target,overwrite=TRUE))stop('Could not copy frozen source')
  }
  write.csv(data.frame(file=freeze$files,md5=freeze$md5),
    file.path(output_dir,'source-hashes-before-run.csv'),row.names=FALSE)
  writeLines(capture.output(sessionInfo()),file.path(output_dir,'session-info.txt'))
  started <- Sys.time()
  work <- function(job) {
    path <- file.path(output_dir,'checkpoints',sprintf('m%04d-%03d.rds',job$m,job$dataset_id))
    if(file.exists(path)) {
      existing<-readRDS(path)
      if(!identical(existing$job,job)||!identical(existing$freeze,freeze))stop('Checkpoint mismatch: ',path)
      return(path)
    }
    g<-study02_generate(job);result<-study02_one(job,g,settings$B,settings$budgets)
    if(job$dataset_id<=3L)result$audit<-study02_public_audit(result,g,settings$B)
    result$freeze<-freeze
    saveRDS(result,paste0(path,'.tmp'),compress='gzip')
    if(!file.rename(paste0(path,'.tmp'),path))stop('Checkpoint finalization failed')
    path
  }
  paths <- parallel::mclapply(jobs,work,mc.cores=workers,mc.set.seed=FALSE,mc.preschedule=FALSE)
  if(any(vapply(paths,inherits,logical(1),'try-error')))stop('Worker failure; retain checkpoints, inspect and resume without redrawing.')
  study02_collect(paths,output_dir)
  writeLines(c(paste('start',started),paste('end',Sys.time()),paste('workers',workers),
    paste('independent_raw_panels',length(jobs))),file.path(output_dir,'execution.txt'))
}
if(sys.nframe()==0L)study02_main()
