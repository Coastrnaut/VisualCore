# Data Model: Particle Universe — Phase 03 (A04-P03)

## VisualCore (public)

### TrailDecay (VisualCoreSimulation, enum namespace)

| Member | Meaning |
|---|---|
| `strengthRange = 0...0.98` | fraction kept per 1/60 s |
| `factor(strength:delta:) -> Double` | `s^(delta·60)`; delta ≤ 0 or non-finite → 1; strength clamped, non-finite → 0 |
| `step8(_ value: UInt8, factor: Double) -> UInt8` | predicted 8-bit result `max(0, round(v·f − 1))` |

### ParticleSystem.liveCount(source:) (VisualCoreSimulation)

Live particles spawned by emitter index `source` (0 for an out-of-range index).

### ParticleBlend (VisualCoreRendering)

`.normal` (premultiplied over, default) and `.additive` (ONE, ONE). `ParticleRenderer.draw(_:camera:metrics:blend:)`.

### TrailLayer (VisualCoreRendering, `@MainActor final class`)

| Member | Rule |
|---|---|
| `static maxEdge = 2048` | the longer edge is scaled down to it, keeping the aspect |
| `init(registry:width:height:) throws` | creates an RGBA8 `PingPongTarget` (cleared) and two `FieldPass`es |
| `width`, `height` | actual target size |
| `strength` | 0…0.98 (clamped) |
| `brightnessCap` | 0…1 (clamped, default 1) |
| `clear()` | zeroes both targets |
| `frame(delta:draw:output:) throws` | decay → `draw(writeTarget)` → composite to `output` (`FieldPass.Output`) with the cap → swap |
| `release()` | releases the targets and passes; idempotent |

### ParticleLayerScene additions

`blend: ParticleBlend` (default `.normal`), `trailStrength` (0, clamped), `brightnessCap` (1, clamped),
`clearTrails()`, `trailLayer` (read-only, for diagnostics and tests). The layer is in use when
`trailStrength > 0 || brightnessCap < 1`.

## App core

### SceneEmitter (extended; schema 1)

| Field | Type | Rule |
|---|---|---|
| `size` | `Double?` | 1…48 world units (start diameter; the end keeps the family's end/start ratio) |
| `lifetime` | `Double?` | 0.2…8 s; particles live 0.8…1.2 × it |
| `gradient` | `String?` | a `Palette.builtIns` id; start = `sample(1)` α 1, end = `sample(0.5)` α 0 |

Validation: finite and in range, known palette id → else `SceneError.invalidEmitter(i)`. `clampedOverrides` helpers
are used for UI input.

### SceneSimulation additions

- `visibleEmitters: [SceneEmitter]`;
- `addEmitter(_:) -> Bool` (false while all 8 slots are busy);
- `canAddEmitter`;
- `removeEmitter(at:) -> Bool` (false for the last one);
- `setEmitter(at:_:)` (family and overrides; position kept);
- `retiredSlots`;
- `rebuildScene() -> ParticleScene`.

### Slot state transitions

`visible → retired` (on removal; emitting off) → `free` (no live particles) → `visible` (reused by add).
