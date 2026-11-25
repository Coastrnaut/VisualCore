# API contract: R02-G18-01 (ApsidesWorkshopCore)

```swift
public enum ApsidesWorkshopError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g18.*
public enum ApsidesWorkshopFixed {                       // Int64, 2^30 as one; integer arithmetic only
    public static let one: Int64; public static let twoPi: Int64
    public static func sin(_ angle: Int64) -> Int64; public static func cos(_ angle: Int64) -> Int64
    public static func sqrt(_ value: Int64) -> Int64                    // of a fixed-point value in 0 … one
    public static func eccentricAnomaly(mean: Int64, eccentricity: Int64) -> (anomaly: Int64, residual: Int64,
        newtonSteps: Int, bisected: Bool) }
public struct ApsidesWorkshopOrbit: Sendable, Hashable, Codable { public let size: Int; public let eccentricity: Int
    public let direction: Int; public var isValid: Bool { get }
    public var periapsisSector: Int { get }; public var apoapsisSector: Int { get }
    public var periapsisDistance: Int { get }; public var apoapsisDistance: Int { get } }   // twentieths
public struct ApsidesWorkshopPoint: Sendable, Hashable, Codable { public let x: Int; public let y: Int }
public struct ApsidesWorkshopPlanet: Sendable, Hashable, Codable { public let x: Int; public let y: Int
    public let radius: Int }
public enum ApsidesWorkshopApsis: String, Sendable, Codable, CaseIterable { case periapsis, apoapsis }
public enum ApsidesWorkshopTarget: Sendable, Hashable, Codable {
    case sweep(sector: Int, low: Int, high: Int); case apsis(ApsidesWorkshopApsis, sector: Int, near: Int, far: Int) }
public enum ApsidesWorkshopFailure: Sendable, Hashable, Codable {
    case contact(planet: Int, tick: Int); case order(target: Int, tick: Int); case share(target: Int, tick: Int, share: Int)
    case apsisSector(target: Int, sector: Int); case apsisDistance(target: Int, distance: Int); public var code: String }
public struct ApsidesWorkshopReport: Sendable, Equatable { public let positions: [ApsidesWorkshopPoint]
    public let shares: [Int]; public let largestResidual: Int64; public let eventTicks: [Int]
    public let deviations: [Int]; public let failure: ApsidesWorkshopFailure?; public var wins: Bool { get } }
public enum ApsidesWorkshopSky {
    public static func positions(_ orbit: ApsidesWorkshopOrbit, period: Int) -> (points: [ApsidesWorkshopPoint],
        largestResidual: Int64)
    public static func sector(of point: ApsidesWorkshopPoint) -> Int
    public static func shares(_ points: [ApsidesWorkshopPoint]) -> [Int]
    public static func touches(_ planet: ApsidesWorkshopPlanet, from a: ApsidesWorkshopPoint,
        to b: ApsidesWorkshopPoint) -> Bool
    public static func report(_ level: ApsidesWorkshopLevel, orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopReport }
public struct ApsidesWorkshopLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init
    throws(ApsidesWorkshopError); encoded() -> Data; static func decode(_:) throws(ApsidesWorkshopError) -> Self;
    fingerprint */
    public func sectorName(_ index: Int) -> String                      // "sector 3"
    public func targetDescription(_ index: Int, report: ApsidesWorkshopReport) -> String
        // "sector 3 swept 18.4 %, needs 15.0 to 20.0 %"
    public func progressDescription(report: ApsidesWorkshopReport, orbit: ApsidesWorkshopOrbit, actionsLeft: Int)
        -> String }
public enum ApsidesWorkshopAction: Sendable, Hashable, Codable { case periapsis(Int, Int); case size(Int); case play }
public enum ApsidesWorkshopStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused,
    won, failed, result }
public enum ApsidesWorkshopEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct ApsidesWorkshopRecord: Sendable, Equatable, Codable { /* per data-model.md */ }
public struct ApsidesWorkshopPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: ApsidesWorkshopLevel
    public private(set) var stage: ApsidesWorkshopStage, orbit: ApsidesWorkshopOrbit, actionsSpent: Int,
        report: ApsidesWorkshopReport, failure: ApsidesWorkshopFailure?, records: [ApsidesWorkshopRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: ApsidesWorkshopLevel)
    public mutating func handle(_ event: ApsidesWorkshopEvent) throws(ApsidesWorkshopError)
    public mutating func apply(_ action: ApsidesWorkshopAction, expecting previous: String)
        throws(ApsidesWorkshopError)                                      // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(ApsidesWorkshopError); public mutating func redo() throws(ApsidesWorkshopError)
    public static func replay(level: ApsidesWorkshopLevel, records: [ApsidesWorkshopRecord])
        throws(ApsidesWorkshopError) -> ApsidesWorkshopPlay
}
public struct ApsidesWorkshopRules: PuzzleRules { /* State = Position, Move = ApsidesWorkshopAction (tunings only);
    rulesID "r02-g18-apsides-workshop"; goal: the predicted play wins */ }
```
