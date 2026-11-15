# Contract: A09-P04 API (app-local; no VisualCore change)

## DigitalAquariumCore

```swift
public enum WaterEffects {
    public static let maxBubbles = 48, bubblesPerVent = 24, releaseInterval = 20, moteCount = 24
    public static let riseSpeed = 1.2, wobble = 0.08, wobbleHz = 1.5, surface = 9.0, ventY = 1.0, moteSpeed = 0.05
    public static func bubbles(step: Int, vents: [Double], reduceMotion: Bool) -> [Vec2]
    public static func motes(step: Int, reduceMotion: Bool) -> [Vec2]
    public static func layer(index: Int) -> Int                       // 0 back, 1 middle, 2 front
    public static func scale(layer: Int) -> Double
    public static func tint(layer: Int) -> Double
    public static func tinted(_ color: RGBA, toward water: RGBA, amount: Double) -> RGBA
}
public enum AquariumWording {
    public static func description(document: HabitatDocument, catalog: SpeciesCatalog, paused: Bool) -> String
    public static func change(from old: AquariumWordingState?, to new: AquariumWordingState) -> String?
}
public struct AquariumWordingState: Equatable, Sendable { habitatId, habitatName, foodCount, decorCount, paused }
public struct AquariumAnnouncer: Equatable, Sendable {
    public static let interval = 3.0
    public init(voiceOverRunning: Bool)
    public mutating func announce(_ text: String, at time: Double) -> Bool
    public mutating func tick(at time: Double) -> String?
    public mutating func reset()
}
```

## Experience

`CausticsScene` (internal, main actor): wraps `FullScreenShaderScene`; `isAvailable` false after a failed setup.
Presenter init gains `announcementSink: (any AnnouncementSink)? = nil, voiceOverRunning: (@MainActor () -> Bool)? =
nil` (defaults: `SystemAnnouncementSink`, the system VoiceOver state), as `ScopePresenter`.
