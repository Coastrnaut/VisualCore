# Feature Specification: R02-F18 — Procedural terrain mesh and skydome

**Feature Branch**: `218-procedural-terrain-mesh-and-skydome` (spec directory only; work on `main`)

**Created**: 2026-11-19

**Status**: Clarified

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

## Clarifications

### Session 2026-11-19

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-19): `HeightField` (VisualCoreScenes) samples `height(x, z)` at x = originX + i · cellSize
(columns and rows 1 … 512, one extra ring), gives normals by central differences and builds a mesh with y up; `MeshBuilder`
and `MeshBudget.default` (262,144 vertices) are in VisualCoreScenes; `Mat4` and `Vec3` are in VisualCoreMath;
`FullScreenShaderScene`, `ShaderBundle` and the `vc/*.glsl` includes (each compiled alone by ShaderBundleTests) are in
VisualCoreRendering; `PlanarShadowRenderer` is the pattern for a state-restoring renderer; the names `TerrainLOD`,
`TerrainPiece`, `TerrainSettings`, `TerrainError`, `ErosionMask`, `SkyModel`, `SkyParameters`, `SkyError` and
`SkyRenderer` are free.

- Q: Where do the parts live and how is the terrain divided? → A: terrain selection, piece meshes, masks, sky reference
  and settings in VisualCoreScenes; `vc/sky.glsl` and `SkyRenderer` in VisualCoreRendering. The terrain is a square of
  P × P pieces (P 1 … 64), each of C × C base cells (C a power of two, 4 … 128) of size s (finite, > 0); a piece at
  level ℓ (0 … L − 1, L 1 … log₂C) samples every 2^ℓ base cells through `HeightField` (cell size s · 2^ℓ, so its even
  points fall on the same coordinates as the finer level's, bit for bit). Its level is
  clamp(⌊log₂(max(d, 1e-9) / D)⌋ + 1, 0, L − 1) for d < D giving 0, d the horizontal distance from the viewpoint to the
  piece's square and D the distance per level (finite, > 0); then levels are lowered (refined) until neighbours differ by
  at most one, visiting pieces row by row until nothing changes. Impact: FR-R02F18-001, 003; SC-R02F18-001.
- Q: How are cracks avoided and the budget kept? → A: on each edge facing a neighbour one level coarser, every odd point
  of the finer piece takes the height (h_left + h_right) / 2 of its two even neighbours along that edge, which is the
  point of the coarser piece's straight edge; even points coincide exactly. The total vertex count Σ (C / 2^ℓ + 1)² must
  not exceed the vertex budget (1 … 4,194,304, default 262,144): when it does, the distance per level is shrunk to D · 2^(−t/4) for
  t = 1, 2, … and the first balanced selection that fits is used (implementation, 2026-11-19: coarsening the farthest
  coarsenable piece first left farther pieces finer than nearer ones); a budget the all-coarsest tiling still exceeds
  is refused. Every coordinate is (global grid index) · s, so shared points are bit-identical for any s. Impact: FR-R02F18-002; SC-R02F18-001, 002.
- Q: How are the erosion masks defined? → A: on the grid points of a `HeightField`: steepness = |∇h| / √(1 + |∇h|²)
  from central differences (the field's own normal), in 0 … 1; flow = log(1 + a) / log(1 + N) with a the D8 flow
  accumulation (each point passes 1 + its inflow to the neighbour of steepest descent, drop over distance, ties in the
  order N, NE, E, SE, S, SW, W, NW; points visited from highest to lowest, ties by index; a point with no lower
  neighbour keeps its flow), N the number of points; wear = steepness · flow. Returned as a three-channel `FieldGrid`.
  Impact: FR-R02F18-004; SC-R02F18-003: a flat field gives steepness 0 everywhere, a tilted plane gives the same
  steepness everywhere and flow growing downhill, a V-shaped valley gathers its greatest flow on its floor.
- Q: What is the sky formula? → A: with d the unit view direction, s the unit sun direction and e = d.y: the day colour is
  mix(horizon, zenith, √max(e, 0)) above the horizon and mix(horizon, ground, smoothstep(0, 0.1, −e)) below it; a dusk
  tint adds dusk · w · max(d·s, 0)⁴ · (1 − max(e, 0)) with w = clamp(1 − |s.y| / 0.25, 0, 1); the day factor
  f = smoothstep(−0.15, 0.05, s.y) scales the colour by mix(night, 1, f); the sun adds sunColour · f ·
  (smoothstep(cos(r + 0.004), cos r, d·s) + g · max(d·s, 0)^k) for e ≥ −r, r the disc's angular radius, g and k the glow
  strength and exponent; the result is clamped to 0 … 1 (linear). `vc/sky.glsl` (`vc_sky`) and `SkyModel` compute the
  same expression in the same order. `SkyRenderer` draws one full-screen triangle at the far plane (depth test LEQUAL,
  no depth write), finding d from the inverse view-projection, and restores what it changes. Impact: FR-R02F18-005, 006;
  SC-R02F18-004.
- Q: What is stored, and what are the failure codes? → A: `TerrainSettings` and `SkyParameters` are each `Codable` JSON
  schema 1 with sorted keys; schema 1 is the first stored form, a newer schema is refused. Reason codes: `TerrainError`
  `r2-f18.terrain-size`, `r2-f18.piece-size`, `r2-f18.level-count`, `r2-f18.level-distance`, `r2-f18.budget`,
  `r2-f18.viewpoint`, `r2-f18.newer-schema`, `r2-f18.malformed`; `SkyError` `r2-f18.sky-parameter`, `r2-f18.direction`,
  `r2-f18.newer-schema`, `r2-f18.malformed`; the experience adds its id, seed and tick. Impact: FR-R02F18-007, 008;
  SC-R02F18-005.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A large landscape in pieces, fine near and coarse far (Priority: P1) 🎯

The engineer describes a terrain by a height function over a large square and a viewpoint, and receives pieces of
ground whose detail falls with distance, within a vertex budget, with no gaps or cracks where pieces of different detail
meet.

**Why this priority**: every consumer draws a landscape larger than one mesh can hold.

**Independent Test**: for seeded viewpoints, neighbouring pieces differ by at most one level, every shared edge has
identical vertex positions on both sides, and the total stays within budget.

**Acceptance Scenarios**:

1. **Given** a viewpoint, **When** pieces are chosen, **Then** nearer pieces are at least as detailed as farther ones,
   except where a farther piece is refined to stay within one level of a finer neighbour.
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
  with distance except where the one-level rule refines a farther piece below its own distance level (with the default
  budget, never at all), the total vertex count stays within budget, and two selections are identical.
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
