# Tasks: Oscilloscope Studio — Phase 01 Audio fixture and acquisition interface

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A08-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A08
(owner, 2026-11-14).

## Phase 1: Setup

- [X] T-A08-101 Baseline: cite the last package evidence on an unchanged `Packages` tree (`.autonomy/checks/A08-P00.app-build.json`, `.autonomy/migration/checks/X-A07.followthrough-odyssey.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: Packages unchanged since the X-A07 follow-through; cites .autonomy/checks/A08-P00.app-build.json and .autonomy/migration/checks/X-A07.followthrough-odyssey.json

## Phase 2: Foundational (VisualCore, stories 1 and 2)

- [X] T-A08-102 [P] [US2] Write `Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{TestSignalTests,StereoSampleBufferTests,ScopeTriggerTests}.swift` first, then `Packages/VisualCore/Sources/VisualCoreAudioDSP/{TestSignal,StereoSampleBuffer,ScopeTrigger}.swift` per contracts/api.md and data-model.md (`TestSignal` sine/square/logarithmic sweep "f(t) = f0 · (f1/f0)^(t/T)", amplitude 0…1, frequency 20…20,000 Hz, `channelCount` 1 or 2, `rightRatio` > 0, `rightPhase`; `StereoSampleBuffer` "capacityFrames power of two 1,024…131,072", interleaved, frame counter published after whole blocks, `frames(from:count:left:right:)` returns 0 for overwritten or unwritten ranges; `ScopeTrigger.find` rising/falling with hysteresis "default 0.02", `TriggerMode` auto/normal, `TimebaseWindow` 10 divisions, "maxSamples 4,096", `isShortened`; all public with `///` docs); tests: sine/square/sweep values at sampled frames within 1e-6 of the closed form, square takes only ±amplitude, the sweep's instantaneous frequency after 1 s of a 100 Hz→10 kHz/2 s sweep is 1 kHz within 1 %, two channels keep their own frequencies, render in chunks equals render at once, buffer wrap and overwrite detection, trigger within one sample of the true crossing over 100 noisy windows (noise −40 dBFS), flat line and out-of-range level give nil, falling slope, NaN level refused, `TimebaseWindow` sample counts for 44.1/48/96 kHz and the 4,096 cap (FR-A08-101, 103, 104; SC-A08-101, 103, 104) — Verified 2026-11-14: 2026-11-14: TestSignal, StereoSampleBuffer, ScopeTrigger/TimebaseWindow + 3 test files; CI=1 swift test --filter TestSignalTests|StereoSampleBufferTests|ScopeTriggerTests: 23 tests pass
- [ ] T-A08-103 [US2] Write `Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/{TestSignalAudioSourceTests,StereoFileAudioSourceTests}.swift` and `Packages/VisualCoreRendering/Sources/VisualCoreAudio/{StereoAudioSource,TestSignalAudioSource,StereoFileAudioSource}.swift` per contracts/api.md (real-time pace in 1,024-frame blocks like `DemoAudioSource`, catch-up ≤ 8 blocks, first block written by `start`; the file source keeps a stereo file's two channels, a mono file reports `channelCount` 1, `AudioSourceError.undecodable` for a damaged file; tests write temporary WAV files generated in the test, never committed audio) (FR-A08-102)

## Phase 3: User Story 1 — a steady, triggered waveform (P1) 🎯

- [ ] T-A08-104 [P] [US1] Create the core target `Packages/ExperiencesCreative/OscilloscopeStudio/Core/{ScopeSettings,ScopeState,SignalWindow,ScopeAcquisition}.swift` and `CoreTests/{ScopeStateTests,SignalWindowTests,ScopeAcquisitionTests}.swift`: `ScopeState` schema 1 per data-model.md (source ∈ {testSignal, file, microphone}; frequency index into {100, 440, 1,000, 5,000 Hz}; gain index into {0.5, 1, 2, 5, 10}; timebase index into {0.1, 0.2, 0.5, 1, 2, 5 ms/div}; trigger level −1…1 finite; unknown indices refused; digest), `ScopeAcquisition` building a `SignalWindow` from a `StereoSampleBuffer` or a mono `SampleRingBuffer` with the trigger (auto fallback marked untriggered, normal keeps the last window marked waiting), gain and clipping; tests: periods per window for 100 Hz/440 Hz/1 kHz/5 kHz at every timebase within ±0.1, the spectrum peak bin of a 4,096-sample 1 kHz window is `SpectrumAnalyzer.expectedBin` (85), 440 Hz at 5 ms/div gives 22 ± 0.1 periods, consecutive windows start on the same phase, flat line untriggered, partial window when the buffer is short, mono window has one channel, gain ×2 doubles extent and marks clipping (FR-A08-110, 111; SC-A08-101, 102)
- [ ] T-A08-105 [US1] Create the experience targets in `Packages/ExperiencesCreative/Package.swift` (`OscilloscopeStudioCore`, `OscilloscopeStudioCoreTests`, `OscilloscopeStudioExperience`, `OscilloscopeStudioExperienceTests`, product `OscilloscopeStudioExperience`) and `Experience/{Adapter/ScopeCore.swift,ScopePresenter.swift,ScopeControls.swift,OscilloscopeStudioExperience.swift}`: adapter (ExperienceCore; actions `source.select`, `signal.waveform`, `signal.frequency`, `gain.select`, `timebase.select`, `trigger.level`, `trigger.slope`, `trigger.mode` with `a08.*` rejection codes; digest; snapshot schema 1), presenter (active source and buffer, `ScopeAcquisition` each frame, grid and trace as `.line` `SceneNode`s through `PrimitiveRenderer` with `Camera2D`, at most one segment per displayed sample; stop on suspend, fresh buffer on activate; microphone through `MicrophoneAudioSource` and the shared permission; "Choose file…" through the system file picker with the undecodable case; spoken description of source, channels, timebase, gain, trigger state, clipping), controls (pickers and buttons with labels and identifiers); tests `ExperienceTests/{ScopeCoreTests,ScopeSessionTests,ScopeRenderTests}.swift` (actions and rejections; snapshot round trip; suspend/activate; denied microphone keeps the previous source; rendered frames of sine and square differ and are non-blank; no context created by the experience) (FR-A08-110, 111, 121, 122, 130)

## Phase 4: User Story 2 — known test signals and sources (P1)

- [ ] T-A08-106 [US2] Register: `Catalog/registrations.json` entry for a08 (capabilities, quality_tiers ["level-0"], palette, content), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency on the product, `scripts/test_scripts.py` products list and `Packages/VisualCore/Tests/VisualCoreExperienceTests/RealCatalogTests.swift` registrations, `xcodegen generate --spec project.yml` (FR-A08-120)

## Phase 5: User Story 3 — the regression fixture (P2)

- [ ] T-A08-107 [US3] Write `Experience/Adapter/ScopeManifest.swift` (nine standard scenarios + fixture-1 1 kHz periods at 1 ms/div, fixture-2 spectrum bin, fixture-3 flat line no trigger) and generate `Packages/ExperiencesCreative/OscilloscopeStudio/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`), with `ExperienceTests/ScopeManifestTests.swift` (FR-A08-120; SC-A08-105)

## Phase 6: Polish & evidence

- [ ] T-A08-108 VisualCoreAudioDSP host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name dsp-host -- swift test --package-path Packages/VisualCore --filter "TestSignalTests|StereoSampleBufferTests|ScopeTriggerTests"`)
- [ ] T-A08-109 VisualCoreAudio sources on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name audio-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests`)
- [ ] T-A08-110 Core tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name core-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests`)
- [ ] T-A08-111 Experience tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name experience-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioExperienceTests`)
- [ ] T-A08-112 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A08-113 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27`)
- [ ] T-A08-114 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`)
- [ ] T-A08-115 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; `Packages/VisualCore/README.md` (test signal, stereo buffer, trigger) and `Packages/VisualCoreRendering/README.md` (two-channel sources); contract G-DEMOWAVES, G-TRIGGER and G-STEREO (test-signal and file paths; microphone part re-owned by A08-P05) closed by "A08-P01" and `python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render`
- [ ] T-A08-116 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P01 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A08-117 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A08-P01

## Dependencies

T-A08-101 → (102 ∥ 104) → 103 (needs 102's buffer) → 105 → 106 → 107 → Polish. 104 depends on the 102 contract only.

## Parallel examples

Agent A: T-A08-102. Agent B: T-A08-104 (against contracts/api.md; builds after A lands). Agent C: T-A08-103 after A.
Agent D: the presenter, controls and tests of 105 once 102–104 pass. Lead: 105 skeleton, 106, 107, docs, runs, commits.

## Implementation strategy

MVP: test signal, trigger and the triggered window (US1 with the US2 foundation); then two-channel sources and the
fixture scenarios; evidence last.
