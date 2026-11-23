# Feature Specification: R02-G11-03 — Echo Cartographer: procedural materials and hero renderer

**Feature Branch**: `403-echo-cartographer-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G11-03 (migration ledger, game feature of experience R02-G11) · ID namespace FR-R02G1103-###,
SC-R02G1103-###, T-R02G1103-###

**Input**: User description: the archived R02-G11-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Procedural materials and hero renderer" for Echo Cartographer, with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/403-echo-cartographer-procedural-materials-and-hero-renderer`; FR-R02G1103-###,
  SC-R02G1103-###, T-R02G1103-###.
- **Packaging (ADR-0009):** the source's `Apps/EchoCartographer` becomes the experience target
  `EchoCartographerExperience` (with its tests) in `Packages/ExperiencesRound02/EchoCartographer/Experience` beside the
  existing `EchoCartographerCore`; the experience `r02-g11.echo-cartographer` (free) is registered in the catalog as a
  candidate (not available) and linked into the one app, as Backwards Aurora was at R02-G10-03; it becomes available
  only at its gate X-R02-G11.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 90" is a milestone figure — the catalog is
  the 100 certified levels of R02-G11-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G11-01 and -02.

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
393's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Backwards Aurora's experience
(R02-G10-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Echo Cartographer kernel provides
the level (chamber, entry, beacons, tolerance, energy, miss cost), the knowledge, the echo report, the play (pulse,
claim, mark, undo, redo, stages, failure energy(action)) and the certified catalog with its pinned digest
(a32a593b…dca9); `AppModelTests` uses `r02-g11.echo-cartographer` as its example of an unregistered candidate and the
next round-two game is `r02-g12.harmonic-bridges`; the catalog's design gives the palette "abyss black, sonar mint and
opal", the hero "dark temples briefly crystallizing into wireframe from expanding cyan light" and the geometry "SDF
primitives plus instanced wireframe edge strips".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the chamber floor is the plane y = 0
  with x to the right and z towards the viewer: with s = 1.8 / max(W, H), cell (x, y) is centred at
  X = (x + 0.5 − W / 2)·s, Z = (y + 0.5 − H / 2)·s. Drawn in this order: the abyss ground (a plane at y = −0.01 covering
  the chamber plus 0.1 on each side); a floor tile (a square 0.9·s wide at y = 0) on every cell known open; the entry as
  a diamond (a square 0.5·s rotated 45°) at y = 0.005; markers as rings (radius 0.32·s, line 0.06·s) at y = 0.01; the
  last pulse's rays as strips 0.05·s wide from the emitter's centre to the struck wall's face or the chamber's edge at
  y = 0.015; the pulse ring (a circle, line 0.06·s, at y = 0.02) whose radius grows by one cell every 0.1 s of
  presentation time from the emitter, up to the longest ray, and echo rings that shrink back to the emitter, one per
  beacon echo, reaching it at that echo's delay (24 ticks of 0.008333 s per cell); on every cell known wall a block
  0.92·s wide and 0.5·s high with dark faces and its 12 edges as strips 0.05·s thick; located beacons as pillars 0.3·s
  wide and 0.8·s high; and the energy gauge, a row of `energy` bars in front of the chamber at z = 1.0, y = 0, spread evenly from x = −0.9
  to 0.9 (each 1.8 / budget wide with a gap of a fifth of that, 0.06 deep), lit for the energy left (corrected at the
  checklist, 2026-11-23: the gauge's extent was added). Walls struck by the last pulse flare (brighter edges) when the pulse ring reaches their distance, fading
  over 0.5 s. Depth testing is on for floor, blocks and pillars; rings, rays and glow are additive and drawn last.
  Unknown cells draw nothing but the ground; unlocated beacons are never drawn. The camera is a fixed authored
  perspective from above and in front (eye (0, 2.4, 1.9) looking at (0, 0, 0.05)) fitted to the box x −1 … 1, z −1 … 1.1,
  y 0 … 0.8 with a 5 % margin for aspect 0.4 … 2.5, so it never moves while a level is played. Nothing drawn is
  consulted by the rules. Impact: FR-R02G1103-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): the pulse ring, every echo ring, flare trails on
  struck walls and 2 glow shells around edges and pillars; `level-1`: the pulse ring and the echo rings, no flare
  trails, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): no rings, no flares, no glow. Floor, walls, entry,
  markers, pillars, rays, colours, gauge and positions are the same at every tier. Levels are ordered richest first; the
  presenter logs each tier change with its reason. Impact: FR-R02G1103-004; SC-R02G1103-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects every known-open
  cell's centre, every known wall's top-face centre, the entry, every marker's centre and the gauge's first bar through
  the same camera and gives the palette. Simulator tests render offscreen at 1,152 × 768 and check, at points at least 6
  pixels from any other element, that a floor-tile centre differs from the ground by at least 0.1 in luminance; that a
  wall's top-face centre differs from the ground by at least 0.08 with green above red by at least 0.05 (mint); that
  the gauge's first bar differs from the ground by at least 0.1; and that the background matches the ground within 0.05
  away from geometry. Palette: ground #05070A, floor tile #3A4A46, wall face #12302A, wall edge #3DF5C4, flare #B8FFF0,
  pulse and rays #5FF7FF, entry #CFE3DD, marker #E8F1EE, pillar #5FF7FF, glow #9FFFF7, lit gauge bar #3DF5C4, unlit
  gauge bar #1E2A2A. Impact: FR-R02G1103-006; SC-R02G1103-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `EchoCartographerSceneSnapshot` (the chamber size, the knowledge per cell, the entry, the markers, the located beacons'
  cells, the last pulse's echo report, stage, failure, energy, energy budget, level number and presentation time) made
  by the adapter; it never holds the kernel, and the snapshot holds no unknown wall and no unlocated beacon. If a program
  fails to compile or link, the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps
  `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion draws the rings and flares at rest
  (no rings, the struck walls at their resting brightness); Reduce Flashing caps the glow gain. An energy failure shows
  the empty gauge and the failure text names the action, as the kernel's reason does. Impact: FR-R02G1103-003, 007;
  SC-R02G1103-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g11.echo-cartographer` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/EchoCartographer/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `EchoCartographerExperience` as a candidate (`available: false` until X-R02-G11), opening at
  seed 0 (level 1); `AppModelTests` switches its unregistered example to the next round-two game
  (`r02-g12.harmonic-bridges`). The adapter (`EchoCartographerExperienceCore`) prepares certified level (seed mod 100) +
  1 from its table of certified candidates (the whole generator only if that candidate no longer certifies) and accepts
  `cell.pulse [x, y]`, `cell.claim [x, y]`, `cell.mark [x, y]`, `play.undo`, `play.redo` and `level.next` (whole
  numbers only); the kernel refuses everything out of range or out of stage; its digest is the level number and the
  play's fingerprint (never the record history, so undo restores the earlier digest); snapshot schema 1
  `{level, records}`. The panel's cursor (column, row) is presentation state of the controls, not kernel state: a level
  opens with the cursor on the entry, and it stays clamped to the chamber. Impact: FR-R02G1103-005, 008, 009;
  SC-R02G1103-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See a dark temple crystallize into wireframe in expanding cyan light (Priority: P1) 🎯

A player opens Echo Cartographer and sees an abyss-black chamber seen from above at an angle. Only what the player has
learned is drawn: the known floor as faint opal tiles, the known walls as sonar-mint wireframe blocks, the entry and
the markers. When a pulse is sent, a cyan ring of light expands from the emitter over the floor, the rays run out to the
walls they strike, and those walls flare into bright wireframe as the light reaches them; the echoes' delays show as
rings that return. Located beacons stand as glowing pillars; a gauge shows the energy left.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose known walls,
known floor, entry, markers and gauge are where a CPU reference of the same snapshot says they are, in the stated
colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose wall, floor and
   marker pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the revealed cells, the markers,
   the located beacons and the gauge follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game and never reveals the hidden (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and it never draws a wall the
player has not revealed or a beacon the player has not located.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback; the geometry of a snapshot contains no unknown wall and no
unlocated beacon.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer pulse rings, no wall flare trails and no glow but keeps the same objective,
cells, markers, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the known walls, the known floor, the markers and the gauge at the same
places; only rings, trails and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole chamber and the gauge with a margin of at least 5 % on each
  side.
- **Colour-blind players:** walls are raised wireframe blocks, the floor is flat tiles, the entry is a diamond, markers
  are rings, located beacons are pillars, the gauge is a row of bars; every cell, echo and measure can be named in words
  by the kernel, so no information is carried by hue only.
- **A failure (energy exhausted):** the gauge is empty and the failure shown names the action, as the kernel's reason
  does.
- **A won level:** every beacon stands as a pillar and the chamber's known walls brighten; the frame checks use the same
  cells.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the pulse rings and wall flares are drawn at rest (the final revealed state) instead of animating;
  Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1103-001**: The experience MUST render the known floor as tiles, the known walls as wireframe blocks
  (instanced edge strips), the entry, the markers, the located beacons, the last pulse's rings and rays and the energy
  gauge entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1103-002**: Materials MUST show an abyss-black ground, sonar-mint wireframe walls that flare in an expanding
  cyan pulse of light, opal floor tiles and marker colours, computed in shaders; every element also has its shape or
  pattern.
- **FR-R02G1103-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict; nothing hidden (unknown walls, unlocated beacons)
  may be drawn.
- **FR-R02G1103-004**: The experience MUST offer three quality tiers that change only pulse rings, flare trails and
  glow, never cells, markers, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G1103-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for pulse, claim, mark, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G11-02.
- **FR-R02G1103-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1103-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1103-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1103-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the chamber size, the knowledge per cell, the entry, the markers, the located beacons, the last
  pulse (emitter, rays, echoes), the stage, failure, energy, level number and presentation time.
- **Chamber geometry**: the ground, the floor tiles, the wall blocks with their edge strips, the entry, the markers, the
  pillars, the pulse rings and rays and the energy gauge.
- **Quality tier**: 0, 1 or 2, with its rings, trails and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1103-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: wall, floor
  and marker positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1103-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict, and no snapshot's geometry contains an unknown wall or an unlocated beacon.
- **SC-R02G1103-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1103-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1103-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1103-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (tap to emit, drag markers, orbit) are R02-G11-04; hints and progression R02-G11-05; accessibility and
  polish R02-G11-06; persistence R02-G11-07. This feature gives the experience a minimal control panel (column −/+, row
  −/+, pulse, claim, mark, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "SDF primitives"
  is read as signed-distance shading of the blocks, tiles and rings in the fragment shaders; the geometry is generated
  meshes.
- Like Backwards Aurora, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G11-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G11-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (SDF primitives plus instanced wireframe edge strips) | FR-R02G1103-001 |
| Signature shader (signed-distance chamber topology, instanced wireframe surfaces, expanding normal-aware echo waves) and palette (abyss black, sonar mint and opal) | FR-R02G1103-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1103-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1103-004 |
| Renderer purity, stability | FR-R02G1103-003; SC-R02G1103-002, 003 |
| Real render captures | FR-R02G1103-006 |
| "Register it in the catalog" (override) | FR-R02G1103-008 |
| No Stage One breakage | FR-R02G1103-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G11.
