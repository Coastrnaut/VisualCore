# Feature Specification: Fluid Art Playground — Phase 01 Ping-pong feedback validation

**Feature Branch**: `019-fap-p01-pingpong` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P01 · ID namespace FR-A02-1##, SC-A02-1##, T-A02-1##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation). Canonical overrides:
- The reusable gaps from the A02-P00 contract are built in VisualCoreRendering with tests, docs, the API baseline
  and the ProjectM regression (constitution 1.3.0, Principle II):
  - G-PINGPONG: a read/write render-target pair;
  - G-FLOATRT: a half-float render-target support query with a fallback;
  - G-FIELDPASS: a full-screen program pass with named inputs.
- The solver math stays in the app, in a GPU-free Core package with a CPU reference (A02 rule).
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing delegation (CLAUDE.md §2), recommended option in each case.

- Q: Which dissipation formula defines "decays only according to configured dissipation"? → A: Per step, every
  channel is multiplied by `1 / (1 + d·Δt)`, where `d` is the configured dissipation (0…10 per second) and `Δt` the
  clamped step. With `d = 0` the value is unchanged.
- Q: What are the bounds for grid size and time step? → A: Each grid edge is 16…512 cells, and further capped by the
  device's maximum render size. The default is 128 × 128. `Δt` is the frame interval clamped to 1/240…1/30 s. After a
  pause, exactly one clamped step is taken; there is no catch-up loop.
- Q: What does the GPU result have to match, given that half-float and 8-bit storage round every step? → A: The CPU
  reference rounds to the same storage precision after every step (`float32`, `float16` or `unorm8`). The GPU must
  match the reference for its active format within one storage step per channel: 1e-3 for half-float values ≤ 1, and
  1.5/255 for the 8-bit fallback. A plain float32 reference is not used for comparison, because 8-bit decay stalls
  when the per-step change is below 1/510.
- Q: How is half-float support decided, and what is the fallback? → A: Support needs a color-buffer float extension
  (`GL_EXT_color_buffer_half_float` or `GL_EXT_color_buffer_float`) and a complete RGBA16F framebuffer probe.
  Otherwise the fallback is RGBA8, with signed velocity encoded as `v / vmax · 0.5 + 0.5` (vmax from the
  configuration, default 4 cells per step). The active format is reported. A test-only override forces the
  fallback.
- Q: What state do the fields have after a context loss? → A: Field contents are never carried across contexts.
  Both pairs are recreated and re-seeded from the configuration's initial state, the step counter resets, and the
  rebuild is reported with 0 leaked or stale resources.

## User Scenarios & Testing *(mandatory)*

Users: people who open the playground (manual journeys 1–2), the implementer of later solver phases, and other apps
that reuse the ping-pong and field-pass machinery (for example A16 Simulation Lab).

### User Story 1 - Bounded velocity and dye fields evolve correctly (Priority: P1) 🎯

The playground keeps a velocity field and a dye field on a bounded grid. Each simulation step reads the current
field and writes the next one to a separate target. With no motion, dye fades only by the configured dissipation,
exactly as the reference model predicts.

**Why this priority**: It is version 0.1 feature 01 and the manual's Phase 01 regression fixture.

**Independent Test**: Start from uniform dye at rest, run a fixed number of steps on the GPU and on the CPU
reference, and compare. The values agree within the stated tolerance, and every step wrote to a different target
than it read.

**Acceptance Scenarios**:

1. **Given** uniform dye and zero velocity, **When** N steps run, **Then** the dye equals the initial value scaled by
   the dissipation decay for N steps, within tolerance, on the GPU and in the CPU reference.
2. **Given** any configuration, **When** it is applied, **Then** the grid size, time step and dissipation are within
   their bounds. Out-of-range values are clamped and reported, never used.
3. **Given** any step, **When** it runs, **Then** it never samples the target it is writing to.

---

### User Story 2 - Reusable ping-pong and field passes in VisualCore (Priority: P1)

Other apps reuse three pieces:
- a pair of render targets that swap roles each step and refuse to read and write the same target;
- a query that says whether half-float targets can be rendered on this device, with a defined fallback;
- a full-screen pass that runs a shader program with named input fields into an output target.

**Why this priority**: It closes gaps G-PINGPONG, G-FLOATRT and G-FIELDPASS from the A02-P00 contract (reuse rule).

**Independent Test**: Package tests for swapping, the read/write guard, budget accounting, release after context
loss, the support query matching a real probe, the fallback, and a field pass matching a CPU result on a tiny grid.
Docs and the API baseline are updated, and the ProjectM regression passes.

**Acceptance Scenarios**:

1. **Given** a pair, **When** it is swapped, **Then** the read and write targets exchange roles. Binding the read
   target as the output is rejected.
2. **Given** a device without half-float render targets (forced in a test), **When** fields are created, **Then** the
   documented fallback format is used and reported.
3. **Given** the VisualCore change, **When** the reference regression runs, **Then** it passes (7/7).

---

### User Story 3 - See the fields on screen (Priority: P2)

From the home screen, the user opens the playground and sees a seeded dye pattern fading according to the
dissipation, rendered through the shared VisualCore host. VoiceOver describes the canvas.

**Why this priority**: It is the smallest visible vertical slice. Touch input arrives in Phase 02.

**Independent Test**: Open the canvas in a UI test. It exists with a spoken description, and the rendered image is
non-blank and changes over time as the dye fades.

**Acceptance Scenarios**:

1. **Given** the home screen, **When** the user opens the playground, **Then** a canvas shows the seeded dye pattern
   with a spoken description.
2. **Given** the canvas, **When** the graphics context is lost, **Then** the fields are rebuilt from the
   configuration and the canvas keeps rendering with 0 leaked resources.

### Edge Cases

- A requested grid larger than the cap (512 per edge, or the device's maximum render size if smaller): clamped to the
  cap and reported.
- Half-float render targets unavailable (no color-buffer float extension, or an incomplete probe): RGBA8 is used, with
  signed velocity encoded as `v / vmax · 0.5 + 0.5`. It is compared against the 8-bit-rounding reference within
  1.5/255.
- A long pause between frames: the simulation time step is clamped, so a resume never takes one huge step.
- Context loss: field contents are not preserved across a context; they are rebuilt from the configuration's
  initial state, and no stale target is used.
- Zero dissipation: dye stays constant to within rounding.
- Maximum dissipation: dye decays toward zero without negative values or NaN.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-101**: The app MUST define a validated fluid configuration:
  - grid width and height, within bounds and capped;
  - time step;
  - dye and velocity dissipation;
  - viscosity and pressure iterations (stored and validated now, used in Phase 03).

  Out-of-range values are clamped and reported.
- **FR-A02-102**: The app MUST provide a GPU-free CPU reference for the fields and for the dissipation step,
  testable on the host.
- **FR-A02-103**: The app MUST keep the velocity and dye fields on the GPU in ping-pong pairs. Every step writes to a
  target different from the one it reads, and the fields are bounded by the configuration.
- **FR-A02-104**: Uniform dye at rest MUST decay only according to the configured dissipation: each step multiplies by
  `1 / (1 + d·Δt)`. After a fixed number of steps, the GPU result matches the precision-matched CPU reference within one
  storage step per channel (1e-3 half-float; 1.5/255 for the RGBA8 fallback).
- **FR-A02-105**: VisualCore MUST provide, with tests, docs and an API-baseline update, followed by a passing ProjectM
  regression:
  - a reusable ping-pong render-target pair: swap, a read/write guard, budget accounting, release;
  - a half-float render-target support query, with a documented fallback;
  - a full-screen field pass with named inputs, typed uniforms and an input-equals-output guard.
- **FR-A02-106**: The app MUST show the evolving dye field on a canvas through the shared VisualCore host, with a
  spoken description. It creates no EGL context of its own.
- **FR-A02-107**: After context loss, the fields MUST be rebuilt from the configuration with no stale handles and 0
  leaked resources.
- **FR-A02-108**: The simulation time step MUST be clamped to 1/240…1/30 s. Resuming after a pause takes exactly one
  clamped step, never a catch-up loop.
- **FR-A02-109**: The VisualCore contract MUST be updated: G-PINGPONG, G-FLOATRT and G-FIELDPASS closed; M01, M03 and
  M10 available. The contract check MUST pass. The app MUST stay offline and link no ProjectM module.

### Key Entities

- **Fluid configuration**: grid width and height, time step, dye dissipation, velocity dissipation, viscosity,
  pressure iterations, seed.
- **Field**: a 2D grid of values (velocity: 2 components; dye: 4 color components), held by the CPU reference or by
  a ping-pong pair on the GPU.
- **Ping-pong pair** (VisualCore): two equally sized render targets with read and write roles.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-101**: For 3 dissipation values (including 0) and 60 steps, uniform dye at rest on the GPU matches the CPU
  reference within the stated tolerance (half-float and fallback paths), on both runtimes.
- **SC-A02-102**: 100% of simulation passes write to a target different from their sampled input (checked by the
  guard and a test).
- **SC-A02-103**: Out-of-range configurations (at least 8 cases) are clamped and reported. No NaN or negative dye
  appears in 1,000 CPU steps at maximum dissipation.
- **SC-A02-104**: Context loss and rebuild leak 0 resources, and the canvas keeps rendering.
- **SC-A02-105**: The API review, documented-API check, contract check, ProjectM regression (7/7) and the app tests on
  both runtimes all pass.

## Assumptions

- The fluid model is artistic, not physical. Phase 01 implements only fields and dissipation; advection, splats and
  pressure arrive in Phases 02–03.
- Device-specific half-float support is confirmed in campaign II. Here the query is checked against a probe on the
  simulators.
- No user settings or persistence in this phase.
