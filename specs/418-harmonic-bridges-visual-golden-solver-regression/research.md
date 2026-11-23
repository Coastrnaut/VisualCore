# Research: R02-G12-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most `HarmonicBridgesSolver.workBound`,
  400,000 choices) and the certified tunings and smaller-choices count, never by seconds. Rationale: CI runners are about
  three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected island-top, string-midpoint, membrane, pip and first-gauge-bar points, the element counts, sRGB palette
  colours), digested with SHA-256 and pinned in the repository. Rationale: no stored pictures (constitution X, XIII);
  the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  feature 308's lessons — the system trigonometry may differ in the last bit between macOS releases, and a hand-edited
  description must not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: feature 309's lesson — a process-wide footprint in a parallel suite measures
  other tests.
- **R5 Golden only in test builds.** Decision: `HarmonicBridgesGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and
  is forbidden in the Release binary. Rationale: as `EchoCartographerGolden` (feature 408).
- **R6 Frame actions.** Decision: a golden frame applies the witness's tunings (not its test) at presentation time 0,
  so bridges, filled marks, pips and spent gauge bars show but the level is not won (a won level lifts its bridges).
  Rationale: positions do not depend on time (the string wave and shells are shader work); every certified plan has at
  least one tuning, and the test comes last, so the frame is never won.
