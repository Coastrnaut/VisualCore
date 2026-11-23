# Feature Specification: R02-G12-03 — Harmonic Bridges: procedural materials and hero renderer

**Feature Branch**: `413-harmonic-bridges-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-23

**Status**: Draft

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
