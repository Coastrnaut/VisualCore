# Tasks: R02-G11-03 — Echo Cartographer: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_403;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1103-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0, 2026-11-23; rendering baseline is R02-G11-02's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G11-02's
  rendering runs (exit 0)
- [X] T-R02G1103-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies VisualCoreScenes, — Verified 2026-11-23: host (86 EchoCartographer tests) exit 0, 2026-11-23; Core dependencies added; purity scan skips the five presentation sources; snapshot, palette and tiers
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence now; `EchoCartographerExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity scan
  of `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerInvariantTests.swift` skip the presentation
  sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles; create
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneSnapshot.swift` (snapshot per data-model.md:
  width, height, knowledge, entry, markers, located, lastEcho, stage, failure, energy, budget, levelNumber, time — "holds
  no unknown wall and no unlocated beacon"; `EchoCartographerTier` "level-0: rings, flare trails, 2 glow shells;
  level-1: rings, no trails, 1 shell; level-2: none; richest first"; `EchoCartographerPalette` "ground #05070A, floor
  #3A4A46, wallFace #12302A, wallEdge #3DF5C4, flare #B8FFF0, pulse #5FF7FF, entry #CFE3DD, marker #E8F1EE, pillar
  #5FF7FF, glow #9FFFF7, gaugeLit #3DF5C4, gaugeUnlit #1E2A2A"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter EchoCartographer`

## Phase 2: Stories 1 and 2 — the chamber and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [ ] T-R02G1103-003 [P] [US1] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerShaders.swift`
  (chamber and glow sources, GLSL ES 3.00; signed-distance shading of tiles, rings and edge strips from per-vertex local
  coordinates; the pulse ring and up to 4 echo rings driven by `u_time` and the echo delays (a cell per 0.1 s); wall
  flare when the ring reaches a struck wall, fading over 0.5 s; uniform names; glow gain cap; palette constants equal to
  the CPU's) with `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerShaderSourceTests.swift`
  (version line, declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants
  match); agent A; `--name host-2`
- [ ] T-R02G1103-004 [P] [US1] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerSceneGeometry.swift`
  (clarification Q1: s = 1.8 / max(W, H), cell centre X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s; ground at y =
  −0.01 over the chamber plus 0.1; floor tiles 0.9·s on known-open cells; entry diamond 0.5·s at y = 0.005; marker rings
  radius 0.32·s line 0.06·s at y = 0.01; rays 0.05·s wide at y = 0.015 to the struck wall's face or the edge; pulse and
  echo rings at y = 0.02; known walls as blocks 0.92·s wide and 0.5·s high with 12 edge strips 0.05·s thick; located
  beacons as pillars 0.3·s wide, 0.8·s high; gauge of `budget` bars at z = 1.0 from x = −0.9 to 0.9, each 1.8 / budget
  wide with a fifth as gap, 0.06 deep, lit for the energy left; nothing on unknown cells and no unlocated beacon; camera
  from eye (0, 2.4, 1.9) to (0, 0, 0.05) fitted to x −1 … 1, z −1 … 1.1, y 0 … 0.8 with a 5 % margin for aspect 0.4 …
  2.5; `project`; fallback coloured parts) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerSceneGeometryTests.swift` (finite and bounded
  for extreme settings — 5 × 5 and 16 × 16 chambers, all known, none known, every wall known, 4 pillars, 8 markers,
  budgets 1 and 60; every cell centre, wall top and gauge bar inside the view with margin at 7 aspects; same positions at
  every tier; no vertex on an unknown cell; gauge bars at 0, half and the budget); agent B; `--name host-3`
- [ ] T-R02G1103-005 [P] [US2] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerExperienceCore.swift`
  (controls "cell.pulse [x, y], cell.claim [x, y], cell.mark [x, y], play.undo, play.redo, level.next"; digest "level
  number and play fingerprint"; schema 1 `{level, records}`; quality profile of three levels; each level certified
  directly from a table of its witness's `skipped` candidate, the whole generator only if that fails;
  `snapshot(time:)`) with `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerExperienceCoreTests.swift`
  (conformance; undo restores the digest; snapshot round trip and refusals; the candidate table equals the witnesses'
  `skipped`) and `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerRendererPurityTests.swift` (200
  seeded snapshots: tier, time and snapshot never change digest or verdict; no snapshot holds an unknown wall or an
  unlocated beacon); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [ ] T-R02G1103-006 [US3] [US4] Create `Packages/ExperiencesRound02/EchoCartographer/Experience/EchoCartographerExperience.swift`,
  `…Presenter.swift`, `…ChamberScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and
  Reduce Flashing; the presenter declares `probes(_:)` — two ground corners, as the round-two X gates require — and its
  quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled column − and +, row − and +, pulse,
  claim, mark, undo, redo, next level; the cursor opens on the entry, clamped to the chamber), and
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G11-QA-001 … 080) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerScenariosTests.swift` and
  `Packages/ExperiencesRound02/EchoCartographer/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g12.harmonic-bridges`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/EchoCartographer/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers
  on 5 levels, at points at least 6 px from any other element: floor-tile centre luminance 0.1 from the ground; wall top
  centre 0.08 from the ground with green above red by 0.05; the gauge's first bar 0.1 from the ground; ground background
  within 0.05; tier coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds;
  Reduce Motion; an energy failure empties the gauge; identity); `--name sim-27 -- python3
  scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme ExperiencesRound02-Package --destination
  sim-27.2 --action test --only-testing EchoCartographerExperienceTests`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search -- swift test --package-path Packages/VisualCore
  --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary feeds catalog search and stays ≤ 300
  characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1103-007 Docs: `docs/architecture/echo-cartographer.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1103-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1103-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1103-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1103-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1103-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1103-006)
- [ ] T-R02G1103-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing.
