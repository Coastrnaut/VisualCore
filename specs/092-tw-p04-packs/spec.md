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
