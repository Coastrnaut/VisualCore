# API contract: R02-G19-01 (MicroscopicAuroraCore)

```swift
public enum MicroscopicAuroraError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g19.*
public struct MicroscopicAuroraPoint: Sendable, Hashable, Codable { public let x: Int; public let y: Int }
public struct MicroscopicAuroraSwimmer: Sendable, Hashable, Codable { public let position: MicroscopicAuroraPoint
    public let velocity: MicroscopicAuroraPoint }
public struct MicroscopicAuroraCell: Sendable, Hashable, Codable, Comparable { public let row: Int
    public let column: Int }                                            // row-major order
public enum MicroscopicAuroraSense: String, Sendable, Codable, CaseIterable { case clockwise, counterclockwise }
public struct MicroscopicAuroraWell: Sendable, Hashable, Codable { public let cell: MicroscopicAuroraCell
    public let strength: Int; public let sense: MicroscopicAuroraSense }
public struct MicroscopicAuroraSwarmRules: Sendable, Hashable, Codable { public let neighbourRadius: Int
    public let separationRadius: Int; public let coherenceRadius: Int; public let separationWeight: Int
    public let alignmentWeight: Int; public let cohesionWeight: Int; public let maxAcceleration: Int
    public let maxSpeed: Int }
public enum MicroscopicAuroraFailure: Sendable, Hashable, Codable {
    case exit(swimmer: Int, tick: Int); case coherence(tick: Int, group: Int)
    case coverage(lit: Int, needed: Int); case connectedness(cell: MicroscopicAuroraCell)
    public var code: String }
public struct MicroscopicAuroraReport: Sendable, Equatable { public let ticks: Int
    public let finalSwimmers: [MicroscopicAuroraSwimmer]; public let density: [Int]   // 576 cells, row-major
    public let litStencil: [MicroscopicAuroraCell]; public let coverage: Int; public let groups: Int
    public let smallestCoherence: Int; public let smallestCoherenceTick: Int
    public let failure: MicroscopicAuroraFailure?; public var wins: Bool { get } }
public enum MicroscopicAuroraDish {
    public static let cells: Int; public static let unit: Int; public static let centre: Int   // 24, 256, 3072
    public static func isInside(_ point: MicroscopicAuroraPoint, radius: Int) -> Bool
    public static func cell(of point: MicroscopicAuroraPoint) -> MicroscopicAuroraCell
    public static func step(_ swimmers: [MicroscopicAuroraSwimmer], wells: [MicroscopicAuroraWell],
        rules: MicroscopicAuroraSwarmRules) -> [MicroscopicAuroraSwimmer]
    public static func coherence(_ swimmers: [MicroscopicAuroraSwimmer], radius: Int) -> Int
    public static func groups(_ cells: [MicroscopicAuroraCell]) -> Int
    public static func swim(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell],
        keepPositions: Bool) -> (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]])
    public static func report(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell])
        -> MicroscopicAuroraReport }
public struct MicroscopicAuroraLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init
    throws(MicroscopicAuroraError); encoded() -> Data; static func decode(_:) throws(MicroscopicAuroraError) -> Self;
    fingerprint */
    public func wellDescription(_ slot: Int, well: MicroscopicAuroraWell?) -> String
        // "well 2 at row 7, column 12, strength 3, counterclockwise"
    public func coverageDescription(report: MicroscopicAuroraReport) -> String
        // "stencil 34 of 40 cells lit, 85.0 %, needs 80.0 %"
    public func progressDescription(report: MicroscopicAuroraReport, wells: [MicroscopicAuroraWell?],
        actionsLeft: Int) -> String }
public enum MicroscopicAuroraAction: Sendable, Hashable, Codable { case place(slot: Int, well: MicroscopicAuroraWell)
    case remove(slot: Int); case play }
public enum MicroscopicAuroraStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing,
    paused, won, failed, result }
public enum MicroscopicAuroraEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct MicroscopicAuroraRecord: Sendable, Equatable, Codable { /* per data-model.md */ }
public struct MicroscopicAuroraPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: MicroscopicAuroraLevel
    public private(set) var stage: MicroscopicAuroraStage, wells: [MicroscopicAuroraWell?], actionsSpent: Int,
        report: MicroscopicAuroraReport, failure: MicroscopicAuroraFailure?, records: [MicroscopicAuroraRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }
    public var canUndo, canRedo: Bool { get }
    public init(level: MicroscopicAuroraLevel)
    public mutating func handle(_ event: MicroscopicAuroraEvent) throws(MicroscopicAuroraError)
    public mutating func apply(_ action: MicroscopicAuroraAction, expecting previous: String)
        throws(MicroscopicAuroraError)                                    // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(MicroscopicAuroraError); public mutating func redo() throws(MicroscopicAuroraError)
    public static func replay(level: MicroscopicAuroraLevel, records: [MicroscopicAuroraRecord])
        throws(MicroscopicAuroraError) -> MicroscopicAuroraPlay
}
public struct MicroscopicAuroraPuzzle: PuzzleRules { /* State = Position, Move = MicroscopicAuroraAction (placements
    only); rulesID "r02-g19-microscopic-aurora"; goal: the predicted play wins */ }
```

The swarm rules type is named `MicroscopicAuroraSwarmRules` and the puzzle contract `MicroscopicAuroraPuzzle`, so the
two are not confused.
