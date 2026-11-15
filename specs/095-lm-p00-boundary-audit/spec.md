# Feature Specification: Light Maze — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `095-lm-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A13-P00 (legacy ledger) · ID namespace FR-A13-0##, SC-A13-0##, T-A13-0##

**Input**: User description: archived manual `apps/13-light-maze.md` §9 Phase 00 `/speckit-specify` prompt (verbatim
in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Light Maze (`a13.light-maze`) is an experience of the VisualCore app, built in
  `Packages/ExperiencesCreative/LightMaze` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with Adapter/,
  ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target, bundle identifier, in-app
  product or store listing. The manual's gate "the app can compile an empty SwiftUI shell" is met by the one app
  itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A12;
  the contract lives in `docs/apps/light-maze/`.
- **Visuals are code:** beams, glow, tiles and backgrounds are procedural geometry and shaders; bundled data (level
  layouts, names) needs a license and provenance record.
- **Constitution:** 2.9.0 adds the A13 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only; device tasks are tagged {device} and wait for ImplementationLock-100.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the A13 constitution commit is `d5d232b6` and the A13-P00 specify commit `57a587f9` (the phase start: the no-change
diff of `Packages` and `External` is taken from it); the reference submodule is pinned at `d93edd1`; twelve
experiences are registered (`Catalog/registrations.json`, A01–A12). VisualCore offers `VisualCoreMath.Vec2` (dot,
scalar cross, length, normalized, distance; no reflect, perpendicular or rotate), `Mat3` (rotation, translation, scale,
`trs`) and `Camera2D`; `VisualCoreMath.Ray3`/`RayHit3` (3D only); `VisualCoreSimulation.AABB2D`, `BroadPhase2D`,
`Shape2D` (circle and box, no segment or polygon), `Pose2D` and `Contacts2D`; `VisualCoreScenes.Primitive` (rect,
circle, line with width, polygon, polyline) and `SceneNode` with transforms and hit testing; `VisualCoreRendering`
`PrimitiveRenderer` (draws a scene-node tree through a `Camera2D`), `RenderTarget`, `ResourceRegistry`,
`PingPongTarget` and `TrailLayer`; `VisualCoreEffects.EffectRenderer` running an `EffectGraphDescription` whose pass
schemas include blur, bloom, composite and flashLimit (`VisualCoreEffectsGraph`); `VisualCoreShaderSource.RenderState`
with additive blending; gesture recognizers (drag, rotate, tap, double-tap, pinch) and `GestureArbiter`
(`VisualCoreScenes`); `AnnouncementSink`, `HapticSink` (`VisualCoreUI`), `AnnouncementPlanner`, `HapticPlanner` and
`EffectiveAccessibility` with Reduce Motion and Reduce Flashing (`VisualCoreSimulation`); `ExperienceStorage`,
`DocumentStore`, `MigrationChain`; `SoundEffectSynth` and `SoundEffectPlayer`. No 2D ray against segments, no
reflection about a normal, no tile board, no undo history, no progression model and no graph search exist in any
framework product; Neon Arcade's glow layer, Oscilloscope Studio's beam polylines and Physics Playground's 2D editing
live only inside those experiences.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A12: the one app is the shell;
  this phase proves it builds for testing with Light Maze absent; the targets come with A13-P01's first rules.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Light Maze? → A: `Packages/ExperiencesCreative/LightMaze` (Auto-Creator.md §16), as A05–A12
  did; no new package is created.
- Q: Does Light Maze need a permission or a new privacy answer? → A: No. Version 0.1 needs no microphone, camera,
  photos, motion or location; progress lives in the experience's own storage, so the app's privacy answers do not
  change.
- Q: Which pieces exist, and who owns the missing ones? → A: Vectors, 2D transforms and camera, primitives with hit
  testing, the primitive renderer, render targets, the effect graph with blur, bloom and composite, additive blending,
  gestures, accessibility sinks and planners, storage and sound effects exist. Gaps and owners, following the manual's
  phases (P01 grid/ray reflection solver and fixtures, P02 rendering and tap interactions, P03 core levels and progress,
  P04 hints, accessibility and visual polish, P05 content solvability and release QA): a 2D ray cast against segments
  and reflection about a normal → `VisualCoreMath` (A13-P01); the tile board, optical rules, bounce cap and cycle
  detection → app-local (A13-P01); beam rendering from the tracer's exact segments with capped glow, and snapped drag
  and rotate → app-local over the primitive renderer, the effect graph and the gesture recognizers (A13-P02); the 20
  levels, level select, unlock progression, undo, restart and saved progress → app-local over `ExperienceStorage`
  (A13-P03); hints, spoken board descriptions, legible colour cues and success feedback → app-local over the
  accessibility planners and sound effects (A13-P04); the solvability checker and its shipping-level proof →
  app-local (A13-P05). The audit confirms or corrects each from the code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Light Maze gets a map of what VisualCore already provides for each capability the
experience needs — render targets, shaders, geometry and transformations, touch controls, and compositing and visual
feedback — and for each version 0.1 feature, with real files, declared names and package products, each marked
available, requires adaptation or upstream gap.

**Why this priority**: the manual's first review gate; every later phase depends on it.

**Independent Test**: run the contract checker; every cited file exists, every cited name is declared, every product
exists, and every non-available row has a gap entry.

**Acceptance Scenarios**:

1. **Given** the contract, **When** the checker runs, **Then** it passes with 0 problems.
2. **Given** a cited name that does not exist, **When** the checker runs, **Then** it fails naming it.
3. **Given** the five brainstorm capabilities and the six version 0.1 features, **When** the traceability is read,
   **Then** each maps to at least one matrix row.

---

### User Story 2 - The reference stays proven (Priority: P1)

The owner sees that the ProjectM reference regression passes before any Light Maze work, and the starting commit is
recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Light Maze absent, so Phase 01
starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Light Maze is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Light Maze can proceed, what is missing upstream, and which module will own
each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable 2D drawing path were missing, **Then** the decision
   is "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example 3D ray intersection but no 2D ray against segments, or a blur pass
  but no beam glow): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example Neon Arcade's glow layer, Oscilloscope Studio's
  beam polylines or Physics Playground's 2D editing) but not in a framework product: not counted as available; reuse
  needs it moved into VisualCore first.
- **Visual beams diverging from logical paths** (the manual's main risk): the audit records that beam geometry must
  come from the CPU tracer only; the rule is assigned to a phase, nothing is built here.
- **Self-intersection, mirror loops and unbounded bounces:** recorded as rules (epsilon and last-hit tracking, a bounce
  cap and cycle detection), not solved here.
- **Glow hiding the beam or colour carrying meaning alone:** the audit records the existing accessibility pieces
  (reduced flashing, colour helpers); the rule's owner is named.
- **Unbounded content** (board size, tiles, segments, levels): the audit records existing budget pieces; the budget's
  owner is named.
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Light Maze work starts.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A13-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A13-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A13-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed: the puzzle board with emitter, wall, mirror, target and
  prism tiles; snapped drag and rotate; 2D ray propagation against segments with reflection, a bounce cap and cycle
  detection; level select, unlock progression, undo and restart; beam glow and colour cues that keep the path legible;
  the solvability check; success feedback; and saved progress.
- **FR-A13-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record the
  phase-start commit, the reference pin and the results.
- **FR-A13-005**: The one app MUST build for testing with Light Maze absent; the experience package check MUST pass;
  Light Maze MUST stay unregistered and unavailable (its targets come with A13-P01's first rules).
- **FR-A13-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no photorealistic optics with refraction physics, no unvalidated user-generated level sharing, no
  endless procedural level generation, no purchased, generated or hand-made sprites, textures or artwork, no claims of
  physical optics accuracy or learning outcomes, and no shader deciding whether a puzzle is solved), the license rule
  (every level, palette and shader bundled later records its author and license; only original content) and a stop/go
  decision with reasons.
- **FR-A13-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A13-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A13-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A13-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A13-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A13-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (12 registered experiences, none of them A13).
- **SC-A13-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A13-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides 2D pieces used by earlier experiences — vectors and 2D transforms, a 2D camera, a scene graph of
  primitives with hit testing, a primitive renderer, render targets, an effect graph with blur, bloom and composite
  passes, gesture recognizers with arbitration, accessibility sinks and planners, experience storage, sound effects and
  quality tiers; the audit confirms each from the code and records what is missing (for example a 2D ray against
  segments, reflection, a tile board, undo history, progression or a solver).
- Levels, tiles, copy and the interface are app-local; generic pieces (for example a 2D ray cast against segments with
  reflection, or an undo history) are assessed for VisualCore ownership.
- Later phases (A13-P01 to A13-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A13-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A13-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A13-005, US3 |
| Review gate: written stop/go decision | FR-A13-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A13-008 |
| Brainstorm capabilities (render targets, shaders, geometry and transformations, touch controls, compositing and visual feedback) | FR-A13-002 |
| Manual non-goals and algorithm decisions 1–4 | FR-A13-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
