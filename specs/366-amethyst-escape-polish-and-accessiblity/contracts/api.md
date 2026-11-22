# API contract: R02-G07-06 (AmethystEscapeCore additions)

```swift
public struct AmethystEscapeFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: AmethystEscapeExperienceCore, new: AmethystEscapeExperienceCore) -> Self
    public static func drag(old: AmethystEscapeExperienceCore, new: AmethystEscapeExperienceCore, shell: Int,
                            sectors: Int) -> Self          // one plan for a multi-sector drag
    public static func picked(shell: Int, core: AmethystEscapeExperienceCore) -> Self   // "<Shell> picked." (state)
    public static func refused(code: String) -> Self         // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String   // the same words for the panel
    public static func summaryText(core: AmethystEscapeExperienceCore) -> String   // the summary element of Q5
}
public struct AmethystEscapeLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var pearl: Double; public private(set) var exit: Double; public private(set) var wedge: Double
    public mutating func settle(to snapshot: AmethystEscapeSceneSnapshot)
    public mutating func step(toward snapshot: AmethystEscapeSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum AmethystEscapeSoundRecipe {
    public static func recipe(pearlShell: Int, shells: Int, stage: AmethystEscapeStage) -> AmbientLoopRecipe }
// AmethystEscapeSceneGeometry.crystalPart / crystalMesh / glowPart / glowMesh gain an optional `lights:` argument: the
// failed wedge's amber, the pearl's and the exit's glow from the lights. Without lights the output is unchanged.
```
