# Feature Specification: Physics Playground — Phase 00 Foundation and VisualCore boundary audit

**Feature Branch**: `081-pp-p00-boundary-audit` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P00 (legacy ledger) · ID namespace FR-A11-0##, SC-A11-0##, T-A11-0##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 00 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **One app (ADR-0009):** Physics Playground (`a11.physics-playground`) is an experience of the VisualCore app, built
  in `Packages/ExperiencesCreative/PhysicsPlayground` (Auto-Creator.md §16 layout: Core, CoreTests, Experience with
  Adapter/, ExperienceTests, Shaders, scenario-manifest.json); it never gets a standalone target. The manual's gate
  "the app can compile an empty SwiftUI shell" is met by the one app itself; nothing is registered yet.
- **Audit only:** this phase modifies neither VisualCore nor ProjectM.
- **Reuse:** the app-neutral contract checker (`scripts/check_app_contract.py`) verifies the contract, as for A01–A10;
  the contract lives in `docs/apps/physics-playground/`.
- **Constitution:** 2.7.0 adds the A11 experience rules (committed at the start of this gate).
- **Evidence:** host and simulator only.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
the A11 constitution commit is `35c24d86` and the A11-P00 specify commit `d3797d7c` (the phase start: the no-change
diff of `Packages` and `External` is taken from it); the reference submodule is pinned at `d93edd1`; ten experiences
are registered (`Catalog/registrations.json`, A01–A10); VisualCore offers `VisualCoreSimulation` (`FixedStepClock`,
`FixedStepRunner` with `FixedStepSimulation`, `TimeStepPolicy` clamping the step to 1/240…1/30 s, `SeededRandom`,
`ParticleSystem`, and `Collision2D` with `CollisionCircle` and `CollisionCapsule` overlap, closest point and swept
tests added at A10-P01), `VisualCoreScenes` (`SceneNode` with `Primitive` rectangles, circles, lines, polygons and
polylines drawn in one batch and hit tested; `TapRecognizer`, `DoubleTapRecognizer`, `LongPressRecognizer`,
`DragRecognizer`, `PinchRecognizer`, `RotateRecognizer`, `GestureArbiter`), `VisualCoreRendering`
(`PrimitiveRenderer`), `VisualCoreExperienceHost` and `VisualCoreExperience` (`ExperienceStorage`, quality tiers).
No rigid-body dynamics exist in any framework product: no box or polygon contact generation, no impulse or constraint
solver, no spring constraint and no broad phase; the only solver is Fluid Art Playground's app-local `FluidSolver`. No
chart or plot component exists.

- Q: How is the manual's "compile an empty shell" gate met in the one app? → A: As for A10: the one app is the shell;
  this phase proves it builds for testing with Physics Playground absent; the targets come with A11-P01's first rules.
- Q: What makes a capability "available"? → A: A public declaration in a VisualCore framework product with at least one
  test that exercises it; an implementation that exists only inside another experience or a harness is "requires
  adaptation" at best.
- Q: Which package holds Physics Playground? → A: `Packages/ExperiencesCreative/PhysicsPlayground` (Auto-Creator.md
  §16), as A05–A10 did; no new package is created.
- Q: Does Physics Playground need a permission or a new privacy answer? → A: No. Version 0.1 needs no microphone,
  camera, photos, motion or location; saved experiments live in the experience's own storage, so the app's privacy
  answers do not change.
- Q: Which pieces exist, and who owns the missing ones? → A: The fixed-step clock and runner, the step policy, batched
  shapes with hit testing, the gesture recognizers, circle and capsule collision, storage and quality tiers exist. Gaps
  and owners, following the manual's phases (P01 physics model, units and deterministic tests, P02 contacts and spring
  solver, P03 gesture editor and overlays, P04 saved experiments and tutorials, P05 numerical stability and performance
  audit): the body and world model with units, static bodies of zero mass, gravity, drag, integration, pause, single
  step, time scale and reset → app-local over `FixedStepRunner` (A11-P01); box contacts (circle–box, box–box), an
  impulse solver with restitution, friction and positional correction, spring constraints with bounded stiffness and a
  broad phase → `VisualCoreSimulation` (A11-P02); spawn, grab, pin and delete gestures, velocity and force arrows and
  the measured state panel → app-local over the recognizers, `Primitive` lines and polygons and native controls
  (A11-P03); presets and saved experiments → app-local over `ExperienceStorage` (A11-P04); stability caps, the body
  budget and sleeping bodies → app-local (A11-P05). The audit confirms or corrects each from the code.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An evidence-backed integration matrix (Priority: P1) 🎯

The engineer who will build Physics Playground gets a map of what VisualCore already provides for each capability the
experience needs — scene rendering, geometry, animation, shader-based effects and data visualization — and for each
version 0.1 feature, with real files, declared names and package products, each marked available, requires adaptation
or upstream gap.

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

The owner sees that the ProjectM reference regression passes before any Physics Playground work, and the starting
commit is recorded, so later phases can prove they changed nothing upstream.

**Independent Test**: the regression's steps run and pass; the baseline document names the commit and the results.

**Acceptance Scenarios**:

1. **Given** the reference regression, **When** it runs in its two chunks, **Then** 7 of 7 steps pass.
2. **Given** the end of this phase, **When** the diff of VisualCore and ProjectM since the phase start is taken,
   **Then** it is empty.

---

### User Story 3 - The shell builds with the experience absent (Priority: P2)

The engineer knows the one app builds for testing and its experience checks pass with Physics Playground absent, so
Phase 01 starts by adding the experience's targets with real rules — and a person using the app sees nothing new.

**Independent Test**: build the app for testing; run the experience package check; read the registry and catalog.

**Acceptance Scenarios**:

1. **Given** the one app, **When** it is built for testing on the iOS 27.2 phone simulator, **Then** the build passes.
2. **Given** the experience package check and the app's registry, **When** they run and are read, **Then** they pass
   and Physics Playground is neither registered nor available.

---

### User Story 4 - A written stop/go decision (Priority: P2)

The owner reads a decision that says whether Physics Playground can proceed, what is missing upstream, and which module
will own each missing piece and in which phase.

**Independent Test**: read the decision and the gap register.

**Acceptance Scenarios**:

1. **Given** the gap register, **When** it is read, **Then** each gap names an owning module and a phase.
2. **Given** the decision, **When** a working host or a buildable drawing path were missing, **Then** the decision is
   "stop" and names the blocker (a missing host is never permission for a second backend).

### Edge Cases

- **A capability exists only partly** (for example circle and capsule overlap without boxes, or lines without arrow
  heads): marked "requires adaptation" with the missing part named.
- **A capability exists only inside another experience** (for example Neon Arcade's game simulation or the fluid
  solver of the fluid art experience) but not in a framework product: not counted as available; reuse needs it moved
  into VisualCore first.
- **Numerical instability from a large step or stiff springs** (the manual's risk 1): the audit records which fixed-step
  and step-policy pieces exist; caps and their proof are assigned to a phase, nothing is built here.
- **Unbounded object counts** (risk 3): the audit records existing budget pieces; the scene budget's owner is named.
- **Users assuming engineering accuracy** (risk 2): recorded as a rule (educational approximation, no engineering or
  safety-critical predictions), not solved here.
- **Simulation offloaded to shaders:** recorded as a negative rule (the CPU solver is authoritative; VisualCore is
  used for drawing only).
- **The build-step count changes during the phase**: the inventory records the count at the time of the check.
- **The reference regression fails before any change**: recorded as a blocker; no Physics Playground work starts.
- **Persisted data, permissions, accessibility interface:** not applicable in this phase (no interface is added).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A11-001**: The contract MUST inventory VisualCore's package products, the render host and its thread rule, the
  shader and resource interfaces, the experience host, the build and release steps, source ownership and the reference
  regression steps, each with real paths.
- **FR-A11-002**: The contract MUST hold a capability matrix covering the five brainstorm capabilities and the six
  version 0.1 features, each row marked available, requires adaptation or upstream gap, with files, declared names and
  products as evidence.
- **FR-A11-003**: Every non-available row MUST have a gap entry naming the owning module (VisualCore or app-local) and
  the phase that will build it; at least these MUST be assessed: circles and boxes with rigid-body collision (including
  static bodies of zero mass), constant gravity, springs and drag, spawn/grab/pin/delete gestures, pause, single step,
  time scale and reset, presets (pendulum, spring chain, stacked objects), velocity and force overlays with a measured
  state panel, saved experiments, and stability and object-count caps.
- **FR-A11-004**: The ProjectM reference regression MUST run in two chunks and pass; a baseline document MUST record
  the phase-start commit, the reference pin and the results.
- **FR-A11-005**: The one app MUST build for testing with Physics Playground absent; the experience package check MUST
  pass; Physics Playground MUST stay unregistered and unavailable (its targets come with A11-P01's first rules).
- **FR-A11-006**: The contract MUST record negative rules (no EGL path of its own, no second renderer, no ProjectM, no
  networking, no simulation in shaders, no 3D soft bodies or fluid solver, no purchased, generated or hand-made
  artwork, no claims of engineering accuracy, safety-critical prediction or learning outcomes), the license rule (every
  preset, palette and shader bundled later records its author and license; only original content) and a stop/go
  decision with reasons.
- **FR-A11-007**: The contract MUST pass the app-neutral contract checker, and its readable view MUST be generated from
  it.
- **FR-A11-008**: This phase MUST NOT change VisualCore or ProjectM (empty diff since the phase start).

### Key Entities

- **Contract**: inventory, matrix rows, gaps, traceability, negative rules, decision (schema 1 of the checker).
- **Regression baseline**: phase-start commit, reference pin, steps and results.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-001**: The contract checker passes with 0 problems; 100% of brainstorm capabilities (5) and version 0.1
  features (6) trace to matrix rows.
- **SC-A11-002**: 100% of non-available rows have a gap with an owning module and a phase.
- **SC-A11-003**: The reference regression passes 7 of 7 steps in two chunks.
- **SC-A11-004**: The app builds for testing on the iOS 27.2 phone simulator and the experience package check passes
  (10 registered experiences, none of them A11).
- **SC-A11-005**: The diff of VisualCore and ProjectM since the phase start is empty; the app's registry and catalog
  availability are unchanged.
- **SC-A11-006**: The contract checker finishes in under 10 seconds; each reference regression chunk and the app build
  finish in under 10 minutes (one foreground command each).

## Assumptions

- VisualCore provides the seeded fixed-step clock and runner, step policies, 2D primitives (rectangles, circles, lines,
  polygons, polylines) drawn in one batch with hit testing, tap, double-tap, long-press and drag gestures, circle and
  capsule collision with swept tests, particles, effects passes, haptic and announcement planners, experience storage
  and quality tiers; the audit confirms each from the code.
- Experiment content (presets, tutorials, copy) and the interface are app-local; generic rigid-body pieces (box
  contacts, an impulse solver, spring constraints, a broad phase) are assessed for VisualCore ownership.
- Later phases (A11-P01 to A11-P06) build the gaps; this phase builds none.

## Traceability

| Source | Requirement |
|---|---|
| Phase 00 deliverable: inventory, products, host, thread, shaders, build steps, ownership, regression | FR-A11-001, 004 |
| Review gate: evidence-backed integration matrix | FR-A11-002, 007, US1 |
| Review gate: compile an empty shell (one-app form: the app itself) | FR-A11-005, US3 |
| Review gate: written stop/go decision | FR-A11-003, 006, US4 |
| "Do not modify VisualCore or ProjectM" | FR-A11-008 |
| Brainstorm capabilities (scene rendering, geometry, animation, shader-based effects, data visualization) | FR-A11-002 |
| Manual non-goals (engineering simulation, 3D soft bodies or fluids, safety-critical predictions) and risks 1–3 | FR-A11-003, 006 |

## Negative Requirements

- No VisualCore or ProjectM change; no experience target, registration or interface in this phase; no artwork; no
  network.
