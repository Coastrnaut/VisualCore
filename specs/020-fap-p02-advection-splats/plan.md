# Implementation Plan: Fluid Art Playground — Phase 02 Core fluid advection and splat injection

**Branch**: `020-fap-p02-advection-splats` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P02

## Summary

Turn multi-touch into capped, evenly resampled splats and carry dye and motion with semi-Lagrangian advection. The
GPU must equal a CPU reference on 8×8 and 16×16 grids in both storage formats.

Reusable pieces go to VisualCore:
- `PointerVelocityTracker` in VisualCoreScenes (G-POINTERVEL);
- `FieldGrid` exact bilinear sampling in VisualCoreSimulation;
- the `vc/field.glsl` include and a shader-library parameter on `FieldPass` in VisualCoreRendering.

The splat and advection equations stay in the app's GPU-free Core package (G-SOLVER, partial).

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), GLSL ES 3.00 (`texelFetch`, `textureSize`, `gl_FragCoord`).

**Primary Dependencies** (all verified in the code at A02-P01):
- VisualCoreScenes: `PointerEvent`, `PointerPhase`, `PointerTracker.maxPointers`, `Vec2` (VisualCoreMath).
- VisualCoreRendering: `RenderHost.pointerHandler`, `PingPongTarget`, `FieldPass`, `FloatRenderSupport`,
  `ShaderBundle.visualCoreLibrary`, `ResourceRegistry.maxTextureSize`.
- VisualCoreUI: `RenderSurface`.
- VisualCoreSimulation: `FieldGrid`, `StoragePrecision`, `SignedRangeEncoding`, `TimeStepPolicy`, `SeededRandom`.

**Storage**: None.

**Testing**: host `swift test` (VisualCore, FluidArtPlaygroundCore); VisualCoreRendering package tests on iOS 27.2
and 26.5; app unit and UI tests on both runtimes with the enumeration guard; the ProjectM regression after the
VisualCore change.

**Target Platform**: iOS/iPadOS 26.0+.

**Project Type**: Mobile app plus shared Swift packages.

**Performance Goals**: no simulator budget (spec Assumptions). Per frame: at most 16 splats × 2 passes, 2 advection
passes and 1 display pass. Advection does 4 texel fetches per cell.

**Constraints**:
- No pass samples its output.
- Samples per update and splats per frame are capped.
- Clamp-to-edge.
- Offline.
- No EGL in the app (isolation check).

**Scale/Scope**:
- VisualCore: 1 new type plus 2 methods, plus 1 GLSL include and 1 FieldPass parameter.
- App Core: 3 new files.
- App: shaders, scene changes, a touch bridge and a splash control.
- About 10 new test classes.

## Constitution Check

| Principle / rule | How this plan complies | Status |
|---|---|---|
| I. Proven renderer only | All passes are `FieldPass` on `RenderHost`; touches come through `RenderHost.pointerHandler`. | PASS |
| II. App-neutral API, reuse first | The tracker, the bilinear sampler (CPU and GLSL) and the FieldPass library parameter are fluid-neutral and go to VisualCore with docs and baseline. The splat and advection equations stay in the app (A02 isolated solver). | PASS |
| II-a. Preserve the reference | The ProjectM regression (7/7) runs after the VisualCore change. | PASS (planned) |
| III. GPU lifecycle | No new GPU objects beyond the existing pairs. The extra passes are created in setup and released in teardown. | PASS |
| IV. Host-testable domain, test first | Tracker, splat, queue and advection references are host-tested first. | PASS |
| V. Devices later | Simulator and host only. | PASS |
| VI. Evidence | run-check, the enumeration guard and xcresults. | PASS |
| VII. Accessible UI | The "Add splash" button is the alternative to the swipe gesture, with a VoiceOver announcement; the audit is rerun. | PASS |
| VIII. Public APIs, privacy | UIKit touches via the VisualCore host; no permissions or networking. | PASS |
| IX. Bounded input | Non-finite samples are rejected; caps per update and per frame; splat values clamped. | PASS |
| X. Licensing | Original shaders carry an MIT header. | PASS |
| A02 Bounded GPU | Δt clamp (Phase 01), splat cap, clamp-to-edge, input ≠ output guard. | PASS |
| A02 Every gesture has a control alternative | The splash button. | PASS |

No violations.

## Project Structure

### Documentation

```text
specs/020-fap-p02-advection-splats/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/visualcore-api.md   # PointerVelocityTracker, FieldGrid.sampleBilinear, vc/field.glsl, FieldPass(library:)
├── contracts/app-splats.md       # Splat, SplatQueue, Advection reference, scene pass order, splash control
├── checklists/
└── tasks.md
```

### Source Code

```text
Packages/VisualCore/Sources/VisualCoreScenes/PointerVelocityTracker.swift            # NEW
Packages/VisualCore/Tests/VisualCoreScenesTests/PointerVelocityTrackerTests.swift    # NEW
Packages/VisualCore/Sources/VisualCoreSimulation/FieldGrid.swift                     # EDIT sampleBilinear(cellX:cellY:)
Packages/VisualCore/Tests/VisualCoreSimulationTests/FieldGridTests.swift             # EDIT bilinear tests
Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/field.glsl          # NEW vc_fieldBilinear
Packages/VisualCoreRendering/Sources/VisualCoreRendering/FieldPass.swift             # EDIT library: parameter
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/FieldBilinearTests.swift # NEW GPU = CPU sampler
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Sources/FluidArtPlaygroundCore/
├── FluidConfiguration.swift   # EDIT brushRadius, forceScale, maxSplatsPerFrame
├── Splat.swift                # NEW validated splat + CPU application (Gaussian)
├── SplatQueue.swift           # NEW tracker samples → splats, capped even drain, splash bursts
└── Advection.swift            # NEW semi-Lagrangian CPU reference (exact bilinear, dissipation)
Apps/FluidArtPlayground/FluidArtPlaygroundCore/Tests/FluidArtPlaygroundCoreTests/
└── SplatTests.swift, SplatQueueTests.swift, AdvectionTests.swift, FluidConfigurationTests.swift (EDIT)
Apps/FluidArtPlayground/App/
├── FluidShaders.swift         # EDIT splat and advect fragments
├── FluidFieldsScene.swift     # EDIT splat + advection pipeline, enqueue(_:)
└── PlaygroundView.swift       # EDIT touch bridge (tracker → queue), "Add splash" button, announcements
Apps/FluidArtPlayground/Tests/Unit/AdvectionFixtureTests.swift, SplatFixtureTests.swift   # NEW
Apps/FluidArtPlayground/Tests/UI/PlaygroundUITests.swift                                  # EDIT splash + drag
docs/apps/fluid-art-playground/visualcore-contract.{json,md}, regression-baseline.md     # EDIT
```

**Structure Decision**: same layering as A02-P01. Dependencies run `App → FluidArtPlaygroundCore →
VisualCoreSimulation`; the app also depends on `VisualCoreScenes` (tracker), `VisualCoreRendering` and
`VisualCoreUI`. Core gains `VisualCoreScenes` only for the tracker's `Sample` type; it imports no GPU module.

## Lifecycle and frame contract

1. **Touch** (main thread): `host.pointerHandler` → `PointerVelocityTracker.handle` → `SplatQueue.add(samples,
   viewSize:)`.
2. **Splash button**: `SplatQueue.addSplash()`.
3. **Frame** (`render`): clamp Δt, then `queue.drain(max: cap)`. Per splat: splat velocity, then splat dye. Then
   advect velocity by itself, then advect dye by velocity (both with the dissipation factor), then display.
4. **Context loss**: the queue is CPU state and survives. The fields are rebuilt from the configuration (Phase 01
   behavior). Pending splats then apply to the new fields.

## Migration and rollback

- **Migration**: `FluidConfiguration` gains 3 fields at schema version 1. No stored files exist (Phase 01 has no
  persistence). `FieldPass.init` gains a defaulted `library:` parameter, which is source compatible. All VisualCore
  changes are additive.
- **Rollback**: revert the feature-020 commits. The Phase 01 behavior (dissipation-only) returns.

## Complexity Tracking

None.
