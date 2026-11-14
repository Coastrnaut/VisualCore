# Feature Specification: Infinite Geometry — Phase 03 3D mesh and camera

**Feature Branch**: `042-ig-p03-mesh-camera` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P03 (legacy ledger) · ID namespace FR-A05-3##, SC-A05-3##, T-A05-3##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** deliverable — the 3D mesh and camera of Infinite Geometry as the smallest vertical
  slice; regression fixture 3 — zoom and field-of-view clamps avoid singular or clipped camera states; the experience
  never owns the graphics context.
- **Gaps built here in VisualCore** (documentation, public-API baseline, tests, reference regression), from
  `docs/apps/infinite-geometry/visualcore-contract.md`: G-MESHSCENE — a depth-correct mesh scene that draws several
  meshes with correct occlusion on screen and offscreen and rebuilds after a context recreation; the remainder of
  G-ORBITBOUNDS — panning the orbit camera's target in view space and a field-of-view clamp (bounds, zoom, orbit and
  reset were delivered in A05-P02).
- **Already delivered (A05-P02, not repeated):** 2D camera, orbit and zoom actions with bounds, reset, gestures for
  orbit/zoom, the kaleidoscope shader.
- **Owner rulings of 2026-11-13:** short tests; audits wait for the device campaign; parallel agents; no wall-clock
  assertions on CI runners.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: the
window surface is created without a depth buffer (no `EGL_DEPTH_SIZE` in the config) and `RenderHost.renderOffscreen`
uses a render target without depth; `ResourceRegistry.makeRenderTarget(… depth: true)` (feature 204) gives a target with
a 24-bit depth renderbuffer; `vcglBlitFramebuffer` is exported by CVisualCoreGL; `MeshRenderer` culls back faces and
leaves depth to the caller; `MeshBounds` gives a mesh's centre and radius; `RenderContext` carries the target
framebuffer and a generation that changes on context recreation; `OrbitBounds` (A05-P02) clamps pitch and distance only.

- Q: Where does the depth buffer come from when neither the window nor the export target has one? → A: The mesh scene
  owns a render target with depth at the context's pixel size, draws its meshes there with depth test and write on,
  then copies the colour to the context's framebuffer with a framebuffer blit (colour only, nearest). The target is
  recreated on resize and on a new context generation, and released on teardown. The export path therefore gets the
  depth-correct result unchanged.
- Q: What exactly is the "outside the bounding sphere" rule? → A: With R the composition's bounding radius about the
  origin (|bounds centre| + bounds radius) and t the target, the clamp raises the minimum distance to
  max(lower distance bound, |t| + R + 2 · near); the framework offers this as a clamp that takes the radius, the
  experience supplies R from the built mesh.
- Q: How does a pan move the 3D target? → A: `camera.pan [dx, dy]` in world units moves the target along the camera's
  right and up vectors; the result is clamped to |t| ≤ 1 (scaled back toward the origin). On the 3D composition a
  two-finger drag sends the negated centroid movement converted by 2 · distance · tan(fov / 2) / view height per point
  (the composition follows the fingers); the existing pan buttons send fixed steps.
- Q: How is the field of view set? → A: `camera.fov [degrees]`, an absolute vertical angle in 30…75 (default 60);
  out-of-range or non-finite values are refused; native buttons "Wider" and "Narrower" step by 5°. No gesture changes
  the field of view.
- Q: How are occlusion probes judged when the mesh shader is lit? → A: The two test meshes are pure red and pure green;
  a probe pixel counts for the nearer mesh when that mesh's channel is the larger one and above 0.25, so shading cannot
  flip the verdict. Offscreen equality compares `renderOffscreen` at the view's pixel size with the screen pixels within
  2/255 per channel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A solid composition that looks solid (Priority: P1) 🎯

A person picks the 3D composition and orbits it. Petals in front always hide petals behind them, from every angle, on
screen and in a captured still.

**Why this priority**: the phase's deliverable; today the petals are drawn in a fixed order, so from some angles a petal
at the back is painted over a petal at the front.

**Independent Test**: on the simulator, draw two overlapping solids in both orders and read the pixels where they
overlap; the nearer solid's colour wins in both orders, on screen and offscreen.

**Acceptance Scenarios**:

1. **Given** two overlapping meshes of different colours, **When** they are drawn in either order, **Then** every probed
   overlap pixel shows the nearer mesh.
2. **Given** the 3D composition seen from behind (yaw π), **When** it is drawn, **Then** the probe pixels of the nearer
   petals show the nearer petals.
3. **Given** a scene that was drawn, **When** the graphics context is recreated, **Then** the next frame draws the same
   picture with no stale resource and the resource ledger returns to its previous counts.

---

### User Story 2 - Move around the composition without breaking the view (Priority: P2)

A person pans the 3D composition sideways, widens or narrows the view angle, zooms and orbits. Whatever they do, the
camera never goes inside the composition, the composition is never cut by the near plane, and the view never becomes
degenerate. Reset brings back the default view.

**Why this priority**: completes the MVP requirement "touch orbit/pan/zoom with reset and camera bounds" for the 3D
composition, and regression fixture 3.

**Independent Test**: apply seeded random sequences of pan, zoom, field-of-view and orbit actions; after each action the
camera satisfies every bound; reset restores the default exactly.

**Acceptance Scenarios**:

1. **Given** the 3D composition, **When** the person pans, **Then** the camera's target moves in the view plane (the
   composition moves with the finger) and stops at the pan limit.
2. **Given** the 3D composition, **When** the person changes the field of view, **Then** it stays within its range;
   values outside are clamped by the gesture and refused when sent as an out-of-range action.
3. **Given** any camera state, **When** the person zooms in as far as possible after panning, **Then** the eye stays
   outside the composition's bounding sphere by at least the near-plane distance.
4. **Given** any camera state, **When** the person resets, **Then** target, distance, angles and field of view equal the
   default.
5. **Given** a state saved by Phase 02 (no target, no field of view), **When** it is restored, **Then** it opens with the
   default target and field of view and its other camera values.

---

### User Story 3 - Reusable mesh scene and camera pan for other experiences (Priority: P3)

A future 3D experience draws its meshes through the same depth-correct scene and uses the same orbit pan and
field-of-view bounds.

**Why this priority**: the constitution's reuse principle: generic behaviour lives in VisualCore.

**Independent Test**: the framework tests prove occlusion, offscreen equality and context recreation for the mesh scene
and pan and field-of-view bounds for the orbit camera without the experience.

**Acceptance Scenarios**:

1. **Given** the framework alone, **When** its tests run, **Then** occlusion in both draw orders, offscreen equality,
   context recreation, pan direction, pan limit and field-of-view clamp are each proved by a test.
2. **Given** the public-API baseline, **When** it is checked, **Then** it lists the new types and members, each documented.

### Edge Cases

- Non-finite pan, field-of-view or zoom values leave the camera unchanged (refused as out of range).
- A pan that would cross the limit stops at the limit; a further pan in the same direction changes nothing and is refused
  as unchanged.
- Zooming in after a pan: the minimum distance grows with the target's offset so the eye never enters the bounding sphere.
- A view whose width or height is zero draws nothing and does not fail.
- A mesh scene with no meshes clears to the background colour.
- Offscreen capture at a size different from the view keeps the depth-correct result.
- A restored state with a camera outside the bounds is refused (as in Phase 02).
- The 2D presets ignore the 3D field-of-view and pan state; their camera behaviour from Phase 02 is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

**Depth-correct 3D (story 1)**
- **FR-A05-301**: The 3D composition MUST be drawn with depth testing so that nearer surfaces hide farther ones from
  every camera angle, on screen and in a captured still.
- **FR-A05-302**: Drawing MUST survive a graphics context recreation: everything is rebuilt and the resource ledger
  returns to its previous counts.
- **FR-A05-303**: The 2D presets MUST keep their Phase 02 renderers.

**Camera (story 2)**
- **FR-A05-310**: The experience MUST accept a pan of the 3D target in the view plane (the existing `camera.pan` action
  applied to the 3D composition: dx, dy in world units along the camera's right and up vectors), limited to |target| ≤ 1.
- **FR-A05-311**: The experience MUST accept a field-of-view action `camera.fov [degrees]` (absolute), limited to 30°…75°
  (default 60°); values outside or non-finite are refused.
- **FR-A05-312**: After any action, the eye MUST stay outside the composition's bounding sphere by at least the near-plane
  distance: minimum distance = max(lower distance bound, |target| + R + 2 · near), R the composition's bounding radius.
- **FR-A05-313**: Reset MUST restore target, distance, yaw, pitch and field of view of the default exactly.
- **FR-A05-314**: Target and field of view MUST be part of the experience state (snapshot, digest, restore); a state saved
  by Phase 02 or Phase 01 MUST restore with the default target and field of view through the shared migration chain.
- **FR-A05-315**: Two-finger drag MUST pan the 3D composition while the pinch zooms; field of view MUST have native
  controls ("Wider"/"Narrower", 5° steps) and no gesture; pan on the 3D composition MUST be reachable with the existing
  pan buttons. Every new button MUST have an accessible label and identifier, and the canvas's accessibility value MUST
  state the field of view when the 3D composition is shown.

**Framework (story 3)**
- **FR-A05-320**: VisualCore MUST provide a depth-correct mesh scene that draws a list of meshes (each with a model
  transform and colour) through one orbit camera, on screen and offscreen with the same result, and rebuilds after a
  context recreation.
- **FR-A05-321**: VisualCore MUST provide orbit-camera pan in view space within a target bound and a field-of-view clamp,
  as additions to the camera bounds of A05-P02.
- **FR-A05-322**: Both MUST be documented, in the public-API baseline, tested, and followed by the reference regression.

**Common**
- **FR-A05-330**: Regression fixture 3 MUST cover zoom and field-of-view clamps and the bounding-sphere rule (no singular
  or clipped state); the other four fixtures MUST keep passing.
- **FR-A05-331**: Drawing only through the host; no network; no imported assets; no second renderer.

### Key Entities

- **Orbit view (3D camera state)**: yaw, pitch, distance (Phase 02) plus target (a point in the plane through the origin
  facing the camera, within radius 1) and field of view (30°…75°).
- **Mesh scene item**: a mesh, its model transform and its colour.
- **Composition bounds**: the bounding sphere of the 3D composition, used by the eye-distance rule.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-301**: In both draw orders, 100% of probed overlap pixels show the nearer mesh, on screen and offscreen, on
  both simulator runtimes.
- **SC-A05-302**: The offscreen picture of a mesh scene equals the on-screen picture within 2/255 per channel on 100% of
  probe pixels.
- **SC-A05-303**: After a context recreation, the next frame matches the previous frame on 100% of probe pixels and the
  resource ledger counts are equal.
- **SC-A05-304**: In 200 seeded random sequences of pan, zoom, field-of-view and orbit actions, 100% of states satisfy all
  bounds, including the bounding-sphere rule; reset restores the default exactly in 100% of cases.
- **SC-A05-305**: The nine scenarios and five fixtures stay valid; the runner passes on both runtimes.
- **SC-A05-306**: The reference regression passes 7 of 7; the public-API baseline lists the new mesh scene and camera
  members, all documented.
- **SC-A05-307**: Every new test finishes in under 10 seconds.

## Assumptions

- The window surface has no depth buffer, so the scene renders to its own target with depth and copies the colour to
  the context's framebuffer (Clarifications); the existing render targets with depth (feature 204) are reused.
- The composition's bounding sphere is computed from the built mesh (its bounds), not hard-coded.
- The depth target costs width × height × 8 bytes (colour plus 24-bit depth stored in 4 bytes) and is accounted in the
  resource ledger like every render target; it is the only new GPU memory of this phase.
- The field of view is the vertical angle of the perspective projection.
- Two-finger pan and pinch share one gesture: the centroid's movement pans and the distance ratio zooms.
- Device performance is measured in the device campaign, not here.

## Out of Scope

- Lighting models beyond the existing lit mesh shader; shadows; textures.
- Mesh caching and level of detail (Phase 05: G-MESHCACHE, G-MESHLOD).
- Export of images or meshes; import of meshes.
- Changes to the 2D camera or the kaleidoscope shader.

## Traceability

| Source | Requirement |
|---|---|
| Brainstorm: procedural 3D compositions, camera controls | FR-A05-301, 310–315 |
| v0.1 feature 01 (one 3D procedural composition) | FR-A05-301, 302 |
| v0.1 feature 02 (touch orbit/pan/zoom with reset and camera bounds) | FR-A05-310–315 |
| Manual §9 Phase 03 fixture "zoom and FOV clamps avoid singular or clipped camera states" | FR-A05-330, SC-A05-304 |
| Contract gap G-MESHSCENE | FR-A05-320, 322, SC-A05-301–303 |
| Contract gap G-ORBITBOUNDS (remainder) | FR-A05-321, 322, SC-A05-304 |

## Negative Requirements

- No second renderer, no Metal code, no compute; the existing GL ES → ANGLE path only.
- No ProjectM type in the experience or the public API.
- No network, analytics, accounts or imported art.
- No long tests: no soak or endurance runs.
