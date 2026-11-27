# Feature Specification: R02-G20-03 — Mushroom Weather: procedural materials and hero renderer

**Feature Branch**: `493-mushroom-weather-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-26

**Status**: Clarified

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

## Clarifications

### Session 2026-11-26

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
483's answers where the games agree. Facts checked in code (read-only, 2026-11-26): Microscopic Aurora's experience as
recorded at R02-G19-03 is the pattern in this package — a Core adapter with a table of certified candidate indices, an
immutable scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Mushroom Weather kernel provides
the level (rows, columns, blocked cells, humidity, vents, pod rules, colonies with bands and floors, M, T, K, sites,
budget), the run's integer humidity per cycle (`MushroomWeatherForest.run(…, keepFields: true)`), the report (ledger,
growth cycles, colony runs, failure: dried, mold, unstable), the play (place, remove, vent, moonlight, run, undo, redo,
stages) and the certified catalog of R02-G20-02 (6 … 9 by 6 … 10 cells, 2 … 5 colonies, 1 … 3 vents, 4 … 6 sites, runs
of 30 … 40 cycles); `AppModelTests` uses `r02-g20.mushroom-weather` as its synthetic unregistered candidate and the next
round-two game is `r02-g21.binary-gardens`; the archived matrix has 80 acceptance rows R2-G20-QA-001 … 080; the
catalog's design gives the palette "fern jade, amber spores and deep blue", the hero "glowing umbrella caps breathing
droplets into a midnight miniature forest" and the geometry "procedural lathed stalks and SDF mushroom caps".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the floor plane is z = 0; cell (r, c)
  of a level with R rows and C columns has its centre at world ((c − (C − 1)/2) · s, ((R − 1)/2 − r) · s, 0) with
  s = min(1.8 / C, 1.6 / R), so every level fills the same box (one rule for every level); y is up the floor. Drawn in
  this order with depth testing on for the solid parts: the backdrop (a large quad behind the floor; a vertical gradient
  from midnight #050A1A at the bottom to midnight top #0E1A33 at the top, still); the moon (a disc of radius 0.12 at
  (1.15, 1.05, −0.5), moon #E8EEF7, its brightness (4 + L)/7 and four phase ticks around it with L + 1 filled); the
  floor cells (a square of side 0.96 s per floor cell, moss #12261C); the blocked cells (a log — a rounded box 0.8 s long
  — when r + c is even, otherwise a stone — a low dome 0.36 s in radius; log #2A2118); the fronds (at the two richer
  tiers only: small L-system fronds of three generations on blocked cells and along the floor's edge, reaching at most
  0.3 s from their root, frond #1F4A33, decoration only); the mist (per floor cell a translucent square at height 0.02,
  side s · (0.2 + 0.7 · min(1, h/M)) for the humidity h at the shown cycle, shaded from mist low #0B1E4A to mist high
  #3A6FD8 by h/M — size and shade both carry the value); the sites (a ring of radius 0.32 s on the floor, site
  #C9A15A); the colonies (a lathed stalk 0.35 s tall and a lathed umbrella cap of radius 0.42 s on top, cap #5FD3A0 when
  the colony is in band at the shown cycle, cap out #3F6E5A otherwise, with a band ring — solid in band, dashed out — on
  the floor around the stalk, stalk #D8E6D0; the cap's fragment shader adds an SDF sparkle of moisture beads whose
  density follows h/M); the pods (a lathed amber orb of radius 0.18 s, 0.26 s once grown with a second ring, pod
  #F2A93B, at height 0.1 s); the droplets (amber motes rising from each pod on fixed paths by presentation time, droplet
  #FFC861, decoration only); the vents (a slatted frame of side 0.9 s at height 0.9 s over the vent cell; slats tilted
  open or flat shut; vent #6E8B7A); the gauges below the floor, one row per colony from y = −1.0 down in steps of 0.07: a
  track from x = −0.9 to 0.9 mapping 0 … M with a band bracket over low … high (band #9FF5C8) and a marker at the
  humidity at the shown cycle (marker #F2A93B), and to its right a run bar of K segments lit for the colony's final run;
  the actions bars, `budget` bars at y = −1.0 − 0.07 · (colonies) − 0.05 (each 1.8 / budget wide with a gap of a fifth,
  0.04 tall), lit for the actions left. The glow is additive and drawn last. The field shown is the predicted run of the
  current arrangement; the shown cycle is presentation state of the adapter (`clock.show [cycle]`, 0 … cycles run, never
  in the digest), 0 at opening and never advanced by time. The camera is a fixed authored perspective (eye (0, −1.6,
  3.0) looking at (0, −0.2, 0)) fitted to the box x −1.3 … 1.3, y −1.5 … 1.2 with a 5 % margin for aspect 0.4 … 2.5.
  Nothing drawn is consulted by the rules. Impact: FR-R02G2003-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): lathed stalks, caps and pods of 16 segments with
  layered shading (translucent cap with rim light and the sparkle), 12 droplets per pod, fronds, 8 spore motes on a fixed
  loop and 2 glow shells around the caps and pods; `level-1`: 10 segments, 6 droplets, fronds, 4 motes, 1 glow shell;
  `level-2` (the design's "Tier 0, D3-safe"): flat caps and pods (screen-facing discs), no droplets, no fronds, no motes,
  no glow. The backdrop, moon, floor, blocked cells, mist, sites, vents, gauges, colours and positions are the same at
  every tier. Levels are ordered richest first; the presenter logs each tier change with its reason. Impact:
  FR-R02G2003-004; SC-R02G2003-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera the floor centre, every colony's cap centre, the moon centre, the first gauge track's centre and the first
  actions bar, and gives the palette. Simulator tests render offscreen at 1,152 × 768 at the shown cycle half the cycles
  run and check, at points at least 6 pixels from every element drawn after them, that each cap's centre is brighter
  than the floor (moss) by at least 0.2 in luminance (at least one cap is checked in every frame); that the moon's centre
  differs from the backdrop by at least 0.1; that the first actions bar (lit) has red above blue by at least 0.08
  (amber); that the first gauge track differs from the backdrop by at least 0.1; and that the median of a 9 × 9 pixel
  patch of backdrop in a lower corner matches the gradient colour at its height within 0.06. Palette: midnight #050A1A,
  midnight top #0E1A33, moon #E8EEF7, moss #12261C, log #2A2118, frond #1F4A33, mist low #0B1E4A, mist high #3A6FD8,
  site #C9A15A, stalk #D8E6D0, cap #5FD3A0, cap out #3F6E5A, pod #F2A93B, droplet #FFC861, vent #6E8B7A, band #9FF5C8,
  marker #F2A93B, actions lit #F2A93B, actions unlit #1A2A3A, broken #FF6B5E, glow #F7FFF9. Impact: FR-R02G2003-006;
  SC-R02G2003-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `MushroomWeatherSceneSnapshot` (the humidity field by cycle of the predicted run, the cycles run, the shown cycle, the
  floor and blocked cells, the colonies with bands, floors and runs, the pods with their growth cycles, the sites, the
  vents and their states, the moonlight, stage, failure, actions left, budget, level number and presentation time) made
  by the adapter; it never holds the kernel. If a program fails to compile or link, the scene draws the level-2
  geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its
  `tierLog`. Reduce Motion stops the droplets and motes (the field never moves by time already); Reduce Flashing caps
  the glow gain. A failure marks the failing element in the broken colour (dried: the colony's cap wilts flat and its
  band ring turns broken; mold: the moldy cell gets a broken patch; unstable: the named colony's gauge marker and run bar
  turn broken) and the failure text names it, as the kernel's reason does. Impact: FR-R02G2003-003, 007; SC-R02G2003-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g20.mushroom-weather` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette #050A1A,
  #5FD3A0, #F2A93B, #3A6FD8, #12261C, the scenario manifest `Packages/ExperiencesRound02/MushroomWeather/
  scenario-manifest.json`, no permissions, a summary of at most 300 characters, content facts: 100 levels and the pinned
  catalog digest of R02-G20-02); `project.yml` and the app's experience registry link `MushroomWeatherExperience` as a
  candidate (`available: false` until X-R02-G20), opening at seed 0 (level 1); `AppModelTests` switches its synthetic
  unregistered candidate to the next round-two game (`r02-g21.binary-gardens`). The adapter
  (`MushroomWeatherExperienceCore`) prepares certified level (seed mod 100) + 1 from its table of certified candidate
  indices (the whole catalog only if that candidate no longer certifies) and accepts `pod.place [slot, row, column]`,
  `pod.remove [slot]`, `vent.set [index, open]` (open 1, shut 0), `moon.set [level]`, `weather.run`, `play.undo`,
  `play.redo`, `level.next` and `clock.show [cycle]` (whole numbers only); the kernel refuses everything out of range or
  out of stage and `clock.show` refuses a cycle outside 0 … cycles run; its digest (domain
  `r02-g20.mushroom-weather.v1`) is the level number and the play's fingerprint (never the record history or the shown
  cycle, so undo restores the earlier digest); snapshot schema 1 `{level, records}`. Impact: FR-R02G2003-005, 008, 009;
  SC-R02G2003-004.

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
