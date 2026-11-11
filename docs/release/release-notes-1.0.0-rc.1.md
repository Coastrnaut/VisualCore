# VisualCore 1.0.0-rc.1 — release notes

**Date:** 2026-11-10 · **Status:** release candidate, **verified on iOS 27.2 and 26.5 simulators only**.
Device support is pending campaign II on D1, D2 and D3 ([support matrix](support-matrix.md)). This is not an App Store
release.

## What's in it

Everything below has public `///` docs and is recorded in the API baseline
[`docs/api/visualcore-public-api.txt`](../api/visualcore-public-api.txt).

### Rendering host and resources (features 003–004)
- `RenderHost` and `RenderView`: EGL lifecycle on ANGLE's Metal backend, main-thread rendering, context generations,
  pause/resume, context loss and recreation, frame pacing from thermal state and Low Power Mode.
- `ResourceRegistry`: textures, buffers, render targets and programs with budgets, a render-target pool, a program
  cache, leak accounting and stale-handle rejection.
- `ShaderLibrary`: includes, defines and line maps. Compile errors report the original file and line.

### Effects (feature 005)
- A versioned effect-graph description, validator and executor. There are eight pass types: copy, color matrix, blur,
  bloom (optionally HDR), distort, composite, feedback and flash limiter.
- Graphs are capped at 32 passes and a memory quota. Failed passes pass their input through. `EffectScene` adds a
  Reduce Flashing limiter.

### Interaction, simulation and drawing (feature 006)
- Math: vectors, matrices, quaternions, `Camera2D`, `OrbitCamera`, easing.
- Simulation: fixed-step clock, seeded random, timelines, a deterministic particle system.
- Scenes: view metrics, pointer tracking, tap/drag/pinch recognizers, scene graph, mesh generators.
- Rendering: primitive, particle (up to 100,000 instances) and mesh renderers; UIKit touches arrive as `PointerEvent`s.

### Samples and adapters (features 007–009)
- **VisualCore Showcase** (`dev.visualcore.Showcase`) has five scenes, a diagnostics overlay, context-loss simulation,
  Reduce Flashing and VoiceOver descriptions.
- **ProjectMReference** puts the ProjectM engine on a VisualCore host. It is a harness, not distributed, and the
  reference is pinned at `d93edd1` (ADR-0005).
- **Lumen Garden** is a second consumer built only from documented APIs.

### Stabilization (feature 010)
- Release gates:
  - public-API review and baseline (`check_public_api.py`);
  - documented-API check for every consumer;
  - license inventory and notices, with an LGPL analysis;
  - shader validation of every built-in and bundled shader;
  - a cleanup sweep: zero leaked resources across all sample scenes after context loss and destroy.
- `VisualCoreAutomation` `AutomationRunner` has smoke, launch and lifecycle modes with JSON reports. It is compiled
  only under `DEBUG || VISUALCORE_AUTOMATION`, and the Showcase Release binary was verified to contain zero
  automation symbols.
- Host and simulator performance baselines ([docs/performance](../performance/README.md)); these are not device
  evidence.
- `scripts/release_check.py` runs every gate. GitHub Actions CI (`.github/workflows/ci.yml`) runs the checks, the host
  tests and an iOS Simulator build of the pure package. Gates that need the locally built ANGLE frameworks run only
  in the release check.
- Documentation: [index](../index.md), [getting started](../getting-started.md).

## Verification

| Evidence | Result |
|---|---|
| `scripts/release_check.py`, all 30 steps (ledger checks `F09/t924-release-chunk1..3`, 2026-11-10) | **30/30 pass** |
| Simulators | iOS 27.2 (iPhone 18 Pro) and iOS 26.5 (iPhone 17 Pro Max): rendering, effects, automation, Showcase, InteractiveDemo, Lumen Garden and ProjectMReference suites |
| GitHub Actions `ci` | checks, host-tests and simulator-build jobs green (run 42950139293) |
| Release binary | 0 automation symbols and 0 trigger strings; ProjectM-independence audit pass |
| Devices D1–D3 | **not tested**: pending campaign II |

## Versions

| Item | Version |
|---|---|
| Every VisualCore module (`*Info.version`) | `1.0.0-rc.1` |
| Showcase `CFBundleShortVersionString` | `1.0.0` (App Store versions are numeric; the rc label lives in the modules and these notes) |
| Reference `External/projectm-ios` | `d93edd1` (ANGLE `29d1823`, projectM `c88894e`) |

## Known limitations

See [known-limitations.md](known-limitations.md). In short:
- no device evidence yet;
- audio taps and DSP, game-controller input, the shared TestSupport baselines, the `VisualCoreUI` surface and asset
  metrics are not built yet (ADR-0006, planned with the first app phases that need them);
- OpenGL ES through ANGLE only.

## Upgrading from 0.1.0

0.1.0 was the internal development line during features 001–009, and there are no external users. One API change
came with the stabilization work: `AutomationRunner.requestedMode` and `requestedFrames` are `nonisolated`. The
baseline diff in git history lists every public declaration.
