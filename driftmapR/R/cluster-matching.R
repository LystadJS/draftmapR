#' Match cluster identities across adjacent snapshots
#'
#' Match supplied hard cluster labels by maximum shared-entity overlap. This
#' function does not fit clusters and does not require aligned coordinates.
#'
#' @param object A `driftmap` created by [drift_data()].
#' @param cluster Name of the column in `object$coordinates` holding supplied
#'   cluster labels. Character, factor, and finite numeric labels are supported.
#'   Missing labels are unassigned. Blank labels and lossy numeric conversions
#'   are rejected. Raw values in `coordinates` are never replaced.
#' @param min_overlap Minimum number of jointly labeled shared entities for a
#'   candidate match; a positive integer. Default 1.
#' @param min_jaccard Minimum Jaccard overlap in `[0, 1]`. Both cluster sizes in
#'   this denominator use only entities present and assigned in BOTH snapshots.
#'   Eligibility thresholds apply before optimization.
#' @param noise Optional labels to treat as unassigned, for example `noise = 0`.
#'   No numeric label, including zero or minus one, is excluded automatically.
#' @param diagnose_ties Compute an objective-loss margin for each selected link?
#'   Default `TRUE`. Disabling this reduces repeated assignment work but retains
#'   deterministic tie resolution; margin/ambiguity diagnostics then are `NA`.
#' @return An updated `driftmap`. `clusters` is a tidy membership table with
#'   `entity`, `time`, `period_index`, character `cluster_original`, stable
#'   `cluster_id`, and `cluster_status` (`initial`, `matched`, `new`, `unassigned`).
#'   IDs are strings `C0001`, `C0002`, etc., never reused within a run.
#'
#'   `diagnostics$cluster_matching` contains:
#'   \describe{
#'     \item{registry}{One row per observed assigned cluster and period, with
#'       original/stable labels, total size, current jointly labeled shared size,
#'       and status. First-period shared sizes are `NA`.}
#'     \item{assignments}{Selected links and unmatched previous/current clusters.
#'       Includes counts, Jaccard, reasons, and `edge_margin`: the optimal total
#'       overlap minus the best total after forbidding that selected link. A zero
#'       margin implies another equally optimal correspondence excludes the link.
#'       Margins/ambiguity are `NA` for unmatched rows or disabled diagnostics.}
#'     \item{transitions}{Every positive observed cluster-to-cluster flow,
#'       including unselected and threshold-ineligible flows, its overlap count,
#'       shares, Jaccard, eligibility, selection, and split/merge candidate flags.}
#'     \item{periods}{Adjacent-pair denominators, cluster counts, matched/new/
#'       unmatched counts, total objective, and pair-level ambiguity.}
#'     \item{overlap_matrices, score_matrices}{Named matrix lists (`p1_to_p2`, etc.).
#'       Rows are previous labels in stable-ID order; columns are current labels
#'       in radix order. Scores equal overlap counts on eligible edges and zero
#'       elsewhere. Zero-size rows/columns for clusters with no shared members are
#'       retained. Only assigned labels create rows/columns.}
#'   }
#'   `settings$cluster_matching` records the contract. Coordinates, alignment,
#'   and stored geometric movement remain unchanged; stored bootstrap results
#'   are cleared because cluster identity has been recomputed.
#' @details For adjacent periods, restrict to the common entities whose labels
#'   are assigned in both. Let \eqn{O_{ab}} count members in previous cluster a
#'   and current cluster b. Maximize \eqn{\sum_{ab} O_{ab} M_{ab}} over binary
#'   one-to-one partial matches (row and column sums at most one). Zero overlaps
#'   can never continue an identity. Jaccard is
#'   \eqn{O_{ab}/(O_{a+}+O_{+b}-O_{ab})}. Matching maximizes the sum of overlap
#'   COUNTS, not the sum of Jaccards or the number of continued clusters.
#'
#'   Initial labels are ordered by radix sorting of their character values,
#'   ignoring factor level order. At each later step previous clusters are
#'   ordered by stable ID and current clusters by radix-sorted original label.
#'   Among equal maximum-overlap solutions, choose the lexicographically smallest
#'   row assignment, placing unmatched after all current labels. Exact integer
#'   feasibility comparisons resolve ties without numeric perturbations or
#'   dependence on the assignment solver's unspecified tie convention.
#'
#'   Only adjacent periods are linked. A returning label without shared membership
#'   receives a new identity. A missing-label/noise observation receives no stable
#'   identity. A cluster with no jointly labeled shared members is unmatched;
#'   this is not evidence of a real birth/death. Reasons distinguish this lack of
#'   evidence from filtering below thresholds or one-to-one competition.
#'
#'   A split candidate means a previous cluster overlaps multiple current clusters;
#'   a merge candidate means a current cluster overlaps multiple previous clusters.
#'   Flags use all positive flows, including ineligible ones. Ordinary individual
#'   switching can produce the same flags. One-to-one matching continues at most
#'   one identity through such patterns; this is not a split/merge model, cluster
#'   stability estimator, or probability of identity. A positive margin is an
#'   objective contrast, not a confidence measure. Results depend on observed
#'   common membership and may be unstable with selective entity loss.
#'
#'   Integer assignments use [clue::solve_LSAP()] with zero padding. Independent
#'   positive-overlap components are solved separately. Tie diagnostics require
#'   additional solves; `diagnose_ties = FALSE` leaves them explicitly unknown.
#' @export
#' @examples
#' first <- data.frame(entity = letters[1:6], time = 1,
#'                     x = c(0, 1, 0, 4, 5, 4), y = c(0, 0, 1, 0, 0, 1),
#'                     cluster = rep(c("A", "B"), each = 3))
#' second <- first
#' second$time <- 2
#' second$cluster <- rep(c("renamed_2", "renamed_1"), each = 3)
#' fit <- drift_data(rbind(first, second)) |> match_clusters()
#' fit$clusters
#' fit$diagnostics$cluster_matching$assignments
#' fit$diagnostics$cluster_matching$overlap_matrices[[1]]
match_clusters <- function(object, cluster = "cluster", min_overlap = 1L,
                            min_jaccard = 0, noise = NULL, diagnose_ties = TRUE) {
  validate_drift_data(object)
  z <- object$coordinates
  if (!is.character(cluster) || length(cluster) != 1L || is.na(cluster) ||
      !nzchar(cluster) || !cluster %in% names(z)) {
    stop("`cluster` must name one existing coordinate-table column.", call. = FALSE)
  }
  if (!is.numeric(min_overlap) || length(min_overlap) != 1L ||
      !is.finite(min_overlap) || min_overlap < 1 || min_overlap != floor(min_overlap)) {
    stop("`min_overlap` must be a positive integer.", call. = FALSE)
  }
  if (!is.numeric(min_jaccard) || length(min_jaccard) != 1L ||
      !is.finite(min_jaccard) || min_jaccard < 0 || min_jaccard > 1) {
    stop("`min_jaccard` must be a finite number in [0, 1].", call. = FALSE)
  }
  check_flag(diagnose_ties, "diagnose_ties")
  original <- normalize_cluster_labels(z[[cluster]], "cluster labels")
  if (!is.null(noise)) {
    noise <- normalize_cluster_labels(noise, "noise labels")
    if (anyNA(noise)) stop("`noise` labels must be nonmissing; NA is already unassigned.", call. = FALSE)
    noise <- unique(noise)
  }
  labels <- original
  labels[labels %in% noise] <- NA_character_
  periods <- object$settings$periods
  n_periods <- length(periods)
  registry <- vector("list", n_periods)
  memberships <- z[c("entity", "time", "period_index")]
  memberships$cluster_original <- original
  memberships$cluster_id <- NA_character_
  memberships$cluster_status <- "unassigned"
  next_id <- 1L
  assignments <- transitions <- pair_diagnostics <- overlaps <- scores <- vector("list", n_periods - 1L)
  for (j in seq_len(n_periods)) {
    idx <- which(z$period_index == j)
    current_labels <- sort(unique(labels[idx][!is.na(labels[idx])]), method = "radix")
    current <- data.frame(time = rep(periods[j], length(current_labels)),
                          period_index = rep(j, length(current_labels)),
                          cluster_original = current_labels,
                          cluster_id = rep(NA_character_, length(current_labels)),
                          size_total = tabulate(match(labels[idx], current_labels), nbins = length(current_labels)),
                          size_shared = rep(NA_integer_, length(current_labels)),
                          status = rep(if (j == 1L) "initial" else "new", length(current_labels)))
    if (j == 1L) {
      if (nrow(current)) {
        current$cluster_id <- sprintf("C%04d", seq.int(next_id, length.out = nrow(current)))
        next_id <- next_id + nrow(current)
      }
    } else {
      previous <- registry[[j - 1L]]
      previous <- previous[order(previous$cluster_id, method = "radix"), , drop = FALSE]
      old_idx <- which(z$period_index == j - 1L)
      common <- intersect(z$entity[old_idx], z$entity[idx])
      a <- labels[old_idx[match(common, z$entity[old_idx])]]
      b <- labels[idx[match(common, z$entity[idx])]]
      joint <- !is.na(a) & !is.na(b)
      nr <- nrow(previous)
      nc <- nrow(current)
      overlap <- matrix(0, nr, nc, dimnames = list(previous$cluster_original, current_labels))
      if (any(joint)) {
        ri <- match(a[joint], previous$cluster_original)
        ci <- match(b[joint], current_labels)
        overlap[] <- tabulate(ri + (ci - 1L) * nr, nbins = nr * nc)
      }
      from_shared <- rowSums(overlap)
      to_shared <- colSums(overlap)
      denominator <- outer(from_shared, to_shared, "+") - overlap
      jaccard <- overlap
      positive_denominator <- denominator > 0
      jaccard[positive_denominator] <- overlap[positive_denominator] / denominator[positive_denominator]
      eligible <- overlap >= min_overlap & jaccard >= min_jaccard
      weight <- overlap
      weight[!eligible] <- 0
      solved <- solve_cluster_assignment(weight, diagnose_ties)
      matched_rows <- which(!is.na(solved$assignment))
      matched_cols <- solved$assignment[matched_rows]
      if (length(matched_rows)) {
        current$cluster_id[matched_cols] <- previous$cluster_id[matched_rows]
        current$status[matched_cols] <- "matched"
      }
      unmatched_cols <- which(is.na(current$cluster_id))
      if (length(unmatched_cols)) {
        current$cluster_id[unmatched_cols] <- sprintf("C%04d", seq.int(next_id, length.out = length(unmatched_cols)))
        next_id <- next_id + length(unmatched_cols)
      }
      current$size_shared <- as.integer(to_shared)
      rows <- c(matched_rows, setdiff(seq_len(nr), matched_rows), rep(NA_integer_, length(unmatched_cols)))
      cols <- c(matched_cols, rep(NA_integer_, nr - length(matched_rows)), unmatched_cols)
      selected <- matrix(FALSE, nr, nc, dimnames = dimnames(overlap))
      if (length(matched_rows)) selected[cbind(matched_rows, matched_cols)] <- TRUE
      assignments[[j - 1L]] <- cluster_assignment_table(
        periods[j - 1L], periods[j], previous, current, rows, cols,
        overlap, jaccard, eligible, from_shared, to_shared, solved)
      transitions[[j - 1L]] <- cluster_transition_table(
        periods[j - 1L], periods[j], previous, current,
        overlap, jaccard, eligible, selected, from_shared, to_shared)
      pair_diagnostics[[j - 1L]] <- data.frame(
        time_from = periods[j - 1L], time_to = periods[j],
        n_shared_entities = length(common), n_jointly_labeled = sum(joint),
        n_excluded_shared = sum(!joint), n_clusters_from = nr, n_clusters_to = nc,
        n_matched = length(matched_rows), n_new = length(unmatched_cols),
        n_unmatched_previous = nr - length(matched_rows),
        objective_overlap = solved$objective,
        n_ambiguous_matches = if (diagnose_ties) sum(solved$ambiguous, na.rm = TRUE) else NA_integer_,
        has_ambiguous_assignment = if (diagnose_ties) any(solved$ambiguous, na.rm = TRUE) else NA)
      overlaps[[j - 1L]] <- overlap
      scores[[j - 1L]] <- weight
    }
    registry[[j]] <- current
    member_match <- match(labels[idx], current$cluster_original)
    assigned <- !is.na(member_match)
    memberships$cluster_id[idx[assigned]] <- current$cluster_id[member_match[assigned]]
    memberships$cluster_status[idx[assigned]] <- current$status[member_match[assigned]]
  }
  names(overlaps) <- names(scores) <- paste0("p", seq_len(n_periods - 1L), "_to_p", seq.int(2L, n_periods))
  bind <- function(x) {
    out <- do.call(rbind, x)
    rownames(out) <- NULL
    out
  }
  object$clusters <- memberships
  object$diagnostics$cluster_matching <- list(
    registry = bind(registry), assignments = bind(assignments),
    transitions = bind(transitions), periods = bind(pair_diagnostics),
    overlap_matrices = overlaps, score_matrices = scores)
  object$settings$cluster_matching <- list(
    cluster = cluster, reference = "previous", objective = "maximum_overlap_count",
    min_overlap = min_overlap, min_jaccard = min_jaccard, noise = noise,
    diagnose_ties = diagnose_ties, cohort = "shared_and_assigned_in_both_periods",
    tie_break = "lexicographic_previous_stable_id_current_label_unmatched_last",
    solver = "clue::solve_LSAP", solver_version = as.character(utils::packageVersion("clue")))
  object$bootstrap <- NULL
  object
}

normalize_cluster_labels <- function(x, name) {
  supported <- is.character(x) || is.factor(x) || (is.numeric(x) && !is.object(x)) ||
    (is.logical(x) && all(is.na(x)))
  if (!supported || !is.null(dim(x))) {
    stop("`", name, "` must be a character, factor, or numeric vector.", call. = FALSE)
  }
  if (is.numeric(x) && any(!is.finite(x[!is.na(x)]))) {
    stop("Numeric ", name, " must be finite or NA.", call. = FALSE)
  }
  if (is.numeric(x) && anyDuplicated(as.character(unique(x[!is.na(x)])))) {
    stop("Distinct numeric ", name, " lose precision as labels; supply explicit character values.", call. = FALSE)
  }
  out <- as.character(x)
  out[is.na(x)] <- NA_character_
  if (any(!is.na(out) & !nzchar(trimws(out)))) {
    stop("Blank ", name, " are invalid; use NA for unassigned membership.", call. = FALSE)
  }
  out
}

cluster_assignment_table <- function(time_from, time_to, previous, current, rows, cols,
                                      overlap, jaccard, eligible, from_shared, to_shared, solved) {
  n <- length(rows)
  matched <- !is.na(rows) & !is.na(cols)
  count <- rep(0, n)
  jac <- margin <- rep(NA_real_, n)
  ambiguous <- rep(NA, n)
  if (any(matched)) {
    count[matched] <- overlap[cbind(rows[matched], cols[matched])]
    jac[matched] <- jaccard[cbind(rows[matched], cols[matched])]
    margin[matched] <- solved$margins[rows[matched]]
    ambiguous[matched] <- solved$ambiguous[rows[matched]]
  }
  status <- rep("unmatched_current", n)
  status[is.na(cols)] <- "unmatched_previous"
  status[matched] <- "matched"
  reason <- rep("max_overlap", n)
  for (i in which(!matched)) {
    shared <- if (is.na(cols[i])) from_shared[rows[i]] else to_shared[cols[i]]
    candidates <- if (is.na(cols[i])) eligible[rows[i], ] else eligible[, cols[i]]
    reason[i] <- if (shared == 0) "no_jointly_labeled_members" else if (!any(candidates)) {
      "below_threshold"
    } else "assignment_competition"
  }
  data.frame(time_from = rep(time_from, n), time_to = rep(time_to, n),
              cluster_from = previous$cluster_original[rows], cluster_to = current$cluster_original[cols],
              id_from = previous$cluster_id[rows], id_to = current$cluster_id[cols],
              n_overlap = count, jaccard = jac,
              from_total = previous$size_total[rows], to_total = current$size_total[cols],
              from_shared = from_shared[rows], to_shared = to_shared[cols],
              status = status, reason = reason, edge_margin = margin, ambiguous = ambiguous,
              row.names = NULL)
}

cluster_transition_table <- function(time_from, time_to, previous, current,
                                      overlap, jaccard, eligible, selected, from_shared, to_shared) {
  positive <- which(overlap > 0, arr.ind = TRUE)
  rows <- positive[, 1L]
  cols <- positive[, 2L]
  n <- length(rows)
  count <- overlap[positive]
  data.frame(time_from = rep(time_from, n), time_to = rep(time_to, n),
              cluster_from = previous$cluster_original[rows], cluster_to = current$cluster_original[cols],
              id_from = previous$cluster_id[rows], id_to = current$cluster_id[cols],
              n_overlap = count, jaccard = jaccard[positive],
              from_share = count / from_shared[rows], to_share = count / to_shared[cols],
              eligible = eligible[positive], selected = selected[positive],
              split_candidate = (rowSums(overlap > 0) > 1L)[rows],
              merge_candidate = (colSums(overlap > 0) > 1L)[cols], row.names = NULL)
}
