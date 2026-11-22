# Tasks: R02-G08-03 — Faceted Forge: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_373;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [ ] T-R02G0803-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G08-02's rendering runs (exit 0)
- [ ] T-R02G0803-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies VisualCoreScenes,
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence now; `FacetedForgeExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product) and create
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneSnapshot.swift` (snapshot per data-model.md: pieces
  with world-space corners — centroid-subtracted and divided by R, the largest centroid-to-corner distance — faces as
  corner index lists in the kernel's order, cut flags "a face whose plane is not one of the crystal's half-spaces" and
  centroids; chosen piece, direction, depth, the preview polygon (empty when the plane misses the piece), stage,
  failure with its piece, cuts, budget, levelNumber, time; `FacetedForgeTier` "level-0: 3 bevel segments, 3 dispersion
  layers, 2 glow shells; level-1: 2, 2, 1; level-2: 1, 1, 0; richest first"; `FacetedForgePalette` "ground #07090F, ice
  #BFE6F5, highlight #F2FBFF, ruby #C8163C, amber #FFB347, lattice #FFE2A8, sliver #FF4D6D, spent #C8163C, unspent
  #3A4558"); `--name host -- swift test --package-path Packages/ExperiencesRound02 --filter FacetedForge`

## Phase 2: Stories 1 and 2 — the crystal and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G0803-003 [P] [US1] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeShaders.swift`
  (crystal and glow sources, GLSL ES 3.00; ice glass with fresnel highlights and up to 3 faux-dispersion layers driven
  by `u_time`; incandescent amber-to-ruby cut faces with a lattice pattern; translucent ruby preview; uniform names;
  glow gain cap; palette constants equal to the CPU's) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeShaderSourceTests.swift` (version line, declared
  uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants match); agent A;
  `--name host-2`
- [ ] T-R02G0803-004 [P] [US1] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeSceneGeometry.swift`
  (each piece from its exact faces, fan-triangulated in the kernel's corner order, edges bevelled with an inset of 0.02
  and the tier's segments; opening along the crystal-centroid-to-piece-centroid direction by 0.12, 0.2 when won, eased
  over 0.4 s of presentation time, at rest under Reduce Motion, no move for a piece centred within 1e-9; cut faces
  amber with a lattice, original faces ice glass, a sliver failure's piece with a cross; the preview polygon ruby with
  a dashed rim; the cut mark a row of `budget` bars along z = 1.3 from x = −0.9 to 0.9, spent ones ruby; ground plane
  y = −1.3; camera from +z pitched 30° fitted to the bounding sphere of radius 1.45 with a 5 % margin for aspect
  0.4 … 2.5; `project`) with `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeSceneGeometryTests.swift`
  (finite and bounded for extreme settings — the uncut crystal and a 20-piece play; every piece centre, cut-face centre
  and the preview centre inside the view with margin at 7 aspects; same positions at every tier; cut flags exact on a
  known cut; opening 0 for the uncut crystal; mark bars at 0, half and the budget); agent B; `--name host-3`
- [ ] T-R02G0803-005 [P] [US2] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeExperienceCore.swift`
  (controls "piece.cut [0 … pieces − 1, 0 … 12, −24 … 24], play.undo, play.redo, level.next"; digest "level number and
  play fingerprint"; schema 1 `{level, records}`; quality profile of three levels; levels generated once per process
  from the certified catalog; `snapshot(chosen:direction:depth:time:)`) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeExperienceCoreTests.swift` (conformance; undo
  restores the digest; snapshot round trip and refusals) and
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRendererPurityTests.swift` (200 seeded snapshots:
  tier, time, preview choice and snapshot never change digest or verdict); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [ ] T-R02G0803-006 [US3] [US4] Create `Packages/ExperiencesRound02/FacetedForge/Experience/FacetedForgeExperience.swift`,
  `…Presenter.swift`, `…CrystalScene.swift` (GL scene with `ShaderMeshRenderer`; translucent glass drawn after opaque
  geometry with depth writes off; fallback; tier log; Reduce Motion and Reduce Flashing; the presenter declares
  `probes(_:)` — two ground corners, as the round-two X gates require — and its quality levels equal the Core's
  `qualityTiers`), `…Controls.swift` (labelled piece picker, direction picker, depth − and +, cut, undo, redo, next
  level), `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G08-QA-001 … 080) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeScenariosTests.swift` and
  `Packages/ExperiencesRound02/FacetedForge/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g09.nocturne-garden`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/FacetedForge/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers on
  5 levels after the witness's first cut: every piece centre (± 3 px) differs from the ground by 0.1 in luminance, every
  cut face centre (± 3 px) has red minus blue ≥ 0.15, the preview centre differs from the ground by 0.05, the mark's
  first bar differs by 0.1, ground background within 0.05; tier coordinates; fallback; resize and zero size; memory
  warning releases and the next frame rebuilds; Reduce Motion; a sliver failure found by a seeded search names its
  piece and cut; identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package
  Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing
  FacetedForgeExperienceTests`; `--name packages -- python3 scripts/check_experience_packages.py`; `--name
  catalog-search -- swift test --package-path Packages/VisualCore --filter
  'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G0803-007 Docs: `docs/architecture/faceted-forge.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0803-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G0803-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0803-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0803-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0803-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0803-006)
- [ ] T-R02G0803-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
