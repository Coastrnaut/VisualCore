# Contract: A09-P02 API

## VisualCoreSimulation (public, recorded in `docs/api/visualcore-public-api.txt`)

```swift
public struct SteeringAgent: Sendable, Equatable { public var position: Vec2; public var velocity: Vec2; public var group: Int; public init(position:velocity:group:) }
public struct SteeringBounds: Sendable, Equatable { public var minX, maxX, minY, maxY: Double; public init(minX:maxX:minY:maxY:); public var isValid: Bool }
public struct SteeringParameters: Sendable, Equatable { neighbourRadius, neighbourLimit: Int, separationRadius, separationWeight, alignmentWeight, cohesionWeight, boundaryWeight, boundaryMargin, maxForce; public init(...) with defaults }
public enum NeighbourSearch { public static func neighbours(of index: Int, in agents: [SteeringAgent], radius: Double, limit: Int) -> [Int] }
public enum Steering {
    public static func force(for index: Int, agents: [SteeringAgent], neighbours: [Int], parameters: SteeringParameters, bounds: SteeringBounds) -> Vec2
    public static func capped(_ v: Vec2, to limit: Double) -> Vec2
}
```

Guarantees: `neighbours` returns ≤ max(0, limit) indices, never `index`, nearest first, ties by index, only agents
within `radius` with finite positions; an out-of-range `index` returns []. `force` is finite and `length ≤ maxForce`;
separation uses every neighbour, alignment and cohesion only neighbours of the same group; an out-of-range index or a
non-finite agent gives `.zero`; bounds that are not `isValid` add no boundary force.

## DigitalAquariumCore

`AquariumSimulation.advance(_:catalog:random:)` keeps its signature; `AquariumSimulation.parameters(for: FishSpecies)
-> SteeringParameters`; `SchoolMetrics.meanSameSpeciesDistance(_:)`, `meanCrossSpeciesDistance(_:)`,
`headingAgreement(_:)`; `HabitatDocument.migrated(catalog:) -> HabitatDocument`; `SpeciesCatalog.decor(id:)`.

## Experience

No new action or control. Snapshot schema 2; fixtures `fixture-6` (schooling) and `fixture-7` (save/load).
