# Research: Particle Universe — Phase 01

## R1 — Extend `ParticleSystem` rather than add a second particle type

- **Decision:** add shapes and bursts to VisualCore's `Emitter`/`ParticleSystem`.
- **Rationale:** A01 already uses it, and the constitution's A04 reuse rule says the extraction condition is met. A
  second pool would split the API.
- **Alternatives:** an app-local pool (rejected: Principle II); a new `VisualCoreParticles` module (rejected: churn
  with no benefit).

## R2 — Random draws per shape keep old results bit-identical

- **Decision:** point shape draws nothing extra; line and ring draw exactly one `double()` *after* the existing angle
  and speed draws.
- **Rationale:** A01's `ParticleReplay` tests and `VisualCoreBaselines` checksums must not change.
- **Alternatives:** draw first (rejected: shifts every later value).

## R3 — Bursts through a per-emitter time accumulator

- **Decision:** `EmitterBurst(count, interval)`.
  - The emitter keeps a burst clock that starts at `interval`, so the first burst comes on the first step.
  - On each step it adds `dt`; while the clock is ≥ `interval` it emits `count` and subtracts `interval`.
  - At most one burst runs per step, and the leftover is capped below one interval, so a stall cannot cause a storm.
- **Rationale:** deterministic, step-indexed, bounded.
- **Alternatives:** wall-clock timers (rejected: not deterministic).

## R4 — Clamping is applied when the system reads emitters

- **Decision:**
  - `Emitter.clamped()` is a pure function, and the system uses `emitters[e].clamped()` when emitting.
  - Stored emitters stay as the caller set them; the app validates its scene separately and reports errors.
  - The ranges are as in spec clarification 1, and A01's ranges (rate ≤ 2,000, size ≤ 24, spread ≤ π, speed ≤ 625)
    lie inside them.
- **Rationale:** total safety without changing valid inputs.

## R5 — Runner generic over a protocol

- **Decision:**
  - `protocol FixedStepSimulation { mutating func step(_ dt: Double); func checksum() -> UInt64 }`.
  - `FixedStepRunner<S, Command>` holds `simulation: S`, `clock: FixedStepClock`, `stepIndex`, `isPaused`, and a
    `ControlStream<Command>`.
  - Its apply closure has the signature `(inout S, Command) -> Void`.
  - `advance(frame:)` returns the steps run.
  - `stepOnce()` steps a paused runner.
  - `run(steps:)` runs a replay with no clock.
- **Rationale:** A09, A11 and A19 reuse it with other simulations. Commands keyed by step index make a replay
  independent of frame lengths (SC-A04-103).
- **Alternatives:** a closure-only stepper (rejected: no checksum contract).

## R6 — Time scale

- **Decision:** the time scale multiplies the frame time before it reaches the clock. The fixed step is unchanged, so
  determinism holds.
- **Rationale:** the step count changes, but the steps stay identical.

## R7 — Fixture platform

- **Decision:** the bit-exact fixture is checked on the macOS host (arm64) and both iOS simulators.
- **Rationale:** `cos`/`sin` come from Apple's libm on all of these. Linux is not claimed.

## R8 — Preview

- **Decision:** a SwiftUI `Canvas` with `TimelineView(.animation(paused:))`. It fits the world square
  [−500, 500]² into the view with aspect fit and y up, and draws each particle as a filled circle of its size, with
  alpha from its color.
- **Rationale:** a CPU drawing with no GPU or EGL, and native accessibility around it.
- **Alternatives:** VisualCore's `ParticleRenderer` (that is Phase 02's GPU loop).
