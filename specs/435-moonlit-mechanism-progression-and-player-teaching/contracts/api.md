# API contract: R02-G14-05

```swift
extension MoonlitMechanismSolver {
    public static func plan(_ level: MoonlitMechanismLevel, phases: [Int], height: Int,
                            maxActions: Int = maxActions, workBound: Int = workBound) -> MoonlitMechanismPlan? }
    // plan(_:) == plan(level, phases: level.startingPhases, height: level.startingHeight); nil for phases of the wrong
    // count or a height out of range
public struct MoonlitMechanismHintPlan: Sendable, Equatable { public let actions: [MoonlitMechanismAction] }   // first = the hint
public enum MoonlitMechanismHintKind: String, Sendable, Codable { case turn, reseat, lamp, run, stuck }
public struct MoonlitMechanismHint: Sendable, Equatable { public let level: Int
    public let kind: MoonlitMechanismHintKind; public let action: MoonlitMechanismAction?; public var text: String }
public enum MoonlitMechanismHints {
    public static func plan(_ play: MoonlitMechanismPlay) -> MoonlitMechanismHintPlan?       // nil: no plan in the actions left
    public static func hint(level: Int, play: MoonlitMechanismPlay) -> MoonlitMechanismHint? } // won: nil
public struct MoonlitMechanismFailureExplanation: Sendable, Equatable { public let failure: MoonlitMechanismFailure
    public let action: Int; public var text: String
    public init?(play: MoonlitMechanismPlay) }
public enum MoonlitMechanismTutorialStep: String, Sendable, Equatable, Codable { case change, align, run, done
    public var text: String
    public func advanced(afterChange: Bool, aligned: Bool, ended: Bool) -> MoonlitMechanismTutorialStep }
public struct MoonlitMechanismProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 97
public enum MoonlitMechanismMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g14.locked, r02-g14.date; snapshot schema 2 with migration from 1.
```
