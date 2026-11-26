# Research: R02-G18-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most
  `ApsidesWorkshopSolver.workBound`, 16,000 orbits judged) and the certified tunings and the orbits judged one
  tuning short, never by seconds. Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (the projected star, orbiter, periapsis and apoapsis markers, planets and first actions bar, the element
  counts, sRGB palette colours), digested with SHA-256 and pinned in the repository. Rationale: no stored pictures
  (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `ApsidesWorkshopGolden` compiles under DEBUG or
  VISUALCORE_AUTOMATION and is forbidden in the Release binary. Rationale: as `ApsidesWorkshopGolden` (feature 468).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's tunings but not the play, at presentation
  time 0 with the authored camera and no preview, shown at tick T / 2 (as the feature-473 frame checks), so the tuned
  orbit, its wedges and spent actions bars show but the level is not won. Rationale: the star pulse is 1 at time 0,
  and the play is the only action that wins, so the frame is never won.
- **R7 Groups of ten.** Decision: the solver regression runs 10 tests of 10 levels. Rationale: the certifying search
  is bounded at 16,000 orbits and the 100-level catalog test of feature 472 already runs in seconds, so ten levels
  per test leave a wide margin under the 10 s rule.
