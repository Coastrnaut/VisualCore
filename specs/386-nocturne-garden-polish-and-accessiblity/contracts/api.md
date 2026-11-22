# API contract: R02-G09-06 (NocturneGardenCore additions)

```swift
public struct NocturneGardenFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: NocturneGardenExperienceCore, new: NocturneGardenExperienceCore) -> Self
    public static func refused(code: String) -> Self         // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String   // the same words for the panel
    public static func summaryText(core: NocturneGardenExperienceCore) -> String
}
public struct NocturneGardenLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var leak: Double
    public mutating func settle(to snapshot: NocturneGardenSceneSnapshot)
    public mutating func step(toward snapshot: NocturneGardenSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum NocturneGardenSoundRecipe {
    public static func recipe(blooms: Int, sun: Int, stage: NocturneGardenStage) -> AmbientLoopRecipe }
// NocturneGardenSceneGeometry.gardenPart / gardenMesh gain an optional `lights:` argument: the leak cross's shade from the
// lights; the scene multiplies the glow gain by `lights.glow`. Without lights the output is unchanged.
```
