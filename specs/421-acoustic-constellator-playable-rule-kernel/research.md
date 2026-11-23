# Research: R02-G13-01

- **R1 A whole-number phase clock.** Decision: phases are positions 0 … 11 on a 12-step clock and rates are whole steps
  per tick. Rationale: the law phase_i += ω_i·dt + K Σ sin(phase_j − phase_i)·dt then advances identically on every
  device; 12 steps give 30° resolution, enough to show phases drifting and locking. Alternatives: real phases (floating
  point, device-dependent); 6 steps (too coarse to show a near-lock).
- **R2 Whole-number coupling, clamped.** Decision: s(d) = sign(d) · t(|d|) with t = 0, 1, 2, 2, 2, 1, 0 (2·sin(πd/6)
  rounded), a step ⌊K · P / 4⌋ clamped to −1 … 1. Rationale: the sine's shape in whole numbers; clamping keeps the
  discrete map from overshooting (simulated: 58 % of random constellations lock against 20 % or less unclamped).
  Alternatives: unclamped steps (oscillate); a linear table (pulls hardest at opposite phases, unlike the sine).
- **R3 Exact order parameter.** Decision: n²R² = |Σ e^{iπφ/6}|² = A + B√3 from the pairwise gap table, compared with an
  integer threshold θ by squaring with sign care. Rationale: the Kuramoto order parameter of the catalog's truth metric,
  decided exactly; verified against floating point on 20,000 random phase sets. Alternatives: an arc-width coherence
  (not the order parameter); floating point (device-dependent at the boundary).
- **R4 Drift snaps links.** Decision: after each tick a link snaps when its gap exceeds σ; the listen fails when the
  remaining links no longer join the symbol's stars. Rationale: "graph disconnects under drift" in exact terms; a snap
  lasts for the listen only, so the player's links are unchanged and the next listen starts whole.
- **R5 Decision order.** Decision: missing symbol links first, then per tick: move, snap, disconnection, coherence, hold.
  Rationale: a hold reached on a tick in which the symbol came apart cannot win; the reasons are reported in one fixed
  order.
- **R6 Label by brute force.** Decision: the graph-isomorphism label is the lexicographically smallest upper-triangle
  adjacency string over all orderings of the stars (at most 8! orderings). Rationale: canonical, exact and simple for
  8 stars; it only reports, never decides.
- **R7 Fingerprints as the signed snapshot.** Decision: the play fingerprint (SHA-256 of schema, level fingerprint,
  links, starting phases, actions spent, stage, failure) and records with previous and next fingerprints, as feature 411.
- **R8 Undo from failed.** Decision: undo from failed returns to playing and is recorded; a won level refuses undo.
