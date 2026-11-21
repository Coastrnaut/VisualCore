# API contract: R02-G04-06 (HueCompassCore additions)

```swift
public struct HueCompassFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: HueCompassExperienceCore, new: HueCompassExperienceCore) -> Self
    public static func picked(band: Int) -> Self             // "Band h picked." (state, no haptic)
    public static func refused(code: String) -> Self         // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String   // the same words for the panel
    public static func summaryText(core: HueCompassExperienceCore) -> String // the summary element of Q5 ("No clues yet.")
}
public struct HueCompassLights: Sendable, Equatable {
    public struct Mark: Sendable, Equatable { public let level: Double; public let bearing: Int }
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var probes: [Int: Double]; public private(set) var selection: Mark?
    public private(set) var ring: Mark?; public private(set) var glow: Double
    public mutating func settle(to snapshot: HueCompassSceneSnapshot)                  // jump to the targets (first frame)
    public mutating func step(toward snapshot: HueCompassSceneSnapshot, elapsed: Double)
    public var isSettled: Bool                                                         // every level at its target
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum HueCompassSoundRecipe {
    public static func recipe(clue: HueCompassClue?, stage: HueCompassStage) -> AmbientLoopRecipe }
// HueCompassSceneGeometry.markPart / markMesh gain an optional `lights:` argument: each mark's radius scaled by its
// level, fading marks drawn at their remembered bearing. Without lights the output is unchanged.
```
