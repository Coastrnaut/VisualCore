# API contract: R02-G08-01 (FacetedForgeCore)

```swift
public enum FacetedForgeError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, miss,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g08.*
public struct FacetedForgeFraction: Sendable, Hashable, Comparable, Codable { public let numerator: Int64
    public let denominator: Int64; public init(_ n: Int64, _ d: Int64 = 1) throws(FacetedForgeError)
    public func adding(_ o: Self) throws(FacetedForgeError) -> Self   // also subtracting, multiplying, dividing
    public var text: String { get } }                                  // "3/16", "1"
public struct FacetedForgeDirection: Sendable, Hashable, Codable { public static let all: [FacetedForgeDirection]  // 13
    public let index: Int; public let x: Int; public let y: Int; public let z: Int; public var name: String { get } }
public struct FacetedForgeHalfSpace: Sendable, Hashable, Codable, Comparable { public let direction: Int
    public let sign: Int; public let depth: Int }
public struct FacetedForgePoint: Sendable, Hashable, Codable, Comparable { public let x, y, z: FacetedForgeFraction }
public struct FacetedForgeFace: Sendable, Hashable { public let plane: FacetedForgeHalfSpace
    public let corners: [FacetedForgePoint] }                          // ordered round the face, outward normal
public struct FacetedForgePiece: Sendable, Hashable, Codable {
    public let halfSpaces: [FacetedForgeHalfSpace]
    public init(halfSpaces: [FacetedForgeHalfSpace]) throws(FacetedForgeError)   // .level("empty") without interior
    public var corners: [FacetedForgePoint] { get }; public var faces: [FacetedForgeFace] { get }
    public var faceCount: Int { get }; public var volume: FacetedForgeFraction { get }
    public var edges: [[FacetedForgePoint]] { get }                    // each edge as its two corners, sorted
    public func cut(direction: Int, depth: Int) throws(FacetedForgeError) -> (below: Self, above: Self)  // .miss
}
public struct FacetedForgeTargetPiece: Sendable, Hashable, Codable { public let share: FacetedForgeFraction
    public let faces: Int }
public struct FacetedForgeLevel: Sendable, Equatable, Codable { /* fields per data-model.md; init throws(FacetedForgeError);
    encoded() -> Data; static func decode(_:) throws(FacetedForgeError) -> Self; fingerprint */
    public var crystal: FacetedForgePiece { get }
    public func pieceName(_ index: Int, share: FacetedForgeFraction, faces: Int) -> String   // "piece 1: 1/4 of the crystal, 6 faces"
    public func targetDescription() -> String }                        // FR-R02G0801-013
public enum FacetedForgeFailure: Sendable, Hashable, Codable { case sliver(Int, Int), budget; public var code: String }
public enum FacetedForgeAction: Sendable, Hashable, Codable { case cut(Int, Int, Int) }   // piece, direction, depth
public enum FacetedForgeStage: String, Sendable, Codable, CaseIterable { case loading, tutorial, playing, paused, won, failed, result }
public enum FacetedForgeEvent: Sendable, Equatable { case begin, dismissTutorial, pause, resume, showResult }
public enum FacetedForgeRecordKind: String, Sendable, Codable { case cut, undo, redo }
public struct FacetedForgeRecord: Sendable, Equatable, Codable { public let schema: Int; public let seed: UInt64; public let cut: Int
    public let kind: FacetedForgeRecordKind; public let action: FacetedForgeAction?; public let previous: String; public let next: String }
public struct FacetedForgePlay: Sendable, Equatable {
    public static var schema: Int { 1 }
    public let level: FacetedForgeLevel
    public private(set) var stage: FacetedForgeStage, pieces: [FacetedForgePiece], cuts: Int,
        failure: FacetedForgeFailure?, records: [FacetedForgeRecord]
    public var fingerprint: String { get }; public var remaining: Int { get }; public var canUndo, canRedo: Bool { get }
    public var shares: [FacetedForgeFraction] { get }                  // per piece, in canonical order
    public init(level: FacetedForgeLevel)
    public mutating func handle(_ event: FacetedForgeEvent) throws(FacetedForgeError)            // .stage
    public mutating func apply(_ action: FacetedForgeAction, expecting previous: String) throws(FacetedForgeError)
        // order: .stage, .stale, .action("range"), .miss
    public mutating func undo() throws(FacetedForgeError); public mutating func redo() throws(FacetedForgeError)
    public static func replay(level: FacetedForgeLevel, records: [FacetedForgeRecord]) throws(FacetedForgeError) -> FacetedForgePlay
}
public struct FacetedForgeRules: PuzzleRules { /* State = Position (pieces, cuts, outcome), Move = FacetedForgeAction;
    rulesID "r02-g08-faceted-forge"; moves while playing: every non-degenerate cut, pieces in order, directions 0 … 12,
    depths ascending */ }
```
