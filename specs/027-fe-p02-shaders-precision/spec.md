# Feature Specification: Fractal Explorer — Phase 02 Fractal shaders and precision probe

**Feature Branch**: `027-fe-p02-shaders-precision` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P02 · ID namespace FR-A03-2##, SC-A03-2##, T-A03-2##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates:**
  - MVP: continuous pinch/pan and animated palette controls.
  - Regression fixture: zoom under a centered pinch keeps the selected complex coordinate stationary.
  - EGL/context ownership stays solely in the VisualCore host.
- **Reuse:** VisualCore `FullScreenShaderScene`, `Palette`, the pinch/drag recognizers and pointer tracker,
  `PlaneViewport` and `SceneClock`.
- **G-PRECISION** closes here: a fragment-precision query in VisualCoreRendering, plus a pure precision advisor in
  VisualCoreMath.
- **Verification and truthful precision:** the GPU escape classes are checked against the FractalMath CPU reference.
  Zoom is clamped at the precision limit, and the limit is shown.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Explore with pinch and pan on a live GPU picture (Priority: P1) 🎯

A person pinches to zoom and drags to pan. The fractal follows their fingers smoothly, and the point between their
fingers stays under their fingers.

**Why this priority**: The phase's MVP gate (v0.1 feature 02, journey 1).

**Independent Test**: Open the explorer, pinch and drag on the canvas, and check that the plane point under the
pinch center stays fixed and the picture redraws.

**Acceptance Scenarios**:

1. **Given** the explorer, **When** it opens, **Then** the picture is drawn by the GPU through the VisualCore host
   at full view resolution. The CPU preview is no longer shown.
2. **Given** a two-finger pinch centered at a screen point, **When** the fingers spread or close, **Then** the plane
   point under the midpoint stays fixed. The relative error is ≤ 1e-9 in the viewport state, and ≤ 1 pixel on
   screen.
3. **Given** a one-finger drag, **When** it moves, **Then** the picture moves exactly with the finger.
4. **Given** the pinch or drag gestures, **When** a person cannot use them, **Then** Zoom in, Zoom out and Reset
   view controls do the same, centered on the view.

---

### User Story 2 - Animated palettes with control (Priority: P1)

A person picks a color palette for the escape bands and can let the colors flow (cycle) or keep them still.

**Why this priority**: The phase's MVP gate (v0.1 feature 02).

**Independent Test**: Pick each palette, turn animation on and off, and observe the colors. With Reduce Motion on,
the animation is off by default and is announced as paused.

**Acceptance Scenarios**:

1. **Given** the palette control, **When** a palette is chosen, **Then** the exterior bands use that palette's colors
   and the interior stays black.
2. **Given** animation on, **When** time passes, **Then** the palette shifts along the bands at a steady rate. **When**
   animation is turned off, **Then** the colors freeze where they are.
3. **Given** Reduce Motion is on, **When** the explorer opens, **Then** palette animation starts off. It can still be
   turned on explicitly.

---

### User Story 3 - The GPU picture matches the math (Priority: P1)

The maintainer needs the shader to compute the same sets as the CPU reference, within what 32-bit shader floats can
represent.

**Why this priority**: The A03 rule (formulas with a CPU reference) and truthful rendering.

**Independent Test**: Render small offscreen pictures of known views in both modes and compare each pixel's
interior/exterior class with the CPU reference.

**Acceptance Scenarios**:

1. **Given** the default Mandelbrot and Julia views at 64 × 64, **When** the GPU and CPU classes are compared,
   **Then** they agree on ≥ 99% of pixels. Disagreements happen only within 1 pixel of the set's boundary.
2. **Given** the origin and c = 2 (Mandelbrot) pixels, **When** rendered, **Then** the origin is interior (black) and
   c = 2 is exterior.

---

### User Story 4 - Know and respect the precision limit (Priority: P2)

A person zooming deep must not see garbage or be told the zoom is unlimited. Near the limit they see a warning. At
the limit, zooming stops and the app says why.

**Why this priority**: v0.1 feature 06 and the A03 truthful-precision rule.

**Independent Test**: Read the device's reported fragment precision, then zoom repeatedly. Check the warning and the
clamp, and that the spoken description includes the limit.

**Acceptance Scenarios**:

1. **Given** the GPU's reported fragment `highp` precision (mantissa bits), **When** the view's pixel step comes
   within 16 representable steps of the coordinate magnitude, **Then** a "Near precision limit" warning is shown
   and spoken.
2. **Given** further zooming, **When** the pixel step would fall below 1 representable step, **Then** the zoom is
   clamped there. The app shows "Precision limit reached" and VoiceOver announces it.
3. **Given** a GPU that reports no `highp` fragment floats, or an unusable report, **When** the limit is computed,
   **Then** the conservative 10-bit (`mediump`) assumption is used and the reason is shown in diagnostics.

### Edge Cases

- A pinch with one finger lifted mid-gesture: it becomes a drag from the remaining finger, without a jump.
- Three or more fingers: the extra fingers are ignored (the tracker's limit applies).
- A shader compile failure: the scene clears to dark gray, the error is shown, and the CPU preview returns as a
  fallback picture.
- A context loss: the scene is rebuilt, and the view state is kept (it lives in the model).
- Precision near zero (center at 0): the limit uses max(|center|, pixel step), so a view at the origin is not
  blocked.
- The iteration cap is unchanged in this phase (200). The cost estimate is Phase 03.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-201**: The explorer MUST draw the fractal on the GPU with VisualCore's full-screen shader scene, hosted by
  VisualCore's render host. It passes the plane view, mode, seed, cap, radius and palette as validated uniforms,
  and creates no EGL context in the app.
- **FR-A03-202**: Canvas gestures MUST map to the viewport:
  - a two-finger pinch zooms about the finger midpoint (anchored);
  - a one-finger drag pans exactly with the finger;
  - the mapping uses VisualCore's pointer tracker and recognizers;
  - Zoom in (×2), Zoom out (×0.5) and Reset view controls are the alternatives.
- **FR-A03-203**: A palette control MUST offer at least 4 VisualCore palettes. An animation toggle shifts the
  palette along the bands at a fixed rate. It defaults to off when Reduce Motion is on.
- **FR-A03-204**: VisualCore MUST report the fragment shader's `highp` and `mediump` float precision (range and
  mantissa bits) as part of the render capabilities (G-PRECISION), with tests, docs, the baseline and the ProjectM
  regression.
- **FR-A03-205**: VisualCore MUST provide a pure precision advisor (G-PRECISION). Given the mantissa bits, the
  coordinate magnitude and the pixel step, it returns *reliable*, *near limit* (< 16 steps) or *beyond limit*
  (< 1 step), and the smallest allowed pixel step. It has host tests, docs and a baseline entry.
- **FR-A03-206**: The app MUST clamp zooming at the advisor's smallest step, show and announce "Near precision
  limit" and "Precision limit reached", and include the state in the spoken description.
- **FR-A03-207**: GPU escape classes MUST match the CPU reference on known 64 × 64 views in both modes (≥ 99% of
  pixels, with disagreements only next to boundary pixels). The origin and c = 2 pixels are checked.
- **FR-A03-208**: The contract MUST record G-PRECISION as closed, with the reused VisualCore pieces. The checks MUST
  pass (documented API, isolation, contract, fast checks), and the ProjectM regression MUST pass after the
  VisualCore changes.

### Key Entities

- **Shader precision** (VisualCore): float range (low and high exponent) and precision bits for `highp` and
  `mediump` fragment floats.
- **Precision status** (VisualCore): reliable / near limit / beyond limit, steps of margin, smallest allowed step.
- **Palette choice and animation** (app): palette id, animate flag, phase.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-201**: Scripted pinches about a point keep that plane point fixed within 1e-9 relative in the state and
  1 pixel on screen. Drags move the content by exactly the finger delta.
- **SC-A03-202**: GPU vs CPU class agreement is ≥ 99% on the default views in both modes (64 × 64), on both
  simulator runtimes.
- **SC-A03-203**: The precision advisor's thresholds follow from the mantissa bits (host tests for 10, 16 and 23
  bits). In the app, repeated zoom-ins stop at the clamp, with the warning and the announcement.
- **SC-A03-204**: Palette choice and animation work. Reduce Motion defaults animation to off. UI tests and the audit
  (default size and XXXL) pass on both runtimes.
- **SC-A03-205**: API review, documented-API, isolation, contract, ProjectM regression (7/7) and all app and host
  tests pass.

## Assumptions

- The simulator's reported precision is context, not device evidence. The device values are measured in campaign II
  (constitution V).
- Float32 view uniforms (center and step) are what the shader sees. The advisor's limit is derived from the
  reported mantissa bits. Perturbation or emulated double are later ideas, not MVP.
- The palette shift rate is a fixed, gentle 0.05 cycles per second. Users can turn it off.
- Preview refinement (low iterations while moving) is Phase 03 with the cost estimate.

## Traceability

| Source | Covered by |
|---|---|
| v0.1 feature 02 (pinch/pan, animated palettes) | FR-A03-202, FR-A03-203, US1, US2 |
| v0.1 feature 06 (visible limits, graceful clamping) | FR-A03-205, FR-A03-206, US4 |
| Manual Phase 02 fixture (centered pinch keeps the coordinate) | FR-A03-202, SC-A03-201 |
| Manual §6 render stages 1–3 (camera → shader → palette) | FR-A03-201, FR-A03-203 |
| Manual §13 risk 1 (precision, no unbounded zoom marketing) | FR-A03-206, Negative |
| Gap G-PRECISION | FR-A03-204, FR-A03-205, FR-A03-208 |
| Journey 1 (curated start, pinch, drag) | US1 |

## Negative Requirements

- No second renderer, no Metal path for precision, no EGL in the app.
- No claim of unlimited zoom. The limit is shown and enforced.
- No precision or performance claims from simulator results.
- No networking, permissions or persistence.
