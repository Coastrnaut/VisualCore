# Tasks: Physics Playground — Phase 02 Contacts and spring solver

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A11-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A11-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only; reference regression and iOS 26 at
X-A11. Precedent: `specs/082-pp-p01-model/tasks.md`.

## Phase 1: Setup

- [X] T-A11-201 Baseline: cite the A11-P01 evidence on the unchanged tree (`.autonomy/checks/A11-P01.{playground-ios27-2,app-unit-2,verify-27-2}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: 2026-11-15: cited .autonomy/checks/A11-P01.{playground-ios27-2,app-unit-2,verify-27-2}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — generic springs, broad phase and warm starting

- [ ] T-A11-202 [P] [US1] Write `Packages/VisualCore/Tests/VisualCoreSimulationTests/{Springs2DTests,BroadPhase2DTests}.swift` first, then `Packages/VisualCore/Sources/VisualCoreSimulation/{Springs2D,BroadPhase2D}.swift`, and add warm starting to `Packages/VisualCore/Sources/VisualCoreSimulation/{Contacts2D,ImpulseSolver2D}.swift` (additive: `Shape2D.bounds(at:)`, `Contact2D.normalImpulses`/`tangentImpulses` default `[]`, `ImpulseSolver2D.solve(_:contacts: inout ...)`; the Phase 01 solve unchanged) with tests in `ImpulseSolver2DTests.swift`, per contracts/api.md and research D1–D3. Spring tests: a stretched spring pulls both ends together, a world anchor never moves, static ends never move, zero length applies nothing, stiffness clamped to 0.1·m/dt² and damping to m/dt, undamped oscillator energy within 2 % over 1,200 ticks at ω·dt ≤ 0.1, damped energy never rises > 0.1 % per second and falls below 10 % within 10 s at ζ = 0.5, equilibrium stretch m·g/k within 2 %, determinism. Broad-phase tests: equal to brute force on 50 seeded scenes (sizes and positions random), touching counts, empty and single inputs, sorted output. Solver tests: warm start with no stored impulses equals the Phase 01 result exactly; five 0.5 m boxes stacked on a static floor for 1,200 ticks with warm starting drift < 2 cm and sink < 1 cm (FR-A11-201–204; SC-A11-201–204)
- [ ] T-A11-203 [P] [US1] Core: `Packages/ExperiencesCreative/PhysicsPlayground/Core/ForceLevels.swift` (new; gravity 0, 1.62, 9.81; drag 0, 0.05, 1.0; stiffness 20, 60, 150, 400 N/m) and changes to `Core/{PhysicsWorld,StartingScene,WorldSimulation,WorldDiagnostics}.swift`: world schema 2 ("springs (≤ 16)", "rest 0.1…10 m", bodies exist and differ, nextSpringId, "gravityLevel 0…2", "dragLevel 0…2", "stiffnessLevel 0…3", contactCache; settings' gravity and drags follow the levels), `PhysicsWorld.migrated()` 1 → 2 (no springs, Earth, low drag, stiffness 1, empty cache), tick order gravity and drag → `Springs2D.apply` (damping ratio 0.1, stiffness from the level) → `BroadPhase2D` body pairs + per-body walls → warm-started solve with the cache keyed by (body id A, body id B or wall, point index) → integrate; the starting scene adds the hanging wood box (world anchor (7.5, 8.0), rest 1.5 m) and two rubber circles joined by a 1.0 m spring with every body non-overlapping; reset restores default levels and an empty cache; diagnostics add spring energy ½k'(L − L₀)². Tests in `Packages/ExperiencesCreative/PhysicsPlayground/CoreTests/{SpringWorldTests,StackFixtureTests,MigrationTests}.swift` and updates to the existing core tests: the hanging box settles within 2 % of m·g/k' in 10 s; a stiffer level oscillates faster; gravity levels 0, 1.62, 9.81 and drag decay within 1 %; the five-box stack bound; the broad phase gives the same world as the A11-P01 all-pairs path on a seeded scene; schema-1 worlds migrate; validation refuses bad springs (FR-A11-210–212; SC-A11-201, 202, 205, 206)

## Phase 3: Stories 1–4 — experience, registration and records

- [ ] T-A11-204 [US1] Experience: `Packages/ExperiencesCreative/PhysicsPlayground/Experience/{Adapter/PlaygroundCore.swift,PlaygroundPresenter.swift,PlaygroundControls.swift}` — snapshot schema 2 with `MigrationChain(currentVersion: 2)` and the 1 → 2 step, `schemaOneExample()`; actions `world.gravity [0…2]`, `world.drag [0…2]`, `world.stiffness [0…3]` (fractional → a11.invalid-choice); springs drawn as 8-coil zigzag polylines 0.03 m wide with anchor dots; controls (gravity, drag, stiffness pickers) with identifiers, VoiceOver labels and values; spoken description adds springs, stiffness, gravity and drag; tests in `Packages/ExperiencesCreative/PhysicsPlayground/ExperienceTests/*` (new actions and refusals, schema-1 example restores, springs drawn at physics anchors, description) (FR-A11-220, 221; SC-A11-206)
- [ ] T-A11-205 [US2] Manifest fixtures 11–18 per research D5 in `Packages/ExperiencesCreative/PhysicsPlayground/Experience/Adapter/PlaygroundManifest.swift`, regenerate `Packages/ExperiencesCreative/PhysicsPlayground/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), `PlaygroundManifestTests` updated (FR-A11-222)
- [ ] T-A11-206 [US4] Registry and records: schema-1 example in `Apps/VisualCore/App/ExperienceRegistry.swift` (`examples: [PlaygroundCore.schemaOneExample()]`), `Catalog/registrations.json` a11 capabilities (springs; gravity and drag levels), `python3 scripts/build_catalog.py`; `Packages/VisualCore/README.md` (springs, broad phase, warm starting), API baseline (`python3 scripts/check_public_api.py --update`); contract `docs/apps/physics-playground/visualcore-contract.json` (G-SPRINGS and G-BROADPHASE closed by "A11-P02"; M06 and M07 available with the new evidence) (FR-A11-204)

## Phase 4: Polish & evidence

- [ ] T-A11-207 VisualCore host tests (`--name visualcore-host -- swift test --package-path Packages/VisualCore --filter "Springs2DTests|BroadPhase2DTests|ImpulseSolver2DTests|Contacts2DTests"`) and public API (`--name public-api -- python3 scripts/check_public_api.py`) (SC-A11-207)
- [ ] T-A11-208 Playground tests on sim-27.2 (`--name playground-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing PhysicsPlaygroundCoreTests PhysicsPlaygroundExperienceTests`; each test < 10 s)
- [ ] T-A11-209 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a11.physics-playground --runtime 27`)
- [ ] T-A11-210 Experience package check, contract and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name contract -- python3 scripts/check_app_contract.py --app physics-playground --render`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A11-211 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A11-P02; update README.md (status, gate count) in the record commit (rule 16)

## Dependencies

T-A11-201 → (202 ∥ 203) → 204 (needs 202, 203) → 205 → 206 → Polish. 203 builds against contracts/api.md and compiles
once 202 lands.

## Parallel examples

Agent A: T-A11-202. Agent B: T-A11-203. Agent C: T-A11-204 after A and B. Lead: 205 regeneration, 206, runs, commits.

## Implementation strategy

MVP: springs and the stack (US1, US2) in VisualCore and the core, then the drawn springs and controls, fixtures and
records; evidence last.
