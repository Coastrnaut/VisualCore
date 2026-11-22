# Research: R02-G08-08

- **R1 Work, not time.** Decision: check the re-solve by counted work (`work` at most
  `FacetedForgeSolver.workBound`, 20,000 cut evaluations) and the certified cuts and smallest cut count (equal to
  `lowerBound(level)`), never by seconds.
  Rationale: CI runners are about three times slower; a count is stable.
- **R2 Code-only baselines.** Decision: a golden frame is a JSON description computed from the snapshot and scene
  geometry (projected piece centres and the preview plane's centre, the cut bars' spent and total counts, sRGB palette
  colours), digested with
  SHA-256 and pinned in the repository. Rationale: no stored pictures (constitution X, XIII); the simulator compares
  rendered pixels with the same description.
- **R3 Quantum fallback and self-check.** Decision: an unequal digest falls back to positions within one 1/8-pixel
  quantum and equal colours and counts; each pinned digest must equal the digest of its
  pinned description. Rationale: feature 308's lessons — the system trigonometry may differ in the last bit between
  macOS releases, and a hand-edited description must not pass.
- **R4 Isolated memory bound.** Decision: the footprint bound applies only when the memory class runs alone; the full
  suite prints the readings. Rationale: feature 309's lesson — a process-wide footprint in a parallel suite measures
  other tests.
- **R5 Golden only in test builds.** Decision: `FacetedForgeGolden` compiles under DEBUG or VISUALCORE_AUTOMATION and
  is forbidden in the Release binary. Rationale: as `AmethystEscapeGolden` (feature 368).
- **R6 Frame cuts.** Decision: a golden frame applies the witness's first min(smallest − 1, 2) cuts at presentation time
  1 s (fully opened), so pieces and spent cut bars show but the level is not won (a won crystal shows no preview).
  Rationale: every witness has smallest ≥ 1 (two target pieces at least); a level of smallest 1 yields the opening
  frame with the preview.
