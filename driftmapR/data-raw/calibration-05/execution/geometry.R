# Instrumentation of the frozen numerical kernel. Diagnostics never set gates.
# Hashed row buffers avoid copying a growing matrix at every diagnostic stage.
study05_geometry_state <- function(model, m, B, keep_matrices = FALSE) {
  e <- new.env(parent = emptyenv())
  e$parent_id <- 0L; e$unit_index <- 0L; e$role <- 1L
  e$keep_matrices <- isTRUE(keep_matrices); e$model <- model
  e$population_basis <- lapply(model$population_grams, function(C)
    eigen(C, symmetric = TRUE)$vectors[, 1:2, drop = FALSE])
  e$embedding_names <- c('parent_id','unit_index','period','role_code','stage_code',
    'attempted','success','lambda1','lambda2','lambda3','gap_absolute',
    'gap_relative1','gap_relative2','projector_distance','angle_min','angle_max',
    'rank_ok','boundary_ok','negative_ok','diagnostic_success')
  e$registration_names <- c('parent_id','unit_index','role_code','stage_code',
    'attempted','success','source_s1','source_s2','source_ratio','target_s1',
    'target_s2','target_ratio','cross_s1','cross_s2','cross_ratio','rss',
    'n_matched','reflection','rotation_angle','rotation_determinant')
  e$embedding <- new.env(hash=TRUE,parent=emptyenv())
  e$registration <- new.env(hash=TRUE,parent=emptyenv())
  e$ne <- 0L; e$nr <- 0L
  e$embedding_messages <- e$registration_messages <- list()
  e$embedding_warnings <- e$registration_warnings <- list()
  e$diagnostic_messages <- list()
  e$projector_fun <- function(U,V) {
    cosines<-pmin(1,pmax(0,svd(crossprod(U,V),nu=0L,nv=0L)$d))
    angles<-acos(cosines)
    c(sqrt(max(0,4-2*sum(cosines^2))),min(angles),max(angles))
  }
  e$embedding_full <- new.env(hash=TRUE,parent=emptyenv())
  e$registration_full <- new.env(hash=TRUE,parent=emptyenv())
  e$oracle_row <- NULL
  e
}

study05_geometry_row <- function(e, kind, stage, period = NA_integer_) {
  if (kind == 'embedding') {
    e$ne <- e$ne + 1L; i <- e$ne
    record<-stats::setNames(rep(NA_real_,length(e$embedding_names)),e$embedding_names)
    record[1:7]<-c(e$parent_id,e$unit_index,period,e$role,stage,0,0)
    e$embedding[[as.character(i)]]<-record
  } else {
    e$nr <- e$nr + 1L; i <- e$nr
    record<-stats::setNames(rep(NA_real_,length(e$registration_names)),e$registration_names)
    record[1:6]<-c(e$parent_id,e$unit_index,e$role,stage,0,0)
    e$registration[[as.character(i)]]<-record
  }
  i
}

# Same checks and arithmetic as study02_spectrum, with spectrum retention before
# rejection. A numerical eigenspace at a sample tie is diagnostic, not identified.
study05_geometry_points <- function(C, e, row, tol = 1e-10) {
  record<-e$embedding[[as.character(row)]]
  on.exit({e$embedding[[as.character(row)]]<-record},add=TRUE)
  record['attempted']<-1
  tryCatch(withCallingHandlers({
    study02_matrix(C, label = 'Gram matrix')
    if (nrow(C) != ncol(C) || !is.numeric(tol) || length(tol) != 1L ||
        !is.finite(tol) || tol <= 0 || tol >= 1)
      stop('A square Gram matrix and tolerance in (0,1) are required.',call.=FALSE)
    magnitude <- max(abs(C))
    if (magnitude == 0) stop('Gram matrix has zero rank.',call.=FALSE)
    if (max(abs(C-t(C))) > 1e-12*magnitude) stop('Gram matrix must be symmetric.',call.=FALSE)
    if (max(abs(rowSums(C))) > 1e-9*nrow(C)*magnitude)
      stop('Gram matrix must be centered across entities.',call.=FALSE)
    spectrum <- eigen((C+t(C))/2,symmetric=TRUE); values <- spectrum$values
    U <- spectrum$vectors[,1:2,drop=FALSE]
    V <- e$population_basis[[as.integer(record['period'])]]
    # Diagnostic failure cannot become an additional numerical success gate.
    diagnostic<-tryCatch(e$projector_fun(U,V),error=function(err)err)
    diagnostic_ok<-!inherits(diagnostic,'error')&&is.numeric(diagnostic)&&
      length(diagnostic)==3L&&all(is.finite(diagnostic))
    if(!diagnostic_ok) {
      e$diagnostic_messages[[as.character(row)]]<-if(inherits(diagnostic,'error'))
        conditionMessage(diagnostic) else 'Projector diagnostic is nonfinite or malformed.'
      diagnostic<-rep(NA_real_,3L)
    }
    rank_ok <- values[1L] > 0 && values[2L] > tol*values[1L]
    negative_ok <- min(values) >= -tol*values[1L]
    boundary_ok <- values[2L]-values[3L] > tol*values[1L]
    record[8:19] <- c(values[1:3],values[2L]-values[3L],
      (values[2L]-values[3L])/values[1L],(values[2L]-values[3L])/values[2L],
      diagnostic,rank_ok,boundary_ok,negative_ok)
    record['diagnostic_success']<-diagnostic_ok
    if(e$keep_matrices) {
      spectrum$projector <- tcrossprod(U)
      e$embedding_full[[as.character(row)]] <- spectrum
    }
    if(!rank_ok) stop('Gram matrix must identify two positive coordinate dimensions.',call.=FALSE)
    if(!negative_ok) stop('Gram matrix has a materially negative eigenvalue.',call.=FALSE)
    if(!boundary_ok) stop('Second/third eigenvalue boundary tie makes the plane unidentified.',call.=FALSE)
    points <- sweep(U,2L,sqrt(values[1:2]),'*')
    rownames(points) <- rownames(C); colnames(points) <- c('x','y')
    record['success'] <- 1
    points
  },warning=function(w) {
    key<-as.character(row)
    e$embedding_warnings[[key]]<-c(e$embedding_warnings[[key]],conditionMessage(w))
  }), error=function(err) {
    e$embedding_messages[[as.character(row)]] <- conditionMessage(err)
    stop(err)
  })
}

# Same normalized SVD algorithm and rank thresholds as study02_register.
# Scalar singular values are saved in ORIGINAL coordinate units, while returned
# singular_values retain the frozen kernel's normalized cross-product convention.
study05_geometry_register <- function(source,target,anchors,e,row,tol=1e-10,
                                      register_override=NULL) {
  record<-e$registration[[as.character(row)]]
  on.exit({e$registration[[as.character(row)]]<-record},add=TRUE)
  record['attempted']<-1
  tryCatch(withCallingHandlers({
    study02_matrix(source,2L,'Source coordinates');study02_matrix(target,2L,'Target coordinates')
    if(!identical(dim(source),dim(target)))
      stop('Source and target must have identical dimensions and entity order.',call.=FALSE)
    if(!is.numeric(tol)||length(tol)!=1L||!is.finite(tol)||tol<=0||tol>=1)
      stop('Tolerance must be in (0,1).',call.=FALSE)
    anchors <- study02_anchors(anchors,nrow(source))
    record['n_matched'] <- length(anchors)
    source_center<-colMeans(source[anchors,,drop=FALSE])
    target_center<-colMeans(target[anchors,,drop=FALSE])
    a<-sweep(source[anchors,,drop=FALSE],2L,source_center,'-')
    b<-sweep(target[anchors,,drop=FALSE],2L,target_center,'-')
    aa<-max(abs(a));bb<-max(abs(b))
    if(!is.finite(aa)||!is.finite(bb)||aa==0||bb==0)
      stop('Anchor coordinates have zero or nonfinite spread.',call.=FALSE)
    a<-a/aa;b<-b/bb
    sa<-svd(a,nu=0L,nv=0L)$d;sb<-svd(b,nu=0L,nv=0L)$d
    record[7:12]<-c(sa*aa,sa[2L]/sa[1L],sb*bb,sb[2L]/sb[1L])
    if(e$keep_matrices)e$registration_full[[as.character(row)]]<-list(
      source_center=source_center,target_center=target_center,
      source_singular_values=sa*aa,target_singular_values=sb*bb,
      normalized_source_anchors=a,normalized_target_anchors=b)
    if(sa[2L]<=tol*sa[1L]||sb[2L]<=tol*sb[1L])
      stop('Rank-deficient anchor geometry.',call.=FALSE)
    decomposition<-svd(crossprod(a,b))
    record[13:15]<-c(decomposition$d*aa*bb,decomposition$d[2L]/decomposition$d[1L])
    if(e$keep_matrices)e$registration_full[[as.character(row)]]$cross_decomposition<-decomposition
    if(decomposition$d[1L]<=0||decomposition$d[2L]<=tol*decomposition$d[1L])
      stop('Rank-deficient anchor cross-covariance.',call.=FALSE)
    rotation<-decomposition$u%*%t(decomposition$v)
    points<-sweep(sweep(source,2L,source_center,'-')%*%rotation,2L,target_center,'+')
    if(any(!is.finite(points)))stop('Registered coordinates are nonfinite.',call.=FALSE)
    colnames(points)<-c('x','y')
    answer<-list(points=points,rotation=unname(rotation),source_center=source_center,
      target_center=target_center,translation=as.numeric(target_center-source_center%*%rotation),
      determinant=det(rotation),singular_values=decomposition$d)
    if(!is.null(register_override)) answer<-register_override(source,target,anchors)
    record[c('rss','reflection','rotation_angle','rotation_determinant')]<-
      c(sum((answer$points[anchors,,drop=FALSE]-target[anchors,,drop=FALSE])^2),
        det(answer$rotation)<0,atan2(answer$rotation[2L,1L],answer$rotation[1L,1L]),det(answer$rotation))
    if(e$keep_matrices)e$registration_full[[as.character(row)]]<-
      utils::modifyList(e$registration_full[[as.character(row)]],answer)
    record['success']<-1
    answer
  },warning=function(w) {
    key<-as.character(row)
    e$registration_warnings[[key]]<-c(e$registration_warnings[[key]],conditionMessage(w))
  }),error=function(err){
    e$registration_messages[[as.character(row)]]<-conditionMessage(err)
    stop(err)
  })
}

study05_geometry_finish <- function(e) {
  table<-function(rows,n,columns) {
    if(n==0L)return(as.data.frame(matrix(numeric(),0L,length(columns),dimnames=list(NULL,columns))))
    as.data.frame(do.call(rbind,mget(as.character(seq_len(n)),envir=rows,inherits=FALSE)))
  }
  embedding<-table(e$embedding,e$ne,e$embedding_names)
  registration<-table(e$registration,e$nr,e$registration_names)
  for(kind in c('embedding','registration')) {
    tab<-get(kind);tab$diagnostic_id<-seq_len(nrow(tab))
    tab$role<-c('core','reference','clean')[as.integer(tab$role_code)]
    tab$stage<-if(kind=='embedding')c('embedding_period1','embedding_period2','observed_reference')[as.integer(tab$stage_code)] else
      c('registration_baseline','alignment_temporal','oracle_registration','evaluation_registration')[as.integer(tab$stage_code)]
    tab$attempted<-as.logical(tab$attempted);tab$success<-as.logical(tab$success)
    tab$message<-ifelse(tab$attempted,'','Blocked by an unavailable preceding stage.')
    messages<-e[[paste0(kind,'_messages')]]
    if(length(messages))tab$message[as.integer(names(messages))]<-unlist(messages,use.names=FALSE)
    tab$warnings<-rep('',nrow(tab));warnings<-e[[paste0(kind,'_warnings')]]
    if(length(warnings))tab$warnings[as.integer(names(warnings))]<-
      vapply(warnings,paste,character(1L),collapse=' | ')
    tab$parent_id<-as.integer(tab$parent_id);tab$unit_index<-as.integer(tab$unit_index)
    tab$role_code<-tab$stage_code<-NULL
    if(kind=='registration')tab$reference<-ifelse(tab$stage=='alignment_temporal',
      'aligned_period1',ifelse(tab$stage %in% c('oracle_registration','evaluation_registration')|
        tab$role=='clean','population_A','observed_R0'))
    if(kind=='embedding') {
      tab$diagnostic_success<-as.logical(tab$diagnostic_success)
      tab$diagnostic_message<-rep('',nrow(tab))
      if(length(e$diagnostic_messages))tab$diagnostic_message[as.integer(names(e$diagnostic_messages))]<-
        unlist(e$diagnostic_messages,use.names=FALSE)
    }
    assign(kind,tab)
  }
  list(embedding=embedding,registration=registration,
       matrices=list(embedding=as.list(e$embedding_full,all.names=TRUE),
         registration=as.list(e$registration_full,all.names=TRUE)))
}
