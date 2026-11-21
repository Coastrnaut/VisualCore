# API contract: R02-G05-06 (ColorfallCanyonsCore additions)

```swift
public struct ColorfallCanyonsFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: ColorfallCanyonsExperienceCore, new: ColorfallCanyonsExperienceCore) -> Self
    public static func picked(cell: Int, columns: Int) -> Self   // "Row r, column c picked." (state, no haptic)
    public static func refused(code: String) -> Self             // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String       // the same words for the panel
    public static func summaryText(core: ColorfallCanyonsExperienceCore) -> String // the summary element of Q5
}
public struct ColorfallCanyonsLights: Sendable, Equatable {
    public struct Sheet: Sendable, Equatable { public let level: Double; public let weights: SIMD3<Double> }
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var sheets: [Int: Sheet]; public private(set) var emitters: [Double]; public private(set) var glow: Double
    public mutating func settle(to snapshot: ColorfallCanyonsSceneSnapshot)                 // jump to the targets
    public mutating func step(toward snapshot: ColorfallCanyonsSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum ColorfallCanyonsSoundRecipe {
    public static func recipe(basinMasses: [[Int]], stage: ColorfallCanyonsStage) -> AmbientLoopRecipe }
// ColorfallCanyonsSceneGeometry.fluidPart / fluidMesh / featurePart / featureMesh gain an optional `lights:` argument:
// sheet brightness and emitter brightness from the lights, fading sheets drawn with their remembered weights. Without
// lights the output is unchanged.
```
