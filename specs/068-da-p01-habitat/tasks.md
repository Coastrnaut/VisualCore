# Tasks: Digital Aquarium — Phase 01 Habitat model and content license audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A09-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A09
(owner, 2026-11-14). Precedent: `specs/061-os-p01-acquisition/tasks.md`.

## Phase 1: Setup

- [X] T-A09-101 Baseline: cite the last package evidence on an unchanged `Packages` tree (`.autonomy/migration/checks/X-A08.host.json`, `.autonomy/checks/A09-P00.app-build.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: Packages unchanged since X-A08 follow-through; cites .autonomy/migration/checks/X-A08.host.json and .autonomy/checks/A09-P00.app-build.json

## Phase 2: Foundational — the habitat model (stories 1–4)

- [X] T-A09-102 [P] [US1] Create the core target `Packages/ExperiencesCreative/DigitalAquarium/Core/{HabitatDocument,SpeciesCatalog,CatalogDecoder,LicenseAudit,AquariumSimulation}.swift` and `Packages/ExperiencesCreative/DigitalAquarium/CoreTests/{HabitatDocumentTests,SpeciesCatalogTests,LicenseAuditTests,AquariumSimulationTests}.swift` per contracts/api.md and data-model.md: species "length 0.3…1.5 units", "maxSpeed ≥ cruise, ≤ 4 units/s", shapes {teardrop, slender} and {ribbon, fan}, license ∈ {"MIT"} with author "VisualCore project", habitats with "total fish 1…24, plants 0…12", two starter habitats (Reef, Kelp; 6–10 fish, 4–6 plants, two species each); refusal reasons missing-license, unsupported-license, unknown-shape, unknown-reference, invalid-number, too-many-fish; bounded wander per clarification 1 with tank 16 × 9 and bounds x 0.5…15.5, y 1.5…8.5, step 1/60 s; tests: two species and ≥ 4 plants in each starter, same seed → identical documents, 10,000 steps × 20 seeds never outside bounds and never above maxSpeed, corner-outward fish turns back, every refusal reason from a malformed JSON fixture with the valid rest kept, audit rows for every item and none missing author or license (FR-A09-101–104, 110, 111; SC-A09-101–103) — Verified 2026-11-14: 2026-11-14: DigitalAquariumCoreTests + DigitalAquariumExperienceTests on sim-27.2, 60 tests 0 failures (.autonomy/xcresults/ExperiencesCreative-sim-27.2-20261114T152737.xcresult); core 32 tests (catalog, decoder refusals, audit, 10,000 steps x 20 seeds inside bounds)

## Phase 3: User Story 1 — a complete aquarium to watch (P1) 🎯

- [X] T-A09-103 [US1] Create the experience targets in `Packages/ExperiencesCreative/Package.swift` (`DigitalAquariumCore`, `DigitalAquariumCoreTests`, `DigitalAquariumExperience`, `DigitalAquariumExperienceTests`, product `DigitalAquariumExperience`) and `Packages/ExperiencesCreative/DigitalAquarium/Experience/{Adapter/AquariumCore.swift,AquariumPresenter.swift,AquariumControls.swift,DigitalAquariumExperience.swift}`: adapter (ExperienceCore; actions habitat.select [0…1], lighting.level [0…2], motion.pause [0…1] with codes a09.*; snapshot schema 1 = document + step + paused + generator state; stepDuration 1/60; qualityTiers 1), presenter drawing water, gravel, plants (polylines/fans swaying) and fish (12-point outline + tail, mirrored by heading) through PrimitiveRenderer with the host's context only, Reduce Motion halving sway and random turning, spoken description (habitat, species, fish count, lighting, paused), controls with labels and values; tests `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/{AquariumCoreTests,AquariumSessionTests,AquariumRenderTests,AquariumTestSupport}.swift` (actions accepted/refused, snapshot round trip and damaged/newer refusal, suspension does not advance steps, non-blank frames that differ between habitats, description words) (FR-A09-120, 121, 123; SC-A09-101, 104) — Verified 2026-11-14: 2026-11-14: DigitalAquariumCoreTests + DigitalAquariumExperienceTests on sim-27.2, 60 tests 0 failures (.autonomy/xcresults/ExperiencesCreative-sim-27.2-20261114T152737.xcresult); AquariumCoreTests, AquariumSessionTests, AquariumRenderTests (actions, snapshot round trip and refusal, no step while suspended, non-blank frames differing by habitat, description); FR-A09-123 resolved to drawn motion only

## Phase 4: User Story 2–4 — registration and the fixture manifest (P1/P2)

- [X] T-A09-104 [US2] Register: `Catalog/registrations.json` entry for a09 (capabilities, quality_tiers ["level-0"], palette, manifest), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency on the product, `scripts/test_scripts.py` products list, `Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift` registrations and the synthetic candidate in `Apps/VisualCore/Tests/Unit/AppModelTests.swift` moved to a10; `python3 scripts/build_catalog.py`; `xcodegen generate --spec project.yml` (FR-A09-122) — Verified 2026-11-14: 2026-11-14: registrations a09 (level-0), candidate in ExperienceRegistry, project.yml product, test_scripts products, RealCatalogTests registrations (host 38 tests pass), synthetic candidate a10; build_catalog 8 available; app build and unit pass (.autonomy/checks/A09-P01.app-unit.json)
- [X] T-A09-105 [US2] Write `Packages/ExperiencesCreative/DigitalAquarium/Experience/Adapter/AquariumManifest.swift` (nine standard scenarios + five fixtures per research D6: swim bounds after a long run, save/restore Kelp bright, pause then steps, both habitats from the validated catalog, bounded counts after habitat switches) and generate `Packages/ExperiencesCreative/DigitalAquarium/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), with `Packages/ExperiencesCreative/DigitalAquarium/ExperienceTests/AquariumManifestTests.swift` (FR-A09-122; SC-A09-105) — Verified 2026-11-14: 2026-11-14: AquariumManifest (9 standard + 5 fixtures), scenario-manifest.json generated; AquariumManifestTests pass in the 60-test run on sim-27.2
- [X] T-A09-106 [US3] Generate `docs/apps/digital-aquarium/content-licenses.md` from `LicenseAudit.markdown(.bundled)` and add a test in `Packages/ExperiencesCreative/DigitalAquarium/CoreTests/LicenseAuditTests.swift` that the markdown lists every catalog item (FR-A09-104) — Verified 2026-11-14: 2026-11-14: docs/apps/digital-aquarium/content-licenses.md generated from LicenseAudit.markdown(.bundled); LicenseAuditTests.theCommittedLicenseDocumentMatchesTheCatalog passes on sim-27.2

## Phase 5: Polish & evidence

- [X] T-A09-107 Aquarium tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name aquarium-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing DigitalAquariumCoreTests DigitalAquariumExperienceTests`; each test < 10 s) (SC-A09-105) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P01.aquarium-ios27.json exit 0, 61 tests 0 failures on sim-27.2; slowest 0.58 s
- [X] T-A09-108 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P01.app-unit.json exit 0 (build-for-testing, unit)
- [X] T-A09-109 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a09.digital-aquarium --runtime 27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P01.verify-27.json exit 0 (a09, nine standard + five fixture scenarios, iOS 27)
- [X] T-A09-110 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A09-P01.experience-packages.json exit 0 (9 experiences)
- [ ] T-A09-111 Contract: G-HABITAT closed by "A09-P01" with rows M09 and M20 available and their evidence; `python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app digital-aquarium --render`
- [ ] T-A09-112 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A09-P01 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A09-113 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A09-P01

## Dependencies

T-A09-101 → 102 → 103 → 104 → 105 → 106 → Polish. 103's presenter and tests may start against contracts/api.md while
102 lands; they build only after it.

## Parallel examples

Agent A: T-A09-102 (core + core tests). Agent B: T-A09-103 experience files and tests (against contracts/api.md).
Lead: Package.swift, 104, 105 regeneration, 106, docs, runs, commits.

## Implementation strategy

MVP: the habitat model and the drawn aquarium (US1 with the bounds fixture of US2); then registration, manifest and
the license document; evidence last.
