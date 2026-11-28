# Tasks: R02-G22-03 — Mycelium Architect: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G22-03. Evidence: `python3
scripts/migration_ledger.py run-check --gate R02-G22-03 --name <check> -- <command>` (never a scratchpad path; recorded
only after every agent has reported; read `exit=` before ticking). Commit after every task (no trailers). Tests short
(< 10 s each), seed 2_513. Presentation sources go in `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/`. Every `host` check runs `swift test
--package-path Packages/ExperiencesRound02 --filter MyceliumArchitect`.

## Phase 1: Setup

- [X] T-R02G2203-001 Baselines after R02-G22-02 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1/2/3c/3e/3f exit=0
  baseline-round02-1` (`VoxelOrigami|MyceliumArchitect`), `-2`, `-3c`, `-3e`, `-3f`

## Phase 2: Foundational

- [X] T-R02G2203-002 Edit `Packages/ExperiencesRound02/Package.swift` (MyceliumArchitectCore gains VisualCoreScenes, — Verified 2026-11-27: package dependencies, snapshot (palette, tiers), adapter (ten controls, r02-g22.pulse, digest, schema 1), scenarios and manifest (94 scenarios), adapter tests (12); host exit=0 (33 XCTest + 74 Swift Testing)
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence; its tests gain VisualCoreScenes,
  VisualCoreExperience, VisualCoreDiagnostics; new `MyceliumArchitectExperience` (path `MyceliumArchitect/Experience`,
  iOS rendering dependencies with `.when(platforms: [.iOS])`), `MyceliumArchitectExperienceTests` and the product);
  create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneSnapshot.swift` (snapshot, palette of clarification Q3, tiers of
  Q2), `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectExperienceCore.swift` (adapter of Q5: certified candidate table, the
  ten controls with declared ranges, `r02-g22.pulse`, digest domain `r02-g22.mycelium-architect.v1`, snapshot schema 1
  `{level, records}`, `qualityTiers`), `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectScenarios.swift`,
  `Packages/ExperiencesRound02/MyceliumArchitect/scenario-manifest.json` (standard scenarios, `full-playthrough`, `hero`, fixtures and R2-G22-QA-001 … 080) and
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectExperienceCoreTests.swift` (controls and refusals, digest purity on 200 seeded
  snapshots under tier, time and shown-pulse changes, restore); `--name host`

## Phase 3: Stories 1 and 2 — the hero scene, pure (P1) 🎯

- [X] T-R02G2203-003 [P] [US1] [US2] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectSceneGeometry.swift` (agent A: fit — Verified 2026-11-27: MyceliumArchitectSceneGeometry (fit, camera, painter's order, board and glow meshes, tapered tubes, CPU reference, fallback) and its tests (13) installed; host-2 exit=0
  rule, cell centres, camera and fitted box of Q1, painter's order, board and glow meshes with materials in uv, tapered
  tubes and caps by tier, CPU reference points) with `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectSceneGeometryTests.swift`
  (finiteness and bounds for extreme levels, order, reference agreement, aspect 0.4 … 2.5 margins); `--name host-2`
- [X] T-R02G2203-004 [P] [US1] Create `Packages/ExperiencesRound02/MyceliumArchitect/Core/Presentation/MyceliumArchitectShaders.swift` (agent B: GLSL ES 3.00 — Verified 2026-11-27: MyceliumArchitectShaders (board and glow GLSL ES 3.00, 7 uniform slots each, no samplers, bounded loops, palette equal to Swift) and its tests (15, incl. agreement with the geometry's material table) installed; host-3 exit=0
  board and glow programs, at most 16 vec4 uniforms, no samplers, bounded loops, fixed hash, palette equal to Swift)
  with `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectShaderSourceTests.swift`; `--name host-3`
- [X] T-R02G2203-005 [US1] [US3] Create the iOS experience `Packages/ExperiencesRound02/MyceliumArchitect/Experience/MyceliumArchitectExperience.swift`, — Verified 2026-11-27: experience target (experience, presenter with probes and tier log, board scene with fallback, labelled panel) and its simulator tests (29) installed; sim-27 exit=65 (spores drawn over the caps hid every cap point at tiers 0/1: spores moved beneath the caps, hollow pips' fallback colour set to ring), sim-27-2 exit=0
  `MyceliumArchitectPresenter.swift` (frame `probes(_:)`, quality levels equal to the Core's `qualityTiers`,
  `tierLog`, `fallbackReason`), `MyceliumArchitectBoardScene.swift`, `MyceliumArchitectControls.swift` (labelled
  minimal panel) and `Packages/ExperiencesRound02/MyceliumArchitect/ExperienceTests/MyceliumArchitectRenderTests.swift` (agent C: frames of levels 1, 21, 41, 61,
  81 at each tier against the CPU reference; forced shader failure shows the fallback; tier changes and shown pulse keep
  the digest); `--name sim-27` (`xcodebuild_package.py … --only-testing MyceliumArchitectExperienceTests`)

## Phase 4: Story 4 — a registered candidate (P2)

- [X] T-R02G2203-006 [US4] Registration: `Catalog/registrations.json` (Q5), `build_catalog.py` (catalog and VisualCore — Verified 2026-11-27: registration (registrations.json, catalog and fixtures rebuilt, project.yml with xcodegen, registry candidate at seed 0, AppModelTests synthetic candidate r02-g23.erosion-painter, RealCatalogTests, test_scripts products); packages, catalog-search, app-unit exit=0
  fixtures), `project.yml` (two products) and `xcodegen generate`, `Apps/VisualCore/App/ExperienceRegistry.swift`
  (candidate, opening seed 0), `Apps/VisualCore/Tests/Unit/AppModelTests.swift` (synthetic candidate
  `r02-g23.erosion-painter`), `Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift`,
  `scripts/test_scripts.py` (products); `--name app-unit` (`release_check.py --only app-build-for-testing-ios27
  app-unit-ios27`)

## Phase 5: Regression, documentation and close

- [X] T-R02G2203-007 Docs: `docs/architecture/mycelium-architect.md` (hero renderer), package README, — Verified 2026-11-27: architecture (hero renderer), package README, automatedtesting; validate_docs PASS; round02-host-1/2/3c/3e/3f exit=0
  `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`, `-3f`
- [X] T-R02G2203-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-27: rendering-27, rendering-26, experiences, host-full exit=0
  `--name host-full`
- [X] T-R02G2203-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-27: reference-1 exit=0
- [X] T-R02G2203-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-27: reference-2 exit=0
- [X] T-R02G2203-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-27: script-tests exit=0 (run alone)
- [ ] T-R02G2203-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G2203-006)
- [ ] T-R02G2203-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B)} → 005 (agent C) → 006 (lead) → 007 … 011, 013; 012 stays open until
device testing. Shared files (package, snapshot, adapter, scenarios, registration, docs) stay with the lead. MVP:
Stories 1 and 2. Coverage: FR-001, 002 → 003, 004; FR-003 → 002, 003, 005; FR-004 → 002, 005; FR-005 → 002; FR-006 →
003, 005; FR-007 → 005; FR-008, 009 → 006 … 011; FR-010 → 005; SC-001 → 005; SC-002 → 002; SC-003 → 003; SC-004 →
006; SC-005 → 007 … 011; SC-006 → 012.
