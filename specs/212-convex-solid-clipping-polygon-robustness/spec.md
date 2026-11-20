# Feature Specification: R02-F12 — Convex solid clipping & polygon robustness

**Feature Branch**: `212-convex-solid-clipping-polygon-robustness` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

**Ledger gate**: R02-F12 (migration ledger, shared round feature) · ID namespace FR-R02F12-###, SC-R02F12-###, T-R02F12-###

**Input**: User description: the archived R02-F12 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"half-space mesh intersection; stable epsilon; face winding; volume ledger; degenerate removal", with the canonical
overrides of ADR-0009 and Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/212-convex-solid-clipping-polygon-robustness`; FR-R02F12-###, SC-R02F12-###,
  T-R02F12-###.
- **Section 13 disposition: new (on existing modules).** The framework builds and validates triangle meshes (R02-F05:
  welding builder, closedness and winding checks, signed volume, degenerate-triangle detection) and clips 2D contact
  segments privately; it has no 3D convex solid, no cut of a solid by a plane, no record of the volume a cut removes and
  no public polygon cleanup. This feature adds a convex solid that can be cut by planes into exact convex parts, with
  outward winding, a size-relative tolerance, removal of slivers and repeated points, and a volume ledger whose sums
  always balance; it reuses the mesh type and its validation for output and checking. Section 13's proposed module
  `VisualCoreGeometry` is not created (as R02-F05, F08 and F11).
- **Who the users are:** the player of Faceted Forge, Crystal Quarry or Amethyst Escape who cuts gems, stone or crystal
  and expects every cut to be clean, the pieces to be whole and the amount removed to add up; the engineer, who cuts the
  same solid on every device and gets the same result.
- **Prerequisites:** R02-F05 (procedural meshes and validation) is pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** cut time of the largest solid on D1–D3, recorded in the device
  campaign. **Owner-only items:** none.

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `Mesh` (positions, normals, uvs, indices; CCW from outside), `MeshBuilder`
(weld tolerance 1e-9 relative), `Mesh.validate(requireClosed:)` (closedness, winding, `invertedFaces`, signed volume
Σ p0·(p1×p2)/6), degenerate triangles at area ≤ 1e-12 × squared diagonal, all in VisualCoreScenes; no 3D clipping,
hull or public signed volume exists; the names `ConvexSolid`, `ClipPlane`, `ConvexCutResult`, `VolumeLedger`,
`PolygonCleanup`, `ConvexSolidError` are unused.

- Q: Where does the library live and how is a solid represented? → A: in VisualCoreScenes beside the meshes, as
  `ConvexSolid`: vertices (`[Vec3]`) and faces (`[[Int]]`, each a convex polygon wound counter-clockwise seen from
  outside, with its outward unit plane). Rationale: the R02-F05/F08/F11 precedent; faces as polygons keep caps and cuts
  exact without triangle bookkeeping. Impact: FR-R02F12-001, 002, 008.
- Q: How is a solid made, given that a general point hull is costly? → A: from a box (`box(min:max:)`), from a closed
  convex mesh (accepted when every vertex lies on or below every face plane within the tolerance), or from a set of
  planes bounded by a box (the box cut by each plane in turn). Building from an arbitrary point cloud is not in this
  slice. Rationale: the three games start from blocks and facet them; half-space intersection is what they do.
  Impact: FR-R02F12-001 (reworded below); excluded scope.
- Q: What is the tolerance and how are degenerate pieces removed? → A: ε = 1e-9 × L, where L is the solid's bounding-box
  diagonal; a vertex with |n·p − h| ≤ ε is on the plane; vertices closer than ε are merged; a corner within ε of the line
  through its neighbours is collinear and removed; a face with fewer than three corners or area ≤ 1e-12 × L² is
  dropped; a side whose every vertex is within ε of the plane is empty. Rationale: the same relative scale as the mesh
  validation (1e-9, 1e-12), so a 1e-3 and a 1e3 solid behave alike. Impact: FR-R02F12-003, 004; SC-R02F12-003, 004.
- Q: What are the limits and the ledger's shape? → A: a solid has at most 4,096 vertices, 1,024 faces and 256 corners per
  face; a cut whose result would exceed them is refused (`tooComplex`). `VolumeLedger` holds the original volume and one
  entry per cut (the cut plane, removed volume, remaining volume), at most 65,536 entries; volumes come from the
  divergence theorem over the faces. The balance |original − remaining − Σ removed| ≤ 1e-9 × original is checked after
  every cut. Impact: FR-R02F12-005; SC-R02F12-002.
- Q: What are the stored form and the failure reports? → A: JSON `{"schema":1,"solid":{"vertices":[…],"faces":[…]},
  "ledger":{…}}`; decoding re-validates; a newer schema or malformed data is refused. `ConvexSolidError` reason codes:
  `r2-f12.non-finite`, `r2-f12.zero-normal`, `r2-f12.empty`, `r2-f12.not-closed`, `r2-f12.not-convex`,
  `r2-f12.too-complex`, `r2-f12.degenerate-polygon`, `r2-f12.newer-schema`, `r2-f12.malformed`; the consuming
  experience adds its id, seed and tick. Conversion to `Mesh` fans each face into triangles with flat normals and passes
  `validate(requireClosed: true)`. Impact: FR-R02F12-006, 007, 008, 010; SC-R02F12-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cut a solid by a plane (Priority: P1) 🎯

The engineer cuts a convex solid by a plane. The result is the kept part (below the plane), the removed part (above),
the new cap face where they meet, and each part's volume. Both parts are closed, convex and wound outward.

**Why this priority**: every cut in the three games is this operation.

**Independent Test**: a unit cube cut through its middle gives two halves of volume 0.5 with a square cap; a cut that
misses keeps the solid unchanged; a cut that takes everything leaves nothing.

**Acceptance Scenarios**:

1. **Given** a cube and a plane through its centre, **When** it is cut, **Then** both parts have half the volume within
   1e-12 relative, both are closed and wound outward, and the cap is a square of the cube's cross-section.
2. **Given** a plane that does not meet the solid, **When** it is cut, **Then** the solid is kept whole (or removed
   whole) and no empty or degenerate face appears.
3. **Given** a plane through a vertex, an edge or a face of the solid, **When** it is cut, **Then** no sliver face,
   repeated point or zero-area face is produced.

### User Story 2 - The volume always adds up (Priority: P1)

A sequence of cuts records, for each cut, the volume removed and the volume remaining. The original volume always equals
the remaining volume plus everything removed.

**Independent Test**: 1,000 seeded cuts of a solid keep the balance within 1e-9 relative; replaying the same
cuts gives the same record.

**Acceptance Scenarios**:

1. **Given** any sequence of cuts, **When** the ledger is read, **Then** original = remaining + Σ removed within 1e-9
   relative after every cut.
2. **Given** the same solid and cuts twice, **When** both ledgers are compared, **Then** they are identical.

### User Story 3 - Clean polygons (Priority: P2)

The engineer cleans a polygon in 3D (from a cap or a face) before using it: repeated and collinear points are removed,
its winding is made to agree with a given normal, and a polygon that has collapsed is reported.

**Independent Test**: a polygon with repeated, collinear and nearly collinear points is reduced to its corners; a
reversed polygon is reversed back; a polygon of fewer than three distinct corners is reported as degenerate.

### User Story 4 - Store and draw the result (Priority: P2)

A cut solid is stored with a level and restored later, and drawn through the existing mesh path.

**Independent Test**: a solid round-trips through its stored form; the mesh made from a solid validates as closed with
positive volume equal to the solid's volume; a newer stored version is refused.

### Edge Cases

- **A plane with a zero or non-finite normal, or a non-finite offset:** refused with a named reason.
- **A solid that is not convex, not closed or empty:** refused when made.
- **A vertex within the tolerance of the plane:** treated as on the plane, never as a tiny piece on either side.
- **Very large and very small solids:** the tolerance scales with the solid's size, so a 1e-3 and a 1e3 cube behave
  alike.
- **A cut that leaves a part thinner than the tolerance:** that part is reported as empty, never as a sliver.
- **A ledger past 65,536 entries:** the next cut is refused (`tooComplex`) and the ledger is unchanged.
- **Many cuts in a row:** the solid stays convex and valid; face and vertex counts stay within 4,096 vertices, 1,024 faces and
  256 corners per face.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F12-001**: A convex solid MUST be made from a box, from a set of planes bounded by a box, or from a
  closed convex mesh, and MUST be refused with a named reason when it is empty, not closed, not convex or not finite.
- **FR-R02F12-002**: Cutting by a plane MUST give the kept part, the removed part, the cap polygon and both volumes, each
  part closed, convex, with every face wound outward, and MUST be exact up to the tolerance ε.
- **FR-R02F12-003**: The tolerance MUST be ε = 1e-9 × the solid's bounding-box diagonal; vertices within it of the plane MUST be treated as on
  the plane, and parts thinner than it MUST be reported as empty.
- **FR-R02F12-004**: No result MUST contain a face with fewer than three distinct corners, a repeated point, collinear
  corners or an area ≤ 1e-12 × the squared diagonal.
- **FR-R02F12-005**: A volume ledger MUST record each cut's removed and remaining volume and keep original = remaining +
  Σ removed within 1e-9 relative at every step.
- **FR-R02F12-006**: Polygon cleanup MUST remove repeated and collinear points, orient the polygon to a given normal, and
  report a collapsed polygon.
- **FR-R02F12-007**: A solid and its ledger MUST have a versioned stored form that round-trips exactly; a newer version or
  malformed data MUST be refused with a named reason.
- **FR-R02F12-008**: A solid MUST convert to a triangle mesh that the existing validation reports as closed, consistently
  wound and of positive volume equal to the solid's.
- **FR-R02F12-009**: Results MUST be deterministic: the same solid and cuts give identical results on every run.
- **FR-R02F12-010**: Every refusal MUST carry a stable reason code naming the feature; existing mesh code and its tests
  MUST be unchanged; every new public name carries documentation; the API baseline and reference regression are updated.

### Key Entities

- **Convex solid**: vertices and outward faces (each a convex polygon with a plane), with a size and a tolerance.
- **Cut plane**: unit normal and offset; "kept" is the side below.
- **Cut result**: kept solid (or empty), removed solid (or empty), cap polygon, volumes.
- **Volume ledger**: original volume and one entry per cut (removed, remaining).
- **Clean polygon**: corners in order, normal, or a degenerate report.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F12-001**: A unit cube cut through its centre on each of the three axes and on 100 seeded planes gives parts
  whose volumes sum to the original within 1e-12 relative, each part valid as a closed outward-wound mesh.
- **SC-R02F12-002**: After 1,000 seeded cuts the ledger balances within 1e-9 relative at every step, and two runs give
  identical ledgers and digests.
- **SC-R02F12-003**: Planes through vertices, edges and faces, and planes within the tolerance of them, produce no face
  that fails the degeneracy rules in 100 of 100 fixtures.
- **SC-R02F12-004**: A 1e-3 and a 1e3 cube cut by the same 100 scaled planes give the same face and vertex counts and
  vertices equal after rescaling within 1e-12 relative.
- **SC-R02F12-005**: At least five positive, negative and boundary fixtures for making and storing solids give their
  stated verdicts; a stored solid round-trips byte for byte.
- **SC-R02F12-006**: Existing mesh tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes
  in under 10 seconds.

## Assumptions

- Solids are convex polyhedra in the coordinates of `VisualCoreMath`; non-convex cutting is not in this slice.
- The consumer games do not exist yet; this slice ships the library and its proofs.
- No user interface: layout, Dynamic Type and VoiceOver are carried by the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Half-space mesh intersection | FR-R02F12-001, 002, 008 |
| Stable epsilon | FR-R02F12-003 |
| Face winding | FR-R02F12-002, 006, 008 |
| Volume ledger | FR-R02F12-005 |
| Degenerate removal | FR-R02F12-004, 006 |
| Schema migration | FR-R02F12-007 |
| Determinism and observability | FR-R02F12-009, 010 |

## Negative Requirements / Excluded scope

- No convex hull of an arbitrary point cloud, no non-convex boolean operations, no mesh repair of arbitrary input, no GPU code, no new module, no device run before
  ImplementationLock-100, no analytics.
