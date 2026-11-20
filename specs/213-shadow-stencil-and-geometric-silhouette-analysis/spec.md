# Feature Specification: R02-F13 — Shadow stencil and geometric silhouette analysis

**Feature Branch**: `213-shadow-stencil-and-geometric-silhouette-analysis` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F13 (migration ledger, shared round feature) · ID namespace FR-R02F13-###, SC-R02F13-###, T-R02F13-###

**Input**: User description: the archived R02-F13 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"projection of 3D polygons; rasterized mask; intersection-over-union; no GPU readback for logic", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/213-shadow-stencil-and-geometric-silhouette-analysis`; FR-R02F13-###,
  SC-R02F13-###, T-R02F13-###.
- **Section 13 disposition: new (on existing modules).** The framework has planes (`ClipPlane`), rays, convex solids
  (R02-F12), meshes (R02-F05), camera projection (`OrbitCamera.project`, `Mat4.perspective`) and a mesh renderer; it
  has no projection of geometry onto a plane from a light, no 2D convex hull, no polygon rasteriser, no coverage mask,
  no intersection-over-union and no shadow drawing; render targets have a depth attachment but no stencil. This feature
  adds the CPU side that decides (projection, silhouettes, masks, IoU) in VisualCoreScenes beside the geometry, and a
  GPU shadow drawing that only portrays the same projection on the existing renderer; no game decision ever reads
  pixels back.
- **Who the users are:** the player of Nocturne Garden, Moonlit Mechanism or Celestial Eclipse Lab who turns an object
  until its shadow matches a target, or lines up an eclipse, and is told how close they are; the engineer, who needs the
  score to be the same on every device and to match what is drawn.
- **Prerequisites:** R02-F03 (numerical foundations) and R02-F05 (meshes) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** shadow drawing cost on D1–D3, recorded in the device campaign.
  **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Project a shape onto the ground (Priority: P1) 🎯

The engineer projects a mesh or a convex solid onto a plane from a point light or a directional light and gets the
shadow as polygons in the plane's own 2D coordinates; for a convex solid the shadow outline is one convex polygon.

**Why this priority**: every shadow puzzle starts from this projection.

**Independent Test**: a unit cube lit straight down casts a unit square; a point light above a square casts a larger
square scaled by the similar-triangle ratio; a solid behind the light casts nothing.

**Acceptance Scenarios**:

1. **Given** a cube and a directional light straight down onto the ground, **When** it is projected, **Then** the
   outline is the unit square within the stated tolerance.
2. **Given** a point light at height h above a square at height s, **When** it is projected, **Then** the shadow is the
   square scaled by h / (h − s) about the light's foot.
3. **Given** geometry on the far side of the light or crossing the light's horizon, **When** it is projected, **Then**
   only the part that casts a shadow is returned, never a flipped or infinite polygon.

### User Story 2 - Measure how close two shapes are (Priority: P1)

The engineer rasterises the shadow and a target shape into masks over the same region and compares them with
intersection over union, giving a score from 0 to 1 that is identical on every run and device.

**Independent Test**: identical shapes score 1, disjoint shapes 0, two half-overlapping squares 1/3; the mask area
converges to the exact polygon area as the grid is refined.

**Acceptance Scenarios**:

1. **Given** two masks of the same region, **When** compared, **Then** IoU = |A ∩ B| / |A ∪ B|, and two empty masks
   score 1 by definition.
2. **Given** masks of different sizes or regions, **When** compared, **Then** the comparison is refused with a named
   reason.
3. **Given** a polygon and a grid, **When** rasterised, **Then** the covered area is within the stated error of the
   exact area.

### User Story 3 - Draw the same shadow (Priority: P2)

The shadow the CPU scores is drawn on the existing renderer as a flattened copy of the object on the ground, darkening
every covered pixel exactly once even where the object overlaps itself.

**Independent Test**: on the simulator, the drawn shadow's covered pixels match the CPU mask away from edges; a
self-overlapping object darkens no pixel twice; GPU objects are released.

### User Story 4 - Store and replay a target (Priority: P2)

A target mask is stored with a puzzle and compared later, by a later version of the app.

**Independent Test**: a mask round-trips through its stored form; a newer or malformed form is refused.

### Edge Cases

- **A light inside the object, or at the plane:** refused or reported as no shadow, never a non-finite polygon.
- **A light direction parallel to the plane:** refused with a named reason.
- **A degenerate projection (a face seen edge-on):** contributes nothing; no zero-area polygon is returned.
- **A polygon larger than the mask region:** clipped to the region.
- **A mask of zero size or beyond the size limit:** refused.
- **Self-intersecting or non-convex projected polygons from a mesh:** covered by the union of their triangles.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F13-001**: The CPU MUST project points, triangles, meshes and convex solids onto a plane from a point light or a
  directional light, giving polygons in a stated 2D basis of the plane, and MUST drop or clip what lies beyond the light.
- **FR-R02F13-002**: The shadow outline of a convex solid MUST be one convex polygon (the convex hull of its projected
  vertices), wound counter-clockwise in the plane basis.
- **FR-R02F13-003**: A coverage mask MUST rasterise polygons over a stated rectangular region at a stated resolution by
  cell-centre sampling, support union of many polygons, and give its covered count, area and a digest.
- **FR-R02F13-004**: Intersection over union of two masks of the same region and resolution MUST be computed exactly from
  their cells; masks that do not match MUST be refused with a named reason.
- **FR-R02F13-005**: The GPU MUST draw the shadow from the same projection on the existing renderer and context,
  darkening each covered pixel once, and MUST NOT be read back for any game decision.
- **FR-R02F13-006**: Invalid input (non-finite values, a zero direction, a light on the plane or parallel to it, a mask of
  zero or excessive size) MUST be refused with a stable reason code naming the feature.
- **FR-R02F13-007**: A mask MUST have a versioned stored form that round-trips exactly; a newer or malformed form MUST
  be refused.
- **FR-R02F13-008**: Results MUST be deterministic: the same inputs give the same polygons, masks, digests and scores
  on every run.
- **FR-R02F13-009**: Existing geometry, camera and renderer code and their tests MUST be unchanged; every new public
  name carries documentation; the API baseline and reference regression are updated.

### Key Entities

- **Light**: point (position) or directional (direction).
- **Projection plane**: a plane with a 2D basis (origin, two unit axes).
- **Shadow polygon**: corners in the plane basis.
- **Coverage mask**: region, width, height, cells.
- **Comparison**: intersection count, union count, IoU.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F13-001**: Cube and square projections equal their closed forms within 1e-12 for directional and point lights,
  over 100 seeded orientations of the cube.
- **SC-R02F13-002**: IoU of identical, disjoint and half-overlapping squares is 1, 0 and 1/3 exactly at grid resolutions
  aligned with the squares; the mask area of a seeded convex polygon is within 1% of its exact area at 256 × 256 and the
  error at least halves from 128 to 256.
- **SC-R02F13-003**: The drawn shadow's covered pixels equal the CPU mask at every pixel whose 3 × 3 CPU neighbourhood is
  uniform, on iOS 27.2 and 26.5 simulators; a self-overlapping object leaves every shadow pixel at the single-shadow
  value; zero live GPU objects after the host is destroyed.
- **SC-R02F13-004**: Two runs of the same 100 seeded scenes give identical masks, digests and scores.
- **SC-R02F13-005**: At least five positive, negative and boundary fixtures for lights, planes and masks give their
  stated verdicts; a stored mask round-trips byte for byte.
- **SC-R02F13-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- Coordinates follow `VisualCoreMath` (right-handed, y up); the ground is usually y = 0 but any plane is allowed.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: layout and accessibility (including a spoken score) belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Projection of 3D polygons | FR-R02F13-001, 002 |
| Rasterised mask | FR-R02F13-003 |
| Intersection-over-union | FR-R02F13-004 |
| No GPU readback for logic | FR-R02F13-005 |
| Shadow stencil (drawing) | FR-R02F13-005 |
| Schema migration | FR-R02F13-007 |
| Determinism and observability | FR-R02F13-006, 008 |

## Negative Requirements / Excluded scope

- No shadow maps or soft shadows, no reading pixels for logic, no new renderer or context, no stencil buffer added to
  the host's framebuffer, no device run before ImplementationLock-100, no analytics.
