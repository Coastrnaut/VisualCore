# Research: R02-G16-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most `StarlitCartoucheSolver.workBound`,
  300,000 legs tried) and the certified legs and the states reached one leg short, never by seconds. Rationale: CI
  runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected star centres, the ship, the beacon, the drawn strokes' midpoints and the first actions bar, the
  element counts, sRGB palette colours), digested with SHA-256 and pinned in the repository. Rationale: no stored
  pictures (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `StarlitCartoucheGolden` compiles under DEBUG or VISUALCORE_AUTOMATION
  and is forbidden in the Release binary. Rationale: as `VoxelOrigamiGolden` (feature 448).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's legs but the last at presentation time 0
  with the authored camera and the default choice, so the symbol is part drawn and spent actions bars show but the
  level is not won. A one-leg witness therefore applies no leg. Rationale: the stars' positions follow the beat, not
  the presentation time, at time 0 the firmament is at its start, and the last leg is the one that wins, so the frame
  is never won.
- **R7 Groups of ten.** Decision: the solver regression runs 10 tests of 10 levels. Rationale: certifying a level takes
  2–6 ms in a debug build (feature 457's persistence agent measured it) and the 100-level catalog test of feature 452
  runs in about a second, so ten levels per test leave a wide margin under the 10 s rule.
