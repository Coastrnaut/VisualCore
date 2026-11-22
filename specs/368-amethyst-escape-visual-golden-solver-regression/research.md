# Research: R02-G07-08

- **R1 Work, not time.** Decision: check the re-solve by counted work (`work` at most
  `AmethystEscapeSolver.stateCount(level)`) and the certified actions, smallest move count and depths, never by seconds.
  Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected pearl, exit and wedge-top centres, the move bar's length, sRGB palette colours), digested with
  SHA-256 and pinned in the repository. Rationale: no stored pictures (constitution X, XIII); the simulator compares
  rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum (lengths within 1/1,024) and equal colours and move counts; each pinned digest must equal the digest of its
  pinned description. Rationale: feature 308's lessons — the system trigonometry may differ in the last bit between
  macOS releases, and a hand-edited description must not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: feature 309's lesson — a process-wide footprint in a parallel suite measures
  other tests.
- **R5 Golden only in test builds.** Decision: `AmethystEscapeGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and
  is forbidden in the Release binary. Rationale: as `ChronoConstellatorGolden` (feature 358).
- **R6 Frame moves.** Decision: a golden frame applies the witness's first min(smallest − 1, 3) actions, so the move bar
  and turned shells show but the pearl has not escaped (the win banner would hide the crystal). Rationale: every witness
  has smallest ≥ 1; level 1 (smallest 1 or more) still yields a valid opening frame.
