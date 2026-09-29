# Study05 composes the frozen Study03/04 estimator. The two deliberate changes
# to the inherited parent function are diagnostic context and honest assumptions.
# No estimator arithmetic, randomization, gate, or stopping rule is replaced.
study05_assumptions <- function(case) {
  if(identical(case$contract,'dependence_stress_outside_iid_contract'))
    'Unsupported misspecification stress: ordered measurement units follow stationary AR(1) dependence; the candidate deliberately uses iid paired-unit draws and iid occurrence jackknife. Pairing across entities and periods does not preserve dependence across units.' else
    'The simulation generates iid paired measurement units across entities and periods; all columns are sampled together across time.'
}

study05_instrument_parent <- function(fun, envir, assumptions) {
  replaced_assumption<-replaced_loop<-0L
  old<-'The simulation generates iid paired measurement units across entities and periods; all columns are sampled together across time.'
  walk<-function(x) {
    if(is.character(x)&&length(x)==1L&&identical(x,old)) {
      replaced_assumption<<-replaced_assumption+1L;return(assumptions)
    }
    if(is.call(x)) {
      # Single-bracket replacement preserves literal NULL arguments in the AST.
      for(i in seq_along(x))if(i>1L)x[i]<-list(walk(x[[i]]))
      if(identical(x[[1L]],as.name('for'))&&identical(x[[2L]],as.name('b'))) {
        replaced_loop<<-replaced_loop+1L
        x[[4L]]<-as.call(c(as.name('{'),list(quote(study05_parent(b))),as.list(x[[4L]])[-1L]))
      }
    }
    x
  }
  body(fun)<-walk(body(fun))
  if(replaced_assumption!=1L||replaced_loop!=1L)
    stop('Inherited Study03 body does not match the locked instrumentation contract.')
  environment(fun)<-envir
  fun
}

study05_one <- function(job,case,generated,B=case$B,
                        keep_inner_values=identical(job$dataset_id,1L),
                        fit_fun=NULL,oracle_register=NULL,evaluation_register=NULL,
                        hooks=list()) {
  if(!is.list(hooks)||any(!vapply(hooks,is.function,logical(1L))))
    stop('hooks must be a list of engineering injection functions.')
  if(!is.null(fit_fun)&&!is.function(fit_fun))stop('fit_fun must be a function.')
  g<-generated;model<-g$model
  if(!identical(job$case_id,case$case_id)||job$m!=case$m||B!=case$B)
    stop('Job, case, and bootstrap budget must agree.')
  geometry<-study05_geometry_state(model,job$m,B,keep_inner_values)
  if(!is.null(hooks$projector))geometry$projector_fun<-hooks$projector
  scope<-new.env(parent=environment(study04_one))
  context<-function()list(parent_id=geometry$parent_id,unit_index=geometry$unit_index,
    role=c('core','reference','clean')[geometry$role])
  scope$study05_parent<-function(b){geometry$parent_id<-as.integer(b);geometry$unit_index<-0L;invisible(NULL)}
  instrumented_fit<-function(C1,C2,reference_points,anchors) {
    ep<-c(study05_geometry_row(geometry,'embedding',1L,1L),
          study05_geometry_row(geometry,'embedding',2L,2L))
    rp<-c(study05_geometry_row(geometry,'registration',1L),
          study05_geometry_row(geometry,'registration',2L))
    if(geometry$role!=3L)geometry$oracle_row<-study05_geometry_row(geometry,'registration',3L)
    if(!is.null(hooks$fit))hooks$fit(context())
    points1<-study03_stage(study05_geometry_points(C1,geometry,ep[1L]),'embedding_period1')
    points2<-study03_stage(study05_geometry_points(C2,geometry,ep[2L]),'embedding_period2')
    baseline<-study03_stage(study05_geometry_register(points1,reference_points,anchors,geometry,rp[1L]),'registration_baseline')
    temporal<-study03_stage(study05_geometry_register(points2,baseline$points,anchors,geometry,rp[2L]),'alignment_temporal')
    answer<-list(raw=list(points1,points2),aligned1=baseline$points,
      aligned2=temporal$points,displacement=temporal$points-baseline$points,
      baseline=baseline,temporal=temporal)
    if(!is.null(fit_fun))answer<-fit_fun(C1,C2,reference_points,anchors)
    answer
  }
  # The observed reference embedding is an additional frozen-kernel operation.
  scope$study02_points<-function(C) {
    oldrole<-geometry$role;geometry$role<-2L
    on.exit({geometry$role<-oldrole},add=TRUE)
    row<-study05_geometry_row(geometry,'embedding',3L,1L)
    study05_geometry_points(C,geometry,row)
  }
  scope$study02_register<-function(source,target,anchors,tol=1e-10) {
    row<-study05_geometry_row(geometry,'registration',4L)
    study05_geometry_register(source,target,anchors,geometry,row,tol,
      register_override=evaluation_register)
  }
  oracle<-function(source,target,anchors) {
    study05_geometry_register(source,target,anchors,geometry,geometry$oracle_row,
      register_override=oracle_register)
  }
  if(!is.null(hooks$quadratic))scope$study03_quadratic<-hooks$quadratic
  jk_scope<-new.env(parent=scope)
  if(!is.null(hooks$covariance))jk_scope$study03_jackknife_covariance<-hooks$covariance
  inherited_jk<-study03_jackknife;environment(inherited_jk)<-jk_scope
  scope$study03_jackknife<-function(X,counts,reference_points,anchors,target_rows,
                                  grams=NULL,fit_fun=study03_fit) {
    positive<-which(counts>0L);index<-0L;oldunit<-geometry$unit_index
    on.exit({geometry$unit_index<-oldunit},add=TRUE)
    # Wrap the complete deletion fit+oracle callback so oracle geometry inherits
    # the correct original-unit index. One failure never stops later deletions.
    deletion<-function(C1,C2,reference_points,anchors) {
      index<<-index+1L;geometry$unit_index<-positive[index]
      fit_fun(C1,C2,reference_points,anchors)
    }
    inherited_jk(X,counts,reference_points,anchors,target_rows,grams=grams,fit_fun=deletion)
  }
  scope$study03_one<-study05_instrument_parent(study03_one,scope,study05_assumptions(case))
  inherited_frame<-study04_one;environment(inherited_frame)<-scope
  result<-inherited_frame(job,case,generated=g,B=B,keep_inner_values=keep_inner_values,
    fit_fun=instrumented_fit,oracle_register=oracle)
  result$design_metadata<-driftmapR::paired_unit_design(g$unit_map,
    assumptions=study05_assumptions(case))
  result$model_metadata$contract<-case$contract
  result$model_metadata$clean_anchors<-model$clean_anchor_ids
  result$model_metadata$population_target_identified<-model$population_target_identified
  result$truth_clean<-model$truth_clean
  result$truth_declared_minus_clean<-model$truth_declared_minus_clean
  result$frame$truth_clean<-model$truth_clean
  result$frame$truth_declared_minus_clean<-model$truth_declared_minus_clean
  result$frame$model_metadata<-result$model_metadata
  result$frame$design_metadata<-result$design_metadata
  # A clean-anchor point is separately attempted even if the inherited core or
  # evaluation failed. It uses A directly and has no bootstrap/JK budget.
  geometry$parent_id<--1L;geometry$unit_index<-0L;geometry$role<-3L
  grams<-lapply(g$X,function(x)tcrossprod(x)/job$m)
  clean<-study03_capture(instrumented_fit(grams[[1L]],grams[[2L]],
    model$population_points[[1L]],model$clean_anchors))
  result$clean<-list(attempted=TRUE,success=clean$ok,stage=clean$stage,
    message=clean$message,warnings=clean$warnings,
    estimate=if(clean$ok)clean$value$displacement[model$target_rows,,drop=FALSE] else
      matrix(NA_real_,length(model$target_rows),2L),truth=model$truth_clean,
    frame='population_A',target='theta_C',interval_computed=FALSE)
  result$geometry<-study05_geometry_finish(geometry)
  for(kind in c('embedding','registration')) {
    result$geometry[[kind]]$case_id<-case$case_id
    result$geometry[[kind]]$dataset_id<-job$dataset_id
  }
  core_available<-isTRUE(result$full_observed_success)
  evaluation_available<-core_available&&isTRUE(result$evaluation_success)
  evaluation_only<-core_available&&!evaluation_available
  result$candidate_point_R0<-if(core_available)
    result$observed$fit$displacement[model$target_rows,,drop=FALSE] else
      matrix(NA_real_,length(model$target_rows),2L)
  decorate<-function(frame) {
    frame$observed_core_fit_available<-core_available
    frame$evaluation_registration_available<-evaluation_available
    frame$evaluation_only_block<-evaluation_only
    frame$outer$observed_core_fit_available<-core_available
    frame$outer$evaluation_registration_available<-evaluation_available
    frame$outer$evaluation_only_block<-evaluation_only
    frame$outer$contract<-case$contract
    frame$attempts$max_multiplicity<-apply(result$weights,1L,max)
    frame$studentization$max_multiplicity<-rep(frame$attempts$max_multiplicity,
      each=length(model$target_ids))
    rows<-frame$regions
    rows$observed_core_fit_available<-core_available
    rows$evaluation_registration_available<-evaluation_available
    rows$evaluation_only_block<-evaluation_only
    rows$candidate_region_delivered<-if(evaluation_only)rep(NA,nrow(rows)) else rows$delivered
    rows$study_evaluable_region_delivered<-rows$delivered
    rows$studentized_nondelivery_reason<-NA_character_
    for(j in seq_along(model$target_ids)) {
      at<-which(rows$entity==model$target_ids[j]&rows$method=='jackknife_studentized')
      rows$studentized_nondelivery_reason[at]<-study05_nondelivery(
        frame$observed_success,frame$observed_jackknife$all_required_success,
        frame$observed_jackknife$covariance_ok[j],sum(is.finite(frame$pivots[,j])),
        B=B,geometry_ok=isTRUE(rows$available[at]))
    }
    frame$regions<-rows
    frame
  }
  result$frame<-decorate(result$frame)
  result<-decorate(result)
  result$execution_metadata<-list(instrumentation='study05-execution-v1',
    engineering_hooks=length(hooks)>0L||!is.null(fit_fun)||!is.null(oracle_register)||!is.null(evaluation_register),
    keep_inner_values=isTRUE(keep_inner_values),scientific_kernel='unchanged Study03/04',
    geometry_changes_gates=FALSE)
  result
}
