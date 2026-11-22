# Tasks: R02-G08-08 — Faceted Forge: visual golden and solver regression

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-08 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_378;
tests stay short (< 10 s each); no wall-clock assertion.

## Phase 1: Setup

- [X] T-R02G0808-001 Baselines: `--name baseline-round02`, `--name baseline-host`, `--name baseline-timing` — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0

## Phase 2: Story 1 — every level stays solvable as certified (P1) 🎯

- [X] T-R02G0808-002 [P] [US1] Create `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRegressionSolverTests.swift` (agent A: for every — Verified 2026-11-22: host (FacetedForgeRegressionSolverTests, 14 tests / 108 cases: all 100 levels in ten groups — generated level equals the witness, witness cuts replay to a win with per-cut digests and fingerprints, solve returns exactly the witness cuts with smallest = lowerBound and work <= workBound; ten named alterations each yield exactly their part) exit 0, lead retest
  level in ten groups of 10, "the generated level equals its witness's level; the witness's cuts replay to a win in
  exactly its smallest cut count within the budget, with its per-cut digests and fingerprints; solve returns exactly
  the witness's cuts with smallest equal to the witness's and to lowerBound(level), with work ≤ workBound"; ten named
  alterations of clarification Q2 (a crystal half-space, the budget, the sliver limit, a target piece's share, a target
  piece's face count; a solution cut; a witness cut, a per-cut digest, a per-cut fingerprint; the smallest cut count)
  each fail naming the level and the part); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  FacetedForgeRegressionSolverTests`

## Phase 3: Story 2 — the picture does not drift (P1)

- [X] T-R02G0808-003 [US2] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeGolden.swift` (DEBUG or VISUALCORE_AUTOMATION; "16 frames: — Verified 2026-11-22: FacetedForgeGolden (16 frames: levels 1, 21, 41, 61, 81 x tiers 0-2 after 2 certified cuts at 1 s, plus the hero frame) and golden-frames.json written with FACETED_FORGE_WRITE_GOLDEN=1 (md5 99bc118c5b9f405d81d393a43a73f91f, unchanged by the later run without the switch); FacetedForgeGolden added to RELEASE_FORBIDDEN and to the invariant test's presentation sources; verified by host-2 exit 0, lead retest
  levels 1, 21, 41, 61, 81 at tiers 0 … 2 at time 1 s after the witness's first min(smallest − 1, 2) cuts, plus the
  hero frame at tier 0; at 1,152 × 768 with the authored camera and the initial preview choice: every piece centre
  (canonical order) and the preview centre, positions rounded to 1/8 px and an off-screen point null; the cuts spent and
  the budget; the ground, ice, highlight, ruby, amber, lattice, sliver, spent and unspent colours 8-bit sRGB; JSON with
  sorted keys; SHA-256"; manifest; compare with the one-quantum fallback and the pinned-digest
  self-check), generate `Packages/ExperiencesRound02/FacetedForge/golden-frames.json` with
  `FACETED_FORGE_WRITE_GOLDEN=1`, and add `FacetedForgeGolden` to `RELEASE_FORBIDDEN` in `scripts/release_check.py`
- [X] T-R02G0808-004 [P] [US2] Create `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRegressionGoldenTests.swift` (agent B: every frame's — Verified 2026-11-22: host-2 (FacetedForgeRegressionGoldenTests 9 tests: recomputed descriptions match the pinned file, pinned digests are the digests of their descriptions, moved positions beyond a quantum, colour, count and tier changes, missing, unknown and renamed frames, schema 2 and a hand-edited description each named; file written only with the switch; plus the invariant suite) exit 0, lead retest
  recomputed description matches its pinned one; each pinned digest equals the digest of its pinned description; a
  moved position beyond a quantum, a changed colour, a missing frame, an unknown frame, schema ≠ 1 and a hand-edited
  description all fail naming the frame; the file is rewritten only with the switch); `--name host-2 -- swift test
  --package-path Packages/ExperiencesRound02 --filter FacetedForgeRegressionGoldenTests`

## Phase 4: Stories 2 and 3 — simulator frames and memory (P1, P2)

- [X] T-R02G0808-005 [US2] [US3] Edit `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeCrystalScene.swift` (`liveObjectCount`: GPU — Verified 2026-11-22: sim-27 (FacetedForgeExperienceTests, 63 tests on iOS 27.2 incl. the 16 golden frames rendered and checked against their descriptions with the feature-373 tolerances, 12 open-draw-warn-close memory cycles with liveObjectCount 0 after each close and warning, a closed scene rebuilt on the next open) exit 0; an unrecorded run passed first
  objects held, 0 after release) and create
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeRegressionGoldenFrameTests.swift` and
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/FacetedForgeRegressionMemoryTests.swift` (agent C: the
  16 frames rendered and checked against their descriptions with the feature-373 tolerances (every piece centre within
  3 px of a pixel 0.1 away from the ground in luminance, the preview centre at least 0.05 and the first cut bar at least
  0.1 away from the ground, the probe corners within 0.05 of the ground); 12 open-draw-warn-close cycles with
  `ProcessMemory.footprint()`, cycles 2 … 12 within 16 MB of cycle 1 when
  `TEST_RUNNER_FACETED_FORGE_MEMORY_ISOLATED=1`, readings printed otherwise; live GPU objects 0 after each close and
  warning; an unavailable footprint fails with a named reason); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing FacetedForgeExperienceTests`

## Phase 5: Story 4 — the checks run on every change (P2)

- [X] T-R02G0808-006 [P] [US4] Create `scripts/faceted_forge_regression.py` and its test in `scripts/test_scripts.py` — Verified 2026-11-22: regression (python3 scripts/faceted_forge_regression.py: host PASS, simulator golden-frame and isolated memory classes PASS, one summary) exit 0; FacetedForgeRegressionTests (5 script tests) OK; CI step 'Faceted Forge regression (host)' added, lead retest
  (agent D: host filter `FacetedForgeRegression`, then the simulator classes through `xcodebuild_package.py
  --only-testing` with the isolation variable, one summary line per part with pass or fail and the first failing name,
  a non-zero exit on any failure), and add the named step "Faceted Forge regression (host)" to
  `.github/workflows/ci.yml`; `--name regression -- python3 scripts/faceted_forge_regression.py`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0808-007 Docs: `docs/architecture/faceted-forge.md` (regression net),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0808-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0808-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0808-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0808-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0808-012 {device} After ImplementationLock-100, on D1, D2 and D3: frame time and memory of the golden levels.
  Not run before the lock.
- [ ] T-R02G0808-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → {002 (agent A), 003 (lead) → 004 (agent B), 005 (lead + agent C), 006 (agent D)} → 007 … 011, 013. 012 is a
{device} task outside this campaign. Shared files (golden source, scene, release list, workflow, docs) stay with the
lead. MVP: Story 1.
