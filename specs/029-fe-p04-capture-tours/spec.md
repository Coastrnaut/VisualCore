# Feature Specification: Fractal Explorer — Phase 04 High-resolution capture and tours

**Feature Branch**: `029-fe-p04-capture-tours` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A03-P04 · ID namespace FR-A03-4##, SC-A03-4##, T-A03-4##

**Input**: User description: archived manual `apps/03-fractal-explorer.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates:**
  - MVP: an adjustable iteration cap with an explicit render-cost estimate.
  - Regression fixture: the precision-warning thresholds are based on known representation limits.
  - EGL/context ownership stays solely in the VisualCore host.
- **Gaps closed here:** G-COST (a relative cost estimate in VisualCore diagnostics) and G-TOUR (log-scale framing
  interpolation in VisualCore math).
- **Reuse:** A02's still-capture path is generalized into VisualCore rendering (still capture) instead of being
  copied. Export sizes, the PNG encoder, temporary folders, offscreen rendering and easing curves are reused.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2), choosing the recommended option each time.
Facts checked in code:
- `RenderHost.renderOffscreen(width:height:time:)` renders the host's scene on its own context and is limited by
  `maxRenderSize`;
- the fractal scene sets the shader time from its clock on every render, and the clock stops while animation is off;
- `ExportGeometry.size(longEdge:aspect:)` caps by device edge, 8192 px and 64 Mpx; `ease(_:_:_:)` with
  `EasingCurve`/`EasingMode` exists in VisualCoreMath;
- A01 and A02 already declare the Photos add-only usage text for the share sheet.

- Q: What happens when a 4096 px capture would make each pixel finer than the precision limit, although the screen
  view is fine? → A: The capture's long edge is reduced until its pixel step is at the advisor's minimum (never below
  the canvas's own pixel size), and the message says "Captured at N px — the precision limit allows no more detail
  here". Upscaling past real precision is never presented as detail.
- Q: How does the center move during a tour flight so that the target stays in view? → A: The log of the span is
  interpolated with easing. The center moves in proportion to the span change: c = c₁ + (c₀ − c₁)·(s − s₁)/(s₀ − s₁)
  (linear when the spans are equal). This keeps the target's offset within |c₁ − c₀|/s₀ of the view. When the target
  is outside the starting view (|c₁ − c₀| > s₀/2), the flight first zooms out to a framing that contains both
  points (center at the midpoint, span = max(s₀, s₁, 2·|c₁ − c₀|)), then zooms in.
- Q: What does the iteration control look like? → A: A slider on a log scale from 50 to 10,000 (whole numbers),
  with ÷2 and ×2 buttons (`fe.cap.down`, `fe.cap.up`). The label reads "Iterations: N". Changes apply immediately.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose the iteration cap and see what it costs (Priority: P1) 🎯

A person exploring a deep region raises the iteration cap to reveal detail. Before and while doing so, they see how
much more work the picture takes, as a relative figure that never pretends to be a time.

**Why this priority**: The phase's MVP gate (v0.1 feature 04).

**Independent Test**: Move the iteration control and read the cost text and the canvas description.

**Acceptance Scenarios**:

1. **Given** the explorer, **When** the person sets the cap with the control (a log-scale slider from 50 to 10,000,
   plus ÷2 and ×2 buttons), **Then** the picture uses the new cap and the canvas description names it.
2. **Given** any cap and canvas, **Then** a line reads "Render cost: N× the default view" (N relative to cap 200 on
   the same canvas, two significant digits), with a word level: light (≤ 2×), moderate (≤ 10×), heavy (> 10×).
3. **Given** a heavy cost, **Then** the line adds "may be slow on this device" and the cap is not refused.

---

### User Story 2 - Capture a high-resolution picture (Priority: P1)

A person saves the current view as a large image to share or keep.

**Why this priority**: v0.1 feature 05 (still capture), the phase title.

**Independent Test**: Capture, then check the image's size and pixels and that a share button appears.

**Acceptance Scenarios**:

1. **Given** the explorer, **When** Capture is tapped, **Then** a PNG of the current view (same center, span and
   palette, the animation frozen) is made at 4096 pixels on the long edge, in the canvas aspect, capped by the
   device's render limit and by the precision limit (clarification 1), and a share button offers it.
2. **Given** the image, **Then** its content matches the live view: escape classes at 64 sample points agree with the
   CPU reference at the same plane points (≥ 99%, boundary only).
3. **Given** a capture failure (size too large, render error), **Then** a message says so and nothing is left on disk.
4. **Given** a new capture or leaving the explorer, **Then** the previous file is deleted; the capture folder is
   emptied at launch.

---

### User Story 3 - Take a guided tour (Priority: P2)

A person picks a curated tour; the view travels smoothly between famous places with a short explanation at each.

**Why this priority**: v0.1 feature 05 (curated guided tours).

**Independent Test**: Start a tour and sample the framing over time; check stops, captions and Reduce Motion.

**Acceptance Scenarios**:

1. **Given** the Tours list (three tours: Seahorse Valley, Elephant Valley, Mini Mandelbrot), **When** a tour starts,
   **Then** the view moves from stop to stop: the zoom changes on a log scale with eased start and end, and the
   center follows so that the target stays in view (clarification 2); each flight takes 4 seconds and each stop holds
   3 seconds with its caption.
2. **Given** Reduce Motion, **Then** the tour jumps between stops without the zoom flight and holds each stop.
3. **Given** a running tour, **When** the person touches the canvas or taps Stop, **Then** the tour stops at the
   current view, which stays.
4. **Given** each tour stop, **Then** it is within this device's precision limit, or the precision banner applies.

---

### User Story 4 - Precision thresholds follow the number format (Priority: P2)

The precision warnings must rest on the real spacing of 32-bit floating point numbers, not on a guess.

**Why this priority**: The phase's regression fixture.

**Independent Test**: Compare the advisor's smallest step with the actual spacing of 32-bit floats at many
magnitudes.

**Acceptance Scenarios**:

1. **Given** 23 mantissa bits (32-bit floats) and magnitudes from 2⁻²⁰ to 4, **Then** the smallest allowed pixel step
   is at least the true spacing of 32-bit floats at that magnitude and at most twice it.
2. **Given** 10 bits (16-bit floats), **Then** the same holds against the true spacing of 16-bit floats.
3. **Given** the device's reported precision bits, **Then** the explorer uses those bits (Phase 02), never a fixed
   guess, except the documented 10-bit fallback.

### Edge Cases

- A cap set while a tour runs: the tour continues; the cap applies.
- The canvas has no size yet: Capture is disabled.
- A capture on a device whose render limit is below 4096: the long edge is the limit (aspect kept).
- A tour started in Julia mode: the tour switches to Mandelbrot (its stops are Mandelbrot places).
- Leaving the explorer during a tour or capture: the tour stops and the file is deleted.
- Cost at the 10,000 cap on a large iPad canvas: shown as a number (for example 63×), never infinity.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A03-401**: VisualCore MUST provide a relative render-cost estimate (G-COST): pixels × iterations × samples
  relative to a reference, monotonic in each factor, labelled relative (never a time), with level words for given
  thresholds. Host tests, docs and a baseline entry.
- **FR-A03-402**: VisualCore MUST provide log-scale framing interpolation and a tour timeline (G-TOUR): between two
  framings the span changes geometrically, the center keeps the target in view, easing applies, the end is exactly
  the target; a timeline of stops with flight and hold durations gives the framing and the current stop at any time,
  with a no-flight mode for Reduce Motion. Host tests, docs and a baseline entry.
- **FR-A03-403**: VisualCore MUST provide a still capture (generalized from A02): offscreen render on the host's own
  context at an export size, PNG encoding, a file in an app-owned temporary folder, the previous file removed, errors
  as messages. Package tests on both runtimes, docs, baseline. A02 is not changed in this phase.
- **FR-A03-404**: The explorer MUST offer the iteration control (`fe.cap`, `fe.cap.down`, `fe.cap.up`) and the cost
  line (`fe.cost`) per US1, and the canvas description MUST include the cap when it is not 200.
- **FR-A03-405**: The explorer MUST offer Capture (`fe.capture`) and a share button (`fe.capture.share`) per US2, with
  a failure message (`fe.capture.error`); the app declares the Photos add-only usage text for saving from the share
  sheet.
- **FR-A03-406**: The explorer MUST offer Tours (`fe.tours`) with three curated Mandelbrot tours, a caption
  (`fe.tour.caption`) and Stop (`fe.tour.stop`) per US3, honouring Reduce Motion.
- **FR-A03-407**: The precision advisor's smallest step MUST be checked against the true float spacing for 23 and 10
  bits (US4), as a host regression fixture.
- **FR-A03-408**: The contract MUST record G-COST and G-TOUR closed and the still capture added (G-CAPTURE), the checks
  MUST pass, and the ProjectM regression (7/7) and the A01 and A02 builds MUST pass after the VisualCore changes.

### Negative requirements

- No time or frame-rate claim from the cost estimate; it is relative.
- No video export of tours in this slice.
- No direct Photos write; saving goes through the system share sheet only.
- No change to A02's capture code in this phase.

### Key Entities

- **Render cost** (VisualCore): pixels, iterations, samples, reference; ratio and level.
- **Framing flight and tour timeline** (VisualCore): stops (framing, hold), flight duration, easing, Reduce Motion.
- **Still capture** (VisualCore): size, folder, latest file, state.
- **Tour** (app): name, stops (framing, caption), mode.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A03-401**: The cost ratio is 1 at the default cap and canvas, doubles when the cap doubles, and its level words
  follow the thresholds, in 100% of test cases.
- **SC-A03-402**: Along any flight, the log of the span changes monotonically and ends exactly at the target; the
  target center stays inside the view at every sampled time (100 samples per flight).
- **SC-A03-403**: A capture at 4096 px (or the device limit) has the canvas aspect and agrees with the CPU reference
  at ≥ 99% of 64 sample points, on both simulator runtimes.
- **SC-A03-404**: The advisor's smallest step lies within [1, 2] × the true float spacing for every tested magnitude
  (23 and 10 bits).
- **SC-A03-405**: UI tests set the cap, read the cost, capture and see the share button, start and stop a tour, on both
  runtimes; the audit passes at default size and XXXL.
- **SC-A03-406**: Fast checks, ProjectM regression 7/7 and the A01 and A02 builds pass.

## Assumptions

- Cost reference: cap 200, one sample per pixel, the current canvas; "samples" stays 1 in this slice.
- Tour stops are well-known published Mandelbrot coordinates; captions are short factual descriptions.
- 4096 px fits within the device render limits reported by the simulators; devices report their own limit.
- The capture temporary folder is emptied at launch (as A02 does).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 04 — adjustable iteration cap with render-cost estimate | FR-A03-401, FR-A03-404, US1 |
| v0.1 feature 05 — still capture and curated guided tours | FR-A03-402, FR-A03-403, FR-A03-405, FR-A03-406 |
| Phase 04 regression fixture — precision thresholds from representation limits | FR-A03-407, US4 |
| Constitution Principle II / owner reuse rule | FR-A03-401–403 |
| Constitution A03 — truthful precision; Principle VIII privacy | US3 AC4, FR-A03-405 |
