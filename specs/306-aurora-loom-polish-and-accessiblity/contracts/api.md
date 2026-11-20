# API contract: R02-G01-06 (AuroraLoomCore additions)

```swift
public struct AuroraLoomFeedbackPlan: Sendable, Equatable {
    public let announcement: (text: String, kind: AnnouncementKind)?   // as Equatable fields: text: String?, kind: AnnouncementKind?
    public let haptic: HapticKind?
    public static func after(old: AuroraLoomExperienceCore, new: AuroraLoomExperienceCore) -> AuroraLoomFeedbackPlan
    public static func refused(code: String) -> AuroraLoomFeedbackPlan        // rejection + error
}
public struct AuroraLoomLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var crossings: [Double]   // 12, ribbon * 4 + gate
    public private(set) var glow: Double
    public mutating func step(toward snapshot: AuroraLoomSceneSnapshot, elapsed: Double)
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum AuroraLoomSoundRecipe { public static func recipe(steps: AuroraLoomSteps, stage: AuroraLoomStage) -> AmbientLoopRecipe }
```
