# Feature Specification: Tiny Worlds — Phase 03 World customization and persistence

**Feature Branch**: `091-tw-p03-customize` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P03 (legacy ledger) · ID namespace FR-A12-3##, SC-A12-3##, T-A12-3##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — seeded terrain and mesh generation with stable boundaries (built in
  A12-P01, kept as the base every customised world regenerates from); regression fixture — placed props persist at
  exact transforms; graphics context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/tiny-worlds/visualcore-contract.json`): G-PROPS (a procedural prop catalog
  and placement, selection, move and delete as replayable actions), G-LIGHT (the world light: direction from azimuth
  and elevation, ambient level) and G-WORLDDOC (the world document, saved worlds and their thumbnails). The three full
  environment packs stay for A12-P04 (G-PACKS) and the detail-tier policy for A12-P05 (G-DETAIL).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec
  Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
Physics Playground's `ExperimentStore` saves, reads, clears and summarises `experiment-<slot>.json` through
`ExperienceStorage`, whose `write(_:to:)` replaces a file atomically (readers see the old or the new file, never a
part); slot actions reach the presenter as closures, not engine actions; `ExperienceSession.renderStill(width:height:)`
draws a still off screen through the host and `StillImageEncoder` encodes it as PNG; `MeshShapes` offers revolution,
extrusion and bevelled boxes; `MeshRenderer(mesh:colors:registry:)` and `Ray3` exist (A12-P02); `WorldState` is
schema 1 with a `MigrationChain` in `WorldsCore`.

- Q: Which props exist and how are they built? → A: Four props, each one mesh with per-vertex colours from its own
  three-colour palette, at most 2,000 vertices, height ≤ 1.2 m, author "VisualCore project", license "MIT": tree
  (revolved trunk and cone crown), rock (bevelled box), house (box with an extruded gabled roof), lantern (revolved
  post with a sphere lamp). Each has a picking box (its bounds). A prop's transform is position (x, y, z), rotation
  about y (−π…π) and scale (fixed 1 in this phase, stored for the packs).
- Q: Which editing actions and rules apply? → A: `prop.place [kind 0…3, x, z]` (the presenter offers the last picked
  ground point, else the world centre), `prop.select [index, −1 for none]`, `prop.move [dx, dz]` (each −1…1 m),
  `prop.rotate [degrees −180…180]`, `prop.delete` (the selected prop). A placed or moved prop snaps to the terrain
  height at its centre and must be within |x|, |z| ≤ 5.5 m, on ground at least 0.05 m above sea level (island, city)
  or on the disc (asteroid garden: ground ≥ −0.4 m), at least 0.6 m from every other prop's centre, with at most 24
  props. Refusals change nothing: `a12.prop-cap`, `a12.outside`, `a12.under-water`, `a12.too-close`,
  `a12.no-selection`, plus `a12.invalid-choice`. A tap selects the nearest prop whose picking box the ray hits before
  the ground, else picks the ground. Changing the preset or seed clears the props and the selection (spoken).
- Q: How is the light set? → A: Azimuth 0°…360° (wrapped), elevation 10°…85°, ambient 0.1…0.6, default 30°, 50°,
  0.35; direction (cos e · sin a, sin e, cos e · cos a); actions `light.azimuth [degrees]`, `light.elevation
  [degrees]`, `light.ambient [value]`, out-of-range refused; every renderer (terrain, sea, props) uses it.
- Q: What is the world document, and how are worlds saved? → A: `WorldState` schema 2 = schema 1 plus props (in
  placement order) and light; `MigrationChain` 1 → 2 adds no props and the default light; snapshot schema 2. The saved
  file `world-<slot>.json` (slots 0…3) holds the schema-2 document as sorted-key JSON (at most 64 KB) plus the slot
  name ("Island, seed 1"); Swift's shortest round-trip number encoding keeps every transform bit-identical. Save,
  open and clear are slot actions of the presenter through a `WorldStore` over `ExperienceStorage` (as Physics
  Playground); opening restores the document into the engine as one replayable `world.open` state replacement;
  damaged, truncated, oversized or newer files are reported (`damaged`, `newer-version`, `too-large`) and the
  current world stays; a failed write leaves the previous file byte-identical.
- Q: How are thumbnails made? → A: On save, the session draws a still of the world off screen at 160 × 120 pixels,
  encodes it as PNG (at most 64 KB) and writes `world-<slot>.png` after the document; the slot list shows it. If no
  context is available, the world is saved without a picture and the slot says "no picture"; a thumbnail never
  affects the document or its digest.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place props on a tiny world (Priority: P1) 🎯

A person picks a prop — a tree, a rock, a little house or a lantern — and places it on the ground where they point;
it sits on the terrain, can be selected, moved and deleted, and never floats, sinks or leaves the world.

**Why this priority**: the manual's third journey ("place one prop") and its prop placement feature.

**Independent Test**: place, move and delete props by actions; read their positions against the terrain and the
rules.

**Acceptance Scenarios**:

1. **Given** a world, **When** a prop is placed at a point, **Then** it rests on the terrain height there within
   1 mm, inside the world and at least the minimum spacing from every other prop.
2. **Given** the prop cap reached, a point outside the world or too close to another prop, **When** a placement is
   asked, **Then** it is refused with a spoken reason and nothing changes.
3. **Given** a selected prop, **When** it is moved or deleted, **Then** only the document changes and the same
   actions replayed give the same world.

---

### User Story 2 - Change the light (Priority: P2)

A person turns the sun around the world, raises or lowers it and sets how bright the shadows are, and the terrain and
props light accordingly.

**Independent Test**: set the light by actions; read the direction and the drawn brightness of a face.

**Acceptance Scenarios**:

1. **Given** azimuth and elevation, **When** set, **Then** the light direction is the stated unit vector, clamped to
   the ranges.
2. **Given** a face lit head-on and the light moved away, **When** drawn, **Then** the face is darker than before.

---

### User Story 3 - Save and reopen a world (Priority: P1)

A person saves the world they made into one of four slots with a small picture of it, and later reopens it exactly —
same terrain, same props at exactly the same places, same light and view.

**Why this priority**: the manual's third journey ends with "save the world"; and the phase's regression fixture.

**Independent Test**: save, close, reopen; compare documents, digests and the thumbnail.

**Acceptance Scenarios**:

1. **Given** a customised world, **When** saved and reopened, **Then** every prop's transform is bit-identical and the
   world's digest is the same.
2. **Given** a damaged, truncated or newer saved file, **When** opened, **Then** it is reported, never crashes and
   the current world stays.
3. **Given** a write interrupted midway, **When** the slot is read, **Then** the previous file is intact.
4. **Given** a save, **When** the slot list is read, **Then** the slot shows its thumbnail at the capped size.

### Edge Cases

- **A prop on a steep slope or at the shore:** rests at the terrain height under its centre; props below sea level
  are refused (they would be under water).
- **Terrain changes under props** (new seed or preset): the props are cleared, because their places belong to the old
  terrain (stated in the spoken message).
- **Older saved state** (schema 1): restores with no props and the default light.
- **Thumbnail rendering unavailable** (no context): the world is saved without a picture and the slot says so.
- **Non-finite or out-of-range values** in actions or files: refused with a reason.
- **Selection of a deleted prop:** the selection clears.

## Requirements *(mandatory)*

### Functional Requirements

**Props (story 1, G-PROPS)**

- **FR-A12-301**: A licensed catalog of procedural props (tree, rock, house, lantern) MUST build each prop's mesh
  within a budget, drawn in its palette colours.
- **FR-A12-302**: Placement MUST snap a prop to the terrain height, keep it inside the world, above sea level and at
  least a minimum spacing from other props, and refuse beyond a prop cap, each refusal with a reason.
- **FR-A12-303**: Select, move (by small steps) and delete MUST be replayable actions that change only the document;
  a tap MUST select the nearest prop under it (by its picking shape) or pick the ground for the next placement; every
  action MUST have a control alternative.

**Light (story 2, G-LIGHT)**

- **FR-A12-310**: The world light MUST be azimuth, elevation and ambient level within stated ranges, mapped to a unit
  direction for every renderer, stored in the world document.

**World document and saved worlds (story 3, G-WORLDDOC)**

- **FR-A12-320**: The world document MUST hold preset, seed, props (kind, position, rotation, scale), the selection, light and
  view,
  versioned, with older versions migrated and newer or damaged ones refused.
- **FR-A12-321**: Four saved-world slots MUST save and reopen documents with atomic writes, never losing the previous
  file on a failed write, and report damaged files.
- **FR-A12-322**: Each save MUST store a thumbnail drawn off screen at a capped size beside the document, reopened with
  the slot list.
- **FR-A12-323**: Placed props MUST persist at exact transforms (bit-identical after save and reopen).

### Key Entities

- **Prop**: kind, position (x, y, z), rotation about y, scale.
- **World light**: azimuth, elevation, ambient.
- **World document**: preset, seed, props, light, view, schema version.
- **Saved slot**: index, name, document, thumbnail.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-301**: 100 % of placed props rest within 1 mm of the terrain, inside the world and keep the spacing;
  100 % of rule-breaking placements are refused with a reason.
- **SC-A12-302**: 100 % of props reopen bit-identical in position, rotation and scale; reopened worlds have the same
  digest.
- **SC-A12-303**: Damaged, truncated and newer files: 0 crashes, 100 % reported, current world unchanged.
- **SC-A12-304**: Thumbnails are written at most the capped size; an interrupted write leaves the previous file
  byte-identical.
- **SC-A12-305**: Every editing action has a control alternative (0 missing); the runner's nine scenarios pass on iOS
  27; every test runs in under 10 s.

## Assumptions

- Mesh shapes (revolution, extrusion, bevelled box), the colour stream, ray intersection, the height-field sampler,
  experience storage with atomic writes and the session's off-screen still drawing exist and are reused.
- The props of this phase are generic small dioramas; the packs of A12-P04 add more props per world.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 MVP: seeded terrain with stable boundaries (base of every customised world) | FR-A12-320, 323 |
| Regression fixture: placed props persist at exact transforms | FR-A12-323, SC-A12-302 |
| EGL/context ownership in the VisualCore host | FR-A12-301, 322 |
| Manual feature 4: prop placement and scene light adjustment | FR-A12-301–303, 310 |
| Manual feature 5: saved world composition and thumbnails | FR-A12-320–322 |
| Brainstorm: materials and assets, lighting | FR-A12-301, 310 |
| Contract gaps G-PROPS, G-LIGHT, G-WORLDDOC | FR-A12-301–323 |

## Negative Requirements

- No imported models or images; no sharing, export or network; no physics or animation of props; no packs beyond the
  generic props in this phase.
