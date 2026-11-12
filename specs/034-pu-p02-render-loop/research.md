# Research: Particle Universe — Phase 02 (A04-P02)

All NEEDS CLARIFICATION items were resolved by the spec's five clarifications (2026-11-11). This file records the
read-only audit and the remaining design decisions.

## R0. Read-only audit of the APIs this phase uses (2026-11-11)

| API | File | Fact used |
|---|---|---|
| `ParticleForce` (`gravity`, `drag`, `attractor`) | `Packages/VisualCore/Sources/VisualCoreSimulation/ParticleSystem.swift` | switch only inside `ParticleSystem.step`; attractor skips `d ≤ 1e-9` |
| `ParticleSystem.spawn` | same | drops when `aliveCount ≥ capacity`, counting `droppedCount` |
| `QualityPolicy` | `Packages/VisualCore/Sources/VisualCoreDiagnostics/QualityPolicy.swift` | `decide(thermal:lowPower:now:)`, hysteresis, `lowPowerCeiling` = best tier under Low Power |
| `FramePacing.Thermal` | `.../VisualCoreDiagnostics/FramePacing.swift` | `nominal, fair, serious, critical`, raw values match `ProcessInfo.ThermalState` |
| `ParticleRenderer` | `Packages/VisualCoreRendering/Sources/VisualCoreRendering/ParticleRenderer.swift` | `draw(_:camera:metrics:)`, size = diameter in world units, premultiplied blend, rebuilds program on generation change |
| `RenderScene`, `FrameInfo` | `.../VisualCoreRendering/RenderScene.swift` | setup/resize/render/teardown on the main actor; `delta` clamped 0…0.1 |
| `RenderHost` | `.../VisualCoreRendering/RenderHost.swift` | `init(scene:)`, `addErrorObserver`, `renderOffscreen`, `recreateContext`, `readPixels`, `pause`/`resume` |
| `Camera2D`, `ViewMetrics` | `Packages/VisualCore/Sources/VisualCoreMath/Camera2D.swift`, `.../VisualCoreScenes/ViewMetrics.swift` | `worldToNDC(camera:)` = scale(2/size) · camera.matrix; `toWorld(_:camera:)` |
| `RenderSurface` | `Packages/VisualCoreRendering/Sources/VisualCoreUI/RenderSurface.swift` | `init(host:accessibilityLabel:accessibilityHint:)` |
| `ProcessInfo` reads | `Apps/FluidArtPlayground/App/PlaygroundView.swift:47`, `FrameScheduler.swift:31` | the A02 app and the frame scheduler each read thermal/Low Power themselves → `DeviceConditions` gives one reader |
| A01 particles | `Apps/GenerativeArtStudio/App/ParticlesArtScene.swift`, `Core/.../ParticleReplay.swift` | uses `gravity` and `drag` only; app-local scene around `ParticleRenderer` (pattern for `ParticleLayerScene`) |

No public exhaustive `switch` over `ParticleForce` exists outside `ParticleSystem.step` (grep of `Apps`, `Harnesses`,
`Packages`), so adding cases is source-compatible.

## R1. Clamping without changing existing results

- **Decision:** `clamped()` range-clamps the four new cases to the clarified limits. For the existing cases it maps
  non-finite numbers to 0 and applies wide "legacy" ranges (gravity components and attractor strength ±1e6, drag
  0…1e6, attractor radius 0…1e12, centers ±1e12) that no existing scene approaches (A01: gravity ±400, drag ≤ 2), so
  their values pass through bit-for-bit. Implementation note (T-A04-202): the first version passed every finite
  value through and failed FR-A04-202 for values near 1e300 (an infinite bound), hence the legacy ranges. Wind is
  scaled through its largest component (no overflow) to just under 2,000 so clamping is idempotent. `step` clamps the force list **once per step** (`forces.map { $0.clamped() }`), then runs
  the unchanged per-particle arithmetic for the old cases.
- **Rationale:** A01, `VisualCoreBaselines`, the harnesses and `replay-v1.json` use only valid old-case values, so their
  checksums cannot change. Every case still has a finite bound (gravity |g|, drag k·|v|, attractor |s|).
- **Alternatives:** range-clamping the old cases too (risks A01 values outside new ranges); clamping per particle
  (wasteful, same result).

## R2. Force formulas (spec clarification 1)

With `d = point − position`, `r = |d|`:
- **repulsor:** for `1e-9 < r < radius`: `a = −s · (1 − r/radius) · d/r`; else 0. Bound `|s|`.
- **gravityWell:** `a = s · d / (r² + ε²)^{3/2}`; at the center `d = 0` gives 0 exactly. Bound `2s/(3√3·ε²)` (maximum
  of `r/(r²+ε²)^{3/2}` at `r = ε/√2`).
- **wind:** `a = rate · (w − v)`. Bound `rate · (|w| + |v|)`, so `bound(speed:)` takes the particle speed (0 for others).
- **vortex:** with `o = −d` (position − point), for `1e-9 < r < radius`: `a = s · (1 − r/radius) · (−o.y, o.x)/r`
  (counter-clockwise for `s > 0`); else 0. Bound `|s|`.

Floating-point: the falloff factor is in [0, 1] and the unit vector has length ≤ 1 + 1 ulp; tests compare against
`bound · (1 + 1e-12)`.

## R3. Particle budget formula vs. the "minimum" edge case

- **Decision:** the clarified formula is binding: `limit = min(requested, max(minimum, ⌊requested × share⌋))`, tier
  clamped to `0…shares.count − 1`, `requested ≤ 0` gives 0. A requested limit below 100 therefore stays at the
  requested value (never above it, SC-A04-203); the sandbox's scene limit range is 100…20,000, so the minimum 100
  is always reachable there. The spec's edge case "uses the minimum (100)" is read as "never drops below 100 unless
  less was requested".
- **Rationale:** the spec's P1 rule "the person's requested limit is never exceeded" outranks an edge-case wording.

## R4. Live limit semantics

- **Decision:** `ParticleSystem.liveLimit` (public get/set, stored clamped to 1…capacity, default capacity). `spawn`
  drops when `aliveCount ≥ min(capacity, liveLimit)`. Lowering it removes nobody. It is not part of `checksum()`
  (state, not configuration), so default behavior is bit-identical.

## R5. DeviceConditions on every platform

- **Decision:** `DeviceConditions { thermal: FramePacing.Thermal; lowPower: Bool }` with `static func current()`
  reading `ProcessInfo.processInfo.thermalState` and `isLowPowerModeEnabled` under `#if canImport(Darwin)`; elsewhere
  it returns nominal / false. Public `ProcessInfo` API only.
- **Alternatives:** keep per-app readers (duplicated in A02 and A04); put it in VisualCoreRendering (it has no GPU
  dependency, so Diagnostics is right, rule R1).

## R6. ParticleLayerScene fit and frame source

- **Decision:** `ParticleLayerScene(world: WorldRect, background: Vec4, source: @MainActor (FrameInfo) -> [ParticleInstance])`.
  `WorldRect` is center + size. For a drawable of `w × h` pixels, `camera(forPixelWidth:height:)` returns
  `Camera2D(center: world.center, zoom: min(w/W, h/H))` used with `ViewMetrics(size: (w, h), scale: 1)` — aspect fit, y
  up. Public static `fit(world:viewSize:)`, `worldPoint` and `viewPoint` let the app map tap points with the same math.
  Implementation note (T-A04-212): the fit scale is carried by `ViewMetrics` (camera zoom 1), because
  `Camera2D.zoom` is clamped to 0.1…100 and a 1,000-unit world in a small view would need less. Errors from the renderer's creation are kept in `lastError` and rethrown from `render` so the host
  reports them (`RenderHostError.scene`).
- **Rationale:** reusable by A09 (aquarium) and A19 (wallpapers); the app writes no GL.

## R7. Frame driving and fallback in the app

- **Decision:** GPU path: the scene's source closure calls `SceneModel.gpuFrame(_:)`, which advances by
  `frame.delta` while playing, runs the quality decision with `frame.time`, and returns the particle copy. CPU path:
  unchanged `TimelineView` → `frame(at:)`. `rendererMode` selects which one is shown; a `RenderHost` init throw or a
  non-`contextLost` error switches to `.cpuFallback`. The renderer status text says "Renderer: GPU" or "Renderer: CPU
  preview (<reason>)".
- **Quality clock (T-A04-219):** quality decisions use one monotonic clock, `ProcessInfo.systemUptime`, on both the
  GPU and the CPU path, instead of the host frame time or the preview's dates named in the plan. Reason: the time base
  stays the same when the screen falls back from the GPU to the CPU preview, so `QualityPolicy`'s decision interval
  and calm period never jump. The simulation itself still advances by each path's frame time.
- **Feature 033 lesson:** per-frame state is read only in small leaf views (counts, effective limit, force text), so
  the controls are not rebuilt per frame.

## R8. Placement input

- **Decision:** a transparent SwiftUI overlay with `DragGesture(minimumDistance: 0)` over the square stage: first
  touch places (or moves) the force, changes move it. Points map to world through `ParticleLayerScene.worldPoint` and
  `ViewMetrics.toWorld`, then clamp to the world square −500…500. Controls: kind menu, Center, four 50-unit nudges,
  strength slider 0.1…2. Wind's direction is from the world center toward the force position; at the exact center it
  blows toward +x.

## R9. UI test seams

- **Decision:** `DeviceConditionsSource` reads `UserDefaults` keys `uitestThermal` (`nominal|fair|serious|critical`)
  and `uitestLowPower` (bool) from launch arguments under `#if DEBUG` only; Release compiles to
  `DeviceConditions.current()`. The quality UI test launches with `-uitestThermal serious` and waits for the effective
  limit to fall below 4,000 (first decision steps down at once, spec clarification 5).
