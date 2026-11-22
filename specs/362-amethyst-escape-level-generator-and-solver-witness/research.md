# Research: R02-G07-02

- **R1 Breadth-first search proves the smallest move count.** Decision: search crystal states level by level in the
  rules' move order; the first escape is at the smallest depth (clarification Q2). Rationale: "breadth-first search over
  discretized shell angles and pearl pocket indices" is the archived solver, and every state at a smaller depth having
  been expanded is itself the proof; the state count bounds the work. Alternatives: iterative deepening (re-expands
  states), A* with a heuristic (needs an admissibility proof).
- **R2 Packed integer states.** Decision: encode offsets and the pearl as one integer and keep visited depths in an
  array. Rationale: up to 400,000 states per proof in a debug build stays fast without hashing; the encoding is exact.
- **R3 Band profiles and tight ranges.** Decision: sectors × shells 6 × 2, 6 × 3, 8 × 3, 8 × 4, 10 × 4 and smallest
  move ranges 3 … 4, 5 … 6, 7 … 8, 9 … 10, 11 … 12, each within the manifest budget. Rationale: a Python prototype
  certified all 80 manifest seeds with at most 33 candidates; ranges two wide keep the standard progression rule (drop
  at most 1, jump at most 3) in manifest order. Alternatives: budget-relative ranges (prototype failed band 5).
- **R4 Advances alone must not escape.** Decision: a candidate whose pearl escapes when only advanced is refused.
  Rationale: the puzzle needs the player to turn a shell (User Story 1, scenario 2).
- **R5 Witness files as certificates.** Decision: as feature 352 — the level's stored form, the actions, per-move state
  digests, play fingerprints, the depth counts as the proof, the unedited counterexample and the near miss, written only
  on opt-in and compared byte for byte otherwise. Rationale: honest, checkable certificates without key material.
