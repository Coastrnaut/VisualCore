# Tasks: VisualCore Music Lab — Phase 01 Audio source and permission shell

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A06-P01 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A06
(owner, 2026-11-14).

## Phase 1: Setup

- [X] T-A06-101 Baseline: cite the last package evidence on an unchanged `Packages/ExperiencesCreative` and VisualCore source tree (`.autonomy/migration/checks/X-A05.host.json`, `.autonomy/checks/A06-P00.app-build.json`) instead of a rerun (owner ruling 4 of 2026-11-14) — Verified 2026-11-14: 2026-11-14 cited: .autonomy/migration/checks/X-A05.host.json (ExperiencesCreative after its last source change) and .autonomy/checks/A06-P00.app-build.json; no rerun (owner ruling 2026-11-14)

## Phase 2: Foundational (VisualCore, story 3)

- [X] T-A06-102 [P] [US3] Add `VisualCoreAudioDSPTests` testTarget to `Packages/VisualCore/Package.swift`; write `Packages/VisualCore/Tests/VisualCoreAudioDSPTests/{SampleRingBufferTests,DemoSignalTests,SpectrumAnalyzerTests}.swift` first, then `Packages/VisualCore/Sources/VisualCoreAudioDSP/{SampleRingBuffer,DemoSignal,SpectrumAnalyzer}.swift` per contracts/api.md ("capacity rounded up to a power of two, 1,024…262,144"; "N power of two 256…4,096"); tests: sine 440/1k/5k at 48 kHz N=1,024 peak bin ±1 and ≥ 20 dB over bins > 2 away; silence → no peak; 200 seeded write/read sequences vs a reference model; overflow drops oldest; writer allocation-free over 10,000 writes (malloc zone counter, local only); demo determinism per seed and modes (FR-A06-102, 110, 111; SC-A06-101–103) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A06-P01.dsp-host.json (17 tests: spectrum peaks 440/1k/5k within ±1 and ≥ 20 dB; silence; demo determinism; ring buffer vs model)
- [X] T-A06-103 [P] [US2] Add `VisualCoreAudioTests` testTarget to `Packages/VisualCoreRendering/Package.swift`; write `Packages/VisualCoreRendering/Sources/VisualCoreAudio/{AudioSource,DemoAudioSource,FileAudioSource,MicrophoneAudioSource,MicrophonePermission}.swift` per contracts/api.md and `Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/{DemoAudioSourceTests,FileAudioSourceTests,MicrophoneSourceTests}.swift`: demo source fills the buffer at its rate; files generated at runtime (WAV, CAF, M4A tones) decode to the expected rate and sample count and loop; a garbage file throws; microphone with permission double: denied/restricted → start throws without engine use, notDetermined → request called once; session category mixes with others (FR-A06-101, 103–105, 107; SC-A06-104, 105) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A06-P01.rendering-ios27.json (VisualCoreAudioTests 17/17: demo, WAV/CAF/M4A decode and loop, garbage refused, permission states, session mixes with others)

## Phase 3: User Story 1 — choose a source and see it (P1) 🎯

- [X] T-A06-104 [US1] Create the experience in `Packages/ExperiencesCreative/VisualCoreMusicLab` (four targets + product in `Packages/ExperiencesCreative/Package.swift`: Core, Experience, CoreTests, ExperienceTests, as for InfiniteGeometry): `Core/{SourceKind,MusicLabState}.swift` (state per data-model.md "fileName ≤ 120 chars"), `Experience/Adapter/MusicLabCore.swift` (ExperienceCore: actions source.demo/source.microphone/source.file/demo.mode/demo.reseed, digest, snapshot schema 1), `Experience/MusicLabPresenter.swift` (owns the active AudioSource and a SampleRingBuffer; draws the latest 1,024 samples as a waveform with PrimitiveRenderer; status text; source lifecycle with the session; spoken description), `Experience/MusicLabControls.swift` (Demo, Microphone, Choose file… (fileImporter), demo mode picker, reseed; labels/identifiers; permission message with Settings link), `Experience/VisualCoreMusicLabExperience.swift` (make), tests `CoreTests/MusicLabStateTests.swift` and `ExperienceTests/{MusicLabCoreTests,MusicLabSessionTests}.swift` (session draws a waveform that matches the demo signal's samples at probe columns; permission-denied falls back to demo; leaving stops the source; five rapid switches end with only the last source running) (FR-A06-120–122) — Verified 2026-11-14: 2026-11-14: experiences-ios27-2 (VisualCoreMusicLab Core/Experience tests pass), commit dd31b0e3
- [X] T-A06-105 [US1] Register: `Catalog/registrations.json` entry for a06 (capabilities, quality_tiers ["level-0"], palette, content), candidate in `Apps/VisualCore/App/ExperienceRegistry.swift`, `project.yml` dependency on the product and `NSMicrophoneUsageDescription` ("Listens to sound in the room to drive the visuals; audio stays on this device and is not recorded."), `xcodegen generate --spec project.yml` (FR-A06-106) — Verified 2026-11-14: 2026-11-14: script-tests-2, app-unit-3 (registration, usage key, candidate), commit dd31b0e3
- [X] T-A06-106 [US1] Write `Packages/ExperiencesCreative/VisualCoreMusicLab/Experience/Adapter/MusicLabManifest.swift` (nine standard scenarios + fixture-1…5 per research D6) and generate `Packages/ExperiencesCreative/VisualCoreMusicLab/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) (FR-A06-120) — Verified 2026-11-14: 2026-11-14: experiences-ios27-2 (MusicLabManifestTests), scenario-manifest.json, commit dd31b0e3

## Phase 4: Polish & evidence

- [X] T-A06-107 DSP host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name dsp-host -- swift test --package-path Packages/VisualCore --filter "SampleRingBufferTests|DemoSignalTests|SpectrumAnalyzerTests"`) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A06-P01.dsp-host.json (exit 0)
- [X] T-A06-108 Rendering package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`) — Verified 2026-11-14: 2026-11-14 .autonomy/checks/A06-P01.rendering-ios27.json (exit 0)
- [X] T-A06-109 Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.experiences-ios27-2.json
- [X] T-A06-110 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.app-unit-3.json
- [X] T-A06-111 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a06.visualcore-music-lab --runtime 27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.verify-27-2.json (0 failures)
- [X] T-A06-112 Experience package check (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.experience-packages.json
- [X] T-A06-113 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; READMEs of VisualCore (VisualCoreAudioDSP) and VisualCoreRendering (VisualCoreAudio); Auto-Creator.md §13 rows (audio products no longer placeholders) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.public-api.json; READMEs and Auto-Creator §13 updated
- [X] T-A06-114 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A06-P01.script-tests-2.json
- [ ] T-A06-115 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A06-P01

## Dependencies

T-A06-101 → (102 ∥ 103) → 104 → 105 → 106 → Polish.

## Parallel examples

Agent A: T-A06-102. Agent B: T-A06-103. Agent C: T-A06-104 (against contracts/api.md). Lead: 105, 106, docs, runs, commits.

## Phase 5: Convergence

- [ ] T-A06-116 Add `testAnUndecodableFileKeepsThePreviousSourceAndShowsAMessage` to `Packages/ExperiencesCreative/VisualCoreMusicLab/ExperienceTests/MusicLabSessionTests.swift` (factory `file` closure throws `AudioSourceError.undecodable`; the demo keeps running, the message is `MusicLabPresenter.undecodableMessage`, the digest is unchanged) and record `python3 Tools/python/desktop_runbook.py run-check --stage A06-P01 --timeout 600 --name experiences-ios27-3 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing VisualCoreMusicLabExperienceTests` per SC-A06-104, FR-A06-103 (partial)
- [ ] T-A06-117 Amend `specs/047-ml-p01-audio-source/data-model.md` "MusicLabState": digest = source, demoSeed, demoMode; fileName is display-only (not in digest or snapshot), as recorded in `MusicLabCore.swift` per data-model digest (contradicts)

## Implementation strategy

MVP: demo/file/microphone sources with the waveform (US1, US2) on the DSP/audio layer (US3); evidence last.
