# Implementation Plan: Graphics Benchmark Lab — Phase 02 Three deterministic workload renderers

**Branch**: `174-gbl-p02-workload-renderers` (spec directory only; work on `main`) | **Date**: 2026-11-19 | **Spec**: [spec.md](spec.md)

## Summary

Graphics Benchmark Lab arrives in the one app as a candidate: three deterministic workloads (textured quads, ALU
stress, particles) drawn through VisualCore's `FieldPass` and `ParticleRenderer`, a pure run timeline and particle
field in the core, a presenter that records frame samples (no GPU time) and summarises a finished run, native
controls, the candidate registration and a scenario manifest the runner passes. Gap G-SCENES closes.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/experience.md](contracts/experience.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6, SwiftUI for the controls, GLSL ES 3.00 fragment programs through `FieldPass`.
- **Dependencies:** the A24-P01 core; VisualCoreExperience, VisualCorePersistence, VisualCoreMath (`Vec2`, `Vec4`,
  `Camera2D`), VisualCoreSimulation (`ParticleInstance`), VisualCoreRendering, VisualCoreExperienceHost, VisualCoreUI.
- **Testing:** the core and experience package tests on sim-27.2; the app build and unit tests; the runner on iOS 27.2.
- **Performance:** tests draw at most 61 frames off screen per workload and never wait for a plan; each under 10 s.
- **Constraints:** no GL call of the experience's own; no clock in the pictures; no VisualCore change.

No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: drawn in the host's context through `FieldPass` and `ParticleRenderer` |
| II | PASS: reused passes, render targets, the particle renderer, `ParticleInstance`, the experience host and the A24-P01 core |
| II-a | PASS: no VisualCore change |
| III | PASS: GPU objects created in `setup`, released in `teardown`, rebuilt after a context loss |
| IV | PASS: timeline and particle field pure and tested |
| V | PASS: no device step; simulator results are not device evidence |
| VI | PASS: no benchmark number in copy; GPU time absent, never zero |
| VII–X | PASS: no network, no permission; textures and particles generated in code |
| XI | PASS: a candidate of the one app, not available before X-A24 |
| XII, XIII | PASS |

A24 rules: consumer not fork; provenance (GPU null); bounded caps checked before allocation; no device ranking.
PASS. Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                              modify  core + VisualCoreMath, VisualCoreSimulation; GraphicsBenchmarkLabExperience(+Tests), product
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Core/{RunTimeline,ParticleField}.swift    new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/CoreTests/{RunTimelineTests,ParticleFieldTests}.swift new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/Adapter/{BenchCore,GBLManifest}.swift new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/Experience/{Workloads,RunRecorder,BenchPresenter,GBLControls,GraphicsBenchmarkLabExperience}.swift new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/ExperienceTests/{BenchTestSupport,BenchCoreTests,WorkloadDrawTests,
  RecorderTests,RebuildTests,GBLManifestTests}.swift                                     new
Packages/ExperiencesCreative/GraphicsBenchmarkLab/scenario-manifest.json                 new
Catalog/registrations.json; Apps/VisualCore/App/ExperienceRegistry.swift; project.yml   modify  candidate a24
Apps/VisualCore/Tests/Unit/AppModelTests.swift (synthetic id a25.effects-composer); RealCatalogTests; scripts/test_scripts.py
docs/apps/graphics-benchmark-lab/visualcore-contract.json (G-SCENES closed)             modify
```

- **Dependency direction:** app → experience → core → VisualCore.
- **Lifecycle:** the presenter builds the selected case's workload in `setup` (or when the case changes at a frame),
  draws it in `draw`, passes the size in `resize` and releases it in `teardown`; a context rebuild sets it up again
  and ends a running run as interrupted.
- **Migration:** snapshot schema 1. **Rollback:** revert the commits.

## Parallel work

- **Agent C:** `RunTimeline`, `ParticleField` and their tests (core).
- **Agent W:** `Workloads.swift` (the three workloads) and `WorkloadDrawTests`, `RebuildTests`.
- **Agent E:** `BenchCore`, `RunRecorder`, `BenchPresenter`, `GBLControls`, `GraphicsBenchmarkLabExperience`,
  `GBLManifest` and their tests, against [contracts/experience.md](contracts/experience.md).
- **Lead:** Package.swift, registration, app tests, the manifest generation, runs, contract and commits.
