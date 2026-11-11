# Implementation Plan: Particle Universe — Phase 01 Seeded particle domain model

**Branch**: `033-pu-p01-seeded-domain` (spec directory only; work on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Gate**: A04-P01

## Summary

Close G-EMITTERS and G-SIMSTEP in VisualCoreSimulation:
- `EmitterShape` (point, line, ring), `EmitterBurst` and `Emitter.clamped()` added to the existing `ParticleSystem`;
- a generic `FixedStepRunner` over a new `FixedStepSimulation` protocol, with pause/resume, step index and a
  `ControlStream` for replays.

Then add the app's GPU-free domain package `ParticleUniverseCore`:
- `ParticleScene` v1 with validation;
- the four `EmitterFamily` presets;
- `SceneCommand` and `SceneSimulation`, which maps a scene onto `ParticleSystem` and the runner;
- the committed replay fixture.

Finally the app's scene screen: a family picker, live and dropped counts, Play/Pause/Step, and a CPU `Canvas` preview.
The GPU loop is Phase 02.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), Xcode 27.2.

**Primary Dependencies**: VisualCore packages, audited in A04-P00:
- VisualCoreSimulation: `ParticleSystem`, `Emitter`, `ParticleForce`, `FixedStepClock`, `SeededRandom`;
- VisualCoreMath: `Vec2`, `Vec4`;
- VisualCoreUI: `AccessibleColors`;
- SwiftUI `Canvas` and `TimelineView`.

**Storage**: none. Scenes are Codable; saving them is Phase 04.

**Testing**:
- XCTest via `swift test` for `Packages/VisualCore` and `Apps/ParticleUniverse/ParticleUniverseCore`;
- XCUITest for the app on the iOS 27.2 and 26.5 simulators, with the enumeration guard.

**Target Platform**: iOS/iPadOS 26.0+; the host tests run on macOS 15+.

**Project Type**: iOS app plus local SwiftPM domain package, consuming the VisualCore packages.

**Performance Goals**:
- No device numbers are claimed (constitution).
- The simulation is bounded by the particle limit (≤ 20,000) and 8 substeps per frame.
- The preview draws at most the limit.

**Constraints**:
- Deterministic results: the same seed and controls give the same checksum.
- No GPU, network or permission use.
- VisualCore changes must leave A01's `ParticleReplay` and the `VisualCoreBaselines` checksums bit-identical.

**Scale/Scope**:
- VisualCore: 2 new files and 1 extended file.
- App core: 5 files.
- App: 2 views.
- About 6 test files.

## Constitution Check

| Principle / rule | Status |
|---|---|
| II Reuse first; A04 reuse rule: emitters and seeded fixed-step simulation in VisualCore | PASS — G-EMITTERS and G-SIMSTEP go into VisualCoreSimulation with tests, docs and the API baseline |
| R1–R5 package rules (pure logic in `Packages/VisualCore`) | PASS — no UIKit/GL in the additions |
| A04 GPU-free domain (host `swift test`) | PASS — `ParticleUniverseCore` is host-tested |
| A04 consumer, not fork; EGL ownership stays in VisualCore | PASS — the app makes no GL/EGL call; the preview is a SwiftUI `Canvas` |
| A04 truthful claims | PASS — the copy says "sandbox"; no physical claims |
| A04 bounded resources, clamped parameters | PASS — limit 100…20,000, `Emitter.clamped()`, cap 8 substeps |
| A04 accessibility (VoiceOver, Dynamic Type, Reduce Motion) | PASS — labelled picker and counts; Reduce Motion starts paused |
| Regression when VisualCore changes | PASS — the 7-step ProjectM regression, plus A01 and A02 builds, are planned (T-A04-1xx) |
| Public API baseline and documentation | PASS — `check_public_api.py --update`, `///` on every public symbol |

No violations; Complexity Tracking empty.

## Project Structure

### Documentation (this feature)

```text
specs/033-pu-p01-seeded-domain/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/simulation-api.md
├── checklists/
└── tasks.md            (speckit-tasks)
```

### Source Code

```text
Packages/VisualCore/Sources/VisualCoreSimulation/
├── ParticleSystem.swift        # extended: shape, burst, clamped(); FixedStepSimulation conformance
├── EmitterShape.swift          # new: EmitterShape, EmitterBurst, Emitter.clamped(), sampling
└── FixedStepRunner.swift       # new: FixedStepSimulation, ControlStream, FixedStepRunner
Packages/VisualCore/Tests/VisualCoreSimulationTests/
├── EmitterShapeTests.swift     # new
└── FixedStepRunnerTests.swift  # new
Apps/ParticleUniverse/ParticleUniverseCore/
├── Package.swift               # depends on VisualCoreSimulation, VisualCoreMath
├── Sources/ParticleUniverseCore/
│   ├── ParticleScene.swift     # versioned scene, validation errors
│   ├── EmitterFamily.swift     # Fountain/Curtain/Halo/Firework presets + spoken descriptions
│   ├── SceneCommand.swift      # control commands (move attractor, burst, set emitting)
│   └── SceneSimulation.swift   # scene → ParticleSystem + FixedStepRunner; counts; snapshot
└── Tests/ParticleUniverseCoreTests/
    ├── ParticleSceneTests.swift
    ├── EmitterFamilyTests.swift
    ├── ReplayFixtureTests.swift
    └── Fixtures/replay-v1.json
Apps/ParticleUniverse/App/
├── ParticleUniverseApp.swift   # home gains "Open sandbox"
├── SceneModel.swift            # @Observable @MainActor wrapper over SceneSimulation
└── SandboxView.swift           # family picker, counts, play/pause/step, Canvas preview
Apps/ParticleUniverse/Tests/UI/SandboxUITests.swift (+ accessibility audit)
project.yml                     # ParticleUniverseCore package dependency
```

**Dependency direction**:

```text
App → ParticleUniverseCore → VisualCoreSimulation → VisualCoreMath
App → VisualCoreUI
```

No reverse edges, and no ProjectM dependency (`check_dependencies.py`).

## Lifecycle contracts

- `SceneModel` owns one `SceneSimulation`. A family, seed or limit change rebuilds the simulation from the scene (no
  mixing).
- The `TimelineView` delivers frame dates. The model passes each frame's time to `runner.advance(frame:)`. A
  `scenePhase` change to background calls `pause()`; returning resumes only if the person had it playing. Resume
  discards accumulated time.
- The preview reads `simulation.instances()` (a value copy) and never writes back.

## Migration and rollback

- **VisualCore additions are source-compatible:**
  - new `Emitter` fields have defaults;
  - the `init` gains defaulted parameters at the end;
  - the point shape draws no extra random number.

  A01, A02 and the baselines must stay bit-identical (existing tests).
- **Rollback:** revert the feature's commits. Nothing is persisted and no schema is on disk yet.
- **Scene schema:** version 1. Decoding rejects other versions; Phase 04 adds the migration path.

## Build and test commands

```bash
swift test --package-path Packages/VisualCore
swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore
xcodegen generate --spec project.yml
xcodebuild test -project VisualCore.xcodeproj -scheme ParticleUniverse -destination "platform=iOS Simulator,id=<27.2|26.5 udid>" \
  -derivedDataPath Build/DerivedData/ParticleUniverse -resultBundlePath .autonomy/xcresults/<name>.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 300 CODE_SIGNING_ALLOWED=NO
python3 scripts/check_public_api.py --update
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

## Complexity Tracking

None.
