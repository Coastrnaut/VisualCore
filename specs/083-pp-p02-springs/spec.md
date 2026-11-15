# Feature Specification: Physics Playground — Phase 02 Contacts and spring solver

**Feature Branch**: `083-pp-p02-springs` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P02 (legacy ledger) · ID namespace FR-A11-2##, SC-A11-2##, T-A11-2##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — constant gravity, springs and drag forces; regression fixture — a resting
  stack remains bounded over long runs (measured over a short run and bounded by arithmetic, owner ruling on short
  tests); graphics-context ownership stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/physics-playground/visualcore-contract.json`): G-SPRINGS (generic spring
  constraints with stiffness and damping bounded for the tick) and G-BROADPHASE (a broad phase whose pairs equal brute
  force, and resting-stack stability) in VisualCore's simulation module; the experience uses both.
- **Out of this phase:** drawing a spring with a gesture, pinning and grabbing (A11-P03), presets and saved
  experiments (A11-P04), stability caps and sleeping bodies (A11-P05).
- **Owner rulings:** short tests; iOS 27 at phase gates; the reference regression for the VisualCore change runs at
  X-A11; every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`ImpulseSolver2D.solve(_:contacts:settings:)` takes `Contact2D(a:b:manifold:)` without stored impulses (cold start
each tick); `WorldSettings` holds gravity, linear and angular drag, tick 1/120 s, iterations and stage size;
`PhysicsWorld.schemaVersion` is 1 and the adapter's `MigrationChain(currentVersion: 1)`; `WorldSimulation` tests all
pairs behind a bounding-circle pre-filter (A11-P01 research D3); `Primitive.polyline` exists for zigzags.

- Q: How does a spring act, and what bounds keep it stable? → A: In `VisualCoreSimulation`: a spring joins anchor A (a
  body index with a body-local point, or a fixed world point) and anchor B (a body index with a local point), with rest
  length, stiffness k (N/m) and damping ratio ζ. Each tick it applies the impulse J = (−k·(L − L₀) − c·vₙ)·dt along the
  unit direction between the world anchors, at the anchors (linear and angular), where vₙ is the closing speed and
  c = 2ζ·√(k·m) with m = 1/(Σ inverse masses of the ends). k is clamped to 0.1·m/dt² (so ω·dt ≤ 0.32) and c to m/dt;
  a length below 1e-9 m applies nothing; static ends never move. Pure, deterministic, documented.
- Q: How does the broad phase work? → A: Axis-aligned bounds from each shape and pose (`Shape2D` gains its bounds);
  sweep and prune along x with an insertion-sorted order; overlap is inclusive within 1e-9 m; it returns the pairs
  (i, j), i < j, sorted ascending, exactly the pairs brute force reports; the world uses it for body pairs and keeps
  the wall test per body.
- Q: How does the solver keep a stack standing? → A: Warm starting: `Contact2D` gains stored normal and tangent impulses
  per point (empty by default, which is the Phase 01 cold start), and a new `solve(_:contacts: inout ...)` applies them
  first and writes the accumulated impulses back; the existing `solve` keeps its behaviour. The world keeps a contact
  cache keyed by (body id A, body id B, point index) from the previous tick and seeds a contact when the pair and point
  count match. Resting stack fixture: five boxes 0.5 m wide (wood) stacked on the floor for 1,200 ticks.
- Q: Which force and stiffness levels exist, and how are they saved? → A: Gravity off, Moon 1.62, Earth 9.81 m/s²
  (default Earth); drag none 0, low 0.05, high 1.0 s⁻¹ for linear and angular drag (default low); stiffness levels 20,
  60, 150, 400 N/m (default 60), each clamped per spring to its stable bound; damping ratio 0.1 for the world's springs.
  Actions `world.gravity [0…2]`, `world.drag [0…2]`, `world.stiffness [0…3]` (fractional → `a11.invalid-choice`). The
  world becomes schema 2 (springs, next spring id, the three levels; settings' gravity and drag follow the levels); the
  migration 1 → 2 adds no springs, Earth, low drag and stiffness level 1. At most 16 springs.
- Q: What does the starting scene add, and how are springs drawn? → A: A wood box (half-size 0.3 m) hanging on a spring
  from the world anchor (7.5, 8.0) on the ceiling with rest length 1.5 m, and two rubber circles (radius 0.3 m) joined by
  a spring of rest length 1.0 m; the Phase 01 bodies keep non-overlapping places. A spring is drawn as an 8-coil zigzag
  polyline 0.03 m wide between its world anchors with small anchor dots; the spoken description adds the spring count,
  stiffness level, gravity and drag.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Springs that bounce and settle (Priority: P1) 🎯

A person sees springs in the stage — a box hanging from the ceiling on a spring and two balls joined by a spring — that
stretch, bounce and settle under gravity; they can make all springs softer or stiffer, switch gravity between off,
Moon and Earth, and turn air drag down or up, and watch the motion change.

**Why this priority**: the manual's MVP for this phase (version 0.1 feature 02) and journey 2 (alter stiffness).

**Independent Test**: opening the experience shows the springs drawn between their anchors; a hanging body oscillates
and settles near its rest point; changing the stiffness level changes the oscillation; gravity off stops falling;
higher drag settles motion sooner.

**Acceptance Scenarios**:

1. **Given** the starting scene, **When** the world runs, **Then** each spring pulls its ends toward its rest length and
   a hanging body comes to rest where the spring force balances gravity, within a stated tolerance.
2. **Given** a stiffness level change, **When** the world runs, **Then** every spring uses the new stiffness (never
   above the stable bound for the tick) and a stiffer spring oscillates faster.
3. **Given** gravity off, Moon or Earth, **When** the world runs, **Then** bodies accelerate at 0, 1.62 or 9.81 m/s²
   downward.
4. **Given** drag none, low or high, **When** the world runs, **Then** speeds decay at the stated rate.

---

### User Story 2 - Stacks that stand (Priority: P1)

A stack of boxes rests on the floor without creeping, sinking or toppling, and many bodies can share the stage while
only nearby pairs are tested.

**Why this priority**: the phase's regression fixture (manual §11 fixture 2) and algorithm decision 1 (broad phase).

**Independent Test**: a stack of five boxes is simulated for ten seconds and its drift and sinking are measured; the
broad phase's pairs are compared with brute force on random scenes.

**Acceptance Scenarios**:

1. **Given** five equal boxes stacked on the floor, **When** the world runs for 10 s, **Then** the top box drifts less
   than 2 cm sideways, no box sinks more than 1 cm below its resting height, and the stack stays standing.
2. **Given** random scenes, **When** the broad phase runs, **Then** it reports exactly the pairs whose bounds overlap,
   the same as testing every pair.

---

### User Story 3 - Springs with known, bounded energy (Priority: P2)

A spring without damping keeps its energy within a stated band, and a damped spring loses energy steadily, so the
toy behaves predictably and never explodes.

**Why this priority**: manual §11 fixture 4 and algorithm decision 3 (bounded stiffness for the chosen tick).

**Acceptance Scenarios**:

1. **Given** an undamped body on a spring without gravity, **When** it oscillates for 10 s, **Then** its total energy
   stays within 2 % of the starting energy.
2. **Given** a damped spring, **When** it oscillates, **Then** its energy never rises by more than 0.1 % from one second
   to the next and falls below 10 % of the start within 10 s at the high damping level.
3. **Given** a stiffness above the stable bound for the tick, **When** it is used, **Then** it is clamped to the bound
   and the motion stays finite.

---

### User Story 4 - Saved worlds keep their springs and forces (Priority: P2)

A saved world restores its springs, stiffness, gravity and drag; a world saved by Phase 01 opens with its bodies, no
springs and the default forces.

**Acceptance Scenarios**:

1. **Given** a world with springs, **When** it is saved and restored, **Then** it is identical.
2. **Given** a Phase 01 saved world, **When** it is restored, **Then** it migrates with no springs and default forces.

### Edge Cases

- **A spring whose body is removed or invalid:** refused by validation; a world never holds a spring to a missing body.
- **A spring of zero length at rest or with both ends at one point:** no direction; no force is applied that tick.
- **Stiffness or damping above the stable bound for the bodies' mass and the tick:** clamped, never applied raw.
- **Springs to the ceiling (world anchors):** a fixed point, not a body; the anchor never moves.
- **Many bodies:** the broad phase keeps per-tick work proportional to nearby pairs; results equal brute force.
- **Gravity off:** bodies keep their velocity apart from drag; springs still act.
- **Non-finite numbers in input or saved state:** refused; the world is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

**Generic springs and broad phase (VisualCore)**

- **FR-A11-201**: The shared simulation module MUST offer spring constraints between two bodies or a body and a fixed
  world point (anchors in body-local coordinates), with rest length, stiffness and damping, applied as impulses each
  tick, with stiffness and damping clamped to bounds that keep the step stable for the bodies' effective mass and the
  tick.
- **FR-A11-202**: The shared simulation module MUST offer a broad phase over axis-aligned bounds that returns exactly the
  overlapping pairs in a fixed order, equal to brute force.
- **FR-A11-203**: The shared solver MUST keep a resting stack bounded (warm starting from the previous tick's impulses or
  an equivalent), additively to its Phase 01 interface.
- **FR-A11-204**: All of it MUST be pure, deterministic, documented and in the published interface record, proved by
  tests; the reference regression is scheduled for X-A11.

**World (app-local)**

- **FR-A11-210**: The world MUST hold springs (between two bodies, or a body and a fixed point) and force settings
  (gravity off, Moon, Earth; drag none, low, high; a stiffness level of four), saved as snapshot schema 2 with a
  migration from schema 1.
- **FR-A11-211**: Each tick MUST apply gravity and drag, then springs, then contacts from the broad phase through the
  solver with warm starting, then integrate.
- **FR-A11-212**: The starting scene MUST include a box hanging from the ceiling on a spring and two circles joined by a
  spring, as well as the Phase 01 bodies.

**Experience**

- **FR-A11-220**: The experience MUST draw every spring as a zigzag between its anchors at its current length, at the
  physics positions, through the host's renderer only; the spoken description MUST add the number of springs, the
  stiffness level, gravity and drag.
- **FR-A11-221**: The person MUST be able to choose the stiffness level, gravity and drag with native controls carrying
  VoiceOver labels and values.
- **FR-A11-222**: The scenario manifest MUST add fixtures for the resting stack, the spring equilibrium, spring energy
  (undamped and damped), stiffness clamping, broad-phase equality, gravity and drag levels, and the schema-1 migration.

### Key Entities

- **Spring**: id, anchor A (body id and local point, or a world point), anchor B (body id and local point), rest length.
- **Force settings**: gravity level, drag level, stiffness level.
- **World (schema 2)**: Phase 01 world plus springs, next spring id and force settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-201**: A body hanging on a spring comes to rest within 2 % of the analytic equilibrium stretch m·g/k (at a
  stiffness inside the bound) after 10 s with damping.
- **SC-A11-202**: A five-box stack drifts < 2 cm and sinks < 1 cm over 10 s (1,200 ticks); drift over longer runs is
  bounded by the measured per-second drift rate (no long run executed).
- **SC-A11-203**: The broad phase equals brute force on 100 % of 50 random scenes.
- **SC-A11-204**: Undamped spring energy stays within 2 % over 10 s; damped energy never rises more than 0.1 % per second
  and falls below 10 % within 10 s at high damping.
- **SC-A11-205**: Gravity levels give 0, 1.62 and 9.81 m/s² within 1 %; drag levels give the stated decay within 1 %.
- **SC-A11-206**: Schema-1 worlds migrate in 100 % of fixtures; save/restore round trips are identical.
- **SC-A11-207**: The standard scenarios and fixtures pass on iOS 27; the VisualCore host tests and the public-interface
  check pass; each package test finishes in under 10 seconds.

## Assumptions

- Spring stiffness levels and drag values are set in clarification and plan and tuned in A11-P05.
- Phase 01's contacts, solver, world, materials and experience are reused (contract rows M06, M07, M09).
- Gesture editing of springs and presets come later (A11-P03, A11-P04).

## Out of Scope

- Drawing, deleting or pinning springs by gesture; grabbing bodies; presets; saved experiment files; sleeping bodies.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 02 (constant gravity, springs and drag) | FR-A11-201, 210–212, 220, 221; story 1 |
| Phase 02 regression fixture (resting stack bounded) | FR-A11-203, 211; story 2 |
| Manual §11 fixture 4 (spring energy bounded) | FR-A11-201; story 3 |
| Manual algorithm decisions 1 (broad phase) and 3 (bounded stiffness) | FR-A11-201, 202 |
| Journey 2 (alter stiffness) | FR-A11-221; story 1 |
| Contract gaps G-SPRINGS, G-BROADPHASE | FR-A11-201–204 |

## Negative Requirements

- No artwork; no network; no permission; no simulation in shaders; no second renderer or context; drawing never changes
  the world; no claim of engineering accuracy.
