# Feature Specification: R02-G21-03 — Binary Gardens: procedural materials and hero renderer

**Feature Branch**: `503-binary-gardens-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-27

**Status**: Clarified

**Ledger gate**: R02-G21-03 (migration ledger, game feature of experience R02-G21) · ID namespace FR-R02G2103-###,
SC-R02G2103-###, T-R02G2103-###

**Input**: User description: the archived R02-G21-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Binary Gardens (code-only hero:
"two suns painting crossing sunrise bands over tiny flowering spheres"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/503-binary-gardens-procedural-materials-and-hero-renderer`; FR-R02G2103-###,
  SC-R02G2103-###, T-R02G2103-###.
- **Packaging (ADR-0009):** the source's `Apps/BinaryGardens` becomes the experience target `BinaryGardensExperience`
  (with its tests) in `Packages/ExperiencesRound02/BinaryGardens/Experience` beside the existing `BinaryGardensCore`
  (the source's `Packages/GameModules/BinaryGardensCore`); the experience `r02-g21.binary-gardens` (free) is registered
  in the catalog as a candidate (not available) and linked into the one app, as Mushroom Weather was at R02-G20-03; it
  becomes available only at its gate X-R02-G21.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 81" is a milestone figure — the catalog is
  the 100 certified levels of R02-G21-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F15 (orbit geometry:
  the analytic orbit curves are drawn from the kernel's own phase table), R02-F10 (quality tiers and non-colour clues)
  and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore packages; the kernel
  of R02-G21-01 and the certified levels of R02-G21-02 (this gate starts after R02-G21-02 is recorded).
- **Model:** feature 493 (Mushroom Weather's hero renderer and experience), itself modelled on feature 483.

## Clarifications

### Session 2026-11-27

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
493's answers where the games agree. Facts checked in code (read-only, 2026-11-27): Mushroom Weather's experience as
recorded at R02-G20-03 is the pattern in this package — a Core adapter with a table of certified candidate indices (each
witness's `skipped`), an immutable scene snapshot, a CPU projection reference, GLSL sources in the Core with material
codes in the uv stream (the shared `ShaderMeshRenderer` binds only position, normal and uv), an iOS-only experience
target (`…Experience.swift`, presenter, scene, controls), a presenter that declares frame `probes(_:)` (two backdrop
corners) and quality levels equal to the Core's `qualityTiers`, a fallback through the shared unlit mesh renderer with
`fallbackReason` and `tierLog`, a scenario manifest with 80 acceptance scenarios and a registration with content facts in
`Catalog/registrations.json`; its research R3 records the lesson that the window surface of the shared renderer has no
depth buffer, so everything is drawn in painter's order with depth testing off and no face culling (its first draft's
"depth-tested solids" had to be corrected at implement), and its adapter refuses an out-of-range shown cycle with its own
rule code (`r02-g20.cycle`). The Binary Gardens kernel (`Packages/ExperiencesRound02/BinaryGardens/Core`) provides the
level (ring radii 2 … 8 of 1 … 40 units, star speed, luminosity levels 1 … 4 of 1 … 64 units, two stars with ring, phase,
luminosity and adjustable flags, maximum tilt 0 … 6 and starting tilt, minimum separation, clamp radius, 1 … 5 worlds
with radius 1 … 60, phase, speed −4 … 4, four flux bounds, window W and bloom band, lethal tolerance E, budget 1 … 24),
the arrangement (rings, phases, luminosities, tilt), the exact report (`BinaryGardensReport`: star and world positions at
ticks 1 … 48 at scale 2²⁰, per world the flux and each star's share at ticks 1 … 48 in milliflux, the bands, the longest
lethal run, the longest cyclic comfortable window and its start, the integral and the bloom result; the minimum star
separation; the first failure), the failures (frozen and scorched with world and walk tick 1 … 48 + E, unstable with
window and required, wilted and bleached with integral and band), the play (ring, phase, luminosity, tilt, run, undo,
redo, stages) and words for every star, world, tick and failure; the integer cosine table at scale 1024 is public
(`BinaryGardensSky.cosine`, `sine`); R02-G21-02 adds the phase step g and the 100-level manifest (1 … 3 worlds, ring radii
up to 16, world radii up to 36 in the catalog) with witnesses and a pinned catalog digest. No `BinaryGardensExperience`
exists yet. `AppModelTests` uses `r02-g21.binary-gardens` as its synthetic unregistered candidate; the next round-two
game is `r02-g22.mycelium-architect`; the archived matrix has 80 acceptance rows R2-G21-QA-001 … 080; the catalog's
design gives the palette "warm vermilion, ice blue and mint world", the hero "two suns painting crossing sunrise bands
over tiny flowering spheres", the geometry "cube-sphere planet mesh and shader-only seasonal banding" and the signature
shader "twin light discs and procedural luminous planet ecologies; numerical gravitation in fixed steps, analytic orbit
curves, procedural planets and starfields". The shared packages have a UV sphere but no cube-sphere generator.

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the kernel's base plane is z = 0
  (x right, y away from the viewer across the plane, z up out of it), the binary's barycentre at the origin. One fit
  rule per level: with R the largest of the level's ring radii and world radii (both level constants), a kernel point
  (x, y, z) at scale 2²⁰ is drawn at k · (x, y, z) / 2²⁰ with k = 0.95 / R, so every system fills the same disc of
  radius 0.95 and nothing a player does changes the scale. Every orbit curve is a 48-gon through the kernel's own table
  points (C[i]/1024, S[i]/1024 for i = 0 … 47, tilted by C[τ]/1024 and S[τ]/1024), so every body sits exactly on a
  vertex of its drawn orbit. Drawn in this order, painter's order with depth testing off and no face culling (the
  window surface has no depth buffer, as feature 493 learned): the backdrop (a large quad behind everything facing the
  eye; a still vertical gradient from space #070815 at the bottom to space top #151B3D at the top with a procedural
  starfield of hashed points, starfield #C8D2F0, covering at most 2 % of its area, the same at every tier); the tilt dial
  (when T_max > 0: T_max + 1 pips from (−1.15, 1.08, 0) to the right in steps of 0.05, the pip of the current tilt a
  filled disc, tilt lit #A6DDFF, the others rings, tilt unlit #2B3560); the star rings (per ring radius of the level a
  dashed 48-gon of radius k · ρ in the orbit plane at the current tilt, ring idle #2B3560; a ring a star stands on is
  solid in that star's colour, alternating the two colours dash by dash when both stars share it); the world orbits (per
  world a thin 48-gon of radius k · a in the base plane, orbit #3A6B66); the trails (at the two richer tiers only: the
  kernel's positions of every star and world at the 8 or 4 ticks before the shown tick as dots fading with age — the
  design's "numerical gravitation in fixed steps" read as the 48 fixed steps of the cycle — decoration only); the bodies
  (the two stars and every world, sorted back to front by their distance from the eye, ties by kind — worlds first —
  then index, so a star behind a world is covered by it): a world is a cube-sphere of radius 0.07 at its position at the
  shown tick (its faces emitted far-first from the fixed eye, so its near side covers its far side), mint world
  #7BE8BE, shaded in the fragment shader by the light of both stars — each star's colour by the
  angle to that star, scaled by the logarithmic light response of that star's kernel share at the shown tick (the stream carries the
  share over 64 000; the response is log2-shaped and reaches 1 at 1 024 milliflux, so catalog worlds of tens to hundreds
  of milliflux read), with a
  brightened sunrise band along each star's terminator, so two suns paint two crossing coloured bands, over an ambient
  floor of 0.35 of the surface colour so a world's night side still reads — and by
  shader-only seasonal banding that follows the world's band at the shown tick, by the latitude φ = asin(n.z) of the
  sphere normal n with feathered edges: lethal low ice caps covering every latitude |φ| ≥ 30° (frost #DDF2FF), dim
  caps covering |φ| ≥ 60°, comfortable open flowers (procedural petal dots, flower #FFE6F2) over a mint
  surface, bright a scorched equatorial belt |φ| ≤ 15° (scorch #C2412A), lethal high a belt |φ| ≤ 40°;
  beneath each world j + 1 pips (marking it as world j + 1); a star is a disc facing the eye of radius
  0.05 + 0.012 · (its luminosity index) at its position at the shown tick — star 1 vermilion #FF5A36, star 2 ice blue
  #A6DDFF, both with a white-hot core #FFF4E8 of half the radius — with corona rays at the richer tiers and, beneath it,
  one pip per luminosity level of the level, filled up to its current level; the gauges below the system, one row per
  world from y = −1.2 down in steps of 0.1: a plate from x = −0.95 to 1.22 (gauge plate #1A2347), on it 48 tick cells
  from x = −0.9 to 0.9 (each 1.8/48 wide with a fifth as gap) whose height is 0.01 + 0.06 · min(1, F/λ_hi) for the
  world's flux F at that tick and whose colour and shape give its band (lethal low #5C8DFF and lethal high #FF4A3D
  crossed, dim #8FB8E0 and bright #FFB27A hollow, comfortable #7BE8BE solid), two guide lines at the heights of c_lo
  and c_hi, a window bracket (window #B8FFE0) under the longest comfortable window from its start tick (cyclic, in two
  pieces when it wraps) with a tick at the required length W (solid when the window is at least W, dashed otherwise),
  a marker (marker #FFF4E8) above the column of the shown tick, and to its right a bloom meter from x = 0.97 to 1.2
  mapping 0 … max(1, 2 · B_hi) with a bracket over B_lo … B_hi (window #B8FFE0) and a marker at min(I, 2 · B_hi); the
  actions bars, `budget` bars at y = −1.2 − 0.1 · (worlds) − 0.03 (each 1.8 / budget wide with a gap of a fifth, 0.035
  tall), lit for the actions left (actions lit #FF7A4D, actions unlit #1E2648). The glow is additive and drawn last. The
  light shown is the report of the current arrangement; the shown tick is presentation state of the adapter
  (`clock.show [tick]`, accepted 1 … 48, never in the digest), 48 at opening — the starting configuration, since tick
  48 is tick 0 again — and never advanced by time; it persists across ring, phase, luminosity, tilt, run, undo and redo
  (the report always covers ticks 1 … 48) and returns to 48 at an opening, `level.next`, reset and restore. The camera is a fixed authored perspective (eye (0, −2.0, 3.2) looking at
  (0, −0.35, 0)) fitted to the box x −1.3 … 1.3, y −1.85 … 1.15, z −0.85 … 0.85 (a star at the largest tilt rises at
  most 0.68 above the plane, plus its disc) with a 5 % margin for aspect 0.4 … 2.5. Nothing drawn is consulted by the
  rules. Impact: FR-R02G2103-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): cube-spheres of 8 × 8 quads per face, star
  coronas of 12 rays, trails of 8 ticks, 8 pollen motes (pollen #FFE6F2) circling each comfortable world on a fixed loop
  and 2 glow shells around the stars and blooming worlds; `level-1`: 5 × 5 quads per face, 6 rays, trails of 4 ticks, 4
  motes, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): 3 × 3 quads per face (still a cube-sphere, keeping the
  banding), no rays, no trails, no motes, no glow. The backdrop and starfield, tilt dial, rings, orbits, body positions
  and sizes, banding, pips, gauges, actions bars and colours are the same at every tier. Levels are ordered richest
  first; the Core's `qualityTiers` equals the presenter's levels; the presenter logs each tier change with its reason.
  Impact: FR-R02G2103-004; SC-R02G2103-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera the barycentre, every world's centre, both stars' centres, the first gauge plate's left margin
  (x = −0.925 on the first row) and the first actions bar, and gives the palette. Simulator tests render offscreen at
  1,152 × 768 at shown tick 24 and check, at points at least 6 pixels from every element drawn after them, that each
  world's centre is brighter than the backdrop at that point by at least 0.15 in luminance (at least one world is
  checked in every frame; the ambient floor of 0.35 keeps a world's surface above that margin on its night side); that each star's centre is brighter than the backdrop by at least 0.4 (at least one star is
  checked in every frame; in the unlit fallback, which draws a star as its flat disc colour without the white-hot core,
  the check is that colour within 0.1); that the first actions bar (lit) has red above blue by at least 0.08 (vermilion); that the
  first gauge plate's left margin differs from the backdrop by at least 0.05; and that the median of a 9 × 9 pixel patch
  of backdrop in a lower corner matches the gradient colour at its height within 0.06 (the sparse starfield cannot move
  a median). Palette: space #070815, space top #151B3D, starfield #C8D2F0, ring idle #2B3560, orbit #3A6B66, star one
  #FF5A36, star two #A6DDFF, core #FFF4E8, world #7BE8BE, frost #DDF2FF, scorch #C2412A, flower #FFE6F2, pollen
  #FFE6F2, gauge plate #1A2347, lethal low #5C8DFF, dim #8FB8E0, comfortable #7BE8BE, bright #FFB27A, lethal high
  #FF4A3D, window #B8FFE0, marker #FFF4E8, tilt lit #A6DDFF, tilt unlit #2B3560, actions lit #FF7A4D, actions unlit
  #1E2648, broken #FF6B5E, glow #FFF9F0. Impact: FR-R02G2103-006; SC-R02G2103-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `BinaryGardensSceneSnapshot` (the level's ring radii, luminosity levels, maximum tilt, phase step, the worlds with
  radius, four flux bounds, window and bloom band, the lethal tolerance; the arrangement; from the kernel's report the
  star and world positions at ticks 1 … 48, every world's flux and shares at ticks 1 … 48, bands, longest lethal run,
  window and its start, integral and bloom result; the shown tick, the fit scale k, stage, failure, actions left,
  budget, level number and presentation time) made by the adapter; it never holds the kernel. If a program fails to
  compile or link, the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps
  `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion stops the coronas and motes
  (positions never move by time already); Reduce Flashing caps the glow gain. A failure marks the failing element in
  the broken colour (frozen or scorched: a broken ring around the named world and its gauge cell at the named tick's
  column, ((tick − 1) mod 48) + 1; unstable: the world's window bracket, or, when no tick is comfortable (window 0,
  start 0), the required-length tick W drawn alone and marked; wilted or bleached: its bloom meter marker),
  and the failure text names it, as the kernel's `failureDescription` does. Impact: FR-R02G2103-003, 007;
  SC-R02G2103-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g21.binary-gardens` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette #070815,
  #FF5A36, #A6DDFF, #7BE8BE, #151B3D, the scenario manifest
  `Packages/ExperiencesRound02/BinaryGardens/scenario-manifest.json`, no permissions, a summary of at most 300
  characters, content facts: 100 levels and the pinned catalog digest of R02-G21-02); `project.yml` and the app's
  experience registry link `BinaryGardensExperience` as a candidate (`available: false` until X-R02-G21), opening at
  seed 0 (level 1); `AppModelTests` switches its synthetic unregistered candidate to the next round-two game
  (`r02-g22.mycelium-architect`). The adapter (`BinaryGardensExperienceCore`) prepares certified level (seed mod 100) + 1
  from its table of certified candidate indices (each witness's `skipped`; the whole catalog only if that candidate no
  longer certifies) and accepts `star.ring [star, index]`, `star.phase [star, step]`, `star.luminosity [star, index]`,
  `orbit.tilt [step]`, `light.run`, `play.undo`, `play.redo`, `level.next` and `clock.show [tick]` (stars 0 and 1;
  whole numbers only); the kernel refuses everything out of range, locked, unchanged, off the phase grid, breaking the
  separation or out of stage with its own codes; the declared ranges are star 0 … 1, ring index 0 … 7, phase 0 … 47,
  luminosity index 0 … 3, tilt 0 … 6 and tick 0 … 60 (0 … 48 + the largest tolerance 12, the span of the kernel's walk
  ticks), so the engine refuses only values outside them, and `clock.show` refuses 0 and 49 … 60 with
  `r02-g21.tick` without touching the kernel; its digest (domain `r02-g21.binary-gardens.v1`) is the level number and the play's fingerprint
  (never the record history or the shown tick, so undo restores the earlier digest); snapshot schema 1
  `{level, records}` (schema 1, so no registered schema example is needed). Impact: FR-R02G2103-005, 008, 009;
  SC-R02G2103-004.
- Q: How do the vertex streams carry materials and the light? → A: as in feature 493: `a_uv.x` = material code +
  value scale · value (a fraction 0 … 1, for valued materials only) + a broken offset when a failure names the element;
  the flats (rings, pips, cells, brackets, markers, bars, discs) carry their local shape coordinates and are cut out by
  signed distance in the fragment shader. A world vertex carries the sphere normal in `a_normal`, its band at the shown
  tick as the material (five world materials, one per band), star 1's share over 64 000 as the value of `a_uv.x` and
  star 2's share over 64 000 in `a_uv.y`; the two star positions at the shown tick are uniforms. Programs are GLSL ES
  3.00 with at most 16 vec4 uniforms, no texture samplers and only bounded loops; the palette constants in the sources
  equal the CPU's; the flowers and starfield come from a fixed hash, never a random source. Impact: FR-R02G2103-001,
  002, 003; SC-R02G2103-003.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch two suns paint crossing sunrise bands over tiny flowering worlds (Priority: P1) 🎯

A player opens Binary Gardens and sees a small star system against a still starfield: a vermilion sun and an ice-blue
sun on their distance rings in a tiltable orbit plane, and tiny mint garden worlds on their own orbits around both.
Each sun lights the side of every world facing it in its own colour, so two coloured dawn lines cross each world; ice
caps grow on worlds that are too dim, a scorched belt on worlds that are too bright, and flowers open where the light
is comfortable. Below the system, a gauge per world shows its light at every tick of the cycle against its comfortable
band, its longest comfortable window against the window it needs, and its total light against its bloom band.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose worlds, stars,
gauges and actions bars are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose world, star,
   gauge and actions-bar pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the stars' rings, phases,
   luminosities, the tilt, the light on every world and the gauges show the new report, and the win or failure shown
   matches the kernel exactly.
3. **Given** a shown tick, **When** it changes, **Then** every body stands at the kernel's position for that tick and
   each world's banding and lit sides follow the kernel's band and shares for that tick, while the digest is unchanged.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown tick or rendering failure, the drawn image never
changes the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn positions,
fluxes, bands and windows are the kernel's exact integers.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown tick and frame count never changes the kernel's digest;
a failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses coarser worlds, no coronas, trails, motes or glow but keeps the same objective,
bodies, orbits, banding, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the worlds, stars, gauges and actions bars at the same places; only the
tessellation, rays, trails, motes and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G21.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the system, the gauges and the actions bars with a margin of at least 5 %
  on each side.
- **Extreme levels:** 1 and 5 worlds, 2 and 8 rings, radii 1 and 60 units, tilt 0 and 6, a star and a world at the same
  point (the clamped flux), a world held still (speed 0), retrograde worlds, flux 0 and 128 000 milliflux, budgets 1 and
  24: every vertex and uniform stays finite and inside the fitted box.
- **Colour-blind players:** the two stars differ by position, ring and the pips beneath them as well as colour; a
  star's luminosity is its disc size and its filled pips; a world's band is its caps, belt or flowers as well as its
  tint; gauge cells carry the band by height and by shape (crossed, hollow, solid), the window by a bracket that is
  solid or dashed, the bloom by a bracket with a marker; worlds and gauge rows are matched by pips; the tilt by the dial
  and the drawn plane; actions by a row of bars; every star, world, tick and failure can be named in words by the
  kernel, so no information is carried by hue only.
- **A failure (frozen, scorched, unstable, wilted, bleached):** the failing element is marked in the broken colour (the
  named world's ring and gauge cell, its window bracket — or its required-length tick alone when the window is 0 — or
  its bloom marker); the failure shown names it, as the kernel's
  reason does.
- **A won level:** every world blooms (flowers and, at the richer tiers, a mint glow); the frame checks use the same
  positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** nothing moves by itself (the shown tick never advances by time; coronas and motes are still);
  Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G2103-001**: The experience MUST render the starfield, the tilt dial, the star rings, the world orbits, the
  two stars, the garden worlds (cube-sphere meshes), the trails, the gauges and the actions bars entirely from generated
  geometry and shader code, with no image assets.
- **FR-R02G2103-002**: Materials MUST show two light discs in warm vermilion and ice blue, mint garden worlds lit by
  both suns with crossing sunrise bands, shader-only seasonal banding (ice caps, scorched belts, flowers) and a
  procedural starfield, computed in shaders; every element also has its shape or pattern.
- **FR-R02G2103-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown tick or failure may change the kernel's state, digest or verdict; drawn positions, shares, bands, windows
  and integrals MUST be the kernel's values for the shown tick.
- **FR-R02G2103-004**: The experience MUST offer three quality tiers that change only tessellation, corona rays,
  trails, motes and glow, never the bodies, orbits, light values, banding, colours, objective or indicators; the
  selected tier and the reason MUST be logged.
- **FR-R02G2103-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for a star's ring, phase and luminosity, the tilt, running the cycle, undo, redo, next level and the shown
  tick, digest, snapshot and restore), opening certified levels of R02-G21-02.
- **FR-R02G2103-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G2103-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G2103-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G2103-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate or lists the registered entries (`RealCatalogTests`),
  and except `BinaryGardensInvariantTests`, whose kernel scans (no clock, floating point or run-time trigonometry;
  allowed imports) read a fixed list of the kernel's files (feature 501's five and feature 502's five in `Core/Content`), so the
  presentation sources (snapshot, shaders with `sin(`/`cos(`, geometry, adapter, scenarios) stay outside them;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.
- **FR-R02G2103-010**: No information MUST be carried by hue alone (the non-colour twins of the edge cases), and the
  presenter MUST expose its tier log, fallback reason and frame probes for diagnostics, with no telemetry leaving the
  device.

### Key Entities

- **Scene snapshot**: the level's rings, luminosity levels, tilt range, phase step and worlds with their bounds, window
  and bloom band; the arrangement; the report's positions, fluxes, shares, bands, windows and integrals; the shown tick,
  fit scale, stage, failure, actions left, budget, level number and presentation time.
- **System geometry**: the backdrop and starfield, the tilt dial, the star rings and world orbits (48-gons through the
  kernel's table points), the trails, the cube-sphere worlds with their pips, the star discs with coronas and pips, the
  gauges and the actions bars.
- **Quality tier**: 0, 1 or 2, with its tessellation, rays, trails, motes and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G2103-001**: On the simulator, frames of 5 certified levels (1, 21, 41, 61, 81) at each tier match the CPU
  reference: world, star, gauge and actions-bar positions within the stated tolerance and palette colours within the
  stated distance.
- **SC-R02G2103-002**: Across 200 seeded snapshots, tier changes, time steps, shown-tick changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G2103-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G2103-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G2103-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G2103-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag star distance rings, tilt the orbit plane, inspect each miniature world) are R02-G21-04; hints and
  progression R02-G21-05; accessibility and polish R02-G21-06; persistence R02-G21-07. This feature gives the experience
  a minimal control panel (a star picker, ring −/+, phase −/+ by the phase step, luminosity −/+, tilt −/+, tick −/+,
  run, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Two suns
  painting crossing sunrise bands over tiny flowering spheres" is read as each star lighting every world in its own
  colour with a brightened terminator, so two coloured dawn lines cross each small world, and flowers opening where the
  light is comfortable; "cube-sphere planet mesh and shader-only seasonal banding" as the world geometry and its
  band-driven caps, belts and flowers; "twin light discs" as the two star discs; "procedural luminous planet ecologies"
  as the flowers, pollen motes and bloom glow; "numerical gravitation in fixed steps, analytic orbit curves" as the
  trails of the 48 fixed steps and the orbits drawn through the kernel's integer phase table; "procedural starfields" as
  the hashed starfield of the backdrop. No physical accuracy of light transport is claimed; the shading is a mobile
  approximation.
- Like Mushroom Weather, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G21-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G21-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g22.mycelium-architect`.
- New type names avoid the dependency audit's denylist (no ProjectM, MilkDrop or preset-library names).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (cube-sphere planet mesh and shader-only seasonal banding) | FR-R02G2103-001, 002 |
| Signature shader (twin light discs and procedural luminous planet ecologies; numerical gravitation in fixed steps, analytic orbit curves, procedural planets and starfields) and palette (warm vermilion, ice blue and mint world) | FR-R02G2103-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G2103-003, 005 |
| Quality tiers 0/1/2, tier log | FR-R02G2103-004, 010 |
| Renderer purity, stability (INV-08, INV-10) | FR-R02G2103-003; SC-R02G2103-002, 003 |
| Real render captures | FR-R02G2103-006 |
| Accessibility (non-colour clues, Reduce Motion, Reduce Flashing), observability | FR-R02G2103-007, 010 |
| "Register it in the catalog" (override) | FR-R02G2103-008 |
| No Stage One breakage | FR-R02G2103-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no depth buffer or depth testing, no network, no telemetry, no store listing, no
  advertising, no gestures beyond the minimal control panel, no device run before ImplementationLock-100, no
  availability before X-R02-G21.
