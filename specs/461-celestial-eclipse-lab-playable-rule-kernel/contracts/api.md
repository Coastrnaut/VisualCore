# API contract: R02-G17-01 (CelestialEclipseLabCore)

```swift
public enum CelestialEclipseLabError: Error, Equatable, Sendable { case level(String), action(String), budget, stage,
    stale, newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g17.*
public struct CelestialEclipseLabVector: Sendable, Hashable, Codable { public let x: Int; public let y: Int
    public let z: Int }
public struct CelestialEclipseLabBody: Sendable, Hashable, Codable { public let orbit: [CelestialEclipseLabVector]
    public let radius: Int; public let fixed: Bool; public var period: Int { get }
    public func position(at tick: Int, phase: Int) -> CelestialEclipseLabVector }
public struct CelestialEclipseLabTarget: Sendable, Hashable, Codable { public let front: Int; public let back: Int
    public let open: Int; public let close: Int }
public enum CelestialEclipseLabVisibility: String, Sendable, Codable, CaseIterable { case partial, total, annular }
public struct CelestialEclipseLabInterval: Sendable, Hashable { public let front: Int; public let back: Int
    public let first: Int; public let last: Int; public let visibility: CelestialEclipseLabVisibility }
public enum CelestialEclipseLabFailure: Sendable, Hashable, Codable {
    case unwanted(front: Int, back: Int, tick: Int); case window(front: Int, back: Int, tick: Int, open: Int, close: Int)
    case horizon(front: Int, back: Int, open: Int, close: Int); public var code: String }
public struct CelestialEclipseLabTimeline: Sendable, Equatable { public let intervals: [CelestialEclipseLabInterval]
    public let matched: Int; public let failure: CelestialEclipseLabFailure?; public var wins: Bool { get } }
public enum CelestialEclipseLabSky {
    public static func eclipses(_ a: CelestialEclipseLabBody, _ b: CelestialEclipseLabBody, at tick: Int,
        phases: (Int, Int)) -> Bool
    public static func intervals(_ level: CelestialEclipseLabLevel, phases: [Int]) -> [CelestialEclipseLabInterval]
    public static func timeline(_ level: CelestialEclipseLabLevel, phases: [Int]) -> CelestialEclipseLabTimeline }
public struct CelestialEclipseLabLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init
    throws(CelestialEclipseLabError); encoded() -> Data; static func decode(_:) throws(CelestialEclipseLabError) -> Self;
    fingerprint */
    public func bodyName(_ index: Int) -> String                       // "body 3"
    public func eclipseName(front: Int, back: Int) -> String           // "body 2 in front of body 4"
    public func progressDescription(timeline: CelestialEclipseLabTimeline, actionsLeft: Int) -> String }
public enum CelestialEclipseLabAction: Sendable, Hashable, Codable { case phase(Int, Int); case run }
public enum CelestialEclipseLabStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused,
    won, failed, result }
public enum CelestialEclipseLabEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public struct CelestialEclipseLabRecord: Sendable, Equatable, Codable { /* per data-model.md */ }
public struct CelestialEclipseLabPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: CelestialEclipseLabLevel
    public private(set) var stage: CelestialEclipseLabStage, phases: [Int], actionsSpent: Int,
        timeline: CelestialEclipseLabTimeline, failure: CelestialEclipseLabFailure?, records: [CelestialEclipseLabRecord]
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: CelestialEclipseLabLevel)
    public mutating func handle(_ event: CelestialEclipseLabEvent) throws(CelestialEclipseLabError)
    public mutating func apply(_ action: CelestialEclipseLabAction, expecting previous: String)
        throws(CelestialEclipseLabError)                                   // order: .stage, .stale, .action, .budget
    public mutating func undo() throws(CelestialEclipseLabError); public mutating func redo() throws(CelestialEclipseLabError)
    public static func replay(level: CelestialEclipseLabLevel, records: [CelestialEclipseLabRecord])
        throws(CelestialEclipseLabError) -> CelestialEclipseLabPlay
}
public struct CelestialEclipseLabRules: PuzzleRules { /* State = Position, Move = CelestialEclipseLabAction (phase only);
    rulesID "r02-g17-celestial-eclipse-lab"; goal: the predicted run wins */ }
```
