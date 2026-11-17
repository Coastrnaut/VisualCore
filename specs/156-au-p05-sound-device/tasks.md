# Tasks: Aurora — Phase 05 Long-run thermal and comfort validation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/sound.md](contracts/sound.md), [quickstart.md](quickstart.md). Gate A21-P05 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A21-P05 --timeout 595 --name <check> -- <command>`.
- **Commits:** one per task, with no trailers.
- **Checks:** read every check's exit before ticking, never in the same command.
- **Scope:** iOS 27 only; no device step; no VisualCore change.
- **Precedent:** `specs/149-zg-p05-quiet-device/tasks.md`. **Rollback:** revert the commits.

## Phase 1: Setup

- [X] T-A21-501 Baseline: cite the A21-P04 evidence (`.autonomy/checks/A21-P04.{au-ios27,app-unit,verify-27}.json`) on — Verified 2026-11-17: 2026-11-17: A21-P04 evidence cited: .autonomy/checks/A21-P04.au-ios27.json, A21-P04.app-unit.json and A21-P04.verify-27.json, all exit 0; no Packages, Apps or project.yml change since the A21-P04 record commit dce6aed6
  the tree recorded at A21-P04 (`dce6aed6`), whose Packages, Apps and `project.yml` are unchanged since (owner ruling
  of 2026-11-14)
- [X] T-A21-502 Add `VisualCoreAudio` (package `rendering`) and `VisualCoreAudioDSP` (package `visualCore`) to the — Verified 2026-11-17: 2026-11-17: AuroraExperience and AuroraExperienceTests gain VisualCoreAudio and VisualCoreAudioDSP (commit 4be85523); the package resolves (swift package describe) and builds and tests: .autonomy/checks/A21-P05.au-ios27.json exit 0
  `AuroraExperience` target of `Packages/ExperiencesCreative/Package.swift` (lead; the package still resolves and
  builds)

## Phase 2: Story 1 — a quiet loop, only when asked (P1) 🎯

- [X] T-A21-503 [P] [US1] Experience (agent E), per contracts/sound.md and data-model.md: — Verified 2026-11-17: 2026-11-17: SkySound.swift (SkyLoopPlaying, AmbientLoopPlayer conformance, SkySound plays while wanted, on screen and active; lazy player), AuroraPresenter (sound seeded from prefs, setSound/setVolume drive it, controlsAppeared/controlsDisappeared/sceneActive; drawing never touches it; fixedDelta test seam), AuroraControls (onAppear/onDisappear, scenePhase, new hints), AuroraExperience loop factory; A21-P05.au-ios27, documented-api (51 of 51), core-purity and isolation exit 0; written by an agent, retested
  - `Experience/SkySound.swift` (new):
    - the protocol `SkyLoopPlaying` (`isEnabled`, `volume: Float`, `isPlaying`, `play() -> Bool`, `stop()`), to
      which `AmbientLoopPlayer` conforms by an extension;
    - the `@MainActor` policy `SkySound` with inputs `wanted`, `onScreen` and `active` ("The loop should play when
      `wanted && onScreen && active`"), `play()` when that becomes true and `stop()` when it becomes false;
    - a lazily made player (factory; nil: `AmbientLoopPlayer(recipe: .gentle)`), so the sound off touches no audio
      session; `volume` passed as a Float on every change;
  - `Experience/AuroraPresenter.swift`:
    - owns one `SkySound`; `setSound(on:)` and `setVolume(_:)` also drive it, and the restored preferences seed it;
    - `controlsAppeared()`, `controlsDisappeared()` and `sceneActive(_:)`;
    - `setup`, `resize`, `draw`, `teardown` and `shedCaches` never touch it;
    - the header comment updated ("Nothing plays" removed);
  - `Experience/AuroraControls.swift`:
    - `.onAppear`/`.onDisappear` on the controls' root view and `@Environment(\.scenePhase)` with `.onChange`
      calling the presenter;
    - the hints become "Plays a quiet sound made in code while Aurora is open" and "How loud the sky's sound is";
    - the header comment updated;
  - `Experience/AuroraExperience.swift`: the test factory takes an optional loop factory;
  - `///` on every new declaration; no GL call outside the scene protocol
  (FR-A21-501–504)
- [X] T-A21-504 [P] [US1] Tests (agent E), `ExperienceTests/SoundLoopTests.swift`, with a fake `SkyLoopPlaying` that — Verified 2026-11-17: 2026-11-17: SoundLoopTests (7: fresh start off and no player; plays only while on, on screen and active; volume 0.4 and 0; drawing lifecycle leaves play/stop counts unchanged; failed play keeps the choice and the sky; digest, snapshot and manifest equal; restored over the same storage, damaged prefs.v1 off), each under 10 s; .autonomy/checks/A21-P05.au-ios27.json exit 0 (65 tests in 15 suites); written by an agent, retested
  counts plays and stops (no audio):
  - a fresh start has the sound off, makes no player and plays nothing;
  - sound on, on screen and active plays; off, off screen or inactive stops; back on screen and active plays again;
  - the volume is 0.4 after `setVolume(0.4)`, and 0 plays silently;
  - setup, draw, teardown, a second setup, a preset change, the still view and reduced flashing leave the play and
    stop counts unchanged;
  - `play()` returning false leaves the sound choice on and the sky drawing;
  - the digest and the manifest are equal with the sound on and off;
  - the choice is restored over the same storage, and a damaged `prefs.v1` opens off;
  - each test runs under 10 s
  (FR-A21-501–504; SC-A21-501, 505)

## Phase 3: Story 2 — low-power cadence (P1)

- [X] T-A21-505 [P] [US2] Tests (agent E), `ExperienceTests/LowPowerCadenceTests.swift`: — Verified 2026-11-17: 2026-11-17: LowPowerCadenceTests (5: Low Power Mode cap 30; 60 x 1/30 and 120 x 1/60 end at the same clock time within 1e-6 with identical stills at the 60 shared instants; a mid-run switch ends at the same time with largest step 0.0333; clamped 0.5 s stall moves at most 0.1 x speed; Reduce Motion and the still view hold), each under 10 s; .autonomy/checks/A21-P05.au-ios27.json exit 0; written by an agent, retested
  - `FramePacing(thermal: .nominal, lowPower: true, requestedMaxFPS: 60).maxFPS == 30`;
  - the presenter drawn off screen for 60 frames of 1/30 s and 120 frames of 1/60 s ends at the same clock time
    (±1e-6), with the pixels identical at the shared instants (every 1/30 s);
  - a run that switches from 1/60 s to 1/30 s frames halfway (Low Power Mode turned on mid-motion) ends at the
    same clock time as either cadence alone, with no step above one frame's span;
  - a 0.5 s stall given as `FramePacing.clampedDelta(0.5)` moves the clock by at most 0.1 s × speed;
  - under Reduce Motion and the still view the clock holds at both cadences;
  - each test runs under 10 s
  (FR-A21-505; SC-A21-502, 505)

## Phase 4: Story 3 — Aurora in the app (P1)

- [X] T-A21-506 [P] [US3] Interface (agent U): `Apps/VisualCore/Tests/UI/Aurora/AUSupport.swift` (after `ZGSupport`: — Verified 2026-11-17: 2026-11-17: AUSupport (fresh and relaunch arguments, AU.reopen) and AUSkyUITests (Violet veil named on the canvas; Still sky and Reduced flashing on; hidden controls back with a tap); .autonomy/checks/A21-P05.app-ui.json exit 0 (chunk c3 on the iOS 27.2 phone: 4 tests in 115.4 s, the three sky tests about 75 s together); written by an agent, retested
  `-vcCandidates`, `-vcResetData`, skip welcome, `-openExperience a21.aurora`; identifiers
  `experience.a21.aurora.<name>`; a relaunch without the reset) and `AUSkyUITests.swift`:
  - pick "Violet veil", and the canvas label names it;
  - turn on "Still sky" and "Reduced flashing"; both read on;
  - hide the controls and tap the sky; the controls are back;
  - each test runs under 60 s
  (FR-A21-506; SC-A21-503)
- [X] T-A21-507 [P] [US3] Interface (agent U): `Apps/VisualCore/Tests/UI/Aurora/AUSoundUITests.swift`: — Verified 2026-11-17: 2026-11-17: AUSoundUITests (sound off on a fresh start; on with a new volume; both restored after a relaunch without the reset) 40.3 s; .autonomy/checks/A21-P05.app-ui.json exit 0; written by an agent, retested
  - a fresh start reads the sound off;
  - turn it on and set the volume, and the controls read the new choice;
  - a relaunch over the same storage restores it;
  - each test runs under 60 s
  (FR-A21-502, 506; SC-A21-503)
- [X] T-A21-508 [US3] Add the serial chunk `"c3": ["AUSkyUITests", "AUSoundUITests"]` to `scripts/release_check.py` — Verified 2026-11-17: 2026-11-17: serial chunk c3 (AUSkyUITests, AUSoundUITests) in scripts/release_check.py and SERIAL_CHUNKS; .autonomy/checks/A21-P05.script-tests.json exit 0; app-ui (c3) and verify-27 exit 0
  and to `SERIAL_CHUNKS` (lead); `scripts/test_scripts.py` passes

## Phase 5: Story 4 — the campaign plan (P2)

- [X] T-A21-509 [P] [US4] Write `docs/apps/aurora/device-campaign.md` (agent D, after — Verified 2026-11-17: 2026-11-17: docs/apps/aurora/device-campaign.md (AU-D1 to AU-D8, each with devices, procedure, pass condition and pending device campaign; no number claimed; D3 stays on iPadOS 26.5), licenses.md row for AmbientLoopRecipe.gentle (synthesised in code, no recording), README table row; .autonomy/checks/A21-P05.docs.json exit 0; written by an agent, reviewed
  `docs/apps/digital-zen-garden/device-campaign.md`):
  - rows AU-D1 to AU-D8 of clarification Q4, each with devices (D1, D2, D3), procedure, pass condition and "pending
    device campaign";
  - short runs extrapolated; no number claimed; D3 stays on iPadOS 26.5;
  - add the loop row (`AmbientLoopRecipe.gentle`, synthesised in code by VisualCoreAudioDSP, no recording) to
    `docs/apps/aurora/licenses.md`;
  - list the plan in `docs/apps/aurora/README.md`
  (FR-A21-507, 508; SC-A21-504)

## Phase 6: Records and evidence

- [X] T-A21-510 Contract: — Verified 2026-11-17: 2026-11-17: .autonomy/checks/A21-P05.contract.json exit 0 (G-SOUND and G-DEVICE closed by A21-P05, G-DEVICE as the plan; M09, M10, M14 and M21 available; M24 waits for G-RELEASE); A21-P05.experience-packages.json exit 0
  - G-SOUND and G-DEVICE are closed by "A21-P05" (G-DEVICE as the plan; its rows wait for devices);
  - rows whose gaps are all closed become available with evidence;
  - check: `--name contract`, `check_app_contract.py --app aurora --render`
- [ ] T-A21-511 Tests (review checkpoint):
  - Aurora on sim-27.2 (`--name au-ios27`), the documented API, isolation and core purity;
  - `xcodegen generate --spec project.yml`;
  - `--name app-ui -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27
    app-ui-ios27-c3`;
  - the runner (`--name verify-27`), the experience packages and the script tests
  (FR-A21-501–506; SC-A21-501–503, 505)
- [ ] T-A21-512 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  A21-P05; update README.md (rule 16) and `docs/automatedtesting.md` (rule 17)

## Dependencies

501 → 502 → {503/504/505, 506/507, 509} → 508 → 510 → 511 → 512.
- **Separate files:** 503–505 (experience), 506/507 (interface) and 509 (documents) touch different files.
- **Order:** 502 precedes 503 because SkySound imports VisualCoreAudio.

## Parallel examples

- **Agent E:** T-A21-503, 504 and 505.
- **Agent U:** T-A21-506 and 507.
- **Agent D:** T-A21-509.
- **Lead:** Package.swift (502), release_check.py (508), the contract, the runs and the commits.

## Implementation strategy

- **MVP:** the loop and its independence from the drawing (503, 504).
- **Then:** the cadence fixture (505) proves fixture 5; the interface journeys (506–508) prove the app; the plan (509)
  closes G-DEVICE.
- **Review checkpoint:** at 511. **Commit boundaries:** one commit per task.
