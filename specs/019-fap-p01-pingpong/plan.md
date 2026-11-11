# Implementation Plan: Fluid Art Playground — Phase 01 Ping-pong feedback validation

**Branch**: `019-fap-p01-pingpong` (spec directory only; work stays on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Ledger gate**: A02-P01

**Input**: Feature specification from `specs/019-fap-p01-pingpong/spec.md` (5 clarifications, session 2026-11-11)

## Summary

Prove the smallest fluid slice: bounded velocity (2 channels) and dye (4 channels) fields that live on the GPU in
ping-pong pairs. With no motion, dye decays exactly as `1 / (1 + d·Δt)` per step. The result is checked against a CPU
reference that rounds to the same storage precision every step.

The reusable machinery is built in VisualCore, as the A02-P00 contract assigns it:
- G-PINGPONG: `PingPongTarget`;
- G-FLOATRT: the half-float render-target support query with an RGBA8 fallback;
- G-FIELDPASS: `FieldPass`.

Generic CPU pieces also go to VisualCore (reuse rule; research R6): a CPU `FieldGrid` with storage-precision rounding,
signed-range encoding, and a clamped variable time step.

The app keeps only the fluid rules:
- the configuration and its bounds;
- the dissipation semantics;
- the seed pattern;
- the dissipation and display shaders;
- the canvas.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), GLSL ES 3.00. Xcode 27.2, XcodeGen 2.46.0.

**Primary Dependencies**:
- VisualCoreRendering: `RenderHost`, `RenderScene`, `ResourceRegistry`, `RenderTarget`, `ShaderProgram`,
  `FullScreenShaderScene.vertexSource`, `RenderCapabilities`.
- VisualCoreUI: `RenderSurface`.
- VisualCore: VisualCoreSimulation (`SeededRandom`) and VisualCoreDiagnostics (`ResourceLedger`).

All of these were verified in the A02-P00 audit (docs/apps/fluid-art-playground/visualcore-contract.json, M01–M10)
and re-read for this plan: `ResourceRegistry.makeRenderTarget(width:height:format:label:)`, `TextureFormat.rgba16f`,
`RenderTarget.bind()/bindColor(unit:)/readPixels()`, and `RenderHost.recreateContext()`, which tears the scene down and
sets it up again.

**Storage**: None (no persistence in Phase 01).

**Testing**:
- Host: `swift test` for VisualCore and for FluidArtPlaygroundCore.
- VisualCoreRendering package tests on the iOS 27.2 and 26.5 simulators (`scripts/xcodebuild_package.py`).
- App unit tests (GPU fixture) and UI tests through the `FluidArtPlayground` scheme on both runtimes.

**Target Platform**: iOS/iPadOS 26.0+ (simulators 27.2 and 26.5 in this campaign).

**Project Type**: Mobile app plus shared Swift packages.

**Performance Goals**:
- At most 512 × 512 per field; 2 passes per frame in Phase 01.
- 60 fps on the simulator is not evidence. Device frame-time is measured in campaign II.

**Constraints**:
- No pass samples its output (guard).
- `Δt` clamped to 1/240…1/30 s.
- Offline, no permissions.
- No ProjectM linkage.
- Context loss rebuilds from the configuration.

**Scale/Scope**:
- 3 new VisualCoreRendering types plus 1 readback/upload extension.
- 3 new VisualCoreSimulation types.
- 1 new app Core package (4 source files).
- 1 scene and 1 canvas view in the app.
- About 12 test classes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / rule | How this plan complies | Status |
|---|---|---|
| I. Proven renderer only | All GPU work goes through `RenderHost`'s ANGLE ES 3.0 context. No new EGL path, no direct Metal. | PASS |
| II. App-neutral public API, reuse first | `PingPongTarget`, `FieldPass`, `FloatRenderSupport`, `RenderTarget.upload(rgbaFloats:)/readFloatPixels()`, `FieldGrid`, `StoragePrecision`, `SignedRangeEncoding` and `TimeStepPolicy` are fluid-neutral and go to VisualCore with `///` docs and an API baseline update. The app keeps only fluid rules. | PASS |
| II-a. Preserve the reference | The ProjectM regression (3/3 + 4/4) runs after the VisualCore change (T-A02-1xx). | PASS (planned) |
| III. GPU lifecycle and thread ownership | Main-actor scene. Pairs are created in `setup` and released in `teardown`, and `recreateContext` re-runs them. Generation-checked handles, 0-leak assertion. | PASS |
| IV. Host-testable domain, test first | The configuration, dissipation, precision rounding and encoding are host-tested before the GPU code. | PASS |
| V. Implementation before devices | Simulator and host only. Device half-float support is checked in campaign II. | PASS |
| VI. Evidence over assertion | `run-check` logs plus xcresults per task. The enumeration guard runs after each suite. | PASS |
| VII. Native, accessible UI | SwiftUI canvas through `RenderSurface` with a spoken description and a header. | PASS |
| VIII. Public APIs, privacy | GL ES via ANGLE only. No networking, no permissions. | PASS |
| IX. Bounded untrusted input | The configuration is clamped (grid, `Δt`, dissipation, iterations, vmax), and the issues are reported. | PASS |
| X. Licensing | All shaders are original, with a header recording the author and license (project license). | PASS |
| A02 Consumer, not fork | No EGL calls in the app; the dependency audit post-build phase stays in place. | PASS |
| A02 Isolated solver with a CPU reference | The dissipation step has a CPU reference that matches precision; the GPU is compared against it. | PASS |
| A02 Bounded GPU | Grid caps, `Δt` clamp, the input≠output guard, and a rebuild from configuration. | PASS |
| A02 One phase at a time | Only Phase 01 scope; advection, splats and pressure are excluded. | PASS |

No violations, so Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/019-fap-p01-pingpong/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/
│   ├── visualcore-rendering-api.md   # PingPongTarget, FieldPass, FloatRenderSupport, float upload/readback
│   ├── visualcore-simulation-api.md  # FieldGrid, StoragePrecision, SignedRangeEncoding, TimeStepPolicy
│   └── app-fields.md                 # FluidConfiguration bounds, dissipation semantics, scene/canvas contract
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
Packages/VisualCore/Sources/VisualCoreSimulation/
├── FieldGrid.swift            # NEW FieldGrid, StoragePrecision (float32/float16/unorm8 rounding)
├── SignedRangeEncoding.swift  # NEW signed value <-> [0,1] encoding for unorm storage
└── TimeStepPolicy.swift       # NEW variable step clamp (min…max, invalid -> min, one step per frame)
Packages/VisualCore/Tests/VisualCoreSimulationTests/
└── FieldGridTests.swift, SignedRangeEncodingTests.swift, TimeStepPolicyTests.swift   # NEW

Packages/VisualCoreRendering/Sources/VisualCoreRendering/
├── FloatRenderSupport.swift   # NEW extension check + probe, cached per generation; storage selection with override
├── PingPongTarget.swift       # NEW read/write pair, swap, guard, accounting, release
├── FieldPass.swift            # NEW full-screen program with named sampler inputs and typed uniforms
├── GPUObjects.swift           # EDIT RenderTarget.upload(rgbaFloats:) and readFloatPixels()
└── RenderCapabilities.swift   # EDIT reportsColorBufferHalfFloat (extension list)
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/
└── FloatRenderSupportTests.swift, PingPongTargetTests.swift, FieldPassTests.swift, FloatTransferTests.swift  # NEW

Apps/FluidArtPlayground/Core/                       # NEW GPU-free package FluidArtPlaygroundCore
├── Package.swift
├── Sources/FluidArtPlaygroundCore/
│   ├── Module.swift
│   ├── FluidConfiguration.swift  # bounds, clamping, issues, Codable v1
│   ├── Dissipation.swift         # factor 1/(1+d·Δt); CPU step over FieldGrid with precision
│   └── DyeSeed.swift             # deterministic seed pattern (SeededRandom), uniform fixture
└── Tests/FluidArtPlaygroundCoreTests/
    ├── FluidConfigurationTests.swift, DissipationTests.swift, DyeSeedTests.swift
Apps/FluidArtPlayground/App/
├── FluidArtPlaygroundApp.swift   # EDIT home gains "Open playground" navigation
├── FluidFieldsScene.swift        # NEW RenderScene: velocity + dye PingPongTargets, dissipation + display FieldPasses
├── FluidShaders.swift            # NEW GLSL ES 3.00 sources (dissipate, display), license header
└── PlaygroundView.swift          # NEW canvas (RenderSurface) with spoken description
Apps/FluidArtPlayground/Tests/
├── Unit/DissipationFixtureTests.swift   # NEW GPU vs CPU, 3 dissipations x 60 steps, both storages
├── Unit/FieldsLifecycleTests.swift      # NEW context-loss rebuild, 0 leaks, guard, dt clamp
└── UI/PlaygroundUITests.swift           # NEW canvas exists, spoken description, non-blank, changes
project.yml                              # EDIT FluidArtPlaygroundCore package, app deps, FluidArtPlaygroundTests target
docs/apps/fluid-art-playground/visualcore-contract.{json,md}  # EDIT close G-PINGPONG/G-FLOATRT/G-FIELDPASS
Packages/VisualCoreRendering/README.md, Packages/VisualCore/README.md, docs/api baseline   # EDIT docs + baseline
```

**Structure Decision**: The A01 layout is reused: an app target under `Apps/<App>/App`, a GPU-free SwiftPM package
under `Apps/<App>/Core`, and unit and UI test bundles. The dependency direction is
`App → FluidArtPlaygroundCore → VisualCore` and `App → VisualCoreRendering/VisualCoreUI → VisualCore`. Core never
imports a rendering module (R1–R5).

## Lifecycle contract (summary; details in contracts/)

1. `setup(context)`:
   - choose the storage format with `FloatRenderSupport.storage(in:forceFallback:)`;
   - create the velocity and dye `PingPongTarget`s at the clamped grid size;
   - compile the `FieldPass`es;
   - upload the seed with `upload(rgbaFloats:)`;
   - reset the step counter.
2. `render(context, frame)`:
   - `Δt = TimeStepPolicy.clamp(frame.delta)`;
   - run the dissipation pass once per pair (read→write, then swap);
   - run the display pass from dye.read to the context framebuffer;
   - increment the step counter.
3. `teardown(context)`: release both pairs and both passes. The registry ledger returns to the pre-setup counts.
4. Context loss (`RenderHost.recreateContext`) runs teardown, then setup on the new generation. Old handles are
   rejected as stale and never used. The fields are re-seeded from the configuration.

## Build and test commands

See [quickstart.md](quickstart.md). Every command is run through
`desktop_runbook.py run-check --stage A02-P01`.

## Migration and rollback

- **Migration**: none. The data is new, nothing is persisted, and the VisualCore additions are purely additive. The
  public API baseline only grows.
- **Rollback**: revert the feature-019 commits. The VisualCore additions have no other consumers yet; the baseline
  diff and the ProjectM regression show any accidental change. App Phase 00 remains a working shell.

## Complexity Tracking

None.
