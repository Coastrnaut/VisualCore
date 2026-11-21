# Feature Specification: R02-G04-03 — Hue Compass: procedural materials and hero renderer

**Feature Branch**: `333-hue-compass-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-21

**Status**: Clarified

**Ledger gate**: R02-G04-03 (migration ledger, game feature of experience R02-G04) · ID namespace FR-R02G0403-###,
SC-R02G0403-###, T-R02G0403-###

**Input**: User description: the archived R02-G04-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Hue Compass (code-only hero:
"prismatic glass vectors floating within luminous spectral fog"), with the canonical overrides of ADR-0009 and
Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/333-hue-compass-procedural-materials-and-hero-renderer`; FR-R02G0403-###,
  SC-R02G0403-###, T-R02G0403-###.
- **Packaging (ADR-0009):** the source's `Apps/HueCompass` becomes the experience target `HueCompassExperience` (with its
  tests) in `Packages/ExperiencesRound02/HueCompass/Experience` beside the existing `HueCompassCore`; the experience
  `r02-g04.hue-compass` (free) is registered in the catalog as a candidate (not available) and linked into the one app,
  as Wave Knot Keeper was at R02-G03-03; it becomes available only at its gate X-R02-G04.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 76" (the 100 certified levels of R02-G04-02
  are the content). **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as `{device}` tasks for
  after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers) and
  the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore packages; the kernel and
  certified levels of R02-G04-01 and -02.

## Clarifications

### Session 2026-11-21

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only, 2026-11-21): Wave Knot Keeper's experience (R02-G03-03 … 10) is the pattern in this package — a Core
adapter, an immutable scene snapshot, a CPU projection reference, GLSL sources in the Core, an iOS-only experience target
with presenter, scene and controls, a scenario manifest with 80 acceptance scenarios, a registration with content facts
(`Catalog/registrations.json`: capabilities, quality tiers, palette, content, manifest, permissions, summary), and the
public `ShaderMeshRenderer`; the Hue Compass kernel provides the level, play, wheel, clues and the certified catalog with
its pinned digest (fcb10a90…8b15); the archive holds the rows R2-G04-QA-001 … 080 and the visual design (prismatic glass
vectors in luminous spectral fog, instanced translucent prisms, analytic fog depth, a full-spectrum wheel with grayscale
evidence glyphs, tiers that change only tessellation and glow); `AppModelTests` uses `r02-g04.hue-compass` as its
example of an unregistered candidate.

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the compass lies in the xy-plane
  with bearing b at angle 2πb/96 counter-clockwise from +x, as in the kernel. The needle is a glass prism from the centre
  to radius 0.8 at the current bearing; 96 thin ticks sit at radius 0.95 … 1.0; the hue wheel is 24 arc segments
  between radius 0.82 and 0.92, band h coloured by hue (h/24) at saturation 0.85 and value 1.0, each with a grayscale
  glyph (shape h mod 4: dot, bar, triangle, ring; and ⌊h/4⌋ + 1 marks) so no band is told by colour alone; the fog is 96
  translucent prisms at radius 1.1 … 1.25, height 0.04 + 0.03 × density and brightness density/9 (luminance only); each
  probed bearing carries a pearl mark at radius 1.32 and the selection an ember mark; after the play ends the target
  bearing carries a sapphire ring. The camera is a fixed authored perspective looking down the z axis tilted 35° about x,
  fitting the compass's bounding circle of radius 1.4 (swipe and orbit come in R02-G04-04). The fog drifts slowly
  (presentation time only). Nothing drawn is consulted by the rules. Impact: FR-R02G0403-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): needle prism with 12 facets, 3 fog layers, 2 glow
  shells; `level-1`: 8 facets, 2 fog layers, 1 glow shell; `level-2` (the design's "Tier 0, D3-safe"): 4 facets, 1 fog
  layer, no glow. Bearings, colours, glyphs and marks sit at the same places at every tier. Levels are ordered richest
  first; the presenter logs each tier change with its reason. Impact: FR-R02G0403-004; SC-R02G0403-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects the needle tip,
  every band segment's centre, every fog prism's top and the probe marks through the same camera and gives the palette.
  Simulator tests render offscreen at 1,152 × 768 and check that the needle tip and each probe mark lie within 3 pixels
  of a pixel brighter than the background by at least 0.15 in luminance, that each band segment's centre pixel is within
  0.15 per channel of its band colour, and that the background matches night within 0.05 away from geometry. Palette:
  night #05070F, pearl #E8E4DA, sapphire #2F6FD8, ember #E0703A, plus the 24 band colours. Impact: FR-R02G0403-006;
  SC-R02G0403-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `HueCompassSceneSnapshot` (bearing, offset, fog, tolerances, clues, selection, stage, frame time, and the target only
  when the stage is won, failed or result) made by the adapter; it never holds the kernel. If a program fails to compile
  or link, the scene draws the level-2 geometry unlit with the shared unlit mesh renderer, keeps `fallbackReason` and
  keeps running; tier changes go to its `tierLog`. Reduce Motion holds the fog drift at time 0; Reduce Flashing caps the
  glow gain. Impact: FR-R02G0403-003, 007; SC-R02G0403-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g04.hue-compass` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the four palette colours, the
  scenario manifest `Packages/ExperiencesRound02/HueCompass/scenario-manifest.json`, no permissions, a summary of at
  most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's experience
  registry link `HueCompassExperience` as a candidate (`available: false` until X-R02-G04), opening at seed 0 (level 1);
  `AppModelTests` switches its unregistered example to the next round-two game (`r02-g05.colorfall-canyons`). The adapter
  (`HueCompassExperienceCore`) prepares certified level (seed mod 100) + 1 and accepts `compass.turn [steps]` (whole,
  −48 … 48, not 0), `compass.probe`, `compass.select [bearing, band]`, `play.undo`, `play.redo` and `level.next`; the kernel
  refuses everything out of range or out of stage; its digest is the level number and the play's fingerprint (never the
  record history, so undo restores the earlier digest); snapshot schema 1 `{level, records}`. Impact: FR-R02G0403-005,
  008, 009; SC-R02G0403-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the spectral compass (Priority: P1) 🎯

A player opens Hue Compass and sees a compass of prismatic glass vectors floating in luminous spectral fog: the
full-spectrum wheel of hue bands around it, the fog's density shown as brightness, the needle at the current bearing,
and marks at every bearing already probed.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose wheel, fog,
needle and probe marks are where a CPU reference of the same snapshot says they are, in the stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose needle, wheel and
   fog pixels match the CPU reference within stated bounds.
2. **Given** a turn or probe from the rule kernel, **When** the next frame is drawn, **Then** the needle and probe marks
   follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, time or rendering failure, the drawn image never changes whether a level is won
or failed; the renderer only reads the kernel's immutable snapshot. The hidden target is never drawn before the play
ends.

**Why this priority**: renderer purity is a certification invariant, and drawing the target early would give the
answer away.

**Independent Test**: changing tier, time and frame count never changes the kernel's digest; a failed shader leaves the
logical state intact and shows a fallback; no frame of a playing level differs when only the target changes.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer facets and simpler fog but keeps the same objective, bearings, colours and
indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the needle, the wheel and the probe marks at the same places; only facet
counts, fog layers and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole compass with a margin of at least 5 % on each side.
- **Colour-blind players:** every hue band also has a distinct grayscale glyph, and fog density is shown by brightness
  alone, so no information is carried by hue only.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the fog drift stands still (time 0); Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0403-001**: The experience MUST render the compass (needle as a prismatic glass vector, 96 bearing ticks), the
  hue wheel of 24 bands, the fog of 96 bearings and the probe and selection marks entirely from generated geometry and
  shader code, with no image assets.
- **FR-R02G0403-002**: Materials MUST show glass facets with a fresnel rim, a spectral wheel whose band colours come from
  the kernel's band rule, luminous fog whose brightness follows the fog density, and an emissive glow, computed in
  shaders; every band also has a grayscale glyph.
- **FR-R02G0403-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict; the target is absent from the snapshot until the
  play has ended.
- **FR-R02G0403-004**: The experience MUST offer three quality tiers that change only facets, fog layers and glow, never
  bearings, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0403-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for turns, probes, selections, undo, redo and next level, digest, snapshot and restore), opening certified
  levels of R02-G04-02.
- **FR-R02G0403-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0403-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0403-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0403-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the bearing, the offset, the fog densities, the tolerances, the clues seen, the selection, the stage,
  the target (only after the play has ended) and the frame time.
- **Compass geometry**: needle prism, ticks, band wheel with glyphs, fog prisms, probe and selection marks.
- **Quality tier**: 0, 1 or 2, with its facets, fog layers and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0403-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: needle, wheel
  and fog pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0403-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict, and no playing snapshot carries the target.
- **SC-R02G0403-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0403-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0403-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0403-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Swiping the compass and gestures are R02-G04-04; hints and progression R02-G04-05; accessibility and polish R02-G04-06;
  persistence R02-G04-07. This feature gives the experience a minimal control panel (turn by one and by four bearings,
  probe, a band picker, select, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Wave Knot Keeper, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G04-QA-001 … 080), and its registration carries the
  content facts (100 levels and the pinned catalog digest).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (instanced translucent prisms, analytic fog depth) | FR-R02G0403-001 |
| Signature shader (colour cones, luminous vectors, hue transforms, glass, glow) and palette | FR-R02G0403-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0403-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0403-004 |
| Renderer purity, stability | FR-R02G0403-003; SC-R02G0403-002, 003 |
| Real render captures | FR-R02G0403-006 |
| "Register it in the catalog" (override) | FR-R02G0403-008 |
| No Stage One breakage | FR-R02G0403-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G04.
