# Research: R02-G06-08

- **R1 Work, not time.** Decision: check the re-solve by counted work (`work` at most tick limit + the sum of the window
  ticks) and the certified phase-change set, lower bound, window, windows and blocked count, never by seconds.
  Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected star, target and loop-cell centres, the tick mark's length, sRGB palette colours), digested with
  SHA-256 and pinned in the repository. Rationale: no stored pictures (constitution X, XIII); the simulator compares
  rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum (lengths within 1/1,024 cell) and equal colours and ticks; each pinned digest must equal the digest of its
  pinned description. Rationale: feature 308's lessons — the system trigonometry may differ in the last bit between macOS
  releases, and a hand-edited description must not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: feature 309's lesson — a process-wide footprint in a parallel suite measures
  other tests.
- **R5 Golden only in test builds.** Decision: `ChronoConstellatorGolden` compiles under DEBUG or VISUALCORE_AUTOMATION
  and is forbidden in the Release binary. Rationale: as `AuroraLoomGolden` (feature 309) and `ColorfallCanyonsGolden`
  (feature 348).
- **R6 Frame tick.** Decision: a golden frame applies the witness's phase changes and then steps min(win tick, 6) ticks
  (the witness's step actions cut there), so trails show but the win banner does not hide stars. Rationale: the
  history holds 24 ticks; 6 shows ribbons at every tier, and every witness wins on tick ≥ 1.
