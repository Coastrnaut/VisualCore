# Tasks: R02-G16-08 — Starlit Cartouche: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md). Gate R02-G16-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G16-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_458;
tests stay short (< 10 s each); no wall-clock assertion. No agent runs host tests while a baseline or chain runs.

## Phase 1: Setup

- [X] T-R02G1608-001 Baselines after R02-G16-07 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (mesh about 2.5 s vs 0.70 s, the process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457: `--filter VoxelOrigami`,
  `--filter 'MoonlitMechanism|AcousticConstellator|HarmonicBridges'`, then chunk 3 in three `--filter` parts:
  `'AuroraLoom|LissajousLabyrinth|HueCompass|WaveKnotKeeper|ChronoConstellator|AmethystEscape'`,
  `'FacetedForge|NocturneGarden|BackwardsAurora'`, `'EchoCartographer|ColorfallCanyons|StarlitCartouche'`)

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G1608-002 [P] [US1] Create — Verified 2026-11-25: 2026-11-25 host exit 0 (100 levels in 10 groups, 13 alteration kinds named; agent A's file retested by the lead)
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRegressionSolverTests.swift` (agent A: for
  every level in ten groups of 10, "the generated level equals its witness's level (fingerprint); the witness's legs
  replay on a fresh play to a win on exactly the last leg and not before, within the budget, with its per-action
  fingerprints (after begin, after the tutorial on a tutorial level, then one per leg) and digests; plan returns exactly
  the witness's legs with statesByDepth[size − 1] equal to the counterexample's states at depth size − 1, with work ≤
  workBound"; thirteen named alterations of clarification Q2 (a star's orbit, a star's window, a corridor's ends, a
  hazard, the range, the beacon, the deadline, a symbol stroke, the budget; a plan leg; a witness action, a per-action
  fingerprint or digest; the counterexample's state count) each fail naming the level and the part); `--name host --
  swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartoucheRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G1608-003 [US2] Create `Packages/ExperiencesRound02/StarlitCartouche/Core/StarlitCartoucheGolden.swift` — Verified 2026-11-25: 2026-11-25 StarlitCartoucheGolden and golden-frames.json (16 frames) generated with STARLIT_CARTOUCHE_WRITE_GOLDEN=1; RELEASE_FORBIDDEN gains StarlitCartoucheGolden; host-2 exit 0
  (DEBUG or VISUALCORE_AUTOMATION; "16 frames: levels 1, 21, 41, 61, 81 at tiers 0 … 2 at presentation time 0 after all
  of the witness's legs but the last (a one-leg witness applies none) with the default choice, plus the hero frame of
  `scenario-manifest.json` at tier 0; at 1,152 × 768 with the authored camera: every star centre at the current beat
  (index order), the ship, the beacon, every drawn stroke's midpoint and the first actions bar, positions rounded to 1/8
  px and a point behind the eye null; the counts of stars, corridors, hazards, active hazards, symbol strokes, drawn
  strokes and lit and total actions bars; the 22 palette colours 8-bit sRGB; JSON with sorted keys; SHA-256"; manifest;
  compare with the one-quantum fallback and the pinned-digest self-check), generate
  `Packages/ExperiencesRound02/StarlitCartouche/golden-frames.json` (schema 1) with `STARLIT_CARTOUCHE_WRITE_GOLDEN=1`,
  and add `StarlitCartoucheGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G1608-004 [P] [US2] Create — Verified 2026-11-25: 2026-11-25 host-2 exit 0 (12 golden tests; one over-strict drawn-strokes check relaxed by the lead: level 41 draws its three strokes before the beacon leg)
  `Packages/ExperiencesRound02/StarlitCartouche/CoreTests/StarlitCartoucheRegressionGoldenTests.swift` (agent B: every
  frame's recomputed description matches its pinned one; each pinned digest equals the digest of its pinned
  description; a moved position beyond a quantum, a changed colour or count, a missing frame, an unknown frame, schema
  ≠ 1 and a hand-edited description all fail naming the frame; the file is rewritten only with the switch); `--name
  host-2 -- swift test --package-path Packages/ExperiencesRound02 --filter StarlitCartoucheRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G1608-005 [US2] [US3] Create — Verified 2026-11-25: 2026-11-25 sim-27 exit 0 (62 tests incl. the golden-frame and memory classes by agent C, passing unedited; 12 cycles 29.91-33.22 MB)
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/StarlitCartouche/ExperienceTests/StarlitCartoucheRegressionMemoryTests.swift` (agent C:
  the 16 frames rendered and checked against their descriptions with the feature-453 tolerances (a star's centre 0.25
  brighter than the backdrop in luminance, the ship's centre with blue above red by 0.08, the first actions bar 0.1
  from the backdrop, the median of every 9 × 9 backdrop patch within 0.06 of the firmament gradient, each point at
  least 6 px from what is drawn after it; points on screen where the description puts
  them); 12 open-draw-warn-close cycles (prepare a level, 3 frames at tier 0, a memory warning, 1 frame, teardown) with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_STARLIT_CARTOUCHE_MEMORY_ISOLATED=1`, readings printed otherwise; the chart scene's `liveObjectCount` 0
  after each close and warning and rebuilt by the next frame; an unavailable footprint fails with a named reason);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing StarlitCartoucheExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [ ] T-R02G1608-006 [P] [US4] Create `scripts/starlit_cartouche_regression.py` and its test in
  `scripts/test_scripts.py` (agent D: host filter `StarlitCartoucheRegression`, then the simulator classes through
  `xcodebuild_package.py --only-testing` with the isolation variable, one summary line per part with pass or fail and
  the first failing name, a non-zero exit on any failure), and add the named step "Starlit Cartouche regression (host)"
  to the `round02-host-tests` job of `.github/workflows/ci.yml`; `--name regression -- python3
  scripts/starlit_cartouche_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1608-007 Docs: `docs/architecture/starlit-cartouche.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (the chunks of T-001)
- [ ] T-R02G1608-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1608-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1608-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1608-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1608-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden
  levels. Not run before the lock.
- [ ] T-R02G1608-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 011, 013. 012 is a {device}
task outside this campaign. Agent A may start in an isolated copy before 001 (a new test file), but runs no host tests
while the lead's baselines or chain run. Shared files (golden source, release list, workflow, docs) stay with the lead.
MVP: Story 1. Requirement coverage: FR-001/002 → 002; FR-003/004 → 003, 004, 005; FR-005 → 005; FR-006 → 006;
FR-007 → 002 … 006; FR-008 → 007 … 011.
