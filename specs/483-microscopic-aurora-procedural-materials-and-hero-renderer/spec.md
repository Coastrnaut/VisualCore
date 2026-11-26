# Feature Specification: R02-G19-03 — Microscopic Aurora: procedural materials and hero renderer

**Feature Branch**: `483-microscopic-aurora-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-26

**Status**: Clarified

**Ledger gate**: R02-G19-03 (migration ledger, game feature of experience R02-G19) · ID namespace FR-R02G1903-###,
SC-R02G1903-###, T-R02G1903-###

**Input**: User description: the archived R02-G19-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Microscopic Aurora (code-only
hero: "bioluminescent protozoa making aurora-like ribbons under a microscope"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/483-microscopic-aurora-procedural-materials-and-hero-renderer`;
  FR-R02G1903-###, SC-R02G1903-###, T-R02G1903-###.
- **Packaging (ADR-0009):** the source's `Apps/MicroscopicAurora` becomes the experience target
  `MicroscopicAuroraExperience` (with its tests) in `Packages/ExperiencesRound02/MicroscopicAurora/Experience` beside
  the existing `MicroscopicAuroraCore` (the source's `Packages/GameModules/MicroscopicAuroraCore`); the experience
  `r02-g19.microscopic-aurora` (free) is registered in the catalog as a candidate (not available) and linked into the one
  app, as Apsides Workshop was at R02-G18-03; it becomes available only at its gate X-R02-G19.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 82" is a milestone figure — the catalog is
  the 100 certified levels of R02-G19-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G19-01 and -02.
- **Model:** feature 473 (Apsides Workshop's hero renderer and experience).

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
473's answers where the games agree. Facts checked in code (read-only, 2026-11-26): Apsides Workshop's experience as
recorded at R02-G18-03 is the pattern in this package — a Core adapter with a table of certified candidate indices
(`certifiedCandidates`, each stored witness's `skipped`), an immutable scene snapshot, a CPU projection reference, GLSL
sources in the Core, an iOS-only experience target (`…Experience.swift`, presenter, scene, controls), a scenario
manifest with 80 acceptance scenarios, a registration with content facts in `Catalog/registrations.json` and the public
`ShaderMeshRenderer`; the Microscopic Aurora kernel provides the level (enclosure, swim length, swarm, stencil,
threshold, coverage, coherence, sites, budget), the swim's integer positions per tick (`MicroscopicAuroraDish.swim(…,
keepPositions: true)`, dish units 0 … 6143), the report (density, lit stencil, coverage, groups, coherence, failure:
exit, coherence, coverage, connectedness), the play (place, remove, play, undo, redo, stages) and the certified catalog
of R02-G19-02 (enclosure 11, 3 … 6 sites, 4 … 8 swimmers, swims of 120 … 160 ticks, digest 03c1dc19…); `AppModelTests`
uses `r02-g19.microscopic-aurora` as its synthetic unregistered candidate and the next round-two game is
`r02-g20.mushroom-weather`; the archived matrix has 80 acceptance rows R2-G19-QA-001 … 080; the catalog's design gives
the palette "sea glass green, heliotrope, white", the hero "bioluminescent protozoa making aurora-like ribbons under a
microscope" and the geometry "instanced tapered capsules, deterministic ribbon trails".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: one fixed scale for every level: a
  dish point (x, y) in dish units maps to world ((x − 3072) · s, (3072 − y) · s, depth) with s = 0.9 / 2816, so an
  enclosure of 11 cells has its rim at radius 0.9; y is up and the camera looks down the z axis. Drawn with depth
  testing off (the shared mesh renderer's path), in this order: the water backdrop (a large quad; a vertical gradient from
  abyss #04110F at the bottom to abyss top #0B2A26 at the top, still); the dish field (a disc of radius R · 256 · s,
  field #0E2E2A); the fronds (at the two richer tiers only: small L-system fronds of three generations rooted outside the
  rim, frond #2E6B5C, decoration only); the rim (a ring at the enclosure radius, 0.012 wide, rim #6FB7A6); the stencil
  (each stencil cell an outline square of side 256 · s, 0.004 wide, stencil #3E7F72); the lit cells (each lit cell a
  filled square inset by 10 %, lit #7FE0C4 for a stencil cell, stray #2F6B5F outside the stencil); the sites (a ring of
  radius 0.35 cell at each site's centre, site #B58CE0); the wells (a spiral of strength + 1 half-turns, radius 0.45
  cell, its arrowhead pointing in the turning sense, well #D2A8FF); the ribbons (for each swimmer a ribbon through its
  kernel positions of the last L ticks up to the shown tick, 0.01 wide fading to its tail, ribbon #8FF0D6); the swimmers
  (a tapered capsule 0.05 long and 0.016 wide at its position at the shown tick, oriented along its velocity, swimmer
  #E9FFF8 with a heliotrope tail tip); the gauges below the dish: coverage on a track at y = −1.08 from x = −0.9 to 0.9
  mapping 0 … 1000 with a tick at the requirement and a mark at the reading (filled, met #B58CE0, when met; hollow,
  unmet #E9FFF8, otherwise); coherence on a track at y = −1.15 mapping 0 … N with a tick at the requirement and a mark
  at the smallest coherence; the actions bars, `budget` bars at y = −1.25 from x = −0.9 to 0.9 (each 1.8 / budget wide
  with a gap of a fifth, 0.04 tall), lit for the actions left. The glow is additive and drawn last. The positions are
  the predicted swim of the current wells; the shown tick is presentation state of the adapter (`clock.show [tick]`,
  0 … ticks swum, never in the digest), 0 at opening and never advanced by time. The camera is a fixed authored
  perspective (eye (0, −0.15, 3.4) looking at (0, −0.15, 0)) fitted to the box x −1.0 … 1.0, y −1.35 … 1.0 with a 5 %
  margin for aspect 0.4 … 2.5. Nothing drawn is consulted by the rules. Impact: FR-R02G1903-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): capsules of 12 segments with layered shading
  (core, rim light), ribbons of the last 64 ticks, fronds and 2 glow shells around the swimmers and ribbons; `level-1`:
  8 segments, 32 ticks, fronds, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): flat capsules (screen-facing
  quads with rounded ends), 16 ticks, no fronds, no glow. The backdrop, field, rim, stencil, lit cells, sites, wells,
  gauges, colours and positions are the same at every tier. Levels are ordered richest first; the presenter logs each
  tier change with its reason. Impact: FR-R02G1903-004; SC-R02G1903-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera the dish centre, the rim's rightmost point, every swimmer at the shown tick, the first site, the coverage
  track's centre and the first actions bar, and gives the palette. Simulator tests render offscreen at 1,152 × 768 at the
  shown tick half the ticks swum and check, at points at least 6 pixels from every element drawn after them, that each
  swimmer's centre is brighter than the dish field by at least 0.25 in luminance; that the rim's rightmost point differs
  from the backdrop by at least 0.1; that the first actions bar (lit) has blue above green by at least 0.08 (heliotrope);
  that the coverage track differs from the backdrop by at least 0.1; and that the median of a 9 × 9 pixel patch of
  backdrop in a corner matches the gradient colour at its height within 0.06. Palette: abyss #04110F, abyss top
  #0B2A26, field #0E2E2A, frond #2E6B5C, rim #6FB7A6, stencil #3E7F72, lit #7FE0C4, stray #2F6B5F, site #B58CE0, well
  #D2A8FF, ribbon #8FF0D6, swimmer #E9FFF8, met #B58CE0, unmet #E9FFF8, actions lit #B58CE0, actions unlit #1E3A35,
  broken #FF6B5E, glow #F2FFFB. Impact: FR-R02G1903-006; SC-R02G1903-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `MicroscopicAuroraSceneSnapshot` (the swimmers' positions and velocities by tick of the predicted swim, the ticks
  swum, the shown tick, the density and lit cells, the stencil, the sites, the wells, coverage and coherence with their
  requirements, stage, failure, actions left, budget, level number and presentation time) made by the adapter; it never
  holds the kernel. If a program fails to compile or link, the scene draws the level-2 geometry unlit with the shared
  unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion keeps
  everything still (nothing moves by time already); Reduce Flashing caps the glow gain. A failure marks the failing
  element in the broken colour (an exit: the escaping swimmer and a mark on the rim where it crossed; a coherence
  failure: the swimmers outside the largest group; a coverage failure: the unlit stencil outlines; a connectedness
  failure: the named cell) and the failure text names it, as the kernel's reason does. Impact: FR-R02G1903-003, 007;
  SC-R02G1903-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g19.microscopic-aurora` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette #04110F,
  #8FF0D6, #B58CE0, #E9FFF8, #0E2E2A, the scenario manifest `Packages/ExperiencesRound02/MicroscopicAurora/
  scenario-manifest.json`, no permissions, a summary of at most 300 characters, content facts: 100 levels and the pinned
  catalog digest); `project.yml` and the app's experience registry link `MicroscopicAuroraExperience` as a candidate
  (`available: false` until X-R02-G19), opening at seed 0 (level 1); `AppModelTests` switches its synthetic unregistered
  candidate to the next round-two game (`r02-g20.mushroom-weather`). The adapter (`MicroscopicAuroraExperienceCore`)
  prepares certified level (seed mod 100) + 1 from its table of certified candidate indices (the whole catalog only if
  that candidate no longer certifies) and accepts `well.place [slot, row, column, strength, sense]` (sense 0 clockwise,
  1 counterclockwise), `well.remove [slot]`, `swim.play`, `play.undo`, `play.redo`, `level.next` and `clock.show
  [tick]` (whole numbers only); the kernel refuses everything out of range or out of stage and `clock.show` refuses a
  tick outside 0 … ticks swum; its digest is the level number and the play's fingerprint (never the record history or
  the shown tick, so undo restores the earlier digest); snapshot schema 1 `{level, records}`. Impact: FR-R02G1903-005,
  008, 009; SC-R02G1903-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch luminous swimmers draw aurora ribbons in the dish (Priority: P1) 🎯

A player opens Microscopic Aurora and sees a round dish under a microscope: a faint target pattern of cells, the magnetic
well sites, and a small swarm of slender luminous swimmers. When the swim plays, the swimmers move along the kernel's
exact positions and leave glowing ribbon trails; cells lit by the trails glow, wells show their turning sense, and gauges
show the stencil's coverage and the swarm's coherence against their requirements.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose dish rim,
swimmers, trails, lit cells, sites, wells and gauges are where a CPU reference of the same snapshot says they are, in the
stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose rim, swimmer, cell,
   well and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the wells, the predicted trails
   and lit cells and the gauges show the new report, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown tick or rendering failure, the drawn image never changes
the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn swimmers stand at
the kernel's exact integer positions.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown tick and frame count never changes the kernel's digest; a
failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses flat swimmers, short trails and no glow but keeps the same objective, dish, cells,
wells, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the rim, swimmers, cells, wells and gauges at the same places; only the
shading detail, trail length and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G19.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the dish and the gauges with a margin of at least 5 % on each side.
- **Colour-blind players:** stencil cells carry an outline, lit cells a fill, sites a ring, wells a spiral whose arrow
  shows the turning sense and whose turns show the strength, the swarm's coherence and the coverage bars with a target
  tick, actions a row of bars; every well, cell, swimmer and measure can be named in words by the kernel, so no
  information is carried by hue only.
- **A failure (exit, coherence, coverage, connectedness):** the failing element is marked in the broken colour (the
  escaping swimmer at the rim, the split swarm's smaller groups, the unlit stencil cells, or the disconnected cell); the
  failure shown names it, as the kernel's reason does.
- **A won level:** every stencil cell is lit and the ribbons glow fully; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** nothing moves by itself (the shown tick never advances by time, the water plane is still); Reduce
  Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1903-001**: The experience MUST render the dish and its rim, the stencil cells, the lit cells, the sites, the
  wells, the swimmers at the shown tick (as tapered capsules), their ribbon trails through the kernel's positions and the
  gauges entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1903-002**: Materials MUST show a still water plane under a microscope, bioluminescent sea-glass-green
  swimmers and ribbons with heliotrope accents and white highlights, computed in shaders; every element also has its
  shape or pattern.
- **FR-R02G1903-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown tick or failure may change the kernel's state, digest or verdict.
- **FR-R02G1903-004**: The experience MUST offer three quality tiers that change only shading detail, trail length and
  glow, never the dish, cells, wells, swimmers' positions, colours, objective or indicators; the selected tier and the
  reason MUST be logged.
- **FR-R02G1903-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for placing, changing and removing wells, playing the swim, undo, redo, next level and the shown tick, digest,
  snapshot and restore), opening certified levels of R02-G19-02.
- **FR-R02G1903-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1903-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1903-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1903-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the swimmers' positions over the swim, the shown tick, the trail density and lit cells, the
  stencil, the sites, the wells, coverage and coherence with their requirements, stage, failure, actions left, budget,
  level number and presentation time.
- **Dish geometry**: the water plane, the rim, the cells, the sites and wells, the swimmer capsules, the ribbon trails
  and the gauges.
- **Quality tier**: 0, 1 or 2, with its shading detail, trail length and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1903-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: rim,
  swimmer, cell, well and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1903-002**: Across 200 seeded snapshots, tier changes, time steps, shown-tick changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G1903-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1903-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1903-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1903-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag up to three magnetic wells, scrub speed, tap freeze field) are R02-G19-04; hints and progression
  R02-G19-05; accessibility and polish R02-G19-06; persistence R02-G19-07. This feature gives the experience a minimal
  control panel (a slot picker, site −/+, strength −/+, sense, place, remove, tick −/+, play, undo, redo, next level, each
  labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Bioluminescent
  protozoa making aurora-like ribbons under a microscope" is read as the swimmers drawn as slender glowing capsules
  leaving ribbon trails over a still water plane in a round microscope field; "instanced tapered capsules, deterministic
  ribbon trails" are capsules per swimmer oriented along its velocity and ribbons through the kernel's exact positions of
  recent ticks; "L-system miniature flora" is read as small procedural fronds at the rim, decoration only.
- Like Apsides Workshop, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G19-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G19-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g20.mushroom-weather`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (instanced tapered capsules, deterministic ribbon trails) | FR-R02G1903-001 |
| Signature shader (slender luminous boids form wave-like living ribbons; L-system miniature flora, deterministic boids, bioluminescence and simple water planes) and palette (sea glass green, heliotrope, white) | FR-R02G1903-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1903-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1903-004 |
| Renderer purity, stability | FR-R02G1903-003; SC-R02G1903-002, 003 |
| Real render captures | FR-R02G1903-006 |
| "Register it in the catalog" (override) | FR-R02G1903-008 |
| No Stage One breakage | FR-R02G1903-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G19.
