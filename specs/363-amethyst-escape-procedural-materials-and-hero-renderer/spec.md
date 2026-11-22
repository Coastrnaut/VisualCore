# Feature Specification: R02-G07-03 — Amethyst Escape: procedural materials and hero renderer

**Feature Branch**: `363-amethyst-escape-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G07-03 (migration ledger, game feature of experience R02-G07) · ID namespace FR-R02G0703-###,
SC-R02G0703-###, T-R02G0703-###

**Input**: User description: the archived R02-G07-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Amethyst Escape (code-only hero:
"layered amethyst gem cathedral with dancing internal facet highlights"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/363-amethyst-escape-procedural-materials-and-hero-renderer`; FR-R02G0703-###,
  SC-R02G0703-###, T-R02G0703-###.
- **Packaging (ADR-0009):** the source's `Apps/AmethystEscape` becomes the experience target `AmethystEscapeExperience`
  (with its tests) in `Packages/ExperiencesRound02/AmethystEscape/Experience` beside the existing `AmethystEscapeCore`;
  the experience `r02-g07.amethyst-escape` (free) is registered in the catalog as a candidate (not available) and linked
  into the one app, as Chrono Constellator was at R02-G06-03; it becomes available only at its gate X-R02-G07.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 80" is a milestone figure — the catalog is
  the 100 certified levels of R02-G07-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues), R02-F11 (SDF and constructive geometry proxies) and the shared custom-shader mesh renderer added at
  R02-G01-03, through the existing VisualCore packages; the kernel and certified levels of R02-G07-01 and -02.
- **Model:** feature 353 (Chrono Constellator's hero renderer) for the adapter, snapshot, geometry, CPU reference,
  scenarios, presenter, scene, fallback and registration.

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
353's answers. Facts checked in code (read-only, 2026-11-22): Chrono Constellator's experience (R02-G06-03 … 10) is the
pattern in this package — a Core adapter with a per-process cache of generated levels, an immutable scene snapshot, a CPU
projection reference, GLSL sources in the Core, an iOS-only experience target (`…Experience.swift`, presenter, scene,
controls), a scenario manifest with 80 acceptance scenarios, a registration with content facts in
`Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Amethyst Escape kernel provides the level (sectors
6 … 12, shells 2 … 5, apertures, walls, blocked wedges, exit gap), crystal (offsets, pearl pocket), play
(`rotate(shell, step)`, `advance`, undo, redo, stages, failure) and the certified catalog with its pinned digest
(e65c4529…94e6); `AppModelTests` uses `r02-g07.amethyst-escape` as its example of an unregistered candidate; the catalog's
design gives the palette "amethyst purple and cool platinum" and the geometry "procedurally beveled wedge polyhedra with
analytic faceting".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the crystal lies in the xz-plane,
  y up, centred at the origin. With n shells and S sectors, shell k (0 innermost) is the annulus from radius
  r_k = 0.2 + k·w to r_k + w, w = 0.8 / n; sector s of shell k covers the angles 2π·(s + o_k)/S … 2π·(s + o_k + 1)/S
  measured from +x towards −z, o_k being the shell's offset, so the world sector of a wedge is (s + o_k) mod S. Each
  wedge is a bevelled prism (height h_k = 0.08 + 0.06·(n − 1 − k), so inner shells stand taller like a cathedral)
  inset by 0.04·w on each side; an aperture is an opening in the shell's outer wall drawn as a gap in its rim band;
  a radial wall is a platinum fin (thickness 0.03·w, height h_k + 0.02) on the wedge's leading edge; a blocked wedge is
  dark and opaque with a raised cross mark on its top. The pearl is a sphere of radius 0.3·w at its pocket's centre
  (radius r_k + w/2, angle at the sector's middle), centre y = h_k + 0.3·w. The exit gap of the outer shell carries a
  platinum arrow mark pointing outward at radius r_(n−1) + w + 0.06. The backdrop is a dark plane at y = 0. The camera is
  a fixed authored perspective looking at the origin from the front (+z), pitched 50° down, fitted to the bounding sphere
  of radius 1.1 (the crystal plus the arrow) with a 5 % margin for aspect 0.4 … 2.5. Facet highlights move with
  presentation time only. Nothing drawn is consulted by the rules. Impact: FR-R02G0703-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): 3 bevel segments per edge, 3 highlight layers,
  2 glow shells around the pearl and exit; `level-1`: 2 bevel segments, 2 highlight layers, 1 glow shell; `level-2`
  (the design's "Tier 0, D3-safe"): 1 bevel segment, 1 highlight layer, no glow. Wedges, walls, pearl, exit, colours,
  marks and positions are the same at every tier. Levels are ordered richest first; the presenter logs each tier change
  with its reason. Impact: FR-R02G0703-004; SC-R02G0703-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects the pearl centre,
  the exit arrow's centre and the top centre of every wedge through the same camera and gives the palette. Simulator
  tests render offscreen at 1,152 × 768 and check that the pearl centre lies within 3 pixels of a pixel brighter than
  the backdrop by at least 0.15 in luminance, that the exit arrow's centre (± 3 pixels) differs from the backdrop by at
  least 0.1, that every open wedge's top centre (± 3 pixels) differs from the backdrop by at least 0.05, and that the
  background matches the backdrop within 0.05 away from geometry. Palette: backdrop #0A0614, amethyst #8E4FD8, facet
  highlight #E3CCFF, platinum #D6DCE6, blocked wedge #1E1426, pearl #F6F2FF, exit #B8F0FF, failure amber #FFB020.
  Impact: FR-R02G0703-006; SC-R02G0703-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `AmethystEscapeSceneSnapshot` (sectors, every shell's apertures, walls, blocked wedges and offset, the pearl pocket,
  the exit gap, stage, failure, moves spent, budget, level number and presentation time) made by the adapter; it never
  holds the kernel. If a program fails to compile or link, the scene draws the level-2 geometry unlit with the shared
  unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion holds the
  facet highlights at time 0; Reduce Flashing caps the glow gain. A failure in a blocked wedge tints that wedge amber
  and the failure text names its shell and sector. Impact: FR-R02G0703-003, 007; SC-R02G0703-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g07.amethyst-escape` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/AmethystEscape/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's experience
  registry link `AmethystEscapeExperience` as a candidate (`available: false` until X-R02-G07), opening at seed 0
  (level 1); `AppModelTests` switches its unregistered example to the next round-two game (`r02-g08`'s id from the
  catalog). The adapter (`AmethystEscapeExperienceCore`) prepares certified level (seed mod 100) + 1 (generated once per
  process) and accepts `shell.rotate [shell, step]` (whole, 0 … shells − 1, −1 or +1), `pearl.advance`, `play.undo`,
  `play.redo` and `level.next`; the kernel refuses everything out of range or out of stage; its digest is the level
  number and the play's fingerprint (never the record history, so undo restores the earlier digest); snapshot schema 1
  `{level, records}`. Impact: FR-R02G0703-005, 008, 009; SC-R02G0703-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the amethyst crystal (Priority: P1) 🎯

A player opens Amethyst Escape and sees a crystal of nested translucent amethyst shells, each a ring of bevelled wedge
facets with openings in its outer wall, cool platinum fins for the radial walls, dark opaque facets for the blocked
wedges, a glowing pearl in its pocket and the exit gap of the outer shell marked; facet highlights shimmer gently.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose pearl, exit gap
and shell facets are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose pearl, exit gap and
   facet pixels match the CPU reference within stated bounds.
2. **Given** a rotation or an advance from the rule kernel, **When** the next frame is drawn, **Then** the shells, walls,
   wedges and pearl follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity is a certification invariant.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed shader
leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer facet bevels, fewer highlight layers and no glow but keeps the same objective,
shells, pearl, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the pearl, the exit gap and the facets at the same places; only bevel
segments, highlight layers and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole crystal with a margin of at least 5 % on each side.
- **Colour-blind players:** openings are gaps in the outer wall, walls are raised fins, blocked wedges are dark and carry
  a cross mark, the exit gap carries an arrow mark and the pearl is the only sphere, so no information is carried by hue
  only.
- **A pearl in a blocked wedge (a failure):** the wedge is marked distinctly and the failure shown names its shell and
  sector.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the facet highlights stand still; Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0703-001**: The experience MUST render every shell's wedge facets, its openings, radial walls and blocked
  wedges, the pearl, the exit gap and the move counter mark entirely from generated geometry and shader code, with no
  image assets.
- **FR-R02G0703-002**: Materials MUST show a dark backdrop, translucent amethyst facets with shifting specular
  highlights, platinum walls, dark blocked wedges, a glowing pearl and a marked exit gap, computed in shaders; every
  element also has its shape.
- **FR-R02G0703-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G0703-004**: The experience MUST offer three quality tiers that change only bevel segments, highlight layers
  and glow, never shells, pearl, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0703-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for rotations, advances, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G07-02.
- **FR-R02G0703-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0703-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0703-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0703-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the level's shells (openings, walls, wedges), every shell's offset, the pearl's pocket, stage,
  failure, moves spent and presentation time.
- **Crystal geometry**: the backdrop, the shell facets, openings, walls, wedges, the pearl, the exit gap and the move
  mark.
- **Quality tier**: 0, 1 or 2, with its bevel segments, highlight layers and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0703-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: pearl, exit
  gap and facet pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0703-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0703-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0703-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0703-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0703-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (dragging a shell bezel, tapping to advance, double tap to isolate a layer, orbit) are R02-G07-04; hints and
  progression R02-G07-05; accessibility and polish R02-G07-06; persistence R02-G07-07. This feature gives the experience
  a minimal control panel (a shell picker, turn − and +, advance, undo, redo, next level, each labelled) so it can be
  exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Chrono Constellator, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G07-QA-001 … 080), and its registration carries the
  content facts (100 levels and the pinned catalog digest).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (procedurally bevelled wedge polyhedra with analytic faceting) | FR-R02G0703-001 |
| Signature shader (translucent nested polygons with shifting specular highlights) and palette (amethyst purple, cool platinum) | FR-R02G0703-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0703-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0703-004 |
| Renderer purity, stability | FR-R02G0703-003; SC-R02G0703-002, 003 |
| Real render captures | FR-R02G0703-006 |
| "Register it in the catalog" (override) | FR-R02G0703-008 |
| No Stage One breakage | FR-R02G0703-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G07.
