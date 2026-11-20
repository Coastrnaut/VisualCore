# API contract: R02-G03-01 (WaveKnotKeeperCore)

```swift
public enum WaveKnotKeeperError: Error, Equatable, Sendable { case level(String), move(String), stage, stale, allowance,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g03.*
public struct WaveKnotKeeperPoint: Sendable, Hashable, Codable { public let x, y, z: Int }
public struct WaveKnotKeeperGate: Sendable, Hashable, Codable { public let min, max: WaveKnotKeeperPoint; func contains(_:) -> Bool }
public struct WaveKnotKeeperTarget: Sendable, Hashable, Codable { public let crossings: Int; public let writhe: Int }
public enum WaveKnotKeeperDirection: String, CaseIterable, Codable { case plusX, minusX, plusY, minusY, plusZ, minusZ }
public struct WaveKnotKeeperMove: Sendable, Hashable, Codable { public let point: Int; public let direction: WaveKnotKeeperDirection }
public struct WaveKnotKeeperSummary: Sendable, Hashable { public let crossings: Int; public let writhe: Int; public let degenerate: Bool }
public enum WaveKnotKeeperGeometry {
    public static func summary(_ points: [WaveKnotKeeperPoint]) -> WaveKnotKeeperSummary
    public static func tension(_ points: [WaveKnotKeeperPoint]) -> Int
    public static func sweepIsClear(_ points: [WaveKnotKeeperPoint], moving index: Int, to: WaveKnotKeeperPoint) -> Bool
    public static func segmentIntersectsTriangle(_ p: WaveKnotKeeperPoint, _ q: WaveKnotKeeperPoint,
        _ a: WaveKnotKeeperPoint, _ b: WaveKnotKeeperPoint, _ c: WaveKnotKeeperPoint) -> Bool
}
public struct WaveKnotKeeperLevel: Sendable, Equatable { /* fields per data-model.md; init throws(WaveKnotKeeperError); encoded(); decode(_:) */
    public func wins(_ points: [WaveKnotKeeperPoint]) -> Bool }
public struct WaveKnotKeeperPlay { /* stages, apply(_:expecting:), undo, redo, records, fingerprint, replay(level:records:) */ }
public struct WaveKnotKeeperRules: PuzzleRules { /* State = [WaveKnotKeeperPoint], Move = WaveKnotKeeperMove */ }
```
