# Contract: render lifecycle, threading and frame pacing (FR-F104, FR-F114)

## States and transitions (executable: `RenderLifecycle.isAllowed`, host-tested in F02)

```text
uninitialized --context created--> surfaceReady --window surface ok--> active
active --suspend (background, lock, view leaves window)--> suspended --resume--> active
active|suspended|surfaceReady --surface lost / zero size / create failed--> surfaceInvalid
surfaceInvalid --layout with valid size--> active      surfaceInvalid --suspend--> suspended
surfaceReady|active|suspended|surfaceInvalid --recreateContext--> reinitialized
reinitialized --scene rebuilt + surface ok--> active | surfaceInvalid | suspended
any non-destroyed --destroy--> destroyed (terminal)
```

Any other transition returns `false`, increments `rejectedTransitions` and is recorded in the bounded
history (default 256 events). Observers get `(old, new, generation)` synchronously on the main thread.

## Generations

`generation` = 0 before the first context, +1 on entering `surfaceReady` or `reinitialized`. GPU
handles carry their generation; a handle from another generation is rejected (see `resources.md`).

## Threading

* Visible render context: main thread only (`@MainActor` host; debug `dispatchPrecondition`).
* Secondary contexts (e.g. warm-up): unshared, created, used and destroyed on one dedicated
  thread; no GL object crosses contexts.
* Scenes get a `RenderContext` only inside `setup`, `resize`, `render`, `teardown`.

## Frame pacing

`CADisplayLink` on the main run loop (common mode), started when the view joins a window, stopped
when it leaves. `preferredFrameRateRange = (min 30, max cap, preferred cap)`; cap = app `maxFPS`
(default 60) except 30 under thermal `serious`/`critical` or Low Power Mode; render scale 0.75 at
`critical`. Frame delta is clamped to ≤ 0.1 s.

## Teardown order

1. Stop warm-up threads; invalidate display link.
2. Make placeholder current; call `scene.teardown` (releases app GPU objects).
3. Release registry-owned resources; assert zero live handles (leak counter).
4. Unbind (`eglMakeCurrent(display, nil, nil, nil)`); destroy window surface, placeholder, context.

## Reconciliation with the audited reference (SC-F103)

| Reference stage (`docs/architecture/current-rendering-pipeline.md`) | Contract clause | Difference |
|---|---|---|
| §1 startup → `ANGLERenderer.make()` | `RenderHost.make()` → `surfaceReady` | none (no engine) |
| §2 EGL display/config/context/placeholder/window surface | identical sequence | none |
| §3 GL via `eglGetProcAddress` | full ES 3.0 table (`CVisualCoreGL`) | broader table, same resolver |
| §4 presentation + display link + quality caps | Frame pacing | identical caps |
| §5 main-thread renderer, unshared prewarm context | Threading | identical rule, generalized |
| §6 resize via `layoutSurface()` | `surfaceInvalid`/`active` on size change | explicit states |
| §7 pause/resume, deinit teardown | suspend/resume; Teardown order | adds leak assertion |
| §7 no context recreation (U-F001) | `recreateContext` → `reinitialized` | **intentional addition**, verified in F02 sim tests, device in campaign II |
