# Feature Specification: Infinite Geometry — Phase 05 Mesh, cache and quality regression

**Feature Branch**: `044-ig-p05-mesh-cache-quality` (spec directory only; work stays on `main`)

**Created**: 2026-11-13

**Status**: Draft

**Ledger gate**: A05-P05 (legacy ledger) · ID namespace FR-A05-5##, SC-A05-5##, T-A05-5##

**Input**: User description: archived manual `apps/05-infinite-geometry.md` §9 Phase 05 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 05):** MVP — adaptive mesh tessellation and render-quality settings; regression fixture —
  non-square displays keep geometric proportions; graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here in VisualCore** (documentation, public-API baseline, tests, reference regression), from
  `docs/apps/infinite-geometry/visualcore-contract.md`: G-MESHCACHE — a bounded, least-recently-used mesh cache keyed by a
  parameter signature; G-MESHLOD — a tessellation choice driven by the quality tier, monotonic and within the mesh budget.
- **Quality path:** the host's quality governor chooses a tier from the experience's quality profile and gives it to the
  experience; the tier never changes the experience state or its digest (contract of `setQualityTier`).
- **Owner rulings of 2026-11-13:** short tests; device timing and audits wait for the device campaign; parallel agents;
  no wall-clock assertions on CI runners.

## Clarifications

### Session 2026-11-13

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ExperienceCore.setQualityTier(_:)` exists ("must not change the digest"; default does nothing) and the session calls it
through `ExperienceShell.setQualityTier` with the level in force from `QualityGovernor` (pin from the app's
`qualityOverride` preference, so the "render-quality setting" already exists in the app); a core declares
`qualityTiers` and `qualityProfile` (`QualityLevel` with `elementShare`); the solid is built by
`Composition.solid` with a fixed `petalSegments = 24` revolution and the mesh triangle count is proportional to the
segments; `StableHash` exists in VisualCoreMath.

- Q: Where is the tessellation chosen and the drawn mesh built, given the tier must not change the digest? → A: The
  core keeps building its reference composition at full tessellation (24 segments) for its digest and bounds, and stores
  the tier outside the digest and snapshot; the presenter builds the drawn solid through the mesh cache at the tier's
  segment count. The reference mesh's bounding sphere contains every lower-tier mesh (their vertices lie on the same
  surface of revolution), so the Phase 03 camera rule stays valid.
- Q: Which quality levels? → A: Four, from best: "Full" (24 segments, element share 1), "High" (16, ⅔), "Medium" (12, ½),
  "Low" (8, ⅓); resolution share 1 and no effect passes at every level. The cheapest draws a third of the best's
  triangles (≤ 50% required).
- Q: What does the framework tessellation choice compute? → A: From a full segment count, a minimum and a tier's element
  share: segments = max(minimum, round(full × share)), lowered further while a supplied vertex estimate exceeds the mesh
  budget; monotonic in the share by construction (VisualCoreDiagnostics, G-MESHLOD).
- Q: What are the cache limits and the size of a mesh? → A: 16 entries and 32 MiB by default (settable); a mesh's size is
  its vertex data (positions, normals and texture coordinates as 4-byte floats) plus 4 bytes per index; keys are a
  64-bit `StableHash` of the signature; least-recently-used eviction ordered by a monotonically increasing use counter, so
  ties cannot occur (VisualCoreScenes, G-MESHCACHE).
- Q: How are proportions measured when tilings fill the whole view? → A: Three checks at four view shapes (portrait
  9:19.5, square, 4:3, landscape 19.5:9): the bounded kaleidoscope is drawn and the bounding box of its non-background
  pixels is square within 1 pixel; for the tilings, the presenter's world-to-pixel mapping maps a unit in x and in y to
  the same number of pixels within 1 pixel (checked on a drawn probe point pair); for the 3D composition, the projected
  bounding sphere's horizontal and vertical extents in pixels agree within 1 pixel.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The 3D composition adapts to the device (Priority: P1) 🎯

On a device under load (or with Low Power Mode), the 3D composition is drawn with fewer triangles so it stays smooth; on
a capable device it is drawn at full detail. The composition itself — its shape parameters, camera and saved state — does
not change, only how finely it is drawn.

**Why this priority**: the phase MVP ("adaptive mesh tessellation and render-quality settings").

**Independent Test**: set each quality tier; the drawn mesh's triangle count falls monotonically from the best to the
cheapest tier, every mesh validates within the budget, and the experience digest is identical at every tier.

**Acceptance Scenarios**:

1. **Given** the 3D composition, **When** the quality tier goes from best to cheapest, **Then** the drawn triangle count
   never rises and the cheapest is at most half of the best.
2. **Given** any tier, **When** the composition is drawn, **Then** its mesh is closed, valid and within the mesh budget.
3. **Given** any state, **When** the tier changes, **Then** the experience digest, a saved snapshot and a saved
   composition are byte-identical to those at the best tier.
4. **Given** the person pins a quality level in the app's settings, **When** the composition is shown, **Then** that
   level's tessellation is used.

---

### User Story 2 - Changing presets is quick and does not rebuild the same mesh twice (Priority: P2)

A person switches back and forth between presets; meshes already built for a preset and tier are reused instead of
rebuilt, and the memory they take is bounded.

**Why this priority**: the manual's mesh-cache rule ("precompute bounded meshes and cache by parameter signature") and the
gap G-MESHCACHE.

**Independent Test**: switch A → B → A at one tier; the second A is a cache hit (no rebuild); after many distinct
compositions the cache never exceeds its entry and byte limits and evicts the least recently used.

**Acceptance Scenarios**:

1. **Given** a composition drawn at a tier, **When** the same composition and tier are drawn again, **Then** the mesh is
   taken from the cache (hit count rises, build count does not).
2. **Given** a changed signature (shape parameter or tier), **When** it is drawn, **Then** it misses and is built once.
3. **Given** more distinct meshes than the cache holds, **When** they are drawn, **Then** the entry and byte limits are
   never exceeded and the least recently used mesh is the one evicted, deterministically.

---

### User Story 3 - Proportions stay true on every screen shape (Priority: P2)

On a tall phone, a wide landscape view or an iPad, circles stay round and squares stay square in every preset.

**Why this priority**: the phase's regression fixture.

**Independent Test**: draw each preset at several view shapes and measure a known feature's width and height in pixels;
their ratio matches the expected ratio within one pixel.

**Acceptance Scenarios**:

1. **Given** views of aspect 9:19.5, 1:1, 4:3 and 19.5:9, **When** each 2D preset is drawn, **Then** the kaleidoscope's
   drawn extent is square and the tilings' world-to-pixel scale is equal in x and y, within 1 pixel.
2. **Given** the same views, **When** the 3D composition is drawn, **Then** the projected extent of its bounding sphere
   is circular within 1 pixel.

### Edge Cases

- A tier outside the profile is clamped to the nearest valid tier.
- A cache limit of zero entries disables caching (every draw builds) without failing.
- A mesh larger than the whole byte limit is drawn but not cached.
- After a graphics context recreation the cache of CPU meshes stays valid; GPU buffers are rebuilt as in Phase 03.
- The 2D presets: quality changes do not change their geometry (their rendering is already resolution-independent).

## Requirements *(mandatory)*

### Functional Requirements

**Adaptive tessellation (story 1)**
- **FR-A05-501**: The experience MUST declare a quality profile of four levels (Full, High, Medium, Low) and draw the 3D
  composition with a tessellation chosen from the current tier (24, 16, 12, 8 segments).
- **FR-A05-502**: The tessellation MUST be monotonic: a cheaper tier never draws more triangles than a better one; the
  cheapest draws at most half the triangles of the best.
- **FR-A05-503**: Every drawn mesh at every tier MUST be closed, valid and within the mesh budget.
- **FR-A05-504**: The tier MUST NOT change the experience state, its digest, snapshots or saved compositions.
- **FR-A05-505**: A quality level pinned by the person through the host MUST be honoured.

**Mesh cache (story 2)**
- **FR-A05-510**: Built meshes MUST be cached by a signature of the composition's shape parameters and the tier, so a
  repeated signature is not rebuilt.
- **FR-A05-511**: The cache MUST stay within an entry limit and a byte limit and evict the least recently used entry,
  deterministically.

**Proportions (story 3)**
- **FR-A05-520**: On non-square views every preset MUST keep its proportions (equal horizontal and vertical scale within
  1 pixel).

**Framework (G-MESHCACHE, G-MESHLOD)**
- **FR-A05-530**: VisualCore MUST provide a bounded least-recently-used mesh cache with hit, miss and eviction counts.
- **FR-A05-531**: VisualCore MUST provide a tessellation choice from a quality tier that is monotonic and respects a mesh
  budget.
- **FR-A05-532**: Both MUST be documented, in the public-API baseline, tested, and followed by the reference regression.

**Common**
- **FR-A05-540**: The nine standard scenarios and five fixtures MUST stay valid; fixture 5 gains the multi-aspect
  proportion check.
- **FR-A05-541**: Drawing only through the host; no network; no imported assets; no second renderer.

### Key Entities

- **Quality profile**: the experience's levels from best to cheapest, each with a share of the full tessellation.
- **Mesh signature**: the composition's shape parameters (kind, order, repeats, scale, motif seed) plus the tier.
- **Mesh cache**: entries (signature → mesh) with a byte size, last use, and limits on entries and bytes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A05-501**: For every solid order tested (3, 5, 8, 12), triangle counts are non-increasing over the tiers and the
  cheapest tier has at most 50% of the best tier's triangles; 100% of meshes validate within budget.
- **SC-A05-502**: The digest is identical at every tier for every preset kind (100%).
- **SC-A05-503**: A → B → A at one tier gives exactly one hit and two builds; 200 seeded random access sequences never
  exceed the cache limits and evict in least-recently-used order (100%).
- **SC-A05-504**: On four view aspects, the three proportion checks of the Clarifications agree within 1 pixel for every
  preset on both simulator runtimes.
- **SC-A05-505**: The runner passes the nine scenarios and five fixtures on both runtimes; the reference regression passes
  7 of 7; the public-API baseline lists the new types, all documented.
- **SC-A05-506**: Every new test finishes in under 10 seconds.

## Assumptions

- The host's quality governor and the app's quality setting already exist (feature 192, UA-F06); this phase only supplies
  the experience's profile and its use of the tier.
- Frame timing on devices is measured in the device campaign; the simulator proves the tier mechanics, not speed.
- The core's reference composition (used for its digest and bounds) is always built at full tessellation; lower tiers
  are drawing-only meshes whose bounds lie inside the full mesh's.

## Out of Scope

- Level of detail by distance; streaming; mesh simplification of arbitrary meshes.
- New presets or shapes.
- Device performance claims.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 05 (adaptive mesh tessellation and render-quality settings) | FR-A05-501–505 |
| Manual §6 algorithm 3 / render stage 2 (bounded meshes cached by signature) | FR-A05-510, 511 |
| Manual §9 Phase 05 fixture "non-square displays keep geometric proportions" | FR-A05-520, 540 |
| Contract gaps G-MESHCACHE, G-MESHLOD | FR-A05-530–532 |
| Manual risk 1 (tessellation spikes CPU/memory — mesh budget) | FR-A05-503, 511 |

## Negative Requirements

- No second renderer, no Metal code; no network, analytics or imported art.
- No device timing claims; no long tests.
