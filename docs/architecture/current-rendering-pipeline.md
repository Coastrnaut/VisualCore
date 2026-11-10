# Current rendering pipeline — ProjectM-iOS reference (feature 001, T-F008/T-F009)

Reference commit `1ad0b99` (ANGLE `29d1823`, projectM `c88894e`). Every claim carries a citation
of the form *ref: path # symbol* (backtick-quoted) relative to `External/projectm-ios`. Citations are verified by
`python3 scripts/inventory_reference.py --check-citations docs/architecture/current-rendering-pipeline.md`.
Unknowns carry follow-up IDs `U-F0xx` (owned by the gate named).

## 1. Startup → renderer initialization

1. The SwiftUI entry point builds the root view and forwards scene phase:
   ref:`Apps/projectM-iOS/ProjectMApp.swift`#`struct ProjectMApp: App`,
   ref:`Apps/projectM-iOS/ProjectMApp.swift`#`coordinator.sceneBecame(active: phase == .active)`.
2. The screen flow is notice → chooser → visualizer:
   ref:`Apps/projectM-iOS/ProjectMApp.swift`#`case .visualizer:`.
3. Choosing a source prepares the renderer once. ANGLE is tried first, then the Apple-OpenGLES
   fallback: ref:`Apps/projectM-iOS/Coordinators/AppCoordinator.swift`#`private func prepareRenderer()`,
   ref:`Apps/projectM-iOS/Coordinators/AppCoordinator.swift`#`renderer = try ANGLERenderer.make()`,
   ref:`Apps/projectM-iOS/Coordinators/AppCoordinator.swift`#`renderer = try? GLESRenderer.make()`.
4. The renderer's `UIView` is hosted in SwiftUI through a `UIViewRepresentable`:
   ref:`Apps/projectM-iOS/Views/VisualizerView.swift`#`struct RendererHost: UIViewRepresentable`,
   ref:`Apps/projectM-iOS/Views/VisualizerView.swift`#`func makeUIView(context: Context) -> UIView { renderer.view }`.
5. The renderer contract is ProjectM-specific (PCM reader, presets):
   ref:`Packages/Rendering/Sources/Rendering/VisualizerRenderer.swift`#`public protocol VisualizerRenderer: AnyObject`,
   ref:`Packages/Rendering/Sources/Rendering/VisualizerRenderer.swift`#`func setPreset(_ preset: Preset) async throws`.

## 2. EGL display, config, context and surfaces

All in ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`public static func make() throws -> ANGLERenderer`:

| Step | Citation |
|---|---|
| Display on ANGLE's Metal platform | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`EGLAttrib(EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE)` |
| `eglGetPlatformDisplay` + `eglInitialize` | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`eglInitialize(display, nil, nil) == EGL_TRUE` |
| RGBA8, ES3, window+pbuffer config | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`EGL_SURFACE_TYPE, EGL_WINDOW_BIT | EGL_PBUFFER_BIT` |
| ES 3.0 context | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 0` |
| 1×1 pbuffer placeholder, made current | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`eglCreatePbufferSurface(display, config, pbuffer)` |
| Window surface on the `CAMetalLayer` | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`eglCreateWindowSurface(display, config, layer, nil)` |
| Layer: BGRA8, opaque | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`metalLayer.pixelFormat = .bgra8Unorm` |
| EGL types/constants declared from pinned ANGLE headers | ref:`Packages/ANGLERendering/Sources/CANGLE/include/CANGLE.h`#`#define EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE 0x3489` |

## 3. GL calls → ANGLE → Metal

* The engine and helpers resolve GL entry points through ANGLE's EGL resolver, not `dlsym`:
  ref:`Packages/ANGLERendering/Sources/CANGLE/CANGLE.c`#`return (void *)eglGetProcAddress(name);`.
* The engine is created with that load proc: ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`ProjectMEngine(glLoader: PMANGLELoadProc, userData: nil)`,
  bridged to ref:`Packages/ProjectMBridge/Sources/ProjectMBridge/PMBridge.mm`#`projectm_create_with_opengl_load_proc`.
* The Metal backend is selected at build time by the reference's ANGLE build (GN args
  `angle_enable_metal=true`, all other backends off; recorded in `Build/ANGLEFrameworks/ANGLE.json`,
  a gitignored output, and in `docs/architecture/projectm-reference-audit.json`). The script is
  ref:`scripts/build_angle_xcframework.py`#`angle_enable_metal=true`.
* The fallback path (not ANGLE) links Apple's OpenGLES through a static table:
  ref:`Packages/ProjectMBridge/Sources/ProjectMBridge/PMGLESLoader.m`#`PMAppleGLESLoadProc`.

## 4. Presentation and frame scheduling

* Frame: make the window surface current → feed PCM → engine renders to FBO 0 (or the flash
  limiter's FBO) → `eglSwapBuffers`: ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`func renderFrame(present: Bool = true, frameTime: Double = 1.0 / 60) -> Bool`,
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`eglSwapBuffers(display, surface)`.
* Scheduling: a `CADisplayLink` on the main run loop, started when the view joins a window and
  stopped when it leaves, through a weak proxy:
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`link.add(to: .main, forMode: .common)`,
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`private final class ANGLEDisplayLinkProxy: NSObject`.
* Frame-rate caps: 60 fps nominal, 30 fps under serious/critical thermal state or Low Power Mode,
  render scale 0.75 at critical:
  ref:`Packages/Rendering/Sources/Rendering/QualityGovernor.swift`#`return CAFrameRateRange(minimum: 30, maximum: cap, preferred: cap)`,
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`ProcessInfo.thermalStateDidChangeNotification`.

## 5. Threading and synchronization

* The renderer is `@MainActor`; every EGL/GL call of the visible renderer runs on the main thread:
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`public final class ANGLERenderer: NSObject, VisualizerRenderer`.
* A **second, unshared** EGL context on the same display, with its own engine, runs on a
  dedicated utility-QoS thread to warm Metal pipelines. It is synchronized only with an
  `NSCondition`-guarded queue and shares no GL objects:
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/PresetPrewarmer.swift`#`thread.qualityOfService = .utility`,
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/PresetPrewarmer.swift`#`private let condition = NSCondition()`.
* No GL fences or sync objects are used between the two contexts (none are needed; nothing is shared).
* The audio→render handoff is the lock-free normalized PCM reader read once per frame:
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`let frames = reader.read(into: pcm, maxFrames: maxFrames)`.

## 6. Resize and orientation

* `layoutSubviews` → `layoutSurface()`. When the pixel size changes, the placeholder is made
  current, the old window surface destroyed, a new one created, and the engine viewport set.
  Orientation is just a layout change: ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`private func layoutSurface()`,
  ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`engine?.setViewportWidth(Int(w), height: Int(h))`.

## 7. Lifecycle: pause/resume, teardown, recreation

* Background/lock → `suspendVisualization()` → `renderer.pause()` (display link paused); foreground →
  `resumeVisualization()` unless the user paused it:
  ref:`Apps/projectM-iOS/Coordinators/LifecycleCoordinator.swift`#`if visualizing, !suspended { visualization?.suspendVisualization() }`,
  ref:`Apps/projectM-iOS/Coordinators/AppCoordinator.swift`#`func suspendVisualization()`.
* Teardown (`isolated deinit`): stop prewarmer → invalidate display link → placeholder current →
  destroy flash limiter → release engine **while its context is current** → unbind → destroy
  surfaces and context: ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`engine = nil   // destroyed while its context is current (bridge guarantee 3)`.
* Prewarmer teardown happens on its own thread: ref:`Packages/ANGLERendering/Sources/ANGLERendering/PresetPrewarmer.swift`#`eglDestroyContext(display, context)`.
* **Recreation:** only the window surface is recreated (on resize). There is no context
  recreation path, no `eglTerminate`, and no context generation tracking.
  **Unknown U-F001** (owner: F02): behavior after a GPU/context loss
  (`EGL_CONTEXT_LOST`, Metal device removal) is not handled or tested in the reference; VisualCore
  adds forced recreation and generations.
  **Unknown U-F002** (owner: F02/F03): there is no memory-warning handling for GPU resources in the
  renderer; VisualCore defines budgets.

## 8. GPU resources and ownership (T-F009)

| Resource | Created / owned by | Cleanup | Citation |
|---|---|---|---|
| Engine shaders, textures, FBOs | projectM engine (LGPL) inside its own state | `projectm_destroy` with the context current | ref:`Packages/ProjectMBridge/Sources/ProjectMBridge/PMBridge.mm`#`projectm_destroy(_handle);` |
| Preset textures | engine, from search paths | engine | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`engine.setTextureSearchPaths(texturePaths)` |
| Flash-limiter program (ES 3.00 shaders), scene FBO + texture, adaptation textures | `CFlashLimiter`, created lazily with the context current | `PMFlashLimiterDestroy` in deinit | ref:`Packages/Rendering/Sources/CFlashLimiter/FlashLimiter.c`#`"#version 300 es\n"`, ref:`Packages/Rendering/Sources/CFlashLimiter/include/CFlashLimiter.h`#`void PMFlashLimiterDestroy(PMFlashLimiter *_Nullable limiter);` |
| Prewarm BGRA8 FBO + texture (256²) | prewarmer thread/context | `PMANGLEDeleteFramebuffer` on that thread | ref:`Packages/ANGLERendering/Sources/CANGLE/CANGLE.c`#`unsigned int PMANGLECreateBGRAFramebuffer(int width, int height, unsigned int *textureOut)` |
| Window surface / placeholder pbuffer | `ANGLERenderer` | `eglDestroySurface` in `layoutSurface()` and deinit | ref:`Packages/ANGLERendering/Sources/ANGLERendering/ANGLERenderer.swift`#`if let surface { eglDestroySurface(display, surface) }` |

There is no central resource registry or byte accounting. Ownership is implicit per component.
**Unknown U-F003** (owner: F03): GPU memory use per preset is not measured in the reference.

## 9. Existing automated evidence in the reference

The renderer tests run on a simulator with pixel readback, e.g.
ref:`Packages/ANGLERendering/Tests/ANGLERenderingTests/ANGLERendererTests.swift`#`func testCreatesAWindowSurfaceAtTheDisplayScale()`
and ref:`Packages/ANGLERendering/Tests/ANGLERenderingTests/ANGLERendererTests.swift`#`func testPauseAndResumeTheDisplayLink()`.
Their result on this Mac is in `docs/verification/projectm-baseline.md`.
