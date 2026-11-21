# API contract: R02-G04-01 (HueCompassCore)

```swift
public enum HueCompassError: Error, Equatable, Sendable { case level(String), action(String), stage, stale, allowance,
    newerSchema(Int), malformed(String); public var reasonCode: String }   // r02-g04.*
public enum HueCompassWheel {
    public static let bearings = 96, bands = 24, bearingsPerBand = 4
    public static let boundaries: [(x: Int, y: Int)]          // 96 constants, angle 2πk/96 × 65 536, rounded
    public static func bearing(x: Int, y: Int) -> Int?         // nil for (0, 0)
    public static func band(of bearing: Int, offset: Int) -> Int
    public static func bearingDistance(_ a: Int, _ b: Int) -> Int   // 0 … 48
    public static func bandDistance(_ a: Int, _ b: Int) -> Int      // 0 … 12
    public static func arc(from: Int, to: Int) -> [Int]        // bearings strictly inside the shorter arc; ccw from `from` on a tie
}
public struct HueCompassClue: Sendable, Hashable, Codable { public let bearing, hueGap, depth: Int }
public enum HueCompassAction: Sendable, Hashable, Codable { case turn(Int), probe, select(bearing: Int, band: Int) }
public struct HueCompassLevel: Sendable, Equatable { /* fields per data-model.md; init throws(HueCompassError); encoded(); decode(_:) */
    public func clue(at bearing: Int) -> HueCompassClue
    public func accepts(bearing: Int, band: Int) -> Bool }
public struct HueCompassPlay { /* stages, apply(_:expecting:), undo, redo, records, fingerprint, replay(level:records:) */ }
public struct HueCompassRules: PuzzleRules { /* State = HueCompassRules.Position (bearing, spent, outcome), Move = HueCompassAction;
    moves: turn(+1), turn(−1), probe, select(current bearing, band 0 … 23) */ }
```
