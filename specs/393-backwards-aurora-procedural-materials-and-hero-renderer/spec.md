# Feature Specification: R02-G10-03 — Backwards Aurora: procedural materials and hero renderer

**Feature Branch**: `393-backwards-aurora-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G10-03 (migration ledger, game feature of experience R02-G10) · ID namespace FR-R02G1003-###,
SC-R02G1003-###, T-R02G1003-###

**Input**: User description: the archived R02-G10-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Backwards Aurora, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/393-backwards-aurora-procedural-materials-and-hero-renderer`; FR-R02G1003-###,
  SC-R02G1003-###, T-R02G1003-###.
- **Packaging (ADR-0009):** the source's `Apps/BackwardsAurora` becomes the experience target
  `BackwardsAuroraExperience` (with its tests) in `Packages/ExperiencesRound02/BackwardsAurora/Experience` beside the
  existing `BackwardsAuroraCore`; the experience `r02-g10.backwards-aurora` (free) is registered in the catalog as a
  candidate (not available) and linked into the one app, as Nocturne Garden was at R02-G09-03; it becomes available only
  at its gate X-R02-G10.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 76" is a milestone figure — the catalog
  is the 100 certified levels of R02-G10-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded
  as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G10-01 and -02.
- **Model:** feature 383 (Nocturne Garden's hero renderer) for the adapter, snapshot, geometry, CPU reference,
  scenarios, presenter, scene, fallback and registration.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See rivers of aurora folding backward through time (Priority: P1) 🎯

A player opens Backwards Aurora and sees, on a midnight sky, an aurora drawn as a glowing deep-ocean-cyan ribbon that
follows the wave's samples along a timeline. The true signal is a pale lilac ghost trail behind it; checkpoints stand as
vertical markers with a ring at the true height, filled when the wave reaches it; every bend sharper than the limit is
marked with a kink cross; the section chosen for reversal is a band behind the ribbon; a gauge shows the reversals spent
against the budget. When a section is reversed, the ribbon's samples in it swap order exactly as the rules say.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose ribbon samples,
ghost trail, checkpoint markers and gauge are where a CPU reference of the same snapshot says they are, in the stated
colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose ribbon, ghost and
   marker pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the ribbon, the kink marks,
   the checkpoint rings and the gauge follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot, and the wave drawn is the kernel's
exact samples, never a curve computed by the graphics.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer trailing aurora layers, no travelling pulses and no glow but keeps the same
objective, samples, markers, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the ribbon samples, the ghost trail, the checkpoint markers and the gauge at
the same places; only trailing layers, pulses and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for
  every aspect ratio from 0.4 to 2.5 the camera fits the whole timeline, every possible height, the markers and the
  gauge with a margin of at least 5 % on each side.
- **Colour-blind players:** checkpoints are rings (filled when matched), sharp bends carry a kink cross, a tear carries a
  larger cross at its seam, the chosen section is a band with dashed edges, and every sample, checkpoint, bend and
  measure can be named in words by the kernel, so no information is carried by hue only.
- **A tear failure:** the seam that broke is marked distinctly and the failure shown names the reversal and the seam, as
  the kernel's reason does.
- **A won level:** the ribbon brightens and every ring is filled; the frame checks use the same samples.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the travelling pulses and the ribbon's shimmer stand still; Reduce Flashing caps the glow to the
  shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G1003-001**: The experience MUST render the wave as a tessellated temporal ribbon through the kernel's exact
  samples, the target as a ghost trail, the checkpoints as markers, the sharp bends as kink marks, the chosen section as
  a band and the reversal gauge entirely from generated geometry and shader code, with no image assets.
- **FR-R02G1003-002**: Materials MUST show a midnight ground, a glowing deep-ocean-cyan aurora ribbon with trailing
  layers and direction-coded pulses along the timeline, a pale lilac ghost trail and marker colours, computed in
  shaders; every element also has its shape or pattern.
- **FR-R02G1003-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result,
  tier, time or failure may change the kernel's state, digest or verdict; the samples drawn are the kernel's samples.
- **FR-R02G1003-004**: The experience MUST offer three quality tiers that change only trailing layers, pulses and glow,
  never samples, markers, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G1003-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for reverse, undo, redo and next level, digest, snapshot and restore), opening certified levels of R02-G10-02.
- **FR-R02G1003-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G1003-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G1003-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G1003-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the wave and target samples, the checkpoints and which are matched, the bend limit and the sharp
  bends, the chosen section, the stage, failure, reversals spent, budget, level number and presentation time.
- **Aurora geometry**: the ground, the ribbon and its trailing layers, the ghost trail, the checkpoint markers, the kink
  marks, the section band and the reversal gauge.
- **Quality tier**: 0, 1 or 2, with its trailing layers, pulses and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario
  manifest and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G1003-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: ribbon,
  ghost and marker positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G1003-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change
  the kernel digest or verdict.
- **SC-R02G1003-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G1003-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G1003-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G1003-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (tapping segment ends, swiping to reverse, the timeline freeze preview) are R02-G10-04; hints and
  progression R02-G10-05; accessibility and polish R02-G10-06; persistence R02-G10-07. This feature gives the
  experience a minimal control panel (start −/+, end −/+, reverse, undo, redo, next level, each labelled) so it can be
  exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Nocturne Garden, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G10-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest of R02-G10-02).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (tessellated temporal ribbon with direction-coded pulses) | FR-R02G1003-001 |
| Signature shader (auroral ribbons fold backward along procedural timelines; deterministic timeline buffers, ghost trails, reversible deformation shaders) and palette (deep ocean cyan, pale lilac, midnight) | FR-R02G1003-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G1003-003, 005 |
| Quality tiers 0/1/2 | FR-R02G1003-004 |
| Renderer purity, stability | FR-R02G1003-003; SC-R02G1003-002, 003 |
| Real render captures | FR-R02G1003-006 |
| "Register it in the catalog" (override) | FR-R02G1003-008 |
| No Stage One breakage | FR-R02G1003-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G10.
