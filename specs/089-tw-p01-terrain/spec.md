# Feature Specification: Tiny Worlds — Phase 01 Procedural seed and mesh fixtures

**Feature Branch**: `089-tw-p01-terrain` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A12-P01 (legacy ledger) · ID namespace FR-A12-1##, SC-A12-1##, T-A12-1##

**Input**: User description: archived manual `apps/12-tiny-worlds.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — three small world presets: island, asteroid garden and miniature city;
  regression fixture — the same seed and settings yield identical mesh hashes in the reference generator; graphics
  context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/tiny-worlds/visualcore-contract.json`): G-TERRAIN (generic seeded noise
  and a height-field terrain mesh with a height sampler and normals computed from the field, in VisualCore's scenes
  module) and G-CONTENTLICENSES (the experience's content records with author and license and an audit). The preset
  slice here is the three terrains with their palettes; props, light adjustment, saved worlds, the full environment
  packs and the detail tier stay for A12-P02…P05 (G-CAMERA, G-MATERIALS, G-PICKING, G-PROPS, G-LIGHT, G-WORLDDOC,
  G-PACKS, G-DETAIL).
- **Experience:** created in `Packages/ExperiencesCreative/TinyWorlds`, registered as a candidate with its scenario
  manifest; the slice draws a real lit terrain of the chosen preset that a person can orbit — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; the reference
  regression for the VisualCore change runs at X-A12 (owner ruling 2026-11-14); every Spec Kit step runs.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a tiny island and look around (Priority: P1) 🎯

A person opens Tiny Worlds and sees a small lit island terrain — a rounded landmass rising from a flat sea level — and
turns and tilts the view around it with the native controls (and later gestures) within comfortable limits.

**Why this priority**: the manual's first journey ("open a tiny island") and the smallest slice that proves the
procedural world reaches the screen through the one host.

**Independent Test**: open the experience on the simulator; a non-blank frame shows the terrain; turning the view
changes the frame and never the world.

**Acceptance Scenarios**:

1. **Given** a fresh session, **When** the experience opens, **Then** the island preset of the default seed is drawn
   lit, and the spoken description names the world, its seed and the view.
2. **Given** the island, **When** the view is turned or tilted, **Then** the frame changes, the camera stays within its
   limits (never below the ground plane, never inside the world's bounds) and the world's digest does not change.

---

### User Story 2 - The same seed always builds the same world (Priority: P1)

The engineer and the owner can trust that a world is reproducible: the same preset, seed and settings give a
byte-identical terrain mesh (by digest) on every run and every device, and different seeds give different worlds.

**Why this priority**: the manual's regression fixture for this phase; saved worlds (A12-P03) depend on it.

**Independent Test**: generate each preset for fixed seeds and compare digests with committed fixtures.

**Acceptance Scenarios**:

1. **Given** each of the three presets and three fixed seeds, **When** the terrain is generated twice, **Then** the
   digests are identical and equal the committed fixtures.
2. **Given** two different seeds, **When** generated, **Then** the digests differ.
3. **Given** two adjacent pieces of one height field, **When** their shared edge is compared, **Then** heights and
   normals match exactly (no seam).

---

### User Story 3 - Three distinct small worlds (Priority: P2)

A person switches between the island, the asteroid garden (a cratered rocky disc with scattered boulder mounds over a
dark void) and the miniature city (a flat terraced plateau of block-like rises) and sees three clearly different
worlds, each in its own procedural palette.

**Independent Test**: choose each preset; each draws, each has its own digest, palette and description.

**Acceptance Scenarios**:

1. **Given** the preset control, **When** a preset is chosen, **Then** its world is generated from the current seed
   and drawn; the choice and the seed are restored after a save and restore.
2. **Given** "new seed", **When** chosen, **Then** a new seed from the session's generator is used and the world
   changes; a refused or invalid choice changes nothing.

---

### User Story 4 - Every bundled content records its origin (Priority: P2)

The owner can see that every bundled preset and palette is original content with an author and a license, in a
generated document that a test keeps equal to the catalog.

**Independent Test**: run the license audit; read the generated document.

**Acceptance Scenarios**:

1. **Given** the catalog, **When** it is audited, **Then** every preset and palette has author and license and 0
   problems are reported; a record without a license or with an unsupported one is refused with a reason.
2. **Given** the generated license document, **When** the test compares it with the catalog, **Then** they match.

### Edge Cases

- **Non-finite or out-of-range settings** (seed text, size, resolution, height scale, octaves): refused with a reason;
  the previous world stays.
- **A resolution beyond the mesh budget:** refused before generation, never a partial mesh.
- **Seams:** adjacent pieces of one field share exact edge heights and normals; one field never depends on the draw
  order.
- **Floating-point differences between devices:** generation uses only operations whose results are the same on every
  supported device (integer hashing and ordinary arithmetic, no platform-varying functions), so the digest fixtures hold
  everywhere.
- **Camera near the ground or very far:** clamped by the existing orbit bounds; the world's own clearance above its
  terrain is A12-P02 (G-CAMERA); here the limits keep the eye above the highest point of the world.
- **Context loss or backgrounding:** the drawn meshes are rebuilt from the world state; backgrounding pauses ambient
  animation (there is none in this slice).
- **Damaged or newer saved state:** refused; a new default world opens.
- **Reduce Motion:** no decorative motion exists in this slice; the camera moves only on request.

## Requirements *(mandatory)*

### Functional Requirements

**Generic terrain in VisualCore (G-TERRAIN, story 2)**

- **FR-A12-101**: VisualCore's scenes module MUST offer seeded two-dimensional noise (a deterministic function of seed
  and position) with fractal sums (octaves, lacunarity, gain), whose output range is stated and whose values are the
  same on every supported device.
- **FR-A12-102**: VisualCore MUST offer a height field over a bounded grid (columns, rows, cell size) with a height
  sampler between grid points, normals computed from the field itself, and a mesh built from it within the mesh budget,
  such that adjacent pieces share exact edge heights and normals.
- **FR-A12-103**: The new generic code MUST be documented, covered by host tests and recorded in the API baseline and
  the VisualCore README; existing meshes and digests MUST NOT change.

**The world core (stories 1–3)**

- **FR-A12-110**: The experience MUST define three presets — island, asteroid garden, miniature city — each a terrain
  recipe (size, resolution, height scale, noise settings and a shaping rule) with a palette.
- **FR-A12-111**: A world (preset, seed, schema version) MUST generate its terrain deterministically; invalid settings
  MUST be refused with a reason and change nothing.
- **FR-A12-112**: Committed digest fixtures MUST pin each preset's terrain for at least three seeds.
- **FR-A12-113**: Content records (presets, palettes) MUST carry author and license; an audit MUST refuse missing or
  unsupported licenses with reasons and a generated document MUST match the catalog (G-CONTENTLICENSES).

**The experience (stories 1 and 3)**

- **FR-A12-120**: The experience MUST draw the current world lit, with depth, through the one host's drawing path and an
  orbit camera within limits, and rebuild its GPU objects after context loss; drawing MUST NOT change the world.
- **FR-A12-121**: Native controls MUST choose the preset, make a new seed, turn and tilt the view and reset it, each
  with a VoiceOver label and value; the canvas MUST have a spoken description (world, seed, view).
- **FR-A12-122**: The experience MUST be registered as a candidate with a scenario manifest (standard scenarios and
  fixtures), saved and restored through its state schema 1, with damaged or newer payloads refused.

### Key Entities

- **World**: preset, seed, schema version; generates the terrain.
- **Preset**: id, name, terrain recipe, palette, author, license.
- **Height field**: columns, rows, cell size, heights; sampler, normals, mesh.
- **View**: yaw, pitch, distance within limits.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A12-101**: 100 % of the 9 fixture worlds (3 presets × 3 seeds) reproduce their committed digests; 0 of 9
  seed pairs per preset collide.
- **SC-A12-102**: Shared edges of adjacent field pieces match exactly in height and normal (0 mismatches over the
  tested edges).
- **SC-A12-103**: Every preset draws a non-blank lit frame on the iOS 27 simulator; turning the view changes the frame
  and leaves the world digest unchanged.
- **SC-A12-104**: The license audit reports 0 problems for the bundled content and the generated document matches.
- **SC-A12-105**: Every preset stays within the mesh budget (vertex and index caps) at its resolution.
- **SC-A12-106**: The runner's nine standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- VisualCore's orbit camera with its bounds, mesh builder, normals, validation, digest, renderer with one directional
  light and fog, the depth pass, the experience host and storage are reused (A12-P00 contract).
- One light direction and one colour per draw are enough for this slice; per-vertex colour (G-MATERIALS) comes in
  A12-P02, so a world is drawn as a few coloured bands or parts (for example land and sea) rather than one painted mesh.
- Snapshot schema 1 holds the world (preset, seed), the view and the generator state; saved worlds are A12-P03.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 MVP: three small presets | FR-A12-110, US3 |
| Regression fixture: same seed → identical mesh hashes | FR-A12-101, 102, 111, 112, US2 |
| EGL/context ownership in the VisualCore host | FR-A12-120 |
| Brainstorm: 3D scenes, camera and navigation, procedural meshes, lighting | FR-A12-102, 120, 121 |
| Manual algorithm decisions 1–2 (reproducible seeds, edge-consistent normals; bounded geometry at load time) | FR-A12-101–103, 111 |
| Contract gaps G-TERRAIN, G-CONTENTLICENSES | FR-A12-101–103, 113 |

## Negative Requirements

- No models, textures or artwork; no network; no second renderer or EGL path; no generation in shaders or per frame; no
  infinite terrain or streaming; no props, saved worlds or packs beyond the three terrains in this phase.
