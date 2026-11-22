# Tasks: R02-G07-03 — Amethyst Escape: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_363;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0703-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline = R02-G07-02 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G07-02's rendering runs (exit 0)
- [X] T-R02G0703-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies VisualCoreScenes, — Verified 2026-11-22: 2026-11-22: host (swift test --filter AmethystEscape) exit 0; Core dependencies now, the Experience targets join with their sources in T-006
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence now; `AmethystEscapeExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product) and create
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneSnapshot.swift` (snapshot per data-model.md: sectors,
  shells with apertures, walls, blocked and offset, pearl pocket, exit gap, stage, failure, moves, budget, levelNumber,
  time; `AmethystEscapeTier` "level-0: 3 bevel segments, 3 highlight layers, 2 glow shells; level-1: 2, 2, 1; level-2:
  1, 1, 0; richest first"; `AmethystEscapePalette` "backdrop #0A0614, amethyst #8E4FD8, highlight #E3CCFF, platinum
  #D6DCE6, blocked #1E1426, pearl #F6F2FF, exit #B8F0FF, amber #FFB020"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter AmethystEscape`

## Phase 2: Stories 1 and 2 — the crystal and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G0703-003 [P] [US1] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeShaders.swift` — Verified 2026-11-22: 2026-11-22: host-2 (AmethystEscapeShaderSourceTests, 13 tests) exit 0, rerun by the lead
  (crystal and glow sources, GLSL ES 3.00; translucent amethyst facets alpha 0.55 with up to 3 shifting specular
  highlight layers driven by `u_time`; uniform names; glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeShaderSourceTests.swift` (version line, declared
  uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A; `--name host-2`
- [X] T-R02G0703-004 [P] [US1] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeSceneGeometry.swift` — Verified 2026-11-22: 2026-11-22: host-3 (AmethystEscapeSceneGeometryTests, 8 tests) exit 0, rerun by the lead
  (shell k annulus from 0.2 + k·w to 0.2 + (k + 1)·w, w = 0.8 / n; wedge of sector s at world sector (s + offset) mod S,
  angles measured from +x towards +z (clockwise from above, as the kernel's +1); bevelled prisms of height h_k = 0.08 + 0.06·(n − 1 − k), inset 0.04·w, the tier's
  bevel segments; apertures as gaps in the rim band; platinum wall fins thickness 0.03·w, height h_k + 0.02 on the
  boundary between own sectors i and i + 1 for wall i; blocked wedges dark with a raised cross; a failed pocket's wedge tinted amber; pearl sphere radius
  0.3·w at the pocket centre, y = h_k + 0.3·w, or on the exit arrow's centre once won; exit arrow over world sector (exit gap + outer offset) mod S at radius
  r_(n−1) + w + 0.06 pointing outward; a platinum move bar along the near edge (z = 1.02, from x = −0.8, length 1.6 ·
  moves / budget); backdrop plane y = 0; camera from +z pitched 50° fitted to the bounding sphere of radius 1.1 with a 5 %
  margin for aspect 0.4 … 2.5; `project`) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeSceneGeometryTests.swift` (finite and bounded for
  extreme settings — 2 × 6 and 5 × 12; pearl, exit and every wedge top inside the view with margin at 7 aspects; same
  positions at every tier; world sector follows the offset; move bar length at 0, half and the budget); agent B;
  `--name host-3`
- [X] T-R02G0703-005 [P] [US2] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeExperienceCore.swift` — Verified 2026-11-22: 2026-11-22: host-4 (ExperienceCoreTests + RendererPurityTests, 12 tests) exit 0, rerun by the lead
  (controls "shell.rotate [0 … shells − 1, −1 or +1], pearl.advance, play.undo, play.redo, level.next"; digest "level
  number and play fingerprint"; schema 1 `{level, records}`; quality profile of three levels; levels generated once per
  process; `snapshot(time:)`) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeExperienceCoreTests.swift` (conformance; undo
  restores the digest; snapshot round trip and refusals) and
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeRendererPurityTests.swift` (200 seeded snapshots:
  tier, time and snapshot never change digest or verdict); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [X] T-R02G0703-006 [US3] [US4] Create `Packages/ExperiencesRound02/AmethystEscape/Experience/AmethystEscapeExperience.swift`, — Verified 2026-11-22: 2026-11-22: sim-27 (AmethystEscapeExperienceTests, 29 tests on iOS 27.2) exit 0, packages exit 0, catalog-search exit 0, host-5 (swift test --filter AmethystEscape incl. scenario tests) exit 0
  `…Presenter.swift`, `…CrystalScene.swift` (GL scene with `ShaderMeshRenderer`; translucent facets drawn after opaque
  geometry with depth writes off; fallback; tier log; Reduce Motion and Reduce Flashing; the presenter declares
  `probes(_:)` — two backdrop corners, as the round-two X gates require — and its quality levels equal the Core's
  `qualityTiers`), `…Controls.swift` (labelled shell picker, turn − and +, advance, undo, redo, next level),
  `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeScenarios.swift` (standard scenarios, full-playthrough,
  hero, fixtures, 80 acceptance scenarios R2-G07-QA-001 … 080) with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeScenariosTests.swift` and
  `Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g08.faceted-forge`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers
  on 5 levels: the pearl centre within 3 px of a pixel 0.15 brighter than the backdrop, the exit arrow differs from the
  backdrop by 0.1, every open wedge top by 0.05, backdrop background within 0.05; tier coordinates; fallback; resize and
  zero size; memory warning releases and the next frame rebuilds; Reduce Motion; identity); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing AmethystEscapeExperienceTests`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [X] T-R02G0703-007 Docs: `docs/architecture/amethyst-escape.md` (renderer and experience), — Verified 2026-11-22: 2026-11-22: round02-host (swift test --package-path Packages/ExperiencesRound02) exit 0; architecture, package README and testing doc updated
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0703-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-22: 2026-11-22: rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0703-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-22: 2026-11-22: reference-1 exit 0
- [ ] T-R02G0703-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0703-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0703-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0703-006)
- [ ] T-R02G0703-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.

## Phase 5: Convergence

- [ ] T-R02G0703-014 Test the wedge-failure description per Spec Edge Cases and FR-R02G0703-007 (partial): in
  `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeExperienceIdentityTests.swift` find, by a
  seeded search over the certified levels, a play whose advance drops the pearl into a blocked wedge, and check that the
  description names that wedge's shell and sector and that the frame tints that wedge amber; part of `--name sim-27-2`
- [ ] T-R02G0703-015 Check the move bar's pixels against the CPU reference per FR-R02G0703-001 and SC-R02G0703-001
  (partial): in `Packages/ExperiencesRound02/AmethystEscape/ExperienceTests/AmethystEscapeRenderTests.swift` (with its
  support file) check, after at least one move, that a pixel within 3 px of the bar's midpoint differs from the backdrop
  by at least 0.1 at each tier on the 5 levels; `--name sim-27-2`
