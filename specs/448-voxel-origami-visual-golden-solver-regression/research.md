# Research: R02-G15-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most `VoxelOrigamiSolver.workBound`,
  300,000 turns tried) and the certified turns and the states reached one turn short, never by seconds. Rationale: CI
  runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected cube centres, hinge mark centres, target cell centres, the first covered pip and the first moves
  bar, the element counts, sRGB palette colours), digested with SHA-256 and pinned in the repository. Rationale: no
  stored pictures (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `VoxelOrigamiGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and is
  forbidden in the Release binary. Rationale: as `MoonlitMechanismGolden` (feature 438).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's turns but the last at presentation time 0
  with the authored camera, so the fold is part done and spent moves bars show but the level is not won (a won level
  lifts the cubes). A one-turn witness therefore applies no turn. Rationale: the programs have no time input, so
  positions do not depend on time; the last turn is the one that wins, so the frame is never won.
- **R7 Groups of five.** Decision: the solver regression runs 20 tests of 5 levels. Rationale: feature 445 measured
  about 1.3 s for a six-turn band-5 search in a debug build; ten such levels per test would pass the 10 s rule.
