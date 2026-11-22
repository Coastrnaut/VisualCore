# Feature Specification: R02-G09-03 — Nocturne Garden: procedural materials and hero renderer

**Feature Branch**: `383-nocturne-garden-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-22

**Status**: Draft

**Ledger gate**: R02-G09-03 (migration ledger, game feature of experience R02-G09) · ID namespace FR-R02G0903-###,
SC-R02G0903-###, T-R02G0903-###

**Input**: User description: the archived R02-G09-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Nocturne Garden, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/383-nocturne-garden-procedural-materials-and-hero-renderer`; FR-R02G0903-###,
  SC-R02G0903-###, T-R02G0903-###.
- **Packaging (ADR-0009):** the source's `Apps/NocturneGarden` becomes the experience target `NocturneGardenExperience`
  (with its tests) in `Packages/ExperiencesRound02/NocturneGarden/Experience` beside the existing `NocturneGardenCore`;
  the experience `r02-g09.nocturne-garden` (free) is registered in the catalog as a candidate (not available) and linked
  into the one app, as Faceted Forge was at R02-G08-03; it becomes available only at its gate X-R02-G09.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 76" is a milestone figure — the catalog
  is the 100 certified levels of R02-G09-02. **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded
  as `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F10 (quality tiers and
  non-colour clues) and the shared custom-shader mesh renderer added at R02-G01-03, through the existing VisualCore
  packages; the kernel and certified levels of R02-G09-01 and -02.
- **Model:** feature 373 (Faceted Forge's hero renderer) for the adapter, snapshot, geometry, CPU reference, scenarios,
  presenter, scene, fallback and registration.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See black botanical shadows climb through pearlescent mist (Priority: P1) 🎯

A player opens Nocturne Garden and sees a garden bed standing as a wall of luminous pearlescent mist on a midnight-blue
ground. The target silhouette is outlined in parchment gold on the mist, the forbidden regions glow lantern coral with a
hatch, and a lantern on the side shows the sun's elevation. Each planted bloom stands in front of the mist as a
procedurally grown flower (a stem with leaves and a head of its kind) and casts a deep black shadow onto the mist exactly
where the rules say its shadow falls; a gauge shows the moves spent against the budget.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose shadow cells,
target outline, forbidden cells and bloom heads are where a CPU reference of the same snapshot says they are, in the
stated colours.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose shadow, target and
   forbidden pixels match the CPU reference within stated bounds.
2. **Given** an action from the rule kernel, **When** the next frame is drawn, **Then** the blooms, the shadows, the
   lantern and the move gauge follow, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, presentation time or rendering failure, the drawn image never changes the
kernel's state or verdict; the renderer only reads the kernel's immutable snapshot, and the shadow drawn is the
kernel's exact mask, never a shadow computed by the graphics.

**Why this priority**: renderer purity is a certification invariant.

**Independent Test**: changing tier, presentation time and frame count never changes the kernel's digest; a failed
shader leaves the logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer mist layers, simpler stems and hard shadow edges with no glow but keeps the same
objective, cells, colours and indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the shadow cells, the target outline, the forbidden cells and the bloom
heads at the same places; only mist layers, stem detail, shadow softness and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see
it as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for
  every aspect ratio from 0.4 to 2.5 the camera fits the whole bed, the blooms and the gauge with a margin of at least
  5 % on each side.
- **Colour-blind players:** the target is an outline with a gold rim and the forbidden cells carry a hatch as well as
  their colour, the shadow is the darkest element, a leak marks the leaking cells with a cross, and each bloom, region
  and measure can be named in words by the kernel, so no information is carried by hue only.
- **A leak failure:** the leaking cells are marked distinctly and the failure shown names the action, as the kernel's
  reason does.
- **A won level:** the blooms brighten and the shadow is shown whole; the frame checks use the same cells.
- **An empty bed:** with no bloom planted the mist shows only the target and the forbidden cells; nothing is dark.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the mist drift and the bloom sway stand still; Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0903-001**: The experience MUST render the bed as a mist plane, the target outline, the forbidden cells, the
  kernel's exact shadow mask, every planted bloom as a procedurally grown flower (stem, leaves, a head shaped by its
  kind's outline), the sun lantern and the move gauge entirely from generated geometry and shader code, with no image
  assets.
- **FR-R02G0903-002**: Materials MUST show a midnight-blue ground, luminous pearlescent mist with drifting layers, deep
  black shadows with a soft edge approximation, a parchment-gold target outline, lantern-coral forbidden cells with a
  hatch and glowing bloom heads, computed in shaders; every element also has its shape or pattern.
- **FR-R02G0903-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict; the shadow drawn is the kernel's mask.
- **FR-R02G0903-004**: The experience MUST offer three quality tiers that change only mist layers, stem detail, shadow
  softness and glow, never cells, colours, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0903-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for plant, move, resize, remove, sun, undo, redo and next level, digest, snapshot and restore), opening
  certified levels of R02-G09-02.
- **FR-R02G0903-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be
  checked on the simulator within stated bounds.
- **FR-R02G0903-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as
  the edge cases state.
- **FR-R02G0903-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0903-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the bed size, the target, forbidden and shadow cells, the blooms (kind, anchor, size), the sun,
  stage, failure, moves spent, budget, level number and presentation time.
- **Garden geometry**: the ground, the mist plane with its cells, the target outline, the forbidden hatch, the shadow
  cells, the grown blooms, the lantern and the move gauge.
- **Quality tier**: 0, 1 or 2, with its mist layers, stem detail, shadow softness and glow.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario
  manifest and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0903-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: shadow,
  target and forbidden cell positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0903-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0903-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for
  every extreme setting.
- **SC-R02G0903-004**: The candidate passes the experience package, registry, catalog and content checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G0903-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0903-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures (dragging stems, pinching to scale, sliding the sun) are R02-G09-04; hints and progression R02-G09-05;
  accessibility and polish R02-G09-06; persistence R02-G09-07. This feature gives the experience a minimal control panel
  (kind picker, column and row −/+, size, plant, bloom picker, move, resize, remove, sun −/+, undo, redo, next level,
  each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Faceted Forge, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`,
  fixtures and the 80 acceptance scenarios of the archived matrix (R2-G09-QA-001 … 080), and its registration carries
  the content facts (100 levels and the pinned catalog digest ce13750a…).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Required geometry (L-system stems, leaf polygons and projected shadow mesh) | FR-R02G0903-001 |
| Signature shader (deep black botanical shadows on coloured mist planes; soft shadow approximation) and palette (midnight blue, lantern coral, parchment gold) | FR-R02G0903-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0903-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0903-004 |
| Renderer purity, stability | FR-R02G0903-003; SC-R02G0903-002, 003 |
| Real render captures | FR-R02G0903-006 |
| "Register it in the catalog" (override) | FR-R02G0903-008 |
| No Stage One breakage | FR-R02G0903-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G09.
