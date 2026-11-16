# Feature Specification: Simulation Lab — Phase 03 Reaction-diffusion and wave algorithms

**Feature Branch**: `119-sl-p03-rd-wave` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P03 (legacy ledger) · ID namespace FR-A16-3##, SC-A16-3##, T-A16-3##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 03):** MVP — pause, reset, step, speed (built in A16-P01 and kept) and a histogram or
  legend overlay; regression fixture — invalid time steps rejected or clamped with a visible explanation; graphics
  context ownership stays solely in the audited VisualCore host.
- **Gap built here** (contract `docs/apps/simulation-lab/visualcore-contract.json`): G-RDWAVE-GPU (reaction-diffusion
  and the wave field stepped and drawn on the GPU with floating-point targets, the float probe per context generation
  and both families disabled with a message when it reports none, the wave's fixed zero border and wrap for
  reaction-diffusion). The legend overlay and the time-step control are added for the phase gates; the histogram and
  presets stay in A16-P04.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A16; every Spec Kit step runs. Follow `specs/118-sl-p02-automata-gpu`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reaction-diffusion and waves on the graphics processor (Priority: P1) 🎯

A person watching reaction-diffusion or a wave field sees it stepped on the graphics processor, agreeing with the
reference rule within a stated tolerance, with the wave held at zero on its edges.

**Why this priority**: the phase's deliverable.

**Independent Test**: run each family for some steps; read the GPU field back; compare with the CPU reference.

**Acceptance Scenarios**:

1. **Given** reaction-diffusion or the wave field, **When** steps run on the GPU, **Then** every cell agrees with the CPU
   reference within the stated tolerance.
2. **Given** the wave field, **Then** every edge cell stays zero.
3. **Given** the drawing surface is lost or resized, **When** drawing resumes, **Then** the GPU field is rebuilt from the
   CPU state.

---

### User Story 2 - Unsupported hardware is stated, not hidden (Priority: P1)

A person on hardware without floating-point render targets is told that reaction-diffusion and the wave field are not
available there, instead of seeing a degraded run.

**Why this priority**: the constitution's "no silent 8-bit run" rule.

**Independent Test**: force the probe to report no support; choose each family; read the message and the controls.

**Acceptance Scenarios**:

1. **Given** no floating-point support, **When** the experience opens, **Then** the two families are shown as
   unavailable with a message and no 8-bit field is made for them.

---

### User Story 3 - Read the field with a legend (Priority: P2)

A person reads a legend beside the field: the colour scale of the current family with its value range, and the current
minimum and maximum, spoken as well as shown.

**Why this priority**: the phase's MVP "histogram/legend overlay".

**Independent Test**: open each family; read the legend and the description.

**Acceptance Scenarios**:

1. **Given** any family, **Then** a legend shows its scale and the current minimum and maximum, and the description
   says the same.

---

### User Story 4 - A too-large time step is explained (Priority: P2)

A person who sets a time step beyond the stable limit sees it refused with a sentence that names the limit, and the
simulation keeps running unchanged.

**Why this priority**: the phase's regression fixture.

**Independent Test**: set time steps below, at and above each limit; read the message and the state.

**Acceptance Scenarios**:

1. **Given** reaction-diffusion, **When** a time step above its limit is set, **Then** it is refused with the sentence
   naming the limit and the state is unchanged.
2. **Given** the wave field, **When** a time step making the Courant number exceed its limit is set, **Then** it is
   refused with "The wave step is too large: the Courant number must stay at or below 0.707." and nothing changes.

### Edge Cases

- **Long runs:** the GPU field is reloaded from the CPU state at a fixed interval so that rounding differences never
  accumulate beyond the tolerance.
- **The automaton:** keeps its exact GPU path from A16-P02; its time step is fixed and the control is disabled.
- **A step program that fails to compile or an incomplete target:** setup throws and the session fails through the
  host's failure state.
- **Restore of a saved state in a disabled family (no float support):** the state is kept and drawn from the CPU field
  with the message; the family cannot be chosen again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A16-301**: Reaction-diffusion MUST step on the GPU on floating-point targets with wrap and agree with the CPU
  reference within the stated tolerance.
- **FR-A16-302**: The wave field MUST step on the GPU on floating-point targets with a fixed zero border and agree with
  the CPU reference within the stated tolerance.
- **FR-A16-303**: The GPU fields MUST be loaded from the CPU state on setup, recreation, resize, any non-step change and
  at a fixed reload interval, and stepped by the engine's iterations otherwise; no pass reads what it writes.
- **FR-A16-310**: The float probe MUST run for each context generation; without support both families MUST be shown as
  unavailable with a message and no 8-bit field made for them.
- **FR-A16-320**: A legend MUST show the family's colour scale, value range and current minimum and maximum; the canvas
  description MUST state them.
- **FR-A16-330**: A time-step control MUST exist for reaction-diffusion and the wave field; values beyond the stability
  limit MUST be refused with a visible, spoken sentence naming the limit, leaving the state unchanged.
- **FR-A16-340**: The runner's standard scenarios MUST pass on iOS 27.

### Key Entities

- **Float field**: two floating-point targets (reaction-diffusion u, v; wave current, previous).
- **Legend**: scale, range, current minimum and maximum.
- **Time step**: per family, with its limit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-301**: After 10 GPU steps on a 16 × 16 grid, both families agree with the CPU within the stated tolerance
  against both half-float roundings.
- **SC-A16-302**: 100 % of wave edge cells read zero after 100 GPU steps.
- **SC-A16-303**: With forced no-support, 0 floating-point or 8-bit fields are made for the two families and the
  message is shown.
- **SC-A16-304**: Time steps 1 % above each limit are refused with their sentence; at the limit they are accepted.
- **SC-A16-305**: The legend values equal the field's minimum and maximum; every test runs in under 10 s; the runner's
  standard scenarios pass on iOS 27.

## Assumptions

- The Gray-Scott GPU step of A16-P02, `PingPongTarget`, `FieldPass` and `FloatRenderSupport` are reused; the canvas
  overlay slot of the host draws the legend; no VisualCore change is planned.

## Traceability

| Source | Requirement |
|---|---|
| Phase 03 deliverable: reaction-diffusion and wave algorithms | FR-A16-301–303 |
| Phase 03 MVP: pause, reset, step, speed and legend overlay | FR-A16-320 (the rest kept from A16-P01) |
| Regression fixture: invalid time steps refused with visible explanation | FR-A16-330, SC-A16-304 |
| Constitution: no silent 8-bit run | FR-A16-310, SC-A16-303 |
| Contract gap G-RDWAVE-GPU | FR-A16-301–310 |
| EGL/context ownership in the VisualCore host | FR-A16-303 |

## Negative Requirements

- No 8-bit simulation of reaction-diffusion or waves; no second renderer; no VisualCore change; no claim of accuracy
  beyond the stated tolerance; no images.
