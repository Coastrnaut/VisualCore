# API contract: R02-G14-06 (MoonlitMechanismCore additions)

```swift
public struct MoonlitMechanismFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: MoonlitMechanismExperienceCore, new: MoonlitMechanismExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: MoonlitMechanismExperienceCore, gear: Int) -> String
}
public struct MoonlitMechanismLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: MoonlitMechanismSceneSnapshot)
    public mutating func step(toward snapshot: MoonlitMechanismSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct MoonlitMechanismPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct MoonlitMechanismAudition: Sendable, Equatable {
    public let partials: [MoonlitMechanismPartial]
    public static let duration = 0.6
    public static func tone(teeth: Int) -> Double
    public static func of(_ play: MoonlitMechanismPlay, gear: Int) -> MoonlitMechanismAudition }
public enum MoonlitMechanismSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func coveredQuarters(_ play: MoonlitMechanismPlay) -> Int  // 0 … 4
    public static func recipe(play: MoonlitMechanismPlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as `u_won` and multiplies the glow gain by `lights.glow`;
// `MoonlitMechanismSceneGeometry`'s fallback parts take a won level (default: the snapshot's won state).
```
