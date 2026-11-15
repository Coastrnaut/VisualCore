# Tasks: Digital Aquarium — Phase 02 Fish movement and visual prototype

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A09-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A09
(owner, 2026-11-14).

## Phase 1: Setup

- [X] T-A09-201 Baseline: cite the A09-P01 evidence on the unchanged tree (`.autonomy/checks/A09-P01.aquarium-ios27.json`, `.autonomy/checks/A09-P01.app-unit.json`, `.autonomy/checks/A09-P01.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: no source change since the A09-P01 record (only specs); cites .autonomy/checks/A09-P01.{aquarium-ios27,app-unit,verify-27}.json

## Phase 2: Foundational (VisualCore steering, story 1)

- [X] T-A09-202 [P] [US1] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/SteeringTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreSimulation/Steering.swift` per contracts/api.md and research D1–D2 (`SteeringAgent`, `SteeringBounds`, `SteeringParameters`, `NeighbourSearch.neighbours(of:in:radius:limit:)`, `Steering.force(for:agents:neighbours:parameters:bounds:)`, `Steering.capped(_:to:)`; public with `///` docs); tests: the search returns ≤ max(0, limit) indices, never self, nearest first with ties by index, only within the radius, nothing for an out-of-range index, a non-finite radius or a non-finite agent; separation pushes apart and separates coincident agents deterministically (lower index +x); alignment and cohesion act only within a group; boundary force points inward inside the margin and is zero outside it and for invalid bounds; every force is finite and ≤ maxForce; identical input gives identical output (FR-A09-201–203; SC-A09-205) — Verified 2026-11-14: 2026-11-14: Steering.swift (SteeringAgent, SteeringBounds, SteeringParameters, NeighbourSearch, Steering); SteeringForceTests + NeighbourSearchTests 16 tests pass (CI=1 swift test)

## Phase 3: User Story 1 — fish that swim together (P1) 🎯

- [X] T-A09-203 [US1] Core document and catalog (schema 2): in `Packages/ExperiencesCreative/DigitalAquarium/Core/SpeciesCatalog.swift` add `DecorShape` {rock, shell}, `DecorKind` (id, name, shape, color, size "0.3…2.0", author, license), `DecorSpot` (decorId, position inside the tank, rotation "−π…π", scale "0.5…2.0"), `StarterHabitat.decor` (≤ 12), `SpeciesCatalog.decor`, `decor(id:)` and bundled kinds round-rock, flat-rock, spiral-shell (MIT, project author) with Reef 3 and Kelp 2 starter pieces; validate them in `Core/CatalogDecoder.swift` and audit them in `Core/LicenseAudit.swift`; in `Core/HabitatDocument.swift` set `currentSchema = 2`, add `FishAgent.turn` (decodes 0 when missing), `DecorPlacement.rotation`/`scale` (decode 0/1 when missing), starter documents carry the habitat's decor, `migrated(catalog:)` (schema 1 → 2, starter decor added when empty) and validation of rotation, scale and decor kinds; tests in `CoreTests/{SpeciesCatalogTests,LicenseAuditTests,HabitatDocumentTests}.swift` and new `CoreTests/HabitatMigrationTests.swift` (FR-A09-212; SC-A09-204) — Verified 2026-11-14: 2026-11-14: decor kinds and starter decor, document schema 2 (turn, rotation, scale), migrated(catalog:), validation; DigitalAquariumCoreTests 44 tests pass on sim-27.2; content-licenses.md regenerated
- [X] T-A09-204 [US1] Schooling in `Packages/ExperiencesCreative/DigitalAquarium/Core/AquariumSimulation.swift` per research D3 (forces from the start-of-step state; `parameters(for:)` species tuning; reduced seeded wander; speed 0.5 × cruise…max; Phase 01 clamp and reflection; smoothed `turn`), `Core/SchoolMetrics.swift` (mean same- and cross-species distance, heading agreement as the length of each species' mean unit heading averaged over species with ≥ 2 fish) and `CoreTests/SchoolingTests.swift` (SC-A09-201 and 202 for ≥ 18 of 20 seeds after 1,800 steps; a lone fish wanders; result independent of fish order; coincident fish separate; paused, no position, velocity or `turn` changes) plus `CoreTests/AquariumSimulationTests.swift` (bounds and speed over 10,000 steps × 20 seeds, no speed below half cruise) (FR-A09-210; SC-A09-201–203) — Verified 2026-11-14: 2026-11-14: schooling via VisualCore steering (start-of-step forces, wander 0.35, speed 0.5×cruise…max, smoothed turn), SchoolMetrics; SchoolingTests Reef 20/20 closer and 19/20 aligned, Kelp 19/20 and 18/20; DigitalAquariumCoreTests 54 tests pass on sim-27.2

## Phase 4: User Story 2 — fish that look alive (P1)

- [X] T-A09-205 [US2] Swim animation and decor drawing in `Packages/ExperiencesCreative/DigitalAquarium/Experience/AquariumPresenter.swift` per research D5 (body wave 0.06 body lengths, tail swing 0.15 body lengths, bend `turn` × 0.12 s capped ±0.35 rad, Reduce Motion × 0.5 on all three; rocks and shells as polygons at each decor transform) with tests in `ExperienceTests/AquariumRenderTests.swift` (a faster fish's outline repeats sooner; a left turn bends the outline left; mirrored by heading; Reduce Motion halves the displacement; two moments of a swim draw different frames; decor polygons follow rotation and scale; the state digest is unchanged by Reduce Motion) (FR-A09-211) — Verified 2026-11-14: 2026-11-14: body wave, tail sweep, turn bend, Reduce Motion ×0.5, decor polygons; AquariumRenderTests 12 tests pass on sim-27.2

## Phase 5: User Story 3 — the aquarium is saved as it was (P2)

- [X] T-A09-206 [US3] Snapshot schema 2 in `Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumCore.swift` (the envelope's schema version through `MigrationChain(currentVersion: 2)`, as every experience does; a schema-1 payload's document is migrated before validation; saves write schema 2), the stored schema-1 payload `AquariumCore.schemaOneExample()` passed to the registry in `Apps/VisualCore/App/ExperienceRegistry.swift` (the framework's migration check, as Oscilloscope Studio does) and tests in `ExperienceTests/{AquariumCoreTests,AquariumSessionTests}.swift` (round trip keeps species, decor transforms and lighting; the schema-1 payload restores with starter decor; an invalid migrated payload is refused) (FR-A09-212; SC-A09-204) — Verified 2026-11-14: 2026-11-14: snapshot schema 2 via MigrationChain(currentVersion: 2), schemaOneExample in the registry; schema-1 migration and decor round trip tests pass (AquariumCoreTests 14, AquariumSessionTests 7 on sim-27.2)
- [X] T-A09-207 [US3] Manifest fixtures 6 (schooling, Reef, 1,800 steps) and 7 (save/load, Kelp, bright, 240 steps) in `Experience/Adapter/AquariumManifest.swift`, regenerate `scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), update `ExperienceTests/AquariumManifestTests.swift` (seven fixtures; fixture 6 meets the schooling metrics; fixture 7 survives a snapshot round trip) and regenerate `docs/apps/digital-aquarium/content-licenses.md` with the decor kinds (FR-A09-213) — Verified 2026-11-14: 2026-11-14: fixtures 6 (schooling) and 7 (save/load), scenario-manifest.json regenerated; AquariumManifestTests 4 tests pass on sim-27.2

## Phase 6: Polish & evidence

- [X] T-A09-208 VisualCore host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name visualcore-host -- swift test --package-path Packages/VisualCore --filter "SteeringForceTests|NeighbourSearchTests"`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P02.visualcore-host.json exit 0 (SteeringForceTests, NeighbourSearchTests 16 tests)
- [X] T-A09-209 Digital Aquarium tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name aquarium-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests`; each test < 10 s) (SC-A09-205) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P02.aquarium-ios27.json exit 0 (core 54 + experience 37 tests, each < 10 s)
- [X] T-A09-210 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P02.app-unit.json exit 0 (registry with the schema-1 example)
- [ ] T-A09-211 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27`)
- [ ] T-A09-212 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A09-213 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; `Packages/VisualCore/README.md` (steering and neighbour search)
- [ ] T-A09-214 Contract G-STEERING and G-FISHSWIM closed by "A09-P02" in `docs/apps/digital-aquarium/visualcore-contract.json` and `python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app digital-aquarium --render`
- [ ] T-A09-215 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P02 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A09-216 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A09-P02; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A09-201 → (202 ∥ 203) → 204 (needs 202, 203) → 205 (needs 203, 204 for `turn`) → 206 → 207 → Polish.

## Parallel examples

Agent A: T-A09-202. Agent B: T-A09-203. Agent C: T-A09-204 after A and B. Agent D: T-A09-205 after C. Lead: 206, 207,
docs, contract, runs, commits.

## Implementation strategy

MVP: VisualCore steering and schooling; then the swim animation; then save/load fixtures; evidence last.
