# Research: R02-G09-02

- **R1 Targets built from blooms.** Decision: each candidate's target is the exact mask of blooms the generator plants
  itself. Rationale: every level is winnable by construction before the solver certifies its smallest move count;
  silhouettes stay botanical. Alternatives: drawn target shapes (often unreachable, long searches).
- **R2 A lower bound that a found solution meets.** Decision: L = min over elevations of [sun move] + ⌈needed / cover⌉,
  with needed the least shared count meeting p/q against the target and cover the best single plant's shared cells
  without leaking beyond the allowance; the solver looks for a sequence of exactly L moves. Rationale: a solution of
  length L proves L is the smallest, as in feature 372; exhaustive proofs over all shorter arrangements would be
  unbounded. Alternatives: breadth-first search over all placements (too large on 32 × 24 beds).
- **R3 Shape-score ordering and coverage pruning.** Decision: candidates ordered by cells in the target minus cells
  outside, pruned when the remaining plants cannot reach the need. Rationale: the catalog's "grid-snapped candidate
  placements with stencil overlap and shape-distance scoring"; deterministic and counted.
- **R4 Bands by fit, not speed.** Decision: higher bands have larger beds, more blooms, all sizes and elevations, a
  tighter required match, a smaller leak allowance and a decoy kind. Rationale: harder means a finer fit, never faster
  reactions.
- **R5 Witness files as in feature 372.** Decision: sorted-key JSON with per-action mask digests, fingerprints, the
  lower-bound argument and the near miss; written only with the explicit switch.
