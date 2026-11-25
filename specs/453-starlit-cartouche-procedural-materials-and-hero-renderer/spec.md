# Feature Specification: R02-G16-03 — Starlit Cartouche: procedural materials and hero renderer

**Feature Branch**: `453-starlit-cartouche-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G16-03 (migration ledger, game feature of experience R02-G16) · ID namespace FR-R02G1603-###,
SC-R02G1603-###, T-R02G1603-###

**Input**: User description: the archived R02-G16-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Starlit Cartouche (code-only
hero: "sapphire ship leaving comet-calligraphy across a rotating firmament"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/453-starlit-cartouche-procedural-materials-and-hero-renderer`;
  FR-R02G1603-###, SC-R02G1603-###, T-R02G1603-###.
- **Packaging (ADR-0009):** the source's `Apps/StarlitCartouche` becomes the experience target
  `StarlitCartoucheExperience` (with its tests) in `Packages/ExperiencesRound02/StarlitCartouche/Experience` beside the
  existing `StarlitCartoucheCore` (the source's `Packages/GameModules/StarlitCartoucheCore`); the experience
  `r02-g16.starlit-cartouche` (free) is registered in the catalog as a candidate (not available) and linked into the one
  app, as Voxel Origami was at R02-G15-03; it becomes available only at its gate X-R02-G16.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 80" is a milestone figure — the catalog is
  the 100 certified levels of R02-G16-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G16-01 and -02.
- **Model:** feature 443 (Voxel Origami's hero renderer and experience).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch a sapphire ship write comet-calligraphy across the star chart (Priority: P1) 🎯

A player opens Starlit Cartouche and sees a deep-ultramarine firmament turning slowly behind a chart of pearl stars on
their orbits, joined by faint corridors. A sapphire ship waits at its star; each flown leg leaves a meteor-gold trail
like a brush stroke, hazard tubes glow on their corridors while they are active, and a small cartouche beside the chart
shows the target symbol and the strokes drawn so far. When the symbol is complete and the ship reaches the beacon, the
trails flare and the cartouche seals.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose stars, ship,
trails, cartouche and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose star, ship, trail,
   cartouche and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the stars move to their orbit
   positions at the new beat, the ship and trails follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, firmament rotation or rendering failure, the drawn image
never changes the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn
stars sit at the kernel's exact orbit positions for the current beat.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses plain star discs, no trail blur and no glow but keeps the same objective, stars,
corridors, trails, cartouche, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the stars, ship, trails, cartouche and gauges at the same places; only the
star shading detail, trail blur and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every star's orbit, the cartouche and the gauges with a margin of at
  least 5 % on each side.
- **Colour-blind players:** each star carries its glyph point as a small mark, the ship has a distinct arrow shape, the
  beacon a ring, flown trails a solid stroke and unflown symbol corridors a dashed line, hazards a striped tube, and
  windows and the deadline are rows of shapes; every star, corridor and measure can be named in words by the kernel, so
  no information is carried by hue only.
- **A failure (departure window, hazard, arrival window, deadline or stroke):** the failing leg is drawn in the broken
  colour and the star, hazard or corridor concerned is marked; the gauges show what was reached and the failure shown
  names it, as the kernel's reason does.
- **A won level:** every symbol trail is lit and the cartouche seals; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the firmament does not turn and stars jump to their positions without gliding; Reduce Flashing caps
  the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1603-001**: The experience MUST render the stars as generated sphere meshes at their orbit positions for the
  current beat, the corridors, the flown trails as generated polyline ribbons, the hazard tubes, the ship, the beacon,
  the cartouche and the gauges entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1603-002**: Materials MUST show a deep-ultramarine firmament, pearl stars with procedural layered shading, a
  sapphire ship and meteor-gold trails, computed in shaders; every element also has its shape or pattern.
- **FR-R02G1603-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, rotation or failure may change the kernel's state, digest or verdict.
- **FR-R02G1603-004**: The experience MUST offer three quality tiers that change only star shading detail, trail blur
  and glow, never stars, corridors, trails, colours, objective or indicators; the selected tier and the reason MUST be
  logged.
- **FR-R02G1603-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for flying a leg, undo, redo, next level and choosing the shown destination and wait, digest, snapshot and
  restore), opening certified levels of R02-G16-02.
- **FR-R02G1603-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1603-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1603-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1603-009**: Existing tests MUST pass unchanged except where a test names the next unregistered
  candidate; every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the stars (positions at the current beat, glyph points, windows), the corridors, the hazards
  and which are active, the flown legs, the drawn strokes and the symbol, the ship's star and beat, the beacon, the
  deadline, the chosen destination and wait, stage, failure, actions left, budget, level number and presentation time.
- **Chart geometry**: the star spheres, corridor lines, trail ribbons, hazard tubes, the ship, the beacon ring, the
  cartouche and the gauges.
- **Quality tier**: 0, 1 or 2, with its star shading detail, trail blur and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1603-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: star, ship,
  trail, cartouche and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1603-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G1603-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1603-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1603-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1603-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (tap a star to queue a leg, drag the time slider, the gliding route preview, orbit) are R02-G16-04; hints and
  progression R02-G16-05; accessibility and polish R02-G16-06; persistence R02-G16-07. This feature gives the
  experience a minimal control panel (destination −/+, wait −/+, fly, undo, redo, next level, each labelled) so it can
  be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Procedural star
  spheres and motion-blurred polyline trails" are generated meshes at the kernel's exact orbit positions; "luminous
  paths across three-dimensional star charts" are the flown legs drawn as trails, so the route seen is always the route
  judged. The rotating firmament is a backdrop only; the chart itself does not turn with it.
- Like Voxel Origami, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G16-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G16-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g17.celestial-eclipse-lab`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (procedural star spheres and motion-blurred polyline trails) | FR-R02G1603-001 |
| Signature shader (luminous paths across three-dimensional star charts; layered star spheres and emission shaders) and palette (deep ultramarine, meteor gold and pearl) | FR-R02G1603-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1603-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1603-004 |
| Renderer purity, stability | FR-R02G1603-003; SC-R02G1603-002, 003 |
| Real render captures | FR-R02G1603-006 |
| "Register it in the catalog" (override) | FR-R02G1603-008 |
| No Stage One breakage | FR-R02G1603-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G16.
