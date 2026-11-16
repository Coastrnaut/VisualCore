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

## Clarifications

### Session 2026-11-16

Answered by the lead under the owner's standing delegation (the recommended option each time), with the facts checked
in code: `FloatRenderSupport.detect(in:)` caches per `ResourceRegistry.generation`; `GrayScottGPU` (A16-P02) keeps u in
red and v in green of an RGBA16F pair; `SimulationSpec.refusal()` already gives `SimulationRefusal.reactionStep`
("… at or below 1.5625.") and `.courant` ("… at or below 0.707."); `ParameterCatalog` declares reaction Δt 0.1…1.5625
and wave Δt 0.05…1 with speed c 0.1…2; the controls show `SimulationMirror.message`; the presenter protocol offers
`makeCanvasOverlay(_:) -> AnyView?`. Today the presenter draws reaction-diffusion and the wave from a CPU upload.

- Q: How is the wave field held on the GPU, and how is its border kept at zero? → A: One RGBA16F ping-pong pair
  (`WaveGPU`, a new app-local type beside `GrayScottGPU`), the current value uⁿ in red and the previous uⁿ⁻¹ in green;
  the step writes (uⁿ⁺¹, uⁿ). The step program takes uniforms `uCourant2` (C²) and `uKeep` (1 − γ) and writes 0 for any
  cell on the edge (index 0 or n − 1, by `gl_FragCoord`), matching `WaveField.step`; neighbours are read by `texelFetch`
  without wrap. Reaction-diffusion keeps the `GrayScottGPU` wrap.
- Q: What tolerance and test shape prove GPU agreement for the two families? → A: 10 GPU steps on a 16 × 16 field from
  the seeded start, read back and compared per cell with the CPU reference computed in both `float16` and
  `float16TowardZero` (the simulator truncates half writes); the GPU passes when the smaller of the two maxima is
  ≤ 0.01, for each family. The wave edge test runs 100 GPU steps on 16 × 16 and reads every edge cell as exactly 0.
- Q: How does the GPU field stay within tolerance on long runs? → A: The presenter steps the GPU field by the engine's
  iteration delta and reloads it from the CPU field whenever 64 GPU steps have run since the last load (and on setup,
  recreation, resize, any family, preset, reset, restore or time-step change). The CPU model stays the truth for
  digests, snapshots, the legend and the description; the automaton keeps its exact A16-P02 path with no reload.
- Q: What does the time-step control look like and how is a refusal shown? → A: A new action `sim.timestep [Δt]` with
  the declared range 0.05…2.0, so values beyond each stable limit reach the core. For reaction-diffusion Δt above
  1.5625 is refused with `a16.unstable` and the sentence of `SimulationRefusal.reactionStep`; for the wave a Δt making
  C = c · Δt exceed 1/√2 is refused with `a16.unstable` and the sentence of `SimulationRefusal.courant`; a Δt outside
  the family's own range is refused with `a16.invalid-choice` and its range sentence; the automaton refuses the action
  with `a16.invalid-choice` ("The cellular automaton advances one generation per step: its time step must be 1."). An
  accepted Δt replaces the spec's time step, keeps the field, the step count, running and speed (the field is not
  reseeded), and reloads the GPU mirror. The presenter shows the refusal's sentence in the controls' message line
  (`SimulationMirror.message`), which VoiceOver announces; the time step is also stated in the status line. A refusal
  changes nothing.
- Q: Where is the legend drawn and what happens without floating-point targets? → A: The legend is a SwiftUI view
  returned by `makeCanvasOverlay(_:)`: a colour bar of the family's palette with the minimum and maximum of the CPU
  field (the inhibitor v for reaction-diffusion, the value `SimulationPalette` colours; the signed height for the wave), and for the automaton the alive and dead counts;
  the canvas description states the same values. The float probe runs in `setup` for each context generation (a test
  seam forces "unsupported"); without support no GPU field (float or 8-bit) is made for the two families, the family
  control refuses choosing them with `a16.unsupported` and the sentence "Reaction-diffusion and the wave field need
  floating-point render targets, which this device does not offer.", shown in the message line, and a restored state
  in either family is drawn from the CPU upload with that sentence in the status line.

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

- **Long runs:** the GPU field is reloaded from the CPU state every 64 GPU steps so that rounding differences never
  accumulate beyond the tolerance.
- **The automaton:** keeps its exact GPU path from A16-P02; its time step is fixed and `sim.timestep` is refused with
  `a16.invalid-choice` and the one-generation sentence.
- **A time step below the family's range or above 2.0:** refused (`a16.invalid-choice` with the range sentence, or the
  engine's `outOfRange` outside 0.05…2.0); nothing changes.
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
  after every 64 GPU steps, and stepped by the engine's iteration delta otherwise; no pass reads what it writes.
- **FR-A16-310**: The float probe MUST run for each context generation; without support no GPU field (float or 8-bit)
  MUST be made for the two families, choosing them MUST be refused with `a16.unsupported` and the sentence
  "Reaction-diffusion and the wave field need floating-point render targets, which this device does not offer.", and a
  restored state in either family MUST be drawn from the CPU upload with that sentence in the status line.
- **FR-A16-320**: A legend in the canvas overlay MUST show the family's colour bar and the current minimum and maximum
  of the CPU field (the automaton: alive and dead counts), on an opaque panel at the bottom-leading corner of the canvas with
  text in the system caption style (Dynamic Type); the canvas description MUST state the same values, so the legend view
  itself is hidden from VoiceOver.
- **FR-A16-330**: An action `sim.timestep [Δt]` (declared 0.05…2.0) MUST set the time step of reaction-diffusion and the
  wave field, keeping the field, step count, running and speed; Δt above 1.5625 (reaction-diffusion) or making
  C = c · Δt exceed 1/√2 (wave) MUST be refused with `a16.unstable` and the limit's sentence, shown in the message line
  and announced; the automaton MUST refuse it with `a16.invalid-choice`; a refusal changes nothing.
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
