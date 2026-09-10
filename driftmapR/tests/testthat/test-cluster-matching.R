# Exact-membership fixtures contain no estimated clustering or random geometry.
# Labels have no statistical order; coordinates deliberately play no role.
cm_data <- function(snapshots, times = seq_along(snapshots)) {
  entities <- sort(unique(unlist(lapply(snapshots, names))), method = "radix")
  rows <- lapply(seq_along(snapshots), function(j) {
    labels <- snapshots[[j]]
    ix <- match(names(labels), entities)
    data.frame(entity = names(labels), time = rep(times[j], length(labels)),
               x = as.numeric(ix), y = as.numeric(ix^2), cluster = unname(labels),
               stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

cm_from_counts <- function(counts) {
  stopifnot(is.matrix(counts), all(counts >= 0), all(counts == round(counts)))
  before <- after <- character()
  k <- 0L
  for (i in seq_len(nrow(counts))) {
    for (j in seq_len(ncol(counts))) {
      if (counts[i, j] > 0) {
        ids <- paste0("e", k + seq_len(counts[i, j]))
        k <- k + counts[i, j]
        before <- c(before, stats::setNames(rep(rownames(counts)[i], length(ids)), ids))
        after <- c(after, stats::setNames(rep(colnames(counts)[j], length(ids)), ids))
      }
    }
  }
  # A zero row/column is still an observed cluster, with no common entity.
  for (i in which(rowSums(counts) == 0)) {
    before <- c(before, stats::setNames(rownames(counts)[i], paste0("left", i)))
  }
  for (j in which(colSums(counts) == 0)) {
    after <- c(after, stats::setNames(colnames(counts)[j], paste0("right", j)))
  }
  cm_data(list(before, after))
}

cm_registry <- function(object, period) {
  x <- object$diagnostics$cluster_matching$registry
  x[x$period_index == period, , drop = FALSE]
}

cm_ids <- function(object, period) {
  x <- cm_registry(object, period)
  stats::setNames(x$cluster_id, x$cluster_original)
}

cm_matches <- function(object) {
  x <- object$diagnostics$cluster_matching$assignments
  x[x$status == "matched", , drop = FALSE]
}

# Independent exhaustive oracle: enumerate every legal partial assignment.
# Suitable only for the deliberately tiny matrices used below.
cm_optimum <- function(counts, minimum = 1L) {
  search <- function(i, unused) {
    if (i > nrow(counts)) return(0)
    alternatives <- search(i + 1L, unused)
    for (j in unused[counts[i, unused] >= minimum & counts[i, unused] > 0]) {
      alternatives <- c(alternatives,
                        counts[i, j] + search(i + 1L, setdiff(unused, j)))
    }
    max(alternatives)
  }
  search(1L, seq_len(ncol(counts)))
}

test_that("pure label permutations preserve identities without alignment", {
  d <- cm_data(list(c(a = "oak", b = "oak", c = "pine", d = "pine"),
                    c(a = "20", b = "20", c = "10", d = "10")))
  object <- drift_data(d)
  result <- match_clusters(object)
  expect_s3_class(result, "driftmap")
  expect_null(result$aligned)
  expect_identical(result$coordinates, object$coordinates)
  expect_equal(unname(cm_ids(result, 1)[c("oak", "pine")]), c("C0001", "C0002"))
  expect_equal(unname(cm_ids(result, 2)[c("20", "10")]), c("C0001", "C0002"))
  assignments <- cm_matches(result)
  expect_equal(assignments$n_overlap, c(2L, 2L))
  expect_equal(assignments$jaccard, c(1, 1))
  expect_true(all(assignments$reason == "max_overlap"))
  expect_equal(result$diagnostics$cluster_matching$periods$objective_overlap, 4)
  expect_true(all(result$clusters$cluster_status[result$clusters$period_index == 1] == "initial"))
  expect_true(all(result$clusters$cluster_status[result$clusters$period_index == 2] == "matched"))
})

test_that("an entity switch is retained in observed transitions", {
  d <- cm_data(list(c(a = "A", b = "A", c = "A", d = "B", e = "B"),
                    c(a = "X", b = "X", c = "Y", d = "Y", e = "Y")))
  result <- match_clusters(drift_data(d))
  flow <- result$diagnostics$cluster_matching$transitions
  switch <- flow[flow$cluster_from == "A" & flow$cluster_to == "Y", ]
  expect_equal(switch$n_overlap, 1)
  expect_equal(switch$from_share, 1 / 3)
  expect_equal(switch$to_share, 1 / 3)
  expect_false(switch$selected)
  expect_true(switch$split_candidate)
  expect_true(switch$merge_candidate)
  switched <- result$clusters[result$clusters$entity == "c", ]
  expect_equal(switched$cluster_id, c("C0001", "C0002"))
  expect_equal(sum(flow$n_overlap), 5)
})

test_that("split candidates retain one identity and allocate the other", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "A", c = "A", d = "A", e = "A"),
    c(a = "X", b = "X", c = "X", d = "Y", e = "Y")))))
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0001", "C0002"))
  flow <- result$diagnostics$cluster_matching$transitions
  expect_true(all(flow$split_candidate))
  expect_false(any(flow$merge_candidate))
  expect_equal(sum(flow$selected), 1)
  assignments <- result$diagnostics$cluster_matching$assignments
  new <- assignments[assignments$status == "unmatched_current", ]
  expect_equal(new$cluster_to, "Y")
  expect_equal(new$reason, "assignment_competition")
  expect_equal(result$diagnostics$cluster_matching$periods$n_new, 1L)
})

test_that("merge candidates retain one predecessor without inventing two matches", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "A", c = "A", d = "B", e = "B"),
    c(a = "X", b = "X", c = "X", d = "X", e = "X")))))
  expect_equal(unname(cm_ids(result, 2)["X"]), "C0001")
  flow <- result$diagnostics$cluster_matching$transitions
  expect_true(all(flow$merge_candidate))
  expect_false(any(flow$split_candidate))
  expect_equal(sum(flow$selected), 1)
  assignments <- result$diagnostics$cluster_matching$assignments
  old <- assignments[assignments$status == "unmatched_previous", ]
  expect_equal(old$cluster_from, "B")
  expect_equal(old$reason, "assignment_competition")
})

test_that("births and deaths do not continue zero-overlap clusters", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "A", c = "B"), c(a = "X", b = "X", d = "Y")))))
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0001", "C0003"))
  diag <- result$diagnostics$cluster_matching
  counts <- diag$overlap_matrices[["p1_to_p2"]]
  expect_equal(counts["A", "X"], 2)
  expect_equal(counts["B", "Y"], 0)
  expect_equal(dim(counts), c(2L, 2L))
  expect_equal(nrow(diag$transitions), 1L)
  expect_equal(diag$periods$n_unmatched_previous, 1L)
  expect_equal(diag$periods$n_new, 1L)
  unmatched <- diag$assignments[diag$assignments$status != "matched", ]
  expect_true(all(unmatched$reason == "no_jointly_labeled_members"))
  expect_true(all(is.na(unmatched$ambiguous)))
})

test_that("completely disjoint entity sets allocate all new identities", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "B"), c(c = "A", d = "B")))))
  expect_equal(unname(cm_ids(result, 2)[c("A", "B")]), c("C0003", "C0004"))
  diag <- result$diagnostics$cluster_matching
  expect_equal(diag$periods$n_shared_entities, 0L)
  expect_equal(diag$periods$n_jointly_labeled, 0L)
  expect_equal(diag$periods$n_matched, 0L)
  expect_equal(diag$periods$objective_overlap, 0)
  expect_equal(nrow(diag$transitions), 0L)
  expect_equal(sum(diag$overlap_matrices[[1]]), 0)
})

test_that("adjacent matching never resurrects a discontinued identity", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "B"), c(b = "X", c = "Y"), c(a = "A", c = "Z")))))
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0002", "C0003"))
  expect_equal(unname(cm_ids(result, 3)[c("A", "Z")]), c("C0004", "C0003"))
  expect_named(result$diagnostics$cluster_matching$overlap_matrices,
               c("p1_to_p2", "p2_to_p3"))
})

test_that("missing and explicitly excluded noise labels remain unassigned", {
  d <- cm_data(list(c(a = "A", b = "A", c = NA, d = "noise", e = "B"),
                    c(a = "X", b = NA, c = "X", d = "noise", e = "Y")))
  result <- match_clusters(drift_data(d), noise = "noise")
  diag <- result$diagnostics$cluster_matching
  expect_equal(diag$periods$n_shared_entities, 5L)
  expect_equal(diag$periods$n_jointly_labeled, 2L)
  expect_equal(sum(diag$overlap_matrices[[1]]), 2L)
  expect_equal(cm_matches(result)$jaccard, c(1, 1))
  expect_false("noise" %in% diag$registry$cluster_original)
  unassigned <- is.na(result$clusters$cluster_original) |
    result$clusters$cluster_original == "noise"
  expect_true(all(is.na(result$clusters$cluster_id[unassigned])))
  expect_true(all(result$clusters$cluster_status[unassigned] == "unassigned"))
  ordinary <- match_clusters(drift_data(d))
  expect_true("noise" %in% ordinary$diagnostics$cluster_matching$registry$cluster_original)
})

test_that("Jaccard uses the jointly labeled shared cohort", {
  d <- cm_data(list(c(a = "A", b = "A", c = "A", d = "A", e = "B"),
                    c(a = "X", b = NA, e = "Y", f = "X", g = "X")))
  result <- match_clusters(drift_data(d), min_jaccard = 1)
  assignments <- cm_matches(result)
  ax <- assignments[assignments$cluster_from == "A", ]
  expect_equal(ax$from_total, 4L)
  expect_equal(ax$to_total, 3L)
  expect_equal(ax$from_shared, 1L)
  expect_equal(ax$to_shared, 1L)
  expect_equal(ax$jaccard, 1)
  expect_true(all(is.na(cm_registry(result, 1)$size_shared)))
  registry <- cm_registry(result, 2)
  expect_equal(registry$size_shared[registry$cluster_original == "X"], 1L)
  expect_equal(result$diagnostics$cluster_matching$periods$n_shared_entities, 3L)
  expect_equal(result$diagnostics$cluster_matching$periods$n_jointly_labeled, 2L)
})

test_that("entirely unassigned periods preserve typed empty outputs", {
  d <- cm_data(list(c(a = NA_character_, b = NA_character_),
                    c(a = NA_character_, c = NA_character_)))
  result <- match_clusters(drift_data(d))
  diag <- result$diagnostics$cluster_matching
  expect_equal(nrow(diag$registry), 0L)
  expect_equal(nrow(diag$assignments), 0L)
  expect_equal(nrow(diag$transitions), 0L)
  expect_equal(dim(diag$overlap_matrices[[1]]), c(0L, 0L))
  expect_equal(diag$periods$n_jointly_labeled, 0L)
  expect_true(all(is.na(result$clusters$cluster_id)))
  expect_type(result$clusters$cluster_id, "character")
  expect_type(diag$assignments$ambiguous, "logical")
})

test_that("an assigned period can border a fully unassigned period", {
  result <- match_clusters(drift_data(cm_data(list(
    c(a = "A", b = "B"), c(a = NA_character_, b = NA_character_),
    c(a = "A", b = "B")))))
  expect_equal(unname(cm_ids(result, 3)[c("A", "B")]), c("C0003", "C0004"))
  diag <- result$diagnostics$cluster_matching
  expect_equal(dim(diag$overlap_matrices[[1]]), c(2L, 0L))
  expect_equal(dim(diag$overlap_matrices[[2]]), c(0L, 2L))
  expect_equal(diag$periods$n_matched, c(0L, 0L))
  expect_equal(diag$periods$n_new, c(0L, 2L))
})

test_that("global assignment resolves a case where greedy matching fails", {
  counts <- matrix(c(9, 8, 8, 0), 2, byrow = TRUE,
                   dimnames = list(c("A", "B"), c("X", "Y")))
  result <- match_clusters(drift_data(cm_from_counts(counts)))
  assignments <- cm_matches(result)
  expect_equal(result$diagnostics$cluster_matching$periods$objective_overlap, 16)
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0002", "C0001"))
  expect_equal(assignments$edge_margin, c(7, 7))
  expect_false(any(assignments$ambiguous))
})

test_that("minimum overlap filters edges before optimization", {
  counts <- matrix(c(5, 4, 4, 0), 2, byrow = TRUE,
                   dimnames = list(c("A", "B"), c("X", "Y")))
  result <- match_clusters(drift_data(cm_from_counts(counts)), min_overlap = 5L)
  assignments <- cm_matches(result)
  expect_equal(nrow(assignments), 1L)
  expect_equal(assignments$cluster_from, "A")
  expect_equal(assignments$cluster_to, "X")
  expect_equal(result$diagnostics$cluster_matching$periods$objective_overlap, 5)
  flow <- result$diagnostics$cluster_matching$transitions
  expect_equal(sum(flow$eligible), 1L)
  unmatched <- result$diagnostics$cluster_matching$assignments
  unmatched <- unmatched[unmatched$status != "matched", ]
  expect_true(all(unmatched$reason == "below_threshold"))
})

test_that("Jaccard threshold boundaries are inclusive", {
  counts <- matrix(c(2, 1, 0, 2), 2, byrow = TRUE,
                   dimnames = list(c("A", "B"), c("X", "Y")))
  inclusive <- match_clusters(drift_data(cm_from_counts(counts)), min_jaccard = 2 / 3)
  expect_equal(nrow(cm_matches(inclusive)), 2L)
  excluded <- match_clusters(drift_data(cm_from_counts(counts)), min_jaccard = 0.7)
  expect_equal(nrow(cm_matches(excluded)), 0L)
  expect_equal(excluded$diagnostics$cluster_matching$periods$objective_overlap, 0)
})

test_that("exact assignment ties are deterministic and reported", {
  counts <- matrix(1L, 2, 2, dimnames = list(c("A", "B"), c("X", "Y")))
  d <- cm_from_counts(counts)
  result <- match_clusters(drift_data(d))
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0001", "C0002"))
  assignments <- cm_matches(result)
  expect_true(all(assignments$ambiguous))
  expect_equal(assignments$edge_margin, c(0, 0))
  expect_true(result$diagnostics$cluster_matching$periods$has_ambiguous_assignment)
  shuffled <- match_clusters(drift_data(d[rev(seq_len(nrow(d))), ]))
  expect_identical(shuffled$clusters, result$clusters)
  expect_identical(shuffled$diagnostics$cluster_matching, result$diagnostics$cluster_matching)
})

test_that("tie order prioritizes prior identity, then current label, with unmatched last", {
  counts <- matrix(2L, 2, 1, dimnames = list(c("A", "B"), "X"))
  result <- match_clusters(drift_data(cm_from_counts(counts)))
  expect_equal(unname(cm_ids(result, 2)["X"]), "C0001")
  expect_true(cm_matches(result)$ambiguous)
  expect_equal(cm_matches(result)$edge_margin, 0)
  counts <- matrix(2L, 1, 2, dimnames = list("A", c("X", "Y")))
  result <- match_clusters(drift_data(cm_from_counts(counts)))
  expect_equal(unname(cm_ids(result, 2)[c("X", "Y")]), c("C0001", "C0002"))
})

test_that("disabled tie diagnostics retain the same assignment with unknown margins", {
  counts <- matrix(1L, 2, 2, dimnames = list(c("A", "B"), c("X", "Y")))
  object <- drift_data(cm_from_counts(counts))
  diagnosed <- match_clusters(object)
  disabled <- match_clusters(object, diagnose_ties = FALSE)
  expect_identical(disabled$clusters, diagnosed$clusters)
  expect_true(all(is.na(cm_matches(disabled)$edge_margin)))
  expect_true(all(is.na(cm_matches(disabled)$ambiguous)))
  expect_true(is.na(disabled$diagnostics$cluster_matching$periods$has_ambiguous_assignment))
})

test_that("small random assignments agree with exhaustive partial-assignment optima", {
  set.seed(62031)
  for (k in seq_len(24L)) {
    nr <- sample(1:3, 1)
    nc <- sample(1:3, 1)
    counts <- matrix(sample(0:5, nr * nc, replace = TRUE), nr, nc,
                     dimnames = list(LETTERS[seq_len(nr)], letters[seq_len(nc)]))
    minimum <- sample(1:3, 1)
    result <- match_clusters(drift_data(cm_from_counts(counts)), min_overlap = minimum)
    assignments <- cm_matches(result)
    expect_equal(sum(assignments$n_overlap), cm_optimum(counts, minimum),
                 info = paste("independent exhaustive oracle case", k))
    expect_false(anyDuplicated(assignments$cluster_from) > 0L)
    expect_false(anyDuplicated(assignments$cluster_to) > 0L)
    expect_true(all(assignments$n_overlap >= minimum))
  }
})

test_that("factor and numeric labels canonicalize without unused phantom clusters", {
  d <- cm_data(list(c(a = "b", b = "a"), c(a = "y", b = "x")))
  d$cluster <- factor(d$cluster, levels = c("unused", "b", "a", "y", "x"))
  result <- match_clusters(drift_data(d))
  expect_equal(unname(cm_ids(result, 1)[c("a", "b")]), c("C0001", "C0002"))
  expect_false("unused" %in% result$diagnostics$cluster_matching$registry$cluster_original)
  expect_type(result$clusters$cluster_original, "character")
  d$cluster <- c(2, 10, 20, 100)
  result <- match_clusters(drift_data(d))
  expect_equal(unname(cm_ids(result, 1)[c("10", "2")]), c("C0001", "C0002"))
  expect_equal(unname(cm_ids(result, 2)[c("20", "100")]), c("C0002", "C0001"))
  d$cluster <- c(-1, 1, -1, 9)
  result <- match_clusters(drift_data(d), noise = -1)
  expect_true(all(is.na(result$clusters$cluster_id[result$clusters$cluster_original == "-1"])))
})

test_that("Date and explicit character schedules survive matching", {
  snapshots <- list(c(a = "A", b = "B"), c(a = "X", b = "Y"),
                    c(a = "later", b = "earlier"))
  dates <- as.Date(c("2025-01-01", "2025-02-01", "2025-03-01"))
  result <- match_clusters(drift_data(cm_data(snapshots, dates)))
  diag <- result$diagnostics$cluster_matching
  expect_s3_class(result$clusters$time, "Date")
  expect_s3_class(diag$registry$time, "Date")
  expect_s3_class(diag$assignments$time_from, "Date")
  expect_s3_class(diag$transitions$time_to, "Date")
  expect_equal(diag$periods$time_from, dates[1:2])
  schedule <- c("baseline", "second", "final")
  result <- match_clusters(drift_data(cm_data(snapshots, schedule), periods = schedule))
  expect_equal(result$diagnostics$cluster_matching$periods$time_to, schedule[2:3])
  expect_equal(unname(cm_ids(result, 3)[c("later", "earlier")]), c("C0001", "C0002"))
})

test_that("matching composes with alignment and preserves existing numerical results", {
  fixture <- fixture_snapshots(rotation = fixture_rotation(pi / 2), translation = c(9, -4))
  fixture$data$cluster <- rep(c("A", "A", "A", "A", "B", "B", "B", "B"), 2)
  fixture$data$cluster[fixture$data$time == 2] <- rep(c("Y", "X"), each = 4)
  raw <- drift_data(fixture$data)
  aligned <- align_snapshots(raw)
  aligned$movement <- measure_drift(aligned)
  aligned$bootstrap <- list(stale = TRUE)
  aligned$diagnostics$sentinel <- "keep"
  result <- match_clusters(aligned)
  expect_identical(result$coordinates, aligned$coordinates)
  expect_identical(result$aligned, aligned$aligned)
  expect_identical(result$transformations, aligned$transformations)
  expect_identical(result$movement, aligned$movement)
  expect_identical(result$diagnostics$sentinel, "keep")
  expect_null(result$bootstrap)
  expect_identical(result$clusters, match_clusters(raw)$clusters)
  expect_equal(measure_drift(result)$distance, rep(0, 8), tolerance = 1e-10)
  expect_silent(validate_drift_data(result))
})

test_that("settings document matching choices and custom label columns", {
  d <- cm_data(list(c(a = "A", b = "A"), c(a = "X", b = "X")))
  names(d)[names(d) == "cluster"] <- "group"
  result <- match_clusters(drift_data(d), cluster = "group", min_overlap = 2L,
                           min_jaccard = 0.5, noise = "noise", diagnose_ties = FALSE)
  settings <- result$settings$cluster_matching
  expect_equal(settings$cluster, "group")
  expect_equal(settings$min_overlap, 2L)
  expect_equal(settings$min_jaccard, 0.5)
  expect_equal(settings$noise, "noise")
  expect_false(settings$diagnose_ties)
  expect_equal(nrow(cm_matches(result)), 1L)
})

test_that("invalid cluster columns and scalar controls fail informatively", {
  d <- cm_data(list(c(a = "A", b = "B"), c(a = "X", b = "Y")))
  object <- drift_data(d)
  expect_error(match_clusters(d))
  expect_error(match_clusters(object, cluster = "absent"), "cluster|column")
  for (bad in list(NULL, NA_character_, character(), c("cluster", "x"), 1L, "")) {
    expect_error(match_clusters(object, cluster = bad))
  }
  for (bad in list(0, -1, 1.5, Inf, NA_real_, "1", c(1, 2))) {
    expect_error(match_clusters(object, min_overlap = bad))
  }
  for (bad in list(-0.1, 1.1, Inf, NA_real_, "0", c(0, 1))) {
    expect_error(match_clusters(object, min_jaccard = bad))
  }
  for (bad in list(NA, 1, "TRUE", logical(), c(TRUE, FALSE))) {
    expect_error(match_clusters(object, diagnose_ties = bad))
  }
  for (bad in list(c("A", "", "X", "Y"), c("A", " ", "X", "Y"),
                   c(1, Inf, 2, 3), as.list(d$cluster), matrix(d$cluster, ncol = 1))) {
    invalid <- object
    invalid$coordinates$cluster <- bad
    expect_error(match_clusters(invalid))
  }
  invalid <- object
  invalid$coordinates$cluster <- c(1, 1 + 1e-15, 2, 3)
  expect_error(match_clusters(invalid), "precision")
})

test_that("numeric NaN labels are unassigned just like numeric NA", {
  d <- cm_data(list(c(a = 1, b = NaN, c = NA_real_),
                    c(a = 2, b = NaN, c = 3)))
  result <- match_clusters(drift_data(d))
  missing <- is.na(result$coordinates$cluster)
  expect_true(all(is.na(result$clusters$cluster_original[missing])))
  expect_true(all(is.na(result$clusters$cluster_id[missing])))
  expect_true(all(result$clusters$cluster_status[missing] == "unassigned"))
  expect_false("NaN" %in% result$diagnostics$cluster_matching$registry$cluster_original)
  expect_equal(result$diagnostics$cluster_matching$periods$n_jointly_labeled, 1L)
  expect_equal(unname(cm_ids(result, 2)[c("2", "3")]), c("C0001", "C0002"))
})

test_that("an all-NA logical label column is accepted without admitting logical labels", {
  d <- cm_data(list(c(a = "A", b = "B"), c(a = "X", b = "Y")))
  d$cluster <- NA
  result <- match_clusters(drift_data(d))
  expect_true(all(is.na(result$clusters$cluster_original)))
  expect_true(all(is.na(result$clusters$cluster_id)))
  expect_true(all(result$clusters$cluster_status == "unassigned"))
  expect_equal(result$diagnostics$cluster_matching$periods$n_clusters_from, 0L)
  expect_equal(result$diagnostics$cluster_matching$periods$n_clusters_to, 0L)
  for (nonmissing in c(TRUE, FALSE)) {
    d$cluster[1] <- nonmissing
    expect_error(match_clusters(drift_data(d)))
  }
})

test_that("numeric clusters can start after a wholly unassigned dated first period", {
  dates <- as.Date(c("2025-01-01", "2025-02-01", "2025-03-01"))
  d <- cm_data(list(c(a = NA_real_, b = NA_real_), c(a = 10, b = 2),
                    c(a = 99, b = 11)), times = dates)
  result <- match_clusters(drift_data(d))
  expect_equal(unname(cm_ids(result, 2)[c("10", "2")]), c("C0001", "C0002"))
  expect_equal(unname(cm_ids(result, 3)[c("99", "11")]), c("C0001", "C0002"))
  diag <- result$diagnostics$cluster_matching
  expect_s3_class(result$clusters$time, "Date")
  expect_s3_class(diag$registry$time, "Date")
  expect_s3_class(diag$assignments$time_from, "Date")
  expect_s3_class(diag$transitions$time_to, "Date")
  expect_equal(diag$periods$n_matched, c(0L, 2L))
  expect_equal(diag$periods$n_new, c(2L, 0L))
  expect_equal(dim(diag$overlap_matrices[["p1_to_p2"]]), c(0L, 2L))
})
