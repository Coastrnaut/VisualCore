# Feature Specification: R02-F08 — Curve, ribbon and tube batch renderer

**Feature Branch**: `208-curve-ribbon-and-tube-batch-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F08 (migration ledger, shared round feature) · ID namespace FR-R02F08-###, SC-R02F08-###, T-R02F08-###

**Input**: User description: the archived R02-F08 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"adaptive curves; parallel transport; continuous texture coordinates; tangent frame and collapse", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/208-curve-ribbon-and-tube-batch-renderer`; FR-R02F08-###, SC-R02F08-###,
  T-R02F08-###.
- **Section 13 disposition: new, on the existing mesh.** The framework has one indexed mesh, a tube along a path with
  rotation-minimising frames (R02-F05, frames internal, texture coordinate along the tube normalised to 0…1), a closed
  camera rail (centripetal Catmull-Rom, fixed sampling, closed only), 2D polylines, and a mesh renderer that draws one
  mesh per call. This feature adds what the nine curve games need, as pure geometry on that one mesh: open and closed
  curves sampled adaptively to a stated accuracy, a public parallel-transport frame that survives cusps and reversals,
  ribbons, texture coordinates in world units that stay continuous across closed seams, and merging many curve meshes
  into one so the existing renderer draws them in one call. No second mesh type and no second renderer.
- **Who the users are:** the engineer of a curve game (Aurora Loom, Lissajous Labyrinth, Wave Knot Keeper, Chrono
  Constellator, Backwards Aurora, Harmonic Bridges, Acoustic Constellator, Starlit Cartouche, Apsides Workshop) who
  builds knots, orbits, wave paths and light trails from code; the player, who must see smooth curves without kinks,
  twisting ribbons or stretched textures; the verification runner, which checks the meshes before they are drawn.
- **Prerequisites:** R02-F05 (mesh compiler and validation) and R02-F07 are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** draw cost of large curve batches on D1–D3 is a device campaign item.
  **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `Mesh` (VisualCoreScenes) holds `Double` `Vec3` positions and normals, `Vec2`
texture coordinates and `UInt32` indices; `MeshBudget.default` is 262,144 vertices and 1,572,864 indices and builders
throw `MeshError.budget` or `.invalidInput`; `Mesh.tube(path:radius:sides:caps:closed:budget:)` uses an internal
`pathFrames` (double reflection, first normal the world axis least parallel to the first tangent, closed-loop twist
spread by arc length, one seam frame appended) with v normalised 0…1; `CameraRail` (VisualCoreMath) is closed-only
centripetal Catmull-Rom with fixed sampling; `MeshRenderer` draws one mesh per call; no curve, ribbon or merge type
exists.

- Q: Where do the new types live and what do they look like? → A: In VisualCoreScenes beside `Mesh` (pure, `Double`,
  `Vec3`): `CubicBezierChain(points:closed:)` (3n + 1 control points open, 3n closed), `CatmullRomSpline(points:closed:
  alpha: 0.5)` (centripetal), both conforming to `ParametricCurve` (`segmentCount`, `position(segment:t:)`,
  `derivative(segment:t:)`); `CurveSampler.sample(_:tolerance:budget:) throws(MeshError) -> CurveSamples` (positions,
  unit tangents, cumulative arc lengths, closed flag); `CurveFrames.parallelTransport(_ samples:initialNormal:)` →
  `[CurveFrame]` (position, tangent, normal, binormal); `Mesh.ribbon(_:width:repeatLength:budget:)`, an overload
  `Mesh.tube(samples:radius:sides:caps:repeatLength:budget:)` and `Mesh.merged(_:budget:)`. The existing tube and rail
  are unchanged. Rationale: one mesh type, one module, pure and host-testable. Impact: section 13 home stays
  VisualCoreScenes (no new module).
- Q: How is adaptive sampling decided and bounded? → A: Each segment is subdivided recursively; an interval is kept
  when the curve at 5 interior parameters (1/6 … 5/6) lies within the tolerance of the chord; otherwise it is split at
  its midpoint, to a depth of 20. Every segment is split at least once unless its control points are collinear within
  the tolerance (so a straight line yields its two end points). Budget: at most 65,536 samples (refused as
  `MeshError.budget` above it). Tolerance must be finite and positive. Arc lengths are cumulative chord lengths.
  Rationale: deterministic, simple, tight enough for cubic segments. Impact: SC-R02F08-001 measures on 1,000 points per
  segment.
- Q: How are collapses and reversals handled? → A: Samples closer than 1e-9 × (1 + largest extent of the samples) to
  the previous kept sample are dropped first (closed curves also drop a last sample equal to the first). The tangent
  at a sample is the normalised sum of its two unit chords; where the sum is shorter than 1e-6 (a reversal), it is the
  chord ahead. Frames are carried by double reflection; at a reversal the normal is kept (only the tangent turns), so
  no frame is undefined and no normal jumps. The first normal is the caller's `initialNormal` made orthogonal to the
  first tangent, or the world axis least parallel to it. Closed curves spread the closing twist linearly by arc length,
  so the last frame equals the first. Rationale: scale-aware, smooth through cusps. Impact: SC-R02F08-002 includes a
  180° reversal and repeated points.
- Q: How are ribbon geometry and texture coordinates defined? → A: A ribbon has two vertices per sample at
  `position ± binormal × width/2`, surface normal the frame normal, u = 0 and 1 across, v = arc length / repeat length;
  for a closed curve the repeat length becomes `L / max(1, round(L / repeat))` so the seam meets, and a seam pair
  repeats the first samples with v = L / repeat. Width is constant or one value per sample (finite, positive). The
  tube overload uses the same frames and v. Rationale: pattern size stays constant; seams continuous. Impact:
  SC-R02F08-003.
- Q: How are meshes merged and drawn? → A: `Mesh.merged` concatenates positions, normals and texture coordinates in
  order and offsets each part's indices by the vertices before it; it refuses an empty list and results above the
  budget, and never welds across parts. The merged mesh is drawn by one `MeshRenderer` draw; the GPU test merges 200
  ribbons laid out on a grid, draws them once and reads pixels at every ribbon's projected centre. Rationale: the
  existing renderer, one buffer, one draw. Impact: SC-R02F08-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A smooth curve with just enough points (Priority: P1) 🎯

An engineer describes a curve by control points (a Bézier or a Catmull-Rom spline, open or closed) and gets samples
that follow it within a stated distance, dense where it bends and sparse where it is straight.

**Why this priority**: every curve game draws curves; fixed sampling either wastes vertices or shows facets.

**Independent Test**: sample known curves and measure the largest distance from the true curve to the sampled
polyline and the number of samples.

**Acceptance Scenarios**:

1. **Given** a curve and a tolerance, **When** it is sampled, **Then** no point of the true curve is farther from the
   polyline than the tolerance, measured on a dense check grid.
2. **Given** a straight segment, **When** sampled, **Then** it needs only its end points.
3. **Given** a curve that would need more samples than the budget, **When** sampled, **Then** it is refused with a
   budget reason rather than truncated.
4. **Given** the same curve twice, **Then** the samples are identical.

---

### User Story 2 - Frames that do not twist or flip (Priority: P1)

The engineer gets a frame (tangent, normal, binormal) at each sample that rotates as little as possible along the
curve, closes on itself on a loop, and stays smooth through cusps, sharp reversals and repeated points.

**Independent Test**: frames along helices, knots, a curve with a 180° reversal and a curve with repeated points.

**Acceptance Scenarios**:

1. **Given** any sampled curve, **Then** every frame is orthonormal and consecutive frames rotate by no more than the
   curve's bend between them.
2. **Given** a closed curve, **Then** the last frame equals the first.
3. **Given** a reversal or repeated points, **Then** no frame is undefined and no normal jumps by more than the bend.

---

### User Story 3 - Ribbons and tubes with textures that do not stretch (Priority: P1)

The engineer builds a ribbon (a strip along the frames, with a width) or a tube from the samples, with a texture
coordinate along the curve in world units, so a pattern keeps its size on long and short curves and meets itself on
a closed loop.

**Independent Test**: build ribbons and tubes on open and closed curves and inspect texture coordinates and seams.

**Acceptance Scenarios**:

1. **Given** a repeat length, **When** a ribbon or tube is built, **Then** the texture coordinate along it grows by 1
   per repeat length of arc.
2. **Given** a closed curve, **Then** the coordinate at the seam matches on both sides (the repeat is adjusted to a
   whole number of repeats).
3. **Given** a width that varies along the curve, **Then** the ribbon's width follows it and the mesh is valid.

---

### User Story 4 - Many curves in one draw (Priority: P2)

The engineer merges hundreds of ribbons and tubes into one mesh and draws it with one call.

**Independent Test**: merge meshes, validate the result, draw it once.

**Acceptance Scenarios**:

1. **Given** 200 curve meshes, **When** merged, **Then** the result has the summed vertex and index counts, every
   index points into its own part, and it passes mesh validation.
2. **Given** the merged mesh, **When** drawn by the existing renderer, **Then** it takes one draw call and shows every
   part.

### Edge Cases

- **A curve with fewer than two distinct points:** refused.
- **A zero tolerance or a non-finite control point:** refused.
- **A ribbon of zero width:** refused; a width function returning non-finite or negative values is refused.
- **A merge above the mesh budget:** refused, nothing partial.
- **The existing tube and camera rail:** unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F08-001**: Cubic Bézier chains and centripetal Catmull-Rom splines, open or closed, MUST evaluate positions
  and first derivatives exactly for given parameters.
- **FR-R02F08-002**: Adaptive sampling MUST produce a polyline within a given tolerance of the curve, deterministic,
  refusing a sample count above a budget, with the cumulative arc length of every sample.
- **FR-R02F08-003**: A public parallel-transport frame MUST be computed for any sampled curve, orthonormal, minimal in
  rotation, closing exactly on closed curves, and defined through cusps, reversals and repeated points.
- **FR-R02F08-004**: Ribbons MUST be built along the frames with a constant or varying width; ribbons and tubes MUST
  offer a texture coordinate along the curve in world units (a repeat length), continuous across closed seams.
- **FR-R02F08-005**: Merging meshes MUST concatenate vertices and offset indices, keep validity and refuse results above
  the mesh budget.
- **FR-R02F08-006**: The merged mesh MUST draw with the existing renderer in one call.
- **FR-R02F08-007**: Existing meshes, tubes, the camera rail and their tests MUST be unchanged; every new public name
  carries documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Curve**: Bézier chain or Catmull-Rom spline, open or closed.
- **Curve samples**: positions, tangents, cumulative arc length.
- **Curve frame**: position, tangent, normal, binormal.
- **Ribbon and tube options**: width (constant or per sample), repeat length.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F08-001**: For 6 reference curves (a circle, a helix, a trefoil knot, a Lissajous figure, an S-shaped Bézier,
  a straight line) and 3 tolerances, the largest distance from the curve to the polyline is within the tolerance in
  18 of 18 cases, and a straight line needs 2 samples.
- **SC-R02F08-002**: Frames are orthonormal within 1e-9 and rotate by no more than the bend plus 1e-9 on every
  reference curve, including a reversal and repeated points; closed curves close within 1e-9.
- **SC-R02F08-003**: Texture coordinates grow by 1 per repeat length within 1e-9 and match across every closed seam.
- **SC-R02F08-004**: A merge of 200 curve meshes validates with no problem and draws in one call on the simulator.
- **SC-R02F08-005**: Existing mesh, tube and camera-rail tests pass unchanged; the reference regression passes 7 of 7;
  each unit test finishes in under 10 seconds.

## Assumptions

- Curves are built on the CPU when content is made or changes, not every frame; the renderer draws the meshes.
- Screen-space (camera-facing) ribbons are drawn as frame-oriented ribbons whose normal the game chooses; a
  camera-facing variant is outside this slice.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Adaptive curves | FR-R02F08-001, 002 |
| Parallel transport | FR-R02F08-003 |
| Continuous texture coordinates | FR-R02F08-004 |
| Tangent frame and collapse | FR-R02F08-003 |
| Batch renderer | FR-R02F08-005, 006 |
| No Stage One breakage | FR-R02F08-007 |

## Negative Requirements / Excluded scope

- No second mesh type or renderer; no per-frame CPU rebuild requirement; no camera-facing ribbons; no image assets; no
  device run before ImplementationLock-100.
