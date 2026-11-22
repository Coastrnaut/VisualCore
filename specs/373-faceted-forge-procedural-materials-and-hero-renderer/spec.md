# Feature Specification: R02-G08-03 — Faceted Forge: procedural materials and hero renderer

**Feature Branch**: `373-faceted-forge-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G08-03 (migration ledger, game feature of experience R02-G08) · ID namespace FR-R02G0803-###,
SC-R02G0803-###, T-R02G0803-###

**Input**: User description: the archived R02-G08-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Faceted Forge, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/373-faceted-forge-procedural-materials-and-hero-renderer`; FR-R02G0803-###,
  SC-R02G0803-###, T-R02G0803-###.
- **Packaging (ADR-0009):** the source's `Apps/FacetedForge` becomes the experience target `FacetedForgeExperience`
  (with its tests) in `Packages/ExperiencesRound02/FacetedForge/Experience` beside the existing `FacetedForgeCore`; the
  experience `r02-g08.faceted-forge` (free) is registered in the catalog as a candidate (not available) and linked into
  the one app, as Amethyst Escape was at R02-G07-03; it becomes available only at its gate X-R02-G08.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 84" is a milestone figure — the catalog
  is the 100 certified levels of R02-G08-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded
  as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues), R02-F11 (SDF and constructive geometry proxies) and the shared custom-shader mesh renderer added
  at R02-G01-03, through the existing VisualCore packages; the kernel and certified levels of R02-G08-01 and -02.
- **Model:** feature 363 (Amethyst Escape's hero renderer) for the adapter, snapshot, geometry, CPU reference,
  scenarios, presenter, scene, fallback and registration.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
363's answers. Facts checked in code (read-only, 2026-11-22): Amethyst Escape's experience (R02-G07-03 … 10) is the
pattern in this package — a Core adapter with a per-process cache of generated levels, an immutable scene snapshot, a
CPU projection reference, GLSL sources in the Core, an iOS-only experience target (`…Experience.swift`, presenter,
scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with content facts in
`Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Faceted Forge kernel provides the level (crystal
half-spaces in the box −6 … 6, budget, sliver limit, target multiset), pieces (exact corners, faces with their planes,
volume, canonical order), play (`cut(piece, direction, depth)`, undo, redo, stages, failure) and the certified catalog
with its pinned digest (ceb59042…a924c); `AppModelTests` uses `r02-g08.faceted-forge` as its example of an
unregistered candidate and the next round-two game is `r02-g09.nocturne-garden`; the catalog's design gives the palette
"ice glass, ruby, inner amber" and the geometry "half-space clipping generates per-piece indexed meshes".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: kernel coordinates map to world
  space by subtracting the crystal's centroid (the mean of its corners) and dividing by R, the largest distance from it
  to a crystal corner, so the crystal fits the unit sphere; y is up. Each piece is drawn from its exact faces (fan
  triangulation of each face's ordered corners) with every edge bevelled by an inset of 0.02, and is moved away from
  the centre along the direction from the crystal's centroid to the piece's centroid by 0.12 (0.2 when won; the
  opening eases over 0.4 s of presentation time and stands still under Reduce Motion). A face is a cut face when its
  plane is not one of the crystal's half-spaces; cut faces get the amber interior with a lattice, the others ice glass.
  The preview plane is the chosen piece's cross-section by the chosen direction and depth (a ruby polygon with a
  dashed rim), drawn only when that plane crosses the piece. The cut mark is a row of `budget` small bars along the
  near edge (z = 1.3, x from −0.9 to 0.9), spent ones lit ruby. The ground is a dark plane at y = −1.3. The camera is a
  fixed authored perspective looking at the origin from the front (+z), pitched 30° down, fitted to the bounding sphere
  of radius 1.45 (the opened crystal plus the mark) with a 5 % margin for aspect 0.4 … 2.5. Dispersion shimmer moves
  with presentation time only. Nothing drawn is consulted by the rules. Impact: FR-R02G0803-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): 3 bevel segments per edge, 3 dispersion layers,
  2 glow shells around cut faces; `level-1`: 2 bevel segments, 2 dispersion layers, 1 glow shell; `level-2` (the
  design's "Tier 0, D3-safe"): 1 bevel segment, 1 dispersion layer, no glow. Pieces, faces, preview plane, colours,
  marks and positions are the same at every tier. Levels are ordered richest first; the presenter logs each tier change
  with its reason. Impact: FR-R02G0803-004; SC-R02G0803-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects every piece's
  opened centroid, the centre of every cut face and the preview plane's centre through the same camera and gives the
  palette. Simulator tests render offscreen at 1,152 × 768 and check that every piece centroid (± 3 pixels) differs
  from the ground by at least 0.1 in luminance, that every cut face's centre (± 3 pixels) is warmer than the ground
  (red minus blue at least 0.15), that the preview plane's centre (± 3 pixels) differs from the ground by at least
  0.05, that the cut mark's first bar (± 3 pixels) differs from the ground by at least 0.1, and that the background
  matches the ground within 0.05 away from geometry. Palette: ground #07090F, ice glass
  #BFE6F5, ice highlight #F2FBFF, ruby #C8163C, inner amber #FFB347, lattice #FFE2A8, sliver cross #FF4D6D, spent mark
  #C8163C, unspent mark #3A4558. Impact: FR-R02G0803-006; SC-R02G0803-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `FacetedForgeSceneSnapshot` (every piece's corners and faces as Doubles in world space before opening, which faces
  are cuts, the chosen piece, direction and depth, stage, failure with its piece, cuts spent, budget, level number and
  presentation time) made by the adapter; it never holds the kernel. If a program fails to compile or link, the scene
  draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier
  changes go to its `tierLog`. Reduce Motion holds the shimmer at time 0 and shows the full opening (0.12, 0.2 when
  won) without easing; Reduce Flashing
  caps the glow gain. A sliver failure marks the thin piece with a sliver-cross colour and the failure text names the
  piece and the cut. Impact: FR-R02G0803-003, 007; SC-R02G0803-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g08.faceted-forge` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/FacetedForge/scenario-manifest.json`, no permissions, a summary of at
  most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's experience
  registry link `FacetedForgeExperience` as a candidate (`available: false` until X-R02-G08), opening at seed 0
  (level 1); `AppModelTests` switches its unregistered example to the next round-two game (`r02-g09.nocturne-garden`).
  The adapter (`FacetedForgeExperienceCore`) prepares certified level (seed mod 100) + 1 (generated once per process)
  and accepts `piece.cut [piece, direction, depth]` (whole; piece 0 … pieces − 1, direction 0 … 12, depth −24 … 24),
  `play.undo`, `play.redo` and `level.next`; the kernel refuses everything out of range or out of stage; its digest is
  the level number and the play's fingerprint (never the record history, so undo restores the earlier digest); snapshot
  schema 1 `{level, records}`. The preview choice (piece, direction, depth) is presentation state of the controls, not
  kernel state: a level opens with piece 0, direction 0 and the middle depth among those whose plane crosses piece 0;
  after a cut, undo or redo the chosen piece is clamped to the new piece count and the depth moved to the nearest
  crossing one. Impact: FR-R02G0803-005, 008, 009; SC-R02G0803-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the glowing crystal open like a blossom (Priority: P1) 🎯

A player opens Faceted Forge and sees an ice-glass crystal on a dark ground. Every piece is a bevelled convex solid,
drawn a little apart from the others so the crystal opens like a geometric blossom; the faces the player has cut glow
with an incandescent amber-to-ruby interior and carry a fine lattice, while the crystal's original faces stay cool ice
glass. The plane of the next cut is shown as a translucent ruby sheet across the chosen piece, and a mark shows the cuts
spent against the budget.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose piece centres,
cut faces and preview plane are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose piece centres and
   face pixels match the CPU reference within stated bounds.
2. **Given** a cut from the rule kernel, **When** the next frame is drawn, **Then** the pieces, the glowing cut faces
   and the cut mark follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity is a certification invariant.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer bevel segments, fewer dispersion layers and no glow but keeps the same objective,
pieces, cut faces, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the piece centres, the cut faces and the preview plane at the same places;
only bevel segments, dispersion layers and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for
  every aspect ratio from 0.4 to 2.5 the camera fits the whole opened crystal with a margin of at least 5 % on each
  side.
- **Colour-blind players:** cut faces carry a lattice pattern as well as their glow, the crystal's original faces are
  plain, the preview plane has a dashed rim, a sliver failure marks the thin piece with a cross, and each piece can be
  named by number, share and face count, so no information is carried by hue only.
- **A sliver failure:** the thin piece is marked distinctly and the failure shown names it and the cut.
- **A won level:** the pieces open fully and the cut faces are lit; the frame checks use the opened positions.
- **A piece centred on the crystal's centre:** a piece whose centroid lies within 1e-9 of the crystal's centroid (the
  uncut crystal, or a central piece) is not moved by the opening; the uncut crystal is drawn whole and unopened.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the interior shimmer stands still and the opening is shown at full distance without easing; Reduce
  Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0803-001**: The experience MUST render every piece as a bevelled convex solid with its exact faces, the cut
  faces, the preview plane of the next cut and the cut mark entirely from generated geometry and shader code, with no
  image assets.
- **FR-R02G0803-002**: Materials MUST show a dark ground, ice-glass original faces with fresnel highlights and faux
  dispersion, incandescent amber-to-ruby cut faces with a lattice, and a translucent ruby preview plane, computed in
  shaders; every element also has its shape or pattern.
- **FR-R02G0803-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G0803-004**: The experience MUST offer three quality tiers that change only bevel segments, dispersion layers
  and glow, never pieces, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0803-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for cuts, undo, redo and next level, digest, snapshot and restore), opening certified levels of R02-G08-02.
- **FR-R02G0803-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G0803-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G0803-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0803-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the pieces (exact corners and faces, which faces are cuts), the chosen piece and the preview
  plane, stage, failure, cuts spent, budget and presentation time.
- **Crystal geometry**: the ground, the bevelled pieces opened about the crystal's centre, the cut faces with their
  lattice, the preview plane and the cut mark.
- **Quality tier**: 0, 1 or 2, with its bevel segments, dispersion layers and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario
  manifest and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0803-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: piece
  centre and cut-face pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0803-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0803-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G0803-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G0803-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0803-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (dragging the cut plane's rim, the depth slider, tapping commit, orbit) are R02-G08-04; hints and
  progression R02-G08-05; accessibility and polish R02-G08-06; persistence R02-G08-07. This feature gives the experience
  a minimal control panel (a piece picker, a direction picker, depth − and +, cut, undo, redo, next level, each
  labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Amethyst Escape, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G08-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (half-space clipping generates per-piece indexed meshes) | FR-R02G0803-001 |
| Signature shader (fast SDF cuts reveal incandescent interiors; bevelled polyhedra, faceted SDFs, instanced lattices, faux dispersion) and palette (ice glass, ruby, inner amber) | FR-R02G0803-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0803-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0803-004 |
| Renderer purity, stability | FR-R02G0803-003; SC-R02G0803-002, 003 |
| Real render captures | FR-R02G0803-006 |
| "Register it in the catalog" (override) | FR-R02G0803-008 |
| No Stage One breakage | FR-R02G0803-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G08.
