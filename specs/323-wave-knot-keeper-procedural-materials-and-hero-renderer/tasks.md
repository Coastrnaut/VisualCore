# Tasks: R02-G03-03 — Wave Knot Keeper: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G03-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G03-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_323;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0303-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G03-03.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G03-02's rendering runs (exit 0)
- [X] T-R02G0303-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies; `WaveKnotKeeperExperience` — Verified 2026-11-21: 2026-11-21 host exit 0 (package: Wave Knot Keeper Core dependencies, experience target and tests; snapshot, palette, tiers, crossing marks)
  and its tests with iOS-conditioned rendering dependencies; the product) and create
  `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneSnapshot.swift` (snapshot, `WaveKnotKeeperTier` "sides 16/10/6, corner samples 8/4/2, glow shells
  2/1/0, richest first", `WaveKnotKeeperPalette` "night #05070F, pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A");
  `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 and 2 — the scene and renderer purity (P1) 🎯

- [X] T-R02G0303-003 [P] [US1] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperShaders.swift` (rope, solid sources; uniform names; caustic pulse) with — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (shader sources, 14 tests: version, uniforms, no samplers or loops, fresnel, caustic, glow shell, gate edge)
  `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperShaderSourceTests.swift` (version line, declared uniforms, no texture samplers,
  bounded loops); `--name host-2`
- [X] T-R02G0303-004 [P] [US1] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperSceneGeometry.swift` (world points × 1/8, rope tube along the — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (geometry, camera, CPU reference; 9 tests: finite at extremes, inside the view at 7 aspects, tube passes every straight part, crossing weights on over-strands only)
  polygon with rounded corners and parallel-transport frames at a tier, handle icospheres, gate cubes, crossing weights,
  camera down −z tilted 20° fitted for aspect 0.4 … 2.5 with a 5 % margin, `project`)
  with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperSceneGeometryTests.swift` (finite and bounded for extreme settings; projections of
  every element inside the view with margin at 7 aspects; the tube passes within one radius of every segment's
  straight part at every tier; crossing weights only on over-strands); `--name host-3`
- [X] T-R02G0303-005 [P] [US2] Create `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperExperienceCore.swift` (controls "point.move [0…15, 0…5], — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (adapter conformance and contract, renderer purity over 200 snapshots; 12 tests)
  point.select [0…15], play.undo, play.redo, level.next"; digest "level number and play fingerprint"; schema 1 `{level, records}`; quality
  profile of three levels) with `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperExperienceCoreTests.swift` (conformance; undo restores the
  digest; snapshot round trip and refusals) and `Packages/ExperiencesRound02/WaveKnotKeeper/CoreTests/WaveKnotKeeperRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict); `--name host-4`

## Phase 3: Experience, registration and frames

- [X] T-R02G0303-006 Create `Packages/ExperiencesRound02/WaveKnotKeeper/Experience/WaveKnotKeeperExperience.swift`, `…Presenter.swift`, `…RopeScene.swift` (GL — Verified 2026-11-21: 2026-11-21 sim-27 exit 0 (render vs CPU reference at 1152x768 on levels 1/21/41/61/81 at three tiers, handle and gate colours, tier log, fallback, zero size, aspects, memory warning, Reduce Motion and Flashing; scenarios 94 incl. 80 acceptance); packages, catalog-search exit 0; candidate registered; draw order fixed (handles over the rope)
  scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing), `…Controls.swift` (a labelled
  point picker, six direction buttons, undo, redo, next level), `Packages/ExperiencesRound02/WaveKnotKeeper/Core/WaveKnotKeeperScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G03-QA-001 … 080) and `Packages/ExperiencesRound02/WaveKnotKeeper/scenario-manifest.json`; register
  the candidate (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example → `r02-g04.hue-compass`,
  `scripts/test_scripts.py`); agent D writes `Packages/ExperiencesRound02/WaveKnotKeeper/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers on 5
  levels; handle colours normal and selected and gate colour (FR-R02G0303-002); tier coordinates;
  fallback; resize and zero size; memory warning releases and the next frame rebuilds (FR-R02G0303-007); Reduce Motion;
  identity); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search`

## Phase 4: Regression, documentation and close

- [X] T-R02G0303-007 Docs: `docs/architecture/wave-knot-keeper.md` (renderer and experience), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; docs/architecture/wave-knot-keeper.md renderer section, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0303-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit (with the Wave Knot Keeper candidate linked) exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0303-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0303-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0303-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0303-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0303-006)
- [ ] T-R02G0303-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
