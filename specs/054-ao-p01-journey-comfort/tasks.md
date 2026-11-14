# Tasks: Audio Odyssey — Phase 01 Journey/camera comfort contract

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A07-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A07
(owner, 2026-11-14).

## Phase 1: Setup

- [X] T-A07-101 Baseline: cite the last package evidence on an unchanged `Packages/ExperiencesCreative` and VisualCore source tree (`.autonomy/migration/checks/X-A06.host-2.json`, `.autonomy/checks/A07-P00.app-build.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: Verified 2026-11-14: cited .autonomy/migration/checks/X-A06.host-2.json and .autonomy/checks/A07-P00.app-build.json (unchanged ExperiencesCreative and VisualCore sources since); no rerun (owner ruling 2026-11-14)

## Phase 2: Foundational (VisualCore, stories 1 and 2)

- [X] T-A07-102 [P] [US2] Write `Packages/VisualCore/Tests/VisualCoreMathTests/{CameraRailTests,RailFlightTests,OriginRebaseTests}.swift` first, then `Packages/VisualCore/Sources/VisualCoreMath/{CameraRail,ComfortLimits,RailFlight,OriginRebase}.swift` per contracts/api.md (closed centripetal Catmull–Rom, "64 samples per span", level frame, near-vertical tangents "within 30°" refused, distance wraps; `ComfortLimits.standard` 8 / 1.5 / 45°/s / 0.25 / 0 and `.reducedMotion` 2.5 / 0.75 / 45°/s / 0 / 0; `RailFlight.maxStep` 0.1 s; `OriginRebase.threshold` 1,024; all public with `///` docs); tests: equal distance steps within 1% spacing over 10 seeded rails, frames continuous across the wrap, `orbitCamera(at:)` eye and look direction equal the pose, 200 seeded speed sequences never exceed speed/acceleration, reduced motion sway 0 and speed ≤ 2.5, NaN/negative dt ignored, same inputs → same states, rebased positions 10^7 units out within 1e-3 while plain Float is not (FR-A07-101–104; SC-A07-101–103) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.math-host.json exit 0 (21 tests in 3 suites: CameraRail spacing <1% over 10 rails, wrap continuity, level frame, turn rate, refusals, orbitCamera = pose; RailFlight 200 seeded sequences within limits, reduced motion sway 0 and speed <= 2.5, dt capped and NaN ignored; OriginRebase 1e7 within 1e-3)

## Phase 3: User Story 1 — fly through a world on a calm rail (P1) 🎯

- [X] T-A07-103 [P] [US1] Create the core target `Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyWorld,JourneyState,JourneyRail,WorldPieces}.swift` and `CoreTests/{JourneyStateTests,JourneyRailTests,WorldPiecesTests}.swift`: `JourneyState` schema 1 per data-model.md ("distance Double ≥ 0, finite"; unknown world refused), `JourneyRail.make(seed:)` (12 seeded control points on a perturbed ellipse, minimum turn radius ≥ 7 ÷ 45°/s), `WorldPieces.piece(_:index:rail:seed:)` for tunnel / landscape / star corridor per clarification 4 ("pieceLength 8", "vertexBudget 4,096"); tests: shared edges of pieces i, i+1 within 1e-9 for every world and 5 seeds, star ownership by distance, budget, determinism, distinct worlds, median generation time measured and printed (no assertion on CI) (FR-A07-110, 111; SC-A07-104) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.core-ios27.json exit 0 (AudioOdysseyCoreTests on sim-27.2: joins within 1e-9 for 3 worlds x 5 seeds incl. the wrap, star ownership, budget, determinism, distinct worlds, schema-1 validation, rail turn radius >= 14 (>= 8.92 comfort; landscape strip needs 12+); stars kept 1.5-6 from the rail so none crosses the camera)
- [X] T-A07-104 [US1] Create the experience targets in `Packages/ExperiencesCreative/Package.swift` (`AudioOdysseyCore`, `AudioOdysseyCoreTests`, `AudioOdysseyExperience`, `AudioOdysseyExperienceTests`, product `AudioOdysseyExperience`) and `Experience/{Adapter/OdysseyCore.swift,OdysseyPresenter.swift,OdysseyControls.swift,AudioOdysseyExperience.swift}`: adapter (ExperienceCore; actions world.select, speed.select, flight.pause, flight.resume, journey.reseed; digest; snapshot schema 1; advance by host steps with the active ComfortLimits), presenter (window of 2 behind and 8 ahead through `DepthMeshPass` with `CameraRail.orbitCamera`, rebased model matrices, one colour per world, spoken description, pause on suspend), controls (world picker, speed picker, pause/resume, labels and identifiers); tests `ExperienceTests/{OdysseyCoreTests,OdysseySessionTests,OdysseyRenderTests}.swift` (world switch keeps distance and speed; Reduce Motion caps speed and sway; pause keeps state; rendered frames of the three worlds differ; no context created by the experience) (FR-A07-120–122) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.experience-ios27.json exit 0 (AudioOdysseyExperienceTests on sim-27.2: 18 Swift Testing + 8 XCTest: actions, digest, snapshot, world switch keeps distance and speed, Reduce Motion speed <= 2.5 and sway 0, pause/resume, three worlds render distinct non-blank frames, no context of its own); Reduce Motion reaches the core as the non-digest action comfort.reduce-motion (recorded in OdysseyCore's header, as permission.mirror in A06)

## Phase 4: User Story 2 — comfortable motion (P1)

- [X] T-A07-105 [US2] Register: `Catalog/registrations.json` entry for a07 (capabilities, quality_tiers ["level-0"], palette, content), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency on the product, `xcodegen generate --spec project.yml` (FR-A07-120) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.app-unit.json exit 0 (app builds with a07 as a candidate; 78 unit tests); Catalog/registrations.json a07 entry; project.yml dependency; xcodegen generated
- [X] T-A07-106 [US2] Write `Experience/Adapter/OdysseyManifest.swift` (nine standard scenarios + fixture-1 watertight joins, fixture-2 comfort limits) and generate `Packages/ExperiencesCreative/AudioOdyssey/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), with `ExperienceTests/OdysseyManifestTests.swift` (FR-A07-120) — Verified 2026-11-14: Verified 2026-11-14: scenario-manifest.json generated (TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1; 9 standard + fixture-1 joins + fixture-2 comfort, 6 controls); OdysseyManifestTests pass in .autonomy/checks/A07-P01.experience-ios27.json; runner .autonomy/checks/A07-P01.verify-27.json 0 failures

## Phase 5: Polish & evidence

- [X] T-A07-107 VisualCoreMath host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name math-host -- swift test --package-path Packages/VisualCore --filter "CameraRailTests|RailFlightTests|OriginRebaseTests"`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.math-host.json exit 0 (21 tests; VisualCoreMath sources unchanged since)
- [X] T-A07-108 Core tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyCoreTests`; the package is iOS-only, so its Core tests run on the simulator as for A06) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P01.core-ios27.json exit 0 (18 Core tests on sim-27.2; Core sources unchanged since)
- [ ] T-A07-109 Experience tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name experience-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyExperienceTests`)
- [ ] T-A07-110 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A07-111 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27`)
- [ ] T-A07-112 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A07-113 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; `Packages/VisualCore/README.md` (VisualCoreMath rail, comfort, rebasing); contract G-CAMERARAIL and G-ORIGINREBASE closed by "A07-P01" and `check_app_contract.py --app audio-odyssey --render`
- [ ] T-A07-114 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P01 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A07-115 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A07-P01

## Dependencies

T-A07-101 → (102 ∥ 103) → 104 → 105 → 106 → Polish. 103 depends on the 102 contract only (`CameraRail` API).

## Parallel examples

Agent A: T-A07-102. Agent B: T-A07-103 (against contracts/api.md; builds after A lands). Lead: 104 skeleton, 105,
106, docs, runs, commits; Agent C may write the presenter and controls of 104 once 102 and 103 pass.

## Implementation strategy

MVP: rail, comfort and rebasing (US2 foundation) with three worlds on the rail (US1) and seamless pieces (US3, inside
T-A07-103); evidence last.
