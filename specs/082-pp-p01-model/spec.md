# Feature Specification: Physics Playground — Phase 01 Physics model, units and deterministic tests

**Feature Branch**: `082-pp-p01-model` (spec directory only; work stays on `main`)

**Created**: 2026-11-15

**Status**: Draft

**Ledger gate**: A11-P01 (legacy ledger) · ID namespace FR-A11-1##, SC-A11-1##, T-A11-1##

**Input**: User description: archived manual `apps/11-physics-playground.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — 2D circles and boxes with rigid-body collision; regression fixture — a
  two-body elastic collision approximates the expected momentum within solver tolerance; graphics-context ownership
  stays solely in the VisualCore host.
- **Gaps built here** (contract `docs/apps/physics-playground/visualcore-contract.json`): G-RIGIDBODY (app-local body
  and world model with units, static bodies, gravity, drag, integration, pause, single step, time scale and reset),
  G-CONTENTLICENSES (app-local material catalog with license records) and — because the phase gate requires circles and
  boxes that collide — the contact part of G-CONTACTS: generic contact generation for circle–circle, circle–box and
  box–box and a generic impulse solver with restitution and friction in VisualCore's simulation module. The broad phase
  and resting-stack stability (with positional correction tuned for stacks) and springs (G-SPRINGS) stay for A11-P02;
  the contract is updated to say so.
- **Experience:** created in `Packages/ExperiencesCreative/PhysicsPlayground`, registered as a candidate with its
  scenario manifest; the slice draws a real stage where bodies fall, collide and come to rest — no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; the reference
  regression for the VisualCore change runs at X-A11 (owner ruling 2026-11-14); every Spec Kit step runs.

## Clarifications

### Session 2026-11-15

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code: an
`ExperienceCore` declares `stepDuration` (default 1/120 s), `update(step:)`, `apply(_:)`, `reset()`, snapshot payload
and restore with a `MigrationChain`, `qualityTiers` (default 1); an `ExperienceAction` carries `control`, `values` and
the `step`, so the applied actions are the input record; the engine's `suspend()`/`resume()` stop and restart stepping;
`SeededRandom` saves and restores its state; `Vec2` (`VisualCoreMath`) offers `dot`, `cross`, `length`, `normalized`
and `isFinite`; `VisualCoreSimulation` depends only on `VisualCoreMath` and holds `Collision2D` (circles and capsules)
but no box, contact or solver code (contract G-CONTACTS); `Primitive` draws rectangles, circles, lines and polygons.

- Q: Which units, stage, tick and limits does the world use? → A: Metres, kilograms (2D: density in kg/m²), seconds
  and radians; y up, origin at the stage's bottom-left; the stage is 10 m wide and 8 m high, enclosed by four static
  walls 1 m thick just outside it (floor, ceiling, left, right). One tick is 1/120 s (the host step). Defaults: gravity
  (0, −9.81) m/s², linear and angular drag 0.05 s⁻¹ applied as the factor 1/(1 + k·dt); speeds capped at 40 m/s and
  40 rad/s (at most 0.33 m per tick, under the wall thickness); at most 48 bodies; radii and box half-sizes 0.15…1.0 m.
- Q: What exactly do the shared contact and solver code offer? → A: In `VisualCoreSimulation`: a shape (circle with
  radius, box with half-extents), a pose (position, angle), a contact manifold (normal pointing from the first body to
  the second, depth ≥ 0, one or two points) from `collide` for circle–circle, circle–box and box–box (separating-axis
  test with reference-face clipping for boxes; touching within 1e-9 counts; separated, non-finite or non-positive sizes
  give none); a rigid-body state (position, angle, velocity, angular velocity, inverse mass, inverse inertia,
  restitution, friction); and a sequential impulse solver that runs a fixed number of velocity iterations (default 10)
  over the contacts with restitution max(eA, eB) applied when the closing speed exceeds 0.5 m/s, Coulomb friction
  √(fA·fB), and then a positional correction of 80 % of the depth beyond a 0.005 m slop shared by inverse mass. Inverse
  mass 0 is static; the solver never divides by zero. All of it is pure, deterministic and documented.
- Q: Which materials ship, and how is the catalog checked? → A: Four materials as Swift data with a JSON encoding and
  a validating decoder: rubber (density 1.2, restitution 0.8, friction 0.9), wood (0.6, 0.4, 0.5), steel (7.8, 0.25,
  0.4) and ice (0.9, 0.1, 0.05), each with fill and edge colours, author "VisualCore project" and license "MIT" (the
  only allowed license). Ranges: density 0.1…10, restitution and friction 0…1. Refusal reasons `missing-license`,
  `unsupported-license`, `out-of-range`, `invalid-number`, `duplicate-id`, with the valid rest kept. A license document
  `docs/apps/physics-playground/content-licenses.md` is generated and checked against the catalog by a test.
- Q: What is the starting scene, and which actions exist? → A: From the seed: three circles and three boxes in the upper
  half at non-overlapping positions with sizes 0.25…0.6 m and seeded materials and angles, at rest, plus one static
  steel ledge (mass 0) at a fixed place on the left. Actions: `world.pause [0…1]`; `world.step` (one tick, only while
  paused, else refused with `a11.not-paused`); `world.timeScale [0…3]` choosing ¼, ½, 1 or 2 (each host step adds the
  scale in quarter ticks to a remainder and runs its whole ticks, so the world after N ticks is the same at every
  scale); `world.reset` (the starting scene of the seed, time scale 1, running); `world.drop [0…1]` (0 circle, 1 box)
  placing a seeded body at y = 7 m, x 1…9 m, refused with `a11.body-cap` at 48 bodies. A refusal changes nothing;
  fractional choices are refused with `a11.invalid-choice`. The replay is the seed plus the applied actions with steps.
- Q: What is saved, drawn and spoken? → A: Snapshot schema 1: the world as JSON with sorted keys (settings, bodies,
  tick, next id, paused, time-scale index and remainder, generator state); a damaged or newer payload is refused and a
  new world opens; one quality level (`level-0`). The stage is drawn letterboxed with its walls; every body is drawn at
  its physics size in its material colours (circles with a radius line showing rotation, boxes as rotated polygons,
  static bodies with a darker hatch). The spoken description names the body count, running or paused and the time
  scale; diagnostics (kinetic and potential energy, momentum) are pure functions of the world for tests and later
  overlays. There is no decorative motion, so Reduce Motion changes nothing.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drop objects into a stage (Priority: P1) 🎯

A person opens Physics Playground and sees a stage with a floor and walls and a few circles and boxes; gravity pulls
them down, they bounce, knock into each other and settle. The person can drop another circle or box, pause the world,
step it one tick at a time, slow it down or speed it up, and reset it.

**Why this priority**: the manual's journey 1 and version 0.1 features 01, 02 (gravity and drag) and 04.

**Independent Test**: opening the experience shows a non-blank stage with bodies that move under gravity within the
first second; dropping adds a body; pause stops all motion; single step advances exactly one tick; reset restores the
starting scene.

**Acceptance Scenarios**:

1. **Given** a new world, **When** the experience opens, **Then** the stage shows its floor, walls and the starting
   bodies, and the dynamic bodies begin to fall.
2. **Given** a falling circle above the floor, **When** it reaches the floor, **Then** it bounces according to its
   restitution and never passes through the floor or a wall.
3. **Given** two bodies that meet, **When** they touch, **Then** they push each other apart and neither passes
   through the other.
4. **Given** the world is paused, **When** time passes, **Then** nothing moves; **When** single step is used, **Then**
   the world advances exactly one tick.
5. **Given** a time scale of one half, two or one quarter, **When** the world runs, **Then** it advances by that
   fraction of ticks per host step, and the result after the same number of ticks is identical to normal speed.
6. **Given** reset, **When** it is used, **Then** the world returns to the starting scene.

---

### User Story 2 - Physics a person can trust to be consistent (Priority: P1)

The physics follows stated units and simple, checkable laws: a free fall matches the textbook result within a stated
tolerance, a head-on elastic collision of two bodies keeps the total momentum, a body of zero mass is static and never
moves, and the same starting scene with the same inputs always gives exactly the same result.

**Why this priority**: the manual's Phase 01 regression fixture, §11 fixtures 3 and 5 and algorithm decisions 1, 2
and 4 (fixed-step CPU solver, impulse collisions, educational approximations).

**Independent Test**: fixed scenes are run and compared with analytic values; a recorded run is replayed and its digest
compared.

**Acceptance Scenarios**:

1. **Given** a body dropped from rest with no drag, **When** it falls for one second, **Then** its speed and distance
   match g·t and g·t²/2 within the stated tolerance.
2. **Given** two equal circles meeting head-on with restitution 1, **When** they collide, **Then** the total momentum
   after the contact equals the total before within the solver tolerance, and the velocities are exchanged within the
   tolerance.
3. **Given** a body with mass 0, **When** the world runs and other bodies hit it, **Then** it never moves, and no
   division by zero or non-finite value appears.
4. **Given** a starting scene and a recorded list of inputs with their ticks, **When** it is replayed twice and at host
   frame times of 1/30, 1/60 and 1/120 s, **Then** the world after the same number of ticks is identical.
5. **Given** drawing on or off, or drawing at another quality level, **When** the world runs, **Then** the world is
   unchanged.

---

### User Story 3 - The world is saved and paused safely (Priority: P2)

A world survives leaving and returning: the bodies, their motion, the time scale and the pause state come back as they
were; the world never fast-forwards while the experience was away; damaged saved data never breaks the experience.

**Acceptance Scenarios**:

1. **Given** a running world, **When** it is saved and restored, **Then** it is identical.
2. **Given** the experience is suspended for any wall-clock time, **When** it resumes, **Then** the world continues
   from the same tick (no catch-up).
3. **Given** a damaged or newer saved state, **When** it is restored, **Then** it is refused and a new world opens.

---

### User Story 4 - Honest, licensed content (Priority: P2)

Every material (name, colours, density, restitution, friction) shipped with the experience records its author and
license, and loading refuses an item without them; the experience states that its results are educational
approximations.

**Acceptance Scenarios**:

1. **Given** the bundled material catalog, **When** it is audited, **Then** every item has an author and an allowed
   license, and a generated license document lists every item.
2. **Given** a malformed catalog (missing or unsupported license, a value out of range, a non-finite number), **When**
   it is loaded, **Then** the bad item is refused with a named reason.

### Edge Cases

- **Too many bodies:** the world has a body cap; dropping beyond it is refused, not queued.
- **A body dropped overlapping another:** the contact pushes them apart over the next ticks without non-finite values.
- **Very fast bodies:** speeds are capped; the floor and walls are thick enough that a capped body cannot cross them
  in one tick.
- **Resting stacks:** may jitter slightly in this phase; bounded resting stacks are A11-P02's fixture.
- **Non-finite numbers in input or saved state:** refused; the world is unchanged.
- **Time scale while paused:** stored; single step still advances exactly one tick.
- **Very small screens or iPad landscape:** the stage keeps its world units; drawing scales and letterboxes.
- **Reduce Motion:** the physics is the content and does not change; decorative motion (if any) is calmed.

## Requirements *(mandatory)*

### Functional Requirements

**Generic contacts (G-CONTACTS, contact part, VisualCore)**

- **FR-A11-101**: The shared simulation module MUST offer generic 2D contact generation between circles and oriented
  boxes (circle–circle, circle–box, box–box) returning a contact normal, penetration depth and up to two contact
  points, and nothing for separated shapes or non-finite input.
- **FR-A11-102**: The shared simulation module MUST offer a generic sequential impulse solver for 2D rigid bodies
  (inverse mass, inverse inertia, restitution, friction) that resolves a set of contacts in a fixed number of
  iterations, treats bodies of inverse mass 0 as static, and applies a bounded positional correction.
- **FR-A11-103**: Both MUST be pure and deterministic, documented, part of the published interface record, and proved
  by tests; because the shared module changes, the seven-step reference regression MUST be scheduled for X-A11.

**World model (G-RIGIDBODY, app-local)**

- **FR-A11-110**: A world MUST be a versioned, validated record of settings (gravity, linear and angular drag, fixed
  tick, solver iterations, stage size) and bodies (id, shape circle or box with size, material, mass derived from
  density and area, inertia, position, angle, velocity, angular velocity, static flag), in stated units (metres,
  kilograms, seconds, radians).
- **FR-A11-111**: Each tick MUST apply gravity and drag to dynamic bodies, integrate with a semi-implicit step, cap
  speeds, generate contacts between all pairs and with the stage walls, and resolve them with the generic solver; a
  body of mass 0 MUST be static.
- **FR-A11-112**: The world MUST support pause, single step, time scales (1/4, 1/2, 1, 2), reset to the starting scene
  and dropping a circle or a box; inputs MUST be recordable with their ticks and replayable, and the same scene and
  inputs MUST give the same world independent of frame pacing and drawing.
- **FR-A11-113**: Diagnostics (kinetic and potential energy, total momentum) MUST be computed from the world without
  changing it, and be labelled as educational approximations wherever shown.
- **FR-A11-114**: Materials MUST come from a catalog whose every item records author and license; loading MUST refuse
  a missing or unsupported license, an out-of-range value or a non-finite number, naming the reason; a content license
  document MUST list every item.

**Experience**

- **FR-A11-120**: The experience MUST draw the stage, the walls and every body (circles with a mark showing rotation,
  boxes at their pose; static bodies distinguishable) procedurally through the host's renderer only, at the sizes the
  physics uses; a spoken description MUST name the number of bodies, whether the world runs or is paused and the time
  scale.
- **FR-A11-121**: The person MUST be able to drop a circle or a box, pause and resume, single step, change the time
  scale and reset, with native controls carrying VoiceOver labels and values; the state MUST be saved and restored by
  the host, and suspension MUST NOT advance the world.
- **FR-A11-122**: The experience MUST be registered as a candidate with a scenario manifest holding the nine standard
  scenarios and fixtures for free fall, two-body momentum, static zero mass, replay determinism, frame-pacing
  independence, time scale and single step, save/restore, no catch-up on resume, catalog refusal and the body cap.

### Key Entities

- **World**: schema version, settings, bodies, tick, next body id, paused, time scale, time-scale remainder.
- **Body**: id, shape and size, material id, mass and inertia (or static), position, angle, velocity, angular velocity.
- **Material**: id, name, colours, density, restitution, friction, author, license.
- **Contact**: body pair, normal, depth, points.
- **Input record**: starting scene and a list of (tick, action).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A11-101**: A new world shows the stage and bodies, and dynamic bodies move within the first second; 0 bodies
  leave the stage over 10,000 ticks from 20 seeded scenes.
- **SC-A11-102**: Free fall after 1 s matches g·t and g·t²/2 within 1 %; a head-on elastic collision of two equal
  circles keeps total momentum within 1e-9 relative error and exchanges velocities within 2 %.
- **SC-A11-103**: A body of mass 0 moves by exactly 0 over 1,000 ticks of impacts; no non-finite value appears in 100 %
  of fixtures.
- **SC-A11-104**: Replays are identical in 100 % of repeats and at frame times of 1/30, 1/60 and 1/120 s.
- **SC-A11-105**: The generic contact tests answer 100 % of the fixed cases correctly (separated, touching,
  overlapping, rotated boxes, non-finite).
- **SC-A11-106**: 100 % of bundled materials carry author and license; 100 % of malformed catalog fixtures are refused
  with a named reason.
- **SC-A11-107**: The nine standard scenarios and the fixtures pass on iOS 27; the VisualCore host tests and the
  public-interface check pass; each package test finishes in under 10 seconds.

## Assumptions

- World units are metres, kilograms, seconds and radians on a fixed stage; exact values are set in clarification and
  plan and tuned in A11-P05.
- The fixed step, seeded generator, recorded inputs, batched shape drawing, storage and quality tiers are reused from
  VisualCore (contract rows M01–M04, M12, M14, M15).
- Springs, the broad phase and stable stacks (A11-P02), editing gestures and overlays (A11-P03), presets and saved
  experiments (A11-P04) and stability caps (A11-P05) come later.

## Out of Scope

- Springs, pins, grabbing, deleting, presets, saved experiments, vector overlays and the state panel, a broad phase.

## Traceability

| Source | Requirement |
|---|---|
| v0.1 feature 01 (circles and boxes with rigid-body collision) | FR-A11-101, 102, 110, 111, 120; story 1 |
| v0.1 feature 02 (constant gravity and drag; springs later) | FR-A11-110, 111; story 1 |
| v0.1 feature 04 (pause, single step, time scale, reset) | FR-A11-112, 121; story 1 |
| Phase 01 regression fixture (two-body elastic momentum) | FR-A11-102, 111; story 2 |
| Manual §11 fixtures 3 (mass zero static) and 5 (deterministic replay) | FR-A11-111, 112; story 2 |
| Manual algorithm decisions 1, 2, 4 | FR-A11-102, 111, 113 |
| Contract gaps G-RIGIDBODY, G-CONTENTLICENSES, G-CONTACTS (contact part) | FR-A11-101–103, 110–114 |
| Constitution A11 (authoritative GPU-free physics, stable and bounded, truthful claims, licenses) | FR-A11-111–114 |

## Negative Requirements

- No artwork, sprites, textures or recordings; no network; no permission; no simulation in shaders; no second renderer
  or context; no ProjectM code; drawing never changes the world; no claim of engineering accuracy.
