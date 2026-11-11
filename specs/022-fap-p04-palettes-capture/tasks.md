---

description: "Task list for feature 022 — Fluid Art Playground Phase 04 interaction and capture UX (ledger gate A02-P04)"
---

# Tasks: Fluid Art Playground — Phase 04 Interaction and capture UX

**Input**: `/specs/022-fap-p04-palettes-capture/` (spec with 5 clarifications, plan, research R1–R5, data model,
contract, quickstart).

**Tests** are required: host Core tests; the VisualCoreRendering package tests and app unit and UI tests on iOS 27.2
and 26.5 with the guard (`xcodegen generate` after adding files); the ProjectM regression; an A01 build. IDs are
`T-A02-4##`, with one commit per task (`scripts/tick_task.py`). Commands run through `run-check --stage A02-P04`.
Checkpoints: `validate_docs`, `check_dependencies`, `check_compliance` and `check_app_isolation` (allowing
`NSPhotoLibraryAddUsageDescription` only).

## Phase 1: Foundational — VisualCore pass run observer (blocks US4)

- [X] T-A02-401 Add `FieldPass.Run` and `@MainActor static var runObserver` in — Verified 2026-11-11: FieldPass.Run (label, output texture or framebuffer, outputIsFramebuffer, input textures) and the @MainActor static runObserver (nil by default; called after validation, just before the draw) with /// docs and a README note; FieldPassTests +1 (a pair run reports the write texture with the read as input, a rejected inputIsOutput run is not reported, framebuffer output flagged). run-check A02-P04/t401-rendering-27 and t401-rendering-26 TEST SUCCEEDED, enumeration guard 134/134 each; API baseline updated (additions) then PASS; ProjectM regression t401-reference-a 3/3 + t401-reference-b 4/4 (FR-A02-407)
  `Packages/VisualCoreRendering/Sources/VisualCoreRendering/FieldPass.swift` (called after validation, before the
  draw; for a target output, `output` is its color texture name). Extend `FieldPassTests` (one run is reported with
  the right input and output names; a rejected run reports nothing). Add docs, README, baseline. Run the package
  tests on 27.2 and 26.5, then the ProjectM regression 3/3 + 4/4 (FR-A02-407).

## Phase 2: User Story 1 — palettes (P1) 🎯

- [X] T-A02-402 [P] [US1] Tests first, then add `FluidPalette.swift` (Core), following clarification 1: — Verified 2026-11-11: FluidPalette (Core): Ink (paper 0.96/0.94/0.88, exp(-2*dye), absorptive ink colors), Smoke (bg 0.04/0.04/0.05, toward 0.92 by 1-exp(-1.5*luma), gray splats), Glowing dye (black + clamped dye, glow flag); six splat colors each; displayColor as the CPU reference; FluidConfiguration.paletteID (default glow, unknown -> glow, reported); SplatQueue colors from the palette with update(configuration:) keeping pending splats; FluidCanvasDescription names the palette. Tests: FluidPaletteTests 4, FluidConfigurationTests (+1 case), SplatQueueTests +1, FluidCanvasDescriptionTests updated. run-check A02-P04/t402-core-test swift test 49/49 pass (FR-A02-401)
  - "ink paper (0.96, 0.94, 0.88), exp(−2·dye)";
  - "smoke bg (0.04, 0.04, 0.05), 1 − exp(−1.5·luma)";
  - "glow black + clamped dye";
  - exactly 6 splat colors each;
  - `displayColor(dye:)` as the CPU reference.

  Add `paletteID` to `FluidConfiguration` ("unknown → glow, reported"). `SplatQueue` colors come from the palette.
  `FluidCanvasDescription` names the palette. Tests: `FluidPaletteTests` and extensions of `FluidConfigurationTests`
  and `SplatQueueTests`.
- [X] T-A02-403 [US1] Add the display shader modes (`uMode`, `uBackground`) and the palette uniforms to — Verified 2026-11-11: Display fragment with uMode/uBackground (ink exp(-2*dye) on paper, smoke toward 0.92 by luma, glow clamped dye on black) fed from the active palette; PlaygroundModel hosts EffectScene(content: FluidFieldsScene, graph: VisualCore bloom threshold 0.6 / intensity 1.2 / radius 8), bypassed unless Glowing dye, reduceFlashing from SystemAccessibilityObserver (synced each frame); queue follows configuration changes; Adjust 'Look' section with a segmented palette picker (fap.adjust.palette); project.yml adds VisualCoreEffects and VisualCoreEffectsGraph. PaletteRenderTests 3: every pixel matches FluidPalette.displayColor within 0.5/255 for ink/smoke/glow, pairwise mean differences 52.7%/64.0%/12.3% (>= 10%), bloom adds light, Reduce Flashing puts the flash limiter in the effective graph, Ink bypasses the glow, switching palettes keeps the fields with no rebuild (SC-A02-401; analyze C3, C4). run-check A02-P04/t403-app-27 and t403-app-26 TEST SUCCEEDED, enumeration guard 38/38 each; isolation and documented-API PASS
  `FluidFieldsScene`. Wrap the host scene in `EffectScene(content:graph:)` with a bloom graph ("threshold 0.6,
  intensity 1.2, radius 8"), bypassed unless the palette is glow, with `reduceFlashing` from
  `SystemAccessibilityObserver`. Add a palette picker (`fap.adjust.palette`) to the Adjust panel. Add
  `PaletteRenderTests`:
  - the same field rendered in each palette;
  - pairwise mean difference ≥ 10%;
  - probes match `displayColor` within 3/255 for ink and smoke;
  - glow spreads beyond the dye with bloom;
  - switching keeps the fields (SC-A02-401);
  - with Reduce Flashing, the glow's effective graph contains the flash limiter (FR-A02-403; analyze C4).

  Add the VisualCoreEffects product to the app target in `project.yml` (analyze C3).

## Phase 3: User Story 2 — pinch and Brush size (P1)

- [X] T-A02-404 [US2] In `PlaygroundView.swift`, feed `PointerTracker` and `PinchRecognizer`. When a second finger — Verified 2026-11-11: PlaygroundModel feeds VisualCore PointerTracker then PinchRecognizer; the second finger cancels every stroke in progress (tracker cancel + queue forget) and enters pinch mode until all fingers lift; brushRadius = start x pinch.scale clamped 0.005...0.25. Adjust 'Brush' section with the Brush size slider (fap.adjust.brush, spoken 'N% of the canvas'). PinchTests 3: distance 200 -> 400 doubles the radius (0.04 -> 0.08 within 1%) with 0 new splats, painting resumes after lift; scale clamped to 0.25 and 0.005; a stroke ends when the second finger lands with no further splats (SC-A02-402; analyze C1). run-check A02-P04/t404-app-27 and t404-app-26 TEST SUCCEEDED, enumeration guard 41/41 each, audit clean (FR-A02-404)
  goes down, cancel both strokes and enter pinch mode, with "brushRadius = start × scale, clamped 0.005…0.25". Add
  the Brush size slider (`fap.adjust.brush`, spoken as a percentage of the canvas). Add `PinchTests` with scripted
  events: spreading to twice the distance doubles the radius, clamping works, and 0 splats come from pinching
  fingers (SC-A02-402). Also cover a one-finger stroke followed by a second finger: the stroke ends and no further
  splats come from it (analyze C1).

## Phase 4: User Story 3 — capture (P2)

- [ ] T-A02-405 [US3] Add `CaptureModel.swift`:
  - `ExportGeometry(maxEdge: host.maxRenderSize)` at 2048 on the long edge in the view aspect;
  - pause, `renderOffscreen`, restore;
  - `StillImageEncoder.pngData`;
  - a temporary file, replacing the previous one and deleted on close;
  - a message on failure.

  Add the capture button and `ShareLink` (`fap.capture`, `fap.capture.share`, `fap.capture.message`). Add
  `NSPhotoLibraryAddUsageDescription` (clarification 5) to `project.yml`. Add `CaptureTests`:
  - an opaque PNG of the expected size;
  - the step count unchanged;
  - palette probes match the on-screen frame;
  - a too-large size refused with a message, with `scene.paused` restored to its previous value (SC-A02-403;
    analyze C2).

## Phase 5: User Story 4 — pass isolation (P1)

- [ ] T-A02-406 [US4] Add `PassIsolationTests` using `FieldPass.runObserver`: 10 frames in every palette and both
  storages, with splats, viscosity and projection on. Assert 0 runs where an input equals the output, and the run
  count per frame equals the expected list (SC-A02-404).

## Phase 6: UI, contract and checks

- [ ] T-A02-407 Add `PaletteCaptureUITests` (pick each palette, change Brush size, capture → share sheet) and extend
  the audit to the new controls. Run the app tests on 27.2 and 26.5 (SC-A02-405).
- [ ] T-A02-408 Update the contract (reused pieces in M02/M06/M09 notes; the observer recorded), then run the release
  fast steps, the isolation check with the allowed usage key, and an A01 build. Add lessons (FR-A02-408, SC-A02-406).

## Analyze remediation (2026-11-11)

Applied under the owner's delegated approval (CLAUDE.md §2):
- C1: a pinch-during-stroke test was added to T-A02-404.
- C2: the pause restore on capture failure was added to T-A02-405.
- C3: the VisualCoreEffects dependency was added to T-A02-403.
- C4: the flash limiter test was added to T-A02-403.

No CRITICAL findings; coverage is 100%.

## Dependencies

- T-A02-401 is first (VisualCore).
- T-A02-402 can run in parallel with it.
- T-A02-403 needs T-A02-402.
- T-A02-404 and T-A02-405 need T-A02-403 (the playground view).
- T-A02-406 needs T-A02-401 and T-A02-403.
- T-A02-407 and T-A02-408 come last.
