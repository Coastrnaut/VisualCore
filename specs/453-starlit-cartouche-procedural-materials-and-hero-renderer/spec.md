# Feature Specification: R02-G16-03 — Starlit Cartouche: procedural materials and hero renderer

**Feature Branch**: `453-starlit-cartouche-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-24

**Status**: Clarified

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

## Clarifications

### Session 2026-11-24

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
443's answers where the games agree. Facts checked in code (read-only, 2026-11-24): Voxel Origami's experience
(R02-G15-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Starlit Cartouche kernel provides
the level (4 … 12 stars with lattice orbits, glyph points on a 5 × 5 grid and windows; the range; corridors with travel;
hazards with intervals; start, beacon, deadline, symbol and budget), the star position at a beat, the leg (from, to,
corridor, wait, depart, arrive), the failures (departure, hazard, arrival, deadline, stroke, budget), the route report
(star, beat, drawn, missing, stray, mismatch, clearance, matched), the play (leg, undo, redo, stages) and the certified
catalog of R02-G16-02 (5 … 10 stars, orbit coordinates −5 … 5); `AppModelTests` uses `r02-g16.starlit-cartouche` as its
synthetic unregistered candidate and the next round-two game is `r02-g17.celestial-eclipse-lab`; the archived matrix has
80 acceptance rows R2-G16-QA-001 … 080; the catalog's design gives the palette "deep ultramarine, meteor gold and
pearl", the hero "sapphire ship leaving comet-calligraphy across a rotating firmament" and the geometry "procedural star
spheres and motion-blurred polyline trails".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: lattice positions map to world space
  by w(v) = (v − m) · s, where m is the centre of the bounding box of every orbit position of every star (so no star
  leaves the frame at any beat) and s = 1.5 / (e + 1) with e the box's largest extent; y is up. Stars are drawn at
  w(position(at: beat)) for the play's current beat. Drawn back to front by distance from the eye (depth testing off,
  the shared mesh renderer's path; ties broken by kind — corridors, hazards, trails, stars, ship and beacon, gauges —
  then by index): the firmament backdrop (a large quad; a vertical gradient from night #0A1240 at the bottom to night
  top #141E5C at the top with sparse procedural specks covering under 5 % of its pixels, turning about the vertical axis
  at 0.02 radians per second of presentation time — a backdrop only, the chart never turns); the corridors, a ribbon
  0.02 wide between the two stars' current positions, symbol corridors not yet drawn dashed pearl, other corridors
  faint; the hazard tubes, a striped ribbon 0.06 wide along their corridor, coral while active (from ≤ beat ≤ to), dim
  otherwise; the trails, one ribbon 0.05 wide per flown leg from w of the from-star's position at departure to w of the
  to-star's position at arrival, meteor gold; the stars, spheres of radius 0.07 at their positions, pearl, each with
  (index mod 6) + 1 notches on a ring around it; the ship, a sapphire arrow of length 0.14 at its star, pointing along
  its last trail (toward +x before the first leg); the beacon ring of radius 0.12 around the beacon star; the chosen
  destination's dashed sapphire ring of radius 0.1; the gauges in screen-facing world space below the chart: the
  cartouche, a 5 × 5 grid 0.5 wide centred at (−0.5, −1.2) in which every symbol corridor is a line between its two
  stars' glyph points, dashed pearl until drawn and solid gold once drawn; the actions bars, `budget` bars at y = −1.05
  from x = 0.0 to 0.9 (each 0.9 / budget wide with a gap of a fifth, 0.04 tall), lit for the actions left; the beat
  track at y = −1.2 from x = 0.0 to 0.9, filled to beat / deadline; the wait pips, 9 pips at y = −1.35 from x = 0.0 to
  0.9, lit up to the chosen wait. The glow is additive and drawn last. After a leg the ship glides along its new trail
  over 0.5 s of presentation time (presentation only; Reduce Motion places it at once). The chosen destination and wait
  are presentation state of the adapter (`route.choose [star, wait]`, never in the digest), at opening the other end of
  the lowest-index corridor from the start star with wait 0. The camera is a fixed authored perspective (eye (1.2, 1.0,
  2.8) looking at (0, −0.2, 0)) fitted to the box x −0.95 … 0.95, y −1.45 … 0.95, z −0.95 … 0.95 with a 5 % margin for
  aspect 0.4 … 2.5. Nothing drawn is consulted by the rules. Impact: FR-R02G1603-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): star spheres of 16 × 12 segments with layered
  shading (core, limb and corona), 3 motion-blur ghosts trailing each trail's end and 2 glow shells around the stars,
  the ship and lit trails; `level-1`: 12 × 8 segments, 1 ghost, 1 glow shell; `level-2` (the design's "Tier 0,
  D3-safe"): flat screen-facing 12-sided star discs, no ghosts, no glow. Stars, corridors, hazards, trails, the ship,
  the beacon, the cartouche, gauges, colours and positions are the same at every tier. Levels are ordered richest first;
  the presenter logs each tier change with its reason. Impact: FR-R02G1603-004; SC-R02G1603-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera every star's centre, the ship's centre, the midpoint of every trail, the cartouche centre and the first
  actions bar, orders them by camera distance as the painter does, and gives the palette. Simulator tests render
  offscreen at 1,152 × 768 at time 0 and check, at points at least 6 pixels from every element drawn after them, that a
  star's centre is brighter than the backdrop by at least 0.25 in luminance; that the ship's centre has blue above red
  by at least 0.08 (sapphire); that a trail's midpoint has red above blue by at least 0.08 (gold); that the first
  actions bar differs from the backdrop by at least 0.1; and that the median of a 9 × 9 pixel patch of backdrop away
  from geometry matches the gradient colour at its height within 0.06 (the median ignores the sparse specks). Palette:
  night #0A1240, night top #141E5C, speck #C9D2FF, pearl #F2EEE6, pearl shade #B8C0D8, corridor #3A4478, symbol dash
  #C9CCE0, trail gold #F5B83D, trail glow #FFE3A0, ship #2F6BFF, ship glow #8FB0FF, beacon #F2EEE6, chosen #2F6BFF,
  hazard active #FF5A5F, hazard idle #5A3A58, actions lit #F5B83D, actions unlit #283058, beat track #8FB0FF, wait lit
  #2F6BFF, wait unlit #283058, broken #FF6B4A, glow #FFF4E0. Impact: FR-R02G1603-006; SC-R02G1603-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `StarlitCartoucheSceneSnapshot` (the stars' positions at the beat, glyph points and windows; the corridors and travel;
  the hazards and which are active; the flown legs with the positions at their departure and arrival; the drawn strokes
  and the symbol; the ship's star and beat; the beacon; the deadline; the chosen destination and wait; the route report;
  stage, failure, actions left, budget, level number and presentation time) made by the adapter; it never holds the
  kernel. If a program fails to compile or link, the scene draws the level-2 geometry unlit with the shared unlit mesh
  renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion stops the
  firmament turning and the ship's glide; Reduce Flashing caps the glow gain. A failure draws the failing leg
  (recomputed through the chart from the last record's action, since a window or deadline failure names no corridor; the
  ship stays at its star) in the broken colour and marks what failed (the star whose window was missed, the hazard met,
  or the stray stroke; a deadline or budget failure marks the beat track or the actions bars), and the failure text
  names it, as the kernel's reason does. Impact: FR-R02G1603-003, 007; SC-R02G1603-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g16.starlit-cartouche` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/StarlitCartouche/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `StarlitCartoucheExperience` as a candidate (`available: false` until X-R02-G16), opening at
  seed 0 (level 1); `AppModelTests` switches its synthetic unregistered candidate to the next round-two game
  (`r02-g17.celestial-eclipse-lab`). The adapter (`StarlitCartoucheExperienceCore`) prepares certified level (seed mod
  100) + 1 from its table of certified candidates (the whole generator only if that candidate no longer certifies) and
  accepts `route.fly [star, wait]`, `play.undo`, `play.redo`, `level.next` and `route.choose [star, wait]` (whole
  numbers only); the kernel refuses everything out of range or out of stage, and `route.choose` refuses a star the
  level does not have, the ship's own star or a wait outside 0 … 8; its digest is the level number and the play's
  fingerprint (never the record history or the chosen destination, so undo restores the earlier digest); snapshot
  schema 1 `{level, records}`. Impact: FR-R02G1603-005, 008, 009; SC-R02G1603-004.

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
- **Colour-blind players:** each star carries (index mod 6) + 1 notches on its ring, the ship has a distinct arrow
  shape, the beacon a ring, the chosen destination a dashed ring, drawn strokes a solid line and undrawn symbol strokes
  a dashed one, hazards a striped tube, and actions, the beat and the wait are rows of shapes; every star, corridor and
  measure can be named in words by the kernel, so no information is carried by hue only.
- **A failure (departure window, hazard, arrival window, deadline, stroke or budget):** the failing corridor is drawn
  in the broken colour and what failed is marked (the star, the hazard, the stray stroke, the beat track or the actions
  bars); the gauges show what was reached and the failure shown
  names it, as the kernel's reason does.
- **A won level:** every symbol trail is lit and the cartouche seals; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the firmament does not turn and the ship is placed at its star without gliding; Reduce Flashing
  caps the glow to the shared limit.

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
