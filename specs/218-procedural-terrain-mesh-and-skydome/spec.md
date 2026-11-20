# Feature Specification: R02-F18 — Procedural terrain mesh and skydome

**Feature Branch**: `218-procedural-terrain-mesh-and-skydome` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Draft

**Ledger gate**: R02-F18 (migration ledger, shared round feature) · ID namespace FR-R02F18-###, SC-R02F18-###, T-R02F18-###

**Input**: User description: the archived R02-F18 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"heightfield LOD; deterministic erosion masks; raster-free procedural sky", with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 13, 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/218-procedural-terrain-mesh-and-skydome`; FR-R02F18-###, SC-R02F18-###,
  T-R02F18-###.
- **Section 13 disposition: extend.** The framework has `HeightField` (feature 089: heights sampled from a function on a
  grid with an extra ring of samples, normals and an indexed mesh, and the guarantee that two fields sampled from the
  same function agree on a shared edge), `GradientNoise2D` (bit-exact seeded noise), `MeshBuilder` with budgets and
  validation, the mesh renderer and the GLSL include library (`vc/*.glsl`) with GPU-against-CPU tests. It has no levels
  of detail for large terrain, no masks describing where water would wear the terrain, and no sky. This feature adds
  those on top of the existing types, which stay unchanged; TinyWorlds keeps its own terrain generator.
- **Who the users are:** the player of Colorfall Canyons, Erosion Painter or Crystal Quarry, who flies over a large
  landscape under a changing sky and must never see holes between pieces of ground, popping seams or a sky made of
  pictures; the engineer, who needs terrain pieces, masks and sky colours that are exact, bounded and identical on every
  device.
- **Prerequisites:** R02-F05 (meshes) and R02-F07 (post passes) are pass.
- **Superseded parts of the source prompt:** the USD 1.99–4.99 purchase model (ADR-0009); the Round 2 lock
  (ImplementationLock-100). **Device-only items:** the frame cost of a full terrain and sky on D1–D3, recorded in the
  device campaign. **Owner-only items:** none.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A large landscape in pieces, fine near and coarse far (Priority: P1) 🎯

The engineer describes a terrain by a height function over a large square and a viewpoint, and receives pieces of
ground whose detail falls with distance, within a vertex budget, with no gaps or cracks where pieces of different detail
meet.

**Why this priority**: every consumer draws a landscape larger than one mesh can hold.

**Independent Test**: for seeded viewpoints, neighbouring pieces differ by at most one level, every shared edge has
identical vertex positions on both sides, and the total stays within budget.

**Acceptance Scenarios**:

1. **Given** a viewpoint, **When** pieces are chosen, **Then** nearer pieces are at least as detailed as farther ones.
2. **Given** two neighbouring pieces of different detail, **When** their edges are compared, **Then** the coarse edge's
   positions equal the fine edge's positions everywhere along it.
3. **Given** the same inputs, **When** chosen twice, **Then** the pieces and meshes are identical.

### User Story 2 - Masks of where water wears the land (Priority: P2)

The engineer derives, from the terrain alone, masks of steepness, water gathering and wear that colour and texture the
ground the same way on every device.

**Independent Test**: on seeded and hand-made terrains the masks have stated values (a flat field has no steepness, a
valley gathers the flow of its slopes) and are bit-identical between runs.

### User Story 3 - A sky made of light, not pictures (Priority: P1)

The engineer draws a sky whose colours come from a formula of the view direction and the sun's direction: a gradient from
horizon to zenith, a sun disc with a glow, colours shifting at dawn and dusk and darkening at night, drawn without any
image.

**Independent Test**: the drawn sky equals the same formula computed independently on the processor within one or two
colour steps per channel, for many directions and sun positions.

### User Story 4 - Save and reopen sky and terrain settings (Priority: P2)

Terrain and sky settings are saved with a schema version and reopened later; newer and damaged forms are refused.

**Independent Test**: settings round-trip byte for byte; newer and damaged forms are refused.

### Edge Cases

- **A viewpoint far outside the terrain:** pieces are still chosen and coarsest far away.
- **A budget too small for the coarsest tiling:** refused with a named reason.
- **A terrain of one piece:** a single piece at full detail within budget.
- **The sun below the horizon, exactly at the horizon or at the zenith:** finite colours, no disc below the horizon.
- **Flat terrain or a single pit:** masks with stated values (no steepness; flow ending in the pit).
- **Sizes, levels or settings outside their ranges:** refused with a named reason.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02F18-001**: A terrain level-of-detail selector MUST divide a square terrain into pieces and pick a detail level
  for each from its distance to the viewpoint, with neighbours differing by at most one level.
- **FR-R02F18-002**: Each piece MUST become a mesh whose edges facing a coarser neighbour match that neighbour exactly, so
  the landscape has no cracks, within a stated vertex budget.
- **FR-R02F18-003**: Pieces MUST reuse the existing height sampling, so that heights agree with the existing height field
  for the same function.
- **FR-R02F18-004**: Erosion masks MUST be derived deterministically from heights: steepness, gathered flow and wear,
  each in 0 … 1, handed to the existing field grid.
- **FR-R02F18-005**: A procedural sky MUST compute its colour from the view and sun directions and stated settings, both
  as a shader include and as an identical processor reference, with no image.
- **FR-R02F18-006**: A sky renderer MUST draw that sky behind a scene for a given camera on the existing renderer,
  restoring the state it changes and leaving no resources after release.
- **FR-R02F18-007**: Terrain and sky settings MUST have a versioned stored form; newer and damaged forms MUST be refused.
- **FR-R02F18-008**: Invalid requests MUST be refused with a stable reason code naming the feature.
- **FR-R02F18-009**: Existing types, experiences and their tests MUST be unchanged; every new public name carries
  documentation; the API baseline and the reference regression are updated.

### Key Entities

- **Terrain settings**: size, base cell size, piece size, level count, distance per level, vertex budget.
- **Terrain piece**: position, size, level, coarser-neighbour edges, mesh.
- **Erosion masks**: steepness, flow and wear per cell.
- **Sky settings**: colours of zenith, horizon and ground, sun disc size and glow, twilight and night tints.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02F18-001**: For 200 seeded viewpoints, neighbouring pieces differ by at most one level, detail never increases
  with distance, the total vertex count stays within budget, and two selections are identical.
- **SC-R02F18-002**: For every pair of neighbouring pieces in 50 seeded selections, every vertex on the shared edge of the
  finer piece lies exactly (bit for bit) on the coarser piece's edge.
- **SC-R02F18-003**: Masks on stated hand-made terrains have their stated values, and masks of 20 seeded terrains are
  bit-identical across runs.
- **SC-R02F18-004**: The drawn sky equals the processor reference within 2 colour steps per channel over a full grid of
  directions for at least 8 sun positions from below the horizon to the zenith.
- **SC-R02F18-005**: Settings round-trip byte for byte; newer and damaged forms are refused; the renderer leaves no GPU
  object after release and restores the state it changed.
- **SC-R02F18-006**: Existing tests pass unchanged; the reference regression passes 7 of 7; each unit test finishes in
  under 10 seconds.

## Assumptions

- The sky is an artistic analytic model, not a physical atmosphere simulation.
- The consumer games do not exist yet; this slice ships the library, the sky include and renderer, and their proofs.
- No user interface: camera controls, layout and accessibility belong to the consuming experiences.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Heightfield LOD | FR-R02F18-001, 002, 003 |
| Deterministic erosion masks | FR-R02F18-004 |
| Raster-free procedural sky | FR-R02F18-005, 006 |
| Schema migration | FR-R02F18-007 |
| Observability | FR-R02F18-008 |
| No Stage One breakage | FR-R02F18-009 |

## Negative Requirements / Excluded scope

- No new module, no change to `HeightField`, `GradientNoise2D`, the mesh renderer or TinyWorlds, no images or textures
  for the sky, no physical atmosphere, no clouds, no device run before ImplementationLock-100, no analytics.
