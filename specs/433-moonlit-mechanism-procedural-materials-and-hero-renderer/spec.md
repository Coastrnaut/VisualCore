# Feature Specification: R02-G14-03 — Moonlit Mechanism: procedural materials and hero renderer

**Feature Branch**: `433-moonlit-mechanism-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Draft

**Ledger gate**: R02-G14-03 (migration ledger, game feature of experience R02-G14) · ID namespace FR-R02G1403-###,
SC-R02G1403-###, T-R02G1403-###

**Input**: User description: the archived R02-G14-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Moonlit Mechanism, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/433-moonlit-mechanism-procedural-materials-and-hero-renderer`;
  FR-R02G1403-###, SC-R02G1403-###, T-R02G1403-###.
- **Packaging (ADR-0009):** the source's `Apps/MoonlitMechanism` becomes the experience target
  `MoonlitMechanismExperience` (with its tests) in `Packages/ExperiencesRound02/MoonlitMechanism/Experience`
  beside the existing `MoonlitMechanismCore`; the experience `r02-g14.moonlit-mechanism` (free) is registered in
  the catalog as a candidate (not available) and linked into the one app, as Acoustic Constellator was at R02-G13-03; it
  becomes available only at its gate X-R02-G14.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 77" is a milestone figure — the catalog is
  the 100 certified levels of R02-G14-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G14-01 and -02.
- **Model:** feature 423 (Acoustic Constellator's hero renderer and experience).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch translucent clockwork cast moving ink shadows on a moonlit paper wall (Priority: P1) 🎯

A player opens Moonlit Mechanism and sees a train of translucent aged-gold gears standing before a lunar-blue lamp,
their teeth interlocking, each gear's solid blades casting ink shadows onto a softly lit paper wall behind. The wall
shows the current key frame's target symbol as a faint outline and any forbidden marks as small crossed cells; a
strip of key-frame cards shows which key frames are required and how many of their cells are covered. Turning the
handle turns the train and moves the shadows; raising the lamp slides each gear's shadow by its depth.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose gears, shadow
cells, target outline, forbidden marks and gauges are where a CPU reference of the same snapshot says they are, in the
stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose gear, shadow-cell,
   target and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the gear phases, the lamp, the
   shadows of the shown key frame and the gauges follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn shadows are the
kernel's exact cast cells, never a separately computed projection.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses no soft shadow edge and no glow and draws gears with fewer outline segments but keeps
the same objective, gears, shadow cells, target, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the gears, shadow cells, target outline and gauges at the same places;
only outline tessellation, the soft shadow edge and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every gear, the whole wall and the gauges with a margin of at least 5 % on
  each side.
- **Colour-blind players:** shadow cells are solid ink squares, target cells an outline, forbidden cells crossed marks,
  missing target cells a dotted outline and stray cells a hatched square; each gear carries a tooth-zero notch and the
  lamp a height ladder; key frames, alignment and moves are rows of shapes; every gear, cell and measure can be named in
  words by the kernel, so no information is carried by hue only.
- **A failure (jammed, forbidden, missing, stray or budget):** the jammed pair's meshing teeth, the forbidden cell or
  the key frame's missing and stray cells are outlined, the gauges show what was reached and the failure shown names it,
  as the kernel's reason does.
- **A won level:** every required key frame's card is lit and the wall glows; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** gears are drawn at their set-up phases without the turning preview; Reduce Flashing caps the glow
  to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1403-001**: The experience MUST render the gears as procedurally extruded toothed outlines with their solid
  blades, the paper wall, the shadow cells of the shown key frame, the target outline, forbidden marks, the lamp and the
  key-frame, alignment and moves gauges entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1403-002**: Materials MUST show translucent aged-gold gears, a lunar-blue lamp light, a warm paper wall and
  ink shadows, computed in shaders; every element also has its shape or pattern.
- **FR-R02G1403-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G1403-004**: The experience MUST offer three quality tiers that change only gear outline tessellation, the
  soft shadow edge and glow, never gears, shadow cells, targets, colours, objective or indicators; the selected tier and
  the reason MUST be logged.
- **FR-R02G1403-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for turn, re-seat, lamp, run, undo, redo, next level and choosing the shown key frame, digest, snapshot and
  restore), opening certified levels of R02-G14-02.
- **FR-R02G1403-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1403-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1403-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1403-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the gears (teeth, phases at the shown key frame, blades, depth, centre, slot tables), the lamp
  height and count, the wall size, the shown key frame and its cast, target and forbidden cells, the run report
  (alignment errors and per-key-frame counts), stage, failure, actions left, budget, level number and presentation time.
- **Clockwork geometry**: the wall, the gear outlines and blades, the shadow cells, the target outline, the forbidden
  marks, the lamp and the gauges.
- **Quality tier**: 0, 1 or 2, with its outline segments, soft shadow edge and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1403-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: gear,
  shadow-cell, target and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1403-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G1403-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1403-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1403-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1403-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (turn the handle, drag a gear, slide the lamp, scrub key frames, orbit) are R02-G14-04; hints and progression
  R02-G14-05; accessibility and polish R02-G14-06; persistence R02-G14-07. This feature gives the experience a minimal
  control panel (turn −/+, gear −/+, re-seat −/+, lamp −/+, key frame −/+, run, undo, redo, next level, each labelled) so
  it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Involute-inspired
  approximated gear outlines extruded procedurally" are generated meshes; "CPU polygonal 3D shadow projections, soft
  shadow approximation" is read as the kernel's exact cast cells drawn as wall quads with a shader-softened edge, so the
  shadow seen is always the shadow judged.
- Like Acoustic Constellator, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G14-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G14-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (involute-inspired gear outlines extruded procedurally) | FR-R02G1403-001 |
| Signature shader (interlocking shadow gears on a luminous paper wall; procedural solids, shadow projections, soft shadow approximation) and palette (aged gold, lunar blue, ink) | FR-R02G1403-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1403-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1403-004 |
| Renderer purity, stability | FR-R02G1403-003; SC-R02G1403-002, 003 |
| Real render captures | FR-R02G1403-006 |
| "Register it in the catalog" (override) | FR-R02G1403-008 |
| No Stage One breakage | FR-R02G1403-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G14.
