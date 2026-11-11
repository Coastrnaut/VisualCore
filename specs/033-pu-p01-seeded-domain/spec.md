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
