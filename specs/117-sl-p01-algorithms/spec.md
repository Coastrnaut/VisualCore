# Feature Specification: Simulation Lab — Phase 01 Algorithm specifications and CPU fixtures

**Feature Branch**: `117-sl-p01-algorithms` (spec directory only; work stays on `main`)

**Created**: 2026-11-16

**Status**: Draft

**Ledger gate**: A16-P01 (legacy ledger) · ID namespace FR-A16-1##, SC-A16-1##, T-A16-1##

**Input**: User description: archived manual `apps/16-simulation-lab.md` §9 Phase 01 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- **Phase gates (manual §9 Phase 01):** MVP — three simulation families: cellular automata, reaction-diffusion and a 2D
  wave field; regression fixture — the Life blinker oscillator has a known two-step period; graphics context ownership
  stays solely in the audited VisualCore host.
- **Gaps built here** (contract `docs/apps/simulation-lab/visualcore-contract.json`): G-RULES (the three CPU references
  with their boundary rules), G-SPEC (the versioned simulation spec, parameter definitions, seeded starts and stability
  limits) and G-SCHEDULER (run, pause, single step, reset and speed). GPU passes come in A16-P02 and A16-P03.
- **Experience:** Simulation Lab becomes a registered candidate (not yet available) that draws the CPU field through
  the one host's drawing path; no placeholder.
- **Owner rulings:** short tests; audits and device runs in the device campaign; iOS 27 at phase gates; reference
  regression and iOS 26 at X-A16; every Spec Kit step runs. Follow `specs/110-me-p01-domain-parser`.

## Clarifications

### Session 2026-11-16

Answered autonomously under the owner's standing delegation, recommended option each time. Facts checked in code:
`VisualCoreParameters` `ParameterDefinition` (name, title, unit, minimum, maximum, …) and `ParameterError`;
`VisualCoreSimulation` `SeededRandom(seed:)` over `SplitMix64`, `FieldGrid` with `StoragePrecision` (float32, float16,
float16TowardZero, unorm8), `TimeStepPolicy`, `PlaybackState`, `FixedStepClock` and `FixedStepRunner`; `VisualCoreMath`
`NumericHygiene`; the engine steps a core at its declared `stepDuration` (brought into 1/240…1/30 s) with at most 8 host
steps per frame (`ExperienceEngine`); `Texture.upload(rgba:)` writes RGBA8 pixels (`GPUObjects.swift`).

- Q: What is the cellular-automaton rule? → A: Two states on a square grid, the eight-cell (Moore) neighbourhood and an
  outer-totalistic birth/survival rule written B…/S…, with a wrap boundary; presets Life B3/S23 (default), HighLife
  B36/S23 and Seeds B2/S; the start is a seeded fill with density 0.25 through `SeededRandom`; storage `unorm8` (exact
  0 and 1).
- Q: What are the Gray-Scott equations and limits? → A: u′ = u + Δt (Dᵤ∇²u − uv² + F(1 − u)), v′ = v + Δt (Dᵥ∇²v + uv²
  − (F + k)v), ∇² the five-point stencil (four neighbours minus four times the centre, cell spacing 1), wrap boundary,
  Dᵤ = 0.16, Dᵥ = 0.08, default Δt = 1.0; stability bound Δt · 4 · max(Dᵤ, Dᵥ) ≤ 1 (Δt ≤ 1.5625), larger Δt refused;
  F and k each in 0…0.1 (presets Spots F 0.035, k 0.065 and Mazes F 0.029, k 0.057); after each step u and v are
  clamped to 0…1 and rounded to `float16`; the start is u = 1, v = 0 with six seeded 4 × 4 patches of u = 0.5, v = 0.25.
- Q: What is the wave scheme and its limit? → A: Leapfrog uⁿ⁺¹ = (2uⁿ − uⁿ⁻¹ + C²∇²uⁿ)(1 − γ) with Courant number
  C = c · Δt / Δx (Δx = 1), the five-point stencil and a fixed zero border; stability C ≤ 1/√2 (≈ 0.7071), larger C
  refused with the sentence "The wave step is too large: the Courant number must stay at or below 0.707."; defaults
  c = 1, Δt = 0.5 (C = 0.5), damping γ in 0…0.05 (default 0.002); the start is a Gaussian pulse (σ = 3 cells, amplitude
  1) at a seeded position; storage `float16`. "Energy does not grow" means the discrete leapfrog energy Σ(uⁿ⁺¹ − uⁿ)² +
  C² Σ over neighbour pairs (uⁿ⁺¹ᵢ − uⁿ⁺¹ⱼ)(uⁿᵢ − uⁿⱼ) stays within 10⁻³ of its start (relative) with γ = 0 on the
  CPU in `float32`, and never increases with γ > 0.
- Q: What are the grid sizes and the speed rule? → A: Grid sizes 16, 32, 64, 128 or 256 cells per side; the experience
  runs 64 × 64 on the CPU in this phase (larger sizes need the GPU passes of A16-P02 and A16-P03 and are refused here);
  the core's step is 1/60 s; speed is one of 0.25, 0.5, 1, 2 or 4 times the family's base rate (automata 10, reaction-
  diffusion 240, wave 120 iterations per second); whole iterations are run per host step, at most 16, and a remainder
  beyond the cap is dropped, never carried into a burst.
- Q: What does the saved state hold? → A: The spec, the scheduler (running, speed, step count) and the field itself
  (the storage bit patterns of each channel, as base64), at most 1,048,576 bytes; a restore checks the spec, the sizes
  and every value (finite, within range) and refuses otherwise, so replay never has to re-run thousands of steps.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch three kinds of simulation (Priority: P1) 🎯

A person opens Simulation Lab, sees a cellular automaton evolving, and switches to reaction-diffusion and to a wave
field, each starting from the same seeded picture every time.

**Why this priority**: the phase's MVP and the v0.1 feature "three simulation families".

**Independent Test**: open the experience; choose each family; read the canvas description and compare frames.

**Acceptance Scenarios**:

1. **Given** the experience, **When** it opens, **Then** a seeded cellular automaton is drawn and its description
   names the family, the rule, the grid size and the step count.
2. **Given** each family, **When** it is chosen, **Then** its seeded field is drawn and differs from the other
   families' fields.
3. **Given** the same family and seed, **When** it is opened twice, **Then** the drawn field and the state digest are
   identical.

---

### User Story 2 - Pause, step and reset exactly (Priority: P1)

A person pauses a simulation, advances it by exactly one step at a time, changes its speed and resets it to the seeded
start.

**Why this priority**: the v0.1 feature "pause, reset, step, speed" and the manual's fixture "pause and one-step advance
exactly one discrete iteration".

**Independent Test**: pause, step once, compare with one CPU step; reset; set the speed above the cap.

**Acceptance Scenarios**:

1. **Given** a paused simulation, **When** one step is asked, **Then** the step count grows by exactly one and the field
   equals one reference step.
2. **Given** a running simulation, **When** reset is asked, **Then** the field and step count return to the seeded start.
3. **Given** any speed request, **Then** no more than the stated cap of steps runs in one frame, even after a long gap.

---

### User Story 3 - Trustworthy reference rules (Priority: P1)

The engineer can trust each algorithm's CPU reference: the Life blinker repeats every two steps, a glider wraps across
the edge, Gray-Scott matches a hand-computed step, and the wave stays symmetric and bounded below its stability limit.

**Why this priority**: the phase's regression fixture and the manual's algorithm decisions 1–4.

**Independent Test**: run the fixture grids; compare with known values.

**Acceptance Scenarios**:

1. **Given** a blinker, **When** two steps run, **Then** the grid equals the start, and after one step it differs.
2. **Given** a Gray-Scott grid, **When** one step runs, **Then** each cell equals the hand-computed value within the
   storage rounding, and all values stay finite and within 0…1.
3. **Given** a centred wave pulse below the stability limit, **When** steps run, **Then** the field stays symmetric, is
   zero on the boundary and its energy does not grow.

---

### User Story 4 - Invalid settings are explained (Priority: P2)

A person (or a saved state) asking for a time step beyond the stability limit, an out-of-range parameter or a
non-finite value is refused or clamped with a visible explanation, and the field is never corrupted.

**Why this priority**: the manual's fixture "invalid time steps rejected or clamped with visible explanation".

**Independent Test**: send each invalid setting; read the explanation; compare the state.

**Acceptance Scenarios**:

1. **Given** a wave time step above the Courant limit, **When** it is asked, **Then** it is refused with a sentence
   naming the limit and nothing changes.
2. **Given** an out-of-range feed or kill value, **When** it is asked, **Then** it is refused with its range and nothing
   changes.

### Edge Cases

- **A saved state of an unknown kind, boundary, version or grid size:** refused; the experience opens its seeded start.
- **A seed of zero or the largest value:** gives a valid, deterministic start.
- **A grid with no live cells (automaton):** stays empty; the description says so.
- **Values drifting outside 0…1 (reaction-diffusion):** clamped by the storage rounding; non-finite values never appear.
- **Switching family while paused:** the new family opens at its seeded start, paused.
- **Very long frame gap:** no catch-up burst beyond the per-frame cap.
- **Context loss:** the CPU field is the truth; the drawing is rebuilt from it.

## Requirements *(mandatory)*

### Functional Requirements

**Rules (story 3)**

- **FR-A16-101**: The cellular automaton MUST use a stated neighbourhood and birth/survival rule with a wrap boundary;
  the Life blinker MUST have period two and a block MUST be still.
- **FR-A16-102**: Reaction-diffusion MUST follow the Gray-Scott equations with a stated Laplacian stencil, diffusion
  constants, feed and kill, a wrap boundary and storage rounding; one step MUST match a hand-computed value.
- **FR-A16-103**: The wave field MUST use a bounded explicit scheme with a fixed zero boundary and a stated stability
  (Courant) limit; below the limit a centred pulse MUST stay symmetric and its energy MUST not grow.

**Spec and safeguards (story 4)**

- **FR-A16-110**: A versioned simulation spec MUST hold the kind, grid size, time step, boundary rule, seed, parameter
  values and algorithm version, and MUST refuse unknown versions, kinds, boundaries and grid sizes.
- **FR-A16-111**: Every parameter MUST have a definition with units, range and description; out-of-range, non-finite
  or unstable values MUST be refused with a visible explanation and change nothing.
- **FR-A16-112**: The same seed MUST give the same starting field and digest.

**Scheduler (story 2)**

- **FR-A16-120**: Run, pause, single step (exactly one iteration), reset (to the seeded start) and speed (steps per
  frame within a cap) MUST be engine actions; no frame runs more than the cap.

**Experience (story 1)**

- **FR-A16-130**: The experience MUST draw the current CPU field through the one host's drawing path with a family
  palette and a canvas description naming the family, rule or preset, grid size and step count; changing the family
  MUST change the drawn pixels and the description.
- **FR-A16-131**: The experience MUST be registered as a candidate with a scenario manifest (standard scenarios and one
  fixture per family) and pass the runner's standard scenarios on iOS 27.

### Key Entities

- **Simulation spec**: kind, grid size, time step, boundary, seed, parameter values, algorithm version.
- **Parameter definition**: id, units, range, description, default.
- **Field**: one or two channels of grid size × grid size values, rounded to the storage precision.
- **Scheduler state**: running or paused, step count, steps per frame.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A16-101**: The blinker equals its start after exactly 2 steps and differs after 1; a block is unchanged after 10.
- **SC-A16-102**: The Gray-Scott step matches the hand-computed values in 100 % of cells within one storage step.
- **SC-A16-103**: Over 100 wave steps at C = 0.5 the pulse stays mirror-symmetric and the discrete energy stays within
  10⁻³ of its start with no damping; a Courant number 1 % above 0.7071 is refused.
- **SC-A16-104**: 100 % of invalid settings are refused with an explanation and leave the digest unchanged.
- **SC-A16-105**: The runner's standard scenarios pass on iOS 27; every test runs in under 10 s.

## Assumptions

- VisualCore provides the CPU field grid with storage precision, a seeded random generator, numeric hygiene, a time-step
  policy, playback and a fixed-step runner, render targets, textures with upload, and the experience host; the audit of
  A16-P00 recorded them. No VisualCore change is planned.
- The grid drawn in this phase is small enough for the CPU to step every frame; GPU passes come later.

## Traceability

| Source | Requirement |
|---|---|
| Phase 01 MVP: three families | FR-A16-101–103, 130 |
| Regression fixture: Life blinker period two | FR-A16-101, SC-A16-101 |
| Algorithm decisions 1–4 (rule and boundary, stencil and stability, Courant, CPU reference) | FR-A16-101–103, 111 |
| v0.1: parameter schema and seeded starts | FR-A16-110–112 |
| v0.1: pause, reset, step, speed | FR-A16-120 |
| Contract gaps G-RULES, G-SPEC, G-SCHEDULER | FR-A16-101–120 |
| EGL/context ownership in the VisualCore host | FR-A16-130 |

## Negative Requirements

- No GPU simulation pass yet; no claim of scientific accuracy; no network or permission; no change to VisualCore; no
  drawing that changes the state; no images.
