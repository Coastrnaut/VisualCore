---

description: "Task list for feature 023 — Fluid Art Playground Phase 05 numerical fixtures and device stress tests (ledger gate A02-P05)"
---

# Tasks: Fluid Art Playground — Phase 05 Numerical fixtures and device stress tests

**Input**: `/specs/023-fap-p05-fixtures-stress/` (spec with 5 clarifications and the checklist amendments, plan,
research R1–R7, data model, contract, quickstart).

**Tests** are required:
- host tests for VisualCore and Core;
- the VisualCoreRendering package tests and app unit and UI tests on iOS 27.2 and 26.5, with the enumeration guard
  (run `xcodegen generate` after adding files);
- a simulator automation rehearsal;
- the Release symbol check;
- the ProjectM regression;
- an A01 build.

**Conventions**: IDs are `T-A02-5##`, with one commit per task (`scripts/tick_task.py`). Commands run through
`run-check --stage A02-P05`. Checkpoints: `validate_docs`, `check_dependencies`, `check_compliance`,
`check_public_api` and `check_app_isolation` (allowing `NSPhotoLibraryAddUsageDescription` only).

## Phase 1: Foundational — VisualCore additions (blocks US2, US4, US5)

- [X] T-A02-501 Write `SyntheticGestureScriptTests` first, then add — Verified 2026-11-11: — Verified 2026-11-11: SyntheticGestureScript (VisualCoreScenes, documented, baseline +9 lines) with Scenes→Simulation edge; SyntheticGestureScriptTests 11/11 (identical/different seeds, 100 seeds×600 frames in bounds, began→moved×n→ended, strictly increasing timestamps, staggered starts, clamps, fallbacks, seed 0=1, negative frame, speed) in run-check A02-P05/t501-host-visualcore swift test exit 0; t501-checks public-api, dependencies, docs, compliance 4/4 PASS
  `Packages/VisualCore/Sources/VisualCoreScenes/SyntheticGestureScript.swift`.
  - **Rules** (data model): `seed` "0 → 1"; `pointerCount` "clamped 1…10"; `strokeSamples` "clamped 1…240";
    `speed` "finite, clamped 0…20,000"; `viewSize` "finite, > 0, else 1×1"; `frameInterval` default 1/60.
  - **Behavior**: `events(forFrame:)` is pure. Each stroke is began, `strokeSamples` × moved, then ended. Pointer i
    starts at frame i. Locations are clamped in the view. Timestamps strictly increase per pointer. A negative frame
    gives no events.
  - **Package**: add the VisualCoreScenes → VisualCoreSimulation edge in `Packages/VisualCore/Package.swift`.
  - **Docs**: /// docs, the README module note and the public-API baseline (`check_public_api.py --update`).
  - **Tests** (≥ 9, the contract list): run `swift test --package-path Packages/VisualCore`, then
    `check_dependencies.py` (FR-A02-505, SC-A02-503).
- [X] T-A02-502 Add to VisualCoreAutomation: — Verified 2026-11-11: — Verified 2026-11-11: AutomationRunner.seedKey/requestedSeed (missing/0/invalid -> 1), postRunCheck + checkNote (after smoke/launch/lifecycle, fail sets result and message, not called for unknown modes), AutomationView postRunCheck/checkNote parameters with defaults; AutomationRunnerTests +4; run-check A02-P05/t502-rendering-27 and -26 TEST SUCCEEDED, enumeration 138/138 each; baseline updated, t502-checks 4/4; ProjectM regression t502-reference-a 3/3 + t502-reference-b 4/4; A01 build-for-testing (t502-a01-build) and Showcase build (t502-showcase-build) succeed
  - `AutomationRunner.seedKey` ("VISUALCORE_AUTORUN_SEED") and `requestedSeed(environment:)` (missing, 0 or invalid
    give 1);
  - `public var postRunCheck: (@MainActor () -> String?)?`, called after smoke, launch and lifecycle and before the
    report is written. A non-nil result sets result "fail" and the message. It is not called for unknown modes or
    renderer-unavailable.
  - `AutomationView.init(…, postRunCheck: (@MainActor (RenderScene) -> String?)? = nil, …)`, forwarded to the runner.

  Extend the automation tests: seed parsing, check pass, check fail, unknown mode not checked. Add docs and the
  baseline. Run the package tests on 27.2 and 26.5 with the guard. Run the ProjectM regression 3/3 + 4/4, and build
  A01 and Showcase (FR-A02-508).

## Phase 2: User Story 1 — Pause, Step, Resume, Reset (P1) 🎯 MVP

- [X] T-A02-503 [P] [US1] Write tests first, then add — Verified 2026-11-11: — Verified 2026-11-11: SimulationControl (paused, stepEnabled, Pause/Resume label, step hint, 4 announcements) and FluidDetail (64/128/256 square, names, 'Medium, 128 by 128 cells', nearest level by shorter edge, apply keeps tuning) in FluidArtPlaygroundCore; SimulationControlTests 3 + FluidDetailTests 3; run-check A02-P05/t503-core-test swift test 55/55 pass; t503-docapi PASS
  `Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/SimulationControl.swift`: `paused`,
  `stepEnabled`, `pauseLabel` ("Pause"/"Resume"), `stepHint` and the four announcements (data model). Also add
  `FluidDetail.swift`: low, medium and high with edges 64, 128 and 256; `name`; `init(grid:)` gives the nearest
  level; `apply(to:)`. Write `SimulationControlTests` and `FluidDetailTests`, then run the host Core tests
  (FR-A02-501, FR-A02-511).
- [X] T-A02-504 [US1] Scene in `Apps/FluidArtPlayground/App/FluidFieldsScene.swift`: — Verified 2026-11-11: — Verified 2026-11-11: FluidFieldsScene.requestStep (one-shot, one step while paused, cleared while running), resetFields (seed dye in the active palette's colors via DyeSeed.pattern(colors:), encoded zero velocity, fill pressure/divergence, stepCount 0, pending splats cleared, pause kept); ControlTests 4 (step x3 +3, touches while paused applied on Step, reset velocity exactly 0 and dye = seed within one storage step in half-float and RGBA8, capture after steps keeps stepCount); run-check A02-P05/t504-app-ios27-2 and t504-app-ios26 TEST SUCCEEDED, enumeration 52/52 each; t504-core-test 55/55
  - `requestStep()`: a one-shot flag; while paused, one full step runs in `render` (drain, splats, advect, solve,
    advect dye); while running, the flag is cleared.
  - `resetFields()`: on the next render, upload the seed dye (current palette's colors) and zero velocity (encoded),
    fill pressure and divergence with zero, and set `stepCount = 0`.

  Add `ControlTests` in `Apps/FluidArtPlayground/Tests/Unit/ControlTests.swift`:
  - Step ×3 while paused gives +3;
  - Step while running gives +0;
  - touches queued while paused are applied by the next Step;
  - after Reset the velocity readback is exactly zero (decoded) and the dye equals the seed within one storage
    step, in both storages;
  - a capture while paused after steps leaves the step count unchanged (analyze G2).

  Run on 27.2 and 26.5 with the guard (FR-A02-501–503, SC-A02-501).
- [X] T-A02-505 [US1] Model and UI in `Apps/FluidArtPlayground/App/PlaygroundView.swift`: — Verified 2026-11-11: — Verified 2026-11-11: PlaygroundModel.togglePause/step/resetCanvas (SimulationControl; reset ends active strokes, drops queued touches, keeps pause/tuning; VoiceOver announcements), bottom-bar fap.pause/fap.step (disabled while running, hint)/fap.reset, canvas description follows the observed pause; ControlTests.testResetDuringSwipeEndsTheStroke, ControlsUITests.testPauseStepResetResume, audit gains the paused playground (default + XXXL, no new issues); run-check A02-P05/t505-app-ios27 and t505-app-ios26 TEST SUCCEEDED, enumeration 54/54 each
  - `togglePause()`, `step()`, `resetCanvas()`; reset ends active strokes, empties the queue, keeps pause and tuning,
    and renders one frame so a paused canvas shows the seed;
  - toolbar controls `fap.pause`, `fap.step` (disabled while running, with the hint) and `fap.reset` ("Reset canvas");
  - VoiceOver announcements.

  Add a model unit test: Reset during an active swipe drops that stroke's later samples, and painting resumes on the
  next touch (analyze G3). Add `ControlsUITests` (`Apps/FluidArtPlayground/Tests/UI/ControlsUITests.swift`), and add the controls to the
  accessibility audit at default size and XXXL. Run on 27.2 and 26.5 (FR-A02-501, SC-A02-501).

## Phase 3: User Story 2 — Deterministic seeded test mode (P1)

- [X] T-A02-506 [US2] Add `Apps/FluidArtPlayground/App/TestMode.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`). — Verified 2026-11-11: — Verified 2026-11-11: TestMode (DEBUG||VISUALCORE_AUTOMATION; fixed 1/60 s, tier pinned via deviceState/clock, max force and splat cap, SyntheticGestureScript 4 pointers/30 samples/1,200 pt/s fed through PlaygroundModel.paint once per stepped frame via beforeDrain; SHA-256 digest of readPixels); DeterminismTests 3: seed 7 x2 byte-identical (digest bf16079c…, 1,122 splats), seeds 7/8 differ in 73.5% of pixels, several pointers paint without pinching; run-check A02-P05/t506-app-ios27 and t506-app-ios26 TEST SUCCEEDED (same digest on both runtimes), enumeration 57/57 each
  `TestMode.configure(model:seed:)` sets:
  - `fixedDelta = 1/60`;
  - the quality tier pinned to Full (the `deviceState` and `clock` seams);
  - force scale and splat cap at the configuration maximums;
  - a `SyntheticGestureScript` (4 pointers, 30 samples, 1,200 points/s, the view size), whose events go through
    `model.handle(_:)` once per stepped frame.

  Add `DeterminismTests`: two fresh models with seed 7 and 120 frames give equal SHA-256 digests of `readPixels()`;
  seeds 7 and 8 differ in ≥ 1% of pixels (any channel). Run on 27.2 and 26.5 (FR-A02-504, SC-A02-502).

## Phase 4: User Story 3 — Fixture suite 1–5 (P2)

- [X] T-A02-507 [US3] Add `FixtureSuiteTests` (`Apps/FluidArtPlayground/Tests/Unit/FixtureSuiteTests.swift`), naming — Verified 2026-11-11: — Verified 2026-11-11: FixtureSuiteTests fixtures 1-5: (1) uniform dye decay max |GPU-ref| 0.0 in float16 and unorm8; (2) zero velocity: 0 cells grown, total 617.07->476.37 within bound 484.53 (unorm8 493.05 <= 501.30); (3) walls/open x both storages, wall normal flow 0, CPU reference 0 out-of-grid reads; (4) test-mode playground 682 runs over 10 frames, 0 self-sampling; (5) 100 suspended frames 0 steps, first frame after resume +1, deltas 600/0/-1/NaN/inf one step each in 1/240..1/30 s, paused scene stays paused with +0 through suspend/resume; run-check A02-P05/t507-app-ios27 and t507-app-ios26 TEST SUCCEEDED, enumeration 62/62 each
  fixtures 1–5:
  1. uniform dye decays by dissipation (reuses the DissipationFixture reference);
  2. zero velocity keeps a known pattern bounded (max does not grow; the sum stays within the dissipation bound);
  3. boundary modes with no out-of-grid reads (reuses the boundary fixture's checks);
  4. no pass samples its output (the runObserver over 10 frames);
  5. bounded catch-up:
     - (a) while the host is paused, `renderOneFrame` returns false and the step count does not change;
     - (b) the first frame after `resume()` gives +1 step;
     - (c) deltas of 600, 0, −1 and NaN each give exactly one step, with `lastStep` in 1/240…1/30;
     - (d) a paused scene, suspended and resumed, stays paused with +0 steps (analyze G1).

  Run on 27.2 and 26.5 (FR-A02-506, SC-A02-504).

## Phase 5: User Story 4 — Stability under stress (P2)

- [X] T-A02-508 [US4] Add `fieldCheck()` to `FluidFieldsScene`. It reads velocity, pressure and dye back — Verified 2026-11-11: — Verified 2026-11-11: FluidFieldsScene.fieldCheck() (finite; dye 0..4; |v|*dt <= longer edge; |p| <= 1e4; RGBA8 not all at extremes). The first stress run FAILED in half-float (|v| 34,688 cells/s, dye 89.5, |p| 4.9e4; run-check t508-app-ios27 exit 65); fixed at the cause: splats clamp velocity per component to +-velocityRange*60 and dye to 0..2 in the shader and the CPU reference (Splat.apply velocityLimit, Splat.dyeCeiling; SplatTests +1; spec implementation clarification). StressTests 3: 600 frames on 256^2 with 10 pointers, max force, 80 iterations: half-float max |v| 382, dye 1.97, |p| 2,168; RGBA8 |v| 341, |p| 956; 0 failed checks, <= cap per frame; touch flood exactly the cap. run-check A02-P05/t508-core-test-3 56/56, t508-app-ios27-2 and t508-app-ios26 TEST SUCCEEDED, enumeration 65/65 each
  (`readFloatPixels`, velocity decoded in 8-bit) and checks:
  - all values finite;
  - dye in 0…4;
  - |v|·Δt ≤ the longer grid edge;
  - |p| ≤ 10⁴;
  - in 8-bit, not all values at the extremes.

  It returns `firstBad`. Add `StressTests`: 600 test-mode frames with 10 pointers at maximum force and 80 iterations,
  per storage (half-float and forced 8-bit), with `fieldCheck()` every 60 frames. A touch flood (10 pointers × 30 samples in one frame) stays ≤ the cap per
  frame (`lastDrained`), and the queue stays bounded. Run on 27.2 and 26.5 (FR-A02-507, SC-A02-505).

## Phase 6: Simulation detail (MVP-06, FR-A02-511)

- [X] T-A02-509 [US1] Add `rebuildFields(configuration:)` to the scene. On the next render it runs `releaseAll` and — Verified 2026-11-11: — Verified 2026-11-11: FluidFieldsScene.rebuildFields (next frame: releaseAll + setup with the new grid and device cap; falls back to the previous grid on failure, rebuildFellBack), PlaygroundModel.detail/setDetail (ends strokes, drops queued touches, keeps pause and tuning, queue rebuilt for the validated grid; syncGrid + message after a fallback), Adjust picker fap.adjust.detail with value 'Medium, 128 by 128 cells'; DetailTests 5 (64/128/256 grids, 10 switches 0 leaks and live count back to Medium, maxEdge 100 caps High, failed upload falls back with message, change during a swipe), AdjustUITests picker (tier row now scrolled into the lazy Form on iOS 26.5); run-check A02-P05/t509-app-ios27-2 and t509-app-ios26-2 TEST SUCCEEDED, enumeration 70/70 each
  `setup` with the new grid, falling back to the previous grid on failure with `lastError`. The model applies the
  detail: it ends strokes, empties and rebuilds the queue for the validated grid, and keeps pause. The Adjust → Solver
  picker `fap.adjust.detail` ("Simulation detail", value "Medium, 128 by 128 cells") follows. Add `DetailTests`: each
  level's grid; 10 switches with 0 leaked resources; an oversized request capped; a failed allocation falls back.
  Extend the Adjust UI test with the picker. Run on 27.2 and 26.5 (FR-A02-511, SC-A02-507).

## Phase 7: User Story 5 — Device stress automation, rehearsed on simulators (P3)

- [ ] T-A02-510 [US5] Add `Apps/FluidArtPlayground/App/AppAutomation.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`).
  `root(mode:)` builds a `PlaygroundModel` in the test mode with `AutomationRunner.requestedSeed()`. It passes the
  model's effect scene to `AutomationView`, with a post-run check that returns `fieldCheck`'s failure, or nil with the
  message `digest=… maxVelocity=… maxDye=…`.
  - Route `FluidArtPlaygroundApp.swift` to it when `VISUALCORE_AUTORUN` is set.
  - In `project.yml`, the FAP target depends on VisualCoreAutomation (empty unless DEBUG or VISUALCORE_AUTOMATION).
  - Add `AutomationTests`: a fake terminate gives result "pass" with a digest; an injected bad check gives "fail".

  Run on 27.2 and 26.5 (FR-A02-508).
- [ ] T-A02-511 [US5] Simulator rehearsal (not device evidence):
  1. Install the Debug app on the 27.2 simulator.
  2. For smoke, launch and lifecycle, run `simctl launch` with `SIMCTL_CHILD_VISUALCORE_AUTORUN=<mode>` and
     `SIMCTL_CHILD_VISUALCORE_AUTORUN_SEED=7`.
  3. Copy each report from the data container and check result "pass".

  Then build Release for generic iOS (unsigned) and run `check_release_symbols.py --app` (0 symbols) and
  `--expect-present` on a Release + VISUALCORE_AUTOMATION measurement build. Run isolation with the built app
  (FR-A02-508, FR-A02-509, SC-A02-506).

## Phase 8: Polish and cross-cutting

- [ ] T-A02-512 Documentation:
  - the contract (`docs/apps/fluid-art-playground/visualcore-contract.{json,md}`): reused pieces, the two VisualCore
    additions, and gate A02-P05;
  - a new `docs/apps/fluid-art-playground/device-campaign.md`: modes, keys, report fields, the D1/D2/D3 rows marked
    "automation ready, device run pending implementation lock";
  - the regression baseline;
  - the simulator lessons.

  Run the fast checks (`release_check.py --only docs app-contracts compliance dependencies public-api licenses
  script-tests host-visualcore documented-api-fluid-art-playground isolation-fluid-art-playground
  host-fluid-art-playground-core`), the ProjectM regression and the A01 build (FR-A02-510, SC-A02-506).

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- D1: dropped the speculative edge T-A02-501 → T-A02-507.
- U1: added US1 scenario 6 to the spec.
- G1–G3: added tests to T-A02-507, T-A02-504 and T-A02-505.
- A1: quantified the touch flood in T-A02-508.

## Dependencies

- T-A02-501 blocks T-A02-506, T-A02-508 and T-A02-510.
- T-A02-502 blocks T-A02-510.
- T-A02-503 blocks T-A02-504, T-A02-505 and T-A02-509.
- T-A02-504 blocks T-A02-505.
- T-A02-506 blocks T-A02-508 and T-A02-510.
- T-A02-508 blocks T-A02-510.
- T-A02-510 blocks T-A02-511.
- T-A02-512 runs last.

Story order: US1 (MVP) → US2 → US3 → US4 → detail → US5 → polish.

## Parallel opportunities

- T-A02-501 and T-A02-502 touch different packages, and T-A02-503 is Core-only. All three can run in parallel; they
  are committed separately.
- T-A02-507 depends only on T-A02-504's step semantics, so it can follow T-A02-504 independently of US2.

## Implementation strategy

1. MVP first: VisualCore additions, then US1 (pause, step and reset), verified on both runtimes.
2. Then the test mode, the fixtures, stress and detail.
3. Then automation and the rehearsal.
4. Review checkpoints after T-A02-502 (VisualCore API and the regression), T-A02-505 (UI and audit), T-A02-511
   (Release symbols) and T-A02-512 (all checks).
