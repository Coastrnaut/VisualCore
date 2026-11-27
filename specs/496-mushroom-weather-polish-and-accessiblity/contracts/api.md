# API contract: R02-G20-06 (MushroomWeatherCore additions)

```swift
public struct MushroomWeatherFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: MushroomWeatherExperienceCore, new: MushroomWeatherExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: MushroomWeatherExperienceCore, slot: Int, site: Int?) -> String
}
public struct MushroomWeatherLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: MushroomWeatherSceneSnapshot)
    public mutating func step(toward snapshot: MushroomWeatherSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct MushroomWeatherPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct MushroomWeatherAudition: Sendable, Equatable {
    public let partials: [MushroomWeatherPartial]
    public static let duration = 0.6
    public static func step(site: Int) -> Int                 // 2 × site index, 0 … 14
    public static func tone(site: Int) -> Double              // 220 Hz × 2^(step / 12)
    public static func of(site: Int, placeable: Bool) -> MushroomWeatherAudition }
public enum MushroomWeatherSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func bandQuarters(_ play: MushroomWeatherPlay) -> Int      // 0 … 4
    public static func recipe(play: MushroomWeatherPlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as the won uniform, multiplies the glow gain by `lights.glow`, passes motion 0 under
// Reduce Motion or Reduce Flashing, and blends the fallback forest's not-won and won colours by `lights.won`
// (`MushroomWeatherForestScene.blendedColours(off:on:level:)`, rebuilt when it moves by a tenth or more).
```
