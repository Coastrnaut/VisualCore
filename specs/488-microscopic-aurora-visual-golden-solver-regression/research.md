# Research: R02-G19-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most
  `MicroscopicAuroraSolver.workBound`, 1,200 well sets judged), the certified placements and the well sets judged at the
  depth one placement short, never by seconds. Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (the projected dish centre, swimmers, wells, sites and first actions bar, the element counts, sRGB palette
  colours), digested with SHA-256 and pinned in the repository. Rationale: no stored pictures
  (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not
  pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `MicroscopicAuroraGolden` compiles under DEBUG or
  VISUALCORE_AUTOMATION and is forbidden in the Release binary. Rationale: as `ApsidesWorkshopGolden` (feature 478).
- **R6 Frame actions.** Decision: a golden frame applies all of the witness's placements but not the play, at presentation
  time 0 with the authored camera, no preview and no freeze, shown at the tick half the ticks swum (as the
  feature-483 frame checks), so the placed wells, their ribbons and the spent actions bars show but the level is not
  won. Rationale: nothing in the dish moves by time, and the play is the only action that wins, so the frame is never
  won.
- **R7 Groups of ten.** Decision: the solver regression runs 10 tests of 10 levels. Rationale: the certifying search
  is bounded at 1,200 well sets and the 100-level catalog test of feature 482 already runs in seconds, so ten levels
  per test leave a wide margin under the 10 s rule.
