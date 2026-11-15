# Tasks: Neon Arcade — Phase 02 Neon Dodge complete mechanics

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A10-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers). iOS 27 only; reference regression and iOS 26 at X-A10 (owner, 2026-11-14). Precedents:
`specs/075-na-p01-engine/tasks.md`, `specs/069-da-p02-schools/tasks.md`.

## Phase 1: Setup

- [X] T-A10-201 Baseline: cite the A10-P01 evidence on the unchanged tree (`.autonomy/checks/A10-P01.arcade-ios27-2.json`, `.autonomy/checks/A10-P01.app-unit.json`, `.autonomy/checks/A10-P01.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: cited .autonomy/checks/A10-P01.{arcade-ios27-2,app-unit,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — lanes, patterns, difficulty, waves (stories 1–3)

- [X] T-A10-202 [US1] Core mechanics per contracts/api.md, data-model.md, research D1–D4 and clarifications 1–4: new `Packages/ExperiencesCreative/NeonArcade/Core/{Lanes,SpawnPattern,Difficulty,WaveDirector}.swift` (five lanes, centre(i) = 0.9 + 1.8 i; patterns rain, wall (row every 120 steps, four spike-balls of radius 0.5 sharing one speed, free lane never the previous one), zigzag (spike-balls walking lanes 0→4→0), orb-trail (glow-orbs in one lane, bars in both neighbours every second gap), each with author "VisualCore project" and license "MIT"; `Difficulty(wave:)` with level = min(wave − 1, 8), fall speed (3 + 0.2 L)…min(5, 3.6 + 0.2 L), spawn gap max(20, 40 − 2.5 L), orb multiplier 1 + L / 2; `WaveDirector` with wave length 600, first spawn at wave step 30, wave 1 `rain`, later waves uniform among the other three patterns); modify `Core/GameRun.swift` (schema 2: `wave` ≥ 1, `waveStep` 0…599, `patternId`, `freeLane` −1…4, `patternCursor` 0…7; decodes schema 1 and `migrated()` sets wave 1, step 0, rain, −1, 0), `Core/GameSimulation.swift` (spawns through the director, survival + 1 per 60 steps of play, orb value × multiplier, cap kept; the capsule bound kept) and `Core/LicenseAudit.swift` (pattern rows, role `pattern`); tests new `CoreTests/{WaveDirectorTests,DifficultyTests,GameRunMigrationTests}.swift` and updated `CoreTests/{GameSimulationTests,ReplayTests,GameRunTests,LicenseAuditTests,ArcadeCatalogTests}.swift`: 20 seeds × 10,000 steps every wave spawn at a lane centre and ≥ 3 patterns per seed; waves advance every 600 steps; difficulty non-decreasing and capped, capsule bound at the ceiling; every wall has exactly one free lane, never the previous one, reachable in time (research D3 arithmetic); survival and multiplier scoring; paused/over unchanged; a restart in a late wave starts wave 1 with `rain`; schema-1 JSON migrates keeping score, lives, player and objects; replay identical (FR-A10-201–205, 210, 211; SC-A10-201–205) — Verified 2026-11-14: 2026-11-14: Lanes, SpawnPattern/PatternTable, Difficulty, WaveDirector; GameRun schema 2 with migrated(); survival and multiplier scoring; 59 core tests incl. WaveDirectorTests, DifficultyTests, GameRunMigrationTests pass on sim-27.2 (.autonomy/checks/A10-P02.arcade-ios27.json)

## Phase 3: Stories 1–3 — the experience (P1)

- [X] T-A10-203 [US3] Experience: `Packages/ExperiencesCreative/NeonArcade/Experience/Adapter/ArcadeCore.swift` (snapshot schema 2, `MigrationChain(currentVersion: 2)` with step 1 → 2 rewriting the run per clarification 4, restore validates the migrated run, `schemaOneExample(seed:)`), `Experience/ArcadePresenter.swift` (five dim lane guides, wave digits beside the score, "wave n" in the description); `Apps/VisualCore/App/ExperienceRegistry.swift` registers the schema-1 example; tests in `ExperienceTests/{ArcadeCoreTests,ArcadeSessionTests,ArcadeRenderTests}.swift` (schema-1 snapshot restores in a new engine with score, lives, player and objects kept; a suspension of any length in wave 3 leaves wave, step, objects and score identical; lane guides drawn at the lane centres; description names the wave; drawing never changes the digest) (FR-A10-210, 211, 220; SC-A10-204) — Verified 2026-11-14: 2026-11-14: snapshot schema 2 with migration 1→2 and schemaOneExample (registered); lane guides from y 2 (probe area plain), wave digits, 'wave n' in the description; ArcadeCore/Session/Render tests pass on sim-27.2 (A10-P02.arcade-ios27, 105 tests)
- [X] T-A10-204 [US3] Manifest: `Experience/Adapter/ArcadeManifest.swift` fixtures 8–11 per research D5 (wave progression, wall gap, background/resume in wave 3, Phase 01 migration), regenerate `Packages/ExperiencesCreative/NeonArcade/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) and `docs/apps/neon-arcade/content-licenses.md`; `ExperienceTests/ArcadeManifestTests.swift` covers the new fixtures (FR-A10-221, 222; SC-A10-206) — Verified 2026-11-14: 2026-11-14: fixtures 8–11 (wave progression, wall gap, background/resume in wave 3, Phase 01 migration); scenario-manifest.json and content-licenses.md regenerated (UPDATE_SCENARIO_MANIFEST=1); ArcadeManifestTests and the license document test pass (A10-P02.arcade-ios27)
- [X] T-A10-205 [US1] Contract: `docs/apps/neon-arcade/visualcore-contract.json` G-GAMERULES closed by "A10-P02" (rows M07, M08, M17 available with the new evidence); `python3 Tools/python/desktop_runbook.py run-check --stage A10-P02 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render` — Verified 2026-11-14: 2026-11-14: contract G-GAMERULES closed by A10-P02; M07, M08, M17 available with VisualCore evidence and NeonArcade examples; .autonomy/checks/A10-P02.contract-2.json exit 0 (17 rows, 95 citations); the first attempt (contract) failed on experience products cited as evidence

## Phase 4: Polish & evidence

- [ ] T-A10-206 Arcade tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P02 --timeout 600 --name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`; each test < 10 s) (SC-A10-201–206)
- [ ] T-A10-207 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P02 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A10-208 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A10-P02 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`)
- [ ] T-A10-209 Experience package check and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A10-210 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P02

## Dependencies

T-A10-201 → 202 → 203 → 204 → 205 → Polish.

## Parallel examples

Agent A: T-A10-202. Agent B: T-A10-203 and 204's Swift files after A. Lead: registry, regeneration, contract, runs,
commits.

## Implementation strategy

MVP: the wave director with difficulty and scoring (US1, US2), then the saved-state migration and the drawn lanes
(US3); evidence last.
