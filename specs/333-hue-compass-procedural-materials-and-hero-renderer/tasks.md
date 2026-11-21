# Tasks: R02-G04-03 — Hue Compass: procedural materials and hero renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G04-03 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G04-03 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Seed 2_333;
tests stay short (< 10 s each). No {owner} tasks.

## Phase 1: Setup

- [X] T-R02G0403-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G04-03.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-02's rendering runs (exit 0)
- [X] T-R02G0403-002 Edit `Packages/ExperiencesRound02/Package.swift` (Core dependencies; `HueCompassExperience` and its — Verified 2026-11-21: 2026-11-21 host exit 0 (Core gains VisualCoreScenes, Experience, Diagnostics, Persistence; HueCompassSceneSnapshot with the target nil while playing, palette with the HSV band rule, glyphs, tiers 12/8/4 facets, 3/2/1 fog layers, 2/1/0 glow shells; the Experience target comes with T-006)
  tests with iOS-conditioned rendering dependencies; the product) and create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneSnapshot.swift`
  (snapshot with the target "nil while playing", `HueCompassTier` "facets 12/8/4, fog layers 3/2/1, glow shells 2/1/0,
  richest first", `HueCompassPalette` "night #05070F, pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A; band(h) = hue
  h/24, s 0.85, v 1.0", `HueCompassGlyph` "shape h mod 4, marks ⌊h/4⌋ + 1"); `--name host -- swift test --package-path
  Packages/ExperiencesRound02`

## Phase 2: Stories 1 and 2 — the scene and renderer purity (P1) 🎯

- [X] T-R02G0403-003 [P] [US1] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassShaders.swift` (glass and solid sources; uniform names; band hue — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (agent A: glass and solid GLSL ES 3.00 sources, 17 tests: version line, declared and used uniforms, no samplers or loops, the GLSL band rule equals HueCompassPalette.band for all 24 bands within 1e-9, capped glow, fog drift still at time 0; colour rides in the normal slot because ShaderMeshRenderer has no colour stream)
  transform equal to `HueCompassPalette.band`; fog drift; glow gain cap) with
  `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassShaderSourceTests.swift` (version line, declared uniforms, no texture samplers, bounded
  loops, the hue formula's constants match the CPU's); `--name host-2`
- [X] T-R02G0403-004 [P] [US1] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassSceneGeometry.swift` (bearing directions, needle prism to radius — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (agent B: needle prism, ticks, unlit band wheel with glyphs clear of the 0.85 sample ring, fog prisms by density, probe/selection/target marks, camera fitting the 1.45 sphere at aspects 0.4 … 2.5; 9 tests: finite and bounded, inside the view at 7 aspects, same places at every tier, fog colour from density only, band colours follow the offset, no target geometry while absent)
  0.8 at a tier's facets, 96 ticks at 0.95 … 1.0, 24 unlit band segments at 0.82 … 0.92 with glyphs at 0.895 … 0.92, fog
  prisms at 1.1 … 1.25 with height 0.04 + 0.03 × density and brightness density/9 in the tier's layers, probe marks at
  1.32 (pearl), selection (ember) and target ring (sapphire, only when present), camera down −z tilted 35° fitted to
  bounding-sphere radius 1.45 for aspect 0.4 … 2.5 with a 5 % margin, `project`) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassSceneGeometryTests.swift`
  (finite and bounded for extreme settings; projections of every element inside the view with margin at 7 aspects;
  bearings, bands, glyphs and marks at the same places at every tier; fog brightness follows density only); `--name
  host-3`
- [X] T-R02G0403-005 [P] [US2] Create `Packages/ExperiencesRound02/HueCompass/Core/HueCompassExperienceCore.swift` (controls "compass.turn [−48 … 48, not 0], — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (agent C: adapter with compass.turn, compass.probe, compass.select, play.undo, play.redo, level.next; digest = level and play fingerprint; schema 1 restore by replay; 14 tests incl. conformance at seeds 0 and 99 and purity over 200 seeded snapshots, no target while playing, twin levels differing only in the target give equal snapshots while playing)
  compass.probe, compass.select [0 … 95, 0 … 23], play.undo, play.redo, level.next"; digest "level number and play
  fingerprint"; schema 1 `{level, records}`; quality profile of three levels; `snapshot(time:)` with no target while
  playing) with `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassExperienceCoreTests.swift` (conformance; undo restores the digest; snapshot
  round trip and refusals) and `Packages/ExperiencesRound02/HueCompass/CoreTests/HueCompassRendererPurityTests.swift` (200 seeded snapshots: tier, time and
  snapshot never change digest or verdict; no playing snapshot carries the target; two levels differing only in the
  target give equal playing snapshots); `--name host-4`

## Phase 3: Experience, registration and frames

- [X] T-R02G0403-006 Create `Packages/ExperiencesRound02/HueCompass/Experience/HueCompassExperience.swift`, `…Presenter.swift`, `…CompassScene.swift` (GL — Verified 2026-11-21: 2026-11-21 sim-27, packages, catalog-search-2 exit 0 (experience target: presenter, compass scene, fallback, controls by an agent, built and tested by the lead on sim-27.2, 19 simulator tests: frames vs the CPU reference at three tiers on levels 1, 21, 41, 61, 81, fallback, zero size, aspects, Reduce Motion and Flashing, memory warning, identity; 94 scenarios with the 80 acceptance rows; candidate registered in Catalog/registrations.json, the registry, project.yml and the RealCatalogTests registered list (the first catalog-search attempt failed until that list named the candidate); AppModelTests example now r02-g05.colorfall-canyons; app-unit exit 0)
  scene with `ShaderMeshRenderer`; fallback; tier log; Reduce Motion and Reduce Flashing), `…Controls.swift` (labelled
  turn −4, −1, +1, +4, probe, band picker, select, undo, redo, next level), `Packages/ExperiencesRound02/HueCompass/Core/HueCompassScenarios.swift`
  (standard scenarios, full-playthrough, hero, fixtures, 80 acceptance scenarios R2-G04-QA-001 … 080) and
  `Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`; register the candidate (`Catalog/registrations.json` with content facts,
  `build_catalog.py`, `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` + `xcodegen generate`,
  `Apps/VisualCore/Tests/Unit/AppModelTests.swift` example → `r02-g05.colorfall-canyons`, `scripts/test_scripts.py`);
  agent D writes `Packages/ExperiencesRound02/HueCompass/ExperienceTests/` (render vs CPU reference at 1,152 × 768 at three tiers on 5 levels: needle tip and
  probe marks within 3 px of bright pixels, band colours at radius 0.85 within 0.15, night background within 0.05; tier
  coordinates; fallback; resize and zero size; memory warning releases and the next frame rebuilds; Reduce Motion;
  identity); `--name sim-27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesRound02 --scheme
  ExperiencesRound02-Package --destination sim-27.2 --action test`; `--name packages -- python3
  scripts/check_experience_packages.py`; `--name catalog-search`

## Phase 4: Regression, documentation and close

- [X] T-R02G0403-007 Docs: `docs/architecture/hue-compass.md` (renderer and experience), — Verified 2026-11-21: 2026-11-21 round02-host exit 0; docs/architecture/hue-compass.md (experience and renderer), Packages/ExperiencesRound02/README.md, docs/automatedtesting.md (two lessons)
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0403-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full, app-unit exit 0
  `--name host-full`, `--name app-unit`
- [X] T-R02G0403-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0403-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0403-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [ ] T-R02G0403-012 {device} After ImplementationLock-100: frame time per tier on D1/D2/D3 (SC-R02G0403-006)
- [ ] T-R02G0403-013 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 → {003 (agent A), 004 (agent B), 005 (agent C)} → 006 (lead; agent D writes the simulator tests) → 007 … 011,
013. 012 stays open until device testing. Shared files (Package.swift, snapshot, presenter, scene, controls, scenarios,
registration, docs) stay with the lead. MVP: Stories 1 and 2.
