# API contract: R02-G13-06 (AcousticConstellatorCore additions)

```swift
public struct AcousticConstellatorFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: AcousticConstellatorExperienceCore, new: AcousticConstellatorExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: AcousticConstellatorExperienceCore, star: Int, partner: Int) -> String
}
public struct AcousticConstellatorLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: AcousticConstellatorSceneSnapshot)
    public mutating func step(toward snapshot: AcousticConstellatorSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct AcousticConstellatorPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct AcousticConstellatorAudition: Sendable, Equatable {
    public let partials: [AcousticConstellatorPartial]
    public static let duration = 0.6
    public static func of(_ snapshot: AcousticConstellatorSceneSnapshot, link: AcousticConstellatorLink, tick: Int) -> AcousticConstellatorAudition }
public enum AcousticConstellatorSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func recipe(play: AcousticConstellatorPlay) -> AmbientLoopRecipe }
// AcousticConstellatorShaders gains `wonLightUniform` ("u_wonLight"), scaling the won look (the `wonLink`
// material's lift and the `.wonGlow` strips); the scene passes `lights.won` as `u_wonLight`, multiplies the glow gain by
// `lights.glow`, and draws tick 0 with pulse 0 and no wave shells under Reduce Motion or Reduce Flashing.
```
