# Tasks: R02-G05-03 — Colorfall Canyons: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_343;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [ ] T-R02G0503-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-02's rendering runs (exit 0)
- [ ] T-R02G0503-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies; `ColorfallCanyonsExperience` and its
  tests with iOS-conditioned rendering dependencies; the product) and create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneSnapshot.swift`
  (snapshot per data-model.md; `ColorfallCanyonsTier` "subdivision 4/2/1, flow bands 3/2/1, glow shells 2/1/0, richest
  first"; `ColorfallCanyonsPalette` "night #05070F, sandstone #8C5A3C, rock #3B302C, pearl #E8E4DA, cyan #19E3F0, coral
  #FF6F59, yellow #FFD23F; fluid = mass-weighted mix"; `ColorfallCanyonsPattern` "cyan stripes, coral dots, yellow
  chevrons"); `--name host -- swift test --package-path Packages/ExperiencesRound02`

## Phase 2: Stories 1 and 2 — the scene and renderer purity (P1) 🎯

- [ ] T-R02G0503-003 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsShaders.swift` (terrain and fluid sources; uniform names;
  fluid colour mix and patterns equal to the palette and pattern rules; flow-band phase from time; glow gain cap) with
  `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsShaderSourceTests.swift` (version line, declared uniforms, no texture samplers, bounded
  loops, the palette constants match the CPU's); `--name host-2`
- [ ] T-R02G0503-004 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsSceneGeometry.swift` (cell size 2/max(columns, rows); block
  tops at 0.06·h·u, rock +0.5·u, drains at 0, basin rims with three target arcs, spring emitters 0.6·u tall dimmed when
  closed or dry, fluid sheets 0.01·u above the top, thickness 0.02·u + 0.04·u·min(V, 24)/24, brightness 0.35 + 0.65·min(V,
  24)/24, flow bands along downhill per tier, camera from +z pitched 50° fitted to the bounding sphere of the tallest
  element + 0.1 with a 5 % margin for aspect 0.4 … 2.5, `project`) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsSceneGeometryTests.swift`
  (finite and bounded for extreme settings; every cell top and emitter inside the view with margin at 7 aspects; same
  positions at every tier; carving lowers the block); `--name host-3`
- [ ] T-R02G0503-005 [P] [US2] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsExperienceCore.swift` (controls "canyon.carve [0 … 119],
  canyon.valve [0 … 2], time.step [1 … 600], play.undo, play.redo, level.next"; digest "level number and play
  fingerprint"; schema 1 `{level, records}`; quality profile of three levels; levels generated once per process;
  `snapshot(time:)`) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsExperienceCoreTests.swift` (conformance; undo restores the
  digest; snapshot round trip and refusals) and `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict); `--name host-4`

## Phase 3: Experience, registration and frames

- [ ] T-R02G0503-006 Create `Packages/ExperiencesRound02/ColorfallCanyons/Experience/ColorfallCanyonsExperience.swift`, `…Presenter.swift`, `…CanyonScene.swift` (GL
  scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing; the presenter declares
  `probes(_:)` — two night corners, as the round-two X gates require — and its quality levels equal the Core's
  `qualityTiers`), `…Controls.swift` (labelled cell
  picker and carve, valve per spring, step 1 and 10, run to the end, undo, redo, next level),
  `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsScenarios.swift` (standard scenarios, full-playthrough, hero, fixtures, 80 acceptance scenarios
  R2-G05-QA-001 … 080) and `Packages/ExperiencesRound02/ColorfallCanyons/scenario-manifest.json`; register the candidate (`Catalog/registrations.json` with content
  facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` + `xcodegen generate`,
  `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example → `r02-g06.chrono-constellator`, `scripts/test_scripts.py`);
  agent D writes `Packages/ExperiencesRound02/ColorfallCanyons/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers on 5 levels: emitter tops
  within 3 px of bright pixels, open cell tops differ from night by 0.1, night background within 0.05; tier coordinates;
  fallback; resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion; identity);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search`

## Phase 4: Regression, documentation and close

- [ ] T-R02G0503-007 Docs: `docs/architecture/colorfall-canyons.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0503-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0503-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0503-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0503-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0503-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0503-006)
- [ ] T-R02G0503-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
