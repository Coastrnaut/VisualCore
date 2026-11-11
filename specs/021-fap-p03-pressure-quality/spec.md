# Feature Specification: Fluid Art Playground — Phase 03 Pressure projection and quality control

**Feature Branch**: `021-fap-p03-pressure-quality` (spec directory only; work stays on `main`)

**Created**: 2026-11-11

**Status**: Draft

**Ledger gate**: A02-P03 · ID namespace FR-A02-3##, SC-A02-3##, T-A02-3##

**Input**: User description: archived manual `apps/02-fluid-art-playground.md` §9 Phase 03 `/speckit-specify` prompt
(verbatim in the invocation).

Canonical overrides:
- Gap G-QUALITY (quality tiers stepped by thermal state and Low Power Mode, with hysteresis) is built in VisualCore,
  with tests, docs, the API baseline and the ProjectM regression (constitution 1.3.0, Principle II).
- The divergence, Jacobi pressure, projection, viscosity and boundary equations stay in the app (G-SOLVER), with a
  CPU reference on 8×8 and 16×16 grids.
- Controls are native and accessible.
- Evidence is host and simulator only.

## Clarifications

### Session 2026-11-11

Answered autonomously under the owner's standing delegation (CLAUDE.md §2), recommended option in each case.

- Q: Which discrete equations define divergence, pressure and projection? → A: The grid is cell-centered with a cell
  size of 1.
  - Divergence: `d = 0.5·((u_R − u_L) + (v_T − v_B))`.
  - Pressure starts at 0 every step (stateless and deterministic) and runs N Jacobi iterations of
    `p' = (p_L + p_R + p_B + p_T − d) / 4`.
  - Projection: `u −= 0.5·(p_R − p_L)` and `v −= 0.5·(p_T − p_B)`.

  Neighbors outside the grid:
  - Pressure uses the center value (zero normal gradient) in both modes.
  - Velocity, with walls: the center cell with its normal component negated. Open: the center cell unchanged.
  - Walls also set the normal component of the edge cells to 0 after projection.
- Q: How are the new scalar fields stored, including the 8-bit fallback? → A: Divergence and pressure use the same
  storage as the velocity, in the R channel. In 8-bit fallback storage they use `SignedRangeEncoding.unorm8`, with
  ranges of 2 × and 4 × the velocity range (cells/s and cells²/s). Values beyond are clamped, never wrapped, and the
  CPU reference models the same encoding.
- Q: How is viscosity applied? → A: Implicit diffusion with `ν = viscosity × 50` cells² per second and 8 fixed Jacobi
  iterations of `x' = (x_L + x_R + x_B + x_T + α·b) / (4 + α)`, with `α = 1/(ν·Δt)`, using the same neighbor rules
  as the velocity. It is skipped at viscosity 0.
- Q: What are the quality policy's rules? → A:
  - Tiers are ordered best first.
  - A decision is at most every 2 s (the decision interval).
  - A serious or critical thermal state, or Low Power Mode above its ceiling, steps one tier down per decision.
  - Stepping up one tier requires 10 s of calm (a nominal or fair thermal state and no Low Power Mode).
  - The Low Power ceiling is the second tier, and the floor is the last tier.

  The app's tiers are:
  - **Full**: the user's iterations and splat cap.
  - **Reduced**: half the iterations, at least 1.
  - **Minimal**: a quarter of the iterations, at least 1, and half the splat cap.

  The panel shows "Quality: <tier> (automatic)".
- Q: In what order does one step run now, and what is the default edge mode? → A:
  1. Splats.
  2. Advect velocity.
  3. Viscosity.
  4. Divergence.
  5. Pressure.
  6. Gradient subtraction and the walls rule.
  7. Advect dye by the projected velocity.

  The default edge mode is walls. Phase 02 fixtures keep their meaning: their CPU references move to the full-step
  reference (`FluidSolver.step`), and uniform-motion fixtures use open edges.

- Q: (found during implementation, T-A02-304) Is "at least 50% less divergence at the default 20 iterations"
  achievable? → A: No, and the threshold was set before measuring. The CPU reference on the 16×16 splat fixture gives
  interior |div| 3529 → 2874 / 2441 / 1921 / 1431 at 5 / 10 / 20 / 40 iterations: always decreasing, with 45.6% at
  20 iterations.

  This is a property of the standard artistic scheme: Jacobi uses the narrow 5-point Laplacian, while divergence and
  gradient use central differences, so central-difference divergence is never fully removed. Neither the default
  (20, cost-bounded) nor the scheme changes. SC-A02-302 now requires a strict decrease and ≥ 40% at 20 iterations,
  with the measured values recorded.

## User Scenarios & Testing *(mandatory)*

Users:
- people tuning how the fluid feels (manual journey 2, version 0.1 feature 03);
- people on hot or Low Power devices, who need the app to stay responsive (manual §12: "reduce pressure iterations
  before reducing touch responsiveness");
- the implementer of later phases;
- other apps that scale work by device state (for example A16 Simulation Lab, A24 Graphics Benchmark Lab).

### User Story 1 - The fluid swirls instead of spreading (Priority: P1) 🎯

After a swipe, the fluid forms swirls and stays roughly incompressible. Motion pushed into one place pushes the fluid
around it instead of piling up. More pressure iterations make the motion more incompressible.

**Why this priority**: It completes the solver of the manual's render sequence (divergence, pressure, projection).

**Independent Test**: On 8×8 and 16×16 grids, in both storage formats and on both runtimes:
- the GPU divergence, pressure iterations and gradient subtraction equal the CPU reference;
- after projection, the remaining divergence of a test field is clearly smaller than before, and it shrinks further
  as the iteration count rises.

**Acceptance Scenarios**:

1. **Given** a velocity field with divergence, **When** it is projected with N pressure iterations, **Then** the GPU
   result matches the CPU reference within the stated tolerance, and the remaining divergence is lower than before.
2. **Given** more iterations, **When** the same field is projected, **Then** the remaining divergence does not
   increase.
3. **Given** a divergence-free field (uniform motion with open boundaries), **When** it is projected, **Then** it is
   unchanged within one storage step.

---

### User Story 2 - Edges behave predictably (Priority: P1)

The user chooses how the canvas edges behave: **walls**, where fluid slides along the edge and cannot leave, or
**open**, where fluid and dye flow out. No mode ever reads outside the grid.

**Why this priority**: It is the manual's Phase 03 regression fixture ("boundary modes have fixture tests and no
out-of-bounds sampling").

**Independent Test**: For each boundary mode, fixtures on 8×8 and 16×16 compare the GPU and the CPU reference near
the edges. With walls, the velocity across a wall is zero after projection. Probes confirm that every neighbor lookup
stays inside the grid.

**Acceptance Scenarios**:

1. **Given** walls and motion toward the left edge, **When** a step runs, **Then** the velocity component through the
   wall at the edge cells is zero within one storage step.
2. **Given** open edges and the same motion, **When** a step runs, **Then** fluid keeps flowing out (the edge cells
   keep their outward velocity).
3. **Given** any mode, **When** any pass runs, **Then** it reads only cells inside the grid.

---

### User Story 3 - Adjust viscosity, dissipation and quality (Priority: P1)

An "Adjust" panel offers sliders for viscosity, dye fading, motion fading and solver quality (pressure iterations),
and a choice of edge mode. The effective value of each control is shown and announced. Changes apply immediately
without losing the current picture. A reset returns every value to its default.

**Why this priority**: It is version 0.1 feature 03 and manual journey 2.

**Independent Test**: In a UI test, open Adjust, change each control and reset. The values shown and spoken match the
configuration the scene uses, and the dye is not cleared. In unit tests, a change of viscosity, dissipation,
iterations or edge mode reaches the next step without a rebuild.

**Acceptance Scenarios**:

1. **Given** the playground, **When** the user moves the quality slider, **Then** the pressure iterations used by the
   next step equal the value shown, and the dye picture is kept.
2. **Given** a non-default configuration, **When** the user taps Reset, **Then** every control returns to its default.
3. **Given** VoiceOver, **When** the user focuses a slider, **Then** it announces its name, value and unit, and can be
   adjusted with swipe up and down.

---

### User Story 4 - Stay responsive when the device is hot or saving power (Priority: P2)

When the device reports a serious or critical thermal state, or Low Power Mode, the app automatically lowers solver
quality: first fewer pressure iterations, then fewer splats per frame. It never ignores touches. When conditions
recover and stay calm for a while, quality steps back up. The user can see the current quality level.

**Why this priority**: Closes G-QUALITY. Manual §12: degrade iterations before touch responsiveness.

**Independent Test**: Host tests of the VisualCore quality policy:
- tier stepping on thermal and Low Power inputs;
- hysteresis on recovery;
- a never-below-minimum floor;
- deterministic decisions for a scripted sequence of states.

The app maps tiers to iterations and splat cap, which unit tests verify.

**Acceptance Scenarios**:

1. **Given** the nominal state at the top tier, **When** the thermal state becomes serious, **Then** the next decision
   is one tier lower.
2. **Given** a lowered tier, **When** the state returns to nominal, **Then** quality steps up only after the calm
   period has passed, one tier at a time.
3. **Given** Low Power Mode, **When** decisions are made, **Then** the tier never exceeds the configured Low Power
   ceiling.

### Edge Cases

- Zero pressure iterations requested: clamped to the minimum (1) and reported.
- A quality tier change mid-stroke: iterations and splat cap change on the next frame; the touch queue is kept.
- The thermal state flips rapidly: hysteresis prevents oscillating up and down; at most one step per decision
  interval.
- A grid with edges of 8 cells (the smallest): boundary handling still reads only inside cells.
- Viscosity 0: the viscosity passes are skipped (no change to the field).
- The edge mode changes while fluid is moving: it applies from the next step without a rebuild.
- An 8-bit storage fallback: pressure, divergence and velocity are stored with their documented ranges and never wrap.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-A02-301**: The app MUST compute the velocity divergence, solve pressure with a configurable number of Jacobi
  iterations, and subtract the pressure gradient. GPU results match a CPU reference on 8×8 and 16×16 grids, in both
  storages, within the stated tolerance.
- **FR-A02-302**: Projection MUST reduce divergence. With more iterations, the remaining divergence of a fixture field
  MUST NOT increase.
- **FR-A02-303**: The app MUST support two boundary modes, walls and open, applied consistently in divergence,
  pressure, gradient and advection. No pass reads outside the grid in either mode.
- **FR-A02-304**: The app MUST apply viscosity as implicit diffusion of velocity (skipped at viscosity 0). The GPU
  matches the CPU reference.
- **FR-A02-305**: The configuration MUST gain the boundary mode (walls by default). Viscosity and pressure iterations, stored since
  Phase 01, are now used. All values are validated and reported as before.
- **FR-A02-306**: An accessible Adjust panel MUST let users change viscosity, dye dissipation, velocity dissipation,
  pressure iterations and the boundary mode, and reset to defaults. Each control shows and announces its effective
  value and unit. Changes apply on the next step without a field rebuild.
- **FR-A02-307**: VisualCore MUST provide a quality policy, with tests, docs, the API baseline and a passing ProjectM
  regression:
  - an ordered list of tiers;
  - step down on serious or critical thermal state or Low Power Mode;
  - step up one tier after a calm period;
  - a Low Power ceiling;
  - at most one change per decision interval.
- **FR-A02-308**: The app MUST map quality tiers to pressure iterations and splat cap, lowering iterations before the
  splat cap, feed the policy from the system thermal state and Low Power Mode, and show the current tier.
- **FR-A02-309**: The VisualCore contract MUST be updated:
  - G-QUALITY closed;
  - G-SOLVER closed (with advection from Phase 02, the solver is complete);
  - M07 and M04 rows updated.

  The checks MUST pass. The app MUST stay offline, request no permissions, store nothing and keep EGL ownership in the
  VisualCore host.

### Key Entities

- **Boundary mode** (app): walls or open.
- **Quality tier** (VisualCore, generic): a named level. Its parameters are set by each app; for this app they are
  pressure iterations and the splat cap.
- **Quality policy** (VisualCore): the ordered tiers, the current tier, the calm-period timer, the Low Power ceiling
  and the decision interval.
- **Pressure and divergence fields** (app): one scalar per cell, the same storage as the velocity.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-A02-301**: Projection fixtures on 8×8 and 16×16, in both storages and on both runtimes, match the CPU reference
  within the stated tolerance.
- **SC-A02-302**: For the splat fixture field, the remaining divergence falls by at least 40% with the default 20
  iterations (measured 45.6%), and decreases as the iterations go 5, 10, 20, 40 (CPU reference; clarification 6).
- **SC-A02-303**: The boundary fixtures for walls and open on both grids: under walls, the velocity through each wall
  is within one storage step of 0, and 0 out-of-grid reads are recorded by the boundary probes.
- **SC-A02-304**: The quality policy host tests cover at least 8 scripted cases, including oscillation, the Low Power
  ceiling, the floor and the calm-period recovery. All pass.
- **SC-A02-305**: The Adjust UI test changes every control and resets it. The accessibility audit (default size and
  XXXL) finds no new issues.
- **SC-A02-306**: The API review, documented-API, isolation and contract checks, the ProjectM regression (7/7) and the
  app tests on both runtimes all pass.

## Assumptions

- The model is artistic, not physical (constitution A02). The tolerances and divergence reductions are fixture
  properties, not claims of physical accuracy.
- Grid resolution changes for quality ("configurable simulation resolution with thermal downgrade", feature 06) are
  outside this phase. Tiers adjust iterations and splat cap only. Resolution tiers arrive with Phase 05's device
  stress tests.
- Thermal states and Low Power Mode come from public system APIs (`ProcessInfo`). Simulator evidence uses injected
  states. Real thermal behavior is a campaign II measurement.
- Nothing is persisted. The Adjust values reset when the screen closes (persistence arrives in Phase 04 or 05).
- The configuration stays at schema version 1 (no stored files exist).
- Automatic quality changes are shown, not announced. The Adjust panel's tier label reflects the current tier, and
  VoiceOver reads it on focus. Announcing every thermal step would interrupt the user for something they cannot act
  on.
- The quality policy starts at the best tier each time the playground opens and is reset when the screen closes, like
  the other Adjust values.

## Traceability

| Source | Covered by |
|---|---|
| Brainstorm "GPU simulation techniques" / manual §6 algorithm 2 (divergence, Jacobi pressure, projection) | FR-A02-301, FR-A02-302 |
| v0.1 feature 03 (viscosity, dissipation, pressure iteration quality) | FR-A02-304–FR-A02-306 |
| Manual Phase 03 regression fixture (boundary modes, no out-of-bounds sampling) | FR-A02-303, SC-A02-303 |
| Manual §12 (degrade iterations before touch responsiveness) | FR-A02-307, FR-A02-308 |
| Manual journey 2 (switch viscosity; reset) | FR-A02-306 |
| Contract gaps G-QUALITY, G-SOLVER | FR-A02-307, FR-A02-309 |

## Negative Requirements

- No second renderer or EGL context, no ProjectM linkage, no networking, permissions or persistence.
- No claim of physical accuracy.
- No out-of-grid reads, and no pass sampling its own output.
- Quality changes never drop or delay touch handling beyond the splat cap; the queue is never cleared by a tier
  change.
- No hidden quality changes: the current tier is visible.
- Thermal state and Low Power Mode are read locally from the system, used only for the current decision, and never
  stored or transmitted.
