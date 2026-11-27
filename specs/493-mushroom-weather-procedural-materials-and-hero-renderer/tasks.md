# Tasks: R02-G20-03 — Mushroom Weather: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_493;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Microscopic Aurora's as recorded at
R02-G19-03 (`git show <R02-G19-03 record commit>:<path>`).

## Phase 1: Setup

- [X] T-R02G2003-001 Baselines on the committed tree after R02-G20-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-26: 2026-11-26 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 after R02-G20-02 (.autonomy/migration/checks/R02-G20-03.baseline-*.json)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (3f with MushroomWeather); the rendering
  baseline is R02-G20-02's rendering runs (exit 0)
- [X] T-R02G2003-002 Edit `Packages/ExperiencesRound02/Package.swift` (`MushroomWeatherCore` gains VisualCoreScenes, — Verified 2026-11-26: 2026-11-26 host exit 0: 96 tests in 12 suites incl. 5 snapshot tests (21 colours, tiers, snapshot vs kernel run at five shown cycles, won and failed plays, time clamping); invariant scans read the kernel files only (.autonomy/migration/checks/R02-G20-03.host.json)
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `MushroomWeatherExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); the renderer-purity and time
  scans of `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherInvariantTests.swift` read only the
  kernel files, so the presentation sources (snapshot, geometry, shaders, scenarios, adapter) stay outside them; create
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneSnapshot.swift` (snapshot per data-model.md:
  rows, columns, blocked cells, humidity fields by cycle, cycles run, shown cycle, mold bound, colonies with band, floor,
  final run, longest run and in-band at the shown cycle, required cycles, pods with growth cycles, sites, vents with
  states, moonlight, failure, stage, actionsLeft, budget, levelNumber, time; `MushroomWeatherTier` "level-0: lathes of
  16 segments, 12 droplets per pod, fronds, 8 motes, 2 glow shells; level-1: 10 segments, 6 droplets, fronds, 4 motes, 1
  shell; level-2: flat caps and pods, no droplets, fronds, motes or glow; richest first"; `MushroomWeatherPalette`
  "midnight #050A1A, midnightTop #0E1A33, moon #E8EEF7, moss #12261C, log #2A2118, frond #1F4A33, mistLow #0B1E4A,
  mistHigh #3A6FD8, site #C9A15A, stalk #D8E6D0, cap #5FD3A0, capOut #3F6E5A, pod #F2A93B, droplet #FFC861, vent
  #6E8B7A, band #9FF5C8, marker #F2A93B, actionsLit #F2A93B, actionsUnlit #1A2A3A, broken #FF6B5E, glow #F7FFF9");
  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter MushroomWeather`

## Phase 2: Stories 1 and 2 — the forest and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G2003-003 [P] [US1] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherShaders.swift` — Verified 2026-11-26: 2026-11-26 host-2 exit 0: 115 tests in 13 suites incl. 19 shader source tests (version, uniforms, 7 of 16 vec4, no samplers or loops, material table 0…28, palette constants, glow caps; glslangValidator absent so its compile test skipped) (.autonomy/migration/checks/R02-G20-03.host-2.json)
  (forest and glow sources, GLSL ES 3.00; lathed shading (core, rim light) from the normal for stalks, caps, pods, logs
  and stones; the translucent cap with an SDF field of moisture beads whose density follows h/M; signed-distance
  shading of the mist squares, site rings, band rings (solid or dashed), vent slats, gauge tracks, band brackets,
  markers, run bars and actions bars from per-vertex local coordinates (material codes in uv: the shared renderer binds
  only position, normal and uv); droplets and motes moved by a time uniform (stopped under Reduce Motion); fronds; the
  still backdrop gradient; the moon with phase ticks; the glow program shades the caps and pods; a won level lights
  every cap; uniform names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match, glow caps);
  agent A; `--name host-2`
- [X] T-R02G2003-004 [P] [US1] Create — Verified 2026-11-26: 2026-11-26 host-3 exit 0: 129 tests in 14 suites incl. 14 geometry tests (extreme settings finite and bounded, every element in view at 7 aspects over 10 catalog levels, positions equal across tiers, mist from kernel values, gauges, won in place, glow shells per tier, failure marks on a failed stage only, shader stream encoding) (.autonomy/migration/checks/R02-G20-03.host-3.json)
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherSceneGeometry.swift` (clarification Q1: cell (r, c)
  at ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s, 0) with s = min(1.8 / C, 1.6 / R); the backdrop quad; the moon disc of
  radius 0.12 at (1.15, 1.05, −0.5) with four phase ticks, L + 1 filled; floor squares of side 0.96 s; logs (rounded
  boxes 0.8 s long, r + c even) and stones (domes of radius 0.36 s); fronds of three generations at the two richer
  tiers, at most 0.3 s from their root; mist squares at height 0.02 of side s · (0.2 + 0.7 · min(1, h/M)) for the
  humidity at the shown cycle, shaded mistLow … mistHigh; site rings of radius 0.32 s; lathed stalks 0.35 s tall and
  umbrella caps of radius 0.42 s (cap in band, capOut otherwise) with band rings; lathed pods of radius 0.18 s (0.26 s
  grown, with a second ring) at height 0.1 s; droplets and motes per tier on fixed paths; slatted vent frames of side
  0.9 s at height 0.9 s, open or shut; one gauge row per colony from y = −1.0 in steps of 0.07 (track x −0.9 … 0.9 over
  0 … M, band bracket, marker, run bar of K segments); actions bars of `budget` at y = −1.0 − 0.07 · colonies − 0.05,
  each 1.8 / budget wide with a fifth as gap, 0.04 tall, lit for the actions left; depth-tested solids and a fixed order
  by kind for the flats; failures marked in the broken colour per clarification Q4; a won level lights every cap
  without moving any position; `glowMesh` per tier (2, 1, 0 shells); camera from eye (0, −1.6, 3.0) to (0, −0.2, 0)
  fitted to x −1.3 … 1.3, y −1.5 … 1.2, z 0 … 0.3 with a 5 % margin for aspect 0.4 … 2.5; `project`; the CPU reference
  points (floor centre, every cap centre, the moon centre, the first gauge track centre, the first actions bar);
  fallback coloured parts) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherSceneGeometryTests.swift`
  (finite and bounded for extreme settings — 6 × 6 and 12 × 14 floors, 1 and 6 colonies, 0 and 6 vents, 6 pods,
  humidity 0 and above M, budgets 1 and 24; every element inside the view with margin at 7 aspects over the catalog's
  levels; the same positions at every tier; mist sizes from the kernel's values only; gauges at 0, band edges and M; a
  won level in place; the glow mesh empty at level-2 and its shell counts per tier; each failure kind marked); agent B;
  `--name host-3`
- [X] T-R02G2003-005 [P] [US2] Create — Verified 2026-11-26: 2026-11-26 host-4 exit 0: 146 tests in 16 suites incl. adapter conformance, undo digests, clock.show refusals (r02-g20.cycle), snapshot round trip, candidate table equal to the witnesses' skipped, 200 seeded purity snapshots (.autonomy/migration/checks/R02-G20-03.host-4.json)
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherExperienceCore.swift` (controls "pod.place [slot, row,
  column], pod.remove [slot], vent.set [index, open], moon.set [level], weather.run, play.undo, play.redo, level.next,
  clock.show [cycle]"; `clock.show` refuses a cycle outside 0 … cycles run; digest "level number and play fingerprint"
  (domain `r02-g20.mushroom-weather.v1`), never the shown cycle; schema 1 `{level, records}`; the shown cycle 0 at
  opening; quality profile of three levels (the Core's `qualityTiers` equals the presenter's levels); each level
  certified directly from a table of its witness's `skipped` candidate, the whole catalog only if that fails;
  `snapshot(time:)`) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherExperienceCoreTests.swift`
  (conformance; undo restores the digest; show changes the snapshot but not the digest and refuses bad values; snapshot
  round trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, shown cycle and snapshot never change digest or verdict; drawn humidity is the kernel's);
  agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [X] T-R02G2003-006 [US3] [US4] Create — Verified 2026-11-26: 2026-11-27 sim-27-2 exit 0 on sim-27.2: 26 tests in 4 suites (frames of levels 1, 21, 41, 61, 81 at three tiers vs the CPU reference, fallback, resize, memory warning, Reduce Motion stills, failure marks, won caps, identity); scenarios exit 0 (153 host tests incl. 7 scenario tests, 94-scenario manifest); packages and catalog-search exit 0; candidate registered; first sim attempt failed on a main-actor static in the test support, fixed (.autonomy/migration/checks/R02-G20-03.{sim-27-2,scenarios,packages,catalog-search}.json)
  `Packages/ExperiencesRound02/MushroomWeather/Experience/MushroomWeatherExperience.swift`, `…Presenter.swift`,
  `…ForestScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing; the
  presenter declares `probes(_:)` — two backdrop corners, as the round-two X gates require — and its quality levels
  equal the Core's `qualityTiers`), `…Controls.swift` (labelled slot, site − and +, place, remove, vent toggles,
  moonlight − and +, cycle − and +, run, undo, redo, next level), and
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G20-QA-001 … 080) with
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherScenariosTests.swift` and
  `Packages/ExperiencesRound02/MushroomWeather/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g21.binary-gardens`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/MushroomWeather/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at the shown
  cycle half the cycles run at three tiers on 5 levels, at points at least 6 px from every element drawn after them:
  each cap's centre brighter than moss by 0.2 in luminance, at least one cap checked; the moon 0.1 from the backdrop;
  the first actions bar with red above blue by 0.08; the first gauge track 0.1 from the backdrop; the median of a 9 × 9
  lower-corner patch within 0.06 of the gradient; tier coordinates; fallback; resize and zero size; memory warning
  releases and the next frame rebuilds; Reduce Motion keeps the frame still; a failure marks the failing element broken;
  a won level lights every cap; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  MushroomWeatherExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [X] T-R02G2003-007 Docs: `docs/architecture/mushroom-weather.md` (renderer and experience), — Verified 2026-11-26: 2026-11-27 docs (architecture renderer and experience, package README, automatedtesting) and round02-host-1, -2, -3c, -3e, -3f exit 0 (.autonomy/migration/checks/R02-G20-03.round02-host-*.json)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G2003-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G2003-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2003-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2003-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2003-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G2003-006)
- [ ] T-R02G2003-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Agents may
draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2. Requirement coverage: FR-001, 002 → 003,
004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006; FR-007 → 006; FR-008 → 006;
FR-009 → 007 … 011.
