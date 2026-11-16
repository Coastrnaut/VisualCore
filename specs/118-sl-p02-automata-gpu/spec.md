# Feature Specification: Simulation Lab — Phase 02 Cellular automata GPU parity

**Feature Branch**: `118-sl-p02-automata-gpu` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P02 (legacy ledger) · ID namespace FR-A16-2##, SC-A16-2##, T-A16-2##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 02):** MVP — a clear parameter schema per experiment and seeded starting conditions
  (built in A16-P01 and kept); regression fixture — Gray-Scott on a tiny grid, GPU against CPU, stays inside a
  documented tolerance; graphics context ownership stays solely in the audited VisualCore host.
- **Gap built here** (contract `docs/apps/simulation-lab/visualcore-contract.json`): G-CA-GPU (the automaton step and
  display on the GPU with exact states and wrap, GPU-versus-CPU parity, pass isolation, rebuild after context loss or
  resize). The phase's fixture adds a Gray-Scott step on the GPU for a tiny grid; reaction-diffusion and the wave field
  run in the experience on the GPU from A16-P03.
- **Experience:** the candidate's automaton steps on the GPU in lockstep with its CPU reference; no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A16; every Spec Kit step runs. Follow `specs/117-sl-p01-algorithms`.

## Clarifications

### Session 2026-11-16

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`PingPongTarget` (read and write `RenderTarget`, `swap()`), `FieldPass.run(pair:input:extraInputs:)`,
`FieldPassError.inputIsOutput` and `FieldPass.runObserver` (each `Run` lists its output and input texture names),
`Texture.readPixels()` and `readFloatPixels()` (`GPUObjects.swift`), `FloatRenderSupport.detect(in:)` and
`StoragePrecision.tolerance` (1e-3 for half floats, 1.5/255 for unorm8) exist; GLES leaves float-to-half rounding of
colour writes implementation-defined (`StoragePrecision.float16TowardZero` documents truncation on the iOS 27.2
simulator).

- Q: Which side is the engine's truth? → A: The CPU model of A16-P01 stays the truth (snapshots, digests, replays); the
  GPU field is a mirror stepped in lockstep and drawn; parity is proved by tests, not trusted at run time.
- Q: When is the GPU field loaded and how far does it step? → A: Loaded from the CPU field at setup, after a context
  recreation or resize, and whenever the core's field changed other than by stepping (family, preset, reset, restore,
  a step count that went down or jumped by more than the per-frame cap); otherwise it runs exactly the iterations the
  engine ran since the last frame (at most 16 per host step × 8 host steps).
- Q: How is the automaton stored and stepped on the GPU? → A: RGBA8, alive = red 255, dead = 0, read with `texelFetch`
  and thresholded at 0.5; neighbours wrap by index modulo the grid size (the registry's CLAMP_TO_EDGE is not used for
  lookup); birth and survival sets passed as two 9-bit masks.
- Q: What are the Gray-Scott fixture and its tolerance? → A: A 16 × 16 seeded grid in an RGBA16F ping-pong pair (u in
  red, v in green), 10 steps with `highp` arithmetic, compared with the CPU reference rounded with `float16` and with
  `float16TowardZero`; it passes when the largest cell difference against either is at most 10 × 1e-3 = 0.01 (one
  half-float storage step per step). The iOS 27.2 simulator reports float targets; when `FloatRenderSupport` reports
  none, the fixture fails with the message "Floating-point render targets are not available" rather than skipping
  silently.
- Q: How is pass isolation observed? → A: `FieldPass.runObserver` records every run for 10 frames; for every run the
  output texture name is not among its input names, and step runs alternate between the two targets of the pair.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The automaton runs on the graphics processor (Priority: P1) 🎯

A person watching a cellular automaton sees it stepped on the graphics processor, cell for cell the same as the
reference rule, at every speed, after pausing and stepping, and after the app returns from the background.

**Why this priority**: the phase's deliverable "cellular automata GPU parity".

**Independent Test**: run the automaton for several steps; read the GPU field back; compare with the CPU reference.

**Acceptance Scenarios**:

1. **Given** a seeded automaton, **When** N steps run on the GPU, **Then** every cell equals the CPU reference after N
   steps.
2. **Given** a blinker, **When** two GPU steps run, **Then** the field equals the start; a glider wraps across an edge.
3. **Given** the drawing surface is lost or resized, **When** drawing resumes, **Then** the GPU field is rebuilt from the
   CPU state and still equals the reference.

---

### User Story 2 - A pass never reads what it writes (Priority: P1)

The engineer can trust the feedback loop: every simulation pass reads one texture and writes the other, never the same.

**Why this priority**: the manual's risk 2 and the constitution's resource-separation rule.

**Independent Test**: observe every pass over several frames.

**Acceptance Scenarios**:

1. **Given** the running automaton, **When** several frames are drawn, **Then** no pass samples the texture it writes.

---

### User Story 3 - Reaction-diffusion agrees on a tiny grid (Priority: P2)

The engineer sees that a Gray-Scott step on the graphics processor agrees with the CPU reference on a tiny grid within
a documented tolerance, before the experience relies on it in Phase 03.

**Why this priority**: the phase's regression fixture.

**Independent Test**: run a few Gray-Scott steps on a tiny grid on both; compare the largest difference with the
tolerance.

**Acceptance Scenarios**:

1. **Given** the same tiny seeded grid, **When** the same number of steps run on the GPU and the CPU, **Then** the
   largest difference in any cell stays within the documented tolerance.
2. **Given** floating-point targets are not available, **Then** the fixture fails with its stated message instead of
   passing silently.

### Edge Cases

- **Speed above one step per frame:** several GPU steps per frame, the same count as the CPU.
- **A refused action:** the GPU field does not change.
- **Reset or family change:** the GPU field is replaced by the CPU start.
- **Restore of a saved state:** the GPU field is loaded from the saved field.
- **Floating-point targets unavailable (fixture only):** the reaction-diffusion fixture fails with its message; the
  automaton needs only 8-bit targets.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-201**: The automaton MUST step on the GPU with exact two-state cells, the same neighbourhood and rule as the
  reference, and a wrap boundary, in ping-pong targets; after any number of steps the GPU field MUST equal the CPU
  reference.
- **FR-A16-202**: The GPU field MUST be loaded from the CPU state at start, reset, family or preset change, restore,
  context recreation and resize, and MUST advance by exactly the iterations the engine ran.
- **FR-A16-203**: No pass MUST read the texture it writes; the separation MUST be observable in tests.
- **FR-A16-204**: The displayed automaton MUST come from the GPU field; drawing MUST never change the engine state.
- **FR-A16-210**: A Gray-Scott step on the GPU MUST agree with the CPU reference on a tiny grid within a documented
  tolerance when floating-point targets are available, and MUST report when they are not.
- **FR-A16-220**: The runner's standard scenarios MUST pass on iOS 27.

### Key Entities

- **GPU field**: two targets of the grid size, one read and one written per step.
- **Parity check**: a read-back of the GPU field compared with the CPU reference.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-201**: 100 % of cells equal the reference after 1, 2, 10 and 100 GPU steps of a seeded automaton.
- **SC-A16-202**: The GPU blinker has period 2 and a GPU glider returns after 4 × grid-size steps.
- **SC-A16-203**: 0 passes read their own output over 10 frames.
- **SC-A16-204**: After context recreation and a resize, the GPU field equals the reference.
- **SC-A16-205**: The Gray-Scott tiny-grid difference stays within the documented tolerance; every test runs in under
  10 s; the runner's standard scenarios pass on iOS 27.

## Assumptions

- `PingPongTarget`, `FieldPass` with its pass observer and input-is-output refusal, `RenderTarget`, read-back of pixels
  and `FloatRenderSupport` exist in VisualCoreRendering and are reused; no VisualCore change is planned.
- The CPU model of A16-P01 stays the engine's truth; the GPU mirrors it.

## Traceability

| Source | Requirement |
|---|---|
| Phase 02 deliverable: cellular automata GPU parity | FR-A16-201, 202, 204, SC-A16-201, 202 |
| Regression fixture: Gray-Scott tiny-grid GPU vs CPU within tolerance | FR-A16-210, SC-A16-205 |
| Manual risk 2: read-write feedback | FR-A16-203, SC-A16-203 |
| Lifecycle: context loss and resize rebuild from CPU state | FR-A16-202, SC-A16-204 |
| Contract gap G-CA-GPU | FR-A16-201–204 |
| EGL/context ownership in the VisualCore host | FR-A16-204 |

## Negative Requirements

- No second renderer and no own EGL path; no VisualCore change; no change to the engine state from drawing; no claim
  of accuracy beyond the stated parity and tolerance; no images.
