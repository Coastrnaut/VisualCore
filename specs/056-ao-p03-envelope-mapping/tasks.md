# Tasks: Audio Odyssey — Phase 03 Audio envelope mapping

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A07-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; no VisualCore change; reference regression at X-A07.

## Phase 1: Setup

- [ ] T-A07-301 Baseline: cite `.autonomy/checks/A07-P02.odyssey-ios27.json` and `.autonomy/checks/A07-P02.app-unit.json` (tree unchanged since apart from documents) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational (Core)

- [ ] T-A07-302 [US2] Core: `Packages/ExperiencesCreative/AudioOdyssey/Core/{AudioEnvelope,WorldMapping,WorldResponse}.swift` per contracts/api.md and data-model.md (envelope from 16 bands "low = bands 0–3, mid = 4–9, high = 10–15", running-peak decay 0.5 s, attack 0.03 / release 0.3 s, transient floor 0.8 on onset, overall = mean of low/mid/high; WorldResponse primary max "tunnel 0.35, landscape 0.6, star 1.0", light [0.30, 0.70]; sensitivity gains 0.6/1.0/1.6; easing factors 0.33/0.66/1.0); `TunnelResponse` kept source-compatible (typealias or wrapper of the tunnel's WorldResponse); `JourneyState` schema 3 ("speedTarget 0.5…7, step 0.5", easing, calmMotion, mappings × 3; schema 1/2 speedChoice → 2/4/7); tests `CoreTests/{AudioEnvelopeTests,WorldMappingTests,WorldResponseTests}.swift` and updated `JourneyStateTests.swift` (band grouping, normalisation, onset floor, smoothing, per-world bounds and steps, defaults, schema 1/2/3 decode, refusals) (FR-A07-301–303, 310–312, 330; SC-A07-304, 306)

## Phase 3: User Story 1 and 2 — pace and mapping (P1) 🎯

- [ ] T-A07-303 [US1] [US2] Experience: adapter (schema 3; `speed.set [0.5…7]`, `easing.select [0…2]`, `comfort.calm [0…1]`, `mapping.set [target 0…1, channel 0…4, sensitivity 0…2]` on the current world, `mapping.reset`; `speed.select` presets kept; advance with `ComfortLimits` scaled by the easing factor and reducedMotion when calm or system Reduce Motion; `schemaOneExample()` and `schemaTwoExample()`); presenter (AudioEnvelope from the FeatureExtractor output each frame → active world's WorldResponse via its WorldMapping; tunnel breathing as in A07-P02; landscape vertical swell; star corridor star scale; light → ambient; description names speed and calm motion); controls (speed slider `speed.slider`, easing picker `easing.0..2`, calm toggle `comfort.calm`, mapping editor per target `mapping.primary.channel`, `mapping.primary.sensitivity`, `mapping.light.channel`, `mapping.light.sensitivity`, `mapping.reset`); tests `ExperienceTests/{OdysseyComfortTests,OdysseyMappingTests}.swift` (200 seeded speed/easing sequences within limits and settling within 1%; gentle ≥ 2× brisk settle time; calm caps speed 2.5 and sway 0; per-world mapping isolation and reset; pulse on one channel raises only mapped responses; five source switches keep host and journey) (FR-A07-301–303, 311, 312, 320, 330)
- [ ] T-A07-304 [US3] Registry: `Apps/VisualCore/App/ExperienceRegistry.swift` passes `OdysseyCore.schemaOneExample()` and `schemaTwoExample()` (FR-A07-330)
- [ ] T-A07-305 [US3] Manifest: fixture-2 adds `speed.set` and `easing.select` steps; fixture-3 keeps the denied-microphone switch and adds two more `source.demo` switches; regenerate `Packages/ExperiencesCreative/AudioOdyssey/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) (FR-A07-331; SC-A07-305)

## Phase 4: Polish & evidence

- [ ] T-A07-306 Audio Odyssey tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name odyssey-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing AudioOdysseyCoreTests AudioOdysseyExperienceTests`)
- [ ] T-A07-307 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A07-308 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a07.audio-odyssey --runtime 27`)
- [ ] T-A07-309 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A07-310 Public API unchanged (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`)
- [ ] T-A07-311 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A07-P03 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A07-312 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A07-P03

## Dependencies

T-A07-301 → 302 → 303 → 304 → 305 → Polish.

## Parallel examples

Agent A: T-A07-302. Agent B: T-A07-303 after A passes. Lead: 304, 305, runs, commits.

## Implementation strategy

MVP: continuous speed, easing and calm motion (US1) with per-world mapping (US2); fixture continuity (US3); evidence last.
