# Feature Specification: Tiny Worlds — Phase 04 Three environment packs

**Feature Branch**: `092-tw-p04-packs` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P04 (legacy ledger) · ID namespace FR-A12-4##, SC-A12-4##, T-A12-4##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 04 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 04):** MVP — prop placement and scene light adjustment (built in A12-P03, now used by
  each pack's bundled composition); regression fixture — the orbit camera respects its limits and never clips through
  the terrain (now including the pack's props); graphics context ownership stays solely in the VisualCore host.
- **Gap built here** (contract `docs/apps/tiny-worlds/visualcore-contract.json`): G-PACKS — the island, asteroid
  garden and miniature city packs: each a bundled world composition (terrain recipe and seed, a prop set, light and
  camera limits) with author and license. The detail-tier policy stays for A12-P05 (G-DETAIL).
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; every Spec
  Kit step runs; no VisualCore change is planned.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`WorldState` is schema 2 (preset index 0…2, a 32-bit seed, view, props, selection, light; no pack field);
`WorldEditing` validates placements against the terrain (bounds, sea level per preset, 0.6 m spacing, 24-prop cap);
`CameraPolicy` clamps to the global limits (pitch 10°…75°, distance 10…30 m) and keeps the eye 0.5 m above the
highest of 9 terrain samples within 1 m, ignoring props; `ContentCatalog` and `LicenseAudit` hold presets, palettes,
props and prop palettes.

- Q: How does a pack relate to the presets and the saved state? → A: One pack per preset (pack i uses preset i), so
  the state needs no new field and schema 2 stays: `world.pack [0…2]` replaces the world with pack i's composition
  (preset, fixed seed, props in order, no selection, light, the pack's default view) and is replayable; "reset to
  pack" sends `world.pack` with the current preset. Opening is spoken ("Opened the island pack."); under Reduce Motion
  the camera moves directly.
- Q: What does each pack hold? → A: Island — seed 11, 3 trees, 2 rocks, 1 house, 1 lantern, light 120°/45°/0.35,
  pitch 15°…70°, distance 12…28 m, default view 45°, 35°, 18 m; asteroid garden — seed 7, 5 rocks, 3 lanterns, light
  300°/30°/0.25, pitch 20°…75°, distance 12…30 m, default view 135°, 40°, 20 m; miniature city — seed 5, 6 houses, 4
  lanterns, 2 trees, light 210°/60°/0.40, pitch 25°…75°, distance 10…24 m, default view 315°, 45°, 16 m. Prop
  positions and turns are fixed numbers in the pack data, chosen to satisfy the placement rules on that seed's
  terrain and verified at load; author "VisualCore project", license "MIT".
- Q: How do pack camera limits and props enter the camera policy? → A: The camera limits become per preset (the
  pack's range, inside the global one) for every world of that preset, applied after every action and on restore; the
  clearance check takes the highest of the 9 terrain samples and of the top (y + model height) of every prop whose
  centre lies within 1 m plus its picking radius of the eye's ground point, and raises the pitch in 1° steps up to the
  pack's upper pitch.
- Q: Which budgets apply? → A: Per pack at most 16 props, 30,000 vertices in all (terrain, sea and every placed prop's
  mesh counted per placement) and 2 + props draws (terrain, sea, one draw per prop).
- Q: What do the fixtures pin? → A: For each pack the state digest right after `world.pack` from the default state
  (committed), its prop count, and that `world.pack` after edits returns that digest exactly; a deliberately broken
  pack (a prop under water) is refused at load with `a12.under-water` and the world stays.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a finished tiny world (Priority: P1) 🎯

A person picks one of three packs — a tropical island with palms and huts, an asteroid garden with boulders and
lanterns, a miniature city with houses and street lights — and sees a composed little world with its own light, ready
to explore and edit.

**Why this priority**: the manual's first journey ("open a tiny island with animated scenery") and its three-world
feature, as finished compositions rather than bare terrain.

**Independent Test**: open each pack; read its document, digest, prop count, light and camera limits.

**Acceptance Scenarios**:

1. **Given** a pack, **When** opened, **Then** its terrain, props, light and view match the bundled composition and
   its digest equals the committed fixture.
2. **Given** an opened pack that was edited, **When** "reset to pack" is chosen, **Then** the bundled composition
   returns exactly.

---

### User Story 2 - The camera never cuts through a pack (Priority: P1)

The engineer and a person orbiting can trust that in every pack the eye stays within that pack's limits and above the
terrain and props around it at every angle and distance.

**Why this priority**: the manual's regression fixture for this phase.

**Independent Test**: sweep each pack's camera through its whole range; read the eye against terrain and props.

**Acceptance Scenarios**:

1. **Given** each pack, **When** the camera is swept across its yaw, pitch and distance range, **Then** every view
   stays inside the pack's limits and keeps the clearance above terrain and props.

---

### User Story 3 - Every pack is within budget and licensed (Priority: P2)

The owner can see that every pack stays within its vertex, prop and draw budgets and that each pack records its
author and license in the generated license document.

**Independent Test**: count each pack's geometry and draws; run the license audit.

**Acceptance Scenarios**:

1. **Given** each pack, **When** generated, **Then** its vertices, props and draws are within the stated budgets.
2. **Given** the license audit, **When** run, **Then** every pack has author and license and 0 problems.

### Edge Cases

- **A pack whose bundled props break the placement rules** (bad data): the pack is refused at load with a reason; the
  app never shows a pack that breaks its own rules.
- **Opening a pack over an edited world:** replaces it (the edited world can be saved first; a spoken note says so).
- **A pack's camera limits narrower than the global ones:** the pack's limits apply and stay within the global ones.
- **Newer or damaged pack data:** refused by the same document rules as saved worlds.
- **Reduce Motion:** opening a pack moves the camera directly.
- **Saved worlds and restored states from before the per-preset limits:** their view is clamped to the preset's
  limits on restore (the document's props and light are kept); the clamp never changes a prop.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A12-401**: Three packs (island, asteroid garden, miniature city) MUST each define a terrain recipe and seed, a
  prop set, a light and camera limits, with a name, author and license.
- **FR-A12-402**: Opening a pack MUST replace the world with the pack's composition deterministically; "reset to pack"
  MUST restore it exactly; both MUST be replayable and spoken.
- **FR-A12-403**: Every pack's props MUST satisfy the placement rules; a pack that does not MUST be refused at load.
- **FR-A12-404**: Each pack's camera limits MUST lie within the global limits, and the camera policy MUST keep the eye
  above terrain and props for every view within them.
- **FR-A12-405**: Each pack MUST stay within stated vertex, prop and draw budgets.
- **FR-A12-406**: Packs MUST appear in the license audit and the generated license document.
- **FR-A12-407**: Committed fixtures MUST pin each pack's composition digest.

### Key Entities

- **Pack**: id, name, preset, seed, props, light, camera limits, author, license.
- **Camera limits**: pitch range, distance range (within the global ones).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-401**: 3 of 3 packs open with their committed digests; reset restores them exactly.
- **SC-A12-402**: Over a sweep of at least 24 yaw × 8 pitch × 4 distance views per pack, 100 % stay within the pack's
  limits and keep the clearance above terrain and props.
- **SC-A12-403**: 100 % of pack props satisfy the placement rules; a deliberately broken pack is refused.
- **SC-A12-404**: Every pack stays within its vertex, prop and draw budgets; the license audit reports 0 problems.
- **SC-A12-405**: The runner's nine scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- Terrain, props, light, the world document and the camera policy of A12-P01–P03 are reused unchanged in shape;
  packs are data plus a loader.

## Traceability

| Source | Requirement |
|---|---|
| Phase 04 MVP: prop placement and scene light adjustment (in each pack's composition) | FR-A12-401, 403 |
| Regression fixture: orbit camera respects limits, no clipping through terrain | FR-A12-404, SC-A12-402 |
| EGL/context ownership in the VisualCore host | FR-A12-402 |
| Manual feature 1: three small world presets island, asteroid garden, miniature city | FR-A12-401, 402, 407 |
| Brainstorm: materials and assets (collectible environments) | FR-A12-401, 406 |
| Contract gap G-PACKS | FR-A12-401–407 |

## Negative Requirements

- No downloaded or purchased content; no new prop kinds beyond the four (packs combine them); no animation; no network.
