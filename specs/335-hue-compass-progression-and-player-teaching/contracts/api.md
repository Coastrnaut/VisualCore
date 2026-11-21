# API contract: R02-G04-05

```swift
public enum HueCompassHintKind: String, Sendable, Codable { case probe, select, guess }
public struct HueCompassHint: Sendable, Equatable { public let level: Int; public let kind: HueCompassHintKind
    public let bearing: Int; public let band: Int?; public let consistent: Int; public var text: String }
public enum HueCompassHints {
    public static func consistent(_ play: HueCompassPlay) -> [Int]              // candidates matching every clue seen
    public static func hint(level: Int, play: HueCompassPlay) -> HueCompassHint? }   // nil when not playing
public struct HueCompassFailureExplanation: Sendable, Equatable { public let failure: HueCompassFailure
    public let target: Int; public let targetBand: Int; public let bearingDistance: Int?; public let bandDistance: Int?
    public var text: String; public init?(play: HueCompassPlay) }
public enum HueCompassTutorialStep: String, Sendable, Equatable, Codable { case aim, probe, select, done
    public var text: String }
public struct HueCompassProgress: Sendable, Equatable, Codable { /* best units and stars per level, frontier;
    record(level:units:smallest:) */ public static func stars(units: Int, smallest: Int) -> Int
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? }   // × 47
public enum HueCompassMode: Sendable, Equatable, Codable { case campaign, practice, daily(level: Int) }
// Adapter controls added: level.select [1…100], mode.daily [y, m, d], mode.practice, mode.campaign, tutorial.dismiss,
// tutorial.hint; codes r02-g04.locked, r02-g04.date; snapshot schema 2 with migration from 1.
```
