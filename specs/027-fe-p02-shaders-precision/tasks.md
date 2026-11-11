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

- [X] T-A03-201 Write `PrecisionAdvisorTests` first, with at least 7 cases from the contract. Then add — Verified 2026-11-11: — Verified 2026-11-11: VisualCoreMath.PrecisionAdvisor (assess: ulp = max(|m|, step) * 2^-bits, margin = step/ulp, reliable >= 16, nearLimit 1...16, beyondLimit < 1, invalid input beyond with margin 0; minimumPixelStep; bits clamped 1...64), documented, README and baseline; PrecisionAdvisorTests 7/7 (thresholds at 10/16/23 bits, margin in ulps, zero magnitude not blocked, monotonic minimum, invalid input, more bits smaller step, clamp) in run-check A03-P02/t201-host-visualcore; t201-checks 4/4
  `Packages/VisualCore/Sources/VisualCoreMath/PrecisionAdvisor.swift`:
  - `assess(mantissaBits:magnitude:pixelStep:)` and `minimumPixelStep(mantissaBits:magnitude:)`;
  - `nearLimitMargin` = 16;
  - non-finite or non-positive input gives `beyondLimit` with a margin of 0.

  Add docs, the README note and the baseline entry. Run `swift test` (FR-A03-205).
- [X] T-A03-202 Add `ShaderPrecision` and the optional `fragmentHighp` and `fragmentMediump` properties to — Verified 2026-11-11: — Verified 2026-11-11: RenderCapabilities.ShaderPrecision (rangeMin, rangeMax, precisionBits, isSupported) and optional fragmentHighp/fragmentMediump filled in query via vcglGetShaderPrecisionFormat(GL_FRAGMENT_SHADER, GL_HIGH_FLOAT/GL_MEDIUM_FLOAT), fragmentMantissaBits(fallback: 10); RenderCapabilitiesPrecisionTests 3 (reported on both simulators: highp 23 bits, range 127 — simulator context only; fallbacks; earlier JSON without the keys decodes and round trips) — run-check A03-P02/t202-rendering-27 and -26 TEST SUCCEEDED, enumeration 141/141 each; baseline +9, t202-checks 4/4; ProjectM regression t202-reference-a 3/3 + t202-reference-b 4/4; A01 and A02 build-for-testing succeeded
  `RenderCapabilities` (VisualCoreRendering). Fill them in `query` with `vcglGetShaderPrecisionFormat`.
  - Add `RenderCapabilitiesPrecisionTests`:
    - on both simulator runtimes the values are present and `highp` bits ≥ `mediump` bits (analyze C1); the simulator values are logged as context;
    - JSON without the new keys still decodes.
  - Run the package tests on 27.2 and 26.5 with the guard.
  - Run the ProjectM regression (3/3 + 4/4) and build A01 and A02 (FR-A03-204).

## Phase 2: User Stories 1 and 3 — GPU render (P1) 🎯

- [X] T-A03-203 [US1] [US3] Add `Apps/FractalExplorer/App/FractalShaders.swift`, the fragment source per research R3. — Verified 2026-11-11: — Verified 2026-11-11: App/FractalShaders.swift (escape-time fragment matching FractalMath: z²+c, |z|²>R² after step n, smooth n+1-log2(log|z|), loop bounded 10,000 with break at u_cap, palette via vc/palette.glsl, interior black) and App/FractalScene.swift (wraps VisualCore FullScreenShaderScene; SceneClock paused when animation off; uniforms centerX/centerY/step (plane units per pixel)/mode/seed/cap/radius/rate; linear-light palette stops); project.yml links VisualCoreRendering/Scenes/Simulation/Parameters. GPUAgreementTests 3: Mandelbrot 64x64 100.0% agreement (origin interior, c=2 exterior), Julia 99.90% with 0 unexplained (boundary-only), clock frozen/advancing with animation — run-check A03-P02/t203-app-ios27 and t203-app-ios26 TEST SUCCEEDED, enumeration guard on both
  Add `FractalScene.swift`, which wraps `FullScreenShaderScene`:
  - a clock, the uniforms, the palette and the error pass-through;
  - parameters `centerX`, `centerY`, `step`, `mode`, `seedX`, `seedY`, `cap`, `radius` and `rate`.

  `project.yml`: the app links VisualCoreRendering, VisualCoreScenes, VisualCoreSimulation and VisualCoreParameters.

  Add `GPUAgreementTests`. Render 64 × 64 offscreen views of the default Mandelbrot and Julia scenes. Expect class
  agreement of at least 99%, with boundary-only disagreements, the origin interior and c = 2 exterior. Run on 27.2
  and 26.5 (FR-A03-201, FR-A03-207, SC-A03-202).
- [X] T-A03-204 [US1] Update `ExplorerModel` and `ExplorerView`: — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel owns one RenderHost(FractalScene) shown through VisualCoreUI RenderSurface (fe.canvas, spoken description, hint), close() on disappear; CPU preview only as the fallback when the shader fails (fe.fallback notice); resize keeps center and the width across the shorter side so zoom stays constant (the first iOS 26.5 run t204-app-ios26 failed at zoom 0.96× after layout; fixed). ExplorerModelTests 4: GPU hosted and following state/resize/close, forced shader failure shows the CPU fallback, recreateContext keeps the view, stale previews dropped (analyze G1) — run-check A03-P02/t204-app-ios27-2 and t204-app-ios26-2 TEST SUCCEEDED, enumeration 11/11 each
  - one `RenderHost(scene: FractalScene)` shown through `RenderSurface` with the label `fe.canvas`, and `close()` on
    disappear;
  - the CPU preview stays as the fallback when the shader reports an error;
  - the size follows the view, and the pixel scale goes to the scene.

  Update the existing model and UI tests. Add two tests (analyze G1):
  - a forced shader failure (an invalid fragment) shows the CPU preview fallback;
  - `recreateContext` keeps the view state.

  Run on both runtimes (FR-A03-201).

## Phase 3: User Story 1 — gestures (P1)

- [X] T-A03-205 [US1] Add the gesture mapping in the model: — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel gesture mapping (RenderHost.pointerHandler -> VisualCore PointerTracker + PinchRecognizer; per-event two-finger pan by midpoint movement then anchored zoom by distance ratio; one-finger pan from tracker positions, so a finger left after a pinch pans without a jump; DragRecognizer cannot hand over mid-sequence — spec implementation clarification) and fe.zoomIn/fe.zoomOut/fe.resetView. GestureTests 5: symmetric pinch keeps the plane point under the midpoint within 1e-9 relative and 1 pt on screen up to 7x, moving pinch follows the midpoint, drag exact, lift mid-pinch no jump/no zoom change, controls. The first run t205-app-ios27/26 failed (2% anchor drift from the cumulative-scale approach); fixed; run-check A03-P02/t205-app-ios27-2 and t205-app-ios26-2 TEST SUCCEEDED, enumeration 16/16 each
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

- [X] T-A03-206 [US2] Add the palette picker `fe.palette` (Sunset by default, then Ocean, Forest, Neon and Ember) and — Verified 2026-11-11: — Verified 2026-11-11: palette picker fe.palette (Sunset default, Ocean, Forest, Neon, Ember; others refused) and fe.animate toggle; animation defaults off under Reduce Motion (SystemAccessibilityObserver.systemValues / injectable SystemAccessibility); FractalScene clock paused when off. PaletteTests 3: each palette's linear stops reach the inner FullScreenShaderScene, animation off gives identical offscreen frames 1 s apart and on changes them, Reduce Motion defaults off but can be turned on — run-check A03-P02/t206-app-ios27 and t206-app-ios26 TEST SUCCEEDED, enumeration 19/19 each
  the `fe.animate` toggle. Reduce Motion turns animation off by default (VisualCoreUI `SystemAccessibilityObserver`).
  The clock pauses while animation is off.

  Add `PaletteTests`:
  - each palette's stops reach the scene;
  - with animation off, two frames 1 s apart are identical; with animation on, they differ;
  - Reduce Motion defaults animation to off.

  Run on both runtimes (FR-A03-203, SC-A03-204).

## Phase 5: User Story 4 — precision limit (P2)

- [X] T-A03-207 [US4] In the model: — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel precision limit: mantissa bits from host.capabilities.fragmentMantissaBits() (highp -> mediump -> 10, test seam), pixel step = unitsPerPoint / display scale; apply(_:) raises unitsPerPoint to PrecisionAdvisor.minimumPixelStep * scale so zoom stops; notice none/near/reached with the FR-A03-206 texts in the fe.precision banner, AccessibilityNotification.Announcement once per state change, canvas description ends with the notice. PrecisionClampTests 4: repeated zoom-ins pass none->near->reached and stop exactly at 0.5*2^-23*3 units/pt, zoom-in at the limit is a no-op, 2 announcements for 2 changes, zoom-out clears; 10 bits clamp >1000x earlier than 23; no host -> 10 bits; pinch cannot pass the limit. The first runs t207-app-ios27/26 failed to compile (ambiguous pow in the test); run-check A03-P02/t207-app-ios27-2 and t207-app-ios26-2 TEST SUCCEEDED, enumeration 23/23 each
  - read `host.capabilities.fragmentHighp` (falling back to `mediump`, then 10 bits);
  - clamp the viewport's units per point so the per-pixel step stays ≥ the advisor's minimum;
  - show the `fe.precision` banner with the FR-A03-206 wording;
  - announce only when the state changes;
  - append the state to the spoken description.

  Add `PrecisionClampTests`: repeated zoom-ins stop at the clamp; the near and reached states and texts are right;
  the announcement count equals the number of state changes; the fallback bits apply. Run on both runtimes
  (FR-A03-206, SC-A03-203).

## Phase 6: Polish

- [X] T-A03-208 Update `ExplorerUITests` (zoom controls, palette, animate) and the audit (explorer with the — Verified 2026-11-11: — Verified 2026-11-11: ExplorerUITests +1 (zoom in/out/reset change the canvas label 2×/0.5×/1×, palette Sunset -> Ocean, animate toggles, zoom buttons reach 'Near precision limit' then 'Precision limit reached — zoom stops here' in banner and canvas label, further zoom-in is a no-op, reset clears) and the audit with the precision banner (Mandelbrot, reached through the zoom controls) at default size and XXXL; first runs t208-app-ios27/26 failed (audit zoomed in Julia at center 0, where floats never limit), -2 failed on iOS 26.5 XXXL contrast of text scrolled under the navigation bar (documented, logged exclusion added), run-check A03-P02/t208-app-ios27-4 and t208-app-ios26-4 TEST SUCCEEDED, enumeration 24/24 each; contract gate A03-P02 (M03 and M10 available, G-PRECISION closed, decision reason) check_app_contract PASS 10 rows/34 citations; regression baseline A03-P02 section; simulator lessons feature 027; t208-fast-checks 11/11 PASS
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

## Phase 7: Convergence

- [ ] T-A03-209 Show where the shader's precision assumption comes from: in `ExplorerModel`, add `precisionSource` (for example "Shader precision: highp, 23 bits" or "Shader precision: assumed 10 bits — the graphics driver reported no usable highp or mediump float precision"). Show it as a footnote `fe.precision.source` beneath the banner. Add unit tests for the highp, mediump-only and no-report cases, and run on both runtimes, per US4/AC3 (partial)
