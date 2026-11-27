# Feature Specification: R02-G20-03 — Mushroom Weather: procedural materials and hero renderer

**Feature Branch**: `493-mushroom-weather-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Draft

**Ledger gate**: R02-G20-03 (migration ledger, game feature of experience R02-G20) · ID namespace FR-R02G2003-###,
SC-R02G2003-###, T-R02G2003-###

**Input**: User description: the archived R02-G20-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Mushroom Weather (code-only
hero: "glowing umbrella caps breathing droplets into a midnight miniature forest"), with the canonical overrides of
ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/493-mushroom-weather-procedural-materials-and-hero-renderer`; FR-R02G2003-###,
  SC-R02G2003-###, T-R02G2003-###.
- **Packaging (ADR-0009):** the source's `Apps/MushroomWeather` becomes the experience target
  `MushroomWeatherExperience` (with its tests) in `Packages/ExperiencesRound02/MushroomWeather/Experience` beside the
  existing `MushroomWeatherCore` (the source's `Packages/GameModules/MushroomWeatherCore`); the experience
  `r02-g20.mushroom-weather` (free) is registered in the catalog as a candidate (not available) and linked into the one
  app, as Microscopic Aurora was at R02-G19-03; it becomes available only at its gate X-R02-G20.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 76" is a milestone figure — the catalog is
  the 100 certified levels of R02-G20-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G20-01 and -02.
- **Model:** feature 483 (Microscopic Aurora's hero renderer and experience).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch glowing caps breathe droplets into a midnight forest (Priority: P1) 🎯

A player opens Mushroom Weather and sees a midnight miniature forest floor: mossy cells and dark logs and stones,
mushroom colonies with translucent umbrella caps on lathed stalks, the pod sites, the canopy vents above some cells, and
a moon whose light sets the evaporation. Humidity shows as a deep-blue mist over each cell that rises and falls with the
weather; pods breathe amber droplets; caps glow fern jade when their colony is inside its band; gauges show each
colony's humidity against its band and its run of cycles in band.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose floor, caps,
pods, vents, mist and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose floor, cap, pod,
   vent and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the pods, vents, moonlight, the
   predicted humidity field and the gauges show the new report, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown cycle or rendering failure, the drawn image never changes
the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn humidity is the
kernel's exact integer field.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown cycle and frame count never changes the kernel's digest; a
failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses flat caps, no droplets and no glow but keeps the same objective, floor, colonies, pods,
vents, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the floor, caps, pods, vents and gauges at the same places; only the shading
detail, droplet count and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G20.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the floor and the gauges with a margin of at least 5 % on each side.
- **Colour-blind players:** colonies carry a cap with a band ring, pods a droplet mark, vents a slatted frame that is
  open or shut, blocked cells a log or stone shape, the mist a height as well as a shade, gauges a band bracket with a
  marker and a run bar; actions a row of bars; every cell, colony, pod, vent and measure can be named in words by the
  kernel, so no information is carried by hue only.
- **A failure (dried, mold, unstable):** the failing element is marked in the broken colour (the dried colony's cap
  wilts, the moldy cell shows a mold patch, the unstable colony's gauge is marked); the failure shown names it, as the
  kernel's reason does.
- **A won level:** every colony's cap glows in band; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** nothing moves by itself (the shown cycle never advances by time, droplets and the mist are still);
  Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2003-001**: The experience MUST render the forest floor and its cells, blocked cells, colonies (lathed stalks
  with SDF umbrella caps), pods, pod sites, vents, the moon, the humidity mist at the shown cycle and the gauges
  entirely from generated geometry and shader code, with no image assets.
- **FR-R02G2003-002**: Materials MUST show a midnight forest floor, translucent caps sparkling with moisture gradients,
  fern-jade glow, amber spore droplets and deep-blue mist, computed in shaders; every element also has its shape or
  pattern.
- **FR-R02G2003-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown cycle or failure may change the kernel's state, digest or verdict.
- **FR-R02G2003-004**: The experience MUST offer three quality tiers that change only shading detail, droplet count and
  glow, never the floor, colonies, pods, vents, humidity values, colours, objective or indicators; the selected tier and
  the reason MUST be logged.
- **FR-R02G2003-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for placing, moving and removing pods, setting vents and the moonlight, running the weather, undo, redo, next
  level and the shown cycle, digest, snapshot and restore), opening certified levels of R02-G20-02.
- **FR-R02G2003-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G2003-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G2003-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G2003-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the humidity field over the run, the shown cycle, the floor and blocked cells, the colonies with
  their bands and runs, the pods and their growth, the sites, the vents, the moonlight, stage, failure, actions left,
  budget, level number and presentation time.
- **Forest geometry**: the floor plane and cells, logs and stones, stalks and caps, pods and droplets, vents, the moon,
  the mist columns and the gauges.
- **Quality tier**: 0, 1 or 2, with its shading detail, droplet count and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2003-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: floor, cap,
  pod, vent and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G2003-002**: Across 200 seeded snapshots, tier changes, time steps, shown-cycle changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G2003-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G2003-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G2003-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G2003-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag spore pods, open or close canopy vents, shift moonlight intensity) are R02-G20-04; hints and
  progression R02-G20-05; accessibility and polish R02-G20-06; persistence R02-G20-07. This feature gives the experience
  a minimal control panel (a slot picker, site −/+, place, remove, vent toggles, moonlight −/+, cycle −/+, run, undo,
  redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Glowing umbrella
  caps breathing droplets into a midnight miniature forest" is read as colonies drawn as lathed stalks with SDF umbrella
  caps that glow when in band, pods releasing amber droplets, and a deep-blue humidity mist over the floor; "procedural
  lathed stalks and SDF mushroom caps" are the geometry; "L-system miniature flora" is read as small procedural fronds on
  blocked cells and at the floor's edge, decoration only; "deterministic boids" as a few drifting spore motes on a fixed
  path, decoration only; "simple water planes" as the still mist plane.
- Like Microscopic Aurora, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G20-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G20-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g21.binary-gardens`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (procedural lathed stalks and SDF mushroom caps) | FR-R02G2003-001 |
| Signature shader (translucent mushroom caps sparkle with moisture gradients; L-system miniature flora, deterministic boids, bioluminescence and simple water planes) and palette (fern jade, amber spores, deep blue) | FR-R02G2003-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G2003-003, 005 |
| Quality tiers 0/1/2 | FR-R02G2003-004 |
| Renderer purity, stability | FR-R02G2003-003; SC-R02G2003-002, 003 |
| Real render captures | FR-R02G2003-006 |
| "Register it in the catalog" (override) | FR-R02G2003-008 |
| No Stage One breakage | FR-R02G2003-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G20.
