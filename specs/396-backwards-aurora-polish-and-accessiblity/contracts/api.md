# API contract: R02-G10-06 (BackwardsAuroraCore additions)

```swift
public struct BackwardsAuroraFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: BackwardsAuroraExperienceCore, new: BackwardsAuroraExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: BackwardsAuroraExperienceCore, sectionStart: Int, sectionEnd: Int) -> String
}
public struct BackwardsAuroraLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public private(set) var tear: Double; public private(set) var preview: Double
    public mutating func settle(to snapshot: BackwardsAuroraSceneSnapshot, previewing: Bool)
    public mutating func step(toward snapshot: BackwardsAuroraSceneSnapshot, previewing: Bool, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum BackwardsAuroraSoundRecipe {
    public static func rootStep(worstBend: Int, limit: Int) -> Int            // 0 … 3
    public static func recipe(play: BackwardsAuroraPlay) -> AmbientLoopRecipe }
// BackwardsAuroraSceneGeometry.auroraPart / auroraMesh gain `fadingTear: Int? = nil`: the tear cross is drawn on the
// last torn seam while the snapshot shows no tear (nil: output unchanged). BackwardsAuroraShaders gains
// `tearLightUniform` ("u_tearLight") and `previewLightUniform` ("u_previewLight"), scaling those materials' alphas; the
// scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow` and passes `lights.tear` and
// `lights.preview` (1 without lights).
```
