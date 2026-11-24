# API contract: R02-G15-06 (VoxelOrigamiCore additions)

```swift
public struct VoxelOrigamiFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: VoxelOrigamiExperienceCore, new: VoxelOrigamiExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: VoxelOrigamiExperienceCore, hinge: Int) -> String
}
public struct VoxelOrigamiLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: VoxelOrigamiSceneSnapshot)
    public mutating func step(toward snapshot: VoxelOrigamiSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct VoxelOrigamiPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct VoxelOrigamiAudition: Sendable, Equatable {
    public let partials: [VoxelOrigamiPartial]
    public static let duration = 0.6
    public static func tone(hinge: Int) -> Double
    public static func of(_ play: VoxelOrigamiPlay, hinge: Int) -> VoxelOrigamiAudition }
public enum VoxelOrigamiSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func coveredQuarters(_ play: VoxelOrigamiPlay) -> Int      // 0 … 4
    public static func recipe(play: VoxelOrigamiPlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow`, and gives the fallback parts
// `wonLevel: lights.won` (rebuilt when it moves by a tenth or more).
```
