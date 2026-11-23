# API contract: R02-G11-05

```swift
extension EchoCartographerSolver {
    public static func continuation(_ level: EchoCartographerLevel, knowledge: EchoCartographerKnowledge,
                                    pulsed: [EchoCartographerCell], energyLeft: Int,
                                    workBound: Int = workBound) -> [EchoCartographerCell]? }   // further pulses; [] when one placement fits
public struct EchoCartographerHintPlan: Sendable, Equatable { public let actions: [EchoCartographerAction] }   // first = the hint
public enum EchoCartographerHintKind: String, Sendable, Codable { case pulse, claim, stuck }
public struct EchoCartographerHint: Sendable, Equatable { public let level: Int; public let kind: EchoCartographerHintKind
    public let action: EchoCartographerAction?; public var text: String }
public enum EchoCartographerHints {
    public static func plan(_ play: EchoCartographerPlay) -> EchoCartographerHintPlan?        // nil: no continuation
    public static func hint(level: Int, play: EchoCartographerPlay) -> EchoCartographerHint? } // won: nil
public struct EchoCartographerFailureExplanation: Sendable, Equatable { public let failure: EchoCartographerFailure
    public let action: Int; public var text: String
    public init?(play: EchoCartographerPlay) }
public enum EchoCartographerTutorialStep: String, Sendable, Equatable, Codable { case pulse, narrow, claim, done
    public var text: String
    public func advanced(afterPulse: Bool, located: Bool, ended: Bool) -> EchoCartographerTutorialStep }
public struct EchoCartographerProgress: Sendable, Equatable, Codable { /* best energy spent and stars per level,
    frontier; record(level:energySpent:certified:) */ public static func stars(energySpent: Int, certified: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 79
public enum EchoCartographerMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss;
// codes r02-g11.locked, r02-g11.date; snapshot schema 2 with migration from 1.
```
