# Contract: Simulation Lab core (feature 117)

```swift
public enum SimulationKind: String, Codable, CaseIterable, Sendable { case automaton, reactionDiffusion, wave }
public enum BoundaryMode: String, Codable, Sendable { case wrap, fixedZero }
public struct SimulationSpec: Codable, Equatable, Sendable {      // schema 1
    public static let gridSizes = [16, 32, 64, 128, 256]
    public var kind: SimulationKind; public var gridSize: Int; public var timeStep: Double
    public var boundary: BoundaryMode; public var seed: UInt64; public var parameters: [String: Double]
    public var algorithmVersion: Int
    public static func standard(_ kind: SimulationKind, preset: Int, seed: UInt64) -> SimulationSpec
    public func validated() -> Result<SimulationSpec, SimulationRefusal>      // with a sentence per reason
}
public struct AutomatonRule: Equatable, Sendable { public let birth: Set<Int>; public let survival: Set<Int>
    public static let life, highLife, seeds; public init?(notation: String); public func step(_ grid: FieldGrid) -> FieldGrid }
public enum GrayScott { public static func step(_ grid: FieldGrid, spec: SimulationSpec) -> FieldGrid }
public enum WaveField { public static func step(current: FieldGrid, previous: FieldGrid, spec: SimulationSpec) -> FieldGrid
    public static func energy(current: FieldGrid, previous: FieldGrid, courant: Double) -> Double }
public struct SimulationScheduler: Codable, Equatable, Sendable { public static let maxIterationsPerHostStep = 16
    public mutating func iterations(forHostStep:) -> Int }
public struct SimulationState: Codable, Equatable, Sendable { … }      // spec + scheduler + field; schema 1
```

Experience actions: `sim.family [0…2]`, `sim.preset [0…2]`, `sim.run`, `sim.pause`, `sim.step`, `sim.reset`,
`sim.speed [0…4]`; refusals `a16.invalid-choice`, `a16.unstable`. Controls identifiers
`experience.a16.simulation-lab.<name>` (`family`, `preset`, `run-pause`, `step`, `reset`, `speed`, `status`).
