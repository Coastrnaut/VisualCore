# Contract: RenderHost lifecycle and threading (FR-F001–FR-F009)

## States and transitions

```text
uninitialized --start()/context ok--> surfaceReady --window surface ok--> active
active --suspend() (background, view removed)--> suspended --resume()--> active
active|suspended --surface lost / zero size / create failed--> surfaceInvalid
surfaceInvalid --layout with valid size--> active
any(non-destroyed) --recreateContext()--> reinitialized --scene.rebuild ok--> active
any --destroy()--> destroyed (terminal)
```

Any other transition is a programming error: `RenderLifecycle.transition(to:)` returns `false` and
records it. Observers receive `(old, new, generation)` synchronously on the main thread.

## Threading

* The host is `@MainActor`. Every EGL/GL call happens on the main thread
  (`dispatchPrecondition(.onQueue(.main))` in debug). Scenes receive `RenderContext` only inside
  `setup`, `render`, `resize`, `teardown` callbacks.

## Generations

* `generation` starts at 1 at first context creation and increments on each recreation.
* `GPUHandle { kind, name, bytes, generation }`; using a handle whose generation ≠ current is
  rejected (`ResourceRegistry.stale` counter) and never reaches GL.

## Scene protocol

```swift
@MainActor public protocol RenderScene: AnyObject {
    func setup(_ context: RenderContext) throws      // create programs/buffers (current generation)
    func resize(_ context: RenderContext, size: PixelSize)
    func render(_ context: RenderContext, frame: FrameInfo)  // draw to context.targetFramebuffer
    func teardown(_ context: RenderContext)          // context current; release GPU objects
}
```

`FrameInfo { index, time, delta (clamped ≤ 0.1 s), targetTimestamp }`.

## Frame pacing

`preferredFrameRateRange` = (min 30, max cap, preferred cap); cap = `maxFPS` (default 60) unless
`ProcessInfo.thermalState ≥ .serious` or Low Power Mode, then 30.

## Test hooks

`renderOneFrame(present:)`, `readPixels() -> [UInt8]` (RGBA, bottom-up rows), `forceRecreate()`,
`capabilities`, `lifecycle.history`.
