# Maximum-weight partial bipartite assignment for integer overlap counts.
# Zero scores are forbidden real links, and leaving any vertex unmatched is
# free. Real choices are ordered by input column index; unmatched sorts last.
# Among all primary-objective optima, rows are fixed in input order to produce
# the exact lexicographically smallest real mapping. No floating perturbation
# or undocumented tie ordering from clue is used.
#
# Diagnostics forbid each selected edge in the ORIGINAL component problem.
# A zero objective loss therefore means that an alternative global optimum
# omits that edge; it is not a conditional loss after earlier lexicographic
# choices and is not a statistical uncertainty estimate.
solve_cluster_assignment <- function(weights, diagnose_ties = TRUE) {
  if (!is.matrix(weights) || !is.numeric(weights) ||
      any(!is.finite(weights)) || any(weights < 0) ||
      any(weights != floor(weights))) {
    stop("`weights` must be a finite nonnegative integer score matrix.",
         call. = FALSE)
  }
  if (sum(weights) > 2^53 - 1) {
    stop("Total weight must not exceed 2^53 - 1 for exact integer assignment.",
         call. = FALSE)
  }
  if (!is.logical(diagnose_ties) || length(diagnose_ties) != 1L ||
      is.na(diagnose_ties)) {
    stop("`diagnose_ties` must be TRUE or FALSE.", call. = FALSE)
  }

  nr <- nrow(weights)
  nc <- ncol(weights)
  result <- list(
    assignment = rep(NA_integer_, nr),
    objective = 0,
    margins = rep(NA_real_, nr),
    ambiguous = rep(NA, nr)
  )
  if (nr == 0L || nc == 0L || !any(weights > 0)) return(result)

  # Independent eligible-edge components have additive objectives. Processing
  # them independently preserves global rowwise lexicographic ordering while
  # avoiding repeated dense solves for hundreds of unrelated singleton groups.
  row_neighbors <- lapply(seq_len(nr), function(i) which(weights[i, ] > 0))
  col_neighbors <- lapply(seq_len(nc), function(j) which(weights[, j] > 0))
  seen_rows <- rep(FALSE, nr)
  seen_cols <- rep(FALSE, nc)
  for (seed in which(lengths(row_neighbors) > 0L)) {
    if (seen_rows[seed]) next
    rows <- seed
    cols <- integer()
    seen_rows[seed] <- TRUE
    pos <- 1L
    while (pos <= length(rows)) {
      added_cols <- row_neighbors[[rows[pos]]]
      added_cols <- added_cols[!seen_cols[added_cols]]
      if (length(added_cols)) {
        seen_cols[added_cols] <- TRUE
        cols <- c(cols, added_cols)
        added_rows <- unique(unlist(col_neighbors[added_cols],
                                    use.names = FALSE))
        added_rows <- added_rows[!seen_rows[added_rows]]
        seen_rows[added_rows] <- TRUE
        rows <- c(rows, added_rows)
      }
      pos <- pos + 1L
    }
    rows <- sort(rows)
    cols <- sort(cols)
    scores <- weights[rows, cols, drop = FALSE]
    if (length(rows) == 1L && length(cols) == 1L) {
      solved <- list(assignment = 1L, objective = as.numeric(scores[1L, 1L]))
    } else {
      solved <- .lex_cluster_assignment(scores)
    }
    chosen <- which(!is.na(solved$assignment))
    result$assignment[rows[chosen]] <- cols[solved$assignment[chosen]]
    result$objective <- result$objective + solved$objective
    if (diagnose_ties) {
      for (i in chosen) {
        forbidden <- scores
        forbidden[i, solved$assignment[i]] <- 0
        alternative <- .maximum_cluster_assignment(forbidden)$objective
        margin <- solved$objective - alternative
        result$margins[rows[i]] <- margin
        result$ambiguous[rows[i]] <- margin == 0
      }
    }
  }
  result
}

# A nonnegative maximum-weight partial matching has the same optimum as a
# square assignment completed with zero-score edges. Padding to max(nr, nc)
# supplies any missing vertices; zero-score real/dummy pairs are discarded.
# Unused real zero pairs cannot block a superior positive partial matching,
# since every partial matching can be completed to a square assignment.
.maximum_cluster_assignment <- function(weights) {
  nr <- nrow(weights)
  nc <- ncol(weights)
  empty <- list(assignment = rep(NA_integer_, nr), objective = 0)
  if (nr == 0L || nc == 0L || !any(weights > 0)) return(empty)
  if (nr == 1L) {
    j <- which.max(weights[1L, ])
    return(list(assignment = as.integer(j),
                objective = as.numeric(weights[1L, j])))
  }
  n <- max(nr, nc)
  padded <- matrix(0, n, n)
  padded[seq_len(nr), seq_len(nc)] <- weights
  assignment <- as.integer(clue::solve_LSAP(padded, maximum = TRUE))[seq_len(nr)]
  values <- padded[cbind(seq_len(nr), assignment)]
  assignment[assignment > nc | values == 0] <- NA_integer_
  list(assignment = assignment, objective = sum(values))
}

# Keep an optimal residual assignment as a feasibility certificate. Only
# candidate columns earlier than its first-row choice need another solve.
# Once an earlier candidate preserves the integer optimum, its optimal
# residual assignment becomes the certificate for the next row.
.lex_cluster_assignment <- function(weights) {
  nr <- nrow(weights)
  nc <- ncol(weights)
  baseline <- .maximum_cluster_assignment(weights)
  objective <- baseline$objective
  remaining_objective <- objective
  baseline_mapping <- baseline$assignment
  available_cols <- seq_len(nc)
  assignment <- rep(NA_integer_, nr)
  for (i in seq_len(nr)) {
    chosen <- baseline_mapping[i]
    candidates <- available_cols[weights[i, available_cols] > 0]
    if (!is.na(chosen)) candidates <- candidates[candidates < chosen]
    remaining_rows <- if (i < nr) seq.int(i + 1L, nr) else integer()
    for (j in candidates) {
      other_cols <- available_cols[available_cols != j]
      alternative <- .maximum_cluster_assignment(
        weights[remaining_rows, other_cols, drop = FALSE]
      )
      if (weights[i, j] + alternative$objective == remaining_objective) {
        chosen <- j
        baseline_mapping[remaining_rows] <-
          other_cols[alternative$assignment]
        break
      }
    }
    assignment[i] <- chosen
    if (!is.na(chosen)) {
      remaining_objective <- remaining_objective - weights[i, chosen]
      available_cols <- available_cols[available_cols != chosen]
    }
  }
  list(assignment = assignment, objective = objective)
}
