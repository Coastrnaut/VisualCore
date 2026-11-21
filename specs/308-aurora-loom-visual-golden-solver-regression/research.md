# Research: R02-G01-08

- **R1 — Solver work bound.** Decision: 3 × (32 × 32 + 256) = 3,840 evaluations per level. Rationale: the solver runs at
  most `maxSweeps` = 32 sweeps of 16 + 16 scores per ribbon, then the full 16 × 16 grid; the existing solver tests bound
  `work` by 768 + 3 × 32 × 32, the same number. Alternatives: a wall-clock limit (rejected: CI runners are slower and the
  owner forbids wall-clock asserts on CI).
- **R2 — Golden baseline form.** Decision: a JSON description of projected positions (1/8 pixel) and 8-bit colours per
  frame, hashed with SHA-256, digests pinned in `golden-frames.json`. Rationale: code-only visuals forbid stored
  pictures made outside the code; a description is exact on every host, so CI catches drift without a GPU; the simulator
  compares renders to the same description with tolerances. The file pins the descriptions as well as the digests:
  positions come from Darwin's sine and cosine, whose last bit may change between macOS releases, so a mismatched digest
  falls back to a comparison within one 1/8-pixel quantum before failing. Alternatives: stored PNG frames (rejected: not code-only and
  GPU-dependent); perceptual image hashes (rejected: tolerance-dependent and opaque).
- **R3 — Golden set.** Decision: levels 1, 21, 41, 61, 81 (one per band) at tiers 0, 1, 2, time 0, plus the hero
  scenario's frame. Rationale: the same five levels the feature-303 render tests use, every tier, and the hero frame the
  catalog shows.
- **R4 — Memory measure.** Decision: `ProcessMemory.footprint()` after each of 12 cycles; bound 16 MB growth over cycle
  1; zero live GPU objects after each close and memory warning. Rationale: footprint is the figure the system judges;
  cycle 1 absorbs one-time caches; a count of the scene's live mesh renderers proves release independently of allocator noise.
- **R5 — CI and the local command.** Decision: a named workflow step running `--filter AuroraLoomRegression`; a Python
  script running the host filter then `xcodebuild_package.py --only-testing` of the two simulator classes with
  its per-test time allowance (it has no whole-run limit), one summary line per part. Rationale: the host job already builds the package; the script reuses the
  time-limited runner (no open-ended waits).
