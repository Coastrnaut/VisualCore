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

## Clarifications

### Session 2026-11-22

Answered autonomously under the owner's standing delegation, safest well-supported option each time, following feature
373's answers where the games agree. Facts checked in code (read-only, 2026-11-22): Faceted Forge's experience
(R02-G08-03 … 10) is the pattern in this package — a Core adapter with a table of certified candidates (each level's
`skipped`) so a level is certified directly from its candidate, an immutable scene snapshot, a CPU projection reference,
GLSL sources in the Core, an iOS-only experience target (`…Experience.swift`, presenter, scene, controls), a scenario
manifest with 80 acceptance scenarios, a registration with content facts in `Catalog/registrations.json` and the public
`ShaderMeshRenderer`; the Nocturne Garden kernel provides the level (bed W × H, target and forbidden cells, supply,
sizes, elevations, opening sun, budget, required match, leak allowance), blooms with exact cells, the mask with match,
leak and deviation, the play (plant, move, resize, remove, sun, undo, redo, stages, failure leak(move) or budget) and
the certified catalog with its pinned digest (ce13750a…52dd); `AppModelTests` uses `r02-g09.nocturne-garden` as its
example of an unregistered candidate and the next round-two game is `r02-g10.backwards-aurora`; the catalog's design
gives the palette "midnight blue, lantern coral and parchment gold", the hero "black botanical silhouettes climbing
through luminous pearlescent mist" and the geometry "L-system stems, leaf polygons and projected shadow mesh".

- Q: What exactly does the scene show, and how does it map the rules to space? → A: the bed stands upright as the mist
  plane z = 0 with y up: with u = 2 / W, cell (column c, row r) spans x from −1 + c·u to −1 + (c + 1)·u and y from r·u
  to (r + 1)·u (row 0 at the bottom, where the blooms' feet are). Every cell of the kernel's mask is a shadow quad on
  the plane; the target's boundary edges carry a gold rim; the forbidden cells a coral hatch; after a leak failure the
  leaking cells (mask ∩ forbidden) a cross. Each bloom is a flower grown in front of the plane at z = 0.35: its head is
  its kind's outline at size·u (unstretched), anchored at the anchor cell's lower-left corner, extruded 0.04 deep with
  a glowing rim; its stem is an L-system of `stemDepth` levels from the foot with a leaf pair at each level. The lantern
  (the sun) is a glowing sphere at x = 1.25 whose height falls with the elevation (y = (1.15 − 0.25·(e − 1))·H·u). The
  move gauge is a row of `budget` small bars below the bed (y = −0.1, x from −0.9 to 0.9), spent ones lit coral. The
  ground is a midnight plane at y = −0.2. The camera is a fixed authored perspective looking at the bed's centre from
  +z, pitched 8° down, fitted to the bounding sphere of the bed, the lantern and the gauge with a 5 % margin for aspect
  0.4 … 2.5. Mist drift and bloom sway move with presentation time only. Nothing drawn is consulted by the rules.
  Impact: FR-R02G0903-001, 002, 006.
- Q: What do the three quality tiers change? → A: `level-0` (richest): 3 mist layers, stem depth 3, shadow edge
  feather 0.3 cell, 2 glow shells around bloom heads; `level-1`: 2 mist layers, stem depth 2, feather 0.15, 1 glow
  shell; `level-2` (the design's "Tier 0, D3-safe"): 1 mist layer, stem depth 1, hard shadow edges, no glow. Cells,
  blooms' heads, target, forbidden cells, colours, gauge and positions are the same at every tier. Levels are ordered
  richest first; the presenter logs each tier change with its reason. Impact: FR-R02G0903-004; SC-R02G0903-001.
- Q: How are rendered frames checked, and within which bounds? → A: the Core's CPU reference projects the centre of
  every bed cell, the gauge's first bar and the screen box of every bloom (head and stem) through the same camera and
  gives the palette. Simulator tests render offscreen at 1,152 × 768 and, at cell centres outside every bloom's box
  (± 3 pixels), check that every shadow cell is darker than the mist by at least 0.15 in luminance, that every
  forbidden cell outside the shadow is warmer than the mist (red minus blue at least 0.15), that every target cell
  outside the shadow differs from a shadow cell by at least 0.15 in luminance, that the gauge's first bar differs from
  the ground by at least 0.1, and that the background matches the ground within 0.05 away from geometry. Palette:
  ground #0A1230, mist #B8C4E0, mist highlight #E6ECF7, shadow #05060A, target gold #E8C872, forbidden coral #FF7A5C,
  leak cross #FF3B30, bloom body #10131C, bloom glow #FFB88A, lantern #FFD9A0, spent mark #FF7A5C, unspent mark
  #3A4558. Impact: FR-R02G0903-006; SC-R02G0903-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `NocturneGardenSceneSnapshot` (bed size, the target, forbidden, shadow and leaking cells as sorted arrays, the blooms
  with kind, anchor and size, the sun, stage, failure, moves spent, budget, level number and presentation time) made by
  the adapter; it never holds the kernel. If a program fails to compile or link, the scene draws the level-2 geometry
  unlit with the shared unlit mesh renderer, keeps `fallbackReason` and keeps running; tier changes go to its
  `tierLog`. Reduce Motion holds mist drift and sway at time 0; Reduce Flashing caps the glow gain. A leak failure
  marks the leaking cells with the cross colour and the failure text names the action, as the kernel's reason does.
  Impact: FR-R02G0903-003, 007; SC-R02G0903-002.
- Q: How is the experience registered and what does the adapter accept? → A: `Catalog/registrations.json` gains
  `r02-g09.nocturne-garden` (capabilities of at most 40 characters, tiers `level-0` … `level-2`, the palette, the
  scenario manifest `Packages/ExperiencesRound02/NocturneGarden/scenario-manifest.json`, no permissions, a summary of
  at most 300 characters, content facts: 100 levels and the pinned catalog digest); `project.yml` and the app's
  experience registry link `NocturneGardenExperience` as a candidate (`available: false` until X-R02-G09), opening at
  seed 0 (level 1); `AppModelTests` switches its unregistered example to the next round-two game
  (`r02-g10.backwards-aurora`). The adapter (`NocturneGardenExperienceCore`) prepares certified level (seed mod 100) + 1
  from its table of certified candidates (the whole generator only if that candidate no longer certifies) and accepts
  `bloom.plant [kind, column, row, size]` (kind 0 … 5 in the kernel's kind order), `bloom.move [bloom, column, row]`,
  `bloom.resize [bloom, size]`, `bloom.remove [bloom]`, `sun.set [elevation]`, `play.undo`, `play.redo` and
  `level.next` (whole numbers only); the kernel refuses everything out of range or out of stage; its digest is the level
  number and the play's fingerprint (never the record history, so undo restores the earlier digest); snapshot schema 1
  `{level, records}`. The panel's choices (kind, column, row, size, bloom) are presentation state of the controls, not
  kernel state: a level opens with its first supplied kind, column 0, row 0, its smallest size and bloom 0; after an
  action, undo or redo the chosen bloom is clamped to the blooms planted. Impact: FR-R02G0903-005, 008, 009;
  SC-R02G0903-004.

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
