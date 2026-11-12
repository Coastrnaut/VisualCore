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
| VisualCoreUI | `RenderSurface` (SwiftUI host for a caller-owned `RenderHost`); diagnostics overlay and accessibility helpers planned |
| VisualCoreAudio | AVAudioEngine microphone / in-app playback taps → DSP features |
| VisualCoreAutomation | AutomationRunner (`DEBUG \|\| VISUALCORE_AUTOMATION` only) |
| VisualCoreExperienceHost | the main-actor part of the experience contract: `ExperiencePresenter`, `ExperienceActionPort`, `ExperienceShell` and the type-erased `Experience` (UA-F02); `ExperienceSession` and `ExperienceHostView`: one experience at a time on one render host (UA-F03) |

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
peak, stale rejections, leaks, shader failures and deduplicated warnings. The budget is a `ResourceBudget`
(256 MiB total by default, optional per-kind caps) passed as `RenderHost(scene:budget:)`; a small budget is an easy
way to test a scene's over-budget path. Shader sources are GLSL ES 3.00
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
| `ParticleRenderer` | `[ParticleInstance]` (≤ 100,000) | instanced soft-edged quads, size = world diameter; `ParticleBlend` `.normal` (default) or `.additive` (feature 035) |
| `ParticleLayerScene` (feature 034) | a `RenderScene`: background + `[ParticleInstance]` from a source closure per frame | aspect-fits a `WorldRect` (y up) with `fit(world:viewSize:)`; `worldPoint`/`viewPoint` map taps with the same fit; feature 035: `blend`, `trailStrength`, `brightnessCap`, `clearTrails()` |
| `TrailLayer` (feature 035) | a fading trail image on an RGBA8 `PingPongTarget` | `frame(delta:output:draw:)`: decay (`TrailDecay`), draw on top, composite over `background` with `brightnessCap`; longer edge ≤ 2,048; `clear()`, `release()` |
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
one mode; these results are rehearsals, not device evidence. `AutomationView(mode:bundleID:makeScene:configure:)` (feature 017) hosts any scene full screen and runs the mode
after the first layout. Each app uses it from a `#if DEBUG || VISUALCORE_AUTOMATION` branch of its root view, as
`Showcase/App/ShowcaseAutomation.swift` does. If no renderer can be created it still writes a `renderer-unavailable`
report.

## Shader bundles, the GLSL library and full-screen scenes (feature 012, A01-P01)

`ShaderBundle(bundle:subdirectory:)` loads an app's `.vert`, `.frag` and `.glsl` files (default folder `Shaders`). Use
`ShaderBundle(files:)` for in-memory sources. Its `library` also contains the **VisualCore GLSL library**, included
with:

```glsl
#include "vc/hash.glsl"     // vc_pcg, vc_hash11, vc_hash21, vc_hash22
#include "vc/noise.glsl"    // vc_valueNoise, vc_gradientNoise, vc_fbm(p, octaves, lacunarity, gain)
#include "vc/palette.glsl"  // uniform vec3 u_palette[8]; uniform int u_paletteCount; vc_palette(t) (linear light)
#include "vc/sdf.glsl"      // vc_sdSphere, vc_sdBox, vc_sdTorus, vc_smoothUnion, vc_rotate
#include "vc/color.glsl"    // vc_srgbEncode, vc_srgbDecode (exact transfer functions)
```

Every library file has an include guard, so a file may be included more than once.

`FullScreenShaderScene(fragmentName:bundle:)` draws one fragment shader over the view. The vertex shader gives
`in vec2 v_uv`. The scene binds whichever of these the shader declares:
- `u_time`: `fixedTime`, else frame time × `timeScale`;
- `u_resolution`;
- `u_seed`: `seedOffsets`;
- `u_palette`/`u_paletteCount`: `palette`, linear stops;
- one float `u_<name>` per entry in `parameters`.

Compile errors do not throw. `errorMessage` becomes `file:line: message`, and the view clears to dark gray.
`ShaderProgram.set(_:vec3Array:)` writes `vec3` array uniforms up to their declared size.

`RenderSurface(host:accessibilityLabel:accessibilityHint:)` (VisualCoreUI) shows a host's view in SwiftUI as one
accessible image element. The screen that created the host destroys it.

`ParameterPanel(editor:)` (VisualCoreUI, feature 013) is a SwiftUI `Section` for any `ParameterEditor` binding. Each row
shows the title, the value with its unit, a slider over the normalized position (logarithmic parameters move by ratio)
and a reset button when the value is modified; a "Reset all" button follows the rows. VoiceOver reads the title as
the label and the formatted value as the value, and increment/decrement move by 5%. Identifiers are
`vc.param.<name>`, `vc.param.<name>.reset` and `vc.param.resetAll`. `ParameterPanelModel.rows(_:)` exposes the same
content for tests.

## Offscreen still export (feature 015, A01-P04)

`host.renderOffscreen(width:height:time:)` renders the host's current scene at any size on the host's own context
(no second context) and returns a `StillImage`: RGBA8, rows top-down. The scene gets a `RenderContext` redirected to
a registry render target, with `FrameInfo.time` = `time` and `delta` 0. Afterwards the target is released and the
scene is resized back to the live surface, also when the export fails. A failure throws `OffscreenRenderError`
(`.unavailable`, `.invalidSize`, `.resource`, `.scene`, `.readback`) and never marks the live scene failed.

- `host.maxRenderSize` is the smallest of the max texture, renderbuffer and viewport sizes. Sizes above it, or above
  64 million pixels (`RenderHost.maxOffscreenPixels`), are refused before any GPU work.
- `StillImageEncoder.pngData(_:)` writes an opaque PNG tagged sRGB (alpha is dropped).
- Scenes that size content in points (for example particles) should scale it for the export's pixel size; shader
  scenes that use `u_resolution` need nothing.

```swift
let size = ExportGeometry(maxEdge: host.maxRenderSize).size(longEdge: 2048, aspect: .portrait)   // 1638 × 2048
let png = try StillImageEncoder.pngData(host.renderOffscreen(width: size.width, height: size.height, time: 4.0))
```

## Ping-pong fields, field passes and half-float targets (feature 019, A02-P01)

These pieces are for GPU simulations and feedback effects that read the previous state and write the next one.

- `FloatRenderSupport.detect(in: context.resources)` reports whether the context lists a color-buffer float
  extension and whether a 4×4 RGBA16F probe target works; `supported` requires both. The result is cached per
  context generation, and the probe target is released. `storageFormat(forceFallback:)` returns `.rgba16f`, or the
  RGBA8 fallback. With RGBA8, store signed values with `VisualCoreSimulation.SignedRangeEncoding`. Size grids within
  `context.resources.maxTextureSize` (the context's `GL_MAX_TEXTURE_SIZE`).
  `RenderCapabilities.reportsColorBufferHalfFloat` is the extension half alone.
- `RenderTarget.upload(rgbaFloats:)` and `readFloatPixels()` move exact RGBA floats in both directions, rows
  bottom-up. RGBA8 is quantized to n/255. Use them to seed fields and to compare them with a CPU reference
  (`FieldGrid`, `StoragePrecision`).
- `PingPongTarget` holds two equal targets. Passes sample `read`, draw into `write`, then `swap()`. Both targets are
  budget-accounted (`bytes`), `release()` is idempotent, and `isValid` turns false after a context recreation.
- `FieldPass` compiles a fragment against `FullScreenShaderScene.vertexSource` (`in vec2 v_uv`) with named
  `sampler2D` inputs. `run(output:inputs:uniforms:)` checks everything before drawing:
  - exactly the declared inputs are supplied;
  - no input is the output (`inputIsOutput`);
  - uniforms are active and of the right type;
  - nothing is stale.

  `run(pair:input:)` steps a `PingPongTarget` and swaps only on success. Passes built from the same source share one
  cached program, so create one pass per source.
- `FieldPass.runObserver` (feature 022, nil by default) receives a `FieldPass.Run` (label, output texture or
  framebuffer, input textures) for every validated run, just before it draws. Tests can use it to prove across whole
  frames that no pass samples its output.
- `#include "vc/field.glsl"` in a field pass (passes resolve VisualCore includes by default through
  `ShaderBundle.visualCoreIncludes`, or take `library:`) provides two functions (feature 020):
  - `vc_fieldTexel(f, cell)`: a clamped `texelFetch`;
  - `vc_fieldBilinear(f, cellCoord)`: exact bilinear sampling with cell centers at `i + 0.5`. It uses the same
    arithmetic as `FieldGrid.sampleBilinear`, so semi-Lagrangian advection matches a CPU reference. Hardware LINEAR
    filtering cannot do that, because of its reduced sub-texel precision.

```swift
let format = FloatRenderSupport.detect(in: context.resources).storageFormat()
let dye = try PingPongTarget(registry: context.resources, width: 128, height: 128, format: format, label: "dye")
let fade = try FieldPass(registry: context.resources, fragment: fadeSource, inputs: ["uField"], label: "fade")
try fade.run(pair: dye, input: "uField", uniforms: ["uFactor": .float(0.98)])   // reads dye.read, writes, swaps
```

## Accessibility settings and effect bypass (feature 016, A01-P05)

`SystemAccessibilityObserver` (VisualCoreUI, `@Observable`) publishes `current: SystemAccessibility`. Its values come
from `UIAccessibility.isReduceMotionEnabled` and `MADimFlashingLightsEnabled()`, and it refreshes on their public
change notifications. Pass `source:` to supply fixed values in tests. Combine it with
`AccessibilityPreferences.resolve` to get the effective settings. Reading these flags needs no permission.

`EffectScene.bypassEffects` draws the content straight into the host framebuffer, skips the graph and the
Reduce-Flashing limiter, and leaves the renderer's state alone. Wrap a scene once and set
`bypassEffects = !reduceFlashing`: the default path then costs nothing, and the limiter does not jump when it comes
back. Set it to true around `renderOffscreen` so a still export is not limited.

`AccessibilitySettingsSection(preferences:system:identifierPrefix:)` is a ready-made form section: System/On/Off
pickers for both settings and a full-contrast row that explains them and shows the device setting. It was built to
pass the system accessibility audit at default and the largest text sizes. `AccessibleColors.accent` (#0040DD light,
#409CFF dark) keeps tinted text at ≥ 4.5:1 contrast, and `AccessibleColors.contrastRatio` computes WCAG ratios.

## Canvas gestures in navigation stacks (feature 020, A02-P02)

Since iOS 26, a navigation stack also pops on a horizontal swipe anywhere in its content. On a canvas where people
draw or paint with drags, a rightward stroke would leave the screen; this was observed on the iOS 26.5 simulator.
Apply `.contentSwipeBackDisabled()` to the canvas screen. It turns off only
`interactiveContentPopGestureRecognizer` while the screen is visible and restores the previous setting when it
disappears. The edge swipe and the back button keep working.

## Acknowledgements (feature 017, A01-P06)

`scripts/bundle_licenses.py --out <bundle>/Licenses` (run as a build phase) writes the license text of every
`scope: shipped` component in `docs/legal/third-party.json`, plus a `licenses.json` index. `AcknowledgementsView`
(VisualCoreUI) lists them with their licenses, and each row opens the full, selectable text. `LicenseInventory` loads
the index. `scripts/check_app_release.py` verifies that every shipped component is bundled when the app's
`release.json` sets `"licenses": true`.

## Experience shell (feature 188, UA-F02)

The main-actor part of an experience is a class that conforms to `ExperiencePresenter`: it creates its GPU objects
through the registry in `setup`, releases them in `teardown`, and draws the core it is handed. `draw` receives the
core as a value, so drawing cannot change the state. `ExperienceShell` joins a presenter with the pure
`ExperienceEngine` of its core and offers one type-erased face, `Experience`, to whoever owns the render host.

```swift
let shell = ExperienceShell(id: myID, presenter: MyPresenter())
try await shell.prepare(seed: 42, timeLimit: .seconds(10))   // the core's preparation runs off the main actor
let host = try RenderHost(scene: shell.scene)                // the owner creates the host; the shell never does
try shell.activate()                                         // frames now run fixed steps, then draw
// …
try shell.beginDeactivation()                                // nothing but teardown reaches the presenter now
host.destroy()
try shell.finishDeactivation()                               // inactive, or failed with experience.gpu-leak
```

Controls built by the presenter send actions through `ExperienceActionPort` (`send`, an observable `revision` and
the state description for assistive technology; identifiers start with the catalog's accessibility prefix). An
error of preparation, setup or drawing moves the lifecycle to failed and stays readable in `shell.diagnostics`.
Contract: [experience-host-api.md](../../specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md).

## Experience session (feature 189, UA-F03)

`ExperienceSession` opens and closes experiences for the whole app. It builds the experience from a factory,
prepares it, creates the one `RenderHost` with the experience's budget, activates it, and on every exit destroys
the host and checks that no GPU object is live or leaked.

```swift
let session = ExperienceSession(snapshotSink: { snapshot in try store.save(snapshot) })
let result = await session.open(ExperienceOpenRequest(id: id, seed: 42) {
    ExperienceShell(id: id, presenter: MyPresenter())
})                                         // .running, .suspended, .failed, .cancelled or .superseded
session.setScenePhase(.background)         // suspends, pauses the host, hands a snapshot to the sink
session.setScenePhase(.active)             // resumes without catching up
session.close()                            // stop clock, snapshot, deactivate, destroy host, count objects, idle
```

`ExperienceHostView(session:)` shows the canvas with the experience's controls, a preparing view with Cancel, a
failure view with Retry and Back, and a message view. A failure of preparation, setup or drawing never takes the
app down: the session is failed, the failure is in `session.diagnostics`, and any experience can be opened next.
A memory warning sheds caches; when the live bytes are still above the memory-pressure limit, the experience is
closed with a message. Texts come from the module's string catalog (`SessionStrings`).
Contract: [session-api.md](../../specs/189-ua-f03-experience-host/contracts/session-api.md).
