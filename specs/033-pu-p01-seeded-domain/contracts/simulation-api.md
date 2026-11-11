# Contract: VisualCoreSimulation additions (G-EMITTERS, G-SIMSTEP) and the app surface

## Public VisualCore API (new or changed; all documented with `///`, recorded in the API baseline)

```swift
public enum EmitterShape: Sendable, Equatable, Codable {
    case point
    case line(halfLength: Double, angle: Double)
    case ring(radius: Double)
}
public struct EmitterBurst: Sendable, Equatable, Codable { public var count: Int; public var interval: Double }
extension Emitter {
    public var shape: EmitterShape      // stored, default .point
    public var burst: EmitterBurst?     // stored, default nil
    public func clamped() -> Emitter
    public static let rateRange, lifetimeRange, speedRange, sizeRange, extentRange: ClosedRange<Double>
}
public protocol FixedStepSimulation { mutating func step(_ dt: Double); func checksum() -> UInt64 }
extension ParticleSystem: FixedStepSimulation {}
public struct ControlStream<Command> { public init(_ entries: [(step: Int, command: Command)]); public func commands(at: Int) -> [Command] }
public struct FixedStepRunner<Simulation: FixedStepSimulation, Command> {
    public init(simulation:, clock: FixedStepClock = .init(), stream: ControlStream<Command> = .init([]), apply:)
    public private(set) var simulation: Simulation
    public private(set) var stepIndex: Int
    public private(set) var isPaused: Bool
    public var clock: FixedStepClock { get }
    public mutating func advance(frame dt: Double) -> Int
    public mutating func stepOnce()
    public mutating func run(steps: Int)
    public mutating func pause(); public mutating func resume()
    public mutating func mutate(_ body: (inout Simulation) -> Void)   // direct edits (e.g. live attractor drag)
}
```

## Guarantees

| ID | Guarantee | Test |
|---|---|---|
| C1 | Point-shape, burst-free emitters produce the same checksums as before this feature | existing `ParticleSystemTests`, A01 `ParticleReplay` tests, `VisualCoreBaselines` |
| C2 | Spawns lie on their shape within 1e-9 | `EmitterShapeTests` |
| C3 | Live ≤ capacity every step; dropped = demand − created | `EmitterShapeTests` |
| C4 | `clamped()` output is finite and in range for any input | `EmitterShapeTests` |
| C5 | A paused runner runs 0 steps; resume discards elapsed time | `FixedStepRunnerTests` |
| C6 | One 10 s frame runs ≤ 8 steps | `FixedStepRunnerTests` |
| C7 | Commands apply before their step index; frame splitting does not change the checksum | `FixedStepRunnerTests` |

## App UI contract (accessibility identifiers)

| Identifier | Element |
|---|---|
| `pu.home.open` | "Open sandbox" link |
| `pu.sandbox.family` | family picker (segmented), values Fountain/Curtain/Halo/Firework |
| `pu.sandbox.description` | spoken family description |
| `pu.sandbox.live` | label "Live particles: N of LIMIT" |
| `pu.sandbox.dropped` | label "Dropped: N" |
| `pu.sandbox.play` | Play/Pause toggle |
| `pu.sandbox.step` | Step button (enabled while paused) |
| `pu.sandbox.reseed` | New seed button |
| `pu.sandbox.canvas` | preview, accessibility label describing family and count |
