# API contract: R02-G12-06 (HarmonicBridgesCore additions)

```swift
public struct HarmonicBridgesFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: HarmonicBridgesExperienceCore, new: HarmonicBridgesExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: HarmonicBridgesExperienceCore, string: Int, peg: Int) -> String
}
public struct HarmonicBridgesLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: HarmonicBridgesSceneSnapshot)
    public mutating func step(toward snapshot: HarmonicBridgesSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct HarmonicBridgesPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct HarmonicBridgesAudition: Sendable, Equatable {
    public let partials: [HarmonicBridgesPartial]
    public static let duration = 0.6
    public static func of(_ snapshot: HarmonicBridgesSceneSnapshot, string: Int, step: Int) -> HarmonicBridgesAudition }
public enum HarmonicBridgesSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func recipe(play: HarmonicBridgesPlay) -> AmbientLoopRecipe }
// HarmonicBridgesShaders gains `wonLightUniform` ("u_wonLight"), scaling the won lift; the scene passes `lights.won`
// as `u_wonLight`, multiplies the glow gain by `lights.glow`, and draws the resting step with motion 0 and no wave
// shells under Reduce Motion or Reduce Flashing.
```
