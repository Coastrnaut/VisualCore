# Tasks: Digital Zen Garden — Phase 02 Sand and rake renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/experience.md](contracts/experience.md), [quickstart.md](quickstart.md). Gate A20-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A20-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking, never in the same command. iOS 27 only; iOS 26
and the reference regression at X-A20. Precedent: `specs/139-lw-p02-still-renderer/tasks.md`. Rollback: revert the
commits.

## Phase 1: Setup

- [X] T-A20-201 Baseline: cite the A20-P01 evidence (`.autonomy/checks/A20-P01.{zg-core-ios27,app-build,experience-packages}.json`) on the tree recorded at A20-P01 (`b4ce48a4`), whose Packages are unchanged since (owner ruling of 2026-11-14) — Verified 2026-11-17: 2026-11-17: A20-P01 evidence cited: .autonomy/checks/A20-P01.zg-core-ios27.json, A20-P01.app-build.json and A20-P01.experience-packages.json, all exit 0; no Packages, Apps or project.yml change since the A20-P01 record commit b4ce48a4
- [X] T-A20-202 Add the targets `DigitalZenGardenExperience` (path `DigitalZenGarden/Experience`) and `DigitalZenGardenExperienceTests` (path `DigitalZenGarden/ExperienceTests`) and the product `DigitalZenGardenExperience` to `Packages/ExperiencesCreative/Package.swift` (lead; dependencies as the Ambient Clock experience plus the core and `VisualCoreMath`) — Verified 2026-11-17: 2026-11-17: DigitalZenGardenExperience (and its tests, product) added to Packages/ExperiencesCreative/Package.swift; the package builds and tests in .autonomy/checks/A20-P02.zg-ios27.json exit 0

## Phase 2: Foundational — the sized field

- [ ] T-A20-203 [P] Extend `Packages/ExperiencesCreative/DigitalZenGarden/Core/SandField.swift` with `init(columns:rows:)` ("defaults 160 × 120"; columns and rows 1…1024) keeping every A20-P01 behaviour at the default, and add `CoreTests/SandFieldSizeTests.swift` (a 480 × 360 field replays deterministically; a stroke covers the same tray region at both sizes within one cell; the default equals the A20-P01 field)

## Phase 3: Story 1 — rake by dragging (P1) 🎯

- [ ] T-A20-204 [US1] Create `Packages/ExperiencesCreative/DigitalZenGarden/Experience/{Adapter/GardenCore.swift,SandScene.swift,GardenPresenter.swift,StrokePatterns.swift,GardenControls.swift,DigitalZenGardenExperience.swift}` per data-model.md and contracts/experience.md: `GardenCore` (snapshot schema 1, the document only; controls `stroke.begin` [3], `stroke.add` [24], `stroke.end` [], `rake.style` [1], `sand.tone` [1], `edit.undo` [], `edit.redo` []; "raw points ≤ 2,048"; commit through `GardenHistory.rake`; refusals leave the state unchanged; outcome `strokes-<n>`; quality tiers level-0 and level-1); `SandScene` (480 × 360 field, `FloatRenderSupport` format, `upload(rgbaFloats:)`, relief fragment over `vc/` with grain only at level-0 (the full level), fitted 4:3 tray, rebuild by replay on setup, resize and restore, a still frame reused when nothing changes, `maxFramesPerSecond` 30); `GardenPresenter` (pointer in view points → tray → actions; one finger; `cancelPointers` ends without commit); the four patterns; native controls with spoken labels; the factory as Ambient Clock's
- [ ] T-A20-205 [US1] Write `Packages/ExperiencesCreative/DigitalZenGarden/ExperienceTests/{GardenTestSupport,GardenCoreTests,SandSceneTests,PointerPathTests,PatternTests}.swift`: actions accepted in range and refused outside or out of order; snapshot round trip; three far-apart pointer events give a committed stroke with gaps ≤ 0.004 + 1e-9; undo and redo rebuild the drawn field equal to a fresh replay; the drawn target read back with `readFloatPixels` matches the CPU field within 1/1024 (rgba16f) or 1/255 (rgba8, forced fallback); a context recreation draws the same frame; a still frame is not redrawn without a change; gesture and native action sets agree (`GestureAlternatives.missing` empty); each pattern commits one stroke; a stroke at the point cap ends there and a drag at the stroke cap is refused with the garden unchanged (FR-A20-201–203, 205, 207; SC-A20-201–203)

## Phase 4: Story 2 — the brush preview (P1)

- [ ] T-A20-206 [US2] Create `Packages/ExperiencesCreative/DigitalZenGarden/Experience/BrushPreview.swift` (the canvas overlay of clarification Q4: a rectangle of the rake's width across the drag direction with one line per tine, scaled to the fitted tray; hidden from accessibility) and `ExperienceTests/BrushPreviewTests.swift` (visible during a drag with the style's width and tines; follows the style change; hidden after the lift and after `cancelPointers`; never changes the digest) (FR-A20-204)

## Phase 5: Registration and manifest

- [ ] T-A20-207 Register the candidate: `Catalog/registrations.json` entry for a20 (capabilities ≤ 40 characters each, quality_tiers ["level-0", "level-1"], palette, manifest `Packages/ExperiencesCreative/DigitalZenGarden/scenario-manifest.json`, permissions []); `python3 scripts/build_catalog.py`; `Apps/VisualCore/App/ExperienceRegistry.swift` candidate `digitalZenGarden` (no examples: schema 1); `project.yml` product; the synthetic candidate id in `Apps/VisualCore/Tests/Unit/AppModelTests.swift` moves to `a21.aurora` (the catalog's a21 id); lists in app and script tests that name candidates (FR-A20-206)
- [ ] T-A20-208 Write `Packages/ExperiencesCreative/DigitalZenGarden/Experience/Adapter/GardenManifest.swift` (nine standard scenarios and fixtures for a raked garden, the wide rake, undo, redo and the tone) and `ExperienceTests/GardenManifestTests.swift` (valid with its fixture count, derived digests equal the engine's, every fixture ends in its state, the committed file matches); generate `scenario-manifest.json` with `UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`

## Phase 6: Records and evidence

- [ ] T-A20-209 Digital Zen Garden tests on sim-27.2 (`--name zg-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalZenGardenCoreTests DigitalZenGardenExperienceTests`), the documented API (`--name documented-api`), the GL isolation (`--name isolation -- python3 scripts/check_app_isolation.py --experiences Packages/ExperiencesCreative/DigitalZenGarden`) and the core purity scan of A20-P01 (`--name core-purity`) (FR-A20-206; SC-A20-204)
- [ ] T-A20-210 Contract: G-SAND, G-RELIEF and G-PREVIEW closed by "A20-P02" (record the CPU-field decision of clarification Q1 in G-SAND's notes); rows whose gaps are all closed become available with evidence; add the relief shader to `docs/apps/digital-zen-garden/licenses.md` (`--name contract`)
- [ ] T-A20-211 Catalog (`--name catalog -- python3 scripts/build_catalog.py --check`); app build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`); runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a20.digital-zen-garden --runtime 27`); packages and script tests
- [ ] T-A20-212 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A20-P02; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

201 → 202 → 203 → 204 → 205 → 206 → 207 → 208 → 209 → 210 → 211 → 212. 203 is the core (its own writer); 204–206 and
208 are one experience (one writer).

## Parallel examples

Agent K: T-A20-203 (core). Agent E: T-A20-204–206 and the manifest source of 208 (experience). Lead: Package.swift,
registration (207), manifest generation, runs, contract, commits.

## Implementation strategy

MVP: raking with the no-gap fixture (204, 205). The preview (206) completes the manual's MVP; registration and the
manifest (207, 208) make it runnable in the app. Review checkpoints after 205 and at 209.
