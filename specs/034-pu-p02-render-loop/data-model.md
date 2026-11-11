# Data Model: Particle Universe — Phase 02 (A04-P02)

## VisualCore (public)

### ParticleForce (VisualCoreSimulation, extended enum)

| Case | Parameters | Clamp (`clamped()`) | `bound(speed:)` |
|---|---|---|---|
| `gravity(Vec2)` (existing) | acceleration | non-finite → 0; components ±1e6 | `|g|` |
| `drag(Double)` (existing) | k | non-finite → 0; 0…1e6 | `k · speed` |
| `attractor(point:strength:radius:)` (existing) | point, s, r | non-finite → 0; s ±1e6; r 0…1e12 | `|s|` |
| `repulsor(point:strength:radius:)` | point, s, r | s ±10,000; r 1…2,000 | `|s|` |
| `gravityWell(point:strength:softening:)` | point, s, ε | s 0…1e9; ε 1…500 | `2s/(3√3·ε²)` |
| `wind(velocity:rate:)` | w, rate | |w| ≤ 2,000 (scaled down); rate 0…10 | `rate · (|w| + speed)` |
| `vortex(point:strength:radius:)` | point, s, r | s ±10,000; r 1…2,000 | `|s|` |

Non-finite point components become 0 and centers are clamped to ±1e12 in every case. Public constants: `ParticleForce.strengthLimit = 10_000`,
`gravityWellStrengthLimit = 1e9`, `radiusRange = 1...2_000`, `softeningRange = 1...500`, `rateRange = 0...10`,
`maxWindSpeed = 2_000`, `legacyLimit = 1e6`, `maxCoordinate = 1e12`. `acceleration(at:velocity:) -> Vec2` evaluates one (already clamped) force — used by tests and
by the new cases in `step`.

### ParticleSystem.liveLimit (VisualCoreSimulation)

`Int`, clamped to 1…capacity on set, default `capacity`. Emission stops while `aliveCount ≥ liveLimit`; each refused
particle increments `droppedCount`. Not part of `checksum()`.

### ParticleBudget (VisualCoreDiagnostics)

| Field | Type | Default (`.standard`) |
|---|---|---|
| `shares` | `[Double]`, each clamped 0…1, non-empty | `[1, 0.6, 0.35, 0.2]` |
| `minimum` | `Int` ≥ 0 | 100 |

`limit(requested:tier:) = min(requested, max(minimum, ⌊requested × shares[clamp(tier)]⌋))`; `requested ≤ 0` → 0.

### DeviceConditions (VisualCoreDiagnostics)

`thermal: FramePacing.Thermal`, `lowPower: Bool`; `init(thermal:lowPower:)`; `static func current()`; `static let
nominal`.

### ParticleLayerScene (VisualCoreRendering, `@MainActor final class`, `RenderScene`)

| Member | Meaning |
|---|---|
| `struct WorldRect { center: Vec2; size: Vec2 }` | world area that must stay visible (aspect fit) |
| `init(world:background:source:)` | `source: @MainActor (FrameInfo) -> [ParticleInstance]` |
| `var world`, `var background` | settable between frames |
| `static func fit(world:viewSize:) -> (camera: Camera2D, metrics: ViewMetrics)?` | aspect fit for a view size (points or pixels); the camera keeps zoom 1 and the metrics carry the fit scale, so `Camera2D.zoomRange` never limits it (T-A04-212) |
| `static func worldPoint(_:viewSize:world:)`, `viewPoint(_:viewSize:world:)` | tap mapping and projection with the same fit |
| `lastInstanceCount`, `lastError` | diagnostics for the app and tests |

Lifecycle: `setup` creates a `ParticleRenderer`; `render` clears to `background`, calls `source(frame)`, draws;
`teardown` releases. A context recreation calls teardown then setup (VisualCore host contract).

## App core (ParticleUniverseCore)

### SceneForce (extended, schema 1)

New cases `repulsor(x:y:strength:radius:)`, `gravityWell(x:y:strength:softening:)`, `wind(vx:vy:rate:)`,
`vortex(x:y:strength:radius:)`. Validation: all values finite; ranges equal the VisualCore clamp ranges (radius
1…2,000, softening 1…500, |strength| ≤ 10,000 or 0…1e9, rate 0…10, |w| ≤ 2,000) → `SceneError.invalidForce(i)`.

### PlacedForce (runtime only)

| Field | Type | Rule |
|---|---|---|
| `kind` | `PlacedForceKind`: attractor, repulsor, gravityWell, wind, vortex | `CaseIterable`, `title`, `spokenName` |
| `position` | `Vec2` | clamped to −500…500 per axis; non-finite rejected (keeps old) |
| `strength` | `Double` multiplier | clamped 0.1…2, non-finite ignored, default 1 |

`particleForce` uses the clarified defaults × multiplier: attractor 300/r300, repulsor 400/r250, gravity well
2,000,000/ε40, wind 120 u/s (center → position, +x at center)/rate 0.8, vortex 250/r300.

### SceneSimulation additions

- `setPlacedForce(_ force: PlacedForce?)` — places, replaces or removes `system.forces[0]`; scene forces follow at
  index 1… when a placed force exists (`moveAttractor` indices are offset accordingly). `placedForce` getter.
- `setLiveLimit(_:)`, `liveLimit`.

### SceneQuality

`QualityPolicy(tierCount: 4, lowPowerCeiling: 1)` + `ParticleBudget.standard`;
`mutating update(conditions:now:requested:) -> Int` returns the effective limit; `tier` getter.

## State transitions

- Placed force: none → placed (tap/Center) → moved (drag/nudge) → kind changed (position kept) → none.
- Quality tier: 0 ⇄ 3 by `QualityPolicy` (down at once when hot, up after the 10 s calm period, ≥ 2 s apart).
- Renderer mode: gpu → cpuFallback(reason) (one-way for the screen's lifetime).
