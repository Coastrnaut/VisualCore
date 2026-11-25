# API contract: R02-G17-06 (CelestialEclipseLabCore additions)

```swift
public struct CelestialEclipseLabFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?); public static let none: Self
    public static func after(old: CelestialEclipseLabExperienceCore, new: CelestialEclipseLabExperienceCore) -> Self
    public static func refused(code: String) -> Self          // rejection + error; texts of clarification Q1 (prefix read)
    public static func refusalText(code: String) -> String    // the same words for the panel
    public static func hint(text: String) -> Self              // a revealed hint: state, no haptic
    public static func summaryText(core: CelestialEclipseLabExperienceCore, body: Int, phase: Int) -> String
}
public struct CelestialEclipseLabLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public mutating func settle(to snapshot: CelestialEclipseLabSceneSnapshot)
    public mutating func step(toward snapshot: CelestialEclipseLabSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct CelestialEclipseLabPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct CelestialEclipseLabAudition: Sendable, Equatable {
    public let partials: [CelestialEclipseLabPartial]
    public static let duration = 0.6
    public static func tone(body: Int) -> Double
    public static func of(_ play: CelestialEclipseLabPlay, body: Int) -> CelestialEclipseLabAudition }
public enum CelestialEclipseLabSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3
    public static func matchedQuarters(_ play: CelestialEclipseLabPlay) -> Int // 0 … 4
    public static func recipe(play: CelestialEclipseLabPlay) -> AmbientLoopRecipe }
// The scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow`, blends the fallback sky's
// not-won and won colours by `lights.won` (`CelestialEclipseLabSkyScene.blendedColours(off:on:level:)`, rebuilt when
// it moves by a tenth or more), and asks the halo pulse with Reduce Motion or Reduce Flashing set.
```
