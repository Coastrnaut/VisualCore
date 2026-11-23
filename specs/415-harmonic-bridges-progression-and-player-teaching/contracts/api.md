# API contract: R02-G12-05

```swift
extension HarmonicBridgesSolver {
    public static func plan(_ level: HarmonicBridgesLevel, pegs: [Int],
                            workBound: Int = workBound) -> HarmonicBridgesPlan? }   // the level at those pegs, locks kept
public struct HarmonicBridgesHintPlan: Sendable, Equatable { public let actions: [HarmonicBridgesAction] }   // first = the hint
public enum HarmonicBridgesHintKind: String, Sendable, Codable { case tune, test, stuck }
public struct HarmonicBridgesHint: Sendable, Equatable { public let level: Int; public let kind: HarmonicBridgesHintKind
    public let action: HarmonicBridgesAction?; public var text: String }
public enum HarmonicBridgesHints {
    public static func plan(_ play: HarmonicBridgesPlay) -> HarmonicBridgesHintPlan?       // nil: no plan in the moves left
    public static func hint(level: Int, play: HarmonicBridgesPlay) -> HarmonicBridgesHint? } // won: nil
public struct HarmonicBridgesFailureExplanation: Sendable, Equatable { public let failure: HarmonicBridgesFailure
    public let action: Int; public var text: String
    public init?(play: HarmonicBridgesPlay) }
public enum HarmonicBridgesTutorialStep: String, Sendable, Equatable, Codable { case tune, bridge, test, done
    public var text: String
    public func advanced(afterTune: Bool, bridged: Bool, ended: Bool) -> HarmonicBridgesTutorialStep }
public struct HarmonicBridgesProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 83
public enum HarmonicBridgesMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g12.locked, r02-g12.date; snapshot schema 2 with migration from 1.
```
