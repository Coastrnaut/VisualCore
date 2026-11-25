# API contract: R02-G16-06 (StarlitCartoucheCore additions)

```swift
public struct StarlitCartoucheFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: StarlitCartoucheExperienceCore, new: StarlitCartoucheExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: StarlitCartoucheExperienceCore, destination: Int, wait: Int) -> String
}
public struct StarlitCartoucheLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: StarlitCartoucheSceneSnapshot)
    public mutating func step(toward snapshot: StarlitCartoucheSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct StarlitCartouchePartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct StarlitCartoucheAudition: Sendable, Equatable {
    public let partials: [StarlitCartouchePartial]
    public static let duration = 0.6
    public static func tone(star: Int) -> Double
    public static func of(_ play: StarlitCartouchePlay, star: Int) -> StarlitCartoucheAudition }
public enum StarlitCartoucheSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func drawnQuarters(_ play: StarlitCartouchePlay) -> Int      // 0 … 4
    public static func recipe(play: StarlitCartouchePlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow`, and gives the fallback parts
// `wonLevel: lights.won` (rebuilt when it moves by a tenth or more).
```
