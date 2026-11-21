# API contract: R02-G03-06 (WaveKnotKeeperCore additions)

```swift
public struct WaveKnotKeeperFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: WaveKnotKeeperExperienceCore, new: WaveKnotKeeperExperienceCore) -> Self
    public static func refused(code: String) -> Self        // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String  // the same words for the panel
}
public struct WaveKnotKeeperLights: Sendable, Equatable {
    public struct Key: Sendable, Hashable { public let first: Int; public let second: Int }
    public struct Crossing: Sendable, Equatable { public let level: Double; public let over: Int; public let fraction: Double }
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var crossings: [Key: Crossing]; public private(set) var match: Double; public private(set) var glow: Double
    public mutating func settle(to snapshot: WaveKnotKeeperSceneSnapshot)                    // jump to the targets (first frame)
    public mutating func step(toward snapshot: WaveKnotKeeperSceneSnapshot, elapsed: Double)
    public var isSettled: Bool                                                               // every level at its target
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public enum WaveKnotKeeperSoundRecipe {
    public static func recipe(summary: WaveKnotKeeperSummary, target: WaveKnotKeeperTarget,
                              stage: WaveKnotKeeperStage) -> AmbientLoopRecipe }
// WaveKnotKeeperSceneGeometry.ropeMesh / glowMesh gain an optional `lights:` argument: the crossing weights of present
// marks scaled by their levels, and fading marks drawn at their remembered fraction of their over-strand.
```
