# Tasks: Neon Arcade — Phase 01 Fixed-step engine and collision fixtures

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A10-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers). iOS 27 only; reference regression and iOS 26 at X-A10 (owner, 2026-11-14). Precedents:
`specs/068-da-p01-habitat/tasks.md`, `specs/069-da-p02-schools/tasks.md`.

## Phase 1: Setup

- [ ] T-A10-101 Baseline: cite the last evidence on an unchanged `Packages` tree (`.autonomy/checks/A10-P00.app-build.json`, `.autonomy/migration/checks/X-A09.*.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational — generic collision (story 3) and the game core (stories 1, 2, 4)

- [ ] T-A10-102 [P] [US3] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/Collision2DTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreSimulation/Collision2D.swift` per contracts/api.md and research D1 (`CollisionCircle`, `CollisionCapsule`, `Collision2D.overlaps` circle–circle and circle–capsule, `closestPoint(on:to:)`, `sweep(_:moving:_:moving:)`, `tolerance` 1e-9; public with `///` docs); tests: touching counts and one unit apart does not; inside; capsule side, both rounded ends and a degenerate segment; sweep returns 0 when already touching, the earliest fraction in 0…1 for a crossing, nil when passing wide, moving apart or with zero relative motion; tunnelling caught for travel of 4, 10 and 50 × the summed radii per step; non-finite input and negative radius give false/nil; identical input gives identical output (FR-A10-101, 102; SC-A10-103)
- [ ] T-A10-103 [P] [US1] Create the core target `Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeCatalog,LicenseAudit,GameRun,GameSimulation}.swift` and `Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeCatalogTests,LicenseAuditTests,GameRunTests,GameSimulationTests,ReplayTests}.swift` per contracts/api.md, data-model.md and research D2–D4: catalog items player `chevron`, hazards `spike-ball` (circle) and `bar` (capsule), orb `glow-orb` worth 10, "radiusRange (min ≤ max, 0.1…1.0)", "halfLengthRange (bar only, 0.3…1.5)", license ∈ {"MIT"} with author "VisualCore project"; refusal reasons missing-license, unsupported-license, unknown-shape, invalid-number with the valid rest kept; `GameRun` schema 1 ("score 0…9,999,999", "lives 0…3", "objects (≤ 24)", "events (≤ 256)", player x 0.5…8.5, hit radius 0.4, invulnerability 90 steps); `GameSimulation.advance` with step 1/60 s, steering to target velocity value × 9 easing at 60 units/s², first spawn at step 30 then every 40, hazard 70 % / orb 30 %, x 0.5…8.5, start y 16.5, fall 3…5 units/s, swept test for circle objects and end-of-step overlap for capsules, removal below y −1, invulnerable contact passes without effect, game over at 0 lives, paused or over changes nothing, restart values (steering 0, score 0, lives 3); tests: first object by 2 s, steering moves the player and it never leaves 0.5…8.5 over 10,000 steps × 20 seeds, objects ≤ 24, hazard hit costs one life and starts invulnerability, orb pickup adds 10, two contacts in one step in id order, game over stops the run, the score stops at 9,999,999, a non-finite steering value is ignored, capsule speed bound (≤ 5 × step < 0.6) checked from the catalog, a replay of 12 recorded steering inputs over 1,200 steps gives identical score, lives and events twice, every refusal reason from a malformed JSON fixture, audit rows for every item with none missing author or license (FR-A10-110–113; SC-A10-101, 102, 104)

## Phase 3: User Story 1 — a game to play (P1) 🎯

- [ ] T-A10-104 [US1] Create the experience targets in `Packages/ExperiencesCreative/Package.swift` (`NeonArcadeCore`, `NeonArcadeCoreTests`, `NeonArcadeExperience`, `NeonArcadeExperienceTests`, product `NeonArcadeExperience`) and `Packages/ExperiencesCreative/NeonArcade/Experience/{Adapter/ArcadeCore.swift,ArcadePresenter.swift,ArcadeControls.swift,NeonArcadeExperience.swift}`: adapter (ExperienceCore; actions run.steer [−1…1], run.pause [0…1], run.restart with codes a10.*; snapshot schema 1 = `ArcadeState` (run + generator state); stepDuration 1/60; qualityTiers 1; digest covers run, eventCount and events), presenter drawing the field, the player (ring at hit radius with a chevron inside), hazards (circles and capsules at rule size), orbs, score and lives through PrimitiveRenderer with the host's context only, glow pulse and background drift halved under Reduce Motion, the drag gesture turning the finger's horizontal offset ÷ 1.5 (clamped) into run.steer, spoken description (score, lives, playing/paused/over), controls (left/right held −1/+1 and 0 on release, pause, restart) with labels and values; tests `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/{ArcadeCoreTests,ArcadeSessionTests,ArcadeRenderTests,ArcadeTestSupport}.swift` (actions accepted/refused, snapshot round trip and damaged/newer refusal, suspension does not advance steps, frame pacing 1/30, 1/60, 1/120 s gives the same run after the same steps, drawing does not change the digest, Reduce Motion halves the presenter's pulse and drift amounts and leaves the digest unchanged, non-blank frames that differ after objects fall, description words) (FR-A10-112, 120–122; SC-A10-101, 102, 105)

## Phase 4: Stories 2–4 — registration, fixtures and records (P1/P2)

- [ ] T-A10-105 [US2] Register: `Catalog/registrations.json` entry for a10 (capabilities, quality_tiers ["level-0"], palette, manifest), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency on the product, `scripts/test_scripts.py` products list, `Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift` registrations and the synthetic candidate in `Apps/VisualCore/Tests/Unit/AppModelTests.swift` moved past a10; `python3 scripts/build_catalog.py`; `xcodegen generate --spec project.yml` (FR-A10-123)
- [ ] T-A10-106 [US2] Write `Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/ArcadeManifest.swift` (nine standard scenarios + seven fixtures per research D5: replay, frame pacing, swept hit, save/restore, resume without catch-up, catalog refusal, bounded objects) and generate `Packages/ExperiencesCreative/NeonArcade/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), with `Packages/ExperiencesCreative/NeonArcade/ExperienceTests/ArcadeManifestTests.swift` (FR-A10-123; SC-A10-106)
- [ ] T-A10-107 [US3] VisualCore records: `Packages/VisualCore/README.md` (2D collision section), API baseline (`python3 scripts/check_public_api.py --update`) and the contract `docs/apps/neon-arcade/visualcore-contract.json` (G-COLLISION2D closed by "A10-P01"; rows M05 and M08 updated with the new evidence; G-GAMERULES notes the Phase 01 part) (FR-A10-102, 103)
- [ ] T-A10-108 [US4] Generate `docs/apps/neon-arcade/content-licenses.md` from `LicenseAudit.markdown(.bundled)` with a test in `Packages/ExperiencesCreative/NeonArcade/CoreTests/LicenseAuditTests.swift` that the document lists every catalog item; link it from `docs/apps/neon-arcade/README.md` (FR-A10-113; SC-A10-104)

## Phase 5: Polish & evidence

- [ ] T-A10-109 VisualCore host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name visualcore-host -- swift test --package-path Packages/VisualCore --filter Collision2DTests`) and public API (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`) (SC-A10-103, 106)
- [ ] T-A10-110 Arcade tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`; each test < 10 s) (SC-A10-101–106)
- [ ] T-A10-111 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A10-112 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`)
- [ ] T-A10-113 Experience package check, contract and script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P01 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`; `--name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A10-114 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P01

## Dependencies

T-A10-101 → (102 ∥ 103) → 104 (needs 102, 103) → 105 → 106 → (107 ∥ 108) → Polish. 103 builds against
contracts/api.md for the collision calls and compiles once 102 lands.

## Parallel examples

Agent A: T-A10-102. Agent B: T-A10-103. Agent C: T-A10-104 experience files and tests after A and B. Lead:
Package.swift, 105, 106 regeneration, 107, 108, runs, commits.

## Implementation strategy

MVP: collision and the game core (US3 and US1's rules with US2's replay), then the drawn game, registration, fixtures
and records; evidence last.
