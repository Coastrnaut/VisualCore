# Implementation Plan: Fluid Art Playground — Phase 03 Pressure projection and quality control

**Branch**: `021-fap-p03-pressure-quality` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P03

## Summary

This phase completes the solver: viscosity, divergence, Jacobi pressure and gradient subtraction, with walls and open
boundary modes. The GPU must equal a CPU reference (`FluidSolver`) on 8×8 and 16×16 grids in both storages. An
accessible Adjust panel changes viscosity, dissipation, iterations and edge mode live. Automatic quality comes from a
new reusable VisualCore `QualityPolicy` (G-QUALITY), which lowers pressure iterations first and then the splat cap.

## Technical Context

**Language/Version**: Swift 6.4.2, GLSL ES 3.00.

**Primary Dependencies** (all verified in code at A02-P02):
- VisualCoreDiagnostics: `FramePacing.Thermal`.
- VisualCoreRendering: `PingPongTarget`, `FieldPass` (`library:`), `vc/field.glsl`, `FloatRenderSupport`,
  `RenderHost`, `ResourceRegistry.maxTextureSize`.
- VisualCoreUI: `RenderSurface`, `AccessibleColors`, `contentSwipeBackDisabled()`.
- VisualCoreSimulation: `FieldGrid`, `StoragePrecision`, `SignedRangeEncoding.unorm8`, `TimeStepPolicy`.
- System: `ProcessInfo.thermalState`, `isLowPowerModeEnabled` and their change notifications. These are public APIs,
  already used by `FrameScheduler`.

**Storage**: None.

**Testing**: host `swift test` (VisualCore, FluidArtPlaygroundCore); app unit and UI tests on iOS 27.2 and 26.5 with
the enumeration guard; the ProjectM regression after the VisualCore change.

**Target Platform**: iOS/iPadOS 26.0+.

**Performance Goals**: no simulator budget. The worst per-frame pass count at the default 20 iterations is 16 splats
× 2 + 2 advect + 8 viscosity + 1 divergence + 20 pressure + 1 gradient + 1 display = 65. Quality tiers reduce the 20
iterations.

**Constraints**: no out-of-grid reads (`vc_fieldTexel` clamps and the boundary rules are explicit); no pass samples
its output; offline; no EGL in the app.

**Scale/Scope**: VisualCore gets 1 new type (`QualityPolicy`). App Core gets 3 files (`BoundaryMode` in the
configuration, `FluidSolver`, `FluidQuality`). The app gets 4 shaders, the scene pipeline, an Adjust panel and quality
wiring. About 8 new test classes.

## Constitution Check

| Principle / rule | Compliance | Status |
|---|---|---|
| I. Proven renderer only | All passes are `FieldPass` on `RenderHost`. | PASS |
| II. Reuse first | `QualityPolicy` is generic and lives in VisualCoreDiagnostics, next to `FramePacing`, whose `Thermal` it consumes. This is a change of owner from the contract's VisualCoreSimulation, which would need a new module dependency (research R1). The solver equations stay in the app (A02). | PASS |
| II-a. Preserve reference | The ProjectM regression runs after the VisualCore change. | PASS (planned) |
| III. GPU lifecycle | The pressure and divergence targets are created in setup and released in teardown, and rebuilt on context loss. | PASS |
| IV. Host-testable, test first | Solver, quality and configuration tests on the host first. | PASS |
| V/VI. Evidence | Simulator and host only, run-check and the guard. | PASS |
| VII. Accessible UI | Native sliders and a picker with values and units, the audit at default size and XXXL. | PASS |
| VIII. Public APIs, privacy | `ProcessInfo` only; no permissions. | PASS |
| IX. Bounded input | Iterations 1…80, viscosity 0…1, edge-mode enum, tiers bounded. | PASS |
| A02 Bounded GPU | Iteration caps, quality degradation, clamp/walls rules, guard. | PASS |

## Project Structure

```text
Packages/VisualCore/Sources/VisualCoreDiagnostics/QualityPolicy.swift               # NEW
Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/QualityPolicyTests.swift       # NEW
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/
├── FluidConfiguration.swift   # EDIT boundaryMode (walls default), BoundaryMode enum
├── FluidSolver.swift          # NEW divergence, Jacobi pressure, gradient, walls rule, viscosity, full step
└── FluidQuality.swift         # NEW tiers Full/Reduced/Minimal → iterations and splat cap
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Package.swift   # EDIT + VisualCoreDiagnostics (QualityPolicy)
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Tests/FluidArtPlaygroundCoreTests/
└── FluidSolverTests.swift, FluidQualityTests.swift, FluidConfigurationTests.swift (EDIT)
Apps/FluidArtPlayground/App/
├── FluidShaders.swift         # EDIT divergence, pressure, gradient, diffuse fragments; advect with edge rules
├── FluidFieldsScene.swift     # EDIT pressure/divergence pairs, full pipeline, live configuration update
├── PlaygroundView.swift       # EDIT Adjust button and sheet, quality wiring
└── AdjustPanel.swift          # NEW accessible controls
Apps/FluidArtPlayground/Tests/Unit/ProjectionFixtureTests.swift, BoundaryFixtureTests.swift, QualityWiringTests.swift  # NEW
Apps/FluidArtPlayground/Tests/Unit/{Splat,Advection}FixtureTests.swift   # EDIT references → FluidSolver.step
Apps/FluidArtPlayground/Tests/UI/AdjustUITests.swift                     # NEW; audit test gains the Adjust sheet
docs/apps/fluid-art-playground/visualcore-contract.{json,md}, regression-baseline.md   # EDIT
```

## Frame contract

Each frame in order:
1. clamp Δt;
2. drain splats under the tier's cap;
3. splat velocity and dye;
4. advect velocity;
5. diffuse (8 iterations if ν > 0);
6. compute divergence;
7. clear the pressure and run N Jacobi iterations (N from the quality tier, at most the user's value);
8. subtract the gradient and apply the walls rule;
9. advect dye by the projected velocity;
10. display.

Configuration changes (viscosity, dissipation, iterations, edge mode) are read at the start of the next frame
through `scene.update(configuration:)` without a rebuild. A grid-size change still needs a rebuild and is not exposed
in this phase.

## Migration and rollback

- **Migration**: `FluidConfiguration` gains `boundaryMode` (still version 1; nothing is stored). Phase 02 fixtures
  switch their CPU reference to `FluidSolver.step`, which includes projection, and use open edges for uniform motion.
  These are recorded test changes; the behavior is preserved.
- **Rollback**: revert the feature-021 commits.

## Complexity Tracking

None.
