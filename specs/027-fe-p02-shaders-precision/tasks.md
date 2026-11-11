---

description: "Task list for feature 027 — Fractal Explorer Phase 02 fractal shaders and precision probe (ledger gate A03-P02)"
---

# Tasks: Fractal Explorer — Phase 02 Fractal shaders and precision probe

**Input**: `/specs/027-fe-p02-shaders-precision/`. That folder holds the spec (5 clarifications plus the checklist
amendments), the plan, research R1–R4, the data model, the contract and the quickstart.

**Tests are required**:
- host tests for VisualCore;
- VisualCoreRendering package tests on both runtimes;
- app unit and UI tests on iOS 27.2 and 26.5, run under the enumeration guard;
- the ProjectM regression;
- the A01 and A02 builds.

**Conventions**: IDs are `T-A03-2##`, with one commit per task through `scripts/tick_task.py`. Commands run through
`run-check --stage A03-P02`.

## Phase 1: Foundational — VisualCore G-PRECISION (blocks US4)

- [ ] T-A03-201 Write `PrecisionAdvisorTests` first, with at least 7 cases from the contract. Then add
  `Packages/VisualCore/Sources/VisualCoreMath/PrecisionAdvisor.swift`:
  - `assess(mantissaBits:magnitude:pixelStep:)` and `minimumPixelStep(mantissaBits:magnitude:)`;
  - `nearLimitMargin` = 16;
  - non-finite or non-positive input gives `beyondLimit` with a margin of 0.

  Add docs, the README note and the baseline entry. Run `swift test` (FR-A03-205).
- [ ] T-A03-202 Add `ShaderPrecision` and the optional `fragmentHighp` and `fragmentMediump` properties to
  `RenderCapabilities` (VisualCoreRendering). Fill them in `query` with `vcglGetShaderPrecisionFormat`.
  - Add `RenderCapabilitiesPrecisionTests`:
    - on both simulator runtimes the values are present and `highp` bits ≥ `mediump` bits (analyze C1); the simulator values are logged as context;
    - JSON without the new keys still decodes.
  - Run the package tests on 27.2 and 26.5 with the guard.
  - Run the ProjectM regression (3/3 + 4/4) and build A01 and A02 (FR-A03-204).

## Phase 2: User Stories 1 and 3 — GPU render (P1) 🎯

- [ ] T-A03-203 [US1] [US3] Add `Apps/FractalExplorer/App/FractalShaders.swift`, the fragment source per research R3.
  Add `FractalScene.swift`, which wraps `FullScreenShaderScene`:
  - a clock, the uniforms, the palette and the error pass-through;
  - parameters `centerX`, `centerY`, `step`, `mode`, `seedX`, `seedY`, `cap`, `radius` and `rate`.

  `project.yml`: the app links VisualCoreRendering, VisualCoreScenes, VisualCoreSimulation and VisualCoreParameters.

  Add `GPUAgreementTests`. Render 64 × 64 offscreen views of the default Mandelbrot and Julia scenes. Expect class
  agreement of at least 99%, with boundary-only disagreements, the origin interior and c = 2 exterior. Run on 27.2
  and 26.5 (FR-A03-201, FR-A03-207, SC-A03-202).
- [ ] T-A03-204 [US1] Update `ExplorerModel` and `ExplorerView`:
  - one `RenderHost(scene: FractalScene)` shown through `RenderSurface` with the label `fe.canvas`, and `close()` on
    disappear;
  - the CPU preview stays as the fallback when the shader reports an error;
  - the size follows the view, and the pixel scale goes to the scene.

  Update the existing model and UI tests. Add two tests (analyze G1):
  - a forced shader failure (an invalid fragment) shows the CPU preview fallback;
  - `recreateContext` keeps the view state.

  Run on both runtimes (FR-A03-201).

## Phase 3: User Story 1 — gestures (P1)

- [ ] T-A03-205 [US1] Add the gesture mapping in the model:
  - `PointerTracker` → `PinchRecognizer` (incremental scale about the center, then the center movement as a pan) and
    `DragRecognizer` (incremental translation);
  - a finger lift mid-pinch restarts the drag without a jump;
  - `fe.zoomIn`, `fe.zoomOut` and `fe.resetView` controls.

  Add `GestureTests`:
  - a scripted pinch keeps the plane point under the midpoint within 1e-9 relative, and within 1 pixel on screen
    through `screen(fromPlane:)`;
  - a drag moves by exactly the delta;
  - a lift mid-pinch causes no jump;
  - the controls work.

  Run on both runtimes (FR-A03-202, SC-A03-201).

## Phase 4: User Story 2 — palettes (P1)

- [ ] T-A03-206 [US2] Add the palette picker `fe.palette` (Sunset by default, then Ocean, Forest, Neon and Ember) and
  the `fe.animate` toggle. Reduce Motion turns animation off by default (VisualCoreUI `SystemAccessibilityObserver`).
  The clock pauses while animation is off.

  Add `PaletteTests`:
  - each palette's stops reach the scene;
  - with animation off, two frames 1 s apart are identical; with animation on, they differ;
  - Reduce Motion defaults animation to off.

  Run on both runtimes (FR-A03-203, SC-A03-204).

## Phase 5: User Story 4 — precision limit (P2)

- [ ] T-A03-207 [US4] In the model:
  - read `host.capabilities.fragmentHighp` (falling back to `mediump`, then 10 bits);
  - clamp the viewport's units per point so the per-pixel step stays ≥ the advisor's minimum;
  - show the `fe.precision` banner with the FR-A03-206 wording;
  - announce only when the state changes;
  - append the state to the spoken description.

  Add `PrecisionClampTests`: repeated zoom-ins stop at the clamp; the near and reached states and texts are right;
  the announcement count equals the number of state changes; the fallback bits apply. Run on both runtimes
  (FR-A03-206, SC-A03-203).

## Phase 6: Polish

- [ ] T-A03-208 Update `ExplorerUITests` (zoom controls, palette, animate) and the audit (explorer with the
  precision banner forced near the limit through the zoom controls), at default size and XXXL on both runtimes.

  Then:
  - contract: gate A03-P02, G-PRECISION closed, M03 and M10 evidence;
  - regression baseline and simulator lessons;
  - the fast checks.

  Covers FR-A03-208 and SC-A03-204–205.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- G1: fallback and context-loss tests.
- D1: palette independent of gestures.
- C1: precision tests run on the simulators.
- 0 critical issues.

## Dependencies

- T-A03-201 and T-A03-202 are independent; both block T-A03-207.
- T-A03-203 → T-A03-204.
- T-A03-205 and T-A03-206 can run in parallel after 204 (analyze D1).
- Both block T-A03-207 → T-A03-208.
