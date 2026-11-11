# Research: A01-P04

APIs verified by the read-only audit (2026-11-10):
- `RenderContext.redirected(to:width:height:)` (RenderScene.swift);
- `ResourceRegistry.makeRenderTarget(width:height:format:label:)` and `release(_:)`;
- `RenderTarget.readPixels()`, which returns bottom-up rows;
- `RenderTarget.handle.name`, the framebuffer name;
- `RenderCapabilities.maxTextureSize` and `maxViewport`;
- `ResourceBudget` (256 MiB default), which `RenderHost.init(scene:maxFramesPerSecond:budget:)` accepts;
- `ResourceRegistry.stats.liveCount`;
- the private `renderContext`, `scene`, `sceneReady`, `sceneFailed` and `makeCurrent()` in RenderHost.swift, which
  the new method uses from inside the type;
- in the app: `ParticlesArtScene.displayScale` and `ClockedArtScene`'s `clock.time` feeding `fixedTime`.

- **R1 Where offscreen rendering lives.** Decision: a `RenderHost` method, so it has the private scene and context
  and needs no second context (Principle I). Alternative: a free function taking a scene and a registry. Rejected:
  it would duplicate the host's makeCurrent, resize and restore lifecycle (CLAUDE.md §4).
- **R2 Maximum size.** Decision: `maxRenderSize = min(maxTextureSize, maxRenderbufferSize, maxViewport.width,
  maxViewport.height)`, with `GL_MAX_RENDERBUFFER_SIZE` added to `RenderCapabilities` (additive field). The registry
  already rejects textures above `maxTextureSize`. The 8192 and 64 MP caps are applied in `ExportGeometry`, and the
  host refuses more than 64 MP.
- **R3 Orientation.** GL rows are bottom-up. `StillImage.init(width:height:bottomUpRGBA:)` flips rows once, and tests
  use a quadrant fixture (a known color per corner) to prove top-down output.
- **R4 Opaque sRGB PNG.** Decision: force alpha to 255 and build a `CGImage` with
  `CGColorSpace(name: CGColorSpace.sRGB)` and `CGImageAlphaInfo.noneSkipLast`. Encode with
  `CGImageDestinationCreateWithData(…, UTType.png.identifier as CFString, 1, nil)`. Decoding with ImageIO in tests
  checks that `alphaInfo` is one of none, noneSkipLast or noneSkipFirst, that the color-space name is sRGB, and that
  the pixels match. Alternative: `UIImage.pngData()`, rejected because its alpha and profile depend on the source
  image.
- **R5 Even rounding.** `short = 2 × round(long × shortRatio ÷ longRatio ÷ 2)`, then
  `max(2, min(short, long))`. 1080 at 4:5 gives 864, and at 16:9 gives 607.5 → 608. Capping applies to the long edge
  first (min of size, maxEdge, 8192), then scales down until w × h ≤ 64 MP and keeps both edges even.
- **R6 Matching the on-screen render.** The hosted test renders on-screen (host view of w×h points at scale 1) and
  offscreen at 2× the size. It box-downscales the export by 2 and compares the mean absolute difference, which must
  be ≤ 6/255.
- **R7 Failure path.** A host is built with `ResourceBudget(total: 8 MiB)`, and an export of 2048² (16 MiB) fails
  with `.resource(.overBudget)`. A later `renderOneFrame` still succeeds and live counts equal those before the
  export. This is a real failure path with no test-only hook.
- **R8 Share and Photos.** SwiftUI `ShareLink(item: url)` presents the system share sheet. "Save Image" there uses
  add-only access, which needs `NSPhotoLibraryAddUsageDescription`. The app never calls PhotoKit itself.
