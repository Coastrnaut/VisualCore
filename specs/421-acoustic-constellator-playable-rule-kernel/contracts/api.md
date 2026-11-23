# API contract: R02-G13-01 (AcousticConstellatorCore)

```swift
public enum AcousticConstellatorError: Error, Equatable, Sendable { case level(String), action(String), stage, stale,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g13.*
public struct AcousticConstellatorStar: Sendable, Hashable, Codable { public let x, y, z: Int
    public let rate: Int; public let phase: Int }
public struct AcousticConstellatorLink: Sendable, Hashable, Codable, Comparable { public let a: Int; public let b: Int }
public enum AcousticConstellatorClock { public static let steps: Int                 // 12
    public static func gap(_ from: Int, _ to: Int) -> Int                            // signed, −5 ... 6
    public static func coupling(_ gap: Int) -> Int                                   // sign(d) · t(|d|)
    public static func orderParts(_ phases: [Int]) -> (a: Int, b: Int)               // n²R² = a + b√3
    public static func atLeast(a: Int, b: Int, threshold: Int) -> Bool               // exact a + b√3 >= threshold
    public static func tick(phases: [Int], rates: [Int], links: [AcousticConstellatorLink], coupling: Int) -> [Int] }
public enum AcousticConstellatorOutcome: Sendable, Hashable { case won(tick: Int), missing(AcousticConstellatorLink),
    disconnected(tick: Int, link: AcousticConstellatorLink), incoherent(longestRun: Int) }
public struct AcousticConstellatorListen: Sendable, Equatable { public let phases: [[Int]]; public let snapped: [[Int]]
    public let order: [[Int]]; public let coherent: [Bool]; public let longestRun: Int
    public let outcome: AcousticConstellatorOutcome }
public enum AcousticConstellatorLabel { public static func label(stars: Int, links: [AcousticConstellatorLink]) -> String }
public struct AcousticConstellatorLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(AcousticConstellatorError);
    encoded() -> Data; static func decode(_:) throws(AcousticConstellatorError) -> Self; fingerprint */
    public func listen(links: [AcousticConstellatorLink], phases: [Int]) -> AcousticConstellatorListen
    public func starName(_ index: Int, phase: Int) -> String           // "star 2, rate 3, phase 7"
    public func linkName(_ link: AcousticConstellatorLink, phases: [Int]) -> String   // "link star 0 to star 3, gap 2"
    public func progressDescription(listen: AcousticConstellatorListen, actionsLeft: Int) -> String }
public enum AcousticConstellatorFailure: Sendable, Hashable, Codable { case missing(AcousticConstellatorLink),
    disconnected(tick: Int, link: AcousticConstellatorLink), incoherent(Int), budget(Int); public var code: String }
public enum AcousticConstellatorAction: Sendable, Hashable, Codable { case link(Int, Int), unlink(Int, Int), nudge(Int, Int), listen }
public enum AcousticConstellatorStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum AcousticConstellatorEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum AcousticConstellatorRecordKind: String, Sendable, Codable { case link, unlink, nudge, listen, undo, redo }
public struct AcousticConstellatorRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64
    public let index: Int; public let kind: AcousticConstellatorRecordKind; public let action: AcousticConstellatorAction?
    public let previous: String; public let next: String }
public struct AcousticConstellatorPlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: AcousticConstellatorLevel
    public private(set) var stage: AcousticConstellatorStage, links: [AcousticConstellatorLink], phases: [Int],
        actionsSpent: Int, report: AcousticConstellatorListen,
        failure: AcousticConstellatorFailure?, records: [AcousticConstellatorRecord]
    public var label: String { get }; public var matchesSymbol: Bool { get }   // computed when read (8! orderings)
    public var actionsLeft: Int { get }; public var fingerprint: String { get }; public var canUndo, canRedo: Bool { get }
    public init(level: AcousticConstellatorLevel)
    public mutating func handle(_ event: AcousticConstellatorEvent) throws(AcousticConstellatorError)        // .stage
    public mutating func apply(_ action: AcousticConstellatorAction, expecting previous: String) throws(AcousticConstellatorError)
        // order: .stage, .stale, .action
    public mutating func undo() throws(AcousticConstellatorError); public mutating func redo() throws(AcousticConstellatorError)
    public static func replay(level: AcousticConstellatorLevel, records: [AcousticConstellatorRecord]) throws(AcousticConstellatorError) -> AcousticConstellatorPlay
}
public struct AcousticConstellatorRules: PuzzleRules { /* State = Position (links, phases, actions spent, outcome),
    Move = AcousticConstellatorAction; rulesID "r02-g13-acoustic-constellator"; moves per data-model.md;
    var initialState: Position */ }
```
