# Tasks: Physics Playground — Phase 05 Numerical stability and performance audit

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/stability.md](contracts/stability.md), [quickstart.md](quickstart.md). Gate A11-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A11-P05 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; device tasks tagged {device} stay
open until ImplementationLock-100. Precedents: `specs/079-na-p05-balance/tasks.md`, `specs/085-pp-p04-experiments/tasks.md`.

## Phase 1: Setup

- [X] T-A11-501 Baseline: cite the A11-P04 evidence on the unchanged tree (`.autonomy/checks/A11-P04.{playground-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A11-P04.{playground-ios27,app-unit,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — sleep, work count, drawing budgets in the core

- [ ] T-A11-502 [US1] Core: new `Packages/ExperiencesCreative/PhysicsPlayground/Core/{Sleep,WorkCount,DrawingBudget}.swift` and changes to `Core/{PhysicsWorld,WorldSimulation,WorldEditing}.swift` per research D1–D3 and data-model.md: world schema 4 ("asleep ⇒ velocities 0 and dynamic, unpinned, ungrabbed; restTicks 0…60"; decode 1→2→3→4, migration 3 → 4 awake with 0); sleep after 60 ticks below 0.05 m/s and 0.05 rad/s; wake on overlap with an awake dynamic body, a spring to an awake dynamic body, an edit naming the body or a body touching a deleted one, any level change; sleeping bodies skip gravity, drag and integration and pairs without an awake dynamic body are not tested; a measured tick returning `WorkCount` (narrowPhaseTests, contacts, contactPoints, solverPointUpdates; derived, never saved); `DrawingBudget.levels` (coils 8/6/4, circle segments 33/24/16, hatch 0.12/0.2/none); tests in `Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{SleepTests,StressTests,WorkBudgetTests,DrawingBudgetTests}.swift`: the stacked-objects preset is fully asleep within 360 ticks and its narrow-phase tests are 0; each wake trigger wakes in the same tick; five stress scenes per clarification Q3 (48 bodies, 16 springs at level 3, seeded nudges every 30 ticks, seeded levels every 240 ticks, 1,200 ticks) keep every value finite, every body inside and the caps; the unedited damped scene's energy rises ≤ 1 % per second; budget limits at 48 awake bodies and 16 springs (narrowPhaseTests ≤ 1,320, contactPoints ≤ 2 × contacts, solverPointUpdates ≤ iterations × contactPoints); replay of a session over every action kind gives identical encoded worlds; a host timing over 600 ticks printed (recorded in research, not asserted) (FR-A11-501–503, 510; SC-A11-501–504)
- [ ] T-A11-503 [P] [US4] Documents: `docs/apps/physics-playground/README.md` capability → proving-test table (each capability of the registration with a test name that exists in `Packages/ExperiencesCreative/PhysicsPlayground` or `Packages/VisualCore`), new `docs/apps/physics-playground/device-campaign.md` (rows: frame pacing per level on the reference phone and tablet, thermal state over 10 minutes at 48 bodies, touch latency for grab, VoiceOver pass; device, procedure, threshold, status "pending device campaign") linked from the README, and new `specs/086-pp-p05-stability/scan-claims.sh` modelled on `specs/079-na-p05-balance/scan-claims.sh` (every named test exists; refuses accurate, accuracy, precise, precision, engineering-grade, safety, predict, prediction, teaches, learning outcome, improves understanding in the a11 catalog entry and the README) (FR-A11-530, 531)

## Phase 3: Stories 2 and 3 — quality levels and fixtures in the experience

- [ ] T-A11-504 [US2] Experience: `Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore.swift,PlaygroundPresenter.swift,PhysicsPlaygroundExperience.swift}`: state schema 5 ("migration 4 → 5: bodies awake, restTicks 0") and `schemaFourExample()`; `qualityTiers` 3 with profile `level-0…level-2`; the core stores no tier; the wrapper forwards `qualityProfile` and `setQualityTier`; the presenter's drawing budget = Low Power Mode (injected, default `ProcessInfo.processInfo.isLowPowerModeEnabled`) ? 2 : host tier; tests in `Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/PlaygroundQualityTests.swift` (declared tiers = presenter levels = 3; coils, segments and hatch per level; Low Power Mode → level 2; digest equal across levels and drawn/undrawn; schema-1…4 examples restore) (FR-A11-520; SC-A11-502, 505)
- [ ] T-A11-505 [US3] Manifest fixtures 34–38 per research D4 in `Packages/ExperiencesCreative/PhysicsPlayground/Experience/Adapter/PlaygroundManifest.swift`, regenerate `Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), `PlaygroundManifestTests` updated
- [ ] T-A11-506 [US4] Registration and records: `Catalog/registrations.json` a11 `summary` "A sandbox of circles, boxes and springs under gravity and drag, with presets, saved experiments and tutorials.", `quality_tiers` ["level-0", "level-1", "level-2"]; `python3 scripts/build_catalog.py`; `Apps/VisualCore/App/ExperienceRegistry.swift` examples add `schemaFourExample()`; contract `docs/apps/physics-playground/visualcore-contract.json` (G-STABILITY closed by "A11-P05"; M13 available; M15 note on the three levels) (FR-A11-520, 530)
- [ ] T-A11-507 [US1] {device} Device campaign measurements per `docs/apps/physics-playground/device-campaign.md` (frame pacing per level, thermals over 10 minutes, touch latency, VoiceOver) — runs only after ImplementationLock-100

## Phase 4: Polish & evidence

- [ ] T-A11-508 Playground tests on sim-27.2 (`--name playground-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests`; each test < 10 s) (SC-A11-506)
- [ ] T-A11-509 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27`)
- [ ] T-A11-510 Claims scan, catalog, packages, contract, distinctiveness and script tests (`--name claims -- bash specs/086-pp-p05-stability/scan-claims.sh`; `--name catalog -- python3 scripts/build_catalog.py --check`; `--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name contract -- python3 scripts/check_app_contract.py --app physics-playground --render`; `--name distinctiveness -- python3 scripts/check_distinctiveness.py --check`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A11-511 Run `/speckit-converge` and `/speckit-implement` until nothing is appended (T-A11-507 {device} stays open by design); then seal and record A11-P05; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A11-501 → 502 → 504 → 505 → 506 → Polish; 503 in parallel with 502 (different files). T-A11-507 waits for
ImplementationLock-100.

## Parallel examples

Agent A: T-A11-502. Agent C: T-A11-503 (documents). Agent B: T-A11-504 after A. Lead: 505 regeneration, 506, runs,
commits.

## Implementation strategy

MVP: stability under stress and deterministic replay (US1, US2) with sleep and budgets (US3); then levels, storefront
and device plan (US4); evidence last.
