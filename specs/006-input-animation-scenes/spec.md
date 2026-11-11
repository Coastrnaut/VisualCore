# Feature Specification: Phase 5 — Input, Animation, Scenes and Procedural Graphics

**Feature Branch**: `006-input-animation-scenes` (spec directory only; work stays on `main`)

**Created**: 2026-11-10

**Status**: Draft

**Ledger gate**: F05 · ID namespace FR-F5##, SC-F5##, T-F5##

**Input**: User description: archived `sources/README.md` §10.7 Phase 5 prompt (verbatim in the
invocation), plus the canonical override: pure logic in host-testable `VisualCore` modules
(`VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreScenes`), GL drawing in `VisualCoreRendering`;
device measurements deferred to campaign II (constitution V).

## Clarifications

### Session 2026-11-10

Answered autonomously under the owner's standing approval (CLAUDE.md §2), recommended option chosen.

- Q: What form does the standalone interactive demo take? → A: A minimal harness app `Harnesses/InteractiveDemo` with its own XcodeGen spec, built unsigned for the simulator, driven by XCUITest; no ProjectM link (the Showcase is feature 007).
- Q: Which seeded random algorithm is used? → A: xoshiro256** seeded through SplitMix64 (integer-only, so sequences are identical on every platform); doubles from the top 53 bits, floats from the top 24 bits; a golden-sequence test pins the first outputs for seed 42.
- Q: What are the gesture thresholds? → A: Tap: ≤ 10 pt movement and ≤ 0.3 s; double-tap: second tap within 0.3 s and 30 pt; long-press: ≥ 0.5 s with ≤ 10 pt movement; drag begins after 10 pt movement. All are configurable per recognizer.
- Q: How do one- and two-finger gestures interact? → A: Pinch and rotate run simultaneously; an active drag is cancelled when a second finger lands, and a pending tap fails once a second finger lands or movement exceeds the tap slop.
- Q: How do animations respect Reduce Motion? → A: Timelines take a `reduceMotion` flag that makes tweens jump to their end values and disables repeats; the demo sets it from the system Reduce Motion setting and then also disables camera inertia. Particles are content, not UI motion, and stay unchanged.

## User Scenarios & Testing *(mandatory)*

Users: developers of the 25 interactive apps (Physics Playground, Particle Universe, Generative Art
Studio, Neon Arcade, Light Maze, Tiny Worlds, Solar System Explorer, Molecular Explorer, …) and the
Showcase, who need touch-driven, animated, procedurally generated graphics without re-implementing
the basics in every app.

### User Story 1 - Map touches into the scene (Priority: P1) 🎯

A developer receives touches and gestures (tap, drag, pinch, rotate, long-press) in view points and
gets them in normalized device coordinates, pixel coordinates and scene (world) coordinates,
regardless of display scale, aspect ratio or a panned/zoomed camera.

**Independent Test**: Host tests convert known points through every coordinate space and back.

**Acceptance Scenarios**:

1. **Given** a 390×844-point view at scale 3, **When** a touch lands at (195, 422), **Then** it maps to NDC (0, 0) and pixel (585, 1266).
2. **Given** a 2D camera zoomed 2× and panned by (10, 0) world units, **When** a touch at the view center is converted, **Then** it maps to world (10, 0); converting back yields the original point within 0.001 points.
3. **Given** two fingers moving apart from 100 to 200 points, **When** the pinch is recognized, **Then** the reported scale is 2.0.
4. **Given** a touch that is cancelled by the system, **When** the gesture ends, **Then** the gesture state becomes cancelled and no tap is reported.

---

### User Story 2 - Deterministic animation and update timing (Priority: P1)

A developer advances simulations at a fixed step independent of the display rate, with seeded
randomness, so the same inputs and seed always produce the same state, and animates values with
easing curves and timelines.

**Independent Test**: Host tests feed frame-time sequences (60 Hz, 120 Hz, stalls) and compare
resulting states and step counts.

**Acceptance Scenarios**:

1. **Given** a 1/120 s fixed step, **When** frames of 1/60 s arrive for 1 s, **Then** exactly 120 steps run and the interpolation factor stays in [0, 1).
2. **Given** a 2 s stall, **When** the next frame arrives, **Then** at most the configured maximum steps per frame run (default 8) and the excess time is dropped and counted.
3. **Given** the same seed and input sequence, **When** a simulation runs twice, **Then** the states are bit-identical.
4. **Given** a timeline with an ease-in-out tween 0→1 over 1 s, **When** sampled at 0, 0.5 and 1 s, **Then** it returns 0, 0.5 and 1, and it is paused, resumed and reversed correctly.

---

### User Story 3 - Particles and 2D scene primitives (Priority: P2)

A developer emits, updates and draws thousands of particles and simple 2D shapes (rectangles,
circles, lines, polygons) arranged in a transform hierarchy.

**Independent Test**: Host tests for emission counts, lifetime, pool limits and transform
composition; simulator pixel tests drawing primitives and particles.

**Acceptance Scenarios**:

1. **Given** an emitter at 100 particles/s with lifetime 1 s, **When** run for 2 s at a fixed step, **Then** between 99 and 101 particles are alive.
2. **Given** a pool capacity of 10,000, **When** emission would exceed it, **Then** no more are emitted and the dropped count is reported.
3. **Given** a parent node rotated 90° with a child offset (1, 0), **When** world transforms are computed, **Then** the child is at (0, 1).
4. **Given** a red circle of radius 8 at the view center, **When** drawn, **Then** the center pixel is red and a pixel 12 px away is background.

---

### User Story 4 - Minimal 3D camera and meshes (Priority: P3)

Apps with 3D content (Solar System Explorer, Molecular Explorer, Interactive Anatomy, Tiny Worlds,
Graphics Benchmark Lab) get a perspective/orbit camera, quaternion rotations and generated meshes
(sphere, cube, plane), justified by those manuals; no full 3D scene engine.

**Independent Test**: Host tests for projection/unprojection, orbit limits and mesh vertex counts and
normals; one simulator test drawing a lit sphere.

**Acceptance Scenarios**:

1. **Given** an orbit camera at distance 5 looking at the origin, **When** a point at the origin is projected, **Then** it lands at NDC (0, 0); a screen ray through the center hits the origin.
2. **Given** a UV sphere with 16 segments and 8 rings, **When** generated, **Then** it has the documented vertex/index counts and unit-length normals.

---

### User Story 5 - Standalone interactive demo (Priority: P2)

A developer runs a small demo app, without ProjectM, where dragging spawns particles, pinch zooms
the camera and shapes animate on a timeline, proving the subsystems work together.

**Independent Test**: Simulator UI test drives a drag and a pinch and reads the demo's diagnostics
(particle count, camera zoom, state).

**Acceptance Scenarios**:

1. **Given** the demo is running, **When** a UI test drags across the view, **Then** the alive-particle count rises above zero.
2. **Given** the demo, **When** a UI test pinches out, **Then** the camera zoom increases.
3. **Given** the demo is backgrounded and foregrounded, **When** it resumes, **Then** the simulation does not jump (no catch-up burst beyond the step limit).

### Edge Cases

- Zero-size or not-yet-laid-out view: conversions return nil instead of dividing by zero.
- More than 10 simultaneous touches: extra touches are ignored, not crashed on.
- Negative, zero, NaN or infinite frame delta: treated as zero; NaN in particle state is detected and the particle is removed (counted).
- Camera zoom limits (default 0.1–100) and orbit pitch limits (±89°) are enforced.
- Timeline with zero duration jumps straight to its end value.
- Device rotation: conversions use the current view size on the next event.
- Reduce Motion on: tweens jump to their end values, repeats are disabled and the demo turns off camera inertia.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-F501**: Provide coordinate conversion among view points, pixels, normalized device coordinates and 2D world coordinates (through a pan/zoom/rotate camera), round-tripping within 0.001 points.
- **FR-F502**: Provide pointer tracking for up to 10 touches and recognizers for tap, double-tap, long-press, drag, pinch and rotate with states possible → began → changed → ended/cancelled/failed; recognizers are pure and fed by timestamped events. Default thresholds: tap ≤ 10 pt and ≤ 0.3 s; double-tap within 0.3 s and 30 pt; long-press ≥ 0.5 s within 10 pt; drag after 10 pt (configurable). Pinch and rotate run simultaneously; a second finger cancels an active drag and fails a pending tap.
- **FR-F503**: Provide a fixed-step clock (default 1/120 s, max 8 steps/frame) reporting steps, interpolation alpha and dropped time; invalid deltas are treated as zero.
- **FR-F504**: Provide a seeded, platform-independent random generator (xoshiro256** seeded via SplitMix64) whose integer sequence is identical on host and iOS for the same seed, pinned by a golden-sequence test.
- **FR-F505**: Provide easing functions (linear, quad, cubic, sine, expo, back, elastic, bounce; in/out/in-out) with f(0)=0, f(1)=1, and timelines/tweens supporting play, pause, seek, reverse, repeat and completion events, plus a `reduceMotion` flag that jumps tweens to their end values and disables repeats.
- **FR-F506**: Provide a 2D scene model: nodes with transform (position, rotation, scale), z-order, visibility, children; primitives rectangle, circle, line, polygon with fill color; world-transform computation and hit testing.
- **FR-F507**: Provide a particle system with a fixed-capacity pool (default 10,000, max 100,000), emitters (rate, burst, lifetime, velocity/spread, color/size over life), forces (gravity, drag, point attractor) and NaN removal, updated on the fixed step.
- **FR-F508**: Provide GL drawing of 2D primitives and particles (instanced or batched) through the registry/program cache, with resources released on teardown and rebuilt on context recreation.
- **FR-F509**: Provide minimal 3D support justified by the 3D app manuals: vectors/matrices/quaternions, perspective and orbit cameras with project/unproject, and mesh generators (plane, cube, UV sphere) with normals; no general 3D scene graph.
- **FR-F510**: Provide a standalone interactive demo harness app `Harnesses/InteractiveDemo` (own XcodeGen spec, unsigned simulator build, no ProjectM symbols) combining input, particles, primitives and a timeline, with a diagnostics readout usable from UI tests; it honors the system Reduce Motion setting.
- **FR-F511**: Simulation state MUST be deterministic for a given seed, step and input sequence on the same platform (bit-identical), independent of display frame rate.

### Key Entities

- **CoordinateSpace / ViewMetrics**: view size in points, scale, camera transform.
- **PointerEvent / Gesture**: id, phase, location, timestamp; recognizer state and values (translation, scale, angle).
- **FixedStepClock**: step, max steps, accumulator, alpha, dropped time.
- **SeededRandom**: state, seed.
- **Easing / Tween / Timeline**: curve, from, to, duration, direction, repeat, events.
- **SceneNode / Primitive**: transform, children, z, visible, shape, color.
- **ParticlePool / Emitter / Force**: capacity, alive count, dropped count; emission and life parameters.
- **Camera2D / OrbitCamera / Mesh**: pan/zoom/rotation; target, distance, yaw/pitch, field of view; vertices, normals, indices.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-F501**: 100% of coordinate round-trip tests (all spaces, 3 scales, 4 aspect ratios, camera transforms) agree within 0.001 points.
- **SC-F502**: Running the same seeded simulation for 10,000 steps twice yields identical state checksums; feeding it at 60 Hz and 120 Hz frame rates yields the same state after the same simulated time.
- **SC-F503**: Every gesture state transition (including cancel and fail paths) is covered by at least one test.
- **SC-F504**: The particle system keeps alive count within ±1 of the analytic expectation in emission tests and never exceeds capacity.
- **SC-F505**: The interactive demo runs in the simulator with zero ProjectM symbols and its UI test (drag, pinch, background/foreground) passes on iOS 27.2 and 26.5.

## Assumptions

- Gestures are recognized by pure recognizers fed from UIKit touches by a thin view adapter, so the logic is host-testable; apps may still use SwiftUI gestures directly.
- Bit-identical determinism is required per platform/architecture; cross-architecture float identity is not promised (only the random sequence is integer-based and identical everywhere).
- Particle and primitive draw performance on devices is measured in campaign II (constitution V); simulator tests are functional only.
- The demo is a minimal harness app (`Harnesses/InteractiveDemo`); the full Showcase is feature 007 (F06).
