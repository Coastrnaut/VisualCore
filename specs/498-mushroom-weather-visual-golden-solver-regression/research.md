# Research: R02-G20-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most `MushroomWeatherSolver.workBound`,
  1,500 arrangements judged), the certified actions and the arrangements judged at the depth one action short, never by
  seconds. Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (the projected floor centre, cap centres, moon centre, first gauge track and first actions bar, the element
  counts, the moonlight, sRGB palette colours), digested with SHA-256 and pinned in the repository. Rationale: no stored
  pictures (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `MushroomWeatherGolden` compiles under DEBUG or VISUALCORE_AUTOMATION
  and is forbidden in the Release binary. Rationale: as `MicroscopicAuroraGolden` (feature 488).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's actions but not the run, at presentation
  time 0 with the authored camera and no preview, shown at the cycle half the cycles run (as the feature-493 frame
  checks), so the placed pods, vent states, moonlight and the spent actions bars show but the level is not won.
  Droplets and motes move by time but are not in the description (their places are excluded from the CPU reference),
  and time 0 fixes them anyway. Rationale: the run is the only action that wins, so the frame is never won.
- **R7 Groups of ten.** Decision: the solver regression runs 10 tests of 10 levels. Rationale: the certifying search
  is bounded at 1,500 arrangements and the 100-level catalog test of feature 492 runs in about 15 s in 20 parallel
  groups, so ten levels per test leave a margin under the 10 s rule.
