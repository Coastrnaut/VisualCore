# Contract: A11-P01 APIs and actions

## VisualCoreSimulation (public, `///`-documented, in the API baseline)

- `enum Shape2D: Sendable, Equatable, Codable { case circle(radius: Double); case box(halfExtents: Vec2) }` with
  `area` and `inertia(mass:)`.
- `struct Pose2D: Sendable, Equatable { var position: Vec2; var angle: Double }` with `toWorld(_:)`, `toLocal(_:)`.
- `struct ContactManifold2D: Sendable, Equatable { var normal: Vec2; var depth: Double; var points: [Vec2] }` (1…2
  points, normal from the first shape to the second).
- `enum Contacts2D { static func collide(_ a: Shape2D, _ poseA: Pose2D, _ b: Shape2D, _ poseB: Pose2D) ->
  ContactManifold2D?; static let tolerance = 1e-9 }`.
- `struct RigidBodyState2D: Sendable, Equatable { var position: Vec2; var angle: Double; var velocity: Vec2; var
  angularVelocity: Double; var inverseMass: Double; var inverseInertia: Double; var restitution: Double; var friction:
  Double }`.
- `struct Contact2D: Sendable, Equatable { var a: Int; var b: Int; var manifold: ContactManifold2D }` (indices into
  the body array).
- `enum ImpulseSolver2D { struct Settings: Sendable, Equatable { var iterations = 10; var restitutionThreshold = 0.5;
  var slop = 0.005; var correction = 0.8 }; static func solve(_ bodies: inout [RigidBodyState2D], contacts:
  [Contact2D], settings: Settings = .init()) }` — changes velocities, then positions by the positional correction.

## PhysicsPlaygroundCore (public within the package, `///`-documented)

- `MaterialCatalog` — `static let bundled`; `materials`; `encoded() -> Data`; `static func decode(_:) -> (catalog:,
  refused: [CatalogRefusal])`.
- `LicenseAudit` — `rows(_:)`, `problems(_:)`, `markdown(_:)`.
- `PhysicsWorld` — schema 1; `validate() -> [String]`.
- `StartingScene` — `static func make(random: inout SeededRandom, catalog:) -> PhysicsWorld`.
- `WorldSimulation` — `static func tick(_ world: inout PhysicsWorld, catalog:)`; `static func advanceHostStep(_:catalog:)`;
  `static func drop(_:kind:random:catalog:) -> Bool`.
- `WorldDiagnostics` — `kineticEnergy`, `potentialEnergy`, `momentum`.

## Experience actions (`a11.physics-playground`)

`world.pause [0…1]`, `world.step`, `world.timeScale [0…3]`, `world.reset`, `world.drop [0…1]`; refusals
`a11.invalid-choice`, `a11.not-paused`, `a11.body-cap`. Snapshot schema 1 = `PlaygroundState`.
