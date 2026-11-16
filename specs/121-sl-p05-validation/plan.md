# Implementation Plan: Simulation Lab — Phase 05 Numerical validation

**Branch**: `121-sl-p05-validation` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-VALIDATION and the phase's regression fixture with no source change outside the tests and one small,
read-only accessor:
- **Validation report** (`ExperienceTests/SimulationValidationTests.swift`):
  - Runs the five measurements of clarifications Q1–Q4: running mirrors, the 16 × 16 fixtures, the stability limits,
    per-frame and memory bounds, and steps per second.
  - Asserts every bound, and renders `docs/apps/simulation-lab/validation-report.md`.
  - Writes the report under `UPDATE_VALIDATION_REPORT=1`. Otherwise it compares the committed file's deterministic
    lines with the generated ones; the steps-per-second lines are excluded.
- **Size-change fixture** (`ExperienceTests/SizeChangeTests.swift`): per family, mid-run, a canvas resize keeps the
  targets and reloads them; a context recreation makes them all new. The next frame's GPU field is within the family's
  tolerance.
- **Boundary rules** on the GPU: wrap for the automaton and reaction-diffusion is asserted by a glider and a disc
  painted across the edge; the wave's zero edges by `WaveBorderTests` (A16-P03). The report cites both.
- **Presenter accessor**: `SimulationPresenter.ownedTargetBytes`, the sum of the display target's and the three pairs'
  bytes, for the memory bound. `maxGPUStepsInFrame` records the largest per-frame delta.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/report.md](contracts/report.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 (tests), Markdown (report).
- **Dependencies** (verified at clarify): `ResourceRegistry.stats.totalBytes` and `.budget.total`,
  `PingPongTarget.bytes`, `RenderTarget` (its handle bytes), `ContinuousClock`; the A16-P01 to P04 code.
- **Storage:** none.
- **Testing:** experience tests on iOS 27.2; app build and unit; runner; packages; contract; documented API; script tests.
- **Performance:** each measurement is short. The report's runs total under 10 s per test: 3 × 120 frames plus 2 ×
  600 CPU iterations plus 2 × 600 GPU iterations.
- **Constraints:** no wall-clock assertion; iOS 27 only (the iOS 26 section at X-A16). No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I One renderer | PASS: measurements on the host's context |
| II Reuse | PASS: the registry's ledger and existing types |
| III Determinism | PASS: the report's deterministic lines are reproducible; timing lines are excluded |
| IV Pure core | PASS: no core change |
| V–VIII | PASS: no persistence, UI, privacy or permission change |
| IX Performance | PASS: per-frame cap and memory bound asserted |
| X–XIII | PASS (documented accessor; no VisualCore change) |

Post-design: PASS. The A16 rule "truthful labels" holds: the report says "simulator figure, not a device claim".

## Project Structure

```text
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift        modify (ownedTargetBytes, maxGPUStepsInFrame)
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{SimulationValidationTests,SizeChangeTests,
  BoundaryRuleTests}.swift                                                            new
docs/apps/simulation-lab/validation-report.md                                         new (generated)
docs/apps/simulation-lab/visualcore-contract.json (G-VALIDATION closed)               modify
```

**Dependency direction:** unchanged. **Lifecycle:** tests open sessions and close them; the report is a generated
document, like the scenario manifest. **Migration:** none. **Rollback:** revert the commits.

## Parallel work

- **Agent A:** `BoundaryRuleTests.swift` and `SizeChangeTests.swift`.
- **Lead:** the presenter accessor, `SimulationValidationTests.swift`, the report, the contract, the runs and the
  commits.
