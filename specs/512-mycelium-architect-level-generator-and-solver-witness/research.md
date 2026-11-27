# Research: R02-G22-02

- **R1 Sites bound the move space.** Decision: optional placement sites (2 … 12 empty cells); with them only sites take
  nutrients and blockers. Rationale: "quantize … to legal values"; a 16 × 16 board would offer 2 · 256 placements per
  move, sites offer at most 24. Alternatives: placements anywhere (the minimality proof would be out of reach).
- **R2 Winning plan first.** Decision: draw the winning plan, grow it, and take the terminals from the grown network
  (the latest-grown cells) with budget and limit from its weight plus the band's slack. Rationale: every candidate is
  solvable by construction; the solver then proves the plan minimal or the candidate is skipped.
- **R3 Breadth-first by action count.** Decision: the solver walks depths 0 … p; within a depth it expands arrangements
  in ascending loss (ties by discovery) and the puzzle contract's move order; reachability skips repeats; the first win
  ends the search. Rationale: "graph shortest path" over the graph of arrangements; the loss only orders, so the first
  win at depth d is minimal and the depths below form the proof. Alternatives: A* with an admissible heuristic (no
  simple admissible bound exists for growth outcomes).
- **R4 Measurements.** Decision: the first implementation task measures the real catalog (accepted candidate index per
  band, work per level and catalog, witness lengths, slowest level and group of five) and records it here; adjustment
  ladder if an entry reaches `generation(n)` or a group of five exceeds 6 s: first the band's limit slack, then its
  budget slack, then its rock ‰ and toxin ‰, never p or the manifest's budgets; the candidate bound may be raised (candidates are cheap). Measured 2026-11-27
  (debug host build, the drafted pipeline): with the clarified profiles 76 of 100 entries generated within 64 candidates
  (skips: networks under 5 cells, toxic or starved growth, minimal plans shorter than p); with every band given at least
  one fixed nutrient, κ ≤ 2, ο ≤ 1, and bands 4 and 5 at 100 ‰ rock and 40 ‰ toxin, 90 generated; with the candidate
  bound at 1 024 all 100 generate: largest accepted candidate index 99, 71, 98, 349, 146 by band; witness lengths exactly
  1, 2, 3, 3, 4; largest work per level 15, 95, 488, 408, 2 219; 28 600 arrangements judged for the catalog; slowest
  level 100 (0.9 s); slowest group of five 96 … 100 (2.2 s); whole catalog 8.9 s. These values are written back into
  spec clarification Q2, data-model.md and plan.md.
- **R5 Loss.** Decision: 16 × Chebyshev distance from each unreached terminal to the nearest grown cell + overweight
  excess + 1 024 for toxic or starved. Rationale: whole numbers; zero exactly when won; nearer networks first.
- **R6 Witness layout.** Decision: as feature 502 (schema 1, sorted keys, per-action 16-hex state digests, play
  fingerprints, terminal report, counterexample with nearest miss, difficulty, skipped candidates); written only with
  `MYCELIUM_ARCHITECT_WRITE_WITNESSES=1`, compared byte for byte otherwise.
- **R7 Catalog identity and split.** Decision: `PuzzleCatalog<MyceliumArchitectPuzzle>.digest(id: "mycelium-architect",
  identities:)` pinned; 20 certification groups of 5; levels cached per process.
- **R8 Source placement.** Decision: new sources in `Core/Content/` so feature 511's scans of `Core/` keep their lists.
