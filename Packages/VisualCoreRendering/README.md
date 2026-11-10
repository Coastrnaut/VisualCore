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
