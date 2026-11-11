# Feature Specification: Particle Universe — Phase 01 Seeded particle domain model

**Feature Branch**: `033-pu-p01-seeded-domain` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A04-P01 · ID namespace FR-A04-1##, SC-A04-1##, T-A04-1##

**Input**: User description: archived manual `apps/04-particle-universe.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):**
  - MVP: multiple emitter families with bounded particle counts (v0.1 feature 01);
  - regression fixture 1: replaying a seed, controls and fixed-step stream reproduces position fixtures on the CPU;
  - EGL and context ownership stays solely in the audited VisualCore host.
- **Gaps closed (contract `docs/apps/particle-universe/visualcore-contract.json`), in VisualCore
  (`VisualCoreSimulation`, constitution Principle II and the A04 reuse rule):**
  - G-SIMSTEP: deterministic fixed-step advancing with capped substeps and bounded catch-up after a pause or
    background, plus replay of a recorded control stream;
  - G-EMITTERS: emitter shapes (point, line, ring) and burst emission, seeded, pool-bounded, with clamped parameters.
- **Out of scope here:** the GPU render loop (Phase 02), force fields beyond VisualCore's existing gravity, drag and
  attractor (G-FIELDS, Phase 02), quality tiers (G-PQUALITY, Phase 02), trails and blending (Phase 03), saving scenes
  (Phase 04).

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing approval (CLAUDE.md §2), choosing the recommended option each time.
Facts checked in code:
- `ParticleSystem` (VisualCoreSimulation) has `Emitter` (position, rate, lifetime, speed, direction, spread, size and
  color ramps), `ParticleForce` (gravity, drag, attractor), a pool with `droppedCount` and `nanRemoved`, `burst(_:from:)`
  and an FNV-1a `checksum()`;
- `FixedStepClock` has `step` (default 1/120 s), `maxSteps` (clamped 1…8), `droppedTime`, `invalidDeltas` and
  `resetAccumulator()`;
- A01's `ParticleReplay` and the `VisualCoreBaselines` checksum use point emitters, so the default shape must draw no
  extra random numbers.

- Q: How are the emitter shapes and bursts added to VisualCore? → A: `Emitter` gains `shape: EmitterShape` (`.point`,
  `.line(halfLength:angle:)`, `.ring(radius:)`, default `.point`) and `burst: EmitterBurst?` (`count`, `interval`
  seconds, default nil). A point draws no extra random number; a line draws one (position along the segment); a ring
  draws one (angle on the circle). A burst emits `count` particles at step times 0, interval, 2·interval, … through
  its own accumulator. Shape positions are offsets from `position`. Clamp ranges: `Emitter.clamped()` maps non-finite values to the default and clamps: rate
  0…20,000 per second; burst count 1…5,000; burst interval 1/60…60 s; lifetime 0.01…60 s; speed 0…10,000; sizes
  0…512; half length and radius 0…10,000; spread 0…2π. Every value A01 and the baselines use lies inside these ranges,
  so their results stay unchanged. The system applies `clamped()` when it reads an emitter.
- Q: What does the fixed-step runner look like? → A: `FixedStepRunner<Simulation: FixedStepSimulation, Command>` in
  VisualCoreSimulation. The protocol has `mutating func step(_ dt: Double)` and `func checksum() -> UInt64`, and
  `ParticleSystem` conforms. The runner:
  - owns a `FixedStepClock` (step 1/120 s, cap 8 per frame);
  - provides `pause()` and `resume()`, where resume discards accumulated time;
  - keeps `stepIndex` and a `ControlStream<Command>`, an ordered list of (step index, command), applying each command
    through a caller closure just before its step;
  - returns from `advance(frame:)` the steps it ran.

  Applying commands at step indices makes replays independent of the frame lengths.
- Q: What are the scene defaults and limits? → A: The world is a square from −500 to 500 world units on both axes, and
  the preview fits it into the view. `ParticleScene` version 1 has:
  - particle limit: default 4,000, range 100…20,000;
  - emitters: at most 8;
  - time scale: 0.25…2, default 1;
  - seed: any `UInt64`;
  - forces: the existing VisualCore gravity, drag and attractor, with finite values.

  The families are:
  - Fountain: point at (0, −400), 600/s, upward cone of 0.6 rad, life 2–4 s, with gravity;
  - Curtain: line at (0, 450), half length 400, 800/s, downward, life 2–3 s;
  - Halo: ring of radius 200 at the origin, 700/s, outward;
  - Firework: point at the origin, bursts of 400 every 1.5 s, full spread, with drag 0.8.
- Q: Where is the replay fixture, and on which platforms must it match? → A:
  `Apps/ParticleUniverse/ParticleUniverseCore/Tests/ParticleUniverseCoreTests/Fixtures/replay-v1.json`. It holds:
  - seed 0x5EED, the Fountain and Firework families, and 600 steps;
  - controls: move the attractor at step 120, burst at step 240, stop Fountain emission at step 360;
  - the expected checksum, live count and the first 8 positions.

  It must match bit for bit on the macOS host and in the iOS simulators. It is written once with `PU_WRITE_FIXTURE=1`
  and never edited. Platforms with a different math library, such as Linux, are not claimed.
- Q: How does the preview run, and how does it respect Reduce Motion? → A: A SwiftUI `Canvas` inside a `TimelineView`
  advances the runner with each frame's time and draws a copy of `instances()`. Under Reduce Motion the scene starts
  paused, with Play and Step controls. The drawing never writes to the simulation.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pick an emitter family and see a bounded particle scene (Priority: P1) 🎯

A person opens the sandbox, picks one of four emitter families and sees particles leave it, with the number of live
particles shown and never above the scene's limit.

**Why this priority**: v0.1 feature 01, the phase's MVP gate.

**Independent Test**: Choose each family in the app; read the live count and the preview; host tests on the shapes.

**Acceptance Scenarios**:

1. **Given** the scene screen, **When** the person picks Fountain, Curtain, Halo or Firework, **Then** particles appear
   from a point, a line, a ring, or in periodic bursts respectively, and the family has a spoken description.
2. **Given** any family at its highest rate, **When** the simulation runs, **Then** the live count never exceeds the
   scene's particle limit and particles that could not be created are counted and shown as "dropped".
3. **Given** a shape, **When** particles spawn, **Then** each starts on that shape (on the point, on the segment, on
   the circle) within a tolerance of 1e-9 world units.
4. **Given** invalid emitter values (negative or non-finite rate, lifetime, size or radius), **Then** they are clamped
   to valid ranges before use and no non-finite particle is created.

---

### User Story 2 - Replay a seed and get the same scene (Priority: P1)

A person (or a test) replays a seed with the same controls and gets exactly the same particle positions; a different
seed gives a different scene.

**Why this priority**: Regression fixture 1 and journey 3 ("pause, reseed and replay a deterministic scene").

**Independent Test**: Host tests against a committed replay fixture.

**Acceptance Scenarios**:

1. **Given** a seed, a scene and a recorded control stream (for example "move the attractor at step 120", "burst at
   step 240"), **When** the stream is replayed for a fixed number of steps, **Then** the state checksum and a sample of
   particle positions equal the committed fixture bit for bit.
2. **Given** the same scene with another seed, **Then** the checksum differs.
3. **Given** the same replay split into different frame lengths (for example 1/60 s versus 1/30 s frames), **Then** the
   number of fixed steps and the final checksum are the same.

---

### User Story 3 - Time stays bounded when the app pauses or frames stall (Priority: P1)

Pausing, a stalled frame or a return from the background never makes the simulation race ahead.

**Why this priority**: Manual §6 render sequence stage 2 ("fixed timestep and capped substeps") and fixture 5's
generic part; G-SIMSTEP.

**Independent Test**: Host tests feed long and invalid frame times.

**Acceptance Scenarios**:

1. **Given** a running scene, **When** one frame reports 10 seconds, **Then** at most the per-frame substep cap of
   fixed steps runs and the rest is counted as dropped time.
2. **Given** a paused scene, **When** time passes and the scene resumes, **Then** no steps run for the paused time.
3. **Given** a frame time that is negative, NaN or infinite, **Then** no step runs and the frame is counted as invalid.

---

### User Story 4 - A validated, versioned scene description (Priority: P2)

The scene a person builds (families, seed, limit, time scale) is plain, versioned data that is checked before use, so
later phases can save it and the renderer can be rebuilt from it.

**Why this priority**: Manual §6 versioned domain schemas; prepares Phase 04 persistence without implementing it.

**Independent Test**: Host tests encode, decode and validate scenes.

**Acceptance Scenarios**:

1. **Given** a valid scene, **When** it is encoded and decoded, **Then** it is equal to the original.
2. **Given** scene data with an unsupported version, non-finite numbers, more emitters than the limit or a particle
   limit outside its range, **Then** it is rejected with a specific reason and nothing is created.

### Edge Cases

- A ring of radius 0 or a line of length 0 behaves as a point.
- A burst interval of 0 or below is clamped to the minimum interval, so it never bursts on every step without limit.
- A scene whose emitters ask for more particles than the limit drops the excess and counts it; the live count stays
  at the limit.
- Changing the family or the seed restarts the scene from the seed; it never mixes the old population into the replay.
- The preview is drawn from a copy of the current particles; the drawing never changes the simulation.
- A control command naming an emitter or attractor that does not exist is ignored and counted; it never crashes or
  changes another element (checklist CHK005).
- Going to the background pauses the scene; returning resumes it only if it was playing, without catching up the
  time spent away. Under Reduce Motion the scene starts paused (checklist CHK017).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A04-101**: VisualCore MUST provide emitter shapes point, line and ring and a burst emission mode (a count every
  interval), each sampled with the system's seeded generator; the default point shape MUST leave existing seeded
  results unchanged (A01's fixtures) (G-EMITTERS).
- **FR-A04-102**: Emitter parameters MUST be clamped to valid ranges before use (rate, burst count and interval,
  lifetime, speed, sizes, shape lengths); totals MUST never exceed the pool capacity, and drops MUST be counted.
- **FR-A04-103**: VisualCore MUST provide a deterministic fixed-step runner for any steppable simulation: fixed step,
  per-frame substep cap, pause and resume with no catch-up for paused time, invalid frame times ignored and counted, a
  step index, and replay of a control stream applied at given step indices (G-SIMSTEP).
- **FR-A04-104**: Replaying the same seed, scene and control stream MUST reproduce the committed position fixture
  (checksum and sampled positions) exactly, independent of how the elapsed time is split into frames.
- **FR-A04-105**: The app MUST define a versioned `ParticleScene` with emitters (family and parameters), the seed, the
  particle limit, the time scale and the existing VisualCore forces, validated on decode and before use, and map it to
  the VisualCore particle system.
- **FR-A04-106**: The app MUST offer four emitter families (Fountain, Curtain, Halo, Firework) through an accessible
  control, show the live and dropped counts, and draw a CPU preview of the current particles that does not use the GPU
  and never mutates the simulation.
- **FR-A04-107**: The contract MUST record G-SIMSTEP and G-EMITTERS as closed with their tests; the API baseline, the
  documented-API check, the VisualCore host tests and the ProjectM reference regression MUST pass; A01 and A02 MUST
  still build.

### Negative requirements

- No GPU simulation, compute shader or new renderer; no EGL or GL call from the app (constitution A04).
- No claim of physical accuracy; the simulation is an artistic sandbox.
- No persistence, network access or permission in this phase.
- No change to `External/projectm-ios`.

### Key Entities

- **Emitter family**: a named preset of shape, emission mode and parameters (Fountain, Curtain, Halo, Firework).
- **Emitter shape**: point, line (half length, angle) or ring (radius), in world units.
- **ParticleScene**: version, seed, particle limit, time scale, emitters, forces.
- **Control stream**: ordered commands with the step index at which each applies.
- **Replay fixture**: seed, scene, control stream, step count, expected checksum and sampled positions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A04-101**: 100% of spawned particles start on their shape (tolerance 1e-9) across 10,000 spawns per shape.
- **SC-A04-102**: With a demand of 10× the limit, the live count stays ≤ the limit on every step and the dropped count
  equals demand minus created.
- **SC-A04-103**: The replay fixture matches bit for bit on the host, and the same replay at two frame lengths gives
  the same checksum.
- **SC-A04-104**: A 10-second frame runs at most the substep cap; a paused period runs 0 steps.
- **SC-A04-105**: All invalid scene cases are rejected with their reason; valid scenes round-trip equal.
- **SC-A04-106**: The family control and counts pass UI tests and the accessibility audit on iOS 27.2 and 26.5.

## Assumptions

- VisualCore's existing `ParticleSystem`, `FixedStepClock` and `SeededRandom` are the base; this phase extends them.
- The preview is a small CPU drawing of the current particle snapshot; the GPU path arrives in Phase 02.
- Defaults (limit, step, cap, family parameters) are chosen in clarification and recorded there.

## Traceability

| Source | Requirement |
|---|---|
| Brainstorm "GPU-oriented particle simulation" (decided: bounded CPU simulation, A04-P00 R1) | FR-A04-103, FR-A04-104 |
| Brainstorm "interaction and simulation parameters" | FR-A04-105, FR-A04-106 |
| v0.1 feature 01 (multiple emitter families with bounded counts) | FR-A04-101, FR-A04-102, FR-A04-106, US1 |
| Manual §11 fixture 1 (replay) | FR-A04-104, US2 |
| Manual §11 fixture 5 (bounded resume), generic part | FR-A04-103, US3 |
| Manual §6 versioned domain schemas | FR-A04-105, US4 |
| Journey 3 (pause, reseed, replay) | US2, US3 |
| Gap register G-SIMSTEP, G-EMITTERS | FR-A04-101, FR-A04-103, FR-A04-107 |
