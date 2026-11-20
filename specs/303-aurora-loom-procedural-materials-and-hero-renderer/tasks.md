# Tasks: R02-G01-03 — Aurora Loom: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G01-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G01-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_303;
tests stay short (< 10 s each). Simulator evidence is one pass on the iOS 27.x phone (sim-27.2).

## Phase 1: Setup

- [X] T-R02G0103-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-20: 2026-11-20 baseline-host, baseline-timing exit 0; baseline-round02 exit 0 (the package's host tests); rendering baseline R02-G02-01 rendering-27/26 exit 0 (.autonomy/migration/checks/R02-G01-03.baseline-*.json)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G02-01's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0103-002 Edit `Packages/ExperiencesRound02/Package.swift` (AuroraLoomCore gains VisualCoreScenes and — Verified 2026-11-20: 2026-11-20 host exit 0: the kernel's level, play and harmony tests unchanged with the Core's new dependencies; AuroraLoomSceneSnapshot with the palette and the tiers ordered richest first (level-0 = 5 layers) as the shared quality contract requires (.autonomy/migration/checks/R02-G01-03.host.json)
  VisualCoreExperience; new `AuroraLoomExperience` at `AuroraLoom/Experience` and `AuroraLoomExperienceTests` at
  `AuroraLoom/ExperienceTests` with rendering dependencies under `.when(platforms: [.iOS])`; product
  `AuroraLoomExperience`); create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneSnapshot.swift` (AuroraLoomPalette "night #07121A, teal #1FD1B4,
  magenta #E0389C, gold #D8E83A", AuroraLoomTier "layers 5/3/1, segments 128/64/32, glow 2/1/0, names level-0 … level-2, richest first",
  AuroraLoomSceneSnapshot); `--name host -- swift test --package-path Packages/ExperiencesRound02` (all Core tests
  unchanged)

## Phase 3: Story 1 — see the auroral silk (P1) 🎯

- [X] T-R02G0103-003 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomSceneGeometry.swift` (centre lines "height H · sin(2πθ/4,096), lanes — Verified 2026-11-20: 2026-11-20 host-2 exit 0: AuroraLoomSceneGeometryTests 12/12 (finite and bounded for extreme settings, every Ω and large times; layers per tier; certified levels; 5 % framing for aspects 0.4 … 2.5; projection follows the GL chain; phase and marker formulas; determinism) (.autonomy/migration/checks/R02-G01-03.host-2.json)
  −1/0/+1", ribbon meshes via CatmullRomSpline, CurveFrames.parallelTransport and Mesh.ribbon per layer, gate rings,
  markers, camera fitting aspect 0.4 … 2.5 with a 5 % margin, projection) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomSceneGeometryTests.swift`
  (finite and bounded for every extreme setting and Ω; layers per tier; fit for aspects 0.4 … 2.5; projection round
  trip); `--name host-2`
- [X] T-R02G0103-004 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomShaders.swift` (ribbon and gate programs, GLSL ES 3.00; wave — Verified 2026-11-20: 2026-11-20 host-3 exit 0: AuroraLoomShaderSourceTests 7/7 (version line, uniforms declared once and used, no samplers or loops, varyings match, attribute layout 0/1/2, ASCII, fallback and gate colours) (.autonomy/migration/checks/R02-G01-03.host-3.json)
  displacement, bevel from u, interference, palette mix, lit state, glow gain) with
  `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomShaderSourceTests.swift` (version line, every declared uniform used and listed, no texture sampler);
  `--name host-3`
- [X] T-R02G0103-005 [P] [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Core/AuroraLoomExperienceCore.swift` (ExperienceCore adapter: id — Verified 2026-11-20: 2026-11-20 host-4 exit 0: AuroraLoomExperienceCoreTests 9/9 (ExperienceConformance 8/8 checks; actions, refusals, undo/redo, certified solutions win, level.next, snapshot round trip, tiers and time never touch the digest) and AuroraLoomScenariosTests 5/5 (validator, engine replay, committed scenario-manifest.json) (.autonomy/migration/checks/R02-G01-03.host-4.json)
  "r02-g01.aurora-loom", schema 1, three tiers, controls "ribbon.move [0…2, 0…1, 0…15], play.undo, play.redo,
  level.next", prepare level (seed mod 100) + 1, digest of the play fingerprint, snapshot and restore of level number and
  records, `snapshot`) with `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomExperienceCoreTests.swift` (ExperienceConformance run; actions; refusals; restore;
  tiers keep the digest); `--name host-4`
- [X] T-R02G0103-006 [US1] Create `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomExperience.swift`, `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomPresenter.swift`, — Verified 2026-11-20: 2026-11-20 round02-build exit 0 (ExperiencesRound02 for the iOS simulator: AuroraLoomExperience, presenter, ribbon scene, controls; host swift test still builds the iOS-only targets empty); shader-mesh-27 exit 0: ShaderMeshRendererTests 4/4 (uv stream, opaque/additive/premultiplied blending, no-uv constant, broken program refused, release and rebuild); public-api exit 0 after the baseline update (4 added) (.autonomy/migration/checks/R02-G01-03.round02-build.json, .autonomy/migration/checks/R02-G01-03.shader-mesh-27.json, .autonomy/migration/checks/R02-G01-03.public-api.json)
  `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomRibbonScene.swift` (GL scene from snapshots: ribbon layers, gate rings, emissive and bloom passes per tier,
  fallback to the shared unlit renderer with a logged reason, Reduce Motion, Reduce Flashing, memory warning) and
  `Packages/ExperiencesRound02/AuroraLoom/Experience/AuroraLoomControls.swift` (minimal panel: per ribbon wave and phase steppers, undo, redo; accessibility labels), all
  under `#if os(iOS)`; `--name round02-build -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02
  --scheme ExperiencesRound02-Package --destination sim-27.2 --action build`

## Phase 4: Stories 1–3 — frames, purity and tiers on the simulator (P1, P2)

- [X] T-R02G0103-007 [P] [US2] Create `Packages/ExperiencesRound02/AuroraLoom/CoreTests/AuroraLoomRendererPurityTests.swift` (200 seeded snapshots: tier changes, time — Verified 2026-11-20: 2026-11-20 host-5 exit 0: AuroraLoomRendererPurityTests 2/2 (testAuroraLoomRendererpurityBoundary; 200 seeded snapshots never change the digest, the state or the verdict) (.autonomy/migration/checks/R02-G01-03.host-5.json)
  steps and forced failures never change the adapter digest or the kernel verdict; testAuroraLoomRendererpurityBoundary
  for R2-G01-INV-10); `--name host-5`
- [X] T-R02G0103-008 [US1] [US3] Create `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomTestSupport.swift`, `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomRenderTests.swift` (levels 1, — Verified 2026-11-20: 2026-11-20 sim-27 exit 0 on sim-27.2: the whole package incl. AuroraLoomExperienceTests 14/14 (levels 1, 21, 41, 61, 81 at level-0/1/2 match the CPU reference at 96 × 64; digest unchanged by drawing; tier log; fallback on a broken program; zero-size view; resize; Reduce Motion still; Reduce Flashing caps the glow; memory warning rebuild). The first run found unlit magenta ribbons only 0.12 above night at level-2; the ribbon shader's unlit floors were raised (.autonomy/migration/checks/R02-G01-03.sim-27.json)
  21, 41, 61, 81 at each tier, 96 × 64 offscreen: ribbon samples within 2 px of lit pixels, marker colours within 0.12,
  background within 0.05), `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomTierTests.swift` (same positions across tiers; tier log) and
  `Packages/ExperiencesRound02/AuroraLoom/ExperienceTests/AuroraLoomFallbackTests.swift` (broken program draws the fallback and logs; zero-size view; resize; Reduce Motion holds the picture still; Reduce
  Flashing caps the glow gain; a memory warning releases caches and the next frame rebuilds them);
  `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`

## Phase 5: Story 4 — a registered candidate (P2)

- [ ] T-R02G0103-009 [US4] Candidate registration: `Catalog/registrations.json` and `Catalog/experiences.json` (palette,
  capabilities, quality tiers level-0 … level-2, summary ≤ 300 characters, scenario manifest
  `Packages/ExperiencesRound02/AuroraLoom/scenario-manifest.json`; available false), `Apps/VisualCore/App/ExperienceRegistry.swift`,
  `project.yml`, the app test fixtures and `scripts/test_scripts.py` as the A25-P02 registration; `--name
  experience-packages -- python3 scripts/check_experience_packages.py`, `--name catalog-search -- swift test
  --package-path Packages/VisualCore --filter 'CatalogSearchTests|RealCatalogTests|RegistryReportTests'`, `--name
  app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0103-010 CI and docs: no new CI simulator step (experience simulator tests need the locally built ANGLE
  frameworks and run locally, as ExperiencesCreative's do; CI keeps the host step and builds the app, which now links
  the candidate); `docs/architecture/aurora-loom.md` (renderer);
  `Packages/ExperiencesRound02/README.md`; `docs/automatedtesting.md`; `docs/migration/path-map.json` if it names the
  experience path; `--name round02-host -- swift test --package-path Packages/ExperiencesRound02`
- [ ] T-R02G0103-011 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`, `--name public-api` / `--name documented-api` if the app sources changed
- [ ] T-R02G0103-012 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0103-013 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0103-014 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0103-015 {device} After ImplementationLock-100, on D1, D2 and D3: record the frame time at each tier
  (SC-R02G0103-006). Not run before the lock; stays open and is carried to the device campaign.
- [ ] T-R02G0103-016 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent B), 004 (agent A), 005 (agent C)} → 006 (lead, with A for the scene) → {007 (lead), 008 (agent D)}
→ 009 (lead) → 010 … 014, 016. 015 is a {device} task outside this campaign. Shared files (Package.swift, snapshot,
registration, app, CI, docs) stay with the lead. MVP: Story 1.
