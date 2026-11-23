# Tasks: R02-G10-03 — Backwards Aurora: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G10-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G10-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_393;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G1003-001 Baselines on the committed tree: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-22: 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit 0; rendering baseline is R02-G10-02's rendering runs (exit 0)
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G10-02's
  rendering runs (exit 0)
- [X] T-R02G1003-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies VisualCoreScenes, — Verified 2026-11-22: host (swift test --filter BackwardsAurora, 91 tests: the Core gains Scenes, Experience, Diagnostics, Persistence; the snapshot, palette and tiers; the invariant test's kernel scan skips the five presentation sources) exit 0, lead
  VisualCoreExperience, VisualCoreDiagnostics, VisualCorePersistence now; `BackwardsAuroraExperience` and its tests with
  iOS-conditioned rendering dependencies join with their sources in T-006; the product); make the renderer-purity scan
  of `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraInvariantTests.swift` skip the presentation
  sources (snapshot, geometry, shaders, scenarios, adapter), which use Doubles; create
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneSnapshot.swift` (snapshot per data-model.md:
  samples, target, checkpoints, matched, bendLimit, kinks (sorted), tear, sectionStart, sectionEnd, stage, failure,
  spent, budget, levelNumber, time; `BackwardsAuroraTier` "level-0: 3 trailing layers, 2 pulses, 2 glow shells;
  level-1: 2, 1, 1; level-2: 1, 0, 0; richest first"; `BackwardsAuroraPalette` "ground #070B1F, ribbon #1FC8D6,
  ribbonHighlight #9FF4FA, glow #6FE8F0, ghost #C9B8F0, ring #DCD3FA, matched #F4F0FF, kink #FF8A7A, tear #FF3B30,
  band #2A3570, spent #1FC8D6, unspent #2B3352"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02 --filter BackwardsAurora`

## Phase 2: Stories 1 and 2 — the aurora and renderer purity (P1) 🎯

**Independent test**: host geometry, shader-source, adapter and purity tests pass; no simulator needed.

- [X] T-R02G1003-003 [P] [US1] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraShaders.swift` — Verified 2026-11-22: host-2 (101 tests incl. BackwardsAuroraShaderSourceTests 10: version and precision; every uniform the scene sets declared and used; 8 and 6 vec4 slots (≤ 16); no samplers; constant-bounded loops; palette constants within 1/255 of BackwardsAuroraPalette; distinct material codes 0–12; pulse direction and per-tier counts on the CPU reference; glow gain per tier and the Reduce Flashing cap) exit 0, lead retest; band dashes come from the mesh (agent B)
  (aurora and glow sources, GLSL ES 3.00; cyan ribbon with a shimmer and direction-coded pulse beads driven by `u_time`
  (left to right outside the chosen section, right to left inside it, at most 2 per section); trailing layers fading;
  lilac ghost; rings, discs, kink and tear crosses, band with dashed edges; uniform names; glow gain cap; palette
  constants equal to the CPU's) with `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraShaderSourceTests.swift`
  (version line, declared uniforms, at most 16 vec4 uniforms, no texture samplers, bounded loops, palette constants
  match); agent A; `--name host-2`
- [ ] T-R02G1003-004 [P] [US1] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraSceneGeometry.swift`
  (clarification Q1: sample k at x = −1 + (k + 0.5)·2/N, y = 0.6·s / 64, z = 0; ribbon 0.06 high through the sample
  points, each segment in 4 straight steps; trailing layer i at z = −0.06·i, y + 0.04·i; ghost polyline 0.024 high at z
  = −0.05; checkpoint ticks y −0.7 … 0.7 at z = −0.02 with rings (radius 0.045, line 0.012) at the target height at z =
  0.02, discs when matched; kink crosses 0.05 across at z = 0.03; a tear cross 0.09 across at its seam; the section band
  x(start) − u/2 … x(end) + u/2, y −0.7 … 0.7, z = −0.08, dashed edges; gauge of `budget` bars at y = −0.85 from x =
  −0.9 to 0.9, spent ones cyan; ground at z = −0.2; drawing order ground, band, trailing layers, ghost, ticks, ribbon,
  rings and discs, crosses, gauge; camera from +z fitted to x −1 … 1, y −0.95 … 0.75 with a 5 % margin for aspect 0.4 …
  2.5; `project`; fallback coloured parts) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraSceneGeometryTests.swift` (finite and bounded
  for extreme settings — 12 and 32 samples at ±64, every kink, a tear, a section at each end, budgets 1 and 40; every
  sample point, ring and gauge bar inside the view with margin at 7 aspects; same positions at every tier; ribbon
  vertices equal the samples; gauge bars at 0, half and the budget); agent B; `--name host-3`
- [ ] T-R02G1003-005 [P] [US2] Create `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraExperienceCore.swift`
  (controls "wave.reverse [start, end], play.undo, play.redo, level.next"; digest "level number and play fingerprint";
  schema 1 `{level, records}`; quality profile of three levels; each level certified directly from a table of its
  witness's `skipped` candidate, the whole generator only if that fails; `snapshot(sectionStart:sectionEnd:time:)`) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraExperienceCoreTests.swift` (conformance; undo
  restores the digest; snapshot round trip and refusals; the candidate table equals the witnesses' `skipped`) and
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraRendererPurityTests.swift` (200 seeded
  snapshots: tier, time and snapshot never change digest or verdict); agent C; `--name host-4`

## Phase 3: Stories 3 and 4 — tiers, experience, registration and frames (P2)

**Independent test**: the simulator suite renders 5 levels at 3 tiers against the CPU reference; the catalog checks pass.

- [ ] T-R02G1003-006 [US3] [US4] Create `Packages/ExperiencesRound02/BackwardsAurora/Experience/BackwardsAuroraExperience.swift`,
  `…Presenter.swift`, `…AuroraScene.swift` (GL scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and
  Reduce Flashing; the presenter declares `probes(_:)` — two ground corners, as the round-two X gates require — and its
  quality levels equal the Core's `qualityTiers`), `…Controls.swift` (labelled start − and +, end − and +, reverse,
  undo, redo, next level; defaults start 0, end 1, clamped to the wave), and
  `Packages/ExperiencesRound02/BackwardsAurora/Core/BackwardsAuroraScenarios.swift` (standard scenarios,
  full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G10-QA-001 … 080) with
  `Packages/ExperiencesRound02/BackwardsAurora/CoreTests/BackwardsAuroraScenariosTests.swift` and
  `Packages/ExperiencesRound02/BackwardsAurora/scenario-manifest.json`; register the candidate
  (`Catalog/registrations.json` with content facts, `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml` + `xcodegen generate`, `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example →
  `r02-g11.echo-cartographer`, `scripts/test_scripts.py`); agent D writes
  `Packages/ExperiencesRound02/BackwardsAurora/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers
  on 5 levels, at sample and target points at least 6 px from every ring, kink and tick: ribbon blue minus red ≥ 0.15
  and luminance 0.15 from the ground; ghost (where |s − t| ≥ 8) luminance 0.1 from the ground with red above green by
  0.05; the gauge's first bar 0.1 from the ground; ground background within 0.05; tier coordinates; fallback; resize and
  zero size; memory warning releases and the next frame rebuilds; Reduce Motion; a tear marks its seam; identity);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test --only-testing BackwardsAuroraExperienceTests`;
  `--name packages -- python3 scripts/check_experience_packages.py`; `--name catalog-search -- swift test
  --package-path Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'` (the summary
  feeds catalog search and stays ≤ 300 characters)

## Phase 4: Regression, documentation and close

- [ ] T-R02G1003-007 Docs: `docs/architecture/backwards-aurora.md` (renderer and experience),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1003-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name app-unit`
- [ ] T-R02G1003-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1003-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1003-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1003-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G1003-006)
- [ ] T-R02G1003-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
