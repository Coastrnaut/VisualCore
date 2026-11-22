# Feature Specification: R02-G06-03 — Chrono Constellator: procedural materials and hero renderer

**Feature Branch**: `353-chrono-constellator-procedural-materials-and-hero-renderer` (spec directory only; work on
`main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G06-03 (migration ledger, game feature of experience R02-G06) · ID namespace FR-R02G0603-###,
SC-R02G0603-###, T-R02G0603-###

**Input**: User description: the archived R02-G06-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Chrono Constellator (code-only
hero: "glowing temporal ribbons resembling a woven astronomical score"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/353-chrono-constellator-procedural-materials-and-hero-renderer`;
  FR-R02G0603-###, SC-R02G0603-###, T-R02G0603-###.
- **Packaging (ADR-0009):** the source's `Apps/ChronoConstellator` becomes the experience target
  `ChronoConstellatorExperience` (with its tests) in `Packages/ExperiencesRound02/ChronoConstellator/Experience` beside
  the existing `ChronoConstellatorCore`; the experience `r02-g06.chrono-constellator` (free) is registered in the catalog
  as a candidate (not available) and linked into the one app, as Colorfall Canyons was at R02-G05-03; it becomes available
  only at its gate X-R02-G06.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 78" is a milestone figure — the catalog is
  the 100 certified levels of R02-G06-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G06-01 and -02.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
343's answers. Facts checked in code (read-only, 2026-11-21): Colorfall Canyons's experience (R02-G05-03 … 10) is the
pattern in this package — a Core adapter with a per-process cache of generated levels, an immutable scene snapshot, a CPU
projection reference, GLSL sources in the Core, an iOS-only experience target (`…Experience.swift`, presenter, scene,
controls), a scenario manifest with 80 acceptance scenarios, a registration with content facts in
`Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Chrono Constellator kernel provides the level,
timeline, evaluation, play, rules and the certified catalog with its pinned digest (6483b20e…6ffc); `AppModelTests` uses
`r02-g06.chrono-constellator` as its example of an unregistered candidate; the catalog's design gives the palette
"indigo, silver and rose" and the geometry "polyline history cache with predictable alpha decay".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the grid lies in the xz-plane with
  cell size u = 2 / max(columns, rows), column c at x = (c − (columns − 1)/2)·u and row r at z = (r − (rows − 1)/2)·u, y up.
  The field is an indigo plane at y = 0 with faint grid lines; each star's loop is a silver track (width 0.08·u, y =
  0.004·u) through its cells' centres; each star is a glowing node (radius 0.3·u, centre y = 0.25·u) drawn with its shape
  (ring, cross, diamond, triangle, square); each target is a rose ring (outer radius 0.42·u, y = 0.006·u) with its
  star's shape inside; a star on its target lights the ring. Each star's history ribbon joins its cells over the last R
  ticks (R by tier), each tick's point raised by 0.04·u per tick of age above the node height, so older paths float up
  like staves of a score, with alpha 1 − age / R (the predictable decay); holds draw as a short vertical bar at the held
  cell; a collision cell gets an amber cross. The camera is a fixed authored perspective looking at the grid centre from
  the front (+z), pitched 55° down, fitted to the bounding sphere of the grid with the ribbons' full height plus 0.1, with
  a 5 % margin for aspect 0.4 … 2.5. Ribbon shimmer moves with presentation time only. Nothing drawn is consulted by the
  rules. Impact: FR-R02G0603-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): ribbons of R = 24 ticks, 4 segments per tick, 2
  glow shells; `level-1`: R = 12, 2 segments, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): R = 6, 1 segment,
  no glow. Stars, targets, tracks, colours, shapes and marks sit at the same places at every tier. Levels are ordered
  richest first; the presenter logs each tier change with its reason. Impact: FR-R02G0603-004; SC-R02G0603-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects every star node
  centre, every target centre and every loop cell centre through the same camera and gives the palette. Simulator tests
  render offscreen at 1,152 × 768 and check that each star centre lies within 3 pixels of a pixel brighter than the field
  by at least 0.15 in luminance, that each target centre's ring (sampled at 0.42·u from the centre in screen space, ± 3
  pixels) differs from the field by at least 0.1, and that the background matches the field within 0.05 away from
  geometry. Palette: field indigo #0B0A24, grid #1C1A44, silver #C9CED8, star #F2F4FF, rose #FF5C8A, collision amber
  #FFB020. Impact: FR-R02G0603-006; SC-R02G0603-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `ChronoConstellatorSceneSnapshot` (grid, every star's loop, target, current cell and the cells of its last 24 ticks, the
  timeline's phases and holds, stage, failure, tick, level number and presentation time) made by the adapter; it never
  holds the kernel. If a program fails to compile or link, the scene draws the level-2 geometry unlit with the shared
  unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its `tierLog`. Reduce Motion holds the
  ribbon shimmer at time 0; Reduce Flashing caps the glow gain. Impact: FR-R02G0603-003, 007; SC-R02G0603-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g06.chrono-constellator` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/ChronoConstellator/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's experience
  registry link `ChronoConstellatorExperience` as a candidate (`available: false` until X-R02-G06), opening at seed 0
  (level 1); `AppModelTests` switches its unregistered example to the next round-two game (`r02-g07.amethyst-escape`).
  The adapter (`ChronoConstellatorExperienceCore`) prepares certified level (seed mod 100) + 1 (generated once per
  process) and accepts `star.phase [star, offset]` (whole, 0 … 4, 0 … 31), `star.hold [star, start, length]` (whole, 0 … 4,
  1 … 1,200, 1 … 60), `star.release [star, start]`, `time.step [ticks]` (whole, 1 … 1,200), `time.rewind`, `play.undo`,
  `play.redo` and `level.next`; the kernel refuses everything out of range or out of stage; its digest is the level number
  and the play's fingerprint (never the record history, so undo restores the earlier digest); snapshot schema 1
  `{level, records}`. Impact: FR-R02G0603-005, 008, 009; SC-R02G0603-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the woven sky (Priority: P1) 🎯

A player opens Chrono Constellator and sees a dark indigo sky with faint silver tracks of each star's loop, glowing
stars of distinct shapes, rose target rings, and glowing ribbons of each star's recent path woven across the sky like an
astronomical score as the timeline replays.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose stars, targets
and tracks are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose star, target and
   track pixels match the CPU reference within stated bounds.
2. **Given** a phase change, hold, step or rewind from the rule kernel, **When** the next frame is drawn, **Then** the
   stars, ribbons and timeline marks follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity is a certification invariant.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed shader
leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses shorter ribbons, fewer ribbon segments and no glow but keeps the same objective, stars,
targets, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the stars, targets and tracks at the same places; only ribbon length and
segments and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole sky grid with a margin of at least 5 % on each side.
- **Colour-blind players:** every star has its shape (ring, cross, diamond, triangle, square), every target repeats its
  star's shape, and collisions and holds have marks, so no information is carried by hue only.
- **Two stars on one cell (a collision):** the cell is marked distinctly and the failure shown names both stars.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the ribbons' shimmer stands still; Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0603-001**: The experience MUST render the sky grid, every star's loop track, the stars, their targets, the
  history ribbons and the timeline marks (holds, the current tick) entirely from generated geometry and shader code, with
  no image assets.
- **FR-R02G0603-002**: Materials MUST show an indigo night field, silver tracks, glowing stars in their shapes, rose
  target rings, emissive ribbons whose brightness fades with age, and an emissive glow, computed in shaders; every star
  also has its shape.
- **FR-R02G0603-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G0603-004**: The experience MUST offer three quality tiers that change only ribbon length and segments and glow,
  never stars, targets, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0603-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for phases, holds, releases, steps, rewind, undo, redo and next level, digest, snapshot and restore), opening
  certified levels of R02-G06-02.
- **FR-R02G0603-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0603-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0603-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0603-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the level's grid, every star (loop, target, current cell, recent path), the timeline (phases,
  holds), stage, failure, tick and presentation time.
- **Sky geometry**: the field, loop tracks, star nodes, target rings, history ribbons and timeline marks.
- **Quality tier**: 0, 1 or 2, with its ribbon length, segments and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0603-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: star, target
  and track pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0603-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0603-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0603-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0603-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0603-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (scrubbing the timeline, dragging a star's start marker, orbit) are R02-G06-04; hints and progression
  R02-G06-05; accessibility and polish R02-G06-06; persistence R02-G06-07. This feature gives the experience a minimal
  control panel (a star picker, phase − and +, add and remove a hold, step 1 and step 10 ticks, run to the end, rewind,
  undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Colorfall Canyons, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G06-QA-001 … 080), and its registration carries the
  content facts (100 levels and the pinned catalog digest).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (polyline history cache with predictable alpha decay) | FR-R02G0603-001 |
| Signature shader (3D star traces accumulate into glowing history ribbons; ghost trails) and palette (indigo, silver, rose) | FR-R02G0603-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0603-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0603-004 |
| Renderer purity, stability | FR-R02G0603-003; SC-R02G0603-002, 003 |
| Real render captures | FR-R02G0603-006 |
| "Register it in the catalog" (override) | FR-R02G0603-008 |
| No Stage One breakage | FR-R02G0603-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G06.
