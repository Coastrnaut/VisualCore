# Feature Specification: R02-G05-03 — Colorfall Canyons: procedural materials and hero renderer

**Feature Branch**: `343-colorfall-canyons-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Draft

**Ledger gate**: R02-G05-03 (migration ledger, game feature of experience R02-G05) · ID namespace FR-R02G0503-###,
SC-R02G0503-###, T-R02G0503-###

**Input**: User description: the archived R02-G05-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Colorfall Canyons (code-only hero:
"liquid neon waterfalls carving bright channels across miniature mesa terrain"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/343-colorfall-canyons-procedural-materials-and-hero-renderer`; FR-R02G0503-###,
  SC-R02G0503-###, T-R02G0503-###.
- **Packaging (ADR-0009):** the source's `Apps/ColorfallCanyons` becomes the experience target
  `ColorfallCanyonsExperience` (with its tests) in `Packages/ExperiencesRound02/ColorfallCanyons/Experience` beside the
  existing `ColorfallCanyonsCore`; the experience `r02-g05.colorfall-canyons` (free) is registered in the catalog as a
  candidate (not available) and linked into the one app, as Hue Compass was at R02-G04-03; it becomes available only at
  its gate X-R02-G05.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 100" is met by the certified levels of
  R02-G05-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as `{device}` tasks for after
  ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues), R02-F18 (procedural terrain) and the shared custom-shader mesh renderer added at R02-G01-03, through
  the existing VisualCore packages; the kernel and certified levels of R02-G05-01 and -02.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the neon canyon (Priority: P1) 🎯

A player opens Colorfall Canyons and sees a miniature mesa terrain of stepped canyon cells, springs glowing at the top,
basins and drains below, and liquid neon in cyan, coral and yellow running down bright channels into the basins as time
runs.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose terrain, springs,
basins and fluid are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose terrain, spring and
   basin pixels match the CPU reference within stated bounds.
2. **Given** a carve, valve toggle or time step from the rule kernel, **When** the next frame is drawn, **Then** the
   terrain heights, channels and fluid follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity is a certification invariant.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed shader
leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses less terrain detail, fewer flow bands and no glow but keeps the same objective, cells,
colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the cells, springs, basins and fluid at the same places; only subdivision,
flow bands and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole terrain with a margin.
- **Colour-blind players:** each colour of fluid also carries a distinct pattern, and every basin shows its required mix
  with the same patterns, so no information is carried by hue only.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the flow bands stand still; Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0503-001**: The experience MUST render the terrain (each cell's height, rock, drains), the springs, the basins
  and the fluid in every cell entirely from generated geometry and shader code, with no image assets.
- **FR-R02G0503-002**: Materials MUST show layered mesa rock with generated normals, glowing springs, neon fluid whose
  colour is the mix of its three colour masses and whose brightness follows its volume, flow bands along each cell's
  downhill direction, and an emissive glow, computed in shaders; every fluid colour also has a pattern.
- **FR-R02G0503-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G0503-004**: The experience MUST offer three quality tiers that change only terrain subdivision, flow bands and
  glow, never cells, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0503-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for carves, valve toggles, time steps, undo, redo and next level, digest, snapshot and restore), opening
  certified levels of R02-G05-02.
- **FR-R02G0503-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0503-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0503-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0503-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the level's grid, current heights, grounds, springs (cell, colour, valve, supply left), basins
  (cell, targets), every cell's colour masses, downhill directions, stage, failure, tick and presentation time.
- **Canyon geometry**: terrain blocks, spring emitters, basin rims, drains, fluid sheets and flow bands.
- **Quality tier**: 0, 1 or 2, with its subdivision, flow bands and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0503-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: terrain,
  spring and basin pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0503-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0503-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0503-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0503-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0503-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (dragging sluice edits, tapping valves, orbit) are R02-G05-04; hints and progression R02-G05-05; accessibility
  and polish R02-G05-06; persistence R02-G05-07. This feature gives the experience a minimal control panel (a cell picker
  and carve, a valve per spring, step 1 and step 10 ticks, run to the end, undo, redo, next level, each labelled) so it
  can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Hue Compass, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`, fixtures and
  the 80 acceptance scenarios of the archived matrix (R2-G05-QA-001 … 080), and its registration carries the content
  facts (100 levels and the pinned catalog digest).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (heightfield mesh, generated normals, flow-map bands) | FR-R02G0503-001 |
| Signature shader (heightfield canyons, spectral dye, flow-map water) and palette | FR-R02G0503-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0503-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0503-004 |
| Renderer purity, stability | FR-R02G0503-003; SC-R02G0503-002, 003 |
| Real render captures | FR-R02G0503-006 |
| "Register it in the catalog" (override) | FR-R02G0503-008 |
| No Stage One breakage | FR-R02G0503-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G05.
