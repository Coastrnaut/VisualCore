# Feature Specification: Infinite Geometry — Phase 02 2D kaleidoscope renderer

**Feature Branch**: `041-ig-p02-kaleidoscope-renderer` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P02 (legacy ledger) · ID namespace FR-A05-2##, SC-A05-2##, T-A05-2##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — touch orbit, pan and zoom with reset and camera bounds; regression fixture —
  mesh generation has index bounds and valid normals; the experience never owns the graphics context.
- **Gaps built here in VisualCore** (documentation, public-API baseline, tests, reference regression): G-SDF2D — 2D
  signed-distance helpers and a shader dihedral fold that matches the framework's CPU fold, proved by a parity test;
  G-ORBITBOUNDS — camera bounds, pan, zoom, orbit and reset for the 2D camera and the orbit camera, pulled forward from
  Phase 03 because this phase's MVP needs it.
- **Rendering:** the kaleidoscope is drawn by a full-screen shader pass on the existing shader path; the tilings keep the
  2D primitive renderer; the 3D composition keeps the mesh renderer.
- **Owner rulings of 2026-11-13:** short tests; audits wait for the device campaign; parallel agents; no wall-clock
  assertions on CI runners.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`FullScreenShaderScene` binds `u_resolution`, `u_palette[8]`/`u_paletteCount`, `u_seed` and one float `u_<name>` per
entry of `parameters` (no arrays or vectors otherwise); `ShaderHashParityTests` is the existing pattern for a GPU/CPU
parity test; `Camera2D` zoom is clamped to 0.1…100 and `OrbitCamera` pitch to ±89° with no pan or reset.

- Q: How does the motif reach the shader? → A: As named floats — `u_order`, `u_repeats`, `u_scale`, `u_count` (3–7) and
  `u_p0x`…`u_p6y` for the motif points — plus the camera's `u_centerX`, `u_centerY`, `u_zoom`; colours through the
  palette binding. No new uniform kinds are needed in the framework.
- Q: How is the shader fold compared with the CPU fold? → A: A simulator test renders, for a 16 × 16 grid of points, the
  GPU-folded point encoded in the colour channels (coordinates mapped from −1…1 to 0…255) and compares with
  `PointGroup.fold` within one step (1/255 of the range), as `ShaderHashParityTests` does for the hash.
- Q: What exactly bounds the 2D view? → A: Zoom 0.5…8 relative to the preset's fit; the view centre stays within the
  composition's extent (the square ±1/scale); clamping happens in the domain action, so the state never holds an
  out-of-bounds camera.
- Q: How do gestures map to actions? → A: One-finger drag → `camera.pan` (screen points converted to world units by the
  fit); pinch → `camera.zoom` (the pinch factor); on the 3D composition a one-finger drag → `camera.orbit` (0.01 rad per
  point) and pinch → distance; double tap → `camera.reset`. Buttons: pan arrows, zoom in/out, orbit arrows, reset.
- Q: How tolerant are the symmetry probes? → A: Points within 1 pixel of a mirror line are excluded; colours match
  within 2/255 per channel; at least 95% of 64 pairs per order must match (SC-A05-201).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A crisp kaleidoscope drawn by the GPU (Priority: P1) 🎯

A person picks the kaleidoscope preset and sees a smooth, sharp-edged kaleidoscope whose mirrors and rotations are
exact, at any order, filling the screen.

**Why this priority**: the phase's deliverable, the 2D kaleidoscope renderer.

**Independent Test**: render the kaleidoscope on the simulator and read pixels at mirrored and rotated positions; they
match.

**Acceptance Scenarios**:

1. **Given** the kaleidoscope at order n, **When** it is drawn, **Then** the colour at any point equals the colour at its
   n rotations and its mirror images (within a small tolerance at edges).
2. **Given** order 1, **When** it is drawn, **Then** the picture is the motif and its mirror only (no extra copies).
3. **Given** a change of order, repetitions, scale, palette or seed, **When** applied, **Then** the next frame reflects it.

---

### User Story 2 - Move the view with touch, within bounds, and reset (Priority: P1)

The person drags to pan, pinches to zoom and, on the 3D composition, drags to orbit; the view never leaves the
composition or flips, and a reset returns to the preset's view. Every gesture also has a button.

**Why this priority**: the phase's MVP.

**Independent Test**: apply pan, zoom, orbit and reset actions (gesture and button) and check the camera state stays
within bounds and reset restores it exactly.

**Acceptance Scenarios**:

1. **Given** a 2D preset, **When** the person pans or zooms beyond the limits, **Then** the view stops at the bound.
2. **Given** the 3D composition, **When** the person orbits, **Then** the pitch stays within ±80° and the distance within
   its range; the view never turns upside down.
3. **Given** any camera state, **When** reset is applied, **Then** the camera returns exactly to the preset's default.
4. **Given** each gesture, **When** the person uses the matching button instead, **Then** the same camera change happens.
5. **Given** a camera action with a non-finite value, **When** applied, **Then** it is refused and nothing changes.

---

### User Story 3 - Shader symmetry is the same as the framework's (Priority: P2)

Other experiences can fold points into a kaleidoscope wedge on the GPU and get exactly the CPU's answer, and draw basic
2D shapes by distance.

**Independent Test**: a simulator test folds a grid of points on the GPU and compares them with the CPU fold.

**Acceptance Scenarios**:

1. **Given** orders 1, 3, 6 and 12 and a grid of points, **When** folded on the GPU and the CPU, **Then** the results
   match within the precision of the render target.
2. **Given** the 2D distance helpers, **When** evaluated, **Then** they give the correct sign inside and outside.

### Edge Cases

- **Zoom at its limits, pan at the edge:** clamped; further gestures do nothing.
- **Pitch at ±80°:** clamped; never flips.
- **Very high order (24):** the wedge is narrow but exact; no aliasing beyond one pixel at the mirror lines.
- **Point exactly on a mirror line or at the centre:** defined colour, identical on both sides.
- **Shader compile failure:** the session's failure path (never a blank screen without a message).
- **Context recreation:** the shader is recompiled and the picture is identical.
- **Reduce Motion:** no automatic camera motion exists; gestures move the view only when the person acts.
- **Camera state in snapshots:** saved and restored with the rest of the state.

## Requirements *(mandatory)*

### Functional Requirements

**Shader kaleidoscope (story 1)**
- **FR-A05-201**: The kaleidoscope preset MUST be drawn by a full-screen shader evaluating the motif by signed distance
  in the folded coordinates of the dihedral group of the preset's order, over its repetitions, coloured from its palette.
- **FR-A05-202**: The drawn picture MUST be symmetric: colours at a point and at its group images match (verified by
  pixel probes on the simulator).
- **FR-A05-203**: The tilings and the 3D composition MUST keep their Phase 01 renderers.

**Camera (story 2)**
- **FR-A05-210**: The experience MUST accept camera actions — pan (dx, dy), zoom (factor), orbit (dyaw, dpitch) and reset
  — validated and clamped to bounds: 2D zoom 0.5…8 of the preset's view, centre within the composition's extent; 3D
  pitch ±80°, distance 3…12, yaw free.
- **FR-A05-211**: Reset MUST restore the preset's default camera exactly.
- **FR-A05-212**: Drag, pinch and (on the 3D composition) orbit gestures MUST map to the same actions, and each MUST
  have a native control alternative.
- **FR-A05-213**: Camera state MUST be part of the experience state (snapshot, digest, restore); a state saved by Phase 01
  (schema 1, no camera) MUST restore with the preset's default camera through the shared migration chain.

**Framework (story 3)**
- **FR-A05-220**: VisualCore MUST provide 2D distance helpers (circle, box, segment) and a dihedral fold in its shader
  library matching `PointGroup.fold`; the motif polygon's distance is computed by the experience from the segment helper
  (its points are experience data).
- **FR-A05-221**: VisualCore MUST provide camera bounds for the 2D and orbit cameras (pan, zoom, orbit, clamp, reset).
- **FR-A05-222**: Both MUST be documented, in the public-API baseline (Swift parts), tested, and followed by the reference
  regression.

**Common**
- **FR-A05-230**: The fixture "mesh generation has index bounds and valid normals" MUST keep passing.
- **FR-A05-231**: Drawing only through the host; no network; no imported assets.

### Key Entities

- **Camera state**: 2D centre and zoom; 3D yaw, pitch, distance; the preset's default for each.
- **Camera bounds**: zoom range, centre extent, pitch limit, distance range.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-201**: Symmetry probes on the drawn kaleidoscope match in ≥ 95% of 64 sampled point/image pairs per order for
  orders 1, 3, 6, 12 (edge pixels excluded within 1 px of mirror lines).
- **SC-A05-202**: The GPU fold matches the CPU fold within 1/255 of the view per coordinate on 100% of a 16 × 16 grid for
  orders 1, 3, 6, 12.
- **SC-A05-203**: Every camera action stays within bounds in 100% of 200 seeded random action sequences; reset restores
  the default exactly in 100% of cases.
- **SC-A05-204**: The nine scenarios and the five fixtures' manifest stay valid; the runner passes 9/9 on both runtimes.
- **SC-A05-205**: The reference regression passes 7 of 7; the public-API baseline lists the camera bounds.
- **SC-A05-206**: Every new test finishes in under 10 seconds.

## Assumptions

- A05-P01 is recorded; the existing full-screen shader pass and shader bundle are used.
- 3D depth testing remains Phase 03 (G-MESHSCENE).

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 deliverable: 2D kaleidoscope renderer | FR-A05-201–203, US1 |
| MVP: touch orbit/pan/zoom with reset and camera bounds | FR-A05-210–213, US2 |
| Fixture: mesh index bounds and valid normals | FR-A05-230 |
| Gate: EGL ownership in the host | FR-A05-231 |
| Gaps G-SDF2D, G-ORBITBOUNDS (A05-P00 contract) | FR-A05-220–222, US3 |
