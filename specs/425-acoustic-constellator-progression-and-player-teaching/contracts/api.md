# API contract: R02-G13-05

```swift
extension AcousticConstellatorSolver {
    public static func plan(_ level: AcousticConstellatorLevel, links: [AcousticConstellatorLink], phases: [Int],
                            maxActions: Int = maxActions, workBound: Int = workBound) -> AcousticConstellatorPlan? }
    // plan(_:) == plan(level, links: level.fixedLinks, phases: level.startingPhases); the plan's links exclude `links`
public struct AcousticConstellatorHintPlan: Sendable, Equatable { public let actions: [AcousticConstellatorAction] }   // first = the hint
public enum AcousticConstellatorHintKind: String, Sendable, Codable { case linkSymbol, linkHelper, nudge, listen, stuck }
public struct AcousticConstellatorHint: Sendable, Equatable { public let level: Int
    public let kind: AcousticConstellatorHintKind; public let action: AcousticConstellatorAction?; public var text: String }
public enum AcousticConstellatorHints {
    public static func plan(_ play: AcousticConstellatorPlay) -> AcousticConstellatorHintPlan?       // nil: no plan in the moves left
    public static func hint(level: Int, play: AcousticConstellatorPlay) -> AcousticConstellatorHint? } // won: nil
public struct AcousticConstellatorFailureExplanation: Sendable, Equatable { public let failure: AcousticConstellatorFailure
    public let action: Int; public var text: String
    public init?(play: AcousticConstellatorPlay) }
public enum AcousticConstellatorTutorialStep: String, Sendable, Equatable, Codable { case link, complete, listen, done
    public var text: String
    public func advanced(afterLink: Bool, complete: Bool, ended: Bool) -> AcousticConstellatorTutorialStep }
public struct AcousticConstellatorProgress: Sendable, Equatable, Codable { /* best actions spent and stars per level,
    frontier; record(level:actionsSpent:certified:) */ public static func stars(actionsSpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 89
public enum AcousticConstellatorMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g13.locked, r02-g13.date; snapshot schema 2 with migration from 1.
```
