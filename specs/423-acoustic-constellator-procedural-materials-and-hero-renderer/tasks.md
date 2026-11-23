# Tasks: R02-G13-03 — Acoustic Constellator: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G13-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G13-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_423;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [ ] T-R02G1303-001 Baselines on the committed tree after R02-G13-02 is recorded: `--name baseline-host`, `--name
  baseline-timing`, `--name baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering
  baseline is R02-G13-02's rendering runs (exit 0)
- [ ] T-R02G1303-002 Edit `Packages/ExperiencesRound02/Package.swift` (`AcousticConstellatorExperience` and its tests
  with iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity
  scan of `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorInvariantTests.swift` skip the
  presentation sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles; create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneSnapshot.swift` (snapshot per
  data-model.md: stars, links, symbol, starting phases, listen report, threshold, hold, window, stage, failure,
  actionsLeft, budget, levelNumber, time, `shownTick` "one tick per 0.25 s, the last held 1 s, looping; 0 at time 0";
  `AcousticConstellatorTier` "level-0: pulse, 2 wave shells, 2 glow shells; level-1: pulse, no shells, 1 glow shell;
  level-2: no pulse, none; richest first"; `AcousticConstellatorPalette` "sky #05060F, star #F4F1E8, hand #F4F1E8, silver
  #B8C0D0, teal #3FD6C6, guide #8A5A9C, broken #FF6B4A, coherenceLit #3FD6C6, coherenceUnlit #2A2433, thresholdMark
  #F4F1E8, holdLit #3FD6C6, holdUnlit #3A3348, movesLit #B8C0D0, movesUnlit #2A2433, shell #6FE0D8, glow #8FF4EA");
  `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter AcousticConstellator`

## Phase 2: Stories 1 and 2 — the constellation and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1303-003 [P] [US1] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorShaders.swift` (constellation and glow
  sources, GLSL ES 3.00; signed-distance shading of stars, hands, filaments, guides and gauges from per-vertex local
  coordinates; the presentation pulse 1 + 0.15 · cos(2π · phase / 12) driven by uniforms, none at level-2 and under
  Reduce Motion; wave shells expanding from radius 0 to 0.12 over 1 s; a won level lifts the symbol links' glow; uniform
  names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorShaderSourceTests.swift` (version line,
  declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A;
  `--name host-2`
- [ ] T-R02G1303-004 [P] [US1] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorSceneGeometry.swift` (clarification Q1: star
  (gx, gy, gz) at X = (gx − 5.5) · 0.14, Z = (gy − 5.5) · 0.11, Y = 0.15 + (gz − 5.5) · 0.02; sky at y = −0.01 over x
  −1.1 … 1.1, z −0.9 … 1.3; dashed guides (8 dashes, 0.006 wide) for unlinked symbol pairs; links as spline strips
  0.01 wide rising 0.03 at the middle, 16 segments, silver when the gap at the shown tick is above 1, teal at most 1;
  snapped links as two halves with the middle 30 % missing; star ellipsoids 0.045 × 0.035 × 0.045 with 12 × 8 segments;
  phase hands 0.006 wide, 0.07 long at angle phase · 30°, 0.04 above the star; coherence gauge of 12 bars at z = 0.85 from
  x = −0.6 to 0.6 with ⌊12 · (A + B√3) / n²⌋ lit and a mark over bar ⌈12θ / n²⌉; hold pips at z = 1.0 from x = −0.4 to
  0.4, lit for the current run; moves gauge of `budget` bars at z = 1.15 from x = −0.9 to 0.9, each 1.8 / budget wide
  with a fifth as gap, 0.05 deep, lit for the actions left; a won level brightens every symbol link without moving any
  position; camera from eye (0, 2.0, 1.7) to (0, 0, 0.2) fitted to x −0.9 … 0.9, z −0.7 … 1.25, y 0 … 0.3 with a 5 %
  margin for aspect 0.4 … 2.5; `project`; fallback coloured parts) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorSceneGeometryTests.swift` (finite and
  bounded for extreme settings — 3 and 8 stars, 0 and 16 links, every link snapped, none, budgets 1 and 40, holds 2 and
  12; every star centre, link check point, gauge bar and pip inside the view with margin at 7 aspects; same positions
  at every tier; teal exactly where the kernel's gap at the shown tick is at most 1; snapped exactly where the kernel's
  report snaps; gauge bars at 0, half and the budget; a won level's links brighter and in place); agent B; `--name
  host-3`
- [ ] T-R02G1303-005 [P] [US2] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorExperienceCore.swift` (controls "link.add
  [a, b], link.remove [a, b], star.nudge [s, ±1], constellation.listen, play.undo, play.redo, level.next"; digest "level
  number and play fingerprint"; schema 1 `{level, records}`; quality profile of three levels (the Core's `qualityTiers`
  equals the presenter's levels); each level certified directly from a table of its witness's `skipped` candidate, the
  whole generator only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorExperienceCoreTests.swift`
  (conformance; undo restores the digest; snapshot round trip and refusals; the candidate table equals the witnesses'
  `skipped`) and `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorRendererPurityTests.swift`
  (200 seeded snapshots: tier, time and snapshot never change digest or verdict; the drawn pulse never changes a phase,
  a snap or the coherence); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1303-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/AcousticConstellator/Experience/AcousticConstellatorExperience.swift`, `…Presenter.swift`,
  `…ConstellationScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce
  Flashing; the presenter declares `probes(_:)` — two sky corners, as the round-two X gates require — and its quality
  levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled star − and +, partner − and +, link, unlink, nudge −
  and +, listen, undo, redo, next level; star 0 and partner 1 chosen when a level opens), and
  `Packages/ExperiencesRound02/AcousticConstellator/Core/AcousticConstellatorScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G13-QA-001 … 080) with
  `Packages/ExperiencesRound02/AcousticConstellator/CoreTests/AcousticConstellatorScenariosTests.swift` and
  `Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g14.moonlit-mechanism`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/AcousticConstellator/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at time 0
  at three tiers on 5 levels, at points at least 6 px from any other element: star centre luminance 0.15 from the sky with
  red, green and blue within 0.1; a teal link's check point 0.08 from the sky with green above red by 0.05; the first
  moves bar 0.1 from the sky; sky background within 0.05; tier coordinates; fallback; resize and zero size; memory
  warning releases and the next frame rebuilds; Reduce Motion; a failure outlines the missing guide or snapped link; a
  won level brightens its links; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  AcousticConstellatorExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1303-007 Docs: `docs/architecture/acoustic-constellator.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1303-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1303-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1303-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1303-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1303-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1303-006)
- [ ] T-R02G1303-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start. Requirement
coverage: FR-001, 002 → 003, 004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 → 004, 006;
FR-007 → 006; FR-008 → 006; FR-009 → 007 … 011.
