# Research: R02-G17-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most
  `CelestialEclipseLabSolver.workBound`, 60,000 settings judged) and the certified phase changes and the settings judged
  one change short, never by seconds. Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected body centres, shadow-lens centres, halos, the playhead and the first actions bar, the element
  counts, sRGB palette colours), digested with SHA-256 and pinned in the repository. Rationale: no stored pictures
  (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `CelestialEclipseLabGolden` compiles under DEBUG or
  VISUALCORE_AUTOMATION and is forbidden in the Release binary. Rationale: as `StarlitCartoucheGolden` (feature 458).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's phase changes but not the run, at
  presentation time 0 with the authored camera and the default chosen body, shown at the first tick of the predicted
  timeline with an eclipse under way (tick 0 if none), so lenses, halos and spent actions bars show but the level is
  not won. Rationale: the halo pulse is 1 at time 0, and the run is the only action that wins, so the frame is never
  won.
- **R7 Groups of ten.** Decision: the solver regression runs 10 tests of 10 levels. Rationale: the certifying search
  is bounded at 60,000 settings and the 100-level catalog test of feature 462 already runs in seconds, so ten levels
  per test leave a wide margin under the 10 s rule.
