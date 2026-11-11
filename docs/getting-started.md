# Getting started with VisualCore

## 1. Requirements

- An Xcode toolchain with the iOS 26+ SDK. The verified host has Xcode 27.2 and Swift 6.4.2; check yours with
  `python3 scripts/verify_environment.py`.
- XcodeGen 2.46.0 to generate projects (`.xcodeproj` files are not committed).
- The ANGLE frameworks built in the reference checkout: `External/projectm-ios/Build/ANGLEFrameworks`
  (see `scripts/run_reference_baseline.py --list`).

## 2. Modules

| Package | Modules | Runs on |
|---|---|---|
| `Packages/VisualCore` | `VisualCoreMath`, `VisualCoreSimulation`, `VisualCoreScenes`, `VisualCoreShaderSource`, `VisualCoreEffectsGraph`, `VisualCoreDiagnostics`, `VisualCoreParameters` (incl. `ParameterEditor`), `VisualCoreTestSupport` (test-only: image comparison), `VisualCorePersistence` (`DocumentStore`) (+ placeholder `VisualCoreAudioDSP`) | macOS host and iOS |
| `Packages/VisualCoreRendering` | `VisualCoreRendering` (incl. `ShaderBundle`, `vc/*.glsl`, `FullScreenShaderScene`, `renderOffscreen`/`StillImageEncoder`), `VisualCoreEffects`, `VisualCoreUI` (`RenderSurface`, `ParameterPanel`), `VisualCoreAutomation` (Debug/measurement only) (+ placeholder `VisualCoreAudio`) | iOS / iPadOS 26+ |

The [package map](../specs/002-architecture-contracts/contracts/package-map.md) lists what each module owns and the
dependency rules. `scripts/check_dependencies.py` enforces them.

## 3. Add VisualCore to an app (XcodeGen)

```yaml
packages:
  VisualCore: { path: Packages/VisualCore }
  VisualCoreRendering: { path: Packages/VisualCoreRendering }
targets:
  MyApp:
    dependencies:
      - { package: VisualCoreRendering, product: VisualCoreRendering }
      - { package: VisualCore, product: VisualCoreScenes }
```

## 4. A first scene

Implement `RenderScene` (`setup`, `resize`, `render`, `teardown`). Then create a `RenderHost` and place its `view` in
your UI. The [rendering README](../Packages/VisualCoreRendering/README.md#integrating-a-render-view-sc-f204-under-30-lines)
has a complete example in under 30 lines, and a test compiles and runs it.

Rules worth knowing on day one:

- All GL work runs on the main thread inside the scene callbacks. Allocate GPU objects through `context.resources` so
  budgets, leak accounting and context recreation work.
- Release what you allocate in `teardown`. After `RenderHost.destroy()`, `resources.stats.leaked` must be 0.
- Load shaders with `ResourceRegistry.program(vertex:fragment:library:vertexName:fragmentName:)`. Compile errors
  name the file and line.
- Describe the canvas with native accessibility (labels, hints). The render view itself is not an accessibility
  element.

## 5. Samples to read

1. **Showcase** (`xcodegen generate` at the repository root, scheme `Showcase`) shows every capability: bundled
   shaders, textures, meshes, particles, effects, diagnostics, context loss and Reduce Flashing.
2. **Lumen Garden** (`Harnesses/SecondConsumer`) is a small game built only from documented APIs.

## 6. Test

```bash
swift test --package-path Packages/VisualCore
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/release_check.py --list
```

Simulator results are development evidence only. Device support is decided by campaign II
([support matrix](release/support-matrix.md)).
