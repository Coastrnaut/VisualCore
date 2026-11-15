# Tasks: Solar System Explorer — Phase 01 Scientific catalog, units and citation audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/catalog.md](contracts/catalog.md), [quickstart.md](quickstart.md). Gate A14-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/096-lm-p01-solver/tasks.md`.

## Phase 1: Setup

- [X] T-A14-101 Baseline: cite the last evidence on an unchanged `Packages` tree (`.autonomy/checks/A14-P00.{app-build,no-change}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A14-P00.{app-build,no-change}.json (exit 0) on the unchanged Packages tree (no rerun)

## Phase 2: Foundational — the core (stories 2–4)

- [X] T-A14-102 [US2] Create the core target `Packages/ExperiencesCreative/SolarSystemExplorer/Core/{Units,BodyCatalog,SourceRecords,CitationAudit,SolarState}.swift` per contracts/catalog.md and data-model.md (`Units` "non-finite or negative → nil", 149,597,870.7 km per AU, 365.25 days per Julian year; `BodyCatalog.bundled` with the Sun and eight planets and the exact values of spec Clarifications Q2, one `SourceRecord` per stored value (NASA NSSDCA Planetary Fact Sheet, public domain, epoch J2000.0; Sun radius IAU 2015 B3 nominal), sorted-key codec refusing damaged, newer or out-of-range documents with the data model's ranges "1…16 bodies, ids unique, radius 1…1,000,000 km, axis 1e6…1e10 km, period 1…1,000,000 days, tilt 0…180°, every value finite"; `factCard(for:)`; `CitationAudit` with allowed licenses `public-domain`, `CC0-1.0` and `markdown`; `SolarState` schema 1 selection 0…8) and tests `Packages/ExperiencesCreative/SolarSystemExplorer/CoreTests/{UnitsTests,BodyCatalogTests,CatalogFixtureTests,CitationAuditTests,SolarStateTests}.swift` (exact AU round trip, refusals; 9 bodies in order, Sun without axis and period; fixture of Clarifications Q3 within 1 %; audit 0 problems and each damaged-record fixture refused with its reason; state codec) (FR-A14-101–104, 110; SC-A14-101–103) — Verified 2026-11-15: 2026-11-15: Core Units (exact 149,597,870.7 km per AU, 365.25 days per Julian year, refusals), BodyCatalog (Sun and eight planets with the Q2 values, codec refusing damaged, newer-version, out-of-range), SourceRecords (34 records, NASA Planetary Fact Sheet public domain, IAU 2015 B3), CitationAudit, SolarState; CoreTests 25 (fixture within 1 %) pass in .autonomy/checks/A14-P01.sse-ios27.json exit 0 on sim-27.2 (SolarSystemExplorerCoreTests 25, SolarSystemExplorerExperienceTests 29, manifest 4)

## Phase 3: Story 1 — the experience

- [X] T-A14-103 [US1] Create the experience targets in `Packages/ExperiencesCreative/Package.swift` (`SolarSystemExplorerCore`, `SolarSystemExplorerCoreTests`, `SolarSystemExplorerExperience`, `SolarSystemExplorerExperienceTests`, product `SolarSystemExplorerExperience`) and `Packages/ExperiencesCreative/SolarSystemExplorer/Experience/{Adapter/SolarCore.swift,SolarPresenter.swift,SolarControls.swift,SolarSystemExplorerExperience.swift}` (actions `body.select [0…8]`, `body.next`, `body.previous`, refusal `a14.invalid-choice`; presenter drawing the nine lit UV spheres with procedural two-band colours in the line-up of Clarifications Q4 through `DepthMeshPass` and a fixed `OrbitCamera`, a ring outline on the selected body, canvas description with "Sizes and spacing not to scale"; controls Previous body, Next body, Body menu and the fact card with units and sources, identifiers `experience.a14.solar-system-explorer.<name>`) and tests `ExperienceTests/{SolarCoreTests,SolarSessionTests,SolarRenderTests,SolarTestSupport}.swift` (actions and refusals; the session opens with nine bodies in catalog order and the Sun selected; a non-blank frame; changing the selection changes the drawn pixels and the card) (FR-A14-120, 121; SC-A14-104) — Verified 2026-11-15: 2026-11-15: package targets and the experience (SolarCore actions body.select/next/previous with a14.invalid-choice; SolarPresenter line-up of nine lit procedural spheres with a ring on the selection, not-to-scale description; SolarControls with fact card); nine ring renderers made once because releasing a mesh renderer releases the shared cached program (found by the first run: the bodies drew at the selection); SolarCoreTests, SolarSessionTests, SolarRenderTests pass in .autonomy/checks/A14-P01.sse-ios27.json exit 0 on sim-27.2 (SolarSystemExplorerCoreTests 25, SolarSystemExplorerExperienceTests 29, manifest 4)
- [X] T-A14-104 [US1] Register: `Catalog/registrations.json` entry for a14 (summary, capabilities, quality_tiers ["level-0"], palette, manifest), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency, `scripts/test_scripts.py` products list, `RealCatalogTests` registrations and `AppModelTests` synthetic candidate id moved past a14 (FR-A14-122) — Verified 2026-11-15: 2026-11-15: a14 registration (Catalog and fixture), candidate in ExperienceRegistry, project.yml dependency, products list, RealCatalogTests, AppModelTests synthetic candidate now a15; checked by the app run of T-A14-109
- [X] T-A14-105 [US1] Write `Packages/ExperiencesCreative/SolarSystemExplorer/Experience/Adapter/SolarManifest.swift` (nine standard scenarios + five fixtures selecting Mercury, Earth, Jupiter, Saturn and Neptune by actions) and generate `Packages/ExperiencesCreative/SolarSystemExplorer/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) with `ExperienceTests/SolarManifestTests.swift` (FR-A14-122) — Verified 2026-11-15: 2026-11-15: SolarManifest (nine standard scenarios, five fixtures Mercury, Earth, Jupiter, Saturn, Neptune; digests pinned) and scenario-manifest.json generated (UPDATE_SCENARIO_MANIFEST=1 on sim-27.2); SolarManifestTests 4 pass in .autonomy/checks/A14-P01.sse-ios27.json exit 0 on sim-27.2 (SolarSystemExplorerCoreTests 25, SolarSystemExplorerExperienceTests 29, manifest 4)

## Phase 4: Story 4 — citations recorded

- [X] T-A14-106 [US4] Generate `docs/apps/solar-system-explorer/data-sources.md` from `CitationAudit.markdown(.bundled)` with a test in `CoreTests/CitationAuditTests.swift` comparing the committed file (through `#filePath`, regenerated with `UPDATE_DATA_SOURCES=1` or `TEST_RUNNER_UPDATE_DATA_SOURCES=1`); link it from `docs/apps/solar-system-explorer/README.md` (FR-A14-110; SC-A14-103) — Verified 2026-11-15: 2026-11-15: docs/apps/solar-system-explorer/data-sources.md (34 values, 0 problems) generated from CitationAudit.markdown and checked by CitationAuditTests.theCommittedDataSourcesDocumentMatchesTheCatalog in .autonomy/checks/A14-P01.sse-ios27.json exit 0 on sim-27.2 (SolarSystemExplorerCoreTests 25, SolarSystemExplorerExperienceTests 29, manifest 4); linked from the experience README
- [X] T-A14-107 [US4] Contract `docs/apps/solar-system-explorer/visualcore-contract.json`: G-CATALOG closed by "A14-P01"; rows M06, M09, M11, M15, M20 updated (`--name contract -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`) — Verified 2026-11-15: 2026-11-15: G-CATALOG closed by A14-P01; rows M06, M09, M11, M15, M20 notes updated (still covered by later gaps); .autonomy/checks/A14-P01.contract.json exit 0

## Phase 5: Records and evidence

- [ ] T-A14-108 Solar System Explorer tests on sim-27.2 (`--name sse-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`) (SC-A14-101–105)
- [ ] T-A14-109 App build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`) (SC-A14-105)
- [ ] T-A14-110 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A14-111 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P01; update README.md in the record commit (rule 16)

## Dependencies

T-A14-101 → 102 → 103 → (104 ∥ 106) → 105 → 107 → 108 → 109 → 110 → 111.

## Parallel examples

Agent A: T-A14-102 (core). Agent B: T-A14-103 (experience) after A. Lead: Package.swift review, registrations, registry,
project.yml, xcodegen, manifest and document regeneration, contract, runs, commits.

## Implementation strategy

MVP: the core with the fixture (102), then the drawn line-up (103–105), then citations recorded (106–107). Review
checkpoints after 102 (host core tests), after 105 and at 108.
