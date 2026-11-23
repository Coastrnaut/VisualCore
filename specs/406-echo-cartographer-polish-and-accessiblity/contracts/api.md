# API contract: R02-G11-06 (EchoCartographerCore additions)

```swift
public struct EchoCartographerFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: EchoCartographerExperienceCore, new: EchoCartographerExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: EchoCartographerExperienceCore, cursor: EchoCartographerCell) -> String
}
public struct EchoCartographerLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: EchoCartographerSceneSnapshot)
    public mutating func step(toward snapshot: EchoCartographerSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum EchoCartographerSoundRecipe {
    public static func rootStep(energy: Int, budget: Int) -> Int            // 0 … 3
    public static func recipe(play: EchoCartographerPlay) -> AmbientLoopRecipe }
// EchoCartographerShaders gains `wonLightUniform` ("u_wonLight"), scaling EC_WON_LIFT; the scene passes `lights.won`
// as `u_wonLight`, multiplies the glow gain by `lights.glow` and passes `u_reduceMotion` = 1 under Reduce Motion or
// Reduce Flashing (1 for u_wonLight without lights).
```
