# Implementation Plan: Simulation Lab — Phase 02 Cellular automata GPU parity

**Branch**: `118-sl-p02-automata-gpu` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-CA-GPU and the phase's Gray-Scott fixture with no VisualCore change:
- **Experience**: `AutomatonGPU` (an RGBA8 `PingPongTarget` at the grid size and a step `FieldPass` with the rule as two
  9-bit masks and wrap by index modulo), and `GrayScottGPU` (an RGBA16F pair and a step pass, used by the fixture
  only in this phase).
- **Presenter**: `SimulationPresenter` steps the automaton on the GPU in lockstep with the engine. It loads from the CPU
  field per clarification 2, displays the GPU field for the automaton through the existing display pass, and keeps the
  CPU upload for the other two families until A16-P03.
- **Tests**: parity of N GPU steps against the CPU reference, blinker and glider, pass isolation through
  `FieldPass.runObserver`, rebuild after context recreation and resize, and the Gray-Scott tolerance fixture.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/gpu.md](contracts/gpu.md).

## Technical Context

- **Language:** Swift 6, GLSL ES 3.00.
- **Dependencies** (verified in clarification): `VisualCoreRendering` (`PingPongTarget`, `FieldPass`, `FieldPassError`,
  `RenderTarget`, `Texture.readPixels()` and `readFloatPixels()`, `FloatRenderSupport`, `ResourceRegistry`),
  `VisualCoreSimulation` (`FieldGrid`, `StoragePrecision`) and the A16-P01 core.
- **Storage:** none new.
- **Testing:** experience tests on the iOS 27.2 simulator (off-screen session); core tests unchanged; app build and
  unit; runner; packages; contract; documented API; script tests.
- **Performance:** at most 128 automaton GPU steps per frame on 64 × 64 cells (bounded by the engine cap).
- **Constraints:** tests under 10 s; iOS 27 only. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: one renderer, field passes |
| II | PASS: ping-pong, field pass, observer and float probe reused |
| III | PASS: the CPU stays the deterministic truth |
| IV | PASS: core unchanged and GPU-free |
| V | PASS: no schema change |
| VI | PASS: parity and tolerance tests |
| VII | PASS: unchanged controls |
| VIII | PASS: no permission |
| IX | PASS: per-frame cap |
| X–XIII | PASS |

The A16 rules pass: resource separation is asserted, there is no silent 8-bit run (the fixture fails without float
targets), and truthful labels hold. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SimulationLab/Experience/{AutomatonGPU,GrayScottGPU,SimulationShaders}.swift          new
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift                                  modify
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{AutomatonParityTests,PassIsolationTests,
  GPURebuildTests,GrayScottToleranceTests}.swift                                                                 new
docs/apps/simulation-lab/visualcore-contract.json (G-CA-GPU closed)                                              modify
```

**Dependency direction:** unchanged (the presenter depends on VisualCoreRendering; the core does not).

**Lifecycle:** the presenter makes the pair and the passes with the display target in `setup`. It loads the pair from
the CPU field, steps the pair by the engine's iteration delta in `draw`, rebuilds everything after a context
recreation, and releases everything in `teardown`.

**Migration:** none. **Rollback:** revert the commits; the presenter returns to the CPU upload.

## Parallel work

- **Agent A:** GPU types, shaders and presenter changes.
- **Agent B:** the four test files, against the contract.
- **Lead:** contract, runs and commits.
