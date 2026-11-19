# Feature Specification: R02-F09 — Instancing and point/beam renderer

**Feature Branch**: `209-instancing-and-point-beam-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F09 (migration ledger, shared round feature) · ID namespace FR-R02F09-###, SC-R02F09-###, T-R02F09-###

**Input**: User description: the archived R02-F09 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"instanced sprites/solids; transparent depth ordering; beam geometry and fragment falloff", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/209-instancing-and-point-beam-renderer`; FR-R02F09-###, SC-R02F09-###,
  T-R02F09-###.
- **Section 13 disposition: extend.** The framework draws 2D particles instanced (`ParticleRenderer`, up to 100,000
  premultiplied soft discs per call, no depth, no sorting), simulates particles deterministically (`ParticleSystem`, in
  VisualCoreSimulation), draws one mesh per call (`MeshRenderer`) and sorts translucent meshes back to front per item
  (`DepthMeshPass`). It has no instanced solids, no 3D points, no beams and no per-instance ordering. This feature adds,
  on the same renderer and context: drawing one mesh many times in one call with a transform and colour per instance;
  view-facing beams between two points with a soft cross-section and round ends (a beam of zero length is a round point
  sprite); and back-to-front ordering of translucent instances. The particle renderer and system are unchanged.
- **Who the users are:** the engineer of Hue Compass, Echo Cartographer, Acoustic Constellator, Microscopic Aurora or
  Starlight Surveyors, who draws hundreds of stars, cells, nodes and light beams; the player, who sees them sharp, in the
  right order and without popping; the device, which must draw them in few calls.
- **Prerequisites:** R02-F05 and R02-F07 are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** draw cost of large instance counts on D1–D3. **Owner-only items:**
  none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `ParticleRenderer` draws 2D instanced quads with `vcglDrawArraysInstanced` and
per-instance attributes at divisor 1 through the internal `DynamicVertexBuffer` (grows by doubling, rebuilt after
context loss), premultiplied soft discs `(1 − smoothstep(0.8, 1, r))`, no depth, no sort, capped at 100,000;
`MeshRenderer` (Lambert with `lightDirection`/`ambient`, optional linear fog `MeshFog`, back-face culling, depth left to
the caller) draws one mesh per call with `vcglDrawElements`; `DepthMeshPass.backToFront(_:view:)` sorts items by
view-space z with an index tie-break; `vcglDrawElementsInstanced` and `vcglVertexAttribDivisor` are loaded but
`DrawElementsInstanced` is unused; `RenderState.premultipliedBlended` exists (R02-F07).

- Q: What do the two renderers look like? → A: `InstancedMeshRenderer(mesh:registry:)` with `draw(_ instances:
  [MeshInstance], view:projection:fog:translucent:)` — per-instance model matrix (4 vec4 attributes) and colour (vec4) at
  divisor 1, one `vcglDrawElementsInstanced` per call, the shader of `MeshRenderer` with `u_model` replaced by the
  instance matrix (normals by its upper 3 × 3), same `lightDirection`, `ambient` and fog; and `BeamRenderer(registry:)`
  with `draw(_ beams: [BeamInstance], view:projection:blend:)` — 6 vertices per instance, `vcglDrawArraysInstanced`. Both in
  VisualCoreRendering, per-instance data in a reused growing buffer like `ParticleRenderer`. Limits: 16,384 mesh
  instances and 65,536 beams per call (refused above). Rationale: same conventions as the existing renderers, generic.
  Impact: SC-R02F09-001 compares against `MeshRenderer` draws.
- Q: How is a beam built and shaded? → A: The two end points are transformed to view space; the strip runs from
  A − d·(w/2) to B + d·(w/2) along the segment direction d (in view space, projected to the plane facing the eye),
  widened by w/2 on each side perpendicular to d and to the view direction; a degenerate (end-on or zero-length)
  segment uses an eye-facing square of side w. The fragment computes r = distance to the segment divided by w/2 and
  shades `colour × falloff(r)` with falloff(r) = exp(−4 r²) for r ≤ 1, 0 beyond (a Gaussian whose edge is about 2% of
  the centre), premultiplied. Blends: `.premultiplied` (sorted) or `.additive` (not sorted). Depth test on, depth write
  off. Rationale: round ends and a soft glow from one formula; points are the zero-length case. Impact: the CPU
  reference `BeamProfile.falloff(_:)` and `BeamProfile.coverage(point:a:b:width:)` are pure.
- Q: Where does ordering live and how is depth taken? → A: `InstanceOrder.backToFront(depths:)` in VisualCoreScenes
  (pure): indices sorted by view-space z ascending (farthest first, z negative in front of the eye), ties by index,
  non-finite depths refused. Mesh instances use the instance's translation; beams the midpoint of A and B. Translucent
  mesh instances are drawn with blending premultiplied, depth write off, after sorting. Rationale: one stable rule, the
  same as `DepthMeshPass`. Impact: SC-R02F09-003.
- Q: What happens with bad input or limits? → A: `InstancingError.tooMany(count, limit)`, `.notFinite(index)`,
  `.badWidth(index)` (≤ 0) thrown before any GL call; an empty list draws nothing. Rationale: no partial frames.
  Impact: tests per case.
- Q: How is "one draw call" proven? → A: Both renderers count their draw calls in an internal `drawCallCount` (tests);
  the instanced 500-mesh picture is compared pixel by pixel with 500 `MeshRenderer.draw` calls into another target.
  Rationale: direct evidence without GPU counters. Impact: SC-R02F09-001.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Many solids in one draw (Priority: P1) 🎯

An engineer draws the same mesh (a gem, a cell, a node) at hundreds of places, each with its own position, rotation,
scale and colour, in one call, lit and fogged like a single mesh.

**Independent Test**: draw instances on the simulator and compare with drawing each instance separately.

**Acceptance Scenarios**:

1. **Given** a mesh and 500 instances, **When** drawn instanced, **Then** the picture equals drawing the 500 one by one
   with the existing mesh renderer, within one code value at every pixel.
2. **Given** an instance count above the limit, **Then** the call is refused with a named reason and nothing is drawn.
3. **Given** a context rebuild, **When** drawn again, **Then** the picture is the same.

---

### User Story 2 - Beams and points with a soft glow (Priority: P1)

An engineer draws beams (two end points, a width, a colour) that always face the viewer, fall off softly from the
centre line to the edge and have round ends; a beam whose ends coincide is a round point.

**Independent Test**: draw a beam and a point on the simulator and compare pixels with a CPU reference of the falloff.

**Acceptance Scenarios**:

1. **Given** a beam, **When** drawn, **Then** the brightness across it follows the stated falloff of the distance to the
   segment, within 2/255 of the reference.
2. **Given** a beam seen from any direction (not end-on), **Then** it shows its full width.
3. **Given** a beam of zero length, **Then** it is a round point of the beam's width.

---

### User Story 3 - Transparent things in the right order (Priority: P1)

Translucent instances and beams are drawn farthest first, so nearer ones cover farther ones, the same on every frame.

**Independent Test**: overlapping translucent instances at known depths, in a scrambled submission order.

**Acceptance Scenarios**:

1. **Given** translucent instances submitted in any order, **When** drawn, **Then** the result equals drawing them sorted
   from farthest to nearest.
2. **Given** two instances at the same depth, **Then** they keep their submission order.

### Edge Cases

- **No instances:** nothing is drawn, no error.
- **A non-finite transform, end point, width or colour:** refused before drawing.
- **A beam seen exactly end-on:** drawn as a round point of its width.
- **Additive beams:** order does not matter and no sort is done.
- **The existing particle and mesh renderers:** unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F09-001**: One mesh MUST draw at many instances in one call, each with a model transform and a colour, with
  the same lighting, fog and depth behaviour as the existing mesh renderer, up to a stated instance limit.
- **FR-R02F09-002**: Beams MUST draw as view-facing strips between two end points with a width, a colour, a soft
  cross-section falloff and round ends; a zero-length beam MUST draw as a round point.
- **FR-R02F09-003**: Translucent instances and beams MUST be ordered farthest first by view depth, stably; additive ones
  are not sorted.
- **FR-R02F09-004**: The falloff and the ordering MUST have a CPU reference in the pure package, and the GPU output MUST
  match it within stated tolerances.
- **FR-R02F09-005**: Invalid input (non-finite values, counts above the limit) MUST be refused before drawing with a
  named reason.
- **FR-R02F09-006**: Every GPU object MUST come from the host's registry, survive a context rebuild by being made again,
  and be released; buffers are reused across frames.
- **FR-R02F09-007**: The existing particle renderer, particle system, mesh renderer and depth pass and their tests MUST
  be unchanged; every new public name carries documentation; the API baseline and the reference regression are
  updated.

### Key Entities

- **Mesh instance**: model transform, colour.
- **BeamInstance**: two end points, width, colour.
- **Blend**: premultiplied over or additive.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F09-001**: 500 instanced solids equal 500 single draws within 1/255 at every pixel; the instanced picture
  takes one draw call.
- **SC-R02F09-002**: Beam and point cross-sections match the CPU falloff within 2/255 at sampled pixels.
- **SC-R02F09-003**: Scrambled translucent submissions give the same picture as sorted ones in 3 of 3 orders; equal
  depths keep their order.
- **SC-R02F09-004**: Over 100 frames the registry's live object count stays constant; after a context rebuild the
  picture is identical.
- **SC-R02F09-005**: Existing particle, mesh and depth-pass tests pass unchanged; the reference regression passes 7 of
  7; each unit test finishes in under 10 seconds.

## Assumptions

- Instances and beams are 3D and drawn with a view and projection, alongside the mesh renderer's conventions.
- Textured or atlased sprites are outside this slice; points are soft discs like the particle renderer's.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Instanced sprites/solids | FR-R02F09-001, 002 |
| Transparent depth ordering | FR-R02F09-003, 004 |
| Beam geometry and fragment falloff | FR-R02F09-002, 004 |
| No Stage One breakage | FR-R02F09-007 |

## Negative Requirements / Excluded scope

- No second renderer or context; no texture atlas; no change to the particle renderer or system; no device run before
  ImplementationLock-100.
