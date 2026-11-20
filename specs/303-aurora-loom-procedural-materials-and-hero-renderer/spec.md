# Feature Specification: R02-G01-03 — Aurora Loom: procedural materials and hero renderer

**Feature Branch**: `303-aurora-loom-procedural-materials-and-hero-renderer` (spec directory only; work on `main`)

**Created**: 2026-11-20

**Status**: Clarified

**Ledger gate**: R02-G01-03 (migration ledger, game feature of experience R02-G01) · ID namespace FR-R02G0103-###,
SC-R02G0103-###, T-R02G0103-###

**Input**: User description: the archived R02-G01-03 `/speckit-specify` prompt (round2.md line 2352), verbatim in the
invocation: "Render signature geometry and materials entirely in shaders and generated meshes" for Aurora Loom, with the
canonical overrides of ADR-0009 and Auto-Creator.md sections 19 and 21.

Canonical overrides:
- **Feature directory and ids:** `specs/303-aurora-loom-procedural-materials-and-hero-renderer`; FR-R02G0103-###,
  SC-R02G0103-###, T-R02G0103-###.
- **Packaging (ADR-0009):** the source's `Apps/AuroraLoom` becomes the experience target `AuroraLoomExperience` (with its
  tests) in `Packages/ExperiencesRound02/AuroraLoom/Experience` beside the existing `AuroraLoomCore`; the experience
  `r02-g01.aurora-loom` (free) is registered in the catalog as a candidate (not available) and linked into the one app,
  as every original experience was at its first experience phase; it becomes available only at its gate X-R02-G01.
- **Superseded parts of the source prompt:** price and "no IAP" (free under the shared purchase controller); the Round 2
  lock and per-round device campaign (ImplementationLock-100); "content count 80" (the 100 certified levels of
  R02-G01-02 are the content). **Device-only items:** the frame-time and thermal budgets on D1/D2/D3, recorded as
  `{device}` tasks for after ImplementationLock-100. **Owner-only items:** none.
- **Shared features used:** R02-F05 (generated meshes), R02-F07 (emissive and bloom passes), R02-F08 (curve sampling,
  parallel-transport frames and ribbon meshes) and R02-F10 (quality tiers) through the existing VisualCore packages; the
  rule kernel and certified levels of R02-G01-01 and -02.

## Clarifications

### Session 2026-11-20

Answered autonomously under the owner's standing delegation, safest well-supported option each time. Facts checked in
code (read-only audit, 2026-11-20): experience targets follow `Packages/ExperiencesCreative/Aurora` (A21: an
`ExperienceCore` adapter, an `ExperiencePresenter` with `RenderScene`s, SwiftUI controls, a scenario manifest);
R02-F08 provides `CurveSampler`, `CurveFrames.parallelTransport` and `Mesh.ribbon`; R02-F07 provides the emissive and
bloom passes; `Catalog/experiences.json` already lists `r02-g01.aurora-loom` with `available: false`; registrations carry
capabilities, quality tier names, palette, scenario manifest, permissions and summary; the A21 experience is named
"Aurora", so every new type keeps the `AuroraLoom` prefix.

- Q: What exactly does the scene show, and how does it map the rules to space? → A: each ribbon r is a curve along the
  loom: at s sixteenths (s from 0 to 16, sampled continuously) its height is H · sin(2π · θ_r(s, t) / 4,096) with
  θ_r = wave · s · 16 + phase · 256 + ω · t (t in ticks, continuous between ticks), its depth is the ribbon's lane
  (−1, 0, +1 times the lane spacing). Each gate is a ring standing across the loom at its position; a small marker on the
  ring shows the target height H · sin(2π · (Θ_g + Ω · t) / 4,096). When a ribbon's residual at a gate is within the
  tolerance the ring and marker brighten. The camera is a fixed authored perspective looking along the loom from above
  (orbit and pan come in R02-G01-04). Rationale: the picture shows the same quantity the kernel judges (phase), so a
  player can read the harmony; nothing in the picture is consulted by the rules. Impact: FR-R02G0103-001, 003, 006.
- Q: What do the three quality tiers change? → A: `level-2` (the design's "Tier 0, D3-safe minimal layers"): one layer
  per ribbon, 32 segments along s, no glow pass; `level-1`: three layers per ribbon, 64 segments, one half-resolution glow
  pass; `level-0` (the design's "Tier 2, dense spectacle"): five layers, 128 segments, two glow passes. The catalog levels
  are ordered richest first because the shared quality contract requires level 0 to be the best and no budget to rise
  from one level to the next (implementation, 2026-11-20). Every tier draws the same ribbon centre lines, gates and markers at the same coordinates. The tier names in
  the catalog are `level-0`, `level-1`, `level-2`; the shared quality controller chooses the tier and the experience logs
  the tier and the reason with each change. Impact: FR-R02G0103-004; SC-R02G0103-001.
- Q: How are rendered frames checked, and within which bounds? → A: a CPU reference in the pure Core computes, from the
  same snapshot, the projected screen positions of the ribbon centre-line samples and the gate markers and the palette
  colours. Simulator tests render offscreen at 96 × 64 pixels and check that each projected ribbon sample lies within
  2 pixels of a pixel brighter than the background by at least 0.15 in luminance, that each gate marker's pixel is within
  0.12 (per channel, 0 … 1) of its expected colour (dim or lit), and that the background matches the palette's night
  colour within 0.05 away from ribbons. Palette: night #07121A, polar teal #1FD1B4, magenta #E0389C, acid gold #D8E83A.
  Impact: FR-R02G0103-006; SC-R02G0103-001.
- Q: What happens on a shader failure, and what does the renderer read? → A: the presenter draws from an immutable
  `AuroraLoomSceneSnapshot` value (steps, level geometry, stage, failure, frame time) made by the adapter after each
  kernel change; it never holds the kernel. If a ribbon or glow program fails to compile or link, the scene draws the
  minimal (level-2) layer with the shared unlit mesh renderer, keeps the program name and the reason in the presenter's
  record (`fallbackReason`; tier changes go to its `tierLog`, since the app has no logging facility for experiences) and
  keeps running; the kernel and its digest are untouched. Reduce Motion holds the picture at tick 0 (deterministic) and
  stops the shimmer and wave travel;
  Reduce Flashing caps the glow gain to the shared limit. Impact: FR-R02G0103-003, 007; SC-R02G0103-002.
- Q: How is the experience registered and what does the minimal control panel do? → A: the candidate registration adds
  `r02-g01.aurora-loom` to `Catalog/registrations.json` (capabilities, quality tiers `level-0` … `level-2`, the palette
  above, a scenario manifest, no permissions, a summary of at most 300 characters), links the `AuroraLoomExperience`
  product into the one app's registry and `project.yml`, and keeps `available: false` in the catalog until X-R02-G01. The
  adapter prepares the certified level chosen by the seed (seed modulo 100, plus one) and accepts the actions `move`
  (ribbon, control, step), `undo`, `redo` and `next-level`; the minimal panel shows one row per ribbon with two steppers
  (wave, phase) and undo, redo buttons, each with an accessibility label. Impact: FR-R02G0103-005, 008; SC-R02G0103-004.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See the auroral silk (Priority: P1) 🎯

A player opens Aurora Loom and sees three luminous ribbons drawn as layered silk in depth, with wave displacement, bevelled
edges and interference shimmer in polar teal, magenta and acid gold, and the four gates and their target harmony shown
in the same scene.

**Why this priority**: the hero scene is the game's identity and the first thing a player sees.

**Independent Test**: on the simulator the experience opens a certified level and renders a frame whose ribbons, gates and
palette are where a CPU reference of the same snapshot says they are.

**Acceptance Scenarios**:

1. **Given** a certified level, **When** the experience opens it, **Then** a frame is rendered whose ribbon and gate
   pixels match the CPU reference within stated bounds.
2. **Given** a move from the rule kernel, **When** the next frame is drawn, **Then** the drawn ribbons follow the new
   controls, and the win or failure state shown matches the kernel exactly.

### User Story 2 - The picture never decides the game (Priority: P1)

Whatever the quality tier, frame rate, time or rendering failure, the drawn image never changes whether a level is won or
failed; the renderer only reads the kernel's immutable snapshot.

**Independent Test**: changing tier, time and frame count never changes the kernel's digest; a failed shader leaves the
logical state intact and shows a fallback.

### User Story 3 - Three quality tiers (Priority: P2)

On older hardware the scene uses fewer layers and simpler effects but keeps the same objective, coordinates and
indicators; the selected tier and its reason are logged.

**Independent Test**: tiers 0, 1 and 2 render the same ribbons and gates at the same places; only density, layer count
and glow change.

### User Story 4 - A registered candidate (Priority: P2)

The experience is part of the one app's catalog as a candidate: it can be opened by tests and in debug builds, is not
shown to players as available, and passes the experience package and registry checks.

**Independent Test**: the package, registry and catalog checks pass; the app's unit tests open the candidate.

### Edge Cases

- **A shader that fails to compile or link:** the scene shows the documented fallback (the minimal level-2 layer, unlit), the failure is
  logged with its name, and the logical state is unchanged.
- **Zero-size or very small views, rotation and resize:** a zero-size view draws nothing and reports no error; for every
  aspect ratio from 0.4 (tall iPhone) to 2.5 (wide iPad) the camera fits the whole loom (ribbons and gate rings) inside
  the view with a margin of at least 5 % on each side.
- **Extreme controls** (all ribbons at step 0 or 15) and the largest Ω: geometry and uniforms stay finite and bounded.
- **Memory warning:** caches are released and rebuilt on the next frame.
- **Reduce Motion:** the animated shimmer and wave travel are slowed to a still or near-still image; Reduce Flashing keeps
  brightness changes below the shared limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-R02G0103-001**: The experience MUST render the three ribbons as layered meshes built from code (sampled curves with
  rotation-minimizing frames), the four gates and the target harmony, entirely from generated geometry and shader code,
  with no image assets.
- **FR-R02G0103-002**: Ribbon materials MUST show wave displacement, bevel edge shading, interference shimmer and an
  emissive glow in the palette polar teal, magenta and acid gold, all computed in shaders.
- **FR-R02G0103-003**: The renderer MUST read only an immutable snapshot of the kernel state; no rendering result, tier,
  time or failure may change the kernel's state, digest or verdict (renderer purity, INV-10).
- **FR-R02G0103-004**: The experience MUST offer three quality tiers that change only tessellation, layer count, glow and
  antialiasing, never coordinates, objective or indicators; the selected tier and the reason MUST be logged.
- **FR-R02G0103-005**: The experience MUST adapt the kernel to the shared experience contract (preparation from a seed,
  actions for moves, undo and redo, digest, snapshot and restore), opening certified levels of R02-G01-02.
- **FR-R02G0103-006**: A CPU reference of the scene's projection and palette MUST exist so rendered frames can be checked
  on the simulator within stated bounds.
- **FR-R02G0103-007**: Shader failures, resizes, memory warnings, Reduce Motion and Reduce Flashing MUST be handled as the
  edge cases state.
- **FR-R02G0103-008**: The experience MUST be registered in the catalog as a candidate and linked into the one app; the
  experience package, registry, catalog and dependency checks MUST pass; it MUST NOT be shown as available.
- **FR-R02G0103-009**: Existing tests MUST pass unchanged; every new public name is documented; the reference regression
  passes; the host tests of the pure Cores keep running on the host.

### Key Entities

- **Scene snapshot**: the kernel's steps, level geometry (gates, targets, Ω, tolerance), stage, outcome and the frame time.
- **Ribbon layer**: one drawn sheet of a ribbon (count by tier), its offset in depth and its share of the glow.
- **Quality tier**: 0, 1 or 2, with its tessellation, layer count and glow settings.
- **Candidate registration**: catalog entry, quality tier names, palette, capabilities and app link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-R02G0103-001**: On the simulator, frames of 5 certified levels at each tier match the CPU reference: ribbon and gate
  pixel positions within the stated tolerance and palette colours within the stated distance.
- **SC-R02G0103-002**: Across 200 seeded snapshots, tier changes, time steps and forced shader failures never change the
  kernel digest or verdict.
- **SC-R02G0103-003**: All generated vertex positions, normals and uniforms are finite and within stated bounds for every
  extreme control setting and every Ω.
- **SC-R02G0103-004**: The candidate passes the experience package, registry, catalog and dependency checks and opens in
  the app's unit tests; it is not listed as available.
- **SC-R02G0103-005**: Existing tests pass unchanged; the reference regression passes 7 of 7; each test finishes in under
  10 seconds (simulator UI-free tests); host tests of the Cores still run with `swift test`.
- **SC-R02G0103-006** {device}: after ImplementationLock-100, the frame time at each tier on D1/D2/D3 is measured and
  recorded (no device run before then).

## Assumptions

- Gestures, camera orbit, dials and anchors are R02-G01-04; hints and progression R02-G01-05; VoiceOver, large text and
  polish R02-G01-06; persistence R02-G01-07; golden images R02-G01-08; full app integration R02-G01-09. This feature gives
  the experience a minimal control panel that issues kernel moves so it can be exercised on the simulator.
- The visual design is the project's own archived design; all geometry and shading are original code.
- The candidate's scenario manifest has the nine standard scenarios, `full-playthrough`, `hero`, three fixtures and the
  source's 80 acceptance scenarios (round2.md §6.1.19, one per row: the planned level, a legal move, a refused move), and
  its registration carries the content facts (100 levels and the pinned catalog digest), because the repository's content
  audit (`verify_experiences.py --audits`) applies to every registered experience, candidates included
  (implementation, 2026-11-20).

## Traceability

| Source deliverable | Requirement |
|---|---|
| Signature geometry (parallel-transport ribbon frames, bevel edges) | FR-R02G0103-001, 002 |
| Signature shader (wave displacement, interference) and palette | FR-R02G0103-002 |
| Frame architecture (snapshot → adapter → scene → GL) | FR-R02G0103-003, 005 |
| Quality tiers 0/1/2 | FR-R02G0103-004 |
| INV-10 renderer purity, INV-08 stability | FR-R02G0103-003; SC-R02G0103-002, 003 |
| Screenshots as real render captures | FR-R02G0103-006 (CPU-checked captures); golden sets in R02-G01-08 |
| "Register it in the catalog" (override) | FR-R02G0103-008 |
| No Stage One breakage | FR-R02G0103-009 |

## Negative Requirements / Excluded scope

- No second renderer, no image assets, no network, no store listing, no advertising, no gestures beyond the minimal
  control panel, no device run before ImplementationLock-100, no availability before X-R02-G01.
