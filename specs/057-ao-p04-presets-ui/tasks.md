# Tasks: Audio Odyssey — Phase 04 Multi-world presets and UI

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A07-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; no VisualCore change; reference regression at X-A07.

## Phase 1: Setup

- [X] T-A07-401 Baseline: cite `.autonomy/checks/A07-P03.odyssey-ios27-3.json` and `.autonomy/checks/A07-P03.app-unit.json` (tree unchanged since apart from documents) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: Verified 2026-11-14: cited .autonomy/checks/A07-P03.odyssey-ios27-3.json and A07-P03.app-unit.json (tree unchanged since apart from documents); no rerun (owner ruling 2026-11-14)

## Phase 2: Foundational (Core)

- [X] T-A07-402 [US1] [US3] Core: `Packages/ExperiencesCreative/AudioOdyssey/Core/{JourneyPreset,DemoResponseTrace}.swift` per contracts/api.md and data-model.md ("name (cleaned, ≤ 60, empty → 'Untitled')", format 1 sorted keys, file name `journey-<lowercased uuid>.json`, built-ins "Deep tunnel"/"Rolling hills"/"Night stars" with ids …7B1–7B3 and saved 0, `actionValues` 16 numbers); tests `CoreTests/{JourneyPresetTests,DemoResponseTraceTests}.swift` (clean and unique names, round trip, newer and malformed refused, file-name round trip, built-ins valid and distinct, actionValues layout; trace deterministic within 1e-6 and rising ≥ 25% of range within 120 frames on synthetic loud frames per world) (FR-A07-401–404, 420) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.core-ios27.json exit 0 (76 Core tests on sim-27.2: JourneyPreset names, round trip, newer/malformed refusals, file names, built-ins, 16 action values and their validation; DemoResponseTrace determinism and >= 25% rise per world on synthetic frames, silence at rest); contract updated to TracePoint and fromActionValues

## Phase 3: User Story 1 and 2 — journeys and sound (P1) 🎯

- [X] T-A07-403 [US1] [US2] Experience: `Experience/JourneyPresetStore.swift` (as A06's store: built-ins first, user presets by name ignoring case, unreadable/newer counted and untouched, atomic writes, refusals for built-ins, plain messages with storage codes); adapter action `preset.apply [16]` (rule `a07.invalid-preset` on any invalid value, applied atomically); factory passes `launch.storage` to the store; presenter reloads the store on activate and keeps the selected preset id and source display state; controls grouped as Journey, Sound (segmented `source.picker`, `source.status`, permission message, mapping editor), Comfort, Journeys (list `preset.<n>`, `preset.save` with a name field, `preset.rename`, `preset.delete`, store messages); tests `ExperienceTests/{JourneyPresetStoreTests,OdysseyPresetApplyTests,OdysseySourcePickerTests}.swift` (save/apply/rename/delete with a temporary storage, quota refusal leaves files unchanged, damaged and newer files counted and byte-identical, apply sets all six fields and eases speed, built-ins refused; source status, file name and permission message per state) (FR-A07-401–404, 410, 430) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.odyssey-ios27.json exit 0 (JourneyPresetStoreTests: round trips of all six fields, 200 seeded unique-name operations, built-ins refused, damaged/newer/built-in-id files counted and byte-identical, quota refusal changes nothing; OdysseyPresetApplyTests: atomic apply, invalid values refused whole, speed eases, paused stays paused; OdysseySourcePickerTests: status, file name, permission message per state); controls grouped Journey, Sound, Comfort, Journeys
- [X] T-A07-404 [US3] Fixture: `ExperienceTests/OdysseyDemoTraceTests.swift` produces analysis frames from the real demo source (fixed seed) through `FeatureExtractor` at fixed 1/60 s steps and asserts DemoResponseTrace determinism and the 25% rise in every world; a host-rendered run of the demo for 120 frames gives the same presenter response sequence twice (FR-A07-420; SC-A07-404) — Verified 2026-11-14: Verified 2026-11-14: OdysseyDemoTraceTests pass in .autonomy/checks/A07-P04.odyssey-ios27.json (real demo seed 7 through FeatureExtractor, 120 frames at 1/60 s: traces equal in every world, maxRise tunnel 0.997, landscape 1.0, star corridor 0.417 >= 0.25; host-rendered runs equal within 1e-6)
- [X] T-A07-405 [US1] Manifest: a fixture-4 step applies the built-in "Rolling hills" with `preset.apply` before the steady flight; regenerate `Packages/ExperiencesCreative/AudioOdyssey/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) (FR-A07-402) — Verified 2026-11-14: Verified 2026-11-14: scenario-manifest.json regenerated (16 controls; fixture-4 applies Rolling hills first); runner .autonomy/checks/A07-P04.verify-27.json 0 failures

## Phase 4: Polish & evidence

- [X] T-A07-406 Audio Odyssey tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name odyssey-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyCoreTests AudioOdysseyExperienceTests`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.odyssey-ios27.json exit 0
- [X] T-A07-407 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.app-unit.json exit 0
- [X] T-A07-408 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.verify-27.json exit 0 (nine standard scenarios)
- [X] T-A07-409 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.experience-packages.json exit 0
- [X] T-A07-410 Public API unchanged (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.public-api.json exit 0 (no VisualCore change)
- [X] T-A07-411 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P04 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) — Verified 2026-11-14: Verified 2026-11-14: .autonomy/checks/A07-P04.script-tests.json exit 0; VisualCore host suite in CI mode .autonomy/checks/A07-P04.visualcore-host-ci.json exit 0 (the CI catalog fix); the local-mode run visualcore-host-2 failed only on two pre-existing local wall-clock bounds (mesh budget 5.97 s vs 5 s, analysis timing) under an external machine load average near 800 from other repositories' builds
- [ ] T-A07-412 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A07-P04

## Dependencies

T-A07-401 → 402 → (403 ∥ 404) → 405 → Polish. 403 and 404 touch different test files; 403 owns the presenter.

## Parallel examples

Agent A: T-A07-402. Agent B: T-A07-403 (+ manifest code of 405). Agent C: T-A07-404 after 402. Lead: 405, runs, commits.

## Implementation strategy

MVP: journey presets (US1) and the clear source picker (US2); the demo fixture (US3); evidence last.

## Phase 5: Convergence

- [X] T-A07-413 Record in `specs/057-ao-p04-presets-ui/plan.md` (Lifecycle) that the preset store reloads in the presenter's `setup()` (every open and context recovery; the presenter protocol has no activate hook), as `Packages/ExperiencesCreative/AudioOdyssey/Experience/OdysseyPresenter.swift` does per plan: Lifecycle (contradicts) — Verified 2026-11-14: Verified 2026-11-14: plan.md Lifecycle now states the reload in setup() (every open and context recovery), matching OdysseyPresenter.swift line 361; validate_docs passed in the tick
