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
2. **Given** floating-point targets are not available, **Then** the comparison is not attempted and the reason is
   recorded.

### Edge Cases

- **Speed above one step per frame:** several GPU steps per frame, the same count as the CPU.
- **A refused action:** the GPU field does not change.
- **Reset or family change:** the GPU field is replaced by the CPU start.
- **Restore of a saved state:** the GPU field is loaded from the saved field.
- **Floating-point targets unavailable (fixture only):** the reaction-diffusion comparison reports it; the automaton
  needs only 8-bit targets.

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
