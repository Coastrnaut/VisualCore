# API contract: R02-G06-06 (ChronoConstellatorCore additions)

```swift
public struct ChronoConstellatorFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: ChronoConstellatorExperienceCore, new: ChronoConstellatorExperienceCore) -> Self
    public static func picked(star: Int) -> Self                 // "Star k (shape) picked." (state, no haptic)
    public static func refused(code: String) -> Self             // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String       // the same words for the panel
    public static func summaryText(core: ChronoConstellatorExperienceCore) -> String // the summary element of Q5
}
public struct ChronoConstellatorLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var rings: [Double]; public private(set) var nodes: [Double]
    public private(set) var glow: Double; public private(set) var collision: Double
    public mutating func settle(to snapshot: ChronoConstellatorSceneSnapshot)                 // jump to the targets
    public mutating func step(toward snapshot: ChronoConstellatorSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum ChronoConstellatorSoundRecipe {
    public static func recipe(onTarget: [Bool], stage: ChronoConstellatorStage) -> AmbientLoopRecipe }
// ChronoConstellatorSceneGeometry.fieldPart / fieldMesh / starPart / starMesh gain an optional `lights:` argument: ring
// shade, node brightness and collision-mark shade from the lights. Without lights the output is unchanged.
```
