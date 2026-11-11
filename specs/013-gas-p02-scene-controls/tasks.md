---

description: "Task list for feature 013 — Generative Art Studio Phase 02 scene controls (ledger gate A01-P02)"
---

# Tasks: Generative Art Studio — Phase 02 Shader scenes and parameter controls

**Input**: `/specs/013-gas-p02-scene-controls/`. **Tests** are required: host, package simulator, app pixel tests and
UI tests on both runtimes, and the reference regression. IDs are `T-A01-2##`, with one commit and push per task
(`scripts/tick_task.py`). **Checkpoints:** after Phase 2, run the API baseline, R1–R5 and the reference regression;
after each phase, run `validate_docs.py`.

## Phase 1: Foundational — VisualCore building blocks (US4; blocks US1–US3)

- [X] T-A01-201 [P] [US4] Implement `Packages/VisualCore/Sources/VisualCoreSimulation/SceneClock.swift` per data-model.md: — Verified 2026-11-10: VisualCoreSimulation/SceneClock.swift (delta cap 0.25 s, speed 0…4, reduced motion 0.5×, wrap at duration, clamped scrub, non-finite ignored); run-check A01-P02/t201-202-host-a2: SceneClockTests 6/6 pass (advance/pause/toggle, delta cap and bad input, scrub clamp and wrap, speed clamp, reduced motion halves playback only, determinism); API baseline updated
  - `duration` 120 by default and > 0; time in 0 ≤ t < duration;
  - speed clamped to 0…4; `maxDelta` 0.25 s; reduced-motion factor 0.5;
  - wrap modulo duration; scrub clamps; non-finite input ignored.

  Add tests in `Packages/VisualCore/Tests/VisualCoreSimulationTests/SceneClockTests.swift`: advance, pause freezes,
  scrub, wrap, delta cap, speed clamp, reduced motion (halves playback; scrub and paused time
  unaffected, analyze C3), NaN ignored, determinism.
- [X] T-A01-202 [P] [US4] Implement `Packages/VisualCore/Sources/VisualCoreParameters/ParameterEditor.swift` per contracts/api.md: — Verified 2026-11-10: VisualCoreParameters/ParameterEditor.swift (set by value/normalized with clamping and NaN→0, reset/resetAll/no-op, isModified/modifiedNames, rebase, formatted 3 significant digits + unit); run-check A01-P02/t201-202-host-a2: ParameterEditorTests 4/4 pass, whole VisualCore host suite green; API baseline updated
  - `set(to:)` returns false for an unknown name or a non-finite value and clamps otherwise;
  - `set(normalized:)` clamps the position and treats non-finite as 0;
  - reset, resetAll, isModified, modifiedNames, rebase;
  - `formatted` gives 3 significant digits plus the unit.

  Add tests in `Packages/VisualCore/Tests/VisualCoreParametersTests/ParameterEditorTests.swift`, including that
  resetting an unchanged parameter is a no-op (analyze C2).
- [X] T-A01-203 [US4] Implement `Packages/VisualCoreRendering/Sources/VisualCoreUI/ParameterPanel.swift`: — Verified 2026-11-10: VisualCoreUI/ParameterPanel.swift (ParameterRow, ParameterPanelModel.rows/adjust ±5%, ParameterPanel Form section: title, value+unit, slider on normalized position, reset when modified, Reset all; VoiceOver label=title, value=formatted, adjustable; identifiers vc.param.*); VisualCoreUI → VisualCoreParameters in Package.swift and package map; R1-R5 PASS; run-check A01-P02/t203-ui-ios27 + ios26: ParameterPanelTests 3/3 (rows/order/format/modified, adjust stays in range incl. log, hosted render), package green; API baseline updated
  - a Form section with a title, value-with-unit text, a Slider on the normalized position and a reset per row,
    plus Reset all;
  - accessibility: label = title, value = formatted value, adjustable ±5%;
  - identifiers `vc.param.<name>`, `vc.param.<name>.reset` and `vc.param.resetAll`.

  Add the VisualCoreUI → VisualCoreParameters dependency in Package.swift and the package-map row. Add
  `Tests/VisualCoreUITests/ParameterPanelTests.swift` (hosted view: every parameter has a row, accessibility values
  are formatted, increment and decrement change the binding within range).
- [X] T-A01-204 [US4] Update the API baseline and READMEs (SceneClock, ParameterEditor, ParameterPanel). Run the — Verified 2026-11-10: READMEs document ParameterEditor, SceneClock and ParameterPanel; API baseline matches (all documented); run-check A01-P02/t204-visualcore-host swift test green; package tests on both runtimes green (A01-P02/t203-ui-ios27 + ios26); t204-reference-regression 7/7 pass (FR-A01-206)
  VisualCore host tests, the VisualCoreRendering package tests on iOS 27.2 and 26.5, and the reference regression
  (7 steps) (FR-A01-206).

## Phase 2: US1 + US2 — Controls on the live scene (P1) 🎯

- [X] T-A01-205 [US1] Implement `Apps/GenerativeArtStudio/Core/Sources/GenerativeArtStudioCore/CompositionEditor.swift` per data-model.md: — Verified 2026-11-10: GenerativeArtStudioCore/CompositionEditor.swift (preset → rebase baseline, palette, setSeed/shuffleSeed, setParameter normalized, updateEditor from panel binding, reset/resetAll, useDefault; composition always validated); run-check A01-P02/t205-core-tests 14/14: all 20 parameters in range for positions 0,1,−1,2,NaN,±∞ (SC-A01-201), reset targets preset baseline, palette-only change, seed shuffle, schema-mismatch editor ignored
  - `choosePreset` rebases the editor;
  - `choosePalette`, `setSeed`, `shuffleSeed(using:)`, `setParameter(normalized:)`, `resetParameter`/`resetAll`;
  - the composition always validated; `useDefault`.

  Add `Apps/GenerativeArtStudio/Core/Tests/GenerativeArtStudioCoreTests/CompositionEditorTests.swift`:
  - every one of the 20 parameters stays in range at 0, 1, −1, 2, NaN and ±∞ positions (SC-A01-201);
  - reset returns to the preset baseline;
  - the preset, palette and seed choices take effect.
- [X] T-A01-206 [US2] Add `Apps/GenerativeArtStudio/App/ClockedArtScene.swift` (wraps an ArtScene and advances a `SceneClock` each frame by `frame.delta`, then renders at `fixedTime = clock.time`) and `ArtSceneFactory.apply(_ composition:, to scene:)` (uniforms, palette and seed offsets; a particles cursor reset). Update `SceneScreen.swift`/`SceneModel` to own the editor and clock (Reduce Motion → `clock.reducedMotion`). Values — Verified 2026-11-10: App/ClockedArtScene.swift (advances SceneClock by frame.delta, renders inner at fixedTime = clock.time); ArtSceneFactory.apply (uniforms/palette/seed; particles update(document:) restarts replay); SceneModel owns CompositionEditor (didSet applies to the live scene), ClockedArtScene, togglePlay/scrub, observable time/isPlaying, Reduce Motion → clock.reducedMotion; values read at render time (rapid edits → latest at next frame). run-check A01-P02/t206-app-build-a2 BUILD SUCCEEDED; t206-app-unit-ios27: existing GenerativeArtStudioTests all pass with the new model
  are read from the editor at render time, so rapid changes apply only the latest value at the next frame (edge case;
  analyze U1).
- [X] T-A01-207 [US1] Add `Apps/GenerativeArtStudio/App/ControlsSheet.swift`: — Verified 2026-11-10: App/ControlsSheet.swift (Time: play/pause labelled Pause/Play, Time slider 0…120 s with spoken seconds value, time label; Preset and Palette lists with selected trait; Seed text + Shuffle; VisualCore ParameterPanel bound to CompositionEditor.editor) presented from toolbar gas.controls.open as a medium/large sheet with background interaction; run-check A01-P02/t207-app-build-a2 BUILD SUCCEEDED; documented API PASS. Behavior verified by T-A01-208
  - presented from `gas.controls.open`, sheet `gas.controls.sheet` with medium and large detents;
  - time row: `gas.time.playPause`, the `gas.time.scrub` slider over 0…120 s, and `gas.time.value`;
  - preset buttons `gas.preset.<id>` and palette buttons `gas.palette.<id>`;
  - seed: `gas.seed.value` and `gas.seed.shuffle`;
  - `ParameterPanel` bound to the editor;
  - changes applied immediately to the live scene.
- [ ] T-A01-208 [US1] Add `Apps/GenerativeArtStudio/Tests/Unit/ControlsRenderTests.swift`:
  - for each family, changing one parameter by ≥ 25% of its normalized range changes the image (mean ≥ 1/255), and
    reset all returns the preset image (≥ 99% within 2/255) (SC-A01-202);
  - a paused clock scrubbed to t renders identical images twice (max 0) (SC-A01-203);
  - a particles palette or seed change equals a fresh render of the new composition;
  - Reduce Motion → `clock.reducedMotion`.

  Add `Apps/GenerativeArtStudio/Tests/UI/ControlsUITests.swift`: open the sheet, move a slider and see the value
  text change, reset, play/pause toggles its accessibility label ("Pause"/"Play"), the scrub slider is labelled "Time" (analyze C1),
  scrub sets the time label, pick a preset and a palette, shuffle
  changes the seed text. Run on iOS 27.2 and 26.5.

## Phase 3: US3 — Recoverable corrupt or future compositions (P1)

- [ ] T-A01-209 [US3] Add `CompositionEditor.open(_:) -> OpenResult` and `RecoverableError` (`title`/`message`), with tests:
  - corrupt data, a future version (7) and an unknown family each fail and keep the previous composition;
  - correctable data opens with notes (SC-A01-204).

  Add `Apps/GenerativeArtStudio/App/LaunchComposition.swift` (`#if DEBUG` `-gasComposition` base64, ≤ 64 KiB, opens
  the family's scene) and a recovery banner in SceneScreen (`gas.recovery.message`, `gas.recovery.useDefault`). Add
  `Apps/GenerativeArtStudio/Tests/UI/RecoveryUITests.swift`: corrupt and future-version launches show the message;
  Use default shows the canvas without the banner; a correctable launch shows no error.

## Phase 4: Polish

- [ ] T-A01-210 Update `docs/apps/generative-art-studio/visualcore-contract.json`:
  - G-CLOCK closed (A01-P02);
  - M02 available, with SceneClock evidence;
  - M10 evidence updated, with G-UI still open for the accessibility settings model;
  - new evidence for ParameterEditor and ParameterPanel.

  Render it. Run `check_app_contract`, the documented API for the app, and release-check fast steps (docs,
  app-contracts, compliance, dependencies, public API, licenses, script tests, host-visualcore) (FR-A01-209,
  SC-A01-205).

## Dependencies

T-A01-201, T-A01-202 (parallel) → T-A01-203 → T-A01-204 → T-A01-205 → T-A01-206 → T-A01-207 → T-A01-208 → T-A01-209 →
T-A01-210.

## Implementation strategy

VisualCore pieces first (the reuse rule), then the domain editor, then the live UI, then recovery. Each step is green
before the next.
