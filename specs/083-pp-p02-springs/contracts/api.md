# Contract: A11-P02 APIs and actions

## VisualCoreSimulation (public, additive, `///`-documented, in the API baseline)

- `enum SpringAnchor2D: Sendable, Equatable { case body(index: Int, local: Vec2); case world(Vec2) }`
- `struct Spring2D: Sendable, Equatable { var a: SpringAnchor2D; var b: SpringAnchor2D; var restLength: Double; var
  stiffness: Double; var dampingRatio: Double }`
- `enum Springs2D { static func stableStiffness(effectiveMass:dt:) -> Double; static func apply(_ bodies: inout
  [RigidBodyState2D], springs: [Spring2D], dt: Double) }`
- `struct AABB2D: Sendable, Equatable { var min: Vec2; var max: Vec2; func overlaps(_:) -> Bool }`; `Shape2D.bounds(at:)`
- `struct BroadPhasePair2D: Sendable, Equatable, Hashable { var a: Int; var b: Int }`; `enum BroadPhase2D { static func
  pairs(_ boxes: [AABB2D]) -> [BroadPhasePair2D] }`
- `Contact2D.normalImpulses`, `Contact2D.tangentImpulses` (default `[]`); `ImpulseSolver2D.solve(_:contacts: inout
  [Contact2D], settings:)`.

## Experience actions (`a11.physics-playground`, schema 2)

Phase 01 actions plus `world.gravity [0…2]`, `world.drag [0…2]`, `world.stiffness [0…3]` (fractional →
`a11.invalid-choice`).
