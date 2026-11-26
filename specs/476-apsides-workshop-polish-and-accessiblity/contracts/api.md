# API contract: R02-G18-06 (ApsidesWorkshopCore additions)

```swift
public struct ApsidesWorkshopFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: ApsidesWorkshopExperienceCore, new: ApsidesWorkshopExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: ApsidesWorkshopExperienceCore, pending: ApsidesWorkshopOrbit?) -> String
}
public struct ApsidesWorkshopLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: ApsidesWorkshopSceneSnapshot)
    public mutating func step(toward snapshot: ApsidesWorkshopSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct ApsidesWorkshopPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct ApsidesWorkshopAudition: Sendable, Equatable {
    public let partials: [ApsidesWorkshopPartial]
    public static let duration = 0.6
    public static func step(size: Int) -> Int                 // (48 − a) / 4 rounded down, 0 … 10
    public static func tone(size: Int) -> Double              // 220 Hz × 2^(step / 12)
    public static func of(_ orbit: ApsidesWorkshopOrbit, level: ApsidesWorkshopLevel) -> ApsidesWorkshopAudition }
public enum ApsidesWorkshopSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func metQuarters(_ play: ApsidesWorkshopPlay) -> Int       // 0 … 4
    public static func recipe(play: ApsidesWorkshopPlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow`, blends the fallback compass's
// not-won and won colours by `lights.won` (`ApsidesWorkshopCompassScene.blendedColours(off:on:level:)`, rebuilt when
// it moves by a tenth or more), and asks the star pulse with Reduce Motion or Reduce Flashing set.
```
