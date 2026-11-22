# API contract: R02-G08-06 (FacetedForgeCore additions)

```swift
public struct FacetedForgeFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: FacetedForgeExperienceCore, new: FacetedForgeExperienceCore) -> Self
    public static func refused(code: String) -> Self         // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String   // the same words for the panel
    public static func summaryText(core: FacetedForgeExperienceCore, choice: FacetedForgePreviewChoice) -> String
}
public struct FacetedForgeLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var sliver: Double
    public mutating func settle(to snapshot: FacetedForgeSceneSnapshot)
    public mutating func step(toward snapshot: FacetedForgeSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum FacetedForgeSoundRecipe {
    public static func recipe(pieces: Int, target: Int, stage: FacetedForgeStage) -> AmbientLoopRecipe }
// FacetedForgeSceneGeometry.crystalPart / crystalMesh gain an optional `lights:` argument: the sliver cross's shade from
// the lights; the scene multiplies the glow gain by `lights.glow`. Without lights the output is unchanged.
```
