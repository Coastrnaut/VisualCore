# Feature Specification: R02-G13-03 — Acoustic Constellator: procedural materials and hero renderer

**Feature Branch**: `423-acoustic-constellator-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G13-03 (migration ledger, game feature of experience R02-G13) · ID namespace FR-R02G1303-###,
SC-R02G1303-###, T-R02G1303-###

**Input**: User description: the archived R02-G13-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Acoustic Constellator, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/423-acoustic-constellator-procedural-materials-and-hero-renderer`;
  FR-R02G1303-###, SC-R02G1303-###, T-R02G1303-###.
- **Packaging (ADR-0009):** the source's `Apps/AcousticConstellator` becomes the experience target
  `AcousticConstellatorExperience` (with its tests) in `Packages/ExperiencesRound02/AcousticConstellator/Experience`
  beside the existing `AcousticConstellatorCore`; the experience `r02-g13.acoustic-constellator` (free) is registered in
  the catalog as a candidate (not available) and linked into the one app, as Harmonic Bridges was at R02-G12-03; it
  becomes available only at its gate X-R02-G13.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 85" is a milestone figure — the catalog is
  the 100 certified levels of R02-G13-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G13-01 and -02.
- **Model:** feature 413 (Harmonic Bridges's hero renderer and experience).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
413's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Harmonic Bridges's experience
(R02-G12-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Acoustic Constellator kernel
provides the level (stars with drawing positions on a 12 × 12 × 12 grid, rates and starting phases, fixed links, the
symbol, K, limits, σ, θ, hold, window, budget), the listen report (phases per tick, snapped links per tick, A and B per
tick, coherent ticks, longest run, outcome), the play (link, unlink, nudge, listen, undo, redo, stages, failures
missing, disconnected, incoherent and budget) and the certified catalog of R02-G13-02; generated star positions lie on
a circle of radius 5 around (6, 6) at depth 5 or 7; `AppModelTests` uses `r02-g13.acoustic-constellator` as its synthetic
unregistered candidate and the next round-two game is `r02-g14.moonlit-mechanism`; the catalog's design gives the
palette "star white, teal resonance and plum", the hero "celestial musical diagrams pulsing along silver filaments" and
the geometry "instanced ellipsoids and shader-tinted spline links".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: star (gx, gy, gz) of the drawing grid
  is at X = (gx − 5.5) · 0.14, Z = (gy − 5.5) · 0.11, Y = 0.15 + (gz − 5.5) · 0.02. Drawn in this order: the sky (a plane
  at y = −0.01 covering x −1.1 … 1.1, z −0.9 … 1.3); the unlinked symbol pairs as dashed guides (8 dashes, 0.006 wide)
  between the star centres; every current link as a spline strip 0.01 wide (a quadratic curve rising 0.03 above the
  chord at its middle, 16 segments), silver when its gap at the shown tick is more than 1 step and teal when it is at
  most 1; a link snapped at or before the shown tick of the preview as two halves with the middle 30 % missing; each star
  as an ellipsoid (radii 0.045 × 0.035 × 0.045, 12 × 8 segments) and its phase hand, a strip 0.006 wide from the centre
  0.07 long at angle phase · 30° in the star's horizontal plane, 0.04 above it; the coherence gauge, a row of 12 bars at
  z = 0.85 spread from x = −0.6 to 0.6 with ⌊12 · (A + B√3) / n²⌋ lit (presentation arithmetic) and a mark over bar
  ⌈12θ / n²⌉; the hold gauge, `hold` pips at z = 1.0 spread from x = −0.4 to 0.4, lit for the current coherent run;
  the moves gauge, `budget` bars at z = 1.15 spread from x = −0.9 to 0.9 (each 1.8 / budget wide with a gap of a fifth,
  0.05 deep), lit for the actions left. The shown tick plays the kernel's listen report of the current state, one tick
  per 0.25 s of presentation time, then holds the last tick 1 s and starts again; at time 0 it is tick 0. Depth testing
  is off (the shared mesh renderer's path): the sky and the flat gauges first, then the guides, the links and the
  hands, then the stars back to front (by z from the far side, then by x) with back faces culled; the glow is additive
  and drawn last. The camera is a fixed authored perspective (eye (0, 2.0, 1.7) looking at (0, 0, 0.2)) fitted to the
  box x −0.9 … 0.9, z −0.7 … 1.25, y 0 … 0.3 with a 5 % margin for aspect 0.4 … 2.5. Nothing drawn is consulted by the
  rules; the drawn pulse never replaces the kernel's phases. Impact: FR-R02G1303-001, 002, 003, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): stars pulse (scale 1 + 0.15 · cos(2π · phase /
  12) at the shown tick), 2 radial wave shells (strip rings 0.01 wide expanding from each star on a coherent tick from
  radius 0 to 0.12 over 1 s, at the star's height) and 2 glow shells around teal links and stars; `level-1`: stars
  pulse, no wave shells, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): no pulse, no shells, no glow. Stars,
  hands, links, guides, gauges, colours and positions are the same at every tier. Levels are ordered richest first; the
  presenter logs each tier change with its reason. Impact: FR-R02G1303-004; SC-R02G1303-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects every star's
  centre, every link's check point (u = 0.25 along its spline at tick 0, 0.015 to the side, clear of the strip), the
  first coherence bar, the first hold pip and the first moves bar through the same camera and gives the palette.
  Simulator tests render offscreen at 1,152 × 768 at time 0 and check, at points at least 6 pixels from any other
  element, that a star's centre differs from the sky by at least 0.15 in luminance with red, green and blue within 0.1 of
  each other (white); that a teal link's strip point differs from the sky by at least 0.08 with green above red by at
  least 0.05; that the first moves bar differs from the sky by at least 0.1; and that the background matches the sky
  within 0.05 away from geometry. Palette: sky #05060F, star #F4F1E8, phase hand #F4F1E8, silver link #B8C0D0, teal link
  #3FD6C6, guide #8A5A9C, broken outline #FF6B4A, coherence lit #3FD6C6, coherence unlit #2A2433, threshold mark
  #F4F1E8, hold lit #3FD6C6, hold unlit #3A3348, moves lit #B8C0D0, moves unlit #2A2433, wave shell #6FE0D8, glow
  #8FF4EA. Impact: FR-R02G1303-006; SC-R02G1303-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `AcousticConstellatorSceneSnapshot` (stars with positions, rates and starting phases, the links, the symbol, the
  kernel's listen report of the current state, threshold, hold, window, stage, failure, actions left, budget, level
  number and presentation time) made by the adapter; it never holds the kernel. If a program fails to compile or link,
  the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps
  running; tier changes go to its `tierLog`. Reduce Motion draws the stars at tick 0 without pulsing and does not play
  the preview; Reduce Flashing caps the glow gain. A failure outlines the missing pair's guide or the snapped link in the
  broken colour, and the failure text names them, as the kernel's reason does. Impact: FR-R02G1303-003, 007;
  SC-R02G1303-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g13.acoustic-constellator` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/AcousticConstellator/scenario-manifest.json`, no permissions, a summary
  of at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `AcousticConstellatorExperience` as a candidate (`available: false` until X-R02-G13), opening
  at seed 0 (level 1); `AppModelTests` switches its synthetic unregistered candidate to the next round-two game
  (`r02-g14.moonlit-mechanism`). The adapter (`AcousticConstellatorExperienceCore`) prepares certified level (seed mod
  100) + 1 from its table of certified candidates (the whole generator only if that candidate no longer certifies) and
  accepts `link.add [a, b]`, `link.remove [a, b]`, `star.nudge [s, ±1]`, `constellation.listen`, `play.undo`,
  `play.redo` and `level.next` (whole numbers only); the kernel refuses everything out of range or out of stage; its
  digest is the level number and the play's fingerprint (never the record history, so undo restores the earlier
  digest); snapshot schema 1 `{level, records}`. The panel's chosen star and partner are presentation state of the
  controls, not kernel state: a level opens with star 0 and partner 1 chosen. Impact: FR-R02G1303-005, 008, 009;
  SC-R02G1303-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See musical stars pulse along silver filaments into a celestial diagram (Priority: P1) 🎯

A player opens Acoustic Constellator and sees star-white stars drifting in a dark sky, each pulsing at its own rate.
Linked stars are joined by silver filaments that turn teal as their phases agree; the target symbol's unlinked pairs
show as faint plum guides. While the listening preview plays, each star's phase hand turns, links that stretch too far
break, and gauges show the coherence against the threshold, the hold so far and the moves left.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose stars, links,
guides and gauges are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose star, link and
   gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the links, the starting phases,
   the listening preview and the gauges follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn pulse never replaces
the kernel's exact phases.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses no wave shells and no glow and draws stars without pulsing but keeps the same
objective, stars, links, guides, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the stars, links, guides and gauges at the same places; only shells, pulse
and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every star and the gauges with a margin of at least 5 % on each side.
- **Colour-blind players:** stars carry a phase hand, symbol pairs that are unlinked are dashed guides, links are solid
  strips and snapped links are broken strips, coherence, hold and moves are rows of shapes; every star, link and measure
  can be named in words by the kernel, so no information is carried by hue only.
- **A failure (missing, disconnected, incoherent or budget):** the missing pair or the snapped link is outlined, the
  gauges show what was reached and the failure shown names it, as the kernel's reason does.
- **A won level:** every symbol link glows teal and the hold gauge is full; the frame checks use the same positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** stars are drawn at their starting phases without pulsing and the preview does not play; Reduce
  Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1303-001**: The experience MUST render the stars as instanced ellipsoids with phase hands, the links as
  shader-tinted spline strips, the unlinked symbol pairs as guides, snapped links as broken strips, and the coherence,
  hold and moves gauges entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1303-002**: Materials MUST show a dark sky, star-white stars, silver filaments turning teal where the phases
  agree and plum for guides and what is short of coherence, computed in shaders; every element also has its shape or
  pattern.
- **FR-R02G1303-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G1303-004**: The experience MUST offer three quality tiers that change only wave shells, star pulse and glow,
  never stars, links, guides, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G1303-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for link, unlink, nudge, listen, undo, redo and next level, digest, snapshot and restore), opening certified
  levels of R02-G13-02.
- **FR-R02G1303-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1303-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1303-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1303-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: stars with their starting phases and rates, the links (fixed and placed), the symbol, the kernel's
  listen report of the current state (phases per tick, snapped links, coherence per tick, runs, outcome), threshold,
  hold, window, stage, failure, actions left, budget, level number and presentation time.
- **Constellation geometry**: the sky, the star ellipsoids and phase hands, the link strips, the guides, the broken
  strips, the gauges.
- **Quality tier**: 0, 1 or 2, with its shells, pulse and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1303-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: star, link
  and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1303-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G1303-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1303-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1303-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1303-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (drag links, tap to nudge, orbit) are R02-G13-04; hints and progression R02-G13-05; accessibility and polish
  R02-G13-06; persistence R02-G13-07. This feature gives the experience a minimal control panel (star −/+, partner −/+,
  link, unlink, nudge −/+, listen, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Acoustically
  inspired distance-field reveals" is read as signed-distance shading of the stars and filaments in the fragment
  shaders; the geometry is generated meshes.
- Like Harmonic Bridges, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G13-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G13-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (instanced ellipsoids and shader-tinted spline links) | FR-R02G1303-001 |
| Signature shader (3D oscillatory curves become glowing star networks; instanced line meshes, transient wave shells, distance-field reveals) and palette (star white, teal resonance, plum) | FR-R02G1303-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1303-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1303-004 |
| Renderer purity, stability | FR-R02G1303-003; SC-R02G1303-002, 003 |
| Real render captures | FR-R02G1303-006 |
| "Register it in the catalog" (override) | FR-R02G1303-008 |
| No Stage One breakage | FR-R02G1303-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G13.
