# Tasks: Solar System Explorer — Phase 02 Approximate orbit computation with fixtures

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/kepler-orbit.md](contracts/kepler-orbit.md), [contracts/orbit-view.md](contracts/orbit-view.md),
[quickstart.md](quickstart.md). Gate A14-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; reference regression and iOS 26 at
X-A14. Precedents: `specs/096-lm-p01-solver/tasks.md` (VisualCore addition), `specs/103-sse-p01-catalog/tasks.md`.

## Phase 1: Setup

- [X] T-A14-201 Baseline: cite the last evidence on the unchanged tree (`.autonomy/checks/A14-P01.{sse-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A14-P01.sse-ios27.json, A14-P01.app-unit.json and A14-P01.verify-27.json (exit 0) on the tree recorded at A14-P01, unchanged since apart from spec documents (no rerun)

## Phase 2: Foundational — VisualCore (story 2)

- [X] T-A14-202 [US2] Add `Packages/VisualCore/Sources/VisualCoreMath/KeplerOrbit.swift` per contracts/kepler-orbit.md ("init nil for non-finite values, e ∉ [0, 1), a ≤ 0, n ≤ 0"; Newton from E₀ = M for e < 0.8 else π, at most 32 steps, stop below 1e-12; M normalised to (−π, π]; position rotated by ω, i, Ω; non-finite time treated as the epoch; `///` on every public symbol) and host tests `Packages/VisualCore/Tests/VisualCoreMathTests/KeplerOrbitTests.swift` (refusals; residual < 1e-10 for e ∈ {0, 0.2056, 0.5, 0.9, 0.95} at 24 anomalies; circular radius constant; perihelion a(1−e) and aphelion a(1+e); period return < 1e-6 rad; inclination lifts the position out of the plane; finite results) (FR-A14-201, 202; SC-A14-202) — Verified 2026-11-15: 2026-11-15: VisualCoreMath.KeplerOrbit (refusals, Newton from M or π at most 32 steps below 1e-12, position rotated by ω, i, Ω; non-finite time is the epoch) with KeplerOrbitTests 9 passing in .autonomy/checks/A14-P02.visualcore-kepler.json exit 0 (residual < 1e-10 for e 0…0.95 at 24 anomalies, periapsis/apoapsis, period return, inclination, node rotation)
- [X] T-A14-203 Document the type in `Packages/VisualCore/README.md` (Kepler orbit paragraph beside 2D ray casting) and update the API baseline (`python3 scripts/check_public_api.py --update`); checks `--name visualcore-kepler -- swift test --package-path Packages/VisualCore --filter KeplerOrbitTests`, `--name visualcore-api -- python3 scripts/check_public_api.py` and `--name visualcore-docs -- python3 scripts/check_documented_api.py` (FR-A14-203) — Verified 2026-11-15: 2026-11-15: Kepler orbit paragraph in Packages/VisualCore/README.md; API baseline updated (15 added, 0 removed); .autonomy/checks/A14-P02.visualcore-kepler.json, A14-P02.visualcore-api.json and A14-P02.visualcore-docs-2.json exit 0 (the first visualcore-docs run, exit 2, omitted the required --sources argument and is kept)

## Phase 3: Foundational — the core model (stories 2, 4)

- [X] T-A14-204 [P] [US2] Add `Packages/ExperiencesCreative/SolarSystemExplorer/Core/{OrbitElements,SimulatedDate,OrbitModel}.swift` per data-model.md (eight planets with the Standish J2000.0 values of Clarifications Q2, "e in [0, 1); a > 0; every value finite"; ω = ϖ − Ω, M₀ = L − ϖ, n = 2π / catalog sidereal period; `SimulatedDate` "−18,262.5 … 18,627.5; steps {±1, ±30, ±365}; label `yyyy-MM-dd` UTC"; `OrbitModel.position(bodyID:day:)` in AU through `KeplerOrbit`, `distanceAU`), the `VisualCoreMath` dependency of the `SolarSystemExplorerCore` and `SolarSystemExplorerCoreTests` targets in `Packages/ExperiencesCreative/Package.swift` (as `LightMazeCore`), and tests `CoreTests/{OrbitElementsTests,SimulatedDateTests,OrbitFixtureTests}.swift` (Earth longitude 100.38° ± 0.3° at J2000; Earth 0.98329 / 1.01671 AU ± 0.2 %; Mars 1.381–1.666 AU ± 0.5 %; period return; 100 steps forward and back exact; range ends accepted, one step beyond refused; negative mean longitudes (Mars, Neptune) normalised to the same position as +360°) (FR-A14-210–212; SC-A14-201, 203) — Verified 2026-11-15: 2026-11-15: OrbitElements (Standish J2000.0 values, validation), SimulatedDate (range, steps, UTC label), OrbitModel (KeplerOrbit per planet, positions in AU, distance in km) and the VisualCoreMath dependency of the core targets; OrbitElementsTests, SimulatedDateTests and OrbitFixtureTests pass in .autonomy/checks/A14-P02.sse-core-ios27.json exit 0 on sim-27.2 (51 core tests; Earth longitude 100.38 deg, Earth 0.98329/1.01671 AU, Mars 1.381-1.666 AU, period return, exact steps); range end corrected in the spec to 2051-01-01 00:00 UTC (18,627.5 days)
- [X] T-A14-205 [US4] Add one `SourceRecord` per planet for quantity `orbital-elements` (Standish, JPL SSD, epoch J2000.0, units "AU, degrees", license `public-domain` with the basis stated) in `Core/SourceRecords.swift`, extend `CitationAudit` coverage and regenerate `docs/apps/solar-system-explorer/data-sources.md` (`UPDATE_DATA_SOURCES=1 TEST_RUNNER_UPDATE_DATA_SOURCES=1`) (FR-A14-210) — Verified 2026-11-15: 2026-11-15: SourceRecord.orbitalElements (8 records, Standish JPL SSD, J2000.0, AU and degrees, public-domain), CitationAudit.elementProblems and the Orbital elements section of data-sources.md (regenerated with UPDATE_DATA_SOURCES=1); CitationAuditTests (elements audited, committed document matches) pass in .autonomy/checks/A14-P02.sse-core-ios27.json exit 0 on sim-27.2
- [X] T-A14-206 [US3] `SolarState` schema 2 in `Core/SolarState.swift` ("selection 0…8, dayOffset, yawSteps (Int), pitchDegrees 5…85 (5 + 10k), zoomSteps −1…12"; migration from schema 1 with dayOffset 0, yaw 0, pitch 35, zoom 0; damaged or newer refused) with `CoreTests/SolarStateSchema2Tests.swift` and `SolarStateTests` adjusted (FR-A14-211, 222) — Verified 2026-11-15: 2026-11-15: SolarState schema 2 (selection, dayOffset, yawSteps, pitchDegrees 5 + 10k in 5...85, zoomSteps -1...12; schema 1 migrates; damaged, newer, out-of-range refused); SolarStateSchema2Tests and the adjusted SolarStateTests pass in .autonomy/checks/A14-P02.sse-core-ios27.json exit 0 on sim-27.2; zoom 12 is 4.12 scene units (spec and research corrected from 4.03)

## Phase 4: Story 1 and 3 — orbit view, focus and camera

- [ ] T-A14-207 [US1] Add `Experience/OrbitLayout.swift` (scene position (x, z, −y)·4√r / r; orbit path of 128 samples; camera target, yaw 15° steps, pitch, distance 60·1.25^−n) and update `Experience/SolarPresenter.swift` (Sun and planets at their positions, display radii × 0.6 and Sun × 0.5, eight orbit tubes radius 0.04, 6 sides, closed, all renderers created once and released together; camera from the state and the focused body; canvas description with date, focused body, distance in AU and km and "Distances and sizes not to scale") with `ExperienceTests/{OrbitLayoutTests,SolarOrbitRenderTests}.swift` (mapping values for Mercury and Neptune; a non-blank frame; a date step changes the drawn pixels; focusing changes the view) (FR-A14-220; SC-A14-204)
- [ ] T-A14-208 [US3] Update `Experience/Adapter/SolarCore.swift` (actions `date.step`, `camera.orbit`, `camera.tilt`, `camera.zoom`, `view.reset`; refusals `a14.invalid-step`, `a14.out-of-range`) and `Experience/SolarControls.swift` (date buttons −365, −30, −1, +1, +30, +365 with the date as value; orbit, tilt, zoom and reset buttons; distance on the fact card; every control labelled with a value) with `SolarCoreTests` and `SolarSessionTests` adjusted (each new action and refusal; the card's km distance equals its AU distance × 149,597,870.7 within rounding; every control has a label and value) (FR-A14-211, 221; story 4)
- [ ] T-A14-209 [US1] Update `Experience/Adapter/SolarManifest.swift` (state schema 2; fixtures keep the five bodies and add `earth-2025` by date steps) and regenerate `SolarSystemExplorer/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) with `SolarManifestTests` adjusted (FR-A14-222)

## Phase 5: Records and evidence

- [ ] T-A14-210 Contract `docs/apps/solar-system-explorer/visualcore-contract.json`: G-ORBIT closed by "A14-P02"; rows M05, M07, M12 updated (`--name contract -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`)
- [ ] T-A14-211 Solar System Explorer tests on sim-27.2 (`--name sse-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`) (SC-A14-201–205)
- [ ] T-A14-212 App build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`) (SC-A14-205)
- [ ] T-A14-213 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A14-214 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P02; update README.md in the record commit (rule 16)

## Dependencies

T-A14-201 → 202 → 203; 202 → 204 → 205; 204 → 206 → (207 ∥ 208) → 209 → 210 → 211 → 212 → 213 → 214.

## Parallel examples

Agent A: T-A14-202 (VisualCore). Agent B: T-A14-204 core files written against contracts/kepler-orbit.md while A
works. Agent C: T-A14-207/208 after 206. Lead: README, API baseline, Package.swift, 205, 206, manifest regeneration,
contract, runs, commits.

## Implementation strategy

MVP: VisualCore Kepler with tests (202–203), then the model with the fixture (204–206), then the drawn orbit view and
controls (207–209). Review checkpoints after 203 (host tests and API), after 206 (core tests on sim-27.2) and at 211.
