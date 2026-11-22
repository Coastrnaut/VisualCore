# Research: R02-G08-01

- **R1 Exact fractions instead of floating point.** Decision: a reduced fraction of two 64-bit integers with checked
  arithmetic; an overflow refuses the action. Rationale: "exact-oriented face classification" and "volume from signed
  tetrahedra" decided alike on every device; the bounds keep values small. Alternatives: doubles with tolerances (a face
  or a sliver judged differently near the boundary), an arbitrary-precision integer type (more code, not needed).
- **R2 A fixed set of 13 integer directions.** Decision: the axes, face diagonals and body diagonals with components in
  {−1, 0, 1}, integer depths. Rationale: the solver of R02-G08-02 can enumerate every cut; every corner is rational with
  a small denominator; directions are nameable in words. Alternatives: free normals (unsearchable, irrational corners).
- **R3 Pieces as half-space lists.** Decision: a piece is the set of its bounding planes; corners, faces and edges are
  derived. Rationale: "convex half-space polytope clipping" is exactly adding one half-space; no mesh surgery to get
  wrong. Alternatives: boundary meshes split by clipping (more state, harder to prove closed).
- **R4 Degenerate cuts refused, slivers fail.** Decision: a plane that leaves no corner strictly on one side is refused
  and spends nothing; a new piece below the sliver limit fails the level. Rationale: "reject degenerate tiny faces"
  without a tolerance, and an honest, named failure for "disallowed slivers".
- **R5 Sliver, then win, then budget.** Decision: judged after each cut in that order; nothing before the first cut.
  Rationale: a sliver is always a failure; a win on the last cut counts.
- **R6 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint, the
  pieces in canonical order, cuts, stage, failure) and records with previous and next fingerprints, as feature 361.
