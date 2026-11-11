# Feature Specification: Fluid Art Playground — Phase 02 Core fluid advection and splat injection

**Feature Branch**: `020-fap-p02-advection-splats` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P02 · ID namespace FR-A02-2##, SC-A02-2##, T-A02-2##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 02 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- Gap G-POINTERVEL (per-pointer velocity, multi-touch independence, capped and resampled samples) is built in
  VisualCore's scene-input module.
- Generic exact bilinear sampling (a CPU grid sampler and a shader include) is built in VisualCore, with tests, docs,
  the API baseline and the ProjectM regression (constitution 1.3.0, Principle II).
- The advection and splat equations stay in the app (G-SOLVER), with a CPU reference on 8×8 and 16×16 grids.
- Every gesture has a control alternative.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing delegation (CLAUDE.md §2), recommended option in each case.

- Q: In which units is motion stored, and how does advection trace back? → A: Velocity is stored in grid cells per
  second. Each step samples the source at `cell center − Δt · v` (in cells). The 8-bit fallback encodes velocity with
  range `velocityRange × 60` cells per second (`velocityRange` keeps its Phase 01 meaning of cells per 1/60 s step).
- Q: What exactly does a splat add? → A: With `d` the distance from the splat center in cells (aspect-correct) and
  `r = radius × shorter grid edge`, velocity gains `force · exp(−d²/r²)`, and dye RGB gains `color · exp(−d²/r²)`.
  Dye alpha is unchanged. Half-float dye is not clamped, and the display clamps. 8-bit storage clamps at 1.
- Q: What are the resampling spacing, the caps and the velocity smoothing? → A:
  - Spacing is half the brush radius in view points (`radius × shorter view edge / 2`).
  - At most 16 samples per pointer per update.
  - Velocity is an exponential moving average with α = 0.5 (the first move uses the raw velocity), and samples
    closer than 1 ms reuse the previous velocity.
  - Force in cells per second = finger velocity in points per second × cells per point × `forceScale` (0…4,
    default 1).
  - Per-frame splat cap: 1…64, default 16.
  - Brush radius: 0.005…0.25 of the shorter edge, default 0.04.
- Q: How can GPU interpolation equal the CPU reference when GPU texture filtering uses reduced sub-texel precision?
  → A: Passes do not use hardware filtering for advection. They fetch the four neighboring cells (clamped to the
  edge) and weight them in 32-bit float from the cell coordinate, exactly as the CPU sampler does. Hardware filtering
  is kept only for display scaling.
- Q: In what order does one step apply its passes? → A:
  1. Drain the capped splats.
  2. Splat each into velocity, then into dye.
  3. Advect velocity by itself.
  4. Advect dye by the advected velocity.

  Dissipation is applied inside both advection passes (`× 1/(1 + d·Δt)`). The "Add splash" control queues burst *k*
  at the canvas center with angle `k × 137.5°`, force 600 cells per second and palette color `k mod 6`.

## User Scenarios & Testing *(mandatory)*

Users:
- people who swipe to paint with fluid (manual journey 1, version 0.1 feature 02);
- VoiceOver and Switch Control users, who need a non-gesture way to add dye;
- the implementer of the Phase 03 pressure solver;
- other apps that turn touches into forces (for example A11 Physics Playground, A20 Digital Zen Garden).

### User Story 1 - Swipe to inject dye and motion (Priority: P1) 🎯

On the playground canvas, each finger that moves leaves a trail of colored dye and pushes the fluid in the direction
of the motion. Several fingers work at once and independently. Fast swipes leave a continuous trail, not separate
dots. However many touches arrive, the number of injections per frame is capped, so the canvas stays responsive.

**Why this priority**: It is version 0.1 feature 02 ("multi-touch splat input with capped injection rate and smooth
resampling") and the first real interaction of the app.

**Independent Test**: Feed scripted multi-touch samples to the splat queue. Check:
- the spacing between consecutive splats of one finger;
- that each finger's splats follow only that finger;
- the per-frame cap.

On the GPU, one splat raises the dye and velocity around its center exactly as the CPU reference predicts.

**Acceptance Scenarios**:

1. **Given** a finger moving 200 points in one touch update, **When** the samples are processed, **Then** splats are
   placed along the path with no gap larger than the configured spacing (half the brush radius), up to the
   per-update cap.
2. **Given** two fingers moving in opposite directions, **When** their splats are applied, **Then** each splat's
   force points in its own finger's direction.
3. **Given** more pending splats than the per-frame cap, **When** a frame runs, **Then** at most the cap is applied,
   chosen evenly along each path and including the newest sample. The excess is counted.
4. **Given** a splat, **When** it is applied on the GPU, **Then** dye and velocity match the CPU reference within one
   storage step.

---

### User Story 2 - Dye and motion are carried by the flow (Priority: P1)

After injection, dye drifts with the fluid's motion, and the motion carries itself forward. With no motion, the dye
pattern stays where it is and stays bounded. The same step on the GPU and on the CPU reference agrees on tiny grids.

**Why this priority**: It is the manual's Phase 02 regression fixture ("zero-velocity test keeps a known dye pattern
bounded") and the core of the solver.

**Independent Test**:
- A seeded pattern with zero motion is run for 120 steps.
- A uniform motion field moves a pattern by a known distance.
- Both are run on the GPU and in the CPU reference on 8×8 and 16×16 grids, in both storage formats, on both
  simulator runtimes.

**Acceptance Scenarios**:

1. **Given** a known dye pattern, zero velocity and zero dissipation, **When** 120 steps run, **Then** the dye is
   unchanged within one storage step, never above its initial maximum and never below 0.
2. **Given** a uniform velocity of half a cell per step to the right, **When** 4 steps run, **Then** the pattern
   moves right by 2 cells (with the documented numerical blur), and the GPU matches the CPU reference.
3. **Given** a uniform velocity field, **When** it advects itself, **Then** it stays uniform away from the edges.

---

### User Story 3 - A control alternative to swiping (Priority: P1)

A visible "Add splash" button injects a splash of dye and motion at a deterministic place on the canvas. It is
announced to VoiceOver and works with Switch Control.

**Why this priority**: The constitution's A02 accessibility rule requires a control alternative for every gesture.

**Independent Test**: In a UI test, press the button. The canvas description changes to report the splash, and the
scene receives exactly one splash burst.

**Acceptance Scenarios**:

1. **Given** the playground, **When** the user activates "Add splash", **Then** one deterministic burst is queued
   through the same queue as touches, and VoiceOver announces it.

---

### User Story 4 - Reusable pointer velocity tracking in VisualCore (Priority: P2)

Other apps reuse a tracker that turns raw touch samples into evenly spaced samples with a smoothed velocity per
finger. It keeps up to 10 fingers independent, caps the samples produced per touch update, and ignores invalid
input.

**Why this priority**: It closes G-POINTERVEL from the A02-P00 contract (reuse rule).

**Independent Test**: Host tests of the tracker check:
- resampling spacing;
- velocity from timestamps;
- independence across fingers;
- the cap;
- invalid samples;
- ended and cancelled touches.

The exact bilinear sampler is host-tested on the CPU and on both simulator runtimes in shaders. The documentation
and the API baseline are updated, and the ProjectM regression passes.

**Acceptance Scenarios**:

1. **Given** samples 10 ms apart moving 5 points each, **When** the tracker processes them, **Then** the reported
   velocity converges to 500 points per second.
2. **Given** a sample with a timestamp that does not advance, **When** it arrives, **Then** the position is updated
   and the previous velocity is kept, with no division by zero.

### Edge Cases

- A touch update that jumps very far (for example after a stall): resampling is capped per update and the cap is
  counted. The trail never produces more than the cap in one update.
- More than 10 fingers: the extra fingers are ignored, and the number ignored is counted.
- A cancelled touch (for example a system gesture): that finger's pending samples are discarded, and no splat is
  made from them.
- A splat at the very edge of the canvas: it is clipped by the grid and never samples outside it.
- A velocity above the storable range in 8-bit fallback storage: it is clamped to the range, never wrapped.
- Advection that traces back outside the grid: edge values are used (clamp to edge), never undefined data.
- A non-finite touch location or timestamp: the sample is rejected and counted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-201**: VisualCore MUST provide a pointer velocity tracker. It turns pointer samples into samples
  resampled at a configurable spacing, each with a smoothed velocity per pointer:
  - up to 10 independent pointers;
  - a cap on samples per update, counted;
  - non-finite input rejected and counted;
  - no division by zero.
- **FR-A02-202**: VisualCore MUST provide exact bilinear sampling with clamp-to-edge for CPU grids, and a matching
  shader include, so GPU passes and CPU references compute identical interpolation.
- **FR-A02-203**: The app MUST define a validated splat: position (normalized, with the origin at the bottom left),
  radius, force and color. Out-of-range or non-finite values are clamped or rejected.
- **FR-A02-204**: The app MUST provide a splat queue. It converts tracker samples into splats, with force from the
  finger's velocity and color by finger order, and drains at most the per-frame cap. When over the cap, splats are
  chosen evenly along each path and always include the newest; the excess is counted.
- **FR-A02-205**: The app MUST apply splats to the velocity and dye fields with a Gaussian falloff. The GPU result
  matches the CPU reference within one storage step.
- **FR-A02-206**: The app MUST advect velocity and dye semi-Lagrangian style every step, in the order of clarification
  5, using exact bilinear sampling and clamp-to-edge, with the configured dissipation folded in. The numerical diffusion is documented. The
  GPU matches the CPU reference on 8×8 and 16×16 grids.
- **FR-A02-207**: With zero velocity and zero dissipation, a known dye pattern MUST stay unchanged within one storage
  step and bounded by its initial range for 120 steps (manual regression fixture).
- **FR-A02-208**: The playground MUST turn real multi-touch on the canvas into splats through the VisualCore tracker
  and the app queue. An "Add splash" button MUST provide the same injection without a gesture, with a VoiceOver
  announcement.
- **FR-A02-209**: The configuration MUST gain the splat settings, validated and reported like the existing fields
  (non-finite values become the default):
  - brush radius: 0.005…0.25 of the shorter edge, default 0.04;
  - force scale: 0…4, default 1;
  - per-frame cap: 1…64, default 16.
- **FR-A02-210**: The VisualCore contract MUST be updated: G-POINTERVEL closed, G-SOLVER partially closed (advection
  and splats; the pressure solve remains for Phase 03), M04 and M05 rows updated. The checks MUST pass, including the
  ProjectM regression after the VisualCore change. The app MUST stay offline, request no permissions and keep EGL
  ownership in the VisualCore host.

### Key Entities

- **Pointer sample** (VisualCore): pointer id, position (view points), velocity (points per second), timestamp, phase.
- **Splat** (app): normalized position, radius (fraction of the shorter grid edge), force (grid cells per second),
  RGBA color, timestamp.
- **Splat queue** (app): pending splats per pointer, the per-frame cap, and counters for dropped splats.
- **Fluid configuration** (app): Phase 01 fields plus brush radius, force scale and per-frame splat cap.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-201**: For scripted swipes, 100% of consecutive same-finger splats are at most the configured spacing
  apart (when under the cap). The cap holds in 100% of frames, with the excess counted exactly.
- **SC-A02-202**: The zero-velocity fixture runs 120 steps on 8×8 and 16×16 grids, in both storage formats, on both
  runtimes. The dye stays within one storage step of the initial pattern and inside its initial range.
- **SC-A02-203**: The uniform-advection and splat fixtures match the CPU reference on both grids, both storages and
  both runtimes, within one storage step per step.
- **SC-A02-204**: Tracker host tests cover at least 8 cases: spacing, velocity, independence, cap, invalid input,
  zero time step, end and cancel. All pass.
- **SC-A02-205**: The "Add splash" control is reachable and labelled for VoiceOver (UI test), and the accessibility
  audit finds no new issues on the playground screen.
- **SC-A02-206**: The API review, documented-API check, isolation check, contract check, ProjectM regression (7/7)
  and the app tests on both runtimes all pass.

## Assumptions

- The model is artistic, not physical (constitution A02). Pressure projection, viscosity and boundary modes arrive in
  Phase 03. Pinch to change the brush radius, palettes and capture arrive in Phase 04. Phase 02 uses clamp-to-edge
  everywhere.
- Simulator timing is not evidence. Frame-time budgets come with the quality policy (Phase 03) and campaign II.
- Nothing is persisted in this phase, and the configuration stays at schema version 1 (no stored files exist yet).
- Release items wait for Phase 06. The app stays at version 0.1.0 (1).

## Traceability

| Source | Covered by |
|---|---|
| Brainstorm: "Shader-based advection and diffusion effects" | FR-A02-206, FR-A02-207 |
| Brainstorm: "Touch input as simulation forces" | FR-A02-201, FR-A02-204, FR-A02-205, FR-A02-208 |
| v0.1 feature 02 (multi-touch, capped rate, smooth resampling) | FR-A02-201, FR-A02-204, SC-A02-201 |
| Manual §6 algorithm 1 (semi-Lagrangian advection, documented diffusion) | FR-A02-206 |
| Manual §6 algorithm 3 (clamp Δt, cap splat count) | FR-A02-204, Phase 01 FR-A02-108 |
| Manual §6 render stages 1–3 (drain splats, inject, advect) | FR-A02-204–FR-A02-206 |
| Manual Phase 02 regression fixture | FR-A02-207, SC-A02-202 |
| Contract gaps G-POINTERVEL, G-SOLVER (partial) | FR-A02-201, FR-A02-210 |

## Negative Requirements

- No second renderer, EGL context or direct Metal; no ProjectM linkage.
- No networking, permissions, accounts or persistence.
- No claim of physical accuracy.
- No pass may sample the texture it writes.
- No unbounded touch processing: the samples per update and the splats per frame are capped.
- No gesture without a control alternative.
