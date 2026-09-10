# Cluster-correspondence validation design

The source-checkout script `data-raw/simulate-clusters.R` uses seed 260911. It
requires installed `driftmapR` and `ggplot2`; all other calculations use base or
recommended R functionality. No clustering model is fitted. Labels and expected
predecessor correspondences are supplied as generating truth.

## Scenarios and acceptance criteria

| Scenario | Generating structure | Required outcome |
|---|---|---|
| Label permutation | Three unchanged groups of four entities, relabeled | Preserve every persistent identifier |
| Entity switching | Two groups exchange one of six members each | Preserve dominant correspondence; expose off-diagonal flows |
| Split | One eight-member group becomes groups of six and two | Six-member child inherits; other child receives a fresh identifier |
| Merge | Six-member and two-member groups become one | Larger predecessor continues; other identifier ends |
| Entrants/exits | One continuing group; one exiting group replaced by new entities | Preserve continuing group; do not match disjoint membership |
| Exact tie | Two-by-two table with every count equal to one | Objective two; deterministic documented tie break; ambiguity flagged |
| No shared entities | Two groups in each period with disjoint entity sets | Zero matches and zero objective; current identifiers all fresh |
| Global assignment conflict | Overlap matrix with rows `(5, 4)` and `(4, 0)` | Select the two edges of four for objective eight, rather than greedy objective five |
| Five-period panel | 96 entities observed per period; exchanges, a 20/12 split, subsequent merge, cluster turnover | Preserve independently declared parent correspondences at all four boundaries |

The five-period panel contains 136 unique entity identifiers. It has 96
observations at each of five periods. Eight entities enter and eight exit at
the second and third boundaries; 24 enter and 24 exit at the last boundary.
At the first boundary, four entities move from each of the first two groups to
the other. Coordinates exist to satisfy the coordinate-object contract and do
not affect membership matching.

## Independent reference calculations

Expected predecessor labels are declared directly from each generating design.
The script joins observed entity membership independently of the package's
assignment output and constructs an overlap table with all observed clusters as
dimensions, including all-zero rows or columns. It then exhaustively enumerates
positive-edge partial one-to-one assignments. An unmatched choice is represented
once per row. Zero-weight edges are never allowed. This yields both the maximum
total overlap and the number of optimal assignments.

The exhaustive reference is deliberately restricted to small cluster counts.
It is a validation oracle, not the intended production algorithm. It consumes
neither the package solver nor the package's selected edges.

Acceptance gates require:

1. Every independently specified predecessor correspondence agrees with the
   persistent identifiers returned by the package.
2. No persistent identifier links a zero-overlap pair.
3. The overlap implied by returned identifiers equals the exhaustive maximum.
4. The reported objective equals the same maximum.
5. The period ambiguity flag agrees with whether more than one optimal partial
   assignment exists.

All comparisons concern integer counts or categorical identifiers and are
exact. Floating-point tolerance is not needed for these gates.

## Outputs

Each scenario exports the supplied data, expected correspondences, memberships,
cluster registry, selected assignments, complete positive flows, period
diagnostics, model object, and all diagnostics. Exact matrices are retained in
RDS form; individual matrices are also exported as long CSV tables. Root-level
files include scenario metrics, row-level correspondence checks, independently
constructed overlap cells, all models, session information, and two figures in
PNG and vector PDF formats.

The heatmaps display overlap counts and outline selected edges. One figure
shows the panel's four adjacent boundaries; the other shows the eight
controlled fixtures. Zero-overlap cells remain visible, while their counts are
suppressed to reduce clutter.

## Interpretation limits

Matching identities is deterministic bookkeeping conditional on the supplied
labels, observed common cohort, objective, and thresholds. It does not validate
the clustering procedure or prove substantive cluster identity. The term
`new` means unmatched by these rules, not an inferred population birth.

Split/merge candidate flags describe multiple positive overlap links. The
switching fixture generates both kinds of flag even though neither a split nor
a merge generated the data. The selected one-to-one assignment omits secondary
flows by design; the full transition table must remain available.

A zero assignment margin describes ambiguity of the objective, not statistical
uncertainty. Counts and checks in these deterministic fixtures are not estimates
of error rates in a population. Bootstrap stability, coverage, inferential
movement detection, and probabilistic split/merge inference are not evaluated.
