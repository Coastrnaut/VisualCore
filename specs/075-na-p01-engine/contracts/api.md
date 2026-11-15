# Contract: A10-P01 APIs and actions

## VisualCoreSimulation (public, `///`-documented, in the API baseline)

- `struct CollisionCircle: Sendable, Equatable { var center: Vec2; var radius: Double }`
- `struct CollisionCapsule: Sendable, Equatable { var a: Vec2; var b: Vec2; var radius: Double }`
- `enum Collision2D`:
  - `static func overlaps(_ a: CollisionCircle, _ b: CollisionCircle) -> Bool`
  - `static func overlaps(_ circle: CollisionCircle, _ capsule: CollisionCapsule) -> Bool`
  - `static func closestPoint(on capsule: CollisionCapsule, to point: Vec2) -> Vec2` (on the segment)
  - `static func sweep(_ a: CollisionCircle, moving da: Vec2, _ b: CollisionCircle, moving db: Vec2) -> Double?`
  - `static let tolerance: Double = 1e-9`

## NeonArcadeCore (public within the package, `///`-documented)

- `ArcadeCatalog` — `static let bundled`; `items`; `encoded() -> Data`; `static func decode(_ data: Data) ->
  (catalog: ArcadeCatalog, refused: [CatalogRefusal])`.
- `LicenseAudit` — `rows(_:)`, `problems(_:)`, `markdown(_:)`.
- `GameRun` — `static func new() -> GameRun`; `validate() -> [String]`.
- `GameSimulation` — `static let step = 1.0 / 60`; `static func advance(_ run: inout GameRun, catalog:, random: inout
  SeededRandom)`; `static func steer(_ run: inout GameRun, value: Double)`.

## Experience actions (`a10.neon-arcade`)

`run.steer [−1…1]`, `run.pause [0…1]`, `run.restart`; refused values give typed rejections with codes `a10.*`.
Snapshot schema 1 = `ArcadeState`.
