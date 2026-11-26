# Tasks: R02-G19-03 — Microscopic Aurora: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_483;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Apsides Workshop's as recorded at
R02-G18-03 (`git show <R02-G18-03 record commit>:<path>`).

## Phase 1: Setup

- [ ] T-R02G1903-001 Baselines on the committed tree after R02-G19-02 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G19-02's
  rendering runs (exit 0)
- [ ] T-R02G1903-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MicroscopicAuroraCore` gains VisualCoreScenes,
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `MicroscopicAuroraExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); the renderer-purity and time
  scans of `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraInvariantTests.swift` read only the
  kernel files, so the presentation sources (snapshot, geometry, shaders, scenarios, adapter) stay outside them; create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneSnapshot.swift` (snapshot per
  data-model.md: radius, positions and velocities by tick, ticks swum, shown tick, density, lit stencil and stray cells,
  stencil, sites, wells, coverage and requirement, coherence and requirement, swarm, failure, stage, actionsLeft, budget,
  levelNumber, time; `MicroscopicAuroraTier` "level-0: capsules of 12 segments, 64 ribbon ticks, fronds, 2 glow shells;
  level-1: 8 segments, 32 ticks, fronds, 1 shell; level-2: flat capsules, 16 ticks, no fronds, no glow; richest first";
  `MicroscopicAuroraPalette` "abyss #04110F, abyssTop #0B2A26, field #0E2E2A, frond #2E6B5C, rim #6FB7A6, stencil
  #3E7F72, lit #7FE0C4, stray #2F6B5F, site #B58CE0, well #D2A8FF, ribbon #8FF0D6, swimmer #E9FFF8, met #B58CE0, unmet
  #E9FFF8, actionsLit #B58CE0, actionsUnlit #1E3A35, broken #FF6B5E, glow #F2FFFB"); `--name host -- swift test
  --package-path Packages/ExperiencesRound02 --filter MicroscopicAurora`

## Phase 2: Stories 1 and 2 — the dish and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1903-003 [P] [US1] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraShaders.swift` (dish and glow sources, GLSL ES
  3.00; capsule shading (core, rim light) from the normal; signed-distance shading of the rim, stencil outlines, lit
  cells, site rings, well spirals and arrows, gauge tracks, requirement ticks, filled or hollow marks and bars from
  per-vertex local coordinates (material codes in uv: the shared renderer binds only position, normal and uv); ribbons
  with an emissive core fading to the tail; fronds; the still backdrop gradient; the glow program shades the swimmers
  and ribbons; a won level brightens the ribbons and lights every stencil cell; uniform names; glow gain cap; palette
  constants equal to the CPU's) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match, glow caps);
  agent A; `--name host-2`
- [ ] T-R02G1903-004 [P] [US1] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSceneGeometry.swift` (clarification Q1: world =
  ((x − 3072) · s, (3072 − y) · s) with s = 0.9 / 2816; the backdrop quad; the field disc of radius R · 256 · s; fronds
  of three generations at the two richer tiers, reaching at most 0.07 beyond the rim; the rim 0.012 wide; stencil
  outlines of side 256 · s, 0.004 wide; lit cells inset by 10 % (lit for stencil cells, stray outside); site rings of
  radius 0.35 cell; well spirals of strength + 1 half-turns, radius 0.45 cell, arrowhead in the turning sense; ribbons
  0.01 wide through each swimmer's kernel positions of the last L ticks up to the shown tick (L = the tier's ribbon
  ticks), fading to the tail; capsules 0.05 long and 0.016 wide at the shown tick oriented along the velocity (a still
  swimmer keeps +x); coverage track at y = −1.08 and coherence track at y = −1.15 from x = −0.9 to 0.9 with requirement
  ticks and reading marks; actions bars of `budget` at y = −1.25, each 1.8 / budget wide with a fifth as gap, 0.04 tall,
  lit for the actions left; painter's order by kind; failures marked in the broken colour per clarification Q4; a won
  level lights every stencil cell without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from eye
  (0, −0.15, 3.4) to (0, −0.15, 0) fitted to x −1.0 … 1.0, y −1.35 … 1.0 with a 5 % margin for aspect 0.4 … 2.5;
  `project`; the CPU reference points (dish centre, rim's rightmost point, swimmers at the shown tick, the first site,
  the coverage track centre, the first actions bar); fallback coloured parts) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSceneGeometryTests.swift` (finite and
  bounded for extreme settings — radius 6 and 11, 4 and 16 swimmers, swims of 120 and 480 ticks, swimmers at the rim,
  budgets 1 and 24, all 576 cells lit; every element inside the view with margin at 7 aspects over the catalog's levels;
  the same positions at every tier; ribbons through kernel positions only; gauges at 0, half and full; a won level in
  place; the glow mesh empty at level-2 and its shell counts per tier; each failure kind marked); agent B; `--name
  host-3`
- [ ] T-R02G1903-005 [P] [US2] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraExperienceCore.swift` (controls "well.place
  [slot, row, column, strength, sense], well.remove [slot], swim.play, play.undo, play.redo, level.next, clock.show
  [tick]"; `clock.show` refuses a tick outside 0 … ticks swum; digest "level number and play fingerprint", never the shown
  tick; schema 1 `{level, records}`; the shown tick 0 at opening; quality profile of three levels (the Core's
  `qualityTiers` equals the presenter's levels); each level certified directly from a table of its witness's `skipped`
  candidate, the whole catalog only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraExperienceCoreTests.swift` (conformance; undo
  restores the digest; show changes the snapshot but not the digest and refuses bad values; snapshot round trip and
  refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, shown tick and snapshot never change digest or verdict; drawn swimmers are the kernel's
  positions); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1903-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/MicroscopicAurora/Experience/MicroscopicAuroraExperience.swift`, `…Presenter.swift`,
  `…DishScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing; the
  presenter declares `probes(_:)` — two backdrop corners, as the round-two X gates require — and its quality levels equal
  the Core's `qualityTiers`), `…Controls.swift` (labelled slot, site − and +, strength − and +, sense, place, remove,
  tick − and +, play, undo, redo, next level), and
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G19-QA-001 … 080) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraScenariosTests.swift` and
  `Packages/ExperiencesRound02/MicroscopicAurora/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g20.mushroom-weather`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/MicroscopicAurora/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at the shown
  tick half the ticks swum at three tiers on 5 levels, at points at least 6 px from every element drawn after them:
  each swimmer's centre brighter than the field by 0.25 in luminance, at least one swimmer checked; the rim point 0.1
  from the backdrop; the first actions bar with blue above green by 0.08; the coverage track 0.1 from the backdrop; the
  median of a 9 × 9 corner patch within 0.06 of the gradient; tier coordinates; fallback; resize and zero size; memory
  warning releases and the next frame rebuilds; Reduce Motion keeps the frame still; a failure marks the failing element
  broken; a won level lights every stencil cell; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py
  --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test
  --only-testing MicroscopicAuroraExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`;
  `--name catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1903-007 Docs: `docs/architecture/microscopic-aurora.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1903-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1903-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1903-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1903-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1903-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1903-006)
- [ ] T-R02G1903-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage: FR-001, 002 → 003,
004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006;
FR-009 → 007 … 011.
