# Implementation Plan: Particle Universe — Phase 02 One emitter and one force in the render loop

**Branch**: `034-pu-p02-render-loop` (spec directory only; work on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Gate**: A04-P02

## Summary

Close two VisualCore gaps, then put the seeded simulation into VisualCore's GPU render loop:

- **G-FIELDS (VisualCoreSimulation):** `ParticleForce` gains `.repulsor`, `.gravityWell`, `.wind` and `.vortex`, a
  public `bound(speed:)` and `clamped()`. `ParticleSystem.step` clamps the forces once per step. Existing cases keep
  their exact arithmetic for valid values (research R1).
- **G-PQUALITY (VisualCoreDiagnostics + VisualCoreSimulation):** `ParticleBudget` (shares 1/0.6/0.35/0.2, minimum 100),
  `DeviceConditions.current()` (public `ProcessInfo` only) and `ParticleSystem.liveLimit`.
- **Generic GPU scene (VisualCoreRendering):** `ParticleLayerScene`, a `RenderScene` that clears, fits a world rectangle
  into the drawable with `Camera2D`/`ViewMetrics`, and draws `[ParticleInstance]` from a source closure with
  `ParticleRenderer`. Pixel-tested offscreen in the package tests on iOS 27.2 and 26.5.
- **App:** `PlacedForce` and `SceneQuality` in `ParticleUniverseCore`; `SceneSimulation.setPlacedForce(_:)` and
  `setLiveLimit(_:)`; `SceneForce` gains the four cases (schema stays 1). The sandbox hosts `ParticleLayerScene` in
  `RenderHost`/`RenderSurface`, with tap/drag placement, controls, strength, effective-limit text, and the CPU
  `Canvas` preview as the fallback on host errors.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), Xcode 27.2 (27B52).

**Primary Dependencies** (all verified in the read-only audit of this session, file paths in research R0):
- VisualCoreSimulation: `ParticleSystem`, `Emitter`, `ParticleForce`, `ParticleInstance`, `FixedStepRunner`,
  `PlaybackState`;
- VisualCoreDiagnostics: `QualityPolicy(tierCount:lowPowerCeiling:decisionInterval:calmPeriod:)`,
  `QualityPolicy.decide(thermal:lowPower:now:)`, `FramePacing.Thermal`;
- VisualCoreMath / VisualCoreScenes: `Vec2`, `Vec4`, `Camera2D(center:zoom:rotation:)`, `ViewMetrics(size:scale:)`,
  `ViewMetrics.toWorld(_:camera:)`, `ViewMetrics.worldToNDC(camera:)`;
- VisualCoreRendering: `RenderScene`, `RenderContext`, `FrameInfo`, `RenderHost(scene:maxFramesPerSecond:budget:)`,
  `RenderHost.addErrorObserver`, `RenderHost.renderOffscreen(width:height:time:)`, `RenderHost.recreateContext()`,
  `RenderHost.readPixels()`, `ParticleRenderer(registry:)`, `ParticleRenderer.draw(_:camera:metrics:)`,
  `ParticleRenderer.release()`, `ParticleRenderer.lastInstanceCount`, `vcglClearColor`/`vcglClear` (CVisualCoreGL,
  inside VisualCoreRendering only);
- VisualCoreUI: `RenderSurface(host:accessibilityLabel:accessibilityHint:)`.

**Storage**: none (scene saving is Phase 04).

**Testing**:
- `swift test --package-path Packages/VisualCore` (forces, live limit, budget, device conditions);
- `swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore` (placed force, scene forces, quality, replay);
- `scripts/xcodebuild_package.py` for `Packages/VisualCoreRendering` on `sim-27.2` and `sim-26.5`
  (`ParticleLayerSceneTests`, SC-A04-205);
- XCUITest for the ParticleUniverse scheme on both simulators with `check_test_enumeration.py`.

**Target Platform**: iOS/iPadOS 26.0+; host tests on macOS 15+.

**Project Type**: iOS app + local SwiftPM domain package, consuming VisualCore packages.

**Performance Goals**: none claimed (constitution, negative requirements). Bounded work: ≤ 20,000 particles (scene
limit range), ≤ 8 steps per frame, forces clamped once per step (not per particle).

**Constraints**:
- `replay-v1.json`, A01's `ParticleReplay` checksums and `VisualCoreBaselines` stay bit-identical.
- No GL/EGL call in the app; all GL lives in VisualCoreRendering.
- DEBUG-only UI seams (`-uitestThermal`, `-uitestLowPower`); Release reads `ProcessInfo` alone.

**Scale/Scope**: VisualCore 3 new files + 1 extended; app core 2 new + 2 extended; app 3 files; ~7 test files.

## Constitution Check

| Principle / rule | Status |
|---|---|
| I Proven renderer only; A04 consumer, not fork | PASS — `ParticleLayerScene` uses the existing `ParticleRenderer` inside `RenderHost`; no new renderer, no app GL/EGL |
| II Reuse first; A04 reuse rule (forces, quality tiers, instanced drawing) | PASS — fields, budget, device conditions and the layer scene go to VisualCore; the app keeps defaults, copy and UI |
| II-a Preserve the reference | PASS — 7-step ProjectM regression in two chunks, A01/A02 clean build-for-testing (tasks) |
| III GPU lifecycle and thread ownership | PASS — the scene creates/releases GPU objects in setup/teardown on the main actor; recreation rebuilds from CPU state |
| IV Host-testable domain, test-first | PASS — all force, budget and placement math is host-tested before UI work |
| V Implementation before devices | PASS — simulator and host only |
| VI Evidence over assertion | PASS — every task closes with a `run-check` log under stage A04-P02 |
| VII Native, accessible UI | PASS — every gesture has a control (Center, nudges, slider); labelled canvas; audits on both runtimes |
| VIII Public APIs, truthful claims | PASS — `ProcessInfo.thermalState`/`isLowPowerModeEnabled`; the gravity well is called artistic |
| IX Bounded untrusted input | PASS — `ParticleForce.clamped()`, `SceneForce` validation, strength multiplier 0.1…2, world clamp |
| Public API baseline and docs | PASS — `///` on every public symbol; `check_public_api.py --update` |

No violations; Complexity Tracking empty. Re-checked after Phase 1 design: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/034-pu-p02-render-loop/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/visualcore-api.md     # G-FIELDS, G-PQUALITY, ParticleLayerScene
├── contracts/app-ui.md             # sandbox identifiers, texts, launch arguments
├── checklists/
└── tasks.md                        (speckit-tasks)
```

### Source Code

```text
Packages/VisualCore/Sources/VisualCoreSimulation/
├── ParticleSystem.swift            # extended: 4 force cases in step(); liveLimit; forces clamped once per step
└── ParticleForceFields.swift       # new: ParticleForce.clamped(), bound(speed:), limits, acceleration(at:velocity:)
Packages/VisualCore/Sources/VisualCoreDiagnostics/
├── ParticleBudget.swift            # new: shares per tier, minimum, limit(requested:tier:)
└── DeviceConditions.swift          # new: thermal + Low Power snapshot, current()
Packages/VisualCore/Tests/VisualCoreSimulationTests/
├── ParticleForceFieldTests.swift   # new: SC-A04-201, SC-A04-202, bit-identity of existing cases
└── LiveLimitTests.swift            # new: SC-A04-203
Packages/VisualCore/Tests/VisualCoreDiagnosticsTests/
└── ParticleBudgetTests.swift       # new: budget table, SC-A04-204 with QualityPolicy, DeviceConditions
Packages/VisualCoreRendering/Sources/VisualCoreRendering/
└── ParticleLayerScene.swift        # new: generic RenderScene (clear, fit world rect, draw instances)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/
└── ParticleLayerSceneTests.swift   # new: SC-A04-205 (3 states), recreation, fit math
Apps/ParticleUniverse/ParticleUniverseCore/Sources/ParticleUniverseCore/
├── ParticleScene.swift             # extended: SceneForce .repulsor/.gravityWell/.wind/.vortex + validation
├── SceneSimulation.swift           # extended: setPlacedForce(_:), setLiveLimit(_:), liveLimit
├── PlacedForce.swift               # new: kind, position, multiplier, defaults, world clamp, particleForce
└── SceneQuality.swift              # new: QualityPolicy(4, ceiling 1) + ParticleBudget per frame
Apps/ParticleUniverse/ParticleUniverseCore/Tests/ParticleUniverseCoreTests/
├── PlacedForceTests.swift          # new
└── SceneQualityTests.swift         # new (plus SceneForce cases in ParticleSceneTests)
Apps/ParticleUniverse/App/
├── SceneModel.swift                # extended: placed force, quality, GPU frame entry, renderer status
├── SandboxView.swift               # extended: force controls, effective limit, GPU surface + CPU fallback
├── ParticleStage.swift             # new: RenderHost owner + ParticleLayerScene + tap/drag overlay
└── DeviceConditionsSource.swift    # new: DEBUG launch-argument seam over DeviceConditions.current()
Apps/ParticleUniverse/Tests/UI/
├── SandboxForceUITests.swift       # new: tap, drag, Center, nudge, strength, kind, renderer status
└── SandboxQualityUITests.swift     # new: -uitestThermal serious / -uitestLowPower YES lower the effective limit
docs/apps/particle-universe/visualcore-contract.{json,md}   # G-FIELDS, G-PQUALITY → closed
```

**Dependency direction**:

```text
App → ParticleUniverseCore → VisualCoreSimulation, VisualCoreDiagnostics → VisualCoreMath
App → VisualCoreRendering (ParticleLayerScene, RenderHost) → VisualCoreSimulation, VisualCoreScenes, CVisualCoreGL
App → VisualCoreUI (RenderSurface)
```

`ParticleUniverseCore` gains a `VisualCoreDiagnostics` product dependency (Package.swift and `project.yml` app
target). No reverse edges, no ProjectM dependency (`check_dependencies.py`).

## Lifecycle contracts

- **Ownership:** `SceneModel` (main actor) owns the `SceneSimulation`, the placed force and `SceneQuality`.
  `ParticleStage` owns one `RenderHost` whose scene is a `ParticleLayerScene`; the scene's source closure calls
  `model.gpuFrame(frame)` and returns the model's particle copy. The scene never writes simulation state.
- **Frames:** on the GPU path the host's `FrameInfo.delta` (clamped 0…0.1 by VisualCore) advances the simulation
  while playing; while paused the scene redraws the held state. On the CPU fallback the existing `TimelineView`
  date path advances it. Exactly one path advances at a time (`rendererMode`).
- **Quality:** once per advanced frame `SceneQuality.update(conditions:now:)` decides the tier (time = host frame time
  or the date path's monotonic seconds) and sets `liveLimit = ParticleBudget.limit(requested: scene.particleLimit,
  tier:)`. Lowering the limit never removes live particles.
- **Errors and recreation:** `RenderHost` init failure or any error from `addErrorObserver` (except `.contextLost`,
  which VisualCore recovers) switches to `rendererMode = .cpuFallback(reason)`. Context recreation calls the scene's
  teardown/setup; the renderer is rebuilt and the simulation (CPU) is untouched.
- **Background:** unchanged from Phase 01 (`PlaybackState`); additionally the host is paused/resumed with the scene
  phase.
- **Rebuild:** a family or seed change rebuilds the simulation and re-applies the placed force and live limit.

## Data schemas

- `ParticleScene` schema version stays **1**. `SceneForce` adds `repulsor(x,y,strength,radius)`,
  `gravityWell(x,y,strength,softening)`, `wind(vx,vy,rate)`, `vortex(x,y,strength,radius)`; validation ranges equal
  the VisualCore clamp ranges. Existing version-1 files decode unchanged (`replay-v1.json` test).
- `PlacedForce` is runtime-only in this phase (not encoded; persistence is Phase 04). Details in
  [data-model.md](data-model.md).

## Migration and rollback

- **Source-compatible VisualCore additions:** new enum cases (no public exhaustive switches on `ParticleForce`
  outside VisualCore — verified by grep in research R1), new types, `liveLimit` defaulting to `capacity`.
  `ParticleRenderer` is unchanged.
- **Behavioral compatibility:** existing cases with valid values give bit-identical steps; checksums of the replay
  fixture, A01 and `VisualCoreBaselines` are the guard.
- **Rollback:** revert the feature's commits; nothing persisted, schema unchanged.

## Build and test commands

```bash
swift test --package-path Packages/VisualCore
swift test --package-path Apps/ParticleUniverse/ParticleUniverseCore
swift test --package-path Apps/GenerativeArtStudio/Core
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package \
  --destination sim-27.2 --action test --result-name a04-p02-rendering-ios27
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package \
  --destination sim-26.5 --action test --result-name a04-p02-rendering-ios26
xcodegen generate --spec project.yml
xcodebuild test -project VisualCore.xcodeproj -scheme ParticleUniverse -destination "platform=iOS Simulator,id=<27.2|26.5 udid>" \
  -derivedDataPath Build/DerivedData/ParticleUniverse -resultBundlePath .autonomy/xcresults/<name>.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO
python3 scripts/check_public_api.py --update
python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean
python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26
```

Every command runs through `python3 Tools/python/desktop_runbook.py run-check --stage A04-P02`.

## Complexity Tracking

None.
