# Implementation Plan: Aurora — Phase 01 Noise and ribbon sky prototype

**Branch**: `152-au-p01-sky-prototype` (spec directory only; work on `main`) | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

## Summary

This phase adds Aurora's pending core and closes G-SCENE, G-SKY and G-CLOCK:
- **Scene:** the sky scene (schema 1) with bounds, refusals and three presets.
- **Sky:** the layered fragment shader `aurora-sky.frag` as source text, its CPU reference (a Swift port of the `vc/`
  hashes and noise), and two quality levels; the core tests draw it off screen and compare.
- **Clock:** `SkyClock` over `SceneClock` with a seamless 600 s loop, held under Reduce Motion or at speed 0.

Research: [research.md](research.md). Data: [data-model.md](data-model.md). Contract:
[contracts/core.md](contracts/core.md). Quickstart: [quickstart.md](quickstart.md).

## Technical Context

- **Language:** Swift 6 and GLSL ES 3.00 (as text). **Dependencies:** `VisualCoreMath`, `VisualCoreSimulation`,
  `VisualCoreExperience` for the core; `VisualCoreRendering` for the core tests only.
- **Testing:** `AuroraCoreTests` on sim-27.2 through `scripts/xcodebuild_package.py`; each test under 10 s.
- **Constraints:** the core is pure (no GL, clock, network, UIKit or SwiftUI); no VisualCore change; no registration.
  No NEEDS CLARIFICATION remains.

## Constitution Check

| Principle | Result |
|---|---|
| I | PASS: the tests draw on the host's own context; the core issues no GL call |
| II | PASS: reuses `SceneClock`, `FullScreenShaderScene`, `ShaderBundle` and `vc/` noise; nothing copied into VisualCore |
| IV | PASS: scene, presets, clock and reference are pure and tested with `swift test`-style package tests |
| VI | PASS: off-screen pixels compared with the reference; no device claim |
| XIII | PASS: presets, palettes and shader written here; recorded in `docs/apps/aurora/licenses.md` |
| A21 | PASS: visuals are code; bounded counts; nothing above 0.75 luminance; Reduce Motion still; stylized, no claim |

Post-design: PASS.

## Project Structure

```text
Packages/ExperiencesCreative/Package.swift                                    modify  AuroraCore, AuroraCoreTests
Packages/ExperiencesCreative/Aurora/Core/SkyScene.swift                       new     scene, bounds, refusals
Packages/ExperiencesCreative/Aurora/Core/SkyPresets.swift                     new     three presets
Packages/ExperiencesCreative/Aurora/Core/SkyClock.swift                       new     rendered clock
Packages/ExperiencesCreative/Aurora/Core/SkyNoise.swift                       new     Swift port of vc/ hash and noise
Packages/ExperiencesCreative/Aurora/Core/SkyReference.swift                   new     CPU reference of the shader
Packages/ExperiencesCreative/Aurora/Core/SkyShader.swift                      new     aurora-sky.frag text, uniforms, levels
Packages/ExperiencesCreative/Aurora/CoreTests/{SceneTests,PresetTests,ClockTests,NoiseTests,SkyRenderTests,
  ReducedMotionFrameTests}.swift                                              new
docs/apps/aurora/licenses.md                                                  new
docs/apps/aurora/visualcore-contract.json (G-SCENE, G-SKY, G-CLOCK closed)    modify
```

- **Dependency direction:** core tests → core → VisualCore products; the core tests also → VisualCoreRendering.
- **Lifecycle:** the core has none; the A21-P02 presenter owns the scene's GPU life.
- **Migration:** schema 1 only. **Rollback:** revert the commits.

## Parallel work

- **Agent S:** scene, presets and their tests.
- **Agent R:** noise port, reference, shader, clock and their tests.
- **Lead:** Package.swift, licenses.md, the contract, runs and commits.
