# VisualCoreRendering (iOS)

iOS 26+ modules over the owner's prebuilt ANGLE frameworks (OpenGL ES 3.0 on Metal), reused in place
from `External/projectm-ios/Build/ANGLEFrameworks` (pin 29d1823; ADR-0002). There is no second
renderer and no `dlsym`; GL entry points come from the generated `CVisualCoreGL` table filled by
`eglGetProcAddress`.

| Product / target | Purpose |
|---|---|
| CVisualCoreEGL, CVisualCoreGL | EGL subset and generated ES 3.0 table (`scripts/generate_vcgl.py`) |
| VisualCoreRendering | `RenderHost`, `RenderView`, lifecycle, capabilities, resources, programs |
| VisualCoreEffects | GPU passes, render-target pool, effect-graph executor |
| VisualCoreUI | SwiftUI render surface, diagnostics overlay, accessibility helpers |
| VisualCoreAudio | AVAudioEngine microphone / in-app playback taps → DSP features |
| VisualCoreAutomation | AutomationRunner (`DEBUG \|\| VISUALCORE_AUTOMATION` only) |

Contracts: [render lifecycle](../../specs/002-architecture-contracts/contracts/render-lifecycle.md),
[resources, shaders, errors](../../specs/002-architecture-contracts/contracts/resources-shaders-errors.md).

```bash
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
  --scheme VisualCoreRendering-Package --destination sim-27.2 --action test
python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering \
  --scheme VisualCoreRendering-Package --destination generic-ios
```

Simulator results are functional evidence only; device evidence comes in campaign II.

## Integrating a render view (SC-F204, under 30 lines)

```swift
import SwiftUI
import VisualCoreRendering

@MainActor final class PulseScene: RenderScene {
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let level = Float(0.5 + 0.5 * sin(frame.time))
        vcglClearColor(level, 0.2, 1 - level, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    func teardown(_ context: RenderContext) {}
}

struct PulseView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = try! RenderHost(scene: PulseScene())
        context.coordinator.host = host
        return host.view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Holder { Holder() }
    final class Holder { var host: RenderHost? }
}
```

`vcgl*` functions come from `CVisualCoreGL` (`import CVisualCoreGL`). The host keeps rendering while the
coordinator holds it, and it suspends in the background on its own.

## Resources and shaders (feature 004)

Every `RenderHost` owns one `ResourceRegistry` (`context.resources`). It creates textures, buffers,
render targets (pooled with `acquireTarget`/`recycle`) and programs (`program(vertex:fragment:defines:library:)`,
cached by SHA-256, LRU 64, recompiled after context recreation). Budgets refuse over-limit requests;
handles from an older context generation are rejected and counted; `stats` reports live counts, bytes,
peak, stale rejections, leaks, shader failures and deduplicated warnings. Shader sources are GLSL ES 3.00
with `#include "name"` from a `ShaderLibrary`; compile errors name the original file and line.
Color-space policy: [docs/rendering/color-space.md](../../docs/rendering/color-space.md).

## Effects (feature 005)

`EffectScene(content:graph:)` renders any scene into a target, runs a validated `EffectGraphDescription`
(JSON-codable, version 1, ≤ 32 passes, 256 MiB texture quota, cycles and missing inputs rejected before
GPU work) and presents the result. A pass that fails passes its first input through and is reported once.
`reduceFlashing = true` appends the flash limiter (displayed mean luminance changes ≤ 0.3 per second).

| Type | Inputs | Parameters (default, range) |
|---|---|---|
| `copy` | input | — |
| `colorMatrix` | input | `matrix` 16 values row-major (identity, −10…10), `offset` 4 values (0, −1…1) |
| `blur` | input | `radius` (4, 1…32); separable Gaussian, σ = radius / 2 |
| `bloom` | input | `threshold` (0.8, 0…1), `intensity` (1, 0…4), `radius` (8, 1…32), `hdr` (0, 0…1 → rgba16f) |
| `distort` | input | `strength` (0.02, 0…0.2), `frequency` (8, 0…64), `speed` (1, 0…10) |
| `composite` | base, overlay | `mode` (0 over, 1 add), `opacity` (1, 0…1) |
| `feedback` | input | `decay` (0.9, 0…1); owns a history target, cleared on resize/recreation |
| `flashLimit` | input | `limit` (0.3, 0.05…1) luminance change per second |

Out-of-range values are clamped and unknown keys are ignored with a warning. Defaults are generated
from `PassSchemas` in `VisualCoreEffectsGraph`; per-effect GPU cost on devices is measured in campaign II.

## Drawing and touches (feature 006)

| Type | Draws | Notes |
|---|---|---|
| `PrimitiveRenderer` | a `SceneNode` tree (rect, circle 12–128 segments, line, ear-clipped polygon) | one batched triangle list, premultiplied alpha |
| `ParticleRenderer` | `[ParticleInstance]` (≤ 100,000) | instanced soft-edged quads, size = world diameter |
| `MeshRenderer` | a `Mesh` through an `OrbitCamera` | Lambert + ambient, back faces culled; enable depth testing yourself when the framebuffer has depth |

All three allocate through `ResourceRegistry`, rebuild their GPU objects on the first draw after a context
recreation and free them in `release()` (call it from `teardown`). `RenderHost.pointerHandler` delivers UIKit
touches as `PointerEvent`s (view points, `UITouch.timestamp`, stable ids) and enables multi-touch; touches are
cancelled when the view leaves its window. A runnable example is `Harnesses/InteractiveDemo` (XcodeGen; drag spawns
particles, pinch zooms, Reduce Motion honored, UI-tested on iOS 27.2 and 26.5).

`ClearColorScene(red:green:blue:)` is the smallest `RenderScene`: it clears the framebuffer to one color. Use it as a
placeholder or a fallback scene when an app has nothing else to draw.

## Automation (feature 010)

`VisualCoreAutomation` compiles only under `DEBUG || VISUALCORE_AUTOMATION`; in a shipping Release build the module is
empty (`scripts/check_release_symbols.py` checks the built app for zero automation symbols). An app starts a run only
from the launch environment `VISUALCORE_AUTORUN=<mode>`. Optionally, `VISUALCORE_AUTORUN_FRAMES` sets the frame count,
from 1 to 10,000 (default 120). No URL scheme or remote trigger can start a run.

| Mode | Measures | Fails when |
|---|---|---|
| `smoke` | frame-time min/median/p95/max over N frames | any frame fails to render |
| `launch` | runner creation → first presented frame | no frame within 600 attempts |
| `lifecycle` | max(5, N/10) pause/resume cycles, context recreation every third | a frame fails or a resource leaks |

`AutomationRunner(host:bundleID:)`'s `run(mode:frames:)` writes
`Documents/visualcore-automation-<mode>-<UTC>.json` (`AutomationReport`, schema 1), then exits with code 0
(pass), 1 (fail) or 2 (error, unknown mode). A measurement build is Release plus
`SWIFT_ACTIVE_COMPILATION_CONDITIONS=VISUALCORE_AUTOMATION`. On a simulator, `scripts/run_automation_sim.py` runs
one mode; these results are rehearsals, not device evidence. The Showcase wires this up in
`Showcase/App/ShowcaseAutomation.swift`.
