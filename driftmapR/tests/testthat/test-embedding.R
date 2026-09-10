# Independent adapter oracles use stats::prcomp(), pairwise distances, and
# explicit feature transformations. Eigenvectors may differ by signs/rotation,
# so geometric comparisons use distance matrices rather than chosen axes.
embedding_fixture <- function() {
  first <- data.frame(
    entity = LETTERS[1:8], time = 1,
    a = c(-2, 0, 2, -1, 1, 3, -3, 0.5),
    b = c(-1, 2, 0, 3, -2, 2, 1, -0.5),
    c = c(2, -1, 0.5, 2, 1, -2, 0, 3),
    d = c(1, 0, 2, -2, 0.5, 1, 3, -1),
    cluster = rep(c("one", "two"), each = 4)
  )
  second <- first
  second$time <- 2
  second$a <- 2 * first$a + 3
  second$b <- first$b / 2 - 2
  second$c <- first$c + c(0, 0, 0, 0, 0, 1, 0, -0.5)
  second$d <- first$d * 1.5
  rbind(first, second)
}

embedding_points <- function(object, index) {
  as.matrix(object$coordinates[object$coordinates$period_index == index,
                               c("x", "y"), drop = FALSE])
}

embedding_distances <- function(x) unname(as.matrix(stats::dist(x)))

embedding_warnings <- function(code) {
  messages <- character()
  value <- withCallingHandlers(code, warning = function(w) {
    messages <<- c(messages, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(value = value, messages = messages)
}

test_that("PCA adapters reproduce base R geometry and retain an auditable fit", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  object <- embed_snapshots(d, features = features)
  expect_s3_class(object, "driftmap")
  expect_identical(object$original_data, d)
  expect_null(object$aligned)
  expect_null(object$transformations)
  expect_null(object$bootstrap)
  expect_identical(object$embedding_metadata$method, "pca")
  expect_identical(object$embedding_metadata$input_type, "features")
  expect_identical(object$embedding_metadata$dimensions, 2L)
  expect_identical(object$embedding_metadata$feature_names, features)
  expect_equal(as.numeric(object$embedding_metadata$feature_weights), rep(1, 4))
  expect_identical(object$coordinates$cluster, d$cluster)
  expect_false(any(features %in% names(object$coordinates)))
  for (j in 1:2) {
    x <- as.matrix(d[d$time == j, features])
    oracle <- stats::prcomp(x, center = TRUE, scale. = FALSE, rank. = 2)
    expect_equal(embedding_distances(embedding_points(object, j)),
                 embedding_distances(oracle$x), tolerance = 1e-10)
    expect_equal(colMeans(embedding_points(object, j)), c(x = 0, y = 0),
                 tolerance = 1e-10)
    fit <- object$embedding_metadata$fits[[j]]
    expect_s3_class(fit$model, "prcomp")
    expect_equal(unname(fit$eigenvalues), (nrow(x) - 1) * oracle$sdev^2,
                 tolerance = 1e-10)
  }
})

test_that("PCA and Euclidean classical MDS retain the same two-dimensional geometry", {
  d <- embedding_fixture()
  pca <- embed_snapshots(d, features = c("a", "b", "c", "d"), method = "pca")
  cmds <- embed_snapshots(d, features = c("a", "b", "c", "d"), method = "cmds")
  for (j in 1:2) {
    expect_equal(embedding_distances(embedding_points(pca, j)),
                 embedding_distances(embedding_points(cmds, j)), tolerance = 1e-9)
    expect_equal(head(unname(cmds$embedding_metadata$fits[[j]]$eigenvalues), 4),
                 unname(pca$embedding_metadata$fits[[j]]$eigenvalues),
                 tolerance = 1e-9)
  }
  expect_equal(cmds$diagnostics$embedding$n_negative, c(0L, 0L))
})

test_that("stored PCA preprocessing and loadings reconstruct scores from original data", {
  d <- embedding_fixture()
  object <- embed_snapshots(d, c("a", "b", "c", "d"),
                             standardize = "first",
                             feature_weights = c(a = 2, b = 0.25, c = 0, d = 3))
  metadata <- object$embedding_metadata
  for (j in 1:2) {
    raw <- as.matrix(object$original_data[object$original_data$time == j,
                                           metadata$feature_names, drop = FALSE])
    centered <- sweep(raw, 2, metadata$preprocessing$centers[[j]], "-")
    standardized <- sweep(centered, 2, metadata$preprocessing$scales[[j]], "/")
    weighted <- sweep(standardized, 2, sqrt(metadata$feature_weights), "*")
    reconstructed <- weighted %*% metadata$fits[[j]]$model$rotation
    expect_equal(unname(reconstructed), unname(embedding_points(object, j)),
                   tolerance = 1e-10)
  }
})

test_that("standardization policies use the documented sample SD reference", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  for (policy in c("none", "first", "pooled", "period")) {
    object <- embed_snapshots(d, features = features, standardize = policy)
    expect_identical(object$embedding_metadata$preprocessing$standardize, policy)
    for (j in 1:2) {
      x <- as.matrix(d[d$time == j, features])
      reference <- switch(policy, first = d[d$time == 1, features],
                          pooled = d[features], period = d[d$time == j, features])
      denominator <- if (policy == "none") rep(1, length(features)) else
        vapply(reference, stats::sd, numeric(1))
      oracle <- stats::prcomp(sweep(x, 2, denominator, "/"), rank. = 2)
      expect_equal(embedding_distances(embedding_points(object, j)),
                   embedding_distances(oracle$x), tolerance = 1e-10)
      expect_equal(unname(object$embedding_metadata$preprocessing$centers[[j]]),
                   unname(colMeans(x)), tolerance = 1e-12)
      expect_equal(unname(object$embedding_metadata$preprocessing$scales[[j]]),
                   unname(denominator), tolerance = 1e-12)
    }
  }
})

test_that("integer feature weights reproduce literal feature duplication", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  weights <- c(2, 0, 3, 1)
  for (method in c("pca", "cmds")) {
    object <- embed_snapshots(d, features, method = method, feature_weights = weights)
    named <- embed_snapshots(d, features, method = method,
                             feature_weights = c(d = 1, b = 0, a = 2, c = 3))
    expect_equal(object$coordinates, named$coordinates, tolerance = 1e-12)
    for (j in 1:2) {
      x <- as.matrix(d[d$time == j, features])
      expanded <- x[, rep(seq_along(weights), weights), drop = FALSE]
      oracle <- stats::prcomp(expanded, rank. = 2)
      expect_equal(embedding_distances(embedding_points(object, j)),
                   embedding_distances(oracle$x), tolerance = 1e-9)
    }
  }
})

test_that("weights preserve absolute geometry instead of being normalized", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  for (method in c("pca", "cmds")) {
    ordinary <- embed_snapshots(d, features, method = method)
    weighted <- embed_snapshots(d, features, method = method,
                                feature_weights = rep(4, 4))
    expect_equal(embedding_distances(embedding_points(weighted, 1)),
                 2 * embedding_distances(embedding_points(ordinary, 1)),
                 tolerance = 1e-9)
  }
})

test_that("centering and global orthogonal changes do not create drift", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(0.61),
                               translation = c(19, -3))
  d <- fixture$data
  names(d)[names(d) == "x"] <- "a"
  names(d)[names(d) == "y"] <- "b"
  for (method in c("pca", "cmds")) {
    object <- align_snapshots(embed_snapshots(d, c("a", "b"), method = method))
    expect_equal(measure_drift(object)$distance, rep(0, 8), tolerance = 1e-9)
  }
})

test_that("rank-two true movement survives full embedding and anchor alignment", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(-0.8),
                               translation = c(-5, 7),
                               movement = data.frame(entity = "H", dx = 1.4, dy = -0.8))
  d <- fixture$data
  names(d)[names(d) == "x"] <- "a"
  names(d)[names(d) == "y"] <- "b"
  for (method in c("pca", "cmds")) {
    result <- measure_drift(align_snapshots(
      embed_snapshots(d, c("a", "b"), method = method), anchors = LETTERS[1:7]))
    expect_equal(result$distance[result$entity != "H"], rep(0, 7), tolerance = 1e-9)
    expect_equal(result$distance[result$entity == "H"], sqrt(1.4^2 + 0.8^2),
                 tolerance = 1e-9)
  }
})

test_that("changing entity availability does not create or impute rows", {
  d <- embedding_fixture()
  d <- d[!(d$entity == "A" & d$time == 2), ]
  d$entity[d$entity == "H" & d$time == 2] <- "NEW"
  object <- embed_snapshots(d, c("a", "b", "c", "d"))
  expect_equal(nrow(object$coordinates), nrow(d))
  expect_setequal(object$coordinates$entity[object$coordinates$time == 2],
                   c(LETTERS[2:7], "NEW"))
  expect_equal(object$diagnostics$embedding$n_entities, c(8L, 7L))
  expect_setequal(measure_drift(align_snapshots(object))$entity, LETTERS[2:7])
})

test_that("row order cannot detach scores or supplied cluster metadata from entities", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  permuted <- d[c(16, 2, 7, 10, 4, 14, 12, 1, 6, 9, 8, 3, 13, 15, 5, 11), ]
  for (method in c("pca", "cmds")) {
    ordinary <- embed_snapshots(d, features, method = method)
    reordered <- embed_snapshots(permuted, features, method = method)
    expect_equal(reordered$coordinates, ordinary$coordinates, tolerance = 1e-12)
    matched <- match_clusters(align_snapshots(reordered))
    expect_equal(matched$diagnostics$cluster_matching$assignments$n_overlap, c(4L, 4L))
    expect_equal(matched$embedding_metadata, reordered$embedding_metadata)
  }
})

test_that("Date and explicit character schedules survive the adapter", {
  d <- embedding_fixture()
  d$time <- as.Date("2024-01-01") + d$time - 1
  object <- embed_snapshots(d, c("a", "b"))
  expect_s3_class(object$coordinates$time, "Date")
  expect_s3_class(object$diagnostics$embedding$time, "Date")
  expect_identical(object$settings$periods, sort(unique(d$time)))
  d$time <- ifelse(d$time == min(d$time), "late", "early")
  object <- embed_snapshots(d, c("a", "b"), periods = c("late", "early"))
  expect_identical(object$settings$periods, c("late", "early"))
  expect_error(embed_snapshots(d, c("a", "b")))
})

test_that("feature columns called x and y are accepted as original measurements", {
  d <- embedding_fixture()
  names(d)[names(d) %in% c("a", "b")] <- c("x", "y")
  object <- embed_snapshots(d, c("x", "y"))
  expect_identical(object$original_data, d)
  expect_equal(ncol(embedding_points(object, 1)), 2L)
  expect_identical(object$coordinates$cluster, d$cluster)
})

test_that("labeled distances reproduce the feature-input classical MDS fit", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  distances <- lapply(1:2, function(j) {
    x <- as.matrix(d[d$time == j, features])
    rownames(x) <- d$entity[d$time == j]
    stats::dist(x)
  })
  from_features <- embed_snapshots(d, features, method = "cmds")
  from_distances <- embed_snapshots(distances, method = "cmds", periods = 1:2)
  expect_identical(from_distances$original_data, distances)
  expect_identical(from_distances$embedding_metadata$input_type, "distances")
  expect_true(all(is.na(from_distances$diagnostics$embedding$n_features)))
  for (j in 1:2) {
    expect_equal(embedding_distances(embedding_points(from_features, j)),
                   embedding_distances(embedding_points(from_distances, j)),
                   tolerance = 1e-9)
  }
  named <- stats::setNames(lapply(distances, as.matrix), c("baseline", "followup"))
  from_named <- embed_snapshots(named, method = "cmds")
  expect_identical(from_named$settings$periods, c("baseline", "followup"))
  expect_equal(embedding_distances(embedding_points(from_named, 1)),
                 embedding_distances(embedding_points(from_distances, 1)), tolerance = 1e-9)
})

test_that("distance-list identity and schedule errors are rejected", {
  x <- as.matrix(embedding_fixture()[1:8, c("a", "b", "c", "d")])
  rownames(x) <- LETTERS[1:8]
  dm <- as.matrix(stats::dist(x))
  expect_error(embed_snapshots(list(dm, dm), method = "cmds"))
  expect_error(embed_snapshots(list(dm, dm), method = "cmds", periods = 1:3))
  expect_error(embed_snapshots(list(dm, dm), method = "pca", periods = 1:2))
  expect_error(embed_snapshots(list(dm, dm), method = "cmds", periods = 1:2,
                                features = c("a", "b")))
  expect_error(embed_snapshots(list(dm, dm), method = "cmds", periods = 1:2,
                                feature_weights = c(1, 1)))
  expect_error(embed_snapshots(list(dm, dm), method = "cmds", periods = 1:2,
                                standardize = "first"))
  nameless <- unname(dm)
  expect_error(embed_snapshots(list(dm, nameless), method = "cmds", periods = 1:2))
  bad <- dm
  rownames(bad)[2] <- rownames(bad)[1]
  expect_error(embed_snapshots(list(dm, bad), method = "cmds", periods = 1:2))
  bad <- dm
  colnames(bad) <- rev(colnames(bad))
  expect_error(embed_snapshots(list(dm, bad), method = "cmds", periods = 1:2))
})

test_that("malformed packed dist objects cannot silently recycle dissimilarities", {
  short <- structure(1, class = "dist", Size = 4L, Labels = letters[1:4])
  expect_error(embed_snapshots(list(short, short), method = "cmds", periods = 1:2))
  points <- matrix(c(-2, -1, 0, 2, 2, 0, -1, 3), ncol = 2, byrow = TRUE,
                     dimnames = list(letters[1:4], NULL))
  valid_shape <- stats::dist(points)
  for (size in list(NULL, NA_real_, Inf, 3.5, c(4L, 4L), "4", 2L)) {
    malformed <- valid_shape
    attr(malformed, "Size") <- size
    expect_error(embed_snapshots(list(malformed, malformed), method = "cmds",
                                  periods = 1:2))
  }
  for (labels in list(NULL, letters[1:3], c("a", "a", "c", "d"),
                      c("a", NA_character_, "c", "d"), c("a", " ", "c", "d"),
                      factor(letters[1:4]))) {
    malformed <- valid_shape
    attr(malformed, "Labels") <- labels
    expect_error(embed_snapshots(list(malformed, malformed), method = "cmds",
                                  periods = 1:2))
  }
})

test_that("feature schemas are explicit finite and unambiguous", {
  d <- embedding_fixture()
  expect_error(embed_snapshots(d))
  for (features in list("a", c("a", "a"), c("a", "absent"), c("entity", "a"),
                       c("a", NA_character_), c("a", "cluster"))) {
    expect_error(embed_snapshots(d, features))
  }
  for (bad_value in list(NA_real_, NaN, Inf, -Inf)) {
    bad <- d
    bad$a[1] <- bad_value
    expect_error(embed_snapshots(bad, c("a", "b")))
  }
  bad <- d
  bad$a <- as.character(bad$a)
  expect_error(embed_snapshots(bad, c("a", "b")))
  bad <- d
  bad$a <- I(cbind(d$a, d$b))
  expect_error(embed_snapshots(bad, c("a", "b")))
})

test_that("core entity-time validation also guards feature adapters", {
  d <- embedding_fixture()
  expect_error(embed_snapshots(rbind(d, d[1, ]), c("a", "b")))
  bad <- d
  bad$entity[1] <- NA_character_
  expect_error(embed_snapshots(bad, c("a", "b")))
  bad <- d
  bad$entity[1] <- " "
  expect_error(embed_snapshots(bad, c("a", "b")))
  bad <- d
  bad$time[1] <- NA_real_
  expect_error(embed_snapshots(bad, c("a", "b")))
  expect_error(embed_snapshots(d, c("a", "b"), periods = 1:3))
  expect_error(embed_snapshots(d[d$time == 1, ], c("a", "b")))
})

test_that("invalid feature weight vectors fail before fitting", {
  d <- embedding_fixture()
  features <- c("a", "b", "c", "d")
  bad_weights <- list(1, rep(0, 4), c(1, 1, 1, -1), c(1, 1, 1, NA_real_),
                      c(1, 1, 1, Inf), c("1", "1", "1", "1"),
                      c(a = 1, b = 1, c = 1, unknown = 1),
                      c(a = 1, b = 1, c = 1, c = 1),
                      c(a = 1, 1, c = 1, d = 1))
  for (weights in bad_weights) {
    expect_error(embed_snapshots(d, features, feature_weights = weights))
  }
})

test_that("insufficient rank is rejected and unscaled constants are retained safely", {
  d <- embedding_fixture()
  too_small <- d[d$entity %in% LETTERS[1:2], ]
  for (method in c("pca", "cmds")) {
    expect_error(embed_snapshots(too_small, c("a", "b"), method = method))
    linear <- d
    linear$b <- 3 * linear$a + 2
    expect_error(embed_snapshots(linear, c("a", "b"), method = method))
    expect_error(embed_snapshots(d, c("a", "b"), method = method,
                                 feature_weights = c(1, 0)))
  }
  d$c <- 2
  object <- embed_snapshots(d, c("a", "b", "c"))
  expect_true(all(is.finite(as.matrix(object$coordinates[c("x", "y")]))))
  for (policy in c("first", "pooled", "period")) {
    expect_error(embed_snapshots(d, c("a", "b", "c"), standardize = policy))
  }
})

test_that("omitted constant features do not block declared standardization", {
  d <- embedding_fixture()
  d$c <- 2
  d$d <- 0
  for (policy in c("first", "pooled", "period")) {
    weighted <- embed_snapshots(d, c("a", "b", "c", "d"),
                                standardize = policy, feature_weights = c(1, 1, 0, 0))
    selected <- embed_snapshots(d, c("a", "b"), standardize = policy)
    for (j in 1:2) {
      expect_equal(embedding_distances(embedding_points(weighted, j)),
                     embedding_distances(embedding_points(selected, j)), tolerance = 1e-10)
      expect_equal(unname(weighted$embedding_metadata$preprocessing$scales[[j]][3:4]), c(1, 1))
    }
  }
})

test_that("diagnostics report omitted inertia and the chosen two-dimensional boundary", {
  d <- embedding_fixture()
  object <- embed_snapshots(d, c("a", "b", "c", "d"))
  diagnostic <- object$diagnostics$embedding
  required <- c("time", "period_index", "method", "n_entities", "n_features",
                "n_positive", "n_negative", "negative_inertia_fraction",
                "positive_inertia_2d_fraction", "absolute_inertia_2d_fraction",
                "eigengap_23", "boundary_tie", "distance_rmse")
  expect_true(all(required %in% names(diagnostic)))
  expect_equal(diagnostic$n_entities, c(8L, 8L))
  expect_equal(diagnostic$n_features, c(4L, 4L))
  expect_equal(diagnostic$n_positive, c(4L, 4L))
  expect_equal(diagnostic$n_negative, c(0L, 0L))
  expect_false(any(diagnostic$boundary_tie))
  for (j in 1:2) {
    eig <- object$embedding_metadata$fits[[j]]$eigenvalues
    expect_equal(diagnostic$positive_inertia_2d_fraction[j], sum(eig[1:2]) / sum(eig),
                 tolerance = 1e-10)
    expect_equal(diagnostic$eigengap_23[j], (eig[2] - eig[3]) / max(abs(eig)),
                 tolerance = 1e-10)
  }
})

test_that("equal eigenvalues at the retained boundary are flagged", {
  # Three orthogonal centered contrasts with equal Gram inertia.
  x <- rbind(diag(3), -diag(3))
  d <- data.frame(entity = rep(LETTERS[1:6], 2), time = rep(1:2, each = 6),
                  a = rep(x[, 1], 2), b = rep(x[, 2], 2), c = rep(x[, 3], 2))
  for (method in c("pca", "cmds")) {
    captured <- embedding_warnings(embed_snapshots(d, c("a", "b", "c"), method = method))
    object <- captured$value
    expect_length(captured$messages, 2L)
    expect_true(all(grepl("tie", captured$messages)))
    expect_true(all(object$diagnostics$embedding$boundary_tie))
    expect_equal(object$diagnostics$embedding$eigengap_23, c(0, 0), tolerance = 1e-10)
    # A tied first/second pair is an identifiable retained subspace.
    expect_no_warning(inside <- embed_snapshots(d, c("a", "b"), method = method))
    expect_false(any(inside$diagnostics$embedding$boundary_tie))
  }
})

test_that("public classical MDS requires explicit truncation of negative inertia", {
  dm <- matrix(c(0, 1, 1, 3,
                 1, 0, 1, 1,
                 1, 1, 0, 1,
                 3, 1, 1, 0), 4, 4, byrow = TRUE,
               dimnames = list(LETTERS[1:4], LETTERS[1:4]))
  distance_list <- list(before = dm, after = dm)
  expect_error(embed_snapshots(distance_list, method = "cmds"))
  captured <- embedding_warnings(embed_snapshots(distance_list, method = "cmds",
                                                  negative_eigen = "truncate"))
  object <- captured$value
  expect_length(captured$messages, 2L)
  expect_true(all(grepl("negative", captured$messages)))
  expect_true(all(object$diagnostics$embedding$n_negative > 0))
  expect_true(all(object$diagnostics$embedding$negative_inertia_fraction > 0))
  expect_true(all(object$diagnostics$embedding$distance_rmse > 0))
  expect_equal(measure_drift(align_snapshots(object))$distance, rep(0, 4),
                 tolerance = 1e-9)
})

test_that("invalid eigen tolerance and adapter choices are rejected", {
  d <- embedding_fixture()
  for (tol in list(0, -1, 1, Inf, NA_real_, c(1e-8, 1e-9), "small")) {
    expect_error(embed_snapshots(d, c("a", "b"), eigen_tol = tol))
  }
  expect_error(embed_snapshots(d, c("a", "b"), method = "umap"))
  expect_error(embed_snapshots(d, c("a", "b"), standardize = "automatic"))
  expect_error(embed_snapshots(d, c("a", "b"), negative_eigen = "correct"))
})
