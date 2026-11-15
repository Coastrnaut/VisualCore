# Tasks: Digital Aquarium — Phase 04 Lighting, particles and accessibility

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A09-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; no VisualCore change in this phase.

## Phase 1: Setup

- [X] T-A09-401 Baseline: cite the A09-P03 evidence on the unchanged tree (`.autonomy/checks/A09-P03.aquarium-ios27.json`, `.autonomy/checks/A09-P03.app-unit.json`, `.autonomy/checks/A09-P03.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: no aquarium or app source change since the A09-P03 evidence (only specs, docs and the record's regenerated catalog fixture); cites .autonomy/checks/A09-P03.{aquarium-ios27,app-unit,verify-27}.json

## Phase 2: Foundational (catalog vents)

- [X] T-A09-402 `StarterHabitat.vents` ("x positions; missing → []", "each finite, 0.5…15.5; at most 4") with Reef [3.0, 12.5] and Kelp [5.5, 10.0] in `Packages/ExperiencesCreative/DigitalAquarium/Core/SpeciesCatalog.swift`, validated in `Core/CatalogDecoder.swift` (refusal `invalid-number` as for other numbers); tests in `CoreTests/SpeciesCatalogTests.swift` (FR-A09-401) — Verified 2026-11-14: 2026-11-14: StarterHabitat.vents (Reef [3, 12.5], Kelp [5.5, 10]) validated by CatalogDecoder; SpeciesCatalogTests pass in DigitalAquariumCoreTests (116 tests) on sim-27.2; content-licenses.md unchanged

## Phase 3: User Story 1 — living water (P1) 🎯

- [X] T-A09-403 [US1] `Core/WaterEffects.swift` per contracts/api.md and research D1, D2 (bubbles and motes from the step count; caps 24 per vent, 48 total, 24 motes; Reduce Motion speeds and no wobble; layers, scales, tints, `tinted`) with `CoreTests/WaterEffectsTests.swift` (every bubble between vent y and surface, x within the wobble of its vent, count ≤ 48 at every step of 3,600 for both habitats; newest bubble at the vent; a bubble leaves at the surface; same step → same output; Reduce Motion halves rise and removes wobble; motes inside 0…16 × 1.5…8.5 and wrap; layer order, scales and tints) (FR-A09-401–404, 410; SC-A09-401, 403) — Verified 2026-11-14: 2026-11-14: WaterEffects (bubbles ≤ 48 from vents to the surface, 24 motes, depth layers); WaterEffectsTests 11 tests pass on sim-27.2

## Phase 4: User Story 3 — the aquarium in words (P2)

- [ ] T-A09-404 [P] [US3] `Core/AquariumWording.swift` and `Core/AquariumAnnouncer.swift` per contracts/api.md and research D4 with `CoreTests/{AquariumWordingTests,AquariumAnnouncerTests}.swift` (description for each state: empty decor, food, paused, both habitats, species counts; change sentences and priority; announcer interval 3 s, VoiceOver gate, latest pending wins, reset) (FR-A09-420, 421; SC-A09-405)

## Phase 5: User Story 2 — depth and light (P1)

- [ ] T-A09-405 [US2] `Experience/CausticsScene.swift` (inline fragment over `FullScreenShaderScene` with `ShaderBundle(files: [:])`; water and gravel colours, strength 0.04/0.07/0.10, time step/60 × 0.4, Reduce Motion 0; `isAvailable` false when `errorMessage` is set; `fragmentOverride` seam) and presenter integration in `Experience/AquariumPresenter.swift` (caustics or fallback; depth-layer order, scale and tint; bubbles and motes as circles in front; `AquariumWording` description; announcer fed by state changes into an injected `AnnouncementSink` with `voiceOverRunning`; context-loss rebuild through setup/teardown) and the factory in `Experience/DigitalAquariumExperience.swift`; tests in `ExperienceTests/AquariumRenderTests.swift` (back before front, scale ≤ 0.75 of front, tint toward water; two frames 60 steps apart differ, identical with Reduce Motion; the pattern is fainter at dim than at bright lighting; the state digest is identical with and without Reduce Motion and effects; broken shader falls back and draws; bubbles drawn; unknown kinds skipped) and `ExperienceTests/AquariumAnnouncementTests.swift` (feed → "Food dropped" once with VoiceOver; nothing without it; first frame silent; two changes within 3 s → one announcement) (FR-A09-404, 410, 411, 421, 430; SC-A09-402–405)

## Phase 6: User Story 4 — damaged or unknown content (P2)

- [ ] T-A09-406 [P] [US4] `CoreTests/UnknownContentTests.swift` (malformed catalogs refused with named reasons: unknown species reference, unsupported fish, plant and decor shapes, unknown decor in a habitat, vent outside the tank; documents with unknown species, plant or decor refused by validation) and a session test in `ExperienceTests/AquariumSessionTests.swift` restoring a snapshot that names an unknown species and an unknown decor kind (refused, `lastRestoreRefusal` set, the Reef opens) (FR-A09-430; SC-A09-406)
- [ ] T-A09-407 [US4] Manifest fixture 11 (Reef, 600 steps) in `Experience/Adapter/AquariumManifest.swift`, regenerate `scenario-manifest.json`, update `ExperienceTests/AquariumManifestTests.swift` (eleven fixtures; at fixture 11's final step `WaterEffects.bubbles` for the Reef's vents has at most 48 bubbles, all between the vents and the surface) (FR-A09-431; SC-A09-402)

## Phase 7: Polish & evidence

- [ ] T-A09-408 Digital Aquarium tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name aquarium-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests`; each test < 10 s) (SC-A09-407)
- [ ] T-A09-409 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A09-410 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27`)
- [ ] T-A09-411 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A09-412 Contract G-WATERFX and G-HABITATA11Y closed by "A09-P04" (M11, M12, M13, M18 available) in `docs/apps/digital-aquarium/visualcore-contract.json` and `python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app digital-aquarium --render`
- [ ] T-A09-413 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P04 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A09-414 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A09-P04; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A09-401 → 402 → (403 ∥ 404 ∥ 406) → 405 (needs 403, 404) → 407 → Polish.

## Parallel examples

Agent A: T-A09-402, 403. Agent B: T-A09-404. Agent C: T-A09-406's core tests. Agent D: T-A09-405 after A and B. Lead:
406's session test, 407, docs, contract, runs, commits.

## Implementation strategy

MVP: water effects in the core and on screen; then caustics and depth; then words and announcements; then unknown
content; evidence last.
