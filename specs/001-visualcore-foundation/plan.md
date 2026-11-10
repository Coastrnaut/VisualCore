# Implementation Plan: VisualCore Foundation

**Branch**: `001-visualcore-foundation` | **Date**: 2026-11-10 | **Spec**: [spec.md](spec.md)

## Summary

Package the audited ANGLE → Metal EGL lifecycle as an app-neutral render host, add GL resource and
shader services, a validated multi-pass effect graph, deterministic input/scene/simulation helpers,
a Showcase app, a ProjectM reference harness, a second consumer and an audio feature bridge, then
stabilize with compliance, symbol-isolation and automation checks (gates F02–F09).

## Technical Context

**Language/Version**: Swift 6.4.2 (Swift 6 mode, strict concurrency), C11 shims
**Primary Dependencies**: prebuilt ANGLE `libEGL`/`libGLESv2` XCFrameworks (pin 29d1823); Apple
UIKit/SwiftUI/QuartzCore/AVFAudio (public APIs only)
**Storage**: JSON files in app containers (atomic writes) for persisted settings
**Testing**: `swift test` (host, `Packages/VisualCore`); `xcodebuild test` on iOS 27.2 and 26.5
simulators (`Packages/VisualCoreRendering`, Showcase UI tests); Python `unittest` for scripts
**Target Platform**: iOS/iPadOS 26.0+ (D3 = 26.5), simulator arm64
**Project Type**: SwiftPM packages + XcodeGen app targets
**Performance Goals**: 60 fps default, 30 fps floor under pressure (device-verified only in campaign II)
**Constraints**: no dlopen/dlsym, no private APIs, no ProjectM outside the reference harness
**Scale/Scope**: 2 packages, ~16 modules, Showcase, 2 harness/consumer apps

## Constitution Check

| Principle | Plan compliance |
|---|---|
| I Proven renderer | Same XCFrameworks via binary targets; eglGetProcAddress GL table (ADR-0002) |
| II App-neutral | ProjectM only in `Harnesses/ProjectMReference` (ADR-0003); symbol scan in F09 |
| III Lifecycle | `RenderLifecycle` state machine + generations; main-thread precondition |
| IV Host-testable | All non-GPU logic in `Packages/VisualCore` with `swift test` |
| V Devices later | No device commands; generic-iOS builds only |
| VI Evidence | Every gate via `run-check` + `seal` + `record` |
| VII Accessibility | Showcase UI built in SwiftUI with labels, Dynamic Type, Reduce Motion/Flashing |
| VIII Public APIs/privacy | Audio via AVAudioSession/AVAudioEngine; privacy manifests; no capture hacks |
| IX Bounded input | Shader size/include limits; graph pass/memory quotas; cycle rejection |
| X Licensing | ANGLE notices bundled; provenance headers in shims |

Gate result: PASS (no violations to justify).

## Project Structure

```text
Packages/VisualCore/                 # host-testable (macOS + iOS)
  Sources/VisualCoreMath/            # Vec2/3/4, Mat3/4, Quat, Camera, easing
  Sources/VisualCoreSimulation/      # FixedStepClock, SeededRandom, Timeline, ParticlePool, NaN guard
  Sources/VisualCoreScenes/          # Mesh generators, InputMapper, PointerTracker, Scene protocol
  Sources/VisualCoreShaderSource/    # ShaderLibrary, include preprocessing, line maps, diagnostics parse
  Sources/VisualCoreEffectsGraph/    # EffectGraph model, validation, topo sort, quotas, FlashLimiterModel
  Sources/VisualCoreDiagnostics/     # FrameStats, MissedSlotCounter, DiagnosticsSnapshot, JSON report
  Sources/VisualCoreAudioDSP/        # SPSC ring, FFT (radix-2), band/RMS/onset features
  Sources/VisualCorePersistence/     # Versioned document envelope, atomic writer, migrations
  Sources/VisualCoreTestSupport/     # FakeClock, fixtures, image compare
  Tests/*
Packages/VisualCoreRendering/        # iOS only
  Sources/CVisualCoreEGL/            # EGL subset declarations (pinned ANGLE constants)
  Sources/CVisualCoreGL/             # generated GL ES 3.0 table + wrappers (eglGetProcAddress)
  Sources/VisualCoreRendering/       # RenderHost, RenderView, lifecycle, capabilities, resources, programs
  Sources/VisualCoreEffects/         # GPU passes, target pool, EffectRenderer, FlashLimiter pass
  Sources/VisualCoreUI/              # SwiftUI RenderSurface, diagnostics overlay, accessibility helpers
  Sources/VisualCoreAudio/           # AVAudioEngine mic/playback taps → DSP features
  Sources/VisualCoreAutomation/      # AutomationRunner (DEBUG || VISUALCORE_AUTOMATION)
  Tests/VisualCoreRenderingTests/    # simulator pixel readback, lifecycle, leaks
Showcase/                            # F06 app (project.yml target VisualCoreShowcase)
Harnesses/ProjectMReference/         # F07 (own ProjectMReference.yml)
Harnesses/SecondConsumer/            # F08 independent consumer (project.yml target)
scripts/                             # verify_environment, audit, validate_docs, check_compliance,
                                     # check_dependencies, check_symbols, generate_vcgl, build_suite,
                                     # run_simulator_suite, check_privacy_manifest, test_scripts
project.yml                          # suite XcodeGen spec (Showcase, SecondConsumer, 25 apps later)
```

**Structure Decision**: two packages per ADR-0003; one suite `project.yml`; separate reference yml.

## Phases → ledger gates

| Gate | Deliverable | Verification command(s) |
|---|---|---|
| F02 | CVisualCoreEGL, CVisualCoreGL, RenderHost, lifecycle, capabilities, readback | `xcodebuild test` VisualCoreRendering on iOS 27.2 + 26.5 sims (clear-color + gradient pixel tests, resize, recreate) |
| F03 | ResourceRegistry, ShaderProgram, ShaderLibrary (host), uniforms, budgets | `swift test` VisualCore (preprocessing/diagnostics); sim tests (compile errors, leaks after 100 recreations) |
| F04 | EffectGraph (host), GPU passes, pool, flash limiter | `swift test` (graph validation fixtures); sim tests (3-pass graph pixels, strobe limiter) |
| F05 | Math, simulation, input, meshes, particles | `swift test` (determinism 10k steps, reference math) |
| F06 | Showcase app, 6+ scenes, UI test | `xcodegen generate`; sim build + UI test; generic-iOS build |
| F07 | ProjectM reference harness + reference package regression | reference `ProjectM.xcframework` built with reference script; harness sim build/test; `xcodebuild test` reference ANGLERendering |
| F08 | SecondConsumer app; VisualCoreAudio + DSP | `swift test` DSP fixtures; sim build/test of SecondConsumer; audio bridge tests |
| F09 | compliance, dependency, symbol, privacy, automation checks; CI yml; API docs | all scripts + `test_scripts.py`; Release `nm` scan; full simulator + generic builds |

## Complexity Tracking

None.
