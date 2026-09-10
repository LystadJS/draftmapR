# Cluster correspondence contract

Version 0.0.2.9000; 2026-09-10.

## What is estimated

`match_clusters()` links supplied hard cluster labels in immediately adjacent
periods. It estimates a bookkeeping correspondence supported by observed shared
membership. It does not fit clusters, identify a latent evolving partition, or
estimate statistical uncertainty. Coordinates need not be aligned because
neither the objective nor the diagnostics use their values.

## Cohort and objective

For periods r and t, form the common-entity cohort whose cluster labels are
assigned in both periods. A missing label, numeric NaN, or an explicitly declared
noise label is unassigned; it receives no stable ID. A wholly missing logical
column is accepted as unassigned. Other nonmissing logical labels are rejected.
Zero and minus one are ordinary cluster labels unless listed in `noise`.

Let O[a,b] count members in the eligible cohort who belong to previous cluster a
and current cluster b. Cluster row/column sets include all assigned clusters
observed in the periods, even if they contain no shared members. Let n[a] and
n[b] be row/column sums of O. Eligible links satisfy:

```
O[a,b] >= min_overlap (default 1)
O[a,b] / (n[a] + n[b] - O[a,b]) >= min_jaccard (default 0)
```

Thresholding precedes optimization. Jaccard uses the jointly labeled shared
cohort, not total period cluster sizes; total and shared sizes are both reported
to make attrition visible. Ratios for matches and positive flows always have
positive denominators. Unmatched assignment ratios are missing.

Maximize `sum(O[a,b] * M[a,b])`, with binary M and at most one selected edge per
row/column, restricting positive choices to eligible links. Leaving a cluster
unmatched has zero objective value. The objective maximizes retained membership
count, not matched cluster count or total Jaccard. A high Jaccard based on one
shared member is not strong evidence; `min_overlap` can impose a larger count.

## Solver and exact ties

The established [clue::solve_LSAP](https://cran.r-project.org/web/packages/clue/refman/clue.html#solve_LSAP)
solves the assignment optimization. Its documented interface supports nonnegative
rectangular assignment and maximization. The package imports clue (and records
its runtime version); no solver code was copied into driftmapR.

The implementation uses a square matrix padded with zeros. Every partial
matching can be completed with zero-score real/dummy pairs, so the padded
maximum equals the positive partial-matching maximum. Zero-score pairs are
discarded. Independent eligible-overlap components are solved separately.

Canonical input order is radix-sorted original character labels in the first
period; later rows follow previous stable-ID order and columns follow current
original-label radix order. Factor level order and input row order do not affect
the result. Numeric labels sort by their character representation, not numeric
value; precision-losing label conversions are rejected.

Among equal primary optima, select the lexicographically smallest row mapping,
with unmatched ranked after every real column. Feasibility checks compare exact
integer objective values and reuse the optimal residual solution. They do not
add small floating penalties or rely on clue's undocumented tie selection.
An internal guard restricts the total integer score to 2^53-1 for exact double
integer arithmetic. Ordinary supported entity counts are far below this limit.

For each selected link, `edge_margin` is the original maximum objective minus
the best objective after forbidding that link in the original problem. Margins
are not conditioned on earlier canonical tie decisions. Zero means another
global optimum excludes that link. Unmatched rows have missing margin/ambiguity;
the pair-level ambiguity flag records any nonunique selected real link.
Disabling tie diagnostics leaves margins and ambiguity fields missing while
retaining exact deterministic matching. Diagnostic margins are not probabilities,
bootstrap stability, statistical significance, or confidence intervals.

## Identities and unmatched cases

Initial assigned clusters receive `C0001`, `C0002`, and so on. A selected link
continues the predecessor's ID. Other current clusters receive monotonically
allocated fresh IDs; IDs never recycle within a run. Only adjacent periods are
linked. A previously used raw label does not resurrect an earlier identity when
its intervening membership is absent or unassigned.

The assignment table has selected links plus an unmatched row for every
uncontinued previous cluster and every new current cluster. Reasons distinguish:

| Reason | Meaning |
|---|---|
| `max_overlap` | Selected by the constrained maximum-count objective. |
| `no_jointly_labeled_members` | No usable shared membership supports correspondence. |
| `below_threshold` | Positive shared flows exist, but all fail the eligibility thresholds. |
| `assignment_competition` | Eligible candidates exist, but one-to-one optimization leaves this cluster unmatched. |

These are observational correspondence statuses. New/unmatched IDs are not
proof of substantive cluster birth/death. Selective loss of members can alter
the preferred matching even when an underlying cluster persists.

## Split and merge candidates

All positive flows are returned, including unselected/ineligible links. A
previous row with multiple positive destinations receives `split_candidate`;
a current column with multiple positive sources receives `merge_candidate`.
Flags deliberately describe the observed overlap topology. A single switching
entity may create either flag. They do not identify a genuine latent split/merge.

One-to-one assignment preserves at most one predecessor/descendant identity
through these patterns. The remaining descendants get new IDs, and uncontinued
ancestors get unmatched diagnostics. No ancestry graph or probabilistic
split/merge model is implemented.

## Object integration and validation boundary

The original coordinate-table label column and geometric results are unchanged.
`object$clusters` holds per-observation original character labels, stable IDs,
and statuses. `object$diagnostics$cluster_matching` stores registry, assignments,
flows, period summaries, and count/eligible-score matrix lists. Recomputing
matching replaces these results and invalidates stored bootstrap output.
Re-aligning does not invalidate this membership-only correspondence.

Independent tiny-matrix enumeration tests verify global optimality, exact
canonical choices, and forbidden-edge margins. Public synthetic tests cover
label permutations, switching, splits/merges as observed flow patterns, entry/
exit, complete turnover, missing/noise labels, thresholds, ties, and schedules.
These are software correctness checks. They do not establish statistical
calibration or generality across applications.
