# Research: R02-G04-08

- **R1 Work, not time.** Decision: bound the re-solve by counted work (probe sets tried ≤ 4,657, the depth-2 search space of 96 bearings), never
  by seconds. Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected positions, sRGB colours), digested with SHA-256 and pinned in the repository. Rationale: no stored
  pictures (constitution X, XIII); the simulator compares rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours; each pinned digest must equal the digest of its pinned description. Rationale: feature
  308's lessons — the system sine may differ in the last bit between macOS releases, and a hand-edited description must
  not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: feature 309's lesson — a process-wide footprint in a parallel suite measures
  other tests.
- **R5 Golden only in test builds.** Decision: `HueCompassGolden` compiles under DEBUG or VISUALCORE_AUTOMATION
  and is forbidden in the Release binary. Rationale: as `AuroraLoomGolden` (feature 309).
