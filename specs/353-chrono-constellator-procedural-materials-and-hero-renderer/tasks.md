# Tasks: R02-G06-03 — Chrono Constellator: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_353;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0603-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G06-02 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G06-02's rendering runs (exit 0)
- [X] T-R02G0603-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies; `ChronoConstellatorExperience` — Verified 2026-11-21: 2026-11-21: host (swift test --filter ChronoConstellator) exit 0; Core dependencies now, the Experience targets join with their sources in T-006 (as in feature 343)
  and its tests with iOS-conditioned rendering dependencies; the product) and create
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneSnapshot.swift` (snapshot per data-model.md
  with the last 24 ticks of each star's cells; `ChronoConstellatorTier` "ribbon 24/12/6 ticks, segments 4/2/1, glow shells
  2/1/0, richest first"; `ChronoConstellatorPalette` "field #0B0A24, grid #1C1A44, silver #C9CED8, star #F2F4FF, rose
  #FF5C8A, amber #FFB020"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter
  ChronoConstellator`

## Phase 2: Stories 1 and 2 — the scene and renderer purity (P1) 🎯

- [X] T-R02G0603-003 [P] [US1] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorShaders.swift` — Verified 2026-11-21: 2026-11-21: host-2 (ChronoConstellatorShaderSourceTests, 13 tests) exit 0, rerun by the lead
  (field and glow sources; uniform names; ribbon alpha decay and shimmer from time; glow gain cap; palette constants
  equal to the CPU's) with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorShaderSourceTests.swift`
  (version line, declared uniforms, no texture samplers, bounded loops, palette constants match); agent A; `--name host-2`
- [X] T-R02G0603-004 [P] [US1] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift` — Verified 2026-11-21: 2026-11-21: host-3 (ChronoConstellatorSceneGeometryTests, 7 tests) exit 0, rerun by the lead
  (cell size 2/max(columns, rows); field at y = 0 with faint grid lines; silver tracks width 0.08·u at y = 0.004·u; star
  nodes radius 0.3·u at y = 0.25·u with their shapes; rose target rings outer radius 0.42·u at y = 0.006·u with the star's
  shape, lit when the star is on it; history ribbons over the tier's R ticks rising 0.04·u per tick of age with alpha
  1 − age/R; hold bars; amber collision cross; camera from +z pitched 55° fitted to the bounding sphere of the grid with the
  ribbons' full height plus 0.1, with a 5 % margin for aspect 0.4 … 2.5; `project`) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorSceneGeometryTests.swift` (finite and bounded
  for extreme settings; every star, target and track cell inside the view with margin at 7 aspects; same positions at
  every tier; alpha decays as stated); agent B; `--name host-3`
- [X] T-R02G0603-005 [P] [US2] Create — Verified 2026-11-21: 2026-11-21: host-4 (ExperienceCoreTests + RendererPurityTests, 12 tests) exit 0, rerun by the lead
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorExperienceCore.swift` (controls "star.phase [0 … 4,
  0 … 31], star.hold [0 … 4, 1 … 1,200, 1 … 60], star.release [0 … 4, 1 … 1,200], time.step [1 … 1,200], time.rewind,
  play.undo, play.redo, level.next"; digest "level number and play fingerprint"; schema 1 `{level, records}`; quality
  profile of three levels; levels generated once per process; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorExperienceCoreTests.swift` (conformance; undo
  restores the digest; snapshot round trip and refusals) and
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict); agent C; `--name host-4`

## Phase 3: Experience, registration and frames

- [X] T-R02G0603-006 Create `Packages/ExperiencesRound02/ChronoConstellator/Experience/ChronoConstellatorExperience.swift`, — Verified 2026-11-21: 2026-11-21: sim-27 (ChronoConstellatorExperienceTests, 26 tests on iOS 27.2) exit 0, packages exit 0, catalog-search exit 0, host-5 (swift test --filter ChronoConstellator incl. scenario tests) exit 0
  `…Presenter.swift`, `…SkyScene.swift` (GL scene with `ShaderMeshRenderer`, back faces culled on every draw as in the
  Colorfall scene; fallback; tier log; Reduce Motion and Reduce
  Flashing; the presenter declares `probes(_:)` — two field corners, as the round-two X gates require — and its quality
  levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled star picker, phase − and +, add and remove a hold,
  step 1 and 10, run to the end, rewind, undo, redo, next level),
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G06-QA-001 … 080) and
  `Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g07.amethyst-escape`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers
  on 5 levels: star centres within 3 px of bright pixels, target rings differ from the field by 0.1, field background
  within 0.05; tier coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds;
  Reduce Motion; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  ChronoConstellatorExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (after `Catalog/registrations.json` changes; the summary
  feeds catalog search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [X] T-R02G0603-007 Docs: `docs/architecture/chrono-constellator.md` (renderer and experience), — Verified 2026-11-21: 2026-11-21: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0603-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0603-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0603-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0603-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0603-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0603-006)
- [ ] T-R02G0603-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.

## Phase 5: Convergence

- [ ] T-R02G0603-014 Draw the current-tick timeline mark per FR-R02G0603-001 (partial): in
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorSceneGeometry.swift` add a silver progress bar
  along the field's near edge whose length is tick / tickLimit of the grid width (field program, track material), the same
  at every tier and inside the camera fit, with host tests in `ChronoConstellatorSceneGeometryTests.swift` (length at tick
  0, half and the limit; finite; in view); `--name host-6`; then the simulator run `--name sim-27-2`
- [ ] T-R02G0603-015 Check track pixels against the CPU reference per SC-R02G0603-001 (partial): in
  `Packages/ExperiencesRound02/ChronoConstellator/ExperienceTests/ChronoConstellatorRenderTests.swift` (with its support
  file) check that, for every loop cell centre no star or target covers, a pixel within 3 px differs from the field colour
  by at least 0.1 at each tier on the 5 levels; part of `--name sim-27-2`
