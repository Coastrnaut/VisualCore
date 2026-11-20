# Feature Specification: R02-F11 — SDF and constructive geometry proxy library

**Feature Branch**: `211-sdf-and-constructive-geometry-proxy-library` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F11 (migration ledger, shared round feature) · ID namespace FR-R02F11-###, SC-R02F11-###, T-R02F11-###

**Input**: User description: the archived R02-F11 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"analytic plane/sphere/box distance; signed volume sampling; conservative raymarch option", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/211-sdf-and-constructive-geometry-proxy-library`; FR-R02F11-###, SC-R02F11-###,
  T-R02F11-###.
- **Section 13 disposition: new (on existing modules).** The shader library has signed distances for a sphere, a box, a
  torus, a circle, a 2D box and a segment, a smooth union and a rotation (`vc/sdf.glsl`); one experience shader marches a
  distance field with no CPU twin; the math module has rays with analytic sphere, box and triangle hits (`Ray3`). There
  is no plane, no hard union, intersection or subtraction, no normal, no CPU signed distance at all, no description of a
  shape that both the CPU and the GPU evaluate, no volume sampling and no march that can be proved not to skip a surface.
  This feature adds a constructive shape description evaluated identically on the CPU (the proxy that decides outcomes:
  hits, containment, collisions) and in the shader, reusing `Ray3`, `vc/sdf.glsl` and the include and compile safety of
  R02-F06; Section 13's proposed module `VisualCoreGeometry` is not created, as R02-F05 and R02-F08 placed geometry in
  VisualCoreScenes.
- **Who the users are:** the player of Amethyst Escape, Faceted Forge, Echo Cartographer or Crystal Quarry, whose tap,
  collision or "is the gem inside the cut" must agree with what is drawn; the engineer, who describes a shape once and
  gets the drawing, the decision and its proof from the same description.
- **Prerequisites:** R02-F05 (procedural meshes) and R02-F06 (safe compilation) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** march cost of the largest shape on D1–D3 GPUs, recorded in the device
  campaign. **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One shape description, one answer (Priority: P1) 🎯

The engineer describes a shape from planes, spheres, boxes and a few others, combined by union, intersection,
subtraction and smooth union, moved and turned. The CPU gives the signed distance and the outward normal at any point;
the shader gives the same distance for the same description.

**Why this priority**: every decision in the four games (hit, inside, contact) rests on this distance.

**Independent Test**: analytic distances of each primitive at chosen points equal their closed forms; the combinations
follow their definitions; the shader output matches the CPU at sampled pixels on the simulator.

**Acceptance Scenarios**:

1. **Given** a sphere, a box or a plane, **When** the distance is asked at a point, **Then** it equals the closed form
   within 1e-12, negative inside and positive outside.
2. **Given** a combination, **When** the distance is asked, **Then** union is the minimum, intersection the maximum and
   subtraction the maximum of the first and the negated second, within 1e-12.
3. **Given** a description, **When** the shader evaluates it on the simulator, **Then** its output matches the CPU within
   the stated tolerance at every sampled pixel.

### User Story 2 - A march that never skips a surface (Priority: P1)

The engineer casts a ray against a shape. The conservative option promises never to step through a surface; the fast
option may take bigger steps. Both report hit, miss or ran out of steps, with the point, the normal and the step count.

**Independent Test**: rays against shapes with known analytic hits return the same distance within the stated
tolerance; a thin shell that a naïve over-relaxed march skips is hit by the conservative march; a ray that misses
reports a miss, and a budget too small reports that it ran out.

**Acceptance Scenarios**:

1. **Given** a ray and a sphere or box, **When** it is marched, **Then** the hit distance matches the analytic hit of
   `Ray3` within 1e-6 and the normal within 1e-4.
2. **Given** a thin shell and the conservative option, **When** marched, **Then** the shell is hit.
3. **Given** too few steps, **When** marched, **Then** the result says the budget ran out, never a false miss.

### User Story 3 - How much is inside (Priority: P2)

The engineer samples a shape on a grid to estimate its volume or to know which cells are inside, deterministically.

**Independent Test**: the estimated volume of a sphere and a box converges to the analytic volume as the grid is refined
and is identical across runs.

**Acceptance Scenarios**:

1. **Given** a box and a grid, **When** sampled, **Then** the inside count and volume estimate match the analytic volume
   within a stated error that halves (or better) when the cell size halves.
2. **Given** the same shape and grid twice, **When** sampled, **Then** the results and their digest are identical.

### User Story 4 - Store and restore a shape (Priority: P2)

A shape description is saved with a level and loaded later, including by a later version of the app.

**Independent Test**: a description round-trips through its stored form; a description from an unknown future version
or one beyond the limits is refused with a named reason.

### Edge Cases

- **A non-finite or negative size, a zero-length direction, a non-finite transform:** refused when the description is
  made, with a named reason.
- **A description deeper or larger than the limits:** refused.
- **A ray starting inside a shape:** reports a hit at distance 0 with the inside flagged.
- **A point exactly on a surface:** distance 0; the normal is still defined.
- **Very large or very small coordinates:** no non-finite result; distances stay finite.
- **A smooth union with zero smoothing:** equals the hard union.
- **A non-uniform scale:** refused for the conservative march (it would break the distance bound).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F11-001**: A shape description MUST support at least plane, sphere, box, rounded box, capsule and torus
  primitives, the hard union, intersection and subtraction, a smooth union with a smoothing radius, and translation,
  rotation and uniform scale.
- **FR-R02F11-002**: The CPU MUST give the signed distance (negative inside) of any description at any point, exact for
  the primitives and hard combinations, and a unit outward normal from the distance's gradient.
- **FR-R02F11-003**: The shader MUST evaluate the same description from generated source on the existing renderer and
  context, matching the CPU within a stated tolerance; generated source MUST compile through the safe compilation of
  R02-F06 on both simulator runtimes.
- **FR-R02F11-004**: A march MUST offer a conservative option that never steps further than the distance bound and a
  fast option with a stated over-relaxation, both bounded by a step budget and a maximum distance, and MUST report hit,
  miss or budget exhausted, with the hit distance, point, normal, step count and whether the ray began inside.
- **FR-R02F11-005**: Volume sampling MUST count inside cells on a grid over stated bounds, estimate the volume, and give
  a digest of the inside mask, deterministically.
- **FR-R02F11-006**: Descriptions MUST be refused at creation when a size is non-finite, negative or zero where it must
  be positive, a direction has zero length, a transform is non-finite or not a rotation, a smoothing radius is negative,
  or the description exceeds the node and depth limits, each with a stable reason code naming the feature.
- **FR-R02F11-007**: A description MUST have a versioned stored form that round-trips exactly; an unknown newer version
  or a malformed form MUST be refused with a named reason, never trapped.
- **FR-R02F11-008**: Decisions (hit, inside, contact) MUST be computable on the CPU from the same description as the
  drawing, so that an experience never decides from pixels.
- **FR-R02F11-009**: The existing shader library functions, the ray type and its tests MUST be unchanged; every new
  public name carries documentation; the API baseline and the reference regression are updated; formula sources are
  cited with their licences.

### Key Entities

- **Shape description**: a tree of primitives, combinations and transforms with limits on nodes and depth.
- **March options**: conservative or fast, step budget, maximum distance, surface tolerance.
- **March result**: outcome, distance, point, normal, steps, began inside.
- **Volume sample**: bounds, resolution, inside count, volume estimate, digest.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F11-001**: Primitive and combination distances equal their closed forms within 1e-12 at 1,000 seeded points
  each.
- **SC-R02F11-002**: Marched hits on spheres and boxes equal the analytic ray hits within 1e-6 over 1,000 seeded rays;
  the conservative march hits a thin shell in every case where the fast one is allowed to miss.
- **SC-R02F11-003**: Shader and CPU distances agree within 2/255 of the encoded range at every sampled pixel, on iOS 27.2
  and 26.5 simulators; the shader's hit mask equals the CPU's at every pixel away from silhouette edges.
- **SC-R02F11-004**: Volume estimates of a sphere and a box are within 2% of the analytic value at 64³ samples and the
  error at least halves from 32³ to 64³; repeated sampling gives the same digest.
- **SC-R02F11-005**: At least five positive, negative and boundary fixtures for descriptions give their stated verdicts
  and reasons; a stored description round-trips byte for byte.
- **SC-R02F11-006**: Existing shader library, ray and mesh tests pass unchanged; the reference regression passes 7 of 7;
  each unit test finishes in under 10 seconds.

## Assumptions

- Shapes are 3D and use the coordinate conventions of `VisualCoreMath` (right-handed, y up).
- The consumer games do not exist yet; this slice ships the library and its proofs, not a game.
- Formulas follow well-known closed forms and published distance functions; their sources are cited.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Analytic plane/sphere/box distance | FR-R02F11-001, 002, 003 |
| Signed volume sampling | FR-R02F11-005 |
| Conservative raymarch option | FR-R02F11-004 |
| CPU proxies that decide outcomes | FR-R02F11-008 |
| Schema migration | FR-R02F11-007 |
| Error handling and observability | FR-R02F11-006 |
| No Stage One breakage | FR-R02F11-009 |

## Negative Requirements / Excluded scope

- No new module, renderer or context; no mesh generation from distance fields (marching cubes) in this slice; no
  texture-based distance fields; no game; no device run before ImplementationLock-100; no analytics.
