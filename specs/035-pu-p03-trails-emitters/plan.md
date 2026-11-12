# Implementation Plan: Particle Universe — Phase 03 Trails and multiple emitters

**Branch**: `035-pu-p03-trails-emitters` (spec directory only; work on `main`) | **Date**: 2026-11-11 |
**Spec**: [spec.md](spec.md) | **Gate**: A04-P03

## Summary

Close G-BLENDTRAIL in VisualCore, then add several emitters, per-emitter overrides and trails to the sandbox:

- **VisualCoreSimulation:** `TrailDecay`, the pure fade model (`factor(strength:delta:)`, the 8-bit step used to
  predict GPU pixels), host-tested.
- **VisualCoreRendering:**
  - `ParticleBlend` (`.normal` default, `.additive`) on `ParticleRenderer.draw`;
  - `TrailLayer`: an RGBA8 `PingPongTarget` with a decay `FieldPass`, a composite `FieldPass` with a brightness cap,
    `clear()`, resize and release;
  - `ParticleLayerScene` gains `blend`, `trailStrength`, `brightnessCap` and `clearTrails()` and uses the layer only
    when needed.
- **App core (`ParticleUniverseCore`):** `SceneEmitter` gets the optional `size`, `lifetime` and `gradient`;
  `SceneSimulation` gets emitter slots with retirement (`addEmitter`, `removeEmitter`, `setEmitterOverrides`,
  `visibleEmitters`, `rebuildScene`).
- **App:** emitter picker, Add and Remove, size, lifetime and gradient controls, a trails toggle, strength and blend,
  the Reduce Flashing cap note, and the CPU-preview note.

## Technical Context

**Language/Version**: Swift 6.4.2 (language mode 6), Xcode 27.2 (27B52).

**Primary Dependencies** (verified in this session's read-only audit; research R0):
- VisualCoreRendering: `PingPongTarget(registry:width:height:format:label:)`, `.read`, `.write`, `.swap()`,
  `.release()`, `.isValid`; `FieldPass(registry:fragment:inputs:label:)`, `.run(output:inputs:uniforms:)` with
  `.target(_)`/`.framebuffer(name:width:height:)`, `FieldUniform.float`, `.release()`;
  `FullScreenShaderScene.vertexSource` (`v_uv`); `RenderTarget.bind()`, `.readPixels()`, `.width`, `.height`;
  `TextureFormat.rgba8`; `ResourceRegistry.stats.liveCount[.texture]`; `ParticleRenderer.draw(_:camera:metrics:)`;
  `ParticleLayerScene` (feature 034); `RenderHost.renderOffscreen`, `recreateContext()`.
- VisualCoreSimulation: `ParticleSystem.emitters` (`isEmitting`), `instances()` (size and color from
  `emitters[source]`), `AccessibilityPreferences.resolve(_:)`, `SystemAccessibility`.
- VisualCoreParameters: `Palette.builtIns`, `Palette.builtIn(_:)`, `Palette.sample(_:)`.
- VisualCoreUI: `SystemAccessibilityObserver.systemValues()`.

**Storage**: none. The overrides are Codable but saving is Phase 04.

**Testing**:
- `swift test` for `Packages/VisualCore` (`TrailDecayTests`) and for `ParticleUniverseCore` (emitter slots,
  overrides, replay);
- `xcodebuild_package.py` for VisualCoreRendering on `sim-27.2` and `sim-26.5` (`ParticleBlendTests`,
  `TrailLayerTests`, with fixture 3 leak counts and SC-A04-303/305 pixels);
- XCUITest on both runtimes, with the enumeration guard.

**Target Platform**: iOS/iPadOS 26.0+; host tests on macOS 15+.

**Project Type**: iOS app plus a local SwiftPM domain package, consuming the VisualCore packages.

**Performance Goals**: no numbers are claimed. The bounds are:
- trail targets with a longer edge ≤ 2,048 px, i.e. at most 2 × 2,048 × 2,048 × 4 B = 32 MiB;
- at most 2 extra full-screen passes per frame, and only while trails or the brightness cap are active;
- at most 8 emitter slots.

**Constraints**:
- `.normal` blend and the absence of a layer keep Phase 02 pixels and A01 identical.
- `replay-v1.json` is unchanged, since the new emitter fields are optional.
- No GL in the app.

**Scale/Scope**:
- VisualCore: 3 new files and 2 extended;
- app core: 2 extended files;
- app: 2 extended and 1 new;
- about 6 test files.

## Constitution Check

| Principle / rule | Status |
|---|---|
| I Proven renderer only; A04 consumer, not fork | PASS — trails are FieldPasses on PingPongTarget inside VisualCore's host |
| II Reuse first; A04 reuse rule (blending, trails, decay targets) | PASS — `ParticleBlend`, `TrailLayer`, `TrailDecay` go into VisualCore; the app keeps presets and UI |
| II-a Preserve the reference | PASS — 7-step regression in two chunks, A01/A02 clean build-for-testing |
| III GPU lifecycle and thread ownership | PASS — the layer is created and released in the scene's setup/render/teardown on the main actor; recreation rebuilds from CPU state |
| IV Host-testable domain, test-first | PASS — `TrailDecay`, slots and overrides are host-tested first |
| V Implementation before devices | PASS |
| VI Evidence over assertion | PASS — `run-check` under A04-P03 |
| VII Native, accessible UI; Reduce Flashing | PASS — native controls, a brightness cap under Reduce Flashing, audits on both runtimes |
| VIII Public APIs | PASS — `UIAccessibility` and `MADimFlashingLightsEnabled` through the existing VisualCoreUI observer |
| IX Bounded input | PASS — clamped overrides, decode validation, capped trail size, ≤ 8 slots |
| Public API baseline and docs | PASS — `///` docs and `check_public_api.py --update` |

No violations. The check is unchanged after design.

## Project Structure

### Documentation

```text
specs/035-pu-p03-trails-emitters/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/visualcore-api.md, contracts/app-ui.md
├── checklists/
└── tasks.md
```

### Source Code

```text
Packages/VisualCore/Sources/VisualCoreSimulation/TrailDecay.swift            # new: factor(strength:delta:), step8(_:factor:)
Packages/VisualCore/Tests/VisualCoreSimulationTests/TrailDecayTests.swift    # new
Packages/VisualCoreRendering/Sources/VisualCoreRendering/
├── ParticleRenderer.swift        # extended: ParticleBlend, draw(_:camera:metrics:blend:) (default .normal)
├── TrailLayer.swift              # new: PingPongTarget + decay/composite FieldPasses, clear, resize, cap, release
└── ParticleLayerScene.swift      # extended: blend, trailStrength, brightnessCap, clearTrails(), layer on demand
Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/
├── ParticleBlendTests.swift      # new: additive sums; normal unchanged
└── TrailLayerTests.swift         # new: SC-A04-303 fade, SC-A04-304 leaks, SC-A04-305 cap, scene integration
Apps/ParticleUniverse/ParticleUniverseCore/Sources/ParticleUniverseCore/
├── ParticleScene.swift           # extended: SceneEmitter size/lifetime/gradient (+ validation, invalidEmitter)
└── SceneSimulation.swift         # extended: emitter slots with retirement, overrides applied to new particles
Apps/ParticleUniverse/ParticleUniverseCore/Tests/ParticleUniverseCoreTests/
├── EmitterSlotTests.swift        # new: SC-A04-301
└── EmitterOverrideTests.swift    # new: SC-A04-302, decode validation, round trip
Apps/ParticleUniverse/App/
├── SceneModel.swift              # extended: emitters, overrides, trails, blend, Reduce Flashing
├── SandboxView.swift             # extended: EmitterControls, TrailControls
└── DeviceConditionsSource.swift  # extended: DEBUG -uitestReduceFlashing
Apps/ParticleUniverse/Tests/UI/SandboxEmitterUITests.swift, SandboxTrailUITests.swift   # new
docs/apps/particle-universe/visualcore-contract.{json,md}   # G-BLENDTRAIL closed; M04, M08 available
```

**Dependency direction** is unchanged from Phase 02. `ParticleUniverseCore` gains the `VisualCoreParameters` product
for `Palette`, through `Package.swift` and the app target in `project.yml`:

```text
App → ParticleUniverseCore → VisualCoreSimulation, VisualCoreDiagnostics, VisualCoreParameters → VisualCoreMath
App → VisualCoreRendering (ParticleLayerScene → TrailLayer → PingPongTarget, FieldPass) ; App → VisualCoreUI
```

## Lifecycle contracts

- **Trail layer ownership:** `ParticleLayerScene` owns at most one `TrailLayer`.
  - It is created on the first frame that needs it (`trailStrength > 0` or `brightnessCap < 1`) at the drawable size
    (longer edge ≤ 2,048).
  - It is released when no longer needed, on teardown, and before a recreation (with VisualCore's
    teardown/setup order).
  - A resize to a different size releases and recreates it, cleared; a zero size releases it.
- **Frame order with the layer:**
  1. decay `read` → `write` with `f = TrailDecay.factor(strength, delta)`;
  2. bind `write` and draw the particles with the chosen blend;
  3. composite `write` → the context framebuffer with the cap;
  4. swap.

  Without the layer the scene keeps Phase 02's direct path.
- **Emitter slots:** see [data-model.md](data-model.md).
  - Removal sets `isEmitting = false` and marks the slot retired; it is freed when no live particle has that source.
  - Freeing is checked on each add and each step.
  - Rebuilding (family change of the whole scene, seed) compacts the slots.
- **Overrides** change `system.emitters[slot]` in place. Lifetime applies to particles born afterwards; size and
  gradient also restyle that emitter's live particles, because `instances()` reads them from the emitter (research
  R3, SC-A04-302 as clarified). Other emitters are never affected.
- **Reduce Flashing:** the model resolves `AccessibilityPreferences()` against `SystemAccessibilityObserver` (system
  flags) or the DEBUG seam each time the screen appears and on change notifications; it sets
  `brightnessCap = 0.6` and shows the note.

## Data schemas

`ParticleScene` stays version **1**. `SceneEmitter` gets three optional fields (data model). Old files decode with
nil overrides, and the replay fixture is bit-identical.

## Migration and rollback

- **Source compatibility:** `draw(... blend: ParticleBlend = .normal)` is a defaulted parameter; `TrailLayer`,
  `TrailDecay` and `ParticleBlend` are new; the new `ParticleLayerScene` properties have defaults that keep Phase 02
  behavior.
- **Rollback:** revert the feature's commits. Nothing is persisted.

## Build and test commands

As in Phase 02 (feature 034 plan), with stage `A04-P03`. Rendering package tests on both runtimes:

```bash
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test --result-name A04-P03-<task>-ios27
```

The app UI test command is the same, plus `-only-testing` while iterating. Every command runs through
`desktop_runbook.py run-check --stage A04-P03`.

## Complexity Tracking

None.
