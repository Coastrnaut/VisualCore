# Tasks: Solar System Explorer — Phase 05 Scientific review and device QA

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/review.md](contracts/review.md), [quickstart.md](quickstart.md). Gate A14-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A14-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; reference regression and iOS 26 at
X-A14. Precedents: `specs/093-tw-p05-qa/tasks.md`, `specs/106-sse-p04-time-tours/tasks.md`.

## Phase 1: Setup

- [X] T-A14-501 Baseline: cite the last evidence on the unchanged tree (`.autonomy/checks/A14-P04.{sse-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A14-P04.sse-ios27.json, A14-P04.app-unit.json and A14-P04.verify-27.json (exit 0) on the tree recorded at A14-P04, unchanged since apart from spec documents (no rerun)

## Phase 2: Story 1 — the review (core)

- [ ] T-A14-502 [P] [US1] Add `Packages/ExperiencesCreative/SolarSystemExplorer/Core/{EventChecks,ScientificReview}.swift` per data-model.md and contracts/review.md (seven `EventFixture`s of Clarifications Q1 "toleranceDays 3", with sources; `EventChecks.evaluate` by daily search within ±10 days refined to 0.01 day; `ScientificReview.modelStatement` with the text of Clarifications Q3; `markdown()` "deterministic, LF, ends with a newline") with `CoreTests/{EventChecksTests,ScientificReviewTests,TruthfulLabelTests}.swift` (each event within ±3 days; the committed `docs/apps/solar-system-explorer/scientific-review.md` equals the generated text, `UPDATE_SCIENTIFIC_REVIEW=1` or `TEST_RUNNER_UPDATE_SCIENTIFIC_REVIEW=1` rewrites it; the review names the data-sources value count and its 0 problems, and every number in the tour captions it lists appears in `data-sources.md`; the 72 states of Clarifications Q4) and generate the document (FR-A14-501, 502, 504; SC-A14-501–503)

## Phase 3: Story 2 — the model statement in the app

- [ ] T-A14-503 [US2] Show "About this model" with `ScientificReview.modelStatement` as label and value in `Experience/SolarControls.swift` (identifier `experience.a14.solar-system-explorer.about-model`), with a session test in `ExperienceTests/SolarQualityTests.swift` (FR-A14-503)

## Phase 4: Story 3 — detail levels

- [ ] T-A14-504 [US3] Declare `SolarCore.qualityTiers` 2 in `Experience/Adapter/SolarCore.swift`; set `quality_tiers` ["level-0", "level-1"] for `a14.solar-system-explorer` in `Catalog/registrations.json` and `Packages/VisualCore/Tests/VisualCoreExperienceTests/Fixtures/Catalog/registrations.json`; draw level 1 (spheres 24 × 12, 200 stars, orbits of 64 samples; renderers of both levels made and released together) in `Experience/{SceneMeshes,SolarPresenter}.swift`; tests in `ExperienceTests/SolarQualityTests.swift` (profile names and count; both levels draw non-blank frames; same recorded centres and state digest; level 1 uses fewer vertices; switching the level during a focus flight and a tour changes neither the state nor the flight's target) (FR-A14-510; SC-A14-504)
- [X] T-A14-505 [US3] Write `docs/apps/solar-system-explorer/device-campaign.md` with the {device} tasks and pass criteria of FR-A14-511 (FR-A14-511) — Verified 2026-11-15: 2026-11-15: docs/apps/solar-system-explorer/device-campaign.md lists six {device} rows (frame time at level 0, the drop to level 1, peak memory, accessibility audits, VoiceOver, Dynamic Type and Reduce Motion) with thresholds, all pending until ImplementationLock-100; python3 scripts/validate_docs.py PASS

## Phase 5: Records and evidence

- [ ] T-A14-506 Contract `docs/apps/solar-system-explorer/visualcore-contract.json`: G-REVIEW closed by "A14-P05"; rows M20, M21, M22 updated (`--name contract -- python3 scripts/check_app_contract.py --app solar-system-explorer --render`)
- [ ] T-A14-507 Solar System Explorer tests on sim-27.2 (`--name sse-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing SolarSystemExplorerCoreTests SolarSystemExplorerExperienceTests`), the VisualCore catalog fixture test (`--name visualcore-catalog -- swift test --package-path Packages/VisualCore --filter VisualCoreExperienceTests`) and documented API (`--name visualcore-docs -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/SolarSystemExplorer`) (SC-A14-501–505)
- [ ] T-A14-508 App build and unit (`xcodegen generate --spec project.yml`; `--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a14.solar-system-explorer --runtime 27`) (SC-A14-505)
- [ ] T-A14-509 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A14-510 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A14-P05; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A14-501 → (502 ∥ 504) → 503 → 505 → 506 → 507 → 508 → 509 → 510.

## Parallel examples

Agent A: T-A14-502. Lead: 503–509.

## Implementation strategy

MVP: the review (502), then the model statement (503), then levels and the device plan (504–505). Review checkpoints
after 502 (core tests) and at 507.
