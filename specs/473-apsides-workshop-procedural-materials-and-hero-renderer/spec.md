# Feature Specification: R02-G18-03 — Apsides Workshop: procedural materials and hero renderer

**Feature Branch**: `473-apsides-workshop-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-25

**Status**: Clarified

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

## Clarifications

### Session 2026-11-25

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
463's answers where the games agree. Facts checked in code (read-only, 2026-11-25): Celestial Eclipse Lab's experience
as recorded at R02-G17-03 is the pattern in this package — a Core adapter with a table of certified candidates, an
immutable scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` (capabilities, tiers `level-0` … `level-2`, a five-colour palette, the
manifest path, no permissions, a summary) and the public `ShaderMeshRenderer`; the Apsides Workshop kernel provides the
level (period 16 … 96, planets, targets, starting orbit, budget), the orbit's integer positions per tick (sky units,
within ±16 384), the shares, the apsis readings, the report (deviations, met, failure: contact, order, share,
apsis-sector, apsis-distance), the play (periapsis, size, play, undo, redo, stages) and the certified catalog of
R02-G18-02 (periods 24 … 48, planets 0 … 3 with radius 1 … 3, digest 73aef009…); `AppModelTests` uses
`r02-g18.apsides-workshop` as its synthetic unregistered candidate and the next round-two game is
`r02-g19.microscopic-aurora`; the archived matrix has 80 acceptance rows R2-G18-QA-001 … 080; the catalog's design gives
the palette "glacial white, deep rose and midnight", the hero "cosmic compass with loops of luminescent elliptical
epicycles" and the geometry "adaptive analytic ellipse tessellation".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: one fixed scale for every level: a
  sky point (x, y) in sky units maps to world (x · s, y · s, depth) with s = 0.9 / 16 384, so the sky bound (64 lattice
  units) lies at radius 0.9 and the compass never rescales when the orbit is tuned; y is up and the camera looks down
  the z axis. Drawn with depth testing off (the shared mesh renderer's path), in this order: the sky backdrop (a large
  quad; a vertical gradient from midnight #0A0B1F at the bottom to midnight top #1A1438 at the top with sparse
  procedural star specks covering under 5 % of its pixels); the swept-area wedges (one triangle star → P(t) → P(t + 1)
  per tick at depth −0.04, filled in wedge #2A2350, or in deep rose wedge #6B2346 for a sector a sweep target names);
  the compass (8 spokes at multiples of 45° from radius 0.06 to 0.92, 0.006 wide, compass #3A3F6B; a rim ring at radius
  0.92, 0.012 wide, with s + 1 notches at the middle of sector s; a bracket arc at radius 0.96 over each sector a sweep
  target names); the ghost loop (the starting orbit's positions, a closed ribbon 0.008 wide at depth −0.08, ghost
  #5B6390); the orbit loop (a closed ribbon 0.014 wide through w of every kernel position in tick order, glacial
  #E8F1FF, refined at tiers 0 and 1 by presentation-only points on the analytic ellipse between ticks — the judged
  chords stay the kernel's); the apsis markers (a diamond 0.035 across at P(0) for the periapsis and a square 0.03
  across at P(T/2) for the apoapsis, deep rose #C2456E; an apsis target's sector is bracketed in the same colour); the
  planets (spheres of radius r · 256 · s at their centres, planet #8C93B8 with a hatched hazard ring 0.01 outside,
  hazard #C2456E); the star (a sphere of radius 2 · 256 · s at the origin, star #FFF4D6); the orbiter (a sphere of
  radius 0.03 at P(shown tick), glacial with a deep rose rim); the gauges below the compass: for target i a track at y =
  −1.08 − 0.07 i from x = −0.9 to 0.9 mapping 0 … 1000 (sweep share) or 0 … 1280 (apsis distance), its band as a bracket
  and its reading as a mark (filled, met #C2456E, for a met target; hollow, unmet #E8F1FF, otherwise); the actions bars,
  `budget` bars at y = −1.55 from x = −0.9 to 0.9 (each 1.8 / budget wide with a gap of a fifth, 0.04 tall), lit for the
  actions left. The glow is additive and drawn last. The shown tick is presentation state of the adapter (`clock.show
  [tick]`, never in the digest), 0 at opening and never advanced by time. The camera is a fixed authored perspective
  (eye (0, −0.3, 3.6) looking at (0, −0.3, 0)) fitted to the box x −1.0 … 1.0, y −1.65 … 1.0 with a 5 % margin for
  aspect 0.4 … 2.5. Nothing drawn is consulted by the rules. Impact: FR-R02G1803-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): spheres of 24 × 16 segments with layered shading
  (core, limb darkening and rim light), 4 refinement points per tick on the orbit loop and 2 glow shells around the
  star, the orbit loop and the orbiter; `level-1`: 16 × 12 segments, 2 refinement points, 1 glow shell; `level-2` (the
  design's "Tier 0, D3-safe"): flat screen-facing 20-sided discs, no refinement (chords only), no glow. The wedges,
  compass, ghost loop, apsis markers, gauges, colours and positions are the same at every tier. Levels are ordered
  richest first; the presenter logs each tier change with its reason. Impact: FR-R02G1803-004; SC-R02G1803-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects through the same
  camera the star's centre, the orbiter at the shown tick, every planet's centre, the first gauge track's centre and the
  first actions bar, and gives the palette. Simulator tests render offscreen at 1,152 × 768 at the shown tick 0 and
  check, at points at least 6 pixels from every element drawn after them, that the star's centre and the orbiter's
  centre are brighter than the backdrop by at least 0.25 in luminance; that the first actions bar (lit) has red above
  blue by at least 0.08 (deep rose); that the first gauge track differs from the backdrop by at least 0.1; and that the
  median of a 9 × 9 pixel patch of backdrop away from geometry matches the gradient colour at its height within 0.06
  (the median ignores the sparse specks). Palette: midnight #0A0B1F, midnight top #1A1438, speck #D8E4FF, wedge
  #2A2350, target wedge #6B2346, compass #3A3F6B, ghost #5B6390, glacial #E8F1FF, deep rose #C2456E, planet #8C93B8,
  hazard #C2456E, star #FFF4D6, met #C2456E, unmet #E8F1FF, actions lit #C2456E, actions unlit #262A4E, broken #E0533A,
  glow #F4F8FF. Impact: FR-R02G1803-006; SC-R02G1803-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `ApsidesWorkshopSceneSnapshot` (the current orbit's steps and positions, the starting orbit's positions, the orbiter's
  position at the shown tick, the shares, the apsis readings, the planets, the targets with their bands, readings,
  deviations and met flags, stage, failure, actions left, budget, level number, shown tick and presentation time) made
  by the adapter; it never holds the kernel. If a program fails to compile or link, the scene draws the level-2 geometry
  unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`.
  Reduce Motion stops the star's glow pulsing; Reduce Flashing caps the glow gain. A failure marks the failing element
  in the broken colour (a contact: the struck planet's hazard ring and the segment from its tick; an order, share or
  apsis failure: that target's gauge track) and the failure text names it, as the kernel's reason does. Impact:
  FR-R02G1803-003, 007; SC-R02G1803-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g18.apsides-workshop` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette #0A0B1F,
  #E8F1FF, #C2456E, #8C93B8, #1A1438, the scenario manifest `Packages/ExperiencesRound02/ApsidesWorkshop/
  scenario-manifest.json`, no permissions, a summary of at most 300 characters, content facts: 100 levels and the pinned
  catalog digest); `project.yml` and the app's experience registry link `ApsidesWorkshopExperience` as a candidate
  (`available: false` until X-R02-G18), opening at seed 0 (level 1); `AppModelTests` switches its synthetic unregistered
  candidate to the next round-two game (`r02-g19.microscopic-aurora`). The adapter (`ApsidesWorkshopExperienceCore`)
  prepares certified level (seed mod 100) + 1 from its table of certified candidate indices (the whole catalog only if
  that candidate no longer certifies) and accepts `orbit.periapsis [k, d]`, `orbit.size [a]`, `orbit.play`,
  `play.undo`, `play.redo`, `level.next` and `clock.show [tick]` (whole numbers only); the kernel refuses everything out
  of range or out of stage and `clock.show` refuses a tick outside 0 … period − 1; its digest is the level number and
  the play's fingerprint (never the record history or the shown tick, so undo restores the earlier digest); snapshot
  schema 1 `{level, records}`. Impact: FR-R02G1803-005, 008, 009; SC-R02G1803-004.

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
