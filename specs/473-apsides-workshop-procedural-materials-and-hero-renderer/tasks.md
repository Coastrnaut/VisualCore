# Tasks: R02-G18-03 — Apsides Workshop: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G18-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_473;
tests stay short (< 10 s each). No {owner} tasks. Agents model their files on Celestial Eclipse Lab's as recorded at
R02-G17-03 (`git show <R02-G17-03 record commit>:<path>`).

## Phase 1: Setup

- [X] T-R02G1803-001 Baselines on the committed tree after R02-G18-02 is recorded: `--name baseline-host`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0 on the committed R02-G18-02 record; rendering baseline is R02-G18-02's rendering runs (exit 0)
  baseline-timing`, `--name baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f`; the rendering baseline is R02-G18-02's
  rendering runs (exit 0)
- [X] T-R02G1803-002 Edit `Packages/ExperiencesRound02/Package.swift` (`ApsidesWorkshopCore` gains VisualCoreScenes, — Verified 2026-11-25: 2026-11-25 ApsidesWorkshopCore gains Scenes, Experience, Diagnostics and Persistence; ApsidesWorkshopSceneSnapshot (palette, tiers, gauges, snapshot); all ApsidesWorkshop tests pass (host exit 0); the invariant scans read only their explicit kernel file list
  VisualCoreExperience, VisualCoreDiagnostics and VisualCorePersistence; `ApsidesWorkshopExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); the renderer-purity and time
  scans of `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopInvariantTests.swift` read only the
  kernel files, so the presentation sources (snapshot, geometry, shaders, scenarios, adapter) are outside them; create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneSnapshot.swift` (snapshot per data-model.md:
  orbit, positions, ghost positions, orbiter at the shown tick, shares, periapsis and apoapsis sector and distance,
  planets, gauges (target, reading, deviation, met), failure, shownTick, period, stage, actionsLeft, budget,
  levelNumber, time; `ApsidesWorkshopTier` "level-0: spheres 24 × 16, 4 refinement points per tick, 2 glow shells;
  level-1: 16 × 12, 2 points, 1 shell; level-2: flat 20-sided discs, chords only, no glow; richest first";
  `ApsidesWorkshopPalette` "midnight #0A0B1F, midnightTop #1A1438, speck #D8E4FF, wedge #2A2350, targetWedge #6B2346,
  compass #3A3F6B, ghost #5B6390, glacial #E8F1FF, deepRose #C2456E, planet #8C93B8, hazard #C2456E, star #FFF4D6, met
  #C2456E, unmet #E8F1FF, actionsLit #C2456E, actionsUnlit #262A4E, broken #E0533A, glow #F4F8FF"); `--name host --
  swift test --package-path Packages/ExperiencesRound02 --filter ApsidesWorkshop`

## Phase 2: Stories 1 and 2 — the compass and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1803-003 [P] [US1] Create `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopShaders.swift`
  (compass and glow sources, GLSL ES 3.00; layered sphere shading (core, limb darkening, rim light) from the normal;
  signed-distance shading of spokes, rim, notches, brackets, the periapsis diamond and apoapsis square, hazard hatching,
  gauge tracks, bands and filled or hollow marks and bars from per-vertex local coordinates (material codes in uv: the
  shared renderer binds only position, normal and uv); the orbit and ghost ribbons with an emissive core and soft edge;
  the wedges in their tint; the backdrop gradient with sparse procedural specks under 5 % of its pixels; the star's glow
  pulsed by `starPulse(time: reduceMotion:)` (1 with Reduce Motion); the glow program shades the star, the orbit loop
  and the orbiter; a won level brightens the orbit loop and lights every gauge mark; uniform names; glow gain cap;
  palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopShaderSourceTests.swift` (version line, declared
  uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match, the pulse rule);
  agent A; `--name host-2`
- [ ] T-R02G1803-004 [P] [US1] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopSceneGeometry.swift` (clarification Q1: world = sky
  units × s with s = 0.9 / 16 384; the backdrop quad; wedges star → P(t) → P(t + 1) at depth −0.04 tinted for target
  sectors; 8 spokes from radius 0.06 to 0.92, 0.006 wide; the rim at 0.92, 0.012 wide, with s + 1 notches at the middle
  of sector s; target brackets at radius 0.96; the ghost ribbon 0.008 wide at depth −0.08; the orbit ribbon 0.014 wide
  through every kernel position in tick order with `refinement` points per tick on the analytic ellipse between ticks
  (presentation only, `Double`); the periapsis diamond 0.035 at P(0) and the apoapsis square 0.03 at P(T/2) and apsis
  target brackets; planet spheres of radius r · 256 · s with hazard rings 0.01 outside; the star of radius 2 · 256 · s;
  the orbiter of radius 0.03 at P(shown tick); gauge rows at y = −1.08 − 0.07 i from x = −0.9 to 0.9 mapping 0 … 1000 or
  0 … 1280 with band brackets and reading marks; actions bars of `budget` at y = −1.55 from x = −0.9 to 0.9, each
  1.8 / budget wide with a fifth as gap, 0.04 tall, lit for the actions left; painter's order by kind (backdrop, wedges,
  compass, ghost, orbit, markers, planets, star, orbiter, gauges); a failure marks the struck planet and segment or the
  failing gauge in the broken colour; a won level lights every gauge mark without moving any position; `glowMesh` per
  tier (2, 1, 0 shells); camera from eye (0, −0.3, 3.6) to (0, −0.3, 0) fitted to x −1.0 … 1.0, y −1.65 … 1.0 with a
  5 % margin for aspect 0.4 … 2.5; `project`; the CPU reference points (the star, the orbiter, planet centres, the first
  gauge track, the first actions bar); fallback coloured parts) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopSceneGeometryTests.swift` (finite and bounded
  for extreme settings — sizes 8 and 48, eccentricity 0 and 15, periods 16 and 96, 0 and 6 planets at the corners,
  budgets 1 and 24; every element inside the view with margin at 7 aspects over the catalog's levels; the same
  positions at every tier; the orbit ribbon through every kernel position; gauges at 0, half and the budget; a won
  level in place; the glow mesh empty at level-2 and its shell counts per tier; each failure kind marked); agent B;
  `--name host-3`
- [ ] T-R02G1803-005 [P] [US2] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopExperienceCore.swift` (controls "orbit.periapsis
  [k, d], orbit.size [a], orbit.play, play.undo, play.redo, level.next, clock.show [tick]"; `clock.show` refuses a tick
  outside 0 … period − 1; digest "level number and play fingerprint", never the shown tick; schema 1 `{level,
  records}`; the shown tick 0 at opening; quality profile of three levels (the Core's `qualityTiers` equals the
  presenter's levels); each level certified directly from a table of its witness's `skipped` candidate, the whole
  catalog only if that fails; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopExperienceCoreTests.swift` (conformance; undo
  restores the digest; show changes the snapshot but not the digest and refuses bad values; snapshot round trip and
  refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRendererPurityTests.swift` (200 seeded
  snapshots: tier, time, shown tick and snapshot never change digest or verdict; the drawn orbit is the kernel's
  positions); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks
pass.

- [ ] T-R02G1803-006 [US3] [US4] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Experience/ApsidesWorkshopExperience.swift`, `…Presenter.swift`,
  `…CompassScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; the star pulse from presentation time;
  Reduce Motion and Reduce Flashing; the presenter declares `probes(_:)` — two backdrop corners, as the round-two X
  gates require — and its quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled eccentricity −
  and +, direction − and +, size − and +, tick − and +, play, undo, redo, next level), and
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G18-QA-001 … 080) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopScenariosTests.swift` and
  `Packages/ExperiencesRound02/ApsidesWorkshop/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` synthetic candidate →
  `r02-g19.microscopic-aurora`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/ApsidesWorkshop/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at the shown
  tick T/2 at three tiers on 5 levels, at points at least 6 px from every element drawn after them: the star's and the
  orbiter's centres brighter than the backdrop by 0.25 in luminance; the first actions bar with red above blue by 0.08;
  the first gauge track 0.1 from the backdrop; the median of a 9 × 9 backdrop patch within 0.06 of the gradient; tier
  coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion stops
  the pulse; a failure marks the failing element broken; a won level lights every gauge mark; identity); `--name sim-27
  -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package
  --destination sim-27.2 --action test --only-testing ApsidesWorkshopExperienceTests`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path Packages/VisualCore
  --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1803-007 Docs: `docs/architecture/apsides-workshop.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f`
- [ ] T-R02G1803-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1803-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1803-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1803-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1803-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1803-006)
- [ ] T-R02G1803-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. The won-level look is part of T-003 and T-004 from the start (the lesson of
R02-G17-03's convergence). Agents may draft in isolated copies before 001 (new files only). MVP: Stories 1 and 2.
Requirement coverage: FR-001, 002 → 003, 004; FR-003 → 002, 005; FR-004 → 002, 003, 004, 006; FR-005 → 005; FR-006 →
004, 006; FR-007 → 006; FR-008 → 006; FR-009 → 007 … 011.
