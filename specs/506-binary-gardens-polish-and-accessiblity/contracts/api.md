# API contract: R02-G21-06 (BinaryGardensCore additions)

```swift
public struct BinaryGardensFeedbackPlan: Sendable, Equatable {
    public let text: String?; public let kind: AnnouncementKind?; public let haptic: HapticKind?
    public let trigger: String                                 // control, bare refusal code, "hint" or "level"
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?, trigger: String); public static let none
    public static let rulePrefix: String                       // "action.rule."
    public static func after(old: BinaryGardensExperienceCore, new: BinaryGardensExperienceCore) -> Self
    public static func refused(code: String) -> Self           // rejection + error; texts of clarification Q1
    public static func refusalText(code: String) -> String     // the same sentence for the panel (prefix read)
    public static func hint(text: String) -> Self               // a revealed hint: state, no haptic
    public static func summaryText(core: BinaryGardensExperienceCore, star: Int) -> String
    public static func keepsLight(_ world: Int, play: BinaryGardensPlay) -> Bool
    public static func worldsKeepingLight(_ play: BinaryGardensPlay) -> Int
    public static func modeName(_ mode: BinaryGardensMode) -> String   // campaign, practice or daily (feature 505)
}
public struct BinaryGardensLights: Sendable, Equatable {
    public static let normalDuration = 0.15, reducedFlashDuration = 0.45
    public static let glowPlaying = 0.7, glowWon = 1.0, glowFailed = 0.35
    public init(reducedFlash: Bool)
    public private(set) var glow: Double; public private(set) var won: Double
    public private(set) var bloom: [Double]                   // one per world, 0 … 1
    public mutating func settle(to snapshot: BinaryGardensSceneSnapshot)
    public mutating func step(toward snapshot: BinaryGardensSceneSnapshot, elapsed: Double)
    public var isSettled: Bool
    public static func maxHalfRangeCrossingsPerSecond(_ samples: [[Double]], frameRate: Double) -> Double
    public static func shortestHalfRangeChange(_ samples: [[Double]], frameRate: Double) -> Double
}
public struct BinaryGardensPartial: Sendable, Equatable { public let frequency: Double; public let gain: Double }
public struct BinaryGardensAudition: Sendable, Equatable {
    public let partials: [BinaryGardensPartial]
    public static let duration = 0.6, baseHertz = 220.0, toneGain = 0.04, fifthRatio = 1.5, beatHertz = 3.0
    public static let maxRingIndex = 7
    public static func step(ring: Int) -> Int                 // 2 × (7 − ring clamped to 0 … 7), 0 … 14
    public static func tone(ring: Int) -> Double              // 220 Hz × 2^(step / 12)
    public static func canChange(star: Int, play: BinaryGardensPlay) -> Bool   // playing and a legal move of the star
    public static func of(ring: Int, canChange: Bool) -> BinaryGardensAudition }
public enum BinaryGardensSoundRecipe {
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int        // 0 … 3, integer comparisons
    public static func lightQuarters(_ play: BinaryGardensPlay) -> Int       // ⌊4 × w / n⌋, 0 … 4
    public static func brightness(_ play: BinaryGardensPlay) -> Double       // (i₁ + i₂) / (2 × (m − 1)); 0 when m = 1
    public static func loopSeconds(play: BinaryGardensPlay) -> Int           // 4 … 16, whole cycles
    public static func recipe(play: BinaryGardensPlay) -> AmbientLoopRecipe }
extension BinaryGardensSceneGeometry {                         // on 504's camera-taking builders
    public static func glowPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, wonLevel: Bool?,
                                camera: BinaryGardensCamera, bloom: [Double]?) throws(MeshError)
        -> BinaryGardensColouredMesh                            // nil: today's 0/1 factors, bit for bit
    public static func glowMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                camera: BinaryGardensCamera, bloom: [Double]?) throws(MeshError) -> Mesh }
// The scene passes `lights.won` as `u_won`, multiplies the glow gain by `lights.glow`, builds the glow mesh with
// `lights.bloom` (rebuilt when a level crosses a 1/32 step), passes `u_motion` 0 under Reduce Motion or Reduce
// Flashing, and blends the fallback's not-won and won colours by `lights.won`
// (`BinaryGardensSystemScene.blendedColours(off:on:level:)`, rebuilt when it crosses a tenth). Nil lights draw the
// snapshot's levels at once.
```

Experience (`BinaryGardensExperience`, internal): `BinaryGardensPresenter.feedback` (`ExperienceFeedback.shared` by
default), `feedbackLog`, `lights`, `sound`, `route(_:)`, `setSound(on:)`, `controlsAppeared()`,
`controlsDisappeared()`, `sceneActive(_:)`, `summaryText`; `BinaryGardensSound` (`setWanted`, `setOnScreen`,
`setActive`, `offer(_:)`, `audition(_:)`, `shouldPlay`) over `AmbientLoopPlayer` and `SoundEffectPlayer` seams;
`BinaryGardensControls.readableWidth` 520; `BinaryGardensMirror.refusalText(code:)` forwards to the feedback plan.
