# Feature Specification: R02-F05 — Procedural mesh compiler and mesh validation

**Feature Branch**: `205-procedural-mesh-compiler-and-mesh-validation` (spec directory only; work on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: R02-F05 (migration ledger, shared round feature) · ID namespace FR-R02F05-###, SC-R02F05-###, T-R02F05-###

**Input**: User description: the archived R02-F05 `/speckit-specify` prompt (round2.md), verbatim in the invocation, with
the canonical overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21, and the owner's rulings of 2026-11-13.

Canonical overrides:
- **Feature directory and ids:** `specs/205-procedural-mesh-compiler-and-mesh-validation`; FR-R02F05-###,
  SC-R02F05-###, T-R02F05-###.
- **Section 13 disposition: extend.** The framework already has one indexed triangle mesh (positions, unit normals,
  texture coordinates, 32-bit indices; plane, cube and sphere generators; counter-clockwise front faces seen from
  outside) and a renderer that draws it. This feature adds what games need on top of that one mesh: a builder of
  indexed vertices, more shapes (parametric surfaces, revolved and extruded profiles, tubes along a path, bevelled
  boxes), normal generation, bounds, and a validator that proves a mesh is well formed. No second mesh type.
- **Who the users are:** the engineer writing one of the 75 games, who builds boards, pieces, tracks and props from
  code and needs them correct, bounded and identical on every run; the player, who must never see holes, inside-out
  faces or flickering shading; the verification runner, which checks content meshes before they are drawn.
- **Prerequisites:** R02-F03 (determinism and numeric hygiene) and R02-F04 (GPU resource ownership) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009: one USD 1.99 unlock); the
  Round 2 lock (ImplementationLock-100). **Device-only items:** none (meshes are built and validated on the CPU; the
  existing renderer draws them). **Owner-only items:** none.
- **Owner rulings of 2026-11-13:** tests are short; system accessibility audits wait for the device campaign;
  independent files go to parallel agents.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build a correct mesh from code (Priority: P1) 🎯

A game engineer describes a shape in code (a surface, a revolved profile, a tube along a path, a bevelled box) and gets
an indexed mesh whose triangles face outward, whose shared vertices are merged, and whose normals shade smoothly where
the surface is smooth and sharply at creases.

**Why this priority**: every 3D game piece is built this way; a wrong mesh is a visible defect.

**Independent Test**: build each shape at several resolutions and check vertex and triangle counts, outward winding,
unit normals and closedness.

**Acceptance Scenarios**:

1. **Given** a closed shape description (a revolved profile closed at both poles, a capped tube, a bevelled box),
   **When** it is built, **Then** the mesh is closed (every edge shared by exactly two triangles), consistently wound
   outward, and every normal has unit length.
2. **Given** an open surface (a grid surface, an uncapped tube), **When** it is built, **Then** its boundary edges are
   exactly the expected outline and its winding is consistent.
3. **Given** a crease angle, **When** normals are generated, **Then** edges sharper than the angle stay sharp and the
   rest are smooth.
4. **Given** the same description twice, **When** both are built, **Then** the meshes are identical, byte for byte.

---

### User Story 2 - Refuse a bad mesh before it is drawn (Priority: P1)

The engineer or the verification runner validates any mesh (built, hand-indexed or loaded from a level) and gets a
precise report of every problem, so that holes, inverted faces, broken indices and non-finite values never reach the
screen.

**Why this priority**: content of 75 games is generated; validation is how it is certified.

**Independent Test**: validate meshes with one planted defect each and check the reported problem and its location.

**Acceptance Scenarios**:

1. **Given** a mesh with an index out of range, a degenerate triangle, a non-finite position, a non-unit normal, a hole,
   a non-manifold edge or an inverted face, **When** it is validated, **Then** each defect is reported with its kind and
   the triangle or vertex it concerns, and the mesh is judged invalid.
2. **Given** a valid closed mesh, **When** it is validated, **Then** no problem is reported and its summary (vertices,
   triangles, boundary edges, closed or open, bounds) is returned.
3. **Given** a mesh above the size budget, **When** it is built or validated, **Then** it is refused with a budget
   problem rather than built partially.

---

### User Story 3 - Know where a mesh is (Priority: P2)

The engineer gets a mesh's bounds (an axis-aligned box and an enclosing sphere) to place the camera, cull, and pick.

**Independent Test**: compare bounds of known shapes with their exact extents.

**Acceptance Scenarios**:

1. **Given** any mesh, **When** bounds are requested, **Then** every vertex lies inside the box and the sphere, and the
   box is tight (each face touches a vertex).
2. **Given** an empty mesh, **When** bounds are requested, **Then** an explicit "empty" result is returned, never a
   box of infinities.

---

### User Story 4 - Existing meshes keep working (Priority: P3)

Scenes that already use the plane, cube and sphere and the renderer that draws them are unchanged.

**Independent Test**: the existing mesh and renderer tests and the reference regression.

**Acceptance Scenarios**:

1. **Given** the existing generators, **When** they run, **Then** their outputs are unchanged and they pass the new
   validator.

### Edge Cases

- **Zero-length tube segment or repeated path point:** skipped deterministically; a path with fewer than two distinct
  points is refused.
- **Profile touching the axis of revolution:** the touching ring collapses to one pole vertex (no degenerate
  triangles).
- **Bevel larger than half the smallest box side:** clamped to half the side.
- **Resolution outside the allowed range:** clamped to the range, as the existing generators do.
- **Welding tolerance:** vertices within the tolerance merge only when their normals and texture coordinates also
  match (or when welding positions only is requested).
- **Very large or very small coordinates:** non-finite results are refused; finite results are kept.
- **Empty mesh:** valid, with empty bounds; drawing it draws nothing.
- **Schema migration:** not applicable — meshes are rebuilt from their descriptions and never stored.
- **Cancellation:** not applicable — building is synchronous and bounded by the budget.

## Requirements *(mandatory)*

### Functional Requirements

**Indexed vertices (story 1)**
- **FR-R02F05-001**: The framework MUST provide a builder that collects vertices and triangles and merges equal
  vertices (position, normal and texture coordinate within a tolerance) into one index, deterministically.
- **FR-R02F05-002**: The builder MUST produce the framework's existing mesh type; no second mesh type is introduced.

**Shapes (story 1)**
- **FR-R02F05-010**: The framework MUST build a parametric surface over a grid of (u, v) samples, open or closed in
  either direction.
- **FR-R02F05-011**: The framework MUST build a solid of revolution from a 2D profile, with poles where the profile
  touches the axis.
- **FR-R02F05-012**: The framework MUST build an extrusion of a closed 2D outline with optional caps.
- **FR-R02F05-013**: The framework MUST build a tube of a given radius along a 3D path, with a twist-free frame along
  the path, optional caps, and an option for a closed loop.
- **FR-R02F05-014**: The framework MUST build a box with bevelled edges of a given radius and segment count.
- **FR-R02F05-015**: Every shape MUST wind its triangles counter-clockwise seen from outside and give unit normals and
  texture coordinates in 0…1.

**Normals (story 1)**
- **FR-R02F05-020**: The framework MUST generate normals from triangles, area- and angle-weighted, with a crease angle
  above which a vertex is split so the edge stays sharp.
- **FR-R02F05-021**: The framework MUST also offer flat normals (one per face).

**Validation (story 2)**
- **FR-R02F05-030**: A validator MUST report: index out of range; index count not a multiple of three; degenerate
  triangle (zero area); non-finite position, normal or texture coordinate; normal not of unit length; texture
  coordinate outside 0…1; array lengths that differ; non-manifold edge (shared by more than two triangles);
  inconsistent winding across an edge; boundary edges (a hole) when the mesh is required to be closed; and, for a
  closed mesh, faces pointing inward (negative enclosed volume).
- **FR-R02F05-031**: Each problem MUST name its kind and the triangle, edge or vertex it concerns; the report MUST list
  every problem up to a limit and count the rest.
- **FR-R02F05-032**: The validator MUST return a summary: vertex, triangle and boundary-edge counts, closed or open,
  bounds and enclosed volume (closed meshes).

**Bounds (story 3)**
- **FR-R02F05-040**: The framework MUST compute a tight axis-aligned box and an enclosing sphere, and an explicit empty
  result for an empty mesh.

**Budgets and determinism**
- **FR-R02F05-050**: Building and validation MUST refuse inputs whose result would exceed a vertex or index budget
  (defaults stated in the plan), with a budget problem and no partial mesh.
- **FR-R02F05-051**: The same description MUST give the same mesh, byte for byte, on every run and runtime; a mesh MUST
  have a stable content digest.
- **FR-R02F05-052**: Building and validation MUST be pure CPU work with no GPU or clock dependence.

**Compatibility (story 4)**
- **FR-R02F05-060**: The existing plane, cube and sphere MUST keep their outputs and pass the validator; the existing
  renderer MUST keep working; the public API changes only by additions (API baseline updated).
- **FR-R02F05-061**: The ProjectM reference regression MUST pass 7 of 7 and the reference stays clean.

**Observability, accessibility, originality**
- **FR-R02F05-070**: The validation report MUST be readable as text and as structured data, so the verification runner
  can record it.
- **FR-R02F05-071**: No asset files: every mesh is built from code; nothing is imported, purchased or generated by a
  model.
- **FR-R02F05-072**: Accessibility: this feature adds no interface; experiences that draw these meshes keep their own
  accessible descriptions.

### Key Entities

- **Mesh** (existing): positions, normals, texture coordinates, triangle indices.
- **Mesh builder**: collects vertices and triangles; welds equal vertices.
- **Shape description**: surface, revolution, extrusion, tube, bevelled box, with resolution parameters.
- **Validation report**: problems (kind, location), summary, counts beyond the limit.
- **Bounds**: box and sphere, or empty.
- **Budget**: maximum vertices and indices.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F05-001**: Every shape at 3 resolutions passes the validator with 0 problems; closed shapes report 0 boundary
  edges and a positive volume within 1% of the analytic volume (sphere, box, cylinder).
- **SC-R02F05-002**: Each of the 12 planted defect kinds is reported with the right kind and location in 12 of 12 cases.
- **SC-R02F05-003**: The same description built twice gives equal digests in 100% of checks; the digests of a fixed set
  of descriptions equal committed values on both simulator runtimes.
- **SC-R02F05-004**: Bounds contain 100% of vertices and each box face touches a vertex.
- **SC-R02F05-005**: The existing plane, cube and sphere outputs are unchanged and valid; the existing mesh and
  renderer tests and the reference regression pass.
- **SC-R02F05-006**: A mesh at the budget builds and validates in under 1 second on the host; every new test finishes in
  under 10 seconds.

## Assumptions

- Meshes are triangle lists with 32-bit indices, as today.
- Texture coordinates follow the existing convention (0…1).
- Rendering stays with the existing renderer and the pipeline of R02-F04; this feature does not add draw paths.

## Excluded scope

- Importing or exporting mesh files; level-of-detail chains; boolean (CSG) operations; mesh simplification;
  skinning and animation; GPU-side generation.

## Traceability

| Source (round2.md R2-F05) | Requirement |
|---|---|
| indexed vertices | FR-R02F05-001, 002 |
| surfaces | FR-R02F05-010, 011, 012 |
| bevels | FR-R02F05-014 |
| tubes | FR-R02F05-013 |
| manifold validation | FR-R02F05-030–032 |
| normals | FR-R02F05-020, 021 |
| bounds | FR-R02F05-040 |
| deterministic tests, error handling | FR-R02F05-050–052 |
| observability | FR-R02F05-070 |
| accessibility, originality, excluded scope | FR-R02F05-071, 072, Excluded scope |
| schema migration | Edge Cases (not applicable: meshes are not stored) |
