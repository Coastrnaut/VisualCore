# Research: R02-F19

- **R1 Bracketed stochastic L-systems.** Decision: single-character symbols, context-free rules with weighted
  successors, one seeded draw per weighted symbol occurrence in reading order (Prusinkiewicz and Lindenmayer, *The
  Algorithmic Beauty of Plants*, 1990). Rationale: compact, well known, deterministic once the draw order is fixed.
  Alternatives: parametric L-systems with expressions (a parser and evaluator for little gain here).
- **R2 Turtle frame.** Decision: heading, left and up vectors rotated by Rodrigues' formula and re-orthonormalised
  (Gram–Schmidt on heading then left) after every turn, so error never accumulates.
- **R3 Shapes.** Decision: closed-form parametric surfaces built with `MeshBuilder`: a curled petal spine with a sine
  half-width, an elliptic cap of revolution with a rim and underside, a tapered bent tube. Rationale: exact dimensions
  for tests, valid meshes, no assets.
- **R4 Reuse for branches.** Decision: each branch is `Mesh.tube` over two `CurveSamples` points, the whole plant
  joined with `Mesh.merged`. Rationale: the existing, tested tube and merge.
- **R5 Dart throwing.** Decision: seeded candidates accepted against a background grid of cell d/√2 (at most one point per
  cell), capped at 30 · maxCount draws. Rationale: deterministic, exactly enforces the spacing, bounded work;
  Bridson's active list gives denser packing but its order depends on list handling.
