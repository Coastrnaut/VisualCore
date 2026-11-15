# Tasks: Digital Aquarium — Phase 03 Editing, feeding and save system

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A09-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; no VisualCore change in this phase.

## Phase 1: Setup

- [X] T-A09-301 Baseline: cite the A09-P02 evidence on the unchanged tree (`.autonomy/checks/A09-P02.aquarium-ios27.json`, `.autonomy/checks/A09-P02.app-unit.json`, `.autonomy/checks/A09-P02.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: no aquarium or app source change since the A09-P02 evidence (only specs and the regenerated catalog hash in Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/experiences.json from the record); cites .autonomy/checks/A09-P02.{aquarium-ios27,app-unit,verify-27}.json

## Phase 2: Foundational (core schema 3)

- [X] T-A09-302 Habitat document schema 3 in `Packages/ExperiencesCreative/DigitalAquarium/Core/HabitatDocument.swift`: `FoodPellet` ("position: Vec2", finite, inside the swim bounds), `food: [FoodPellet]` ("≤ 12; missing → []"), `currentSchema = 3`, `migrated(catalog:)` brings schemas 1 and 2 to 3, validation of the food count and positions; habitat starter documents have no food; tests in `CoreTests/{HabitatDocumentTests,HabitatMigrationTests}.swift` (FR-A09-320) — Verified 2026-11-14: 2026-11-14: HabitatDocument schema 3 (FoodPellet, food ≤ 12, migrated 1/2 → 3, validation); HabitatDocumentTests and HabitatMigrationTests pass in DigitalAquariumCoreTests (72 tests) on sim-27.2

## Phase 3: User Story 1 — feeding the fish (P1) 🎯

- [X] T-A09-303 [US1] `Packages/ExperiencesCreative/DigitalAquarium/Core/Feeding.swift` per contracts/api.md and research D2 (3 pellets at x − 0.25, x, x + 0.25 clamped into the swim bounds; refused whole beyond 12; sink 0.5 units/s; eaten within 0.5 × length + 0.15, one per fish per step, fish in document order, nearest pellet first; removed at or below the floor; seek force toward the nearest pellet within 4 units, weight 2.5) and the seek and feeding step in `Core/AquariumSimulation.swift` (seek added before the existing cap; feeding step after the move); tests in `CoreTests/FeedingTests.swift` (drop positions and refusal at the limit; sinking pace; floor removal; eating rule; seek direction and range; SC-A09-302 ≥ 18 of 20 seeds; bounds and speed still hold with food) (FR-A09-301–303; SC-A09-301, 302) — Verified 2026-11-14: 2026-11-14: Feeding (drop, sink, eat, floor, seek) and seek/feeding step in AquariumSimulation; FeedingTests 11 tests, SC-A09-302 20/20 seeds; DigitalAquariumCoreTests 72 pass on sim-27.2

## Phase 4: User Story 2 — arranging decorations (P1)

- [X] T-A09-304 [P] [US2] `Packages/ExperiencesCreative/DigitalAquarium/Core/DecorEditing.swift` (place with rotation 0 and scale 1 at the point clamped into the tank, refused at 12; move clamped; remove; `tankPoint(fractionX:fractionY:)`) with `CoreTests/DecorEditingTests.swift` (FR-A09-310; SC-A09-303) — Verified 2026-11-14: 2026-11-14: DecorEditing (place, move, remove, tankPoint); DecorEditingTests 6 tests pass on sim-27.2
- [X] T-A09-305 [P] [US2] `Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumGestures.swift` (declarations tap 1 → `food.drop`, long press 2 → `decor.place`, drag 3 starting on a piece → `decor.move` on began and changed; view points → tank fractions with the presenter's centred scale; reset) with `ExperienceTests/AquariumGestureTests.swift` (synthetic pointer events: a quick tap feeds and never places or moves; a 0.6 s hold places and never feeds; a drag from a piece moves it; a drag from water sends nothing; a second finger cancels; a hold of 0.4 s sends nothing) (FR-A09-311; SC-A09-304) — Verified 2026-11-14: 2026-11-14: AquariumGestures over GestureArbiter (tap → food.drop, long press → decor.place, drag on a piece → decor.move for every move; second finger suppresses); AquariumGestureTests 11 tests pass on sim-27.2
- [X] T-A09-306 [US2] Core actions and snapshot schema 3 in `Experience/Adapter/AquariumCore.swift` (`food.drop [0…1, 0…1]`, `decor.kind [0…2]`, `decor.place [0…1, 0…1]`, `decor.move [0…11, 0…1, 0…1]`, `decor.remove [0…11]`; refusals `a09.food-full`, `a09.decor-full`, `a09.no-such-decor`, `a09.invalid-choice`; `decorKind` in `AquariumState`; habitat change clears food and keeps the kind; `MigrationChain(currentVersion: 3)` with step 2 adding `decorKind` 0; `schemaTwoExample()` and the registry in `Apps/VisualCore/App/ExperienceRegistry.swift`; restore refuses an out-of-range kind) with tests in `ExperienceTests/AquariumCoreTests.swift` (every action and refusal; a feed while paused adds pellets that do not move until the motion resumes; a move of a just-removed index is refused with `a09.no-such-decor`; habitat change clears food and keeps the kind) (FR-A09-301, 310, 320) — Verified 2026-11-14: 2026-11-14: five actions with refusals, decorKind, snapshot schema 3 (chain 1→2→3), schemaTwoExample in the registry, damaged kind refused; AquariumCoreTests 19 tests pass on sim-27.2; scenario-manifest.json regenerated for the schema-3 digests
- [X] T-A09-307 [US2] Presenter and controls: pellets drawn as small circles; `pointer(_:viewSize:port:)` through `AquariumGestures`; `gestureActions` {food.drop, decor.place, decor.move} ⊆ `nativeActions`; description names pellet and decor counts; controls Feed, kind picker, Add, piece picker, Move left/right/up/down, Remove, each labelled with an identifier in `Experience/{AquariumPresenter,AquariumControls}.swift`; tests in `ExperienceTests/{AquariumRenderTests,AquariumSessionTests}.swift` (pellets change the frame; `GestureAlternatives.missing` is empty; description counts) (FR-A09-311–313) — Verified 2026-11-14: 2026-11-14: pellets drawn, pointer through AquariumGestures, gestureActions ⊆ nativeActions, description names pellet and decor counts, Feeding and Decorations controls; AquariumRenderTests 16 tests pass on sim-27.2

## Phase 5: User Story 3 — leaving and returning (P2)

- [X] T-A09-308 [US3] Manifest fixtures 8 (feeding), 9 (decor editing) and 10 (no fast-forward with food) in `Experience/Adapter/AquariumManifest.swift`, regenerate `scenario-manifest.json`, update `ExperienceTests/AquariumManifestTests.swift`; session test: with pellets sinking, a suspension of any length and a resume leave step, fish and pellets identical and continue; schema-1 and schema-2 snapshots restore (FR-A09-321, 322; SC-A09-305) — Verified 2026-11-14: 2026-11-14: fixtures 8 (feeding), 9 (decor editing), 10 (no fast-forward with food); manifest regenerated; AquariumManifestTests 4 and AquariumSessionTests 9 tests pass on sim-27.2 (suspension with food holds step, fish and pellets)

## Phase 6: Polish & evidence

- [X] T-A09-309 Digital Aquarium tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name aquarium-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests`; each test < 10 s) (SC-A09-306) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P03.aquarium-ios27.json exit 0 (core 72 + experience 55 XCTest + 4 manifest tests, each < 10 s)
- [X] T-A09-310 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P03.app-unit.json exit 0 (registry with the schema-1 and schema-2 examples)
- [X] T-A09-311 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P03.verify-27.json exit 0 (nine standard scenarios PASS on 27.2 per .autonomy/logs/A09-P03.verify-27.log; the ten fixtures are proved by AquariumManifestTests in T-A09-309)
- [X] T-A09-312 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P03.experience-packages.json exit 0
- [X] T-A09-313 Contract G-FEEDPLACE closed by "A09-P03" (M10 available) in `docs/apps/digital-aquarium/visualcore-contract.json` and `python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app digital-aquarium --render` — Verified 2026-11-14: 2026-11-14: G-FEEDPLACE closed by A09-P03; M10 available (.autonomy/checks/A09-P03.contract.json exit 0)
- [ ] T-A09-314 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P03 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A09-315 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A09-P03; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A09-301 → 302 → (303 ∥ 304 ∥ 305) → 306 (needs 303, 304) → 307 (needs 305, 306) → 308 → Polish.

## Parallel examples

Agent A: T-A09-302 then 303. Agent B: T-A09-304 and 305. Agent C: T-A09-307 after the lead's 306. Lead: 306, 308,
docs, contract, runs, commits.

## Implementation strategy

MVP: feeding (core and tap); then decor editing; then the save and resume fixtures; evidence last.
