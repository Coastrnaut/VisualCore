# Research: R02-G14-08

- **R1 Work, not time.** Decision: check the re-plan by counted work (`work` at most `MoonlitMechanismSolver.workBound`,
  400,000 runs) and the certified turns, lamp steps, re-seats and smaller-vectors count, never by seconds. Rationale: CI
  runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected cast-cell centres, gear centres and rim check points, key-frame card centres, the first alignment
  pip, the lamp centre and the first moves bar, the element counts, sRGB palette colours), digested with SHA-256 and
  pinned in the repository. Rationale: no stored pictures (constitution X, XIII); the simulator compares rendered pixels
  with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its pinned description. Rationale:
  the system trigonometry may differ in the last bit between macOS releases, and a hand-edited description must not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: a process-wide footprint in a parallel suite measures other tests.
- **R5 Golden only in test builds.** Decision: `MoonlitMechanismGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and
  is forbidden in the Release binary. Rationale: as `AcousticConstellatorGolden` (feature 428).
- **R6 Frame actions.** Decision: a golden frame applies the witness's turns, re-seats and lamp steps (not its run) at
  presentation time 0 with key frame 0 shown, so the set-up's shadows and spent moves bars show but the level is not won
  (a won level lifts the paper). Rationale: the programs have no time input, so positions do not depend on time; every
  certified plan has at least one action before its run, so the frame is never won.
