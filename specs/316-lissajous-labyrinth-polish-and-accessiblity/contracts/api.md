# API contract: R02-G02-06 (LissajousLabyrinthCore additions)

```swift
public struct LissajousLabyrinthFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: LissajousLabyrinthExperienceCore, new: LissajousLabyrinthExperienceCore) -> Self
    public static func refused(code: String) -> Self        // rejection + error; texts of clarification Q1
}
public struct LissajousLabyrinthLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var checkpoints: [Double]; public private(set) var obstacles: [Double]; public private(set) var glow: Double
    public mutating func settle(to snapshot: LissajousLabyrinthSceneSnapshot)              // jump to the targets (first frame)
    public mutating func step(toward snapshot: LissajousLabyrinthSceneSnapshot, elapsed: Double)
    public static func targets(_ snapshot: LissajousLabyrinthSceneSnapshot) -> (checkpoints: [Double], obstacles: [Double], glow: Double)
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum LissajousLabyrinthSoundRecipe {
    public static func recipe(dials: LissajousLabyrinthDials, stage: LissajousLabyrinthStage) -> AmbientLoopRecipe }
```
