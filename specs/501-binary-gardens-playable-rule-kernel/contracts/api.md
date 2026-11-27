# API contract: R02-G21-01 (BinaryGardensCore)

Every public symbol carries `///` documentation; everything a consumer does not need is `internal`. Stars and worlds
are 0-based in code and numbered from 1 in words.

```swift
public enum BinaryGardensError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }
    // r02-g21.level, .action, .budget, .stage, .stale, .newer-schema, .malformed
public struct BinaryGardensStar: Sendable, Hashable, Codable { public let ring: Int; public let phase: Int
    public let luminosity: Int; public let ringAdjustable: Bool; public let phaseAdjustable: Bool
    public let luminosityAdjustable: Bool }
public struct BinaryGardensWorld: Sendable, Hashable, Codable { public let radius: Int; public let phase: Int
    public let speed: Int; public let lethalLow: Int; public let comfortLow: Int; public let comfortHigh: Int
    public let lethalHigh: Int; public let window: Int; public let bloomLow: Int; public let bloomHigh: Int }
public struct BinaryGardensArrangement: Sendable, Hashable, Codable { public let rings: [Int]
    public let phases: [Int]; public let luminosities: [Int]; public let tilt: Int }   // two entries per star array
public struct BinaryGardensPoint: Sendable, Hashable, Codable { public let x: Int; public let y: Int
    public let z: Int }                                                   // scale 2^20
public enum BinaryGardensBand: String, Sendable, Codable, CaseIterable { case lethalLow, dim, comfortable, bright,
    lethalHigh }
public enum BinaryGardensBloom: String, Sendable, Codable { case below, inside, above }
public enum BinaryGardensFailure: Sendable, Hashable, Codable {
    case frozen(world: Int, tick: Int); case scorched(world: Int, tick: Int)       // walk tick 1 … 48 + E
    case unstable(world: Int, window: Int, required: Int)
    case wilted(world: Int, integral: Int, low: Int, high: Int)
    case bleached(world: Int, integral: Int, low: Int, high: Int)
    public var code: String }                                             // frozen, scorched, unstable, wilted, bleached
public struct BinaryGardensWorldLight: Sendable, Equatable {
    public let flux: [Int]; public let shares: [[Int]]                    // ticks 1 … 48; shares[tick][star]
    public let bands: [BinaryGardensBand]
    public let longestLethalRun: Int                                      // cyclic, at most 48
    public let window: Int; public let windowStart: Int                   // longest cyclic comfortable run, start tick
    public let integral: Int                                              // Σ flux over ticks 1 … 48; mean = integral / 48
    public let bloom: BinaryGardensBloom }
public struct BinaryGardensReport: Sendable, Equatable {
    public let starPositions: [[BinaryGardensPoint]]                      // [tick 1 … 48][star]
    public let worldPositions: [[BinaryGardensPoint]]                     // [tick 1 … 48][world]
    public let worlds: [BinaryGardensWorldLight]
    public let minimumSeparationSquared: Int; public let minimumSeparationTick: Int   // scale 2^40, tick 0 … 47 (tick 0 is the configuration of tick 48)
    public let failure: BinaryGardensFailure?; public var wins: Bool { get } }
public enum BinaryGardensSky {
    public static let cycle: Int                                          // 48
    public static let cosine: [Int]                                       // 48 literal entries, scale 1024
    public static func sine(_ step: Int) -> Int                           // cosine[(step + 36) mod 48]
    public static func phase(_ start: Int, speed: Int, tick: Int) -> Int  // non-negative (start + speed·tick) mod 48
    public static func starPosition(radius: Int, phase: Int, tilt: Int) -> BinaryGardensPoint
    public static func worldPosition(radius: Int, phase: Int) -> BinaryGardensPoint
    public static func squaredDistance(_ a: BinaryGardensPoint, _ b: BinaryGardensPoint) -> Int   // scale 2^40
    public static func flux(luminosity: Int, squaredDistance: Int, clampRadius: Int) -> Int
        // ⌊1000·L·2^40 / max(D, r_min²·2^40)⌋ milliflux, at most 64 000
    public static func band(_ flux: Int, of world: BinaryGardensWorld) -> BinaryGardensBand
    public static func keepsSeparation(_ level: BinaryGardensLevel, arrangement: BinaryGardensArrangement) -> Bool
    public static func report(_ level: BinaryGardensLevel, arrangement: BinaryGardensArrangement)
        -> BinaryGardensReport }                                          // the judge: lethal walk, then per world unstable, wilted / bleached
public struct BinaryGardensLevel: Sendable, Equatable, Codable {
    public static let schema: Int                                         // 1
    public let id: String; public let seed: UInt64; public let difficulty: Int
    public let ringRadii: [Int]; public let starSpeed: Int; public let luminosityLevels: [Int]
    public let stars: [BinaryGardensStar]; public let maxTilt: Int; public let startTilt: Int
    public let minimumSeparation: Int; public let clampRadius: Int; public let worlds: [BinaryGardensWorld]
    public let lethalTolerance: Int; public let budget: Int; public let tutorial: Bool; public let fingerprint: String
    public init(id: String, seed: UInt64, difficulty: Int, ringRadii: [Int], starSpeed: Int, luminosityLevels: [Int],
        stars: [BinaryGardensStar], maxTilt: Int, startTilt: Int, minimumSeparation: Int, clampRadius: Int,
        worlds: [BinaryGardensWorld], lethalTolerance: Int, budget: Int, tutorial: Bool) throws(BinaryGardensError)
    public var start: BinaryGardensArrangement { get }
    public func encoded() -> Data
    public static func decode(_ data: Data) throws(BinaryGardensError) -> BinaryGardensLevel
    public func starDescription(_ star: Int, arrangement: BinaryGardensArrangement) -> String
        // "star 1 on ring 3, 12 units, phase 9, luminosity 24"
    public func worldTickDescription(_ world: Int, tick: Int, report: BinaryGardensReport) -> String
        // "world 2 at tick 17: 41 250 milliflux, comfortable, band 30 000 … 52 000"
    public func worldDescription(_ world: Int, report: BinaryGardensReport) -> String
        // "world 2: window of 31 ticks from tick 5, 24 required; longest lethal run 1 of 2 allowed;
        //  integral 1 980 000, bloom band 1 900 000 … 2 100 000"
    public func failureDescription(_ failure: BinaryGardensFailure) -> String
        // "world 1 froze at tick 50 (tick 2 of the next cycle)"
    public func progressDescription(report: BinaryGardensReport, arrangement: BinaryGardensArrangement,
        actionsLeft: Int) -> String }
public enum BinaryGardensAction: Sendable, Hashable, Codable { case ring(star: Int, index: Int)
    case phase(star: Int, step: Int); case luminosity(star: Int, index: Int); case tilt(step: Int); case run }
public enum BinaryGardensStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing,
    paused, won, failed, result }
public enum BinaryGardensEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct BinaryGardensRecord: Sendable, Equatable, Codable { public let schema: Int; public let levelSeed: UInt64
    public let index: Int; public let kind: Kind; public let action: BinaryGardensAction?
    public let previous: String; public let next: String
    public enum Kind: String, Sendable, Codable, CaseIterable { case ring, phase, luminosity, tilt, run, undo, redo,
        begin, dismissTutorial, pause, resume, showResult } }
public struct BinaryGardensPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: BinaryGardensLevel
    public private(set) var stage: BinaryGardensStage, arrangement: BinaryGardensArrangement, actionsSpent: Int,
        report: BinaryGardensReport, failure: BinaryGardensFailure?, records: [BinaryGardensRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }
    public var canUndo: Bool { get }; public var canRedo: Bool { get }
    public init(level: BinaryGardensLevel)
    public mutating func handle(_ event: BinaryGardensEvent) throws(BinaryGardensError)
    public mutating func apply(_ action: BinaryGardensAction, expecting previous: String)
        throws(BinaryGardensError)                                       // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(BinaryGardensError); public mutating func redo() throws(BinaryGardensError)
    public static func replay(level: BinaryGardensLevel, records: [BinaryGardensRecord])
        throws(BinaryGardensError) -> BinaryGardensPlay                  // another level or a broken chain: .malformed
}
public struct BinaryGardensPuzzle: PuzzleRules {
    public struct Position: Hashable, Codable, Sendable { public let arrangement: BinaryGardensArrangement
        public let actionsSpent: Int; public init(arrangement: BinaryGardensArrangement, actionsSpent: Int) }
    public typealias State = Position; public typealias Move = BinaryGardensAction   // arrangement actions only
    public let level: BinaryGardensLevel
    public init(level: BinaryGardensLevel)
    public var rulesID: String { get }                                    // "r02-g21-binary-gardens"
    public var initialState: Position { get }
    public func moves(in state: Position) -> [BinaryGardensAction]        // order of research R14, at most 120
    public func apply(_ move: BinaryGardensAction, to state: Position) -> Position?   // nil where the play refuses
    public func isSolved(_ state: Position) -> Bool }                     // BinaryGardensSky.report(...).wins
```

The sky's geometry, light and judge live in `BinaryGardensSky` and the puzzle contract is `BinaryGardensPuzzle`, so
the game's name does not clash with a module type. `BinaryGardensPlay` and `BinaryGardensPuzzle` agree: a move is
legal in the puzzle exactly when `apply(_:expecting:)` accepts it in `playing` with actions left, and both produce the
same arrangement. No existing module's API changes; no VisualCore API baseline update is needed.

## Public names beyond this contract (feature 501 convergence, T-R02G2101-014)

The implementation exposes these additional public names; each is documented in the source:

- Memberwise initializers of `BinaryGardensStar`, `BinaryGardensWorld`, `BinaryGardensArrangement`,
  `BinaryGardensPoint`, `BinaryGardensWorldLight` and `BinaryGardensReport`: tests, the generator (feature 502) and the
  scene snapshot (feature 503) build these values directly.
- `BinaryGardensBand.isLethal` and `.words`: the judge's lethal walk and the light report's words.
- `BinaryGardensFailure.world`: the failing world's number for the failure explanation (feature 505).
- `BinaryGardensLevel.startReport`, `grouped(_:)` and its public range constants: the opening report, numbers in
  words with grouped digits, and the ranges the generator draws from.
- `BinaryGardensSky.tableScale`, `positionScale`, `squaredScale` and `millifluxPerUnit`: the fixed-point scales
  (1024, 2^20, 2^40, 1000) named once for the renderer and the tests.

