# Tasks: R02-G02-03 — Lissajous Labyrinth: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G02-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G02-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_313;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0203-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 R02-G02-03.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G01-06's rendering runs (exit 0)
- [X] T-R02G0203-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies; `LissajousLabyrinthExperience` — Verified 2026-11-20: 2026-11-20 host exit 0 (package: Lissajous Core dependencies, experience target and tests; snapshot, palette, tiers)
  and its tests with iOS-conditioned rendering dependencies; the product) and create
  `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneSnapshot.swift` (snapshot, `LissajousLabyrinthTier` "stride 1/2/4, glow 2/1/0, trail
  512/256/128, richest first", `LissajousLabyrinthPalette` "night #070B1E, cobalt #2F5BD8, violet #8A4FE0, copper #D9824A");
  `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Story 1 and 2 — the scene and renderer purity (P1) 🎯

- [X] T-R02G0203-003 [P] [US1] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthShaders.swift` (thread, solid sources; uniform names) with — Verified 2026-11-20: 2026-11-20 host-2 exit 0 (shader sources, 11 tests)
  `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthShaderSourceTests.swift` (version line, declared uniforms, no texture samplers,
  bounded loops); `--name host-2`
- [X] T-R02G0203-004 [P] [US1] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthSceneGeometry.swift` (path at a tier's stride, thread mesh — Verified 2026-11-20: 2026-11-20 host-3 exit 0 (geometry, camera, CPU reference; 6 tests)
  with tangent-space width, rings, icospheres, head, camera fitted for aspect 0.4 … 2.5 with a 5 % margin, `project`)
  with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthSceneGeometryTests.swift` (finite and bounded for extreme settings; projections of
  every element inside the view with margin at 7 aspects; tier samples are exact kernel samples); `--name host-3`
- [X] T-R02G0203-005 [P] [US2] Create `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthExperienceCore.swift` (controls "dial.set [0…3, 0…15], — Verified 2026-11-20: 2026-11-20 host-4 exit 0 (adapter conformance and contract, renderer purity over 200 snapshots; 11 tests)
  play.undo, play.redo, level.next"; digest "level number and play fingerprint"; schema 1 `{level, records}`; quality
  profile of three levels) with `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthExperienceCoreTests.swift` (conformance; undo restores the
  digest; snapshot round trip and refusals) and `Packages/ExperiencesRound02/LissajousLabyrinth/CoreTests/LissajousLabyrinthRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict); `--name host-4`

## Phase 3: Experience, registration and frames

- [X] T-R02G0203-006 Create `Packages/ExperiencesRound02/LissajousLabyrinth/Experience/LissajousLabyrinthExperience.swift`, `…Presenter.swift`, `…ThreadScene.swift` (GL — Verified 2026-11-20: 2026-11-20 sim-27 exit 0 (18 new simulator tests: frames vs CPU reference at 768x512 on levels 1/21/41/61/81 at three tiers, ring states, tier log, fallback, zero size, aspects, memory warning, Reduce Motion; round-two package incl. scenarios); packages, catalog-search exit 0; candidate registered
  scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing), `…Controls.swift` (four
  labelled steppers, undo, redo, next level), `Packages/ExperiencesRound02/LissajousLabyrinth/Core/LissajousLabyrinthScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G02-QA-001 … 080) and `Packages/ExperiencesRound02/LissajousLabyrinth/scenario-manifest.json`; register
  the candidate (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example → `r02-g03.wave-knot-keeper`,
  `scripts/test_scripts.py`); agent D writes `Packages/ExperiencesRound02/LissajousLabyrinth/ExperienceTests/` (render vs CPU reference at three tiers on 5 levels;
  checkpoint colours for unvisited, visited and next and the obstacle contact colour (FR-R02G0203-002); tier coordinates;
  fallback; resize and zero size; memory warning releases and the next frame rebuilds (FR-R02G0203-007); Reduce Motion;
  identity); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search`

## Phase 4: Regression, documentation and close

- [X] T-R02G0203-007 Docs: `docs/architecture/lissajous-labyrinth.md` (renderer and experience), — Verified 2026-11-20: 2026-11-20 round02-host exit 0; docs/architecture/lissajous-labyrinth.md renderer section, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0203-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-20: 2026-11-20 rendering-27, rendering-26, experiences, host-full, app-unit (with the Lissajous candidate linked) exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0203-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-20: 2026-11-20 reference-1 exit 0
- [X] T-R02G0203-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-20: 2026-11-20 reference-2 exit 0: 7 of 7 with chunk 1
- [ ] T-R02G0203-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0203-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0203-006)
- [ ] T-R02G0203-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
