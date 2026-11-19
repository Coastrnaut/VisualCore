# Implementation Plan: Graphics Benchmark Lab — Phase 03 Runner/profiler and capability probing

**Branch**: `175-gbl-p03-runner-probe` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Two additive VisualCoreRendering changes and the experience's runner and report:
- **U-RENDERINFO:** `ResourceRegistry.renderCapabilities`, set by the host for each context generation.
- **U-GPUTIMER:** a hand-written optional extension block in the GL loader and a public `GPUFrameTimer` over
  `GL_EXT_disjoint_timer_query`, returning a frame's GPU time only when available and not disjoint.
- **G-RUNNER:** the dropped-frame rule, stop at the next frame, GPU times from the timer when the probe allows it.
- **G-REPORT:** `RunReport` from public sources, carried in run file version 2.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contracts:
[contracts/visualcore.md](contracts/visualcore.md), [contracts/experience.md](contracts/experience.md).
Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, C (the loader block), Swift Testing.
- **Dependencies:** VisualCoreRendering (changed additively), VisualCoreDiagnostics (`DeviceConditions`), the A24 core.
- **Testing:** VisualCoreRendering tests on sim-27.2 (`RegistryCapabilitiesTests`, `GPUFrameTimerTests`); the public-API
  check and `--update`; the A24 package tests; the reference regression in two chunks; the app build, unit tests and
  the runner on iOS 27.2.
- **Constraints:** the generated `CVisualCoreGL.h` is untouched; no ProjectM change; no device run.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: timer queries issued in the host's context inside scene callbacks; no second renderer |
| II | PASS: generic timing and renderer facts go into VisualCore, not the experience |
| II-a | PASS: the reference regression runs in two chunks after the change |
| III | PASS: queries created in the owning context, dropped after a generation change |
| IV | PASS: probe, report and dropped rule pure and tested |
| V | PASS: no device step; simulator GPU times are not device evidence |
| VI | PASS: GPU time only from a non-disjoint available result |
| VIII | PASS: report from public APIs; no unique identifier; no network |
| XI–XIII | PASS |

A24 rules: provenance, bounded runs, no CPU time labelled GPU. PASS. Post-design: PASS.

## Project Structure

```text
Packages/VisualCoreRendering/Sources/CVisualCoreGL/include/CVisualCoreGLLoad.h          modify  extension block
Packages/VisualCoreRendering/Sources/CVisualCoreGL/VCGLLoadFromEGL.c                    modify  optional EXT entry points
Packages/VisualCoreRendering/Sources/VisualCoreRendering/ResourceRegistry.swift         modify  renderCapabilities
Packages/VisualCoreRendering/Sources/VisualCoreRendering/RenderHost.swift               modify  set it in takeCapabilities
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GPUFrameTimer.swift            new
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/{RegistryCapabilitiesTests,GPUFrameTimerTests}.swift new
Packages/VisualCoreRendering/README.md; Packages/VisualCore/README.md; docs/api/visualcore-public-api.txt  modify
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/{TimerProbe,RunReport,DroppedFrameRule}.swift  new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/BenchmarkRun.swift               modify  version 2 with report, migration from 1
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{TimerProbeTests,RunReportTests,DroppedFrameRuleTests}.swift new; RunDocumentTests modify
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{ReportSource}.swift       new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{RunRecorder,BenchPresenter}.swift  modify
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/{GPUTimingTests,ReportTests}.swift new; RecorderTests modify
specs/175-gbl-p03-runner-probe/scan-identifiers.sh                                      new
docs/apps/graphics-benchmark-lab/visualcore-contract.json (four gaps closed)            modify
```

- **Dependency direction:** experience → VisualCoreRendering (`GPUFrameTimer`, `renderCapabilities`) → loader.
- **Lifecycle:** the presenter creates the timer in `setup`, brackets the workload draw in `draw`, polls each frame,
  releases it in `teardown`; a rebuild makes a new timer.
- **Migration:** run file version 1 → 2 adds `report: null`; the reader accepts both. **Rollback:** revert the commits;
  the API baseline returns with them.

## Parallel work

- **Agent V:** the VisualCore change (loader block, `GPUFrameTimer`, registry property, host line, their tests, README
  paragraphs) against [contracts/visualcore.md](contracts/visualcore.md).
- **Agent C:** `TimerProbe`, `RunReport`, `DroppedFrameRule`, run file version 2 and their tests.
- **Agent E (after V and C):** `ReportSource`, the recorder and presenter changes and their tests.
- **Lead:** the API baseline update, the reference regression, the scan, runs, contract and commits.
