# API contract: R02-G16-05

```swift
extension StarlitCartoucheSolver {
    public static func plan(_ level: StarlitCartoucheLevel, from star: Int, beat: Int, drawn: Set<Int>,
                            maxLegs: Int = maxLegs, workBound: Int = workBound) -> StarlitCartouchePlan? }
    // plan(level) == plan(level, from: level.start, beat: 0, drawn: []); nil for an unknown star or a state that
    // already wins
public struct StarlitCartoucheHintPlan: Sendable, Equatable { public let legs: [StarlitCartoucheAction] }   // first = the hint
public enum StarlitCartoucheHintKind: String, Sendable, Codable { case leg, stuck }
public struct StarlitCartoucheHint: Sendable, Equatable { public let level: Int
    public let kind: StarlitCartoucheHintKind; public let action: StarlitCartoucheAction?; public var text: String }
public enum StarlitCartoucheHints {
    public static func plan(_ play: StarlitCartouchePlay) -> StarlitCartoucheHintPlan?       // nil: no plan in the actions left
    public static func hint(level: Int, play: StarlitCartouchePlay) -> StarlitCartoucheHint? } // won: nil
public struct StarlitCartoucheFailureExplanation: Sendable, Equatable { public let failure: StarlitCartoucheFailure
    public let action: Int; public var text: String
    public init?(play: StarlitCartouchePlay) }
public enum StarlitCartoucheTutorialStep: String, Sendable, Equatable, Codable { case fly, symbol, recover, done
    public var text: String
    public func advanced(afterLeg: Bool, ended: Bool) -> StarlitCartoucheTutorialStep }
public struct StarlitCartoucheProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 37
public enum StarlitCartoucheMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g16.locked, r02-g16.date; snapshot schema 2 with migration from 1.
```
