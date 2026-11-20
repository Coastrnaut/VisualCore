# Feature Specification: R02-G02-03 — Lissajous Labyrinth: procedural materials and hero renderer

**Feature Branch**: `313-lissajous-labyrinth-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Draft

**Ledger gate**: R02-G02-03 (migration ledger, game feature of experience R02-G02) · ID namespace FR-R02G0203-###,
SC-R02G0203-###, T-R02G0203-###

**Input**: User description: the archived R02-G02-03 `/speckit-specify` prompt (round2.md), verbatim in the invocation:
"Render signature geometry and materials entirely in shaders and generated meshes" for Lissajous Labyrinth, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/313-lissajous-labyrinth-procedural-materials-and-hero-renderer`;
  FR-R02G0203-###, SC-R02G0203-###, T-R02G0203-###.
- **Packaging (ADR-0009):** the source's `Apps/LissajousLabyrinth` becomes the experience target
  `LissajousLabyrinthExperience` (with its tests) in `Packages/ExperiencesRound02/LissajousLabyrinth/Experience` beside
  the existing `LissajousLabyrinthCore`; the experience `r02-g02.lissajous-labyrinth` (free) is registered in the catalog
  as a candidate (not available) and linked into the one app, as Aurora Loom was at R02-G01-03; it becomes available only
  at its gate X-R02-G02.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 90" (the 100 certified levels of R02-G02-02
  are the content). **Device-only items:** frame-time and thermal budgets on D1/D2/D3, recorded as `{device}` tasks for
  after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and glow passes), R02-F08 (curve sampling,
  frames and ribbon meshes), R02-F10 (quality tiers) and the shared custom-shader mesh renderer added at R02-G01-03,
  through the existing VisualCore packages; the kernel and certified levels of R02-G02-01 and -02.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the luminous flower (Priority: P1) 🎯

A player opens Lissajous Labyrinth and sees the tracer's closed path drawn as a luminous ink thread in three dimensions —
a slowly blooming mathematical flower in cobalt, violet and copper — with the checkpoints and obstacles of the level in
the same scene and a bright tracer head moving slowly along the path.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose thread,
checkpoints, obstacles and palette are where a CPU reference of the same snapshot says they are.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose path, checkpoint and
   obstacle pixels match the CPU reference within stated bounds.
2. **Given** a dial change from the rule kernel, **When** the next frame is drawn, **Then** the drawn path follows the
   new dials, and the win or failure shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, time or rendering failure, the drawn image never changes whether a level is won
or failed; the renderer only reads the kernel's immutable snapshot.

**Why this priority**: renderer purity (R2-G02-INV-10) is a certification invariant.

**Independent Test**: changing tier, time and frame count never changes the kernel's digest; a failed shader leaves the
logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer samples and simpler effects but keeps the same objective, coordinates and
indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 draw the same path points, checkpoints and obstacles at the same places; only
sample density, thread width detail, trail length and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: tests and debug builds can open it, players do not see it
as available, and the experience package, registry, catalog and content checks pass.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal tier, unlit), keeps
  the program name and reason, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 to 2.5 the camera fits the whole figure (path, checkpoints and obstacles) inside the view with a
  margin of at least 5 % on each side.
- **Extreme dials** (every legal setting, the largest amplitudes, frequency c = 9): geometry and uniforms stay finite
  and bounded.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the tracer head and shimmer stand still (tick 0); Reduce Flashing caps the glow to the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0203-001**: The experience MUST render the lap's closed path as a thread mesh built from code (the kernel's
  samples with tangent-space width), the checkpoints and the obstacles as generated meshes, and the tracer head, entirely
  from generated geometry and shader code, with no image assets.
- **FR-R02G0203-002**: Thread materials MUST show luminous ink with depth fading, an emissive glow and interference
  shimmer, checkpoints MUST show unvisited, visited-in-order and next states, and obstacles a translucent volume with a
  rim, all in the palette cobalt, violet and copper, computed in shaders.
- **FR-R02G0203-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict (renderer purity).
- **FR-R02G0203-004**: The experience MUST offer three quality tiers that change only sample density, thread detail,
  trail length and glow, never coordinates, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0203-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for dial changes, undo, redo and next level, digest, snapshot and restore), opening certified levels of
  R02-G02-02.
- **FR-R02G0203-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0203-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0203-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog, content and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0203-009**: Existing tests MUST pass unchanged except where a test names the next unregistered candidate;
  every new public name is documented; the reference regression passes; the Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the dials, level geometry (amplitudes, frequency c, checkpoints, obstacles), stage, verdict, visit
  ticks and the frame time.
- **Thread**: the drawn path of one lap at a tier's sample density, with its width and glow.
- **Quality tier**: 0, 1 or 2, with its sample stride, thread detail, trail length and glow passes.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities, content facts, scenario manifest
  and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0203-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: path,
  checkpoint and obstacle pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0203-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0203-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme setting.
- **SC-R02G0203-004**: The candidate passes the experience package, registry, catalog and content checks and opens in the
  app's unit tests; it is not listed as available.
- **SC-R02G0203-005**: Existing tests pass; the reference regression passes 7 of 7; each test finishes in under 10
  seconds; the Cores still run with `swift test` on the host.
- **SC-R02G0203-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Dials, gestures and the trace scrubber are R02-G02-04; hints and progression R02-G02-05; accessibility and polish
  R02-G02-06; persistence R02-G02-07. This feature gives the experience a minimal control panel (steppers for the four
  dials, undo, redo, next level, each labelled) so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- Like Aurora Loom, the candidate's scenario manifest has the standard scenarios, `full-playthrough`, `hero`, fixtures
  and the 80 acceptance scenarios of the archived matrix (R2-G02-QA-001 … 080), and its registration carries the content
  facts (100 levels and the pinned catalog digest), because the content audit applies to registered candidates.

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (adaptive curve tessellation with tangent-space width) | FR-R02G0203-001 |
| Signature shader (luminous harmonic curves, interference, emissive) and palette | FR-R02G0203-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0203-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0203-004 |
| INV-10 renderer purity, INV-08 stability | FR-R02G0203-003; SC-R02G0203-002, 003 |
| Real render captures | FR-R02G0203-006 |
| "Register it in the catalog" (override) | FR-R02G0203-008 |
| No Stage One breakage | FR-R02G0203-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G02.
