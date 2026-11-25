# Feature Specification: R02-G17-03 — Celestial Eclipse Lab: procedural materials and hero renderer

**Feature Branch**: `463-celestial-eclipse-lab-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-25

**Status**: Clarified

**Ledger gate**: R02-G17-03 (migration ledger, game feature of experience R02-G17) · ID namespace FR-R02G1703-###,
SC-R02G1703-###, T-R02G1703-###

**Input**: User description: the archived R02-G17-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Celestial Eclipse Lab (code-only
hero: "glowing planetary crescents eclipsing into razor-edge corona halos"), with the canonical overrides of ADR-0009
and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/463-celestial-eclipse-lab-procedural-materials-and-hero-renderer`;
  FR-R02G1703-###, SC-R02G1703-###, T-R02G1703-###.
- **Packaging (ADR-0009):** the source's `Apps/CelestialEclipseLab` becomes the experience target
  `CelestialEclipseLabExperience` (with its tests) in `Packages/ExperiencesRound02/CelestialEclipseLab/Experience`
  beside the existing `CelestialEclipseLabCore` (the source's `Packages/GameModules/CelestialEclipseLabCore`); the
  experience `r02-g17.celestial-eclipse-lab` (free) is registered in the catalog as a candidate (not available) and
  linked into the one app, as Starlit Cartouche was at R02-G16-03; it becomes available only at its gate X-R02-G17.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 74" is a milestone figure — the catalog is
  the 100 certified levels of R02-G17-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G17-01 and -02.
- **Model:** feature 453 (Starlit Cartouche's hero renderer and experience).

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
453's answers where the games agree. Facts checked in code (read-only, 2026-11-25): Starlit Cartouche's experience
(R02-G16-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Celestial Eclipse Lab kernel
provides the level (2 … 6 bodies on lattice orbits with radii, fixed flags and depth order; the horizon; the target
with windows; the starting phases and budget), a body's position at a tick for a phase, the eclipse intervals with
their visibility classes, the timeline (intervals, matched count, failure: unwanted, window or horizon), the play
(phase, run, undo, redo, stages) and the certified catalog of R02-G17-02 (3 … 6 bodies, coordinates within −18 … 18,
depth layers −13 … 9, radii 1 … 4, horizons 24 … 48, digest c74bf277…); `AppModelTests` uses
`r02-g17.celestial-eclipse-lab` as its synthetic unregistered candidate and the next round-two game is
`r02-g18.apsides-workshop`; the archived matrix has 80 acceptance rows R2-G17-QA-001 … 080; the catalog's design gives
the palette "corona gold, ink navy and muted ember", the hero "glowing planetary crescents eclipsing into razor-edge
corona halos" and the geometry "analytic orbital rings, signed circle masks and eclipse glow shaders".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: lattice positions map to world space
  by w(v) = (v − m) · s, where m is the centre of the bounding box of every orbit position of every body widened by
  that body's radius in x and y (so no disc leaves the frame at any tick) and s = 1.5 / (e + 1) with e the box's largest
  extent; y is up and +z (nearer in the
  rules) is toward the camera, so the picture is seen from the side the rules project onto. Bodies are drawn at
  w(position(at: shown tick, phase)) for the current phases. Drawn back to front by distance from the eye (depth
  testing off, the shared mesh renderer's path; ties broken by kind — rings, bodies, halos, gauges — then by index):
  the sky backdrop (a large quad; a vertical gradient from ink #0B1530 at the bottom to ink top #16224A at the top with
  sparse procedural specks covering under 5 % of its pixels); the orbital rings, a closed ribbon 0.012 wide through w
  of every orbit position in order, orbit blue, with (index mod 6) + 1 notches at the body's position and a square
  frame for a fixed body; the bodies, spheres of radius r · s at their positions, disc ivory with layered limb shading;
  the eclipse crescents: every back body of an eclipse under way at the shown tick (the kernel's strict overlap) is
  darkened inside the front body's projected circle (centre and radius r · s from the kernel's x and y): a shadow lens,
  the exact intersection of the two circles computed in code (the back disc for a total eclipse, the front disc for an
  annular one), drawn in crescent shadow right after the back body and before the front body, so the crescent seen is
  the overlap judged (implementation note, 2026-11-25: the shared mesh renderer binds only position, normal and uv, so
  the circle mask is geometry rather than per-vertex shader attributes); the corona halos, a thin ring at the front
  body's rim, corona gold, when the eclipse's class at the shown tick is total or annular; the chosen body's dashed ring
  of radius r · s + 0.04; the gauges in screen-facing world space below the sky: the timeline strip at y = −1.15 from
  x = −0.9 to 0.9 mapping ticks 0 … horizon − 1, each target window a bracket above it at y = −1.05 with the target's
  index in notches, each predicted event a mark at its first tick (a filled diamond, corona gold, for a matched event; a
  cross, ember, for the failing event; faint for events after the last match), and the playhead, a vertical line at
  the shown tick; the actions bars, `budget` bars at y = −1.35 from x = −0.9 to 0.9 (each 1.8 / budget wide with a gap
  of a fifth, 0.04 tall), lit for the actions left. The glow is additive and drawn last. The chosen body and the shown
  tick are presentation state of the adapter (`orbit.choose [body]`, `clock.show [tick]`, never in the digest), at
  opening the lowest-numbered movable body and tick 0; the shown tick is never advanced by time. The camera is a fixed
  authored perspective (eye (0.3, 0.2, 3.4) looking at (0, −0.25, 0)) fitted to the box x −0.95 … 0.95, y −1.45 …
  0.95, z −0.95 … 0.95 with a 5 % margin for aspect 0.4 … 2.5. Nothing drawn is consulted by the rules. Impact:
  FR-R02G1703-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): body spheres of 24 × 16 segments with layered
  shading (core, limb darkening and rim light) and 2 glow shells around the halos and the chosen ring; `level-1`:
  16 × 12 segments, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): flat screen-facing 20-sided body discs,
  no glow. Rings, crescents (the shadow lens is drawn at every tier), halos, the timeline, gauges, colours and
  positions are the same at every tier. Levels are ordered richest first; the presenter logs each tier change with its
  reason. Impact: FR-R02G1703-004; SC-R02G1703-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera every body's centre, the timeline strip's centre, each target bracket, the playhead and the first actions bar,
  orders them by camera distance as the painter does, and gives the palette. Simulator tests render offscreen at
  1,152 × 768 at the shown tick 0 and check, at points at least 6 pixels from every element drawn after them, that the
  centre of a body not covered at tick 0 is brighter than the backdrop by at least 0.25 in luminance; that the first
  actions bar (lit) has red above blue by at least 0.08 (corona gold); that the timeline strip's centre differs from
  the backdrop by at least 0.1; and that the median of a 9 × 9 pixel patch of backdrop away from geometry matches the
  gradient colour at its height within 0.06 (the median ignores the sparse specks). Palette: ink #0B1530, ink top
  #16224A, speck #C9D2FF, disc #E9E1CF, disc shade #7A829A, orbit #33406E, fixed frame #8A93B0, chosen #F2C14E, corona
  #F2C14E, corona glow #FFE7A3, crescent shadow #050A18, ember #C8553D, window #E8E2D0, matched #F2C14E, unwanted
  #C8553D, faint event #5A6488, playhead #FFE7A3, actions lit #F2C14E, actions unlit #24305A, broken #E0533A, glow
  #FFF1D0. Impact: FR-R02G1703-006; SC-R02G1703-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `CelestialEclipseLabSceneSnapshot` (the bodies' positions at the shown tick for the current phases, radii and fixed
  flags; the orbits; the eclipses under way at the shown tick with their classes; the target and windows; the predicted
  intervals and matched count; the shown tick and horizon; the chosen body; stage, failure, actions left, budget, level
  number and presentation time) made by the adapter; it never holds the kernel. If a program fails to compile or link,
  the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps
  running; tier changes go to its `tierLog`. Reduce Motion stops the halos pulsing; Reduce Flashing caps the glow gain.
  A failure marks the failing event on the timeline in the broken colour (an unwanted or out-of-window event at its
  tick; a horizon failure at the strip's end with the next target's bracket outlined) and outlines its two bodies; the
  failure text names it, as the kernel's reason does. Impact: FR-R02G1703-003, 007; SC-R02G1703-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g17.celestial-eclipse-lab` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/CelestialEclipseLab/scenario-manifest.json`, no permissions, a summary
  of at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `CelestialEclipseLabExperience` as a candidate (`available: false` until X-R02-G17), opening
  at seed 0 (level 1); `AppModelTests` switches its synthetic unregistered candidate to the next round-two game
  (`r02-g18.apsides-workshop`). The adapter (`CelestialEclipseLabExperienceCore`) prepares certified level (seed mod
  100) + 1 from its table of certified candidate indices (the whole catalog only if that candidate no longer certifies)
  and accepts `orbit.phase [body, offset]`, `clock.run`, `play.undo`, `play.redo`, `level.next`, `orbit.choose [body]`
  and `clock.show [tick]` (whole numbers only); the kernel refuses everything out of range or out of stage,
  `orbit.choose` refuses a body the level does not have and `clock.show` a tick outside 0 … horizon − 1; its digest is
  the level number and the play's fingerprint (never the record history, the chosen body or the shown tick, so undo
  restores the earlier digest); snapshot schema 1 `{level, records}`. Impact: FR-R02G1703-005, 008, 009;
  SC-R02G1703-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch glowing planets eclipse into corona halos (Priority: P1) 🎯

A player opens Celestial Eclipse Lab and sees miniature planets on their orbital rings over an ink-navy sky, seen from
one side. As the predicted clock is stepped, a nearer planet slides across a farther one: its shadow cuts a precise
crescent from the glowing disc, and when the cover is total or annular a razor-edge corona halo flares in gold. Below
the sky a timeline shows the target eclipses with their windows and the eclipses the current phases predict.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose planets, rings,
crescents, timeline and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose planet, ring,
   timeline and gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the planets move to their orbit
   positions at the shown tick for the new phases, the timeline shows the new prediction, and the win or failure shown
   matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time, shown tick or rendering failure, the drawn image never changes
the kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn planets sit at the
kernel's exact orbit positions for the shown tick.

**Why this priority**: the rules are exact integers; a picture that decided anything would break them.

**Independent Test**: changing tier, presentation time, shown tick and frame count never changes the kernel's digest; a
failed shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses flat planet discs and no glow but keeps the same objective, planets, rings, crescents,
timeline, colours and indicators; the selected tier and its reason are logged.

**Why this priority**: the app runs on three device classes.

**Independent Test**: tiers 0, 1 and 2 draw the planets, rings, timeline and gauges at the same places; only the planet
shading detail and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Why this priority**: later features build on the candidate; players must not see it before X-R02-G17.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every orbit, the timeline and the gauges with a margin of at least 5 % on
  each side.
- **Colour-blind players:** each planet carries (index mod 6) + 1 notches on its ring, fixed planets a square frame,
  the chosen planet a dashed ring, matched predicted eclipses a filled mark and unwanted ones a cross, windows brackets,
  and actions a row of bars; every body, eclipse and measure can be named in words by the kernel, so no information is
  carried by hue only.
- **A failure (unwanted eclipse, an eclipse outside its window, or the horizon reached):** the failing event is marked
  on the timeline in the broken colour and the two planets involved are outlined; the failure shown names it, as the
  kernel's reason does.
- **A won level:** every target mark is lit and the corona halos of the matched eclipses flare; the frame checks use the
  same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the halos do not pulse (the shown tick never advances by itself); Reduce Flashing caps the glow to
  the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1703-001**: The experience MUST render the planets as generated sphere meshes at their orbit positions for
  the shown tick, the orbital rings, the eclipse crescents and corona halos, the timeline and the gauges entirely from
  generated geometry and shader code, with no image assets.
- **FR-R02G1703-002**: Materials MUST show an ink-navy sky, glowing planetary discs with procedural layered shading,
  precise shadow crescents where a nearer planet covers a farther one, and corona-gold halos with muted-ember accents,
  computed in shaders; every element also has its shape or pattern.
- **FR-R02G1703-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time, shown tick or failure may change the kernel's state, digest or verdict.
- **FR-R02G1703-004**: The experience MUST offer three quality tiers that change only planet shading detail and glow,
  never planets, rings, crescents, timeline, colours, objective or indicators; the selected tier and the reason MUST be
  logged.
- **FR-R02G1703-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for changing a phase, running the clock, undo, redo, next level, choosing the shown planet and the shown
  tick, digest, snapshot and restore), opening certified levels of R02-G17-02.
- **FR-R02G1703-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1703-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1703-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1703-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the bodies (positions at the shown tick for the current phases, radii, fixed flags), the orbits,
  the eclipses under way at the shown tick with their visibility classes, the target with windows, the predicted
  timeline and matched count, the shown tick and horizon, the chosen planet, stage, failure, actions left, budget, level
  number and presentation time.
- **Sky geometry**: the planet spheres, orbital rings, shadow lenses, corona halos, the timeline and the gauges.
- **Quality tier**: 0, 1 or 2, with its planet shading detail and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1703-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: planet,
  ring, timeline and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1703-002**: Across 200 seeded snapshots, tier changes, time steps, shown-tick changes and forced shader
  failures never change the kernel digest or verdict.
- **SC-R02G1703-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1703-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1703-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1703-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag orbital handles, rotate the time dial, step the predicted timeline, orbit) are R02-G17-04; hints and
  progression R02-G17-05; accessibility and polish R02-G17-06; persistence R02-G17-07. This feature gives the experience
  a minimal control panel (planet −/+, phase −/+, tick −/+, run, undo, redo, next level, each labelled) so it can be
  exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Analytic orbital
  rings, signed circle masks and eclipse glow shaders" are generated rings through the kernel's exact orbit positions, a
  shadow lens computed from the two discs' projected circles, and an emissive halo pass; the eclipse drawn is always
  the eclipse judged.
- Like Starlit Cartouche, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G17-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G17-02).
- `AppModelTests`' synthetic unregistered candidate moves to the next round-two game, `r02-g18.apsides-workshop`.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (analytic orbital rings, signed circle masks and eclipse glow shaders) | FR-R02G1703-001 |
| Signature shader (precise shadow crescents over glowing planetary discs; procedural planets, layered spheres and emission shaders) and palette (corona gold, ink navy and muted ember) | FR-R02G1703-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1703-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1703-004 |
| Renderer purity, stability | FR-R02G1703-003; SC-R02G1703-002, 003 |
| Real render captures | FR-R02G1703-006 |
| "Register it in the catalog" (override) | FR-R02G1703-008 |
| No Stage One breakage | FR-R02G1703-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G17.
