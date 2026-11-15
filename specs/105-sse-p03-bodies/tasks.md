# Tasks: Solar System Explorer — Phase 03 Camera and 3D body rendering

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/bodies.md](contracts/bodies.md), [quickstart.md](quickstart.md). Gate A14-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; reference regression and iOS 26 at
X-A14. Precedent: `specs/104-sse-p02-orbits/tasks.md`.

## Phase 1: Setup

- [X] T-A14-301 Baseline: cite the last evidence on the unchanged tree (`.autonomy/checks/A14-P02.{sse-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A14-P02.sse-ios27.json, A14-P02.app-unit.json and A14-P02.verify-27.json (exit 0) on the tree recorded at A14-P02, unchanged since apart from spec documents (no rerun)

## Phase 2: Foundational — core surfaces, ring and scale (stories 1, 2)

- [X] T-A14-302 [P] [US1] Add `Packages/ExperiencesCreative/SolarSystemExplorer/Core/{SphereNoise,SurfaceRecipe}.swift` per data-model.md (`SphereNoise` "seed (UInt64), octaves 4, lacunarity 2, gain 0.5", "`value(at: Vec3) -> Double` in [0, 1]; deterministic"; `SurfaceRecipe` per body with seed 0xA14_0000 + index and the styles of Clarifications Q1, "`colors(for: Mesh)` one per vertex, each channel 0…1", `digest` the stable hash of the colours) with `CoreTests/{SphereNoiseTests,SurfaceRecipeTests}.swift` (range, determinism, equal values at equal directions; digests stable and pairwise distinct; on a 48 × 24 UV sphere the seam and pole vertices get equal colours and the largest colour jump across the date line ≤ the largest neighbour jump elsewhere) (FR-A14-301; SC-A14-301) — Verified 2026-11-15: 2026-11-15: SphereNoise (seeded 3D value noise, 4 octaves, directions rounded to a 2^-30 grid so seam and pole vertices match) and SurfaceRecipe (nine recipes, SurfaceColor per vertex, SHA-256 digest of quantised colours); SphereNoiseTests and SurfaceRecipeTests pass in .autonomy/checks/A14-P03.sse-core-ios27.json exit 0 on sim-27.2 (73 core tests; digests stable and distinct, seam and pole colours equal, date-line jump within the neighbour maximum); data-model notes colors(for: [Vec3])
- [X] T-A14-303 [US1] Add `Core/RingRecord.swift` ("inner < cassini inner < cassini outer < outer"; 74,500, 117,580, 122,170, 136,775 km), source records `ring-inner-radius`, `ring-outer-radius`, `cassini-division` (NSSDCA Saturnian Rings Fact Sheet, J2000.0, km, public-domain) in `Core/SourceRecords.swift`, `CitationAudit` coverage and a "## Saturn's rings" section of `docs/apps/solar-system-explorer/data-sources.md` (regenerated), with `CoreTests/RingRecordTests.swift` (FR-A14-302) — Verified 2026-11-15: 2026-11-15: RingRecord (74,500 / 117,580-122,170 / 136,775 km), SourceRecord.ringRecords (NSSDCA Saturnian Rings Fact Sheet, J2000.0, km, public-domain), CitationAudit.ringProblems and the Saturn's rings section of data-sources.md (regenerated); RingRecordTests and CitationAuditTests pass in .autonomy/checks/A14-P03.sse-core-ios27.json exit 0 on sim-27.2
- [X] T-A14-304 [US2] Add `Core/ScaleMode.swift` (`enhanced` 0 = the A14-P02 mapping and display radii; `trueRelative` 1 = 2 scene units per AU for positions and radii; labels "Distances and sizes not to scale" and "Distances and sizes to one scale; small bodies marked"; near/far: enhanced 0.5/200, true max(1e-4, 0.05 d)/d + 70; overview distance 60 or 120) with `CoreTests/ScaleModeTests.swift` (true-mode ratio of drawn radius to drawn distance within 0.1 % of the catalog; enhanced equals A14-P02's mapping) (FR-A14-310, 311; SC-A14-302) — Verified 2026-11-15: 2026-11-15: ScaleMode (enhanced 4 sqrt r with A14-P01 display radii x 0.6 / x 0.5; true-relative 2 units per AU for positions and radii; labels; camera distance 60 or 120; clip ranges); ScaleModeTests pass in .autonomy/checks/A14-P03.sse-core-ios27.json exit 0 on sim-27.2 (true-mode radius-to-distance ratios within 0.1 percent)
- [X] T-A14-305 [US2] `SolarState` schema 3 in `Core/SolarState.swift` (schema 2 fields + "`scaleMode` 0…1"; migrates schema 2 with mode 0 and schema 1; damaged or newer refused) with `CoreTests/SolarStateSchema3Tests.swift` and the existing state tests adjusted (FR-A14-310, 330) — Verified 2026-11-15: 2026-11-15: SolarState schema 3 (scaleMode 0/1; schema 2 and 1 migrate with the enhanced mode; mode 2 refused out-of-range, missing damaged); SolarStateSchema3Tests and adjusted SolarStateTests pass in .autonomy/checks/A14-P03.sse-core-ios27.json exit 0 on sim-27.2

## Phase 3: Stories 2–4 — experience model

- [X] T-A14-306 [US2] Update `Experience/Adapter/SolarCore.swift` (action `scale.mode [0…1]`, non-whole refused `a14.invalid-choice`; migration 2 → 3; canvas description with the mode's label; distance words unchanged) with `SolarCoreTests` adjusted (FR-A14-310, 312) — Verified 2026-11-15: 2026-11-15: SolarCore scale.mode [0...1] (non-whole refused a14.invalid-choice), migration steps 1 to 2 and 2 to 3, digest a14.solar.v3, canvas description ending with the mode's label; SolarCoreTests (scale action, schema-2 envelope migrates) and SolarSessionTests pass in .autonomy/checks/A14-P03.sse-exp-model.json exit 0 on sim-27.2
- [ ] T-A14-307 [P] [US3] Add `Experience/FocusFlight.swift` (pure; 30 frames, smoothstep on target, log-space distance, clearance push-out to 3 × drawn radius + 0.5 × near, Reduce Motion one frame, restart from the current eye) and precision helpers (camera-relative Double → Float) with `ExperienceTests/{FocusFlightTests,PrecisionTests}.swift` (72 ordered pairs × 31 frames × 2 modes keep the eye outside every body and the focused body inside near/far; Reduce Motion one frame; restart; Float error < 0.1 px at 2,000 px and 60° for every body, both modes, zoom steps −1, 0, 12) (FR-A14-320–322; SC-A14-303, 304)

## Phase 4: Story 1 — drawing

- [ ] T-A14-308 [US1] Add `Experience/SceneMeshes.swift` (48 × 24 spheres with recipe colours, orbit paths for both scale modes (128 samples each), two-sided ring annulus with the Cassini band tilted by Saturn's axial tilt, 400-star mesh centred on the eye at 0.9 × far, marker rings) and update `Experience/OrbitLayout.swift`, `Experience/SolarPresenter.swift` (scale mode mapping, markers below 2 px, starfield, flight with Reduce Motion from `SolarSystemExplorerExperience.make`, camera-relative model matrices, all renderers made and released together) and `Experience/SolarControls.swift` (Scale picker with value and announcement), with `ExperienceTests/{SceneMeshesTests,SolarBodiesRenderTests}.swift` and the existing render and session tests adjusted (coloured bodies; the ring visible around Saturn; switching the scale changes pixels and the Scale control's value and spoken description name the active mode; markers drawn only for bodies below 2 px in the true-relative mode; context recreation redraws within a pixel tolerance) (FR-A14-301–303, 311, 312, 320)
- [ ] T-A14-309 [US2] Update `Experience/Adapter/SolarManifest.swift` (state schema 3; fixture `fixture-earth-true-scale`; digests re-pinned) and regenerate `SolarSystemExplorer/scenario-manifest.json` with `SolarManifestTests` adjusted (FR-A14-330)

## Phase 5: Records and evidence

- [ ] T-A14-310 Contract `docs/apps/solar-system-explorer/visualcore-contract.json`: G-BODIES closed by "A14-P03" (label placement moved to G-TOURS with its rationale; the 3D noise recorded as app-local); rows M06, M07, M09, M13, M21, M23 updated (`--name contract -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`)
- [ ] T-A14-311 Solar System Explorer tests on sim-27.2 (`--name sse-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`) (SC-A14-301–305)
- [ ] T-A14-312 App build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`) (SC-A14-305)
- [ ] T-A14-313 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A14-314 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P03; update README.md in the record commit (rule 16)

## Dependencies

T-A14-301 → (302 ∥ 303 ∥ 304) → 305 → 306 → 308 → 309 → 310 → 311 → 312 → 313 → 314; 307 needs only 304 (ScaleMode's drawn radii and near/far) and runs in parallel with 305–306; 308 needs 302–307.

## Parallel examples

Agent A: T-A14-302. Agent B: T-A14-307 once T-A14-304 lands (against contracts/bodies.md and ScaleMode). Lead: 303–306, 309.
Agent C: T-A14-308 after 302–307.

## Implementation strategy

MVP: surfaces and the ring (302–303), then scale modes and state (304–306), then flight and precision (307), then
drawing (308–309). Review checkpoints after 305 (core tests), after 307 and at 311.
