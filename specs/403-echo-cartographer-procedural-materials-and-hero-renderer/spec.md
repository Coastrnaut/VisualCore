# Feature Specification: R02-G11-03 — Echo Cartographer: procedural materials and hero renderer

**Feature Branch**: `403-echo-cartographer-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

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
