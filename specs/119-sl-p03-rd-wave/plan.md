# Implementation Plan: Simulation Lab — Phase 03 Reaction-diffusion and wave algorithms

**Branch**: `119-sl-p03-rd-wave` (spec directory only; work on `main`) | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

## Summary

Build G-RDWAVE-GPU and the phase gates (legend overlay; refused time steps explained) with no VisualCore change:
- **Experience GPU**: `WaveGPU` (new; an RGBA16F `PingPongTarget`, current height in red and previous in green, a step
  `FieldPass` with `uCourant2` and `uKeep` and a fixed zero border by cell index); `GrayScottGPU` (A16-P02) is now used by
  the presenter. Two display programs, `SimulationShaders.reactionDisplay` and `waveDisplay`, colour the float fields
  with the `SimulationPalette` stops passed as uniforms.
- **Presenter**: `SimulationPresenter` probes `FloatRenderSupport.detect(in:)` in `setup` and keeps one GPU mirror per
  family. A mirror loads from the CPU field (setup, recreation, resize, non-step change, or after 64 GPU steps since the
  last load, clarification Q3), steps by the engine's iteration delta otherwise, and draws through its display program.
  Without float support (or with the test seam `forceFloatUnsupported`), no float or 8-bit field is made for the two
  families. A restored state of either family is drawn from the CPU upload, with the unsupported sentence in the status
  line.
- **Core adapter**: the new action `sim.timestep [0.05…2.0]` in `SimulationCore` sets the spec's time step, keeping the
  field, the step count, running and speed. Refusals follow clarification Q4; the new rule code is
  `a16.unsupported`. The presenter's `send` refuses `sim.family` 1 or 2 locally with `a16.unsupported` when the probe
  reported no support. The core cannot know the device; the runner always plays on a simulator with float support.
- **Words**: `SimulationPresenter.answerWords` gives the refusal's own sentence (`SimulationRefusal.reactionStep`,
  `.courant`, the range sentence, the one-generation sentence, the unsupported sentence). The status line states the
  time step.
- **Legend**: `SimulationLegend` (new, SwiftUI) is returned by `makeCanvasOverlay(_:)`. It shows a colour bar of the
  family's palette with the minimum and maximum of the CPU field (v for reaction-diffusion, the height for the wave), or
  the alive and dead counts for the automaton. The values come from `SimulationLegendValues`, which also feeds the canvas
  description.
- **Tests**:
  - the GPU tolerance of both families (10 steps on 16 × 16 against both half roundings, ≤ 0.01);
  - the wave's zero edges after 100 GPU steps;
  - the reload after 64 steps, and the rebuild after recreation and resize;
  - forced no-support;
  - time-step acceptance and refusal 1 % above and at each limit;
  - legend values against the field; GPU display pixels against the CPU palette (±1 per channel);
  - manifest and fixtures regenerated for the new control.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract: [contracts/gpu.md](contracts/gpu.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, GLSL ES 3.00, SwiftUI.
- **Dependencies** (verified at clarify): from `VisualCoreRendering`: `PingPongTarget`, `FieldPass` (with
  `runObserver`), `RenderTarget`, `Texture.readFloatPixels()`, `FloatRenderSupport.detect(in:)` (cached per
  `ResourceRegistry.generation`) and `ResourceRegistry`. From `VisualCoreSimulation`: `FieldGrid`. From the host:
  `ExperiencePresenter.makeCanvasOverlay(_:)`. From the A16-P01 and A16-P02 code: `GrayScott`, `WaveField`,
  `SimulationSpec.refusal()`, `SimulationRefusal.reactionStep` and `.courant`, `GrayScottGPU`, `AutomatonGPU` and
  `SimulationPalette`.
- **Storage:** no schema change. The time step is already in `SimulationSpec` and the state schema.
- **Testing:** experience tests on the iOS 27.2 simulator (off-screen session); core tests for the time-step action;
  the manifest regenerated; app build and unit; runner; packages; contract; documented API; script tests.
- **Performance:** at most `maxStepsPerFrame` (128) GPU steps per frame on 64 × 64 cells; the reload after 64 steps
  costs one 64 × 64 float upload.
- **Constraints:** tests under 10 s; iOS 27 only at this phase gate. No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I One renderer | PASS: field passes on the host's OpenGL ES context |
| II Reuse | PASS: ping-pong, field pass, float probe, canvas overlay reused; nothing new in VisualCore |
| III Determinism | PASS: the CPU model stays the truth for digests, snapshots, legend and description |
| IV Pure core | PASS: the core changes only by the time-step action, GPU-free |
| V Persistence | PASS: no schema change |
| VI Tests | PASS: tolerance, border, reload, no-support, refusal, legend tests |
| VII Accessibility | PASS: the legend values are in the description; refusals are announced in the message line |
| VIII Privacy | PASS: no permission, no network |
| IX Performance | PASS: per-frame cap kept |
| X–XIII | PASS (no ads, no art, no new target, documentation and API baseline of the app package only) |

The A16 rules pass. Resource separation is asserted through `runObserver`. There is no silent 8-bit run: no field is
made without float support, and the families are refused with a sentence. The labels are truthful: the tolerance is
stated and not exceeded. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/SimulationLab/Experience/WaveGPU.swift                                new
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationLegend.swift                       new (view + values)
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationShaders.swift                      modify (two displays)
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationPresenter.swift                     modify (mirrors, probe, overlay, words)
Packages/ExperiencesCreative/SimulationLab/Experience/SimulationControls.swift                     modify (time-step row; families disabled)
Packages/ExperiencesCreative/SimulationLab/Experience/Adapter/SimulationCore.swift                 modify (sim.timestep, a16.unsupported)
Packages/ExperiencesCreative/SimulationLab/scenario-manifest.json                                  regenerate (control list; digests unchanged)
Packages/ExperiencesCreative/SimulationLab/ExperienceTests/{FloatFieldToleranceTests,WaveBorderTests,
  FloatMirrorTests,FloatUnsupportedTests,TimeStepTests,LegendTests}.swift                          new
docs/apps/simulation-lab/visualcore-contract.json (G-RDWAVE-GPU closed)                            modify
```

**Dependency direction:** unchanged. The presenter, GPU types and legend depend on VisualCoreRendering, the host and
the core; the core depends on nothing graphical.

**Lifecycle:**
- `setup` probes float support, then makes the display target, the four display passes, the automaton pair and, with
  support, the Gray-Scott and wave pairs.
- `draw` brings the current family's mirror in line, then runs its display.
- `resize` invalidates every mirror.
- Recreation runs `setup` again with a new registry generation, so the probe runs again.
- `teardown` releases everything.

**Migration:** none; a saved state replays as before. **Rollback:** revert the commits; the presenter returns to the
CPU upload for the two families and the time-step action disappears. Any saved state still decodes.

## Parallel work

- **Agent A:** `WaveGPU.swift` and the two display programs, from the contract.
- **Agent B:** `SimulationLegend.swift`.
- **Agent C:** the six test files, from the contract.
- **Lead:** core adapter, presenter, controls, manifest, contract JSON, runs and commits.
