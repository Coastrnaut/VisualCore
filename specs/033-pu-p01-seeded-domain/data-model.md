# Data model: Particle Universe — Phase 01

## VisualCore (VisualCoreSimulation)

### EmitterShape (enum, Sendable, Equatable, Codable)

| Case | Fields | Sampling (offset from `Emitter.position`) |
|---|---|---|
| `point` | — | (0, 0); no random draw |
| `line(halfLength:angle:)` | half length ≥ 0 (world units), angle (rad) | u = random.double(); offset = (2u − 1)·halfLength·(cos angle, sin angle) |
| `ring(radius:)` | radius ≥ 0 | θ = 2π·random.double(); offset = radius·(cos θ, sin θ) |

### EmitterBurst (struct, Sendable, Equatable, Codable)

- `count`: Int, 1…5,000.
- `interval`: seconds, 1/60…60.

### Emitter (extended)

- New field `shape: EmitterShape = .point`.
- New field `burst: EmitterBurst? = nil`.
- New function `clamped() -> Emitter`:
  - non-finite values → the default;
  - rate 0…20,000; lifetime 0.01…3,600 (ordered; widened from 60 during T-A04-102 for the baselines’ 100 s); speed 0…10,000 (ordered); sizes 0…512; spread 0…2π;
  - half length and radius 0…10,000; burst count 1…5,000; interval 1/60…60.

### FixedStepSimulation (protocol)

- `mutating func step(_ dt: Double)`.
- `func checksum() -> UInt64`.
- `ParticleSystem` conforms.

### ControlStream<Command> (struct, Sendable where Command: Sendable)

- `entries`: [(step: Int, command: Command)], sorted stably by step; negative steps are dropped.
- `commands(at step:)`: returns the entries for that step, in insertion order.

### FixedStepRunner<S: FixedStepSimulation, Command>

- **Fields:**
  - `simulation: S`;
  - `clock: FixedStepClock`;
  - `stepIndex: Int` (steps completed);
  - `isPaused: Bool`;
  - `stream: ControlStream<Command>`;
  - `apply: (inout S, Command) -> Void`.
- **State transitions:** running ⇄ paused (`pause()` and `resume()`; resume calls `clock.resetAccumulator()`).
- **Operations:**
  - `advance(frame dt:) -> Int`: returns 0 when paused, otherwise `clock.advance(by:)` steps, each applying that
    step's commands first;
  - `stepOnce()`: a single step regardless of pause;
  - `run(steps:)`: n steps with no clock.

## App (ParticleUniverseCore)

### EmitterFamily (enum String, CaseIterable, Codable)

The cases are `fountain`, `curtain`, `halo` and `firework`. Each has:
- `title` and `spokenDescription`;
- `emitter() -> Emitter`, with the parameters from spec clarification 4;
- `forces() -> [ParticleForce]`.

### ParticleScene (struct, Codable, Equatable) — schema version 1

| Field | Type | Rule |
|---|---|---|
| `version` | Int | == 1 |
| `seed` | UInt64 | any |
| `particleLimit` | Int | 100…20,000 (default 4,000) |
| `timeScale` | Double | finite, 0.25…2 (default 1) |
| `emitters` | [SceneEmitter] | 1…8 |
| `forces` | [SceneForce] | ≤ 8; all values finite; radius > 0 |

- **SceneEmitter:** `family`, plus an optional `position` override (finite).
- **SceneForce:** a Codable mirror of `gravity(x,y)`, `drag(k ≥ 0)` and `attractor(x, y, strength, radius > 0)`.
- **`validate() throws(SceneError)`:** the cases are `unsupportedVersion(Int)`, `nonFinite(field)`,
  `limitOutOfRange(Int)`, `timeScaleOutOfRange(Double)`, `emitterCount(Int)` and `forceCount(Int)`. `decode` validates.

### SceneCommand (enum, Codable, Equatable)

- `moveAttractor(index:x:y:)`.
- `burst(emitter:count:)`: count clamped to 1…5,000.
- `setEmitting(emitter:on:)`.

Commands with an invalid index are ignored and counted.

### SceneSimulation (struct)

- `init(scene:) throws(SceneError)` builds a `ParticleSystem(capacity: particleLimit, seed:)`, the families' emitters
  and forces, and a `FixedStepRunner` (step 1/120, cap 8).
- `advance(frame:)` scales by `timeScale`.
- Accessors: `liveCount`, `droppedCount`, `ignoredCommands`, `checksum()`, `instances()` and `positions(first:)`.

### Replay fixture (`replay-v1.json`)

```json
{ "schema": 1, "scene": { ... }, "controls": [{"step":120,"command":{...}}, ...], "steps": 600,
  "expected": { "checksum": "0x…", "live": N, "positions": [[x,y], ... 8 pairs as exact decimal strings] } }
```

The positions are stored as `Double.bitPattern` hex strings for an exact comparison.
