# Feature Specification: Oscilloscope Studio — Phase 02 Timebase/trigger waveform renderer

**Feature Branch**: `062-os-p02-trace-xy` (spec directory only; work stays on `main`)

**Created**: 2026-11-14

**Status**: Draft

**Ledger gate**: A08-P02 (legacy ledger) · ID namespace FR-A08-2##, SC-A08-2##, T-A08-2##

**Input**: User description: archived manual `apps/08-oscilloscope-studio.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — a stereo XY (Lissajous) view using the available stereo input; regression
  fixture — trigger detection handles a flat line and a missing crossing; graphics-context ownership stays solely in
  the VisualCore host.
- **Gaps built here in VisualCore** (docs, public-API baseline, tests; reference regression at X-A08 per the owner
  ruling of 2026-11-14), from `docs/apps/oscilloscope-studio/visualcore-contract.json`: G-DECIMATION (a min/max
  reduction of a sample window to at most one column pair per pixel) and G-TRACESTRIP (a bounded multi-point line
  shape drawn as one batch by the host's existing 2D renderer). **App-local:** G-XYMODE moves from A08-P03 into this
  phase because the manual's Phase 02 gate asks for the XY view.
- **Experience:** the triggered waveform of A08-P01 is redrawn as decimated trace strips (no per-sample shapes), and
  the XY view plots the left channel against the right; a mono source shows the XY view disabled and marked.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec Kit
  step runs.

## Clarifications

### Session 2026-11-14

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`Primitive` (VisualCoreScenes) has `rect`, `circle`, `line(Vec2, Vec2, width:)` and `polygon` (≤ 256 points); only
`SceneGraph.swift` (`bounded`, `contains`) and `PrimitiveRenderer.triangles` switch over it; `PrimitiveRenderer` draws a
node tree as one triangle batch (`lastTriangleCount`), tested in `PrimitiveRendererTests` on the simulator; the scope
presenter draws in pixel units (`ViewMetrics(size: pixel width × height, scale: 1)` from `context.pixelWidth`); the
A08-P01 presenter draws one `.line` node per segment; `ScopeState` is schema 1.

- Q: How is the multi-point line shape added without changing the existing shapes? → A: A new case
  `Primitive.polyline([Vec2], width: Double)` with `maxPolylinePoints = 8,192` (two points per column for 4,096
  columns); `bounded` keeps the first 8,192 finite points and a non-negative finite width; `contains` is the distance to
  the nearest segment; `PrimitiveRenderer` draws it as one quad per non-zero segment (the same six vertices a two-point
  `.line` gives), so its pixels equal the segments drawn one by one; the four existing cases are untouched.
- Q: What does the reduction return and how is it drawn? → A: `MinMaxDecimator` in `VisualCoreAudioDSP` returns, for
  N columns, the per-column (min, max) of the samples whose index falls in that column (column = ⌊i × N / count⌋);
  when count ≤ N it returns one column per sample with min = max = the sample. The presenter draws it as a zig-zag
  polyline (min then max per column, at the column's x), so every peak is on screen with at most 2 N points.
- Q: How many columns does the waveform use? → A: The canvas's pixel width inside the grid inset (at most 4,096 per the
  window cap); one polyline per channel per frame.
- Q: How does the XY view scale, and what counts as stereo? → A: x = left × gain, y = right × gain, each clamped to
  ±1 and mapped to the square grid area centred on the canvas; one polyline through the window's frames in order
  (at most 4,096 points). A window is stereo when its channel count is 2; the test signal and stereo files are stereo,
  the microphone and mono files are not.
- Q: How does the saved state change? → A: `ScopeState` schema 2 adds `display` ∈ {waveform, xy}; the migration from
  schema 1 adds `waveform`; a new action `display.select [0…1]` changes it (refused with `a08.needs-stereo` only by
  the presenter's live check, never by the core, so snapshots stay deterministic); the canvas description names the
  view.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Lissajous figure from stereo input (Priority: P1) 🎯

A maker plays the two-channel test signal (or a stereo file) and switches the scope to XY: the left channel drives the
horizontal axis and the right channel the vertical axis, so the 2 : 3 frequency ratio of the test signal draws a
stable Lissajous figure.

**Why this priority**: the manual's MVP for this phase.

**Independent Test**: with the stereo test signal (left 1 kHz, right 1.5 kHz) in XY mode, the plotted points equal the
window's (left, right) sample pairs scaled by the gain, and the figure closes on itself over the window.

**Acceptance Scenarios**:

1. **Given** a stereo source and XY mode, **When** a frame is drawn, **Then** every plotted point is (left × gain,
   right × gain) of one window frame, clamped to full scale.
2. **Given** a mono source (the microphone or a mono file), **When** XY mode is chosen, **Then** the scope keeps the
   waveform view, marks XY as unavailable ("XY needs two channels") and says so.
3. **Given** XY mode, **When** the source changes from stereo to mono, **Then** the view falls back to the waveform
   with the same mark; the chosen view stays XY, so a stereo source shows XY again without a new choice.

---

### User Story 2 - A trace that keeps its peaks without over-drawing (Priority: P1)

A musician looks at a 5 ms/div window of a square wave or a short click: every peak is still visible, and the trace
is drawn with no more points than the screen has pixel columns.

**Why this priority**: the renderer half of this phase; the catalog's "resample decimated display points to avoid
drawing more geometry than pixels".

**Independent Test**: reducing a window to N columns keeps the extreme value of every column, never returns more
than N column pairs, and returns the samples unchanged when they already fit.

**Acceptance Scenarios**:

1. **Given** a 2,400-sample square-wave window and 400 columns, **When** it is reduced, **Then** every column holds
   the column's minimum and maximum, and the trace's highest and lowest points equal the window's.
2. **Given** a single-sample impulse anywhere in the window, **When** it is reduced, **Then** the column that holds it
   shows its full height.
3. **Given** 300 samples and 400 columns, **When** it is reduced, **Then** the 300 samples are drawn as they are.
4. **Given** a trace, **When** it is drawn, **Then** it is one bounded line shape per channel, not one shape per
   segment.

---

### User Story 3 - The trigger fixture (Priority: P2)

The owner can rely on a fixed check: a flat line and a level the signal never crosses give no trigger, the auto mode
keeps showing the newest span and says "no trigger", and the normal mode keeps the last triggered trace and says
"waiting".

**Independent Test**: scenario fixtures and session tests for the flat line and the missing crossing in both modes.

**Acceptance Scenarios**:

1. **Given** silence, **When** frames are drawn in auto mode, **Then** the trace is the flat newest span and the
   canvas says "no trigger".
2. **Given** a trigger level above the signal's amplitude in normal mode, **When** frames are drawn, **Then** the last
   triggered trace stays and the canvas says "waiting".

### Edge Cases

- **Zero or negative column count, empty window, NaN samples:** the reduction returns no columns or skips non-finite
  samples; the line shape refuses non-finite points and drops them.
- **More points than the shape bound:** the line shape keeps at most its maximum point count (the first points), so a
  caller error cannot allocate without limit.
- **Very short windows (fewer samples than columns):** drawn unreduced.
- **Clipped values:** drawn at full scale; the clipping mark of A08-P01 stays.
- **Width below one pixel or zero-length segments:** the shape still draws a visible line of at least one pixel and
  skips zero-length segments.
- **XY with the sweep:** the sweep's right channel follows the 1.5 ratio, so the figure keeps changing; it is still
  plotted pair by pair.

## Requirements *(mandatory)*

### Functional Requirements

**VisualCore (gaps)**

- **FR-A08-201**: VisualCore MUST offer a min/max reduction of a sample window to at most N columns that keeps the
  minimum and maximum of every column, returns at most N columns, returns the samples unchanged when they number N or
  fewer, and ignores non-finite samples (G-DECIMATION).
- **FR-A08-202**: VisualCore MUST offer a multi-point line shape with a width, bounded to a maximum point count and
  refusing non-finite points, drawn by the host's existing 2D renderer as one batch, with pixels matching the same
  segments drawn one by one (G-TRACESTRIP).
- **FR-A08-203**: Existing 2D shapes and their drawing MUST stay unchanged (rectangles, circles, two-point lines,
  polygons).

**Experience**

- **FR-A08-210**: The waveform view MUST draw each channel as one decimated line shape with at most one column pair per
  pixel column of the canvas.
- **FR-A08-211**: The scope MUST offer an XY view that plots left against right for stereo windows, scaled by the gain
  and clamped to full scale; for mono sources it MUST keep the waveform view, mark XY as unavailable and say so.
- **FR-A08-212**: The display mode MUST be saved with the scope state (schema 2); a schema-1 state restores with the
  waveform view.
- **FR-A08-213**: The canvas description MUST name the view (waveform or XY), and in XY the frequency ratio of the test
  signal; flat-line and missing-crossing states MUST read "no trigger" (auto) or "waiting" (normal).
- **FR-A08-220**: The scenario manifest MUST add fixtures for the flat line and the missing crossing in both trigger
  modes and for the XY view.
- **FR-A08-230**: No networking, recording or storage of audio; levels relative to full scale; no claims of
  calibrated phase or frequency measurement from the Lissajous figure.

### Key Entities

- **Column reduction**: column count N; per column a minimum and maximum; identity when the window fits.
- **Line shape**: points (bounded count), width.
- **Scope state** (schema 2): A08-P01's fields plus the display mode (waveform or XY).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A08-201**: For squares, impulses and noise windows of 2,400 samples reduced to 100…1,000 columns, every column's
  minimum and maximum equal the column's true extremes and the output never exceeds the column count.
- **SC-A08-202**: A line shape of N points draws in one batch; its rendered pixels equal those of the same N − 1
  segments drawn one by one within 1 % of the covered pixels; non-finite points are dropped.
- **SC-A08-203**: In XY with the stereo test signal, 100 % of plotted points equal the window's scaled (left, right)
  pairs; a mono source never enters XY.
- **SC-A08-204**: The flat-line and missing-crossing fixtures pass in auto and normal mode; the canvas says "no
  trigger" or "waiting" accordingly.
- **SC-A08-205**: All existing primitive tests pass unchanged; the scenarios and fixtures pass on iOS 27; each package
  test finishes in under 10 seconds.

## Assumptions

- The canvas's pixel column count comes from the host's view metrics; the reduction runs once per channel per frame.
- Spectrum view and dB annotation stay for A08-P03; freeze, cursors and presets for A08-P04.

## Out of Scope

- Spectrum view and annotation (A08-P03); freeze, cursors, zoom mapping and presets (A08-P04); stereo microphone routes
  (A08-P05).

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (stereo XY/Lissajous view using available stereo input) | FR-A08-211, 212; story 1 |
| v0.1 feature 01 (time-domain waveform) and catalog decision "no more geometry than pixels" | FR-A08-201, 210; story 2 |
| Manual §9 Phase 02 fixture (trigger handles flat line and missing crossing) | FR-A08-213, 220; story 3 |
| Catalog fixture "Stereo XY view is disabled or clearly marked for mono sources" | FR-A08-211; story 1 AC2 |
| Capabilities "Line rendering", "Multiple visualization modes" | FR-A08-202, 211 |
| Contract gaps G-DECIMATION, G-TRACESTRIP, G-XYMODE | FR-A08-201–203, 211 |

## Negative Requirements

- No second renderer or context; no ProjectM code; no networking; no audio stored, recorded or sent; no calibrated
  phase or frequency claims; no change to existing shapes' drawing.
