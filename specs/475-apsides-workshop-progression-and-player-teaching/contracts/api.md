# API contract: R02-G18-05

```swift
extension ApsidesWorkshopSolver {
    public static func plan(_ level: ApsidesWorkshopLevel, from orbit: ApsidesWorkshopOrbit, maxTunings: Int = 2,
                            workBound: Int = workBound) -> ApsidesWorkshopPlan? }
    // plan(level) == plan(level, from: level.orbit); a plan of no tunings when the orbit already wins
public struct ApsidesWorkshopHintPlan: Sendable, Equatable { public let tunings: [ApsidesWorkshopAction] }
public enum ApsidesWorkshopHintKind: String, Sendable, Codable { case tune, play, stuck }
public struct ApsidesWorkshopHint: Sendable, Equatable { public let level: Int
    public let kind: ApsidesWorkshopHintKind; public let action: ApsidesWorkshopAction?; public var text: String }
public enum ApsidesWorkshopHints {
    public static func plan(_ play: ApsidesWorkshopPlay) -> ApsidesWorkshopHintPlan?     // nil: none in the actions left
    public static func hint(level: Int, play: ApsidesWorkshopPlay) -> ApsidesWorkshopHint? } // won: nil
public struct ApsidesWorkshopFailureExplanation: Sendable, Equatable {
    public let failure: ApsidesWorkshopFailure; public var text: String
    public init?(play: ApsidesWorkshopPlay) }
public enum ApsidesWorkshopTutorialStep: String, Sendable, Equatable, Codable { case knob, order, recover, done
    public var text: String
    public func advanced(afterTuning: Bool, ended: Bool) -> ApsidesWorkshopTutorialStep }
public struct ApsidesWorkshopProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 23
public enum ApsidesWorkshopMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g18.locked, r02-g18.date; snapshot schema 2 with migration from 1.
```
