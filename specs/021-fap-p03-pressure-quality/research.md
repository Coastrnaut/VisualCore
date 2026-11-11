# Research: Fluid Art Playground — Phase 03

## R1 Where QualityPolicy lives

- **Decision**: in `VisualCoreDiagnostics/QualityPolicy.swift`, next to `FramePacing`, using `FramePacing.Thermal`.
- **Rationale**: `VisualCoreSimulation` depends only on `VisualCoreMath`. Using `Thermal` there would add a module
  dependency (R1–R5 review). Thermal and power policy is a diagnostics and pacing concern. The contract gap
  G-QUALITY's owner is updated, with this justification.
- **Alternatives**: an `Int` thermal level in Simulation (loses type safety); app-local (violates reuse; A16 and A24
  need it).

## R2 Policy semantics

- **Decision**: `QualityPolicy(tierCount:lowPowerCeiling:decisionInterval:calmPeriod:)`.
  - `decide(thermal:lowPower:now:) -> Int` returns the tier index (0 = best).
  - Down steps happen when thermal ≥ serious, or when Low Power Mode is on and the tier is above the ceiling.
  - Up steps happen after `calmPeriod` of a calm state.
  - At most one change per `decisionInterval`.
  - Counters record the changes.
- **Rationale**: deterministic, with time injected so host tests are exact; hysteresis avoids oscillation.

## R3 Projection discretization

As in spec clarification 1 (central differences, stateless Jacobi starting at 0). The CPU and GPU use the same
operation order: the GPU fragment computes `(pL + pR + pB + pT − d) * 0.25` in this order, and the CPU matches it.

## R4 Boundary rules on the GPU

- **Decision**: shaders fetch neighbors through `vc_fieldTexel` (clamped). For velocity under walls, when the
  neighbor index is outside the grid, the shader takes the center value and negates the normal component. A
  `uWalls` uniform selects the mode.
  - The divergence and gradient passes run per cell with explicit `i == 0` and `i == W−1` tests.
  - The walls rule zeroes the normal component of edge cells inside the gradient pass.
  - Advection keeps clamp sampling: under walls the edge velocity is already 0 after projection, so nothing crosses.
- **Out-of-bounds probe**: a CPU `FieldAccessLog` in the reference records every index it reads. The GPU uses only
  clamped fetches (by construction) plus explicit edge branches, and the fixtures compare edges exactly.

## R5 Viscosity

The implicit Jacobi of clarification 3, with `b` = the velocity before diffusion. Each of the 8 iterations ping-pongs
through a scratch pair, so `b` stays readable as a separate input.

## R6 Scalar fields in 8-bit storage

Divergence and pressure use `SignedRangeEncoding.unorm8` with ranges of 2× and 4× the velocity range. The CPU
reference rounds through the same encoding after every pass (precision-matched, as in Phases 01–02).

## R7 Live configuration

`FluidFieldsScene.update(configuration:)` validates it with the current grid (grid fields are ignored), stores it, and
applies it from the next frame. `PlaygroundModel` forwards Adjust changes. Defaults come from `FluidConfiguration()`.

## R8 Fixture tolerance

The tolerance is one storage step per stored pass. Projection with N iterations stores N + 3 times, so the tolerance
is `(N + 3) × step`, with relative half precision for large values. In practice, Phases 01–02 matched exactly. The
reports print the observed maximum.
