# Tasks: Neon Arcade — Phase 03 Visual effects and audio/haptics

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A10-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A10-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers). iOS 27 only; reference regression and iOS 26 at X-A10 (owner, 2026-11-14). Precedents:
`specs/075-na-p01-engine/tasks.md`, `specs/076-na-p02-mechanics/tasks.md`.

## Phase 1: Setup

- [X] T-A10-301 Baseline: cite the A10-P02 evidence on the unchanged tree (`.autonomy/checks/A10-P02.{arcade-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: cited .autonomy/checks/A10-P02.{arcade-ios27,app-unit,verify-27}.json on the unchanged tree (no rerun)

## Phase 2: Foundational — VisualCore sound effects (story 2) and the core flow and effects (stories 1–3)

- [X] T-A10-302 [P] [US2] Write `Packages/VisualCore/Tests/VisualCoreAudioDSPTests/SoundEffectSynthTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreAudioDSP/SoundEffect.swift` per contracts/api.md and research D1 (`SoundWaveform`, `SoundEffect` with "startFrequency, endFrequency 40…4,000 Hz", "duration 0.02…1 s", "attack, release ≥ 0.002 s", "noise 0…1", "gain 0…0.9", `isValid`; `SoundEffectSynth.render(_:sampleRate:)`; public with `///` docs); tests: identical output twice, sample count = duration × rate, every sample finite and |s| ≤ gain, first and last 2 ms within 5 % of silence, each waveform's zero crossings follow the frequency sweep within 5 %, noise changes the buffer deterministically, invalid effects render an empty buffer; then write `Packages/VisualCoreRendering/Tests/VisualCoreAudioTests/SoundEffectPlayerTests.swift` and `Packages/VisualCoreRendering/Sources/VisualCoreAudio/SoundEffectPlayer.swift` per research D2 (4 voices, `.ambient`, lazy engine start, `isEnabled`, `play(_:id:) -> Bool`, `stopAll()`, `activeVoices`, interruption and background → stopAll); simulator tests: playing needs no microphone permission and never touches the input node, a disabled player plays nothing, a fifth simultaneous request is dropped, `stopAll()` leaves 0 active voices, an interruption notification stops playback (FR-A10-301, 302; SC-A10-302, 303) — Verified 2026-11-14: 2026-11-14: SoundEffect/SoundEffectSynth (VisualCoreAudioDSP; 8 host tests, .autonomy/checks/A10-P03.audio-dsp-host.json) and SoundEffectPlayer (VisualCoreAudio, ambient, 4 voices; 9 simulator tests incl. a real-engine run, A10-P03.audio-player-ios27-2.json; the first run failed on a wrong stop-count expectation in the test)
- [X] T-A10-303 [P] [US1] Core: new `Packages/ExperiencesCreative/NeonArcade/Core/{ArcadeFlow,ArcadeEffects}.swift` per research D3–D4 and clarifications 2–5 (`ArcadeScreen` title/playing/paused/over; `ArcadeFlow` transitions and refusal; `EffectCue` and `ArcadeEffects.plan(previous:current:)` with "3 visual cues and 2 sound cues per step"; `ArcadeSound` with the four shapes of clarification 4 and their haptic kinds); tests new `Packages/ExperiencesCreative/NeonArcade/CoreTests/{ArcadeFlowTests,ArcadeEffectsTests,HighSpeedFixtureTests}.swift` (every allowed and refused transition; cues for pickup, hit, wave and over in event order, capped, none for an unchanged run; sound shapes valid and within the data-model limits; high-speed circle hazards at 20, 50, 100 units/s crossing the player within one step are hit at that step and the same 1.5 units sideways are not) (FR-A10-310, 320, 330; SC-A10-301, 305) — Verified 2026-11-14: 2026-11-14: ArcadeFlow (screens, transitions, refusals), ArcadeEffects (cue plan, 3 visual / 2 sound caps, ArcadeSound shapes), HighSpeedFixtureTests (20, 50, 100 units/s hit; side pass none); 80 core tests pass on the host (core targets only); simulator run in T-A10-308

## Phase 3: Stories 1–3 — the experience (P1)

- [ ] T-A10-304 [US1] Experience: `Packages/ExperiencesCreative/Package.swift` (NeonArcadeExperience and its tests gain `VisualCoreAudio` and `VisualCoreAudioDSP`); `NeonArcade/Experience/Adapter/ArcadeCore.swift` (snapshot schema 3 with `screen`, `sound`, `haptics`, migration 2 → 3 per clarification 2, `schemaTwoExample()`, new experiences open on title, actions run.start, settings.sound, settings.haptics and the screen rules with `a10.wrong-screen`, only playing advances); `NeonArcade/Experience/{ArcadePresenter,ArcadeControls}.swift` and new `NeonArcade/Experience/ArcadeEffectsLayer.swift` (title, paused and game-over screens with score and wave, cross-fades of `transitionDuration(0.25, reduceMotion:)`, particle bursts through `ParticleSystem`/`ParticleRenderer` advanced by game steps and drawn below the collision shapes, hit ring and tint or outline under reduced flashing, wave sweep, sounds through `SoundEffectPlayer` and haptics through `ExperienceFeedback` honouring the settings, `run.pause [1]` sent on suspension while playing, `stopAll()` in teardown and on suspension, controls Start/Play again, Sound, Haptics with labels and values); `Apps/VisualCore/App/ExperienceRegistry.swift` adds `schemaTwoExample()`; tests in `NeonArcade/ExperienceTests/` (flow through actions and refusals; schema-1 and schema-2 snapshots restore; title on a new experience; suspension while playing records a pause; identical digests with effects, sound and haptics on or off and with reduced flashing; effects freeze while paused; injected sound and haptic sinks receive the cues only when enabled; screens spoken; a saved title or game-over screen restores to the same screen; under Reduce Motion the screen cross-fade lasts 0 s) (FR-A10-310, 311, 320, 321; SC-A10-301, 304)
- [ ] T-A10-305 [US3] Manifest: `NeonArcade/Experience/Adapter/ArcadeManifest.swift` fixtures 12–14 per research D5 (run past its first hit naming `HighSpeedFixtureTests`; title → start; settings off) with fixtures 1–11 starting with `run.start`; regenerate `NeonArcade/scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`); `ExperienceTests/ArcadeManifestTests.swift` (FR-A10-330; SC-A10-306)
- [ ] T-A10-306 [US2] VisualCore records and contract: `Packages/VisualCore/README.md` (sound effects), API baseline (`python3 scripts/check_public_api.py --update`), `docs/apps/neon-arcade/visualcore-contract.json` (G-SOUNDFX and G-TRANSITIONS closed by "A10-P03"; rows M06, M09, M12 updated; G-COLLISION2D's phase-3 proof recorded); `python3 Tools/python/desktop_runbook.py run-check --stage A10-P03 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app neon-arcade --render` (FR-A10-303)

## Phase 4: Polish & evidence

- [ ] T-A10-307 VisualCore tests: host (`--name audio-dsp-host -- swift test --package-path Packages/VisualCore --filter SoundEffectSynthTests`), rendering package player tests (`--name audio-player-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --only-testing VisualCoreAudioTests/SoundEffectPlayerTests`) and public API (`--name public-api -- python3 scripts/check_public_api.py`) (SC-A10-302, 303)
- [ ] T-A10-308 Arcade tests on sim-27.2 (`--name arcade-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing NeonArcadeCoreTests NeonArcadeExperienceTests`; each test < 10 s) (SC-A10-301–306)
- [ ] T-A10-309 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner iOS 27 (`--name verify-27 -- python3 scripts/verify_experiences.py --only a10.neon-arcade --runtime 27`)
- [ ] T-A10-310 Experience package check and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A10-311 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A10-P03

## Dependencies

T-A10-301 → (302 ∥ 303) → 304 (needs both) → 305 → 306 → Polish.

## Parallel examples

Agent A: T-A10-302. Agent B: T-A10-303. Agent C: T-A10-304/305 Swift files after A and B. Lead: Package.swift,
registry, regeneration, README, API baseline, contract, runs, commits.

## Implementation strategy

MVP: the flow (US1) and the high-speed fixture (US3) in the core; then the sound engine and the effects (US2); evidence
last.
