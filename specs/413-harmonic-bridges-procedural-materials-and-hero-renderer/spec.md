# Feature Specification: R02-G12-03 — Harmonic Bridges: procedural materials and hero renderer

**Feature Branch**: `413-harmonic-bridges-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Clarified

**Ledger gate**: R02-G12-03 (migration ledger, game feature of experience R02-G12) · ID namespace FR-R02G1203-###,
SC-R02G1203-###, T-R02G1203-###

**Input**: User description: the archived R02-G12-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Harmonic Bridges, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/413-harmonic-bridges-procedural-materials-and-hero-renderer`; FR-R02G1203-###,
  SC-R02G1203-###, T-R02G1203-###.
- **Packaging (ADR-0009):** the source's `Apps/HarmonicBridges` becomes the experience target
  `HarmonicBridgesExperience` (with its tests) in `Packages/ExperiencesRound02/HarmonicBridges/Experience` beside the
  existing `HarmonicBridgesCore`; the experience `r02-g12.harmonic-bridges` (free) is registered in the catalog as a
  candidate (not available) and linked into the one app, as Echo Cartographer was at R02-G11-03; it becomes available
  only at its gate X-R02-G12.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 82" is a milestone figure — the catalog is
  the 100 certified levels of R02-G12-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G12-01 and -02.
- **Model:** feature 403 (Echo Cartographer's hero renderer).

## Clarifications

### Session 2026-11-23

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
403's answers where the games agree. Facts checked in code (read-only, 2026-11-23): Echo Cartographer's experience
(R02-G11-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates, an immutable
scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
(`…Experience.swift`, presenter, scene, controls), a scenario manifest with 80 acceptance scenarios, a registration with
content facts in `Catalog/registrations.json` and the public `ShaderMeshRenderer`; the Harmonic Bridges kernel provides
the level (islands with drawing positions on a 16 × 10 grid, strings with lengths, pegs and locks, steps of tones,
threshold, budget), the report (swings per step, string and sample; bridges; reached islands), the play (tune, test,
undo, redo, stages, failures broken(step, string) and budget(action)) and the certified catalog with its pinned digest
(b832e7ee…c737); `AppModelTests` uses `r02-g12.harmonic-bridges` as its example of an unregistered candidate and the
next round-two game is `r02-g13.acoustic-constellator`; the catalog's design gives the palette "warm copper, cyan
membranes and mist violet", the hero "strings swelling into translucent glowing architecture as they find resonance"
and the geometry "swept strings and radial wave-shell strip meshes".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the islands stand on the plane
  y = 0 with x to the right and z towards the viewer: island (gx, gy) of the 16 × 10 drawing grid is at
  X = (gx − 7.5) · 0.12, Z = (gy − 4.5) · 0.12. Drawn in this order: the mist ground (a plane at y = −0.01 covering
  x −1.1 … 1.1, z −0.8 … 1.1); each island as a hexagonal prism (radius 0.07, height 0.1) with copper faces and its
  top edges as strips 0.008 thick; a ring (radius 0.1, line 0.012) at y = 0.005 around the start island and a
  four-pointed star (radius 0.1) around the goal; every string as a swept strip 0.012 wide between its islands' top
  centres at y = 0.1, deflected sideways by its drawn wave (presentation only: Σ over its resonant modes in the shown
  step of 0.03 · w · sin(nπu) · cos(2π · n · t / 1.6), u along the string, 24 segments); a string that is a bridge in the
  shown step as a membrane strip 0.05 wide beneath it; on each string the five samples k = 1 … 5 at u = k / 6 as marks
  0.02 wide at y = 0.11, a filled square when the kernel's swing E(k) reaches the threshold and a hollow ring when it
  does not; every island the start reaches in the shown step lit with a glow ring; the window's steps as a row of pips
  at z = 0.8, y = 0 (squares 0.06 wide spread evenly from x = −0.3 to 0.3; filled for the shown step, outlined
  otherwise, a cross on a broken step; corrected at the checklist, 2026-11-23: the pips' extent and size were added) and the moves gauge, a row of
  `budget` bars at z = 0.95, y = 0, spread evenly from x = −0.9 to 0.9 (each 1.8 / budget wide with a gap of a fifth of
  that, 0.05 deep), lit for the actions left. The shown step cycles every 1.2 s of presentation time while playing
  (a test or a win shows every step in turn as well); at time 0 it is step 0. Depth testing is off (the shared mesh
  renderer's path): the ground and the flat layers first, then the membranes, the strings and the marks, then the
  islands back to front (by z from the far side, then by x) with back faces culled, then the pips and the gauge; the
  glow is additive and drawn last. The camera is a fixed authored perspective (eye (0, 1.9, 1.6) looking at
  (0, 0, 0.1)) fitted to the box x −1 … 1, z −0.7 … 1.0, y 0 … 0.2 with a 5 % margin for aspect 0.4 … 2.5. Nothing drawn
  is consulted by the rules; the drawn wave never replaces the kernel's exact swing. Impact: FR-R02G1203-001, 002, 003,
  006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): strings swing, 2 radial wave shells (strip rings 0.01
  wide expanding from each resonating string's midpoint from radius 0 to 0.15 over 1.6 s, at y = 0.1; corrected at
  the checklist, 2026-11-23: the shells' size was added) and 2 glow shells around membranes and reached islands;
  `level-1`: strings swing, no wave shells, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): strings at rest
  (straight), no shells, no glow. Islands, strings, membranes, marks, pips, gauge, colours and positions are the same at
  every tier. Levels are ordered richest first; the presenter logs each tier change with its reason. Impact:
  FR-R02G1203-004; SC-R02G1203-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects every island's
  top centre, every bridge membrane's midpoint (in the shown step, strings at rest), every string's midpoint, the first
  gauge bar and the first step pip through the same camera and gives the palette. Simulator tests render offscreen at
  1,152 × 768 at time 0 and check, at points at least 6 pixels from any other element, that an island's top centre
  differs from the ground by at least 0.1 in luminance with red above blue by at least 0.05 (copper); that a membrane's
  midpoint differs from the ground by at least 0.08 with blue above red by at least 0.05 (cyan); that the gauge's first
  bar differs from the ground by at least 0.1; and that the background matches the ground within 0.05 away from geometry.
  Palette: ground #07060C, island face #7A4A2E, island edge #E0A070, string #C88A5A, membrane #4FD8E8, filled mark
  #B8F4FF, hollow mark #7A6A9C, start ring #F2D2A8, goal star #A894FF, reached glow #8FF4FF, wave shell #6FE0F0, pip
  #4FD8E8, unlit pip #3A3348, lit gauge bar #E0A070, unlit gauge bar #2A2433. Impact: FR-R02G1203-006; SC-R02G1203-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `HarmonicBridgesSceneSnapshot` (islands with positions, strings with ends, lengths, current pegs and locks, the
  kernel's report, the steps' resonant modes per string, threshold, start, goal, stage, failure, actions left, budget,
  level number and presentation time) made by the adapter; it never holds the kernel. If a program fails to compile or
  link, the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps
  running; tier changes go to its `tierLog`. Reduce Motion draws strings at rest and does not cycle the shown step
  (step 0, or the broken step after a failed test); Reduce Flashing caps the glow gain. A failure outlines the broken
  step's pip and the broken string, and the failure text names them, as the kernel's reason does. Impact:
  FR-R02G1203-003, 007; SC-R02G1203-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g12.harmonic-bridges` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/HarmonicBridges/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `HarmonicBridgesExperience` as a candidate (`available: false` until X-R02-G12), opening at
  seed 0 (level 1); `AppModelTests` switches its unregistered example to the next round-two game
  (`r02-g13.acoustic-constellator`). The adapter (`HarmonicBridgesExperienceCore`) prepares certified level (seed mod
  100) + 1 from its table of certified candidates (the whole generator only if that candidate no longer certifies) and
  accepts `string.tune [s, p]`, `crossing.test`, `play.undo`, `play.redo` and `level.next` (whole numbers only); the
  kernel refuses everything out of range or out of stage; its digest is the level number and the play's fingerprint
  (never the record history, so undo restores the earlier digest); snapshot schema 1 `{level, records}`. The panel's
  chosen string and peg are presentation state of the controls, not kernel state: a level opens with string 0 chosen at
  its current peg, both clamped. Impact: FR-R02G1203-005, 008, 009; SC-R02G1203-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See strings swell into glowing architecture as they find resonance (Priority: P1) 🎯

A player opens Harmonic Bridges and sees crystalline copper islands over a dark mist, joined by suspended strings.
Strings that resonate with the sounding tones swing as standing waves; where a string's averaged swing is strong enough
along its whole length it swells into a translucent cyan membrane, a walkway. Islands the start can reach glow; a row of
step markers shows which step of the crossing window is sounding; a gauge shows the moves left.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose islands,
strings, bridges, step markers and gauge are where a CPU reference of the same snapshot says they are, in the stated
colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose island, bridge and
   gauge pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the pegs, the bridges, the
   reachable islands and the gauge follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer reads only the kernel's immutable snapshot, and the drawn swing never replaces
the kernel's exact swing.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses no wave shells and no glow and draws strings at rest but keeps the same objective,
islands, strings, bridges, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the islands, bridges, step markers and gauge at the same places; only
shells, motion and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits every island, the step markers and the gauge with a margin of at least
  5 % on each side.
- **Colour-blind players:** islands are raised prisms, the start has a ring and the goal a star, bridges are wide
  membranes and other strings thin lines, each sample's swing is a filled square when it reaches the threshold and a
  hollow ring when it does not, step markers and the gauge are rows of shapes; every string, bridge and measure can be
  named in words by the kernel, so no information is carried by hue only.
- **A failure (a broken step or the budget spent):** the broken step's marker and the broken string are outlined, the
  gauge shows what is left and the failure shown names the step and the string, as the kernel's reason does.
- **A won level:** every bridge of the path glows and every reached island is lit; the frame checks use the same
  positions.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** strings are drawn at rest (their resting shape, no swinging) and the window's steps do not cycle;
  Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1203-001**: The experience MUST render the islands as crystalline prisms, the strings as swept strips, the
  bridges as membranes, the sample swings, the reachable islands, the step markers and the moves gauge entirely from
  generated geometry and shader code, with no image assets.
- **FR-R02G1203-002**: Materials MUST show a dark mist ground, warm copper islands and strings, cyan membranes for
  bridges and mist violet for what is short of the threshold, computed in shaders; every element also has its shape or
  pattern.
- **FR-R02G1203-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict.
- **FR-R02G1203-004**: The experience MUST offer three quality tiers that change only wave shells, string motion and
  glow, never islands, strings, bridges, colours, objective or indicators; the selected tier and the reason MUST be
  logged.
- **FR-R02G1203-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for tune, test, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G12-02.
- **FR-R02G1203-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1203-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1203-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1203-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: islands, strings with their pegs, the kernel's report (swings, bridges, reached islands per
  step), steps, threshold, stage, failure, actions left, budget, level number and presentation time.
- **Bridge geometry**: the ground, the island prisms, the string strips, the membranes, the sample marks, the step
  markers and the moves gauge.
- **Quality tier**: 0, 1 or 2, with its shells, motion and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1203-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: island,
  bridge and gauge positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1203-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G1203-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1203-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1203-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1203-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (pluck, drag peg, tap freeze) are R02-G12-04; hints and progression R02-G12-05; accessibility and polish
  R02-G12-06; persistence R02-G12-07. This feature gives the experience a minimal control panel (string −/+, peg −/+,
  tune, test, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code. "Acoustically
  inspired distance-field reveals" is read as signed-distance shading of the membranes and prisms in the fragment
  shaders; the geometry is generated meshes.
- Like Echo Cartographer, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G12-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G12-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (swept strings and radial wave-shell strip meshes) | FR-R02G1203-001 |
| Signature shader (oscillating wave membranes between crystalline anchors, instanced line meshes, transient wave shells, distance-field reveals) and palette (warm copper, cyan membranes, mist violet) | FR-R02G1203-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1203-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1203-004 |
| Renderer purity, stability | FR-R02G1203-003; SC-R02G1203-002, 003 |
| Real render captures | FR-R02G1203-006 |
| "Register it in the catalog" (override) | FR-R02G1203-008 |
| No Stage One breakage | FR-R02G1203-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G12.
