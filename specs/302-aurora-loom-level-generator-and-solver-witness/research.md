# Research: R02-G01-02

- **R1 Separable solve.** Decision: solve each ribbon on its own. Rationale: the win needs every residual of every ribbon
  within the tolerance, and the ribbons do not interact (a residual depends only on its own ribbon's steps), so the set of
  winning settings is the product of the three ribbons' winning sets; the shortest solution is the sum of each ribbon's
  fewest changes (0, 1 or 2, since one move changes one control). Alternatives: R02-F23's BFS over 16⁶ states (exact but
  16.7 M states; the per-ribbon grid of 256 is the same proof at 1/20,000 of the cost).
- **R2 Descent then grid.** Decision: per ribbon, coordinate descent alternating wave and phase (each step picks the value
  of that control that minimises the ribbon's largest |residual|, ties to the lower value, at most 32 sweeps, stopping when a
  sweep changes nothing), then always the exact grid over 256 settings. Rationale: the source asks for "bounded
  phase-gradient coordinate descent with exact grid search fallback"; running the grid always makes optimality a proof, and
  the descent result is cross-checked against it (SC-R02G0102-002). The method is `descent` when every ribbon's descent
  endpoint is a winning setting at the optimal number of changes, `grid` otherwise.
- **R3 Ribbons turn with Ω.** Decision: generated ribbons have ω = Ω. Rationale: with ω ≠ Ω the residual drifts by (ω − Ω)
  per tick and never stays within the tolerance for two periods, so such a ribbon could never be solved by steps.
- **R4 Band profiles.** Decision: Ω (16, 32, 64, 128, 256), tolerance (160, 96, 64, 40, 24) and shortest range (1–2, 2–3,
  3–4, 4–5, 5–6) for bands 1 … 5. Rationale: harder bands ask for more moves and finer accuracy (a narrower tolerance) but
  never smaller gestures (the step sizes stay 16 and 256 units); every tolerance is below 256, so a phase step always breaks
  a win (counterexample, R6). Shortest ≤ 6 < every move budget (≥ 8).
- **R5 Candidate draw.** Decision: candidate k draws the winning (wave, phase), four distinct gate positions 1 … 15, per-gate
  offsets in −⌊tol/2⌋ … ⌊tol/2⌋ (targets = winning phase at the gate + offset), then a scramble count c uniformly in the
  band's shortest range and c distinct controls of six, each set to a different random step. Accepted when the level is
  valid, the solver's shortest lies in the band range and does not exceed the budget; otherwise k + 1, at most 64.
  Rationale: deterministic, independent per level, and the skipped count is recorded.
- **R6 Counterexample.** Decision: the witness's end setting with ribbon 0's phase moved by +1 step (mod 16); its worst
  mismatch names ribbon, gate, tick and residual and exceeds the tolerance. Rationale: one phase step moves every residual by
  256 > every tolerance, so this near-miss always loses, satisfying "a counterexample that violates four gate phase
  congruence".
- **R7 Witness files.** Decision: JSON, sorted keys, pretty-printed with a trailing newline, schema 1; produced from the
  generator output and compared byte for byte in tests; written only with `AURORA_LOOM_WRITE_WITNESSES=1`; located from
  the test file via `#filePath`. Rationale: the archived manifest names the artifact paths; byte comparison catches any
  drift in rules or seeds ("refuse … fake expected hashes").
- **R8 Difficulty and progression.** Decision: `AuroraLoomDifficulty` (shortest, work, winning settings, tolerance, Ω) with
  `puzzleDifficulty` = `PuzzleDifficulty(shortest:, explored: work)`; the catalog keeps `ProgressionRule.standard` and band
  means of shortest and work do not fall. Rationale: reuses R02-F24's measures. Risk: work depends on descent sweeps; if a
  band mean falls, the generator's acceptance is tightened (recorded as a spec amendment) rather than the check weakened.
