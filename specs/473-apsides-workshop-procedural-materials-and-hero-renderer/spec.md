# Feature Specification: R02-G18-03 — Apsides Workshop: procedural materials and hero renderer

**Feature Branch**: `473-apsides-workshop-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-25

**Status**: Draft

**Ledger gate**: R02-G18-03 (migration ledger, game feature of experience R02-G18) · ID namespace FR-R02G1803-###,
SC-R02G1803-###, T-R02G1803-###

**Input**: User description: the archived R02-G18-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Apsides Workshop (code-only hero:
"cosmic compass with loops of luminescent elliptical epicycles"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/473-apsides-workshop-procedural-materials-and-hero-renderer`; FR-R02G1803-###,
  SC-R02G1803-###, T-R02G1803-###.
- **Packaging (ADR-0009):** the source's `Apps/ApsidesWorkshop` becomes the experience target
  `ApsidesWorkshopExperience` (with its tests) in `Packages/ExperiencesRound02/ApsidesWorkshop/Experience` beside the
  existing `ApsidesWorkshopCore` (the source's `Packages/GameModules/ApsidesWorkshopCore`); the experience
  `r02-g18.apsides-workshop` (free) is registered in the catalog as a candidate (not available) and linked into the one
  app, as Celestial Eclipse Lab was at R02-G17-03; it becomes available only at its gate X-R02-G18.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 78" is a milestone figure — the catalog is
  the 100 certified levels of R02-G18-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G18-01 and -02.
- **Model:** feature 463 (Celestial Eclipse Lab's hero renderer and experience).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch the orbit trace luminous loops across the cosmic compass (Priority: P1) 🎯

A player opens Apsides Workshop and sees a star at the centre of a cosmic compass: eight sky sectors marked by spokes
and a graduated rim over a midnight sky. The orbit is drawn as a luminous elliptical loop through the orbiter's exact
positions, the area it sweeps glows in each sector it crosses, the periapsis and apoapsis are marked, exclusion planets
sit as procedural spheres, and gauges show each target's share or distance against its band.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose star, orbit,
orbiter, planets and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose star, orbit,
   planet and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the orbit loop and the orbiter
   move to the kernel's positions for the new orbit, the gauges show the new readings, and the win or failure shown
   matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown tick or rendering failure, the drawn image never changes
the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn orbit passes
through the kernel's exact integer positions.

**Why this priority**: the rules are exact integers on fixed-point orbits; a picture that decided anything would break
them.

**Independent Test**: changing tier, presentation time, shown tick and frame count never changes the kernel's digest; a
failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses flat discs and no glow but keeps the same objective, compass, orbit, planets, colours
and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the star, orbit, planets and gauges at the same places; only the shading
detail and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G18.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the compass, every orbit position and the gauges with a margin of at
  least 5 % on each side.
- **Colour-blind players:** each sector carries its number in notches on the rim, target sectors a bracket, the
  periapsis a diamond and the apoapsis a square, planets a hatched hazard ring, met targets a filled mark and unmet ones
  a hollow one, and actions a row of bars; every sector, target, planet and measure can be named in words by the
  kernel, so no information is carried by hue only.
- **A failure (contact, order, share, apsis sector or apsis distance):** the failing element is marked in the broken
  colour (the struck planet and the segment, or the failing target's gauge); the failure shown names it, as the
  kernel's reason does.
- **A won level:** every target mark is lit and the orbit loop glows fully; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** nothing moves by itself (the shown tick never advances by time); Reduce Flashing caps the glow to
  the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1803-001**: The experience MUST render the star, the cosmic compass (sector spokes and graduated rim), the
  orbit loop through the kernel's positions, the orbiter at the shown tick, the swept-area glow, the apsis markers, the
  exclusion planets and the gauges entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1803-002**: Materials MUST show a midnight sky with a procedural starfield, a glacial-white luminous orbit
  with deep-rose accents, procedurally shaded planets and an emissive star, computed in shaders; every element also has
  its shape or pattern.
- **FR-R02G1803-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown tick or failure may change the kernel's state, digest or verdict.
- **FR-R02G1803-004**: The experience MUST offer three quality tiers that change only shading detail and glow, never the
  compass, orbit, planets, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G1803-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for the periapsis knob, the size, playing the revolution, undo, redo, next level and the shown tick, digest,
  snapshot and restore), opening certified levels of R02-G18-02.
- **FR-R02G1803-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1803-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1803-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1803-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the orbit's positions for the current orbit, the orbiter's position at the shown tick, the sector
  shares, the apsis readings, the planets, the targets with their bands and deviations, the starting orbit's positions
  (its ghost loop), stage, failure, actions left, budget, level number, shown tick and presentation time.
- **Compass geometry**: the star, the sector spokes and rim, the orbit loop, the swept-area wedges, the apsis markers,
  the planets and the gauges.
- **Quality tier**: 0, 1 or 2, with its shading detail and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1803-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: star, orbit,
  planet and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1803-002**: Across 200 seeded snapshots, tier changes, time steps, shown-tick changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G1803-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1803-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1803-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1803-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag the periapsis knob and the semi-major axis, turn the time crank) are R02-G18-04; hints and progression
  R02-G18-05; accessibility and polish R02-G18-06; persistence R02-G18-07. This feature gives the experience a minimal
  control panel (eccentricity −/+, direction −/+, size −/+, tick −/+, play, undo, redo, next level, each labelled) so it
  can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. The "cosmic
  compass with loops of luminescent elliptical epicycles" is read as the compass of the eight sectors around the star
  with the orbit drawn as a luminous elliptical loop and the starting orbit as a faint ghost loop at a different depth;
  "adaptive analytic ellipse tessellation" is a ribbon through the kernel's exact positions, refined between ticks along
  the same ellipse for smoothness, the judged chords being the kernel's.
- Like Celestial Eclipse Lab, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G18-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G18-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g19.microscopic-aurora`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (adaptive analytic ellipse tessellation) | FR-R02G1803-001 |
| Signature shader (celestial paths trace luminous ellipses at varying depths; analytic orbit curves, procedural planets and starfields) and palette (glacial white, deep rose and midnight) | FR-R02G1803-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1803-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1803-004 |
| Renderer purity, stability | FR-R02G1803-003; SC-R02G1803-002, 003 |
| Real render captures | FR-R02G1803-006 |
| "Register it in the catalog" (override) | FR-R02G1803-008 |
| No Stage One breakage | FR-R02G1803-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G18.
