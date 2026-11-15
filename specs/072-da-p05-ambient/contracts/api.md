# Contract: A09-P05 API (app-local; no VisualCore change)

## DigitalAquariumCore

```swift
public struct AquariumBudget: Equatable, Sendable { bubblesPerVent: Int; motes: Int; causticsOctaves: Int
    public static func budget(tier: Int, ambient: Bool) -> AquariumBudget }
public struct AmbientDimmer: Equatable, Sendable { idleInterval 60, fadeDuration 2, dimLevel 0.6
    public private(set) var idle: Double; public var brightness: Double
    public mutating func advance(by seconds: Double, active: Bool); public mutating func touch() }
public struct AquariumConfiguration: Codable, Equatable, Sendable { … format 1 …
    public static func make(document: HabitatDocument, decorKind: Int, ambient: Bool, name: String, id: UUID,
                            savedAt: Date) -> AquariumConfiguration
    public func validate(catalog: SpeciesCatalog) -> [String]
    public func actions(catalog: SpeciesCatalog) -> [(control: String, values: [Double])] }
AquariumSimulation.advance(_:catalog:random:ambient: Bool = false)
AquariumSimulation.ambientSpeedFactor = 0.6
WaterEffects.bubbles(step:vents:reduceMotion:perVent: Int = bubblesPerVent)
WaterEffects.motes(step:reduceMotion:count: Int = moteCount)
```

## Experience

Actions: `ambient.mode [0…1]`, `decor.turn [0…11, −π…π, 0.5…2.0]` (`a09.no-such-decor`). `qualityTiers` 3. Snapshot
schema 4; `schemaThreeExample()`. `AquariumLibrary` (main actor): `entries`, `unreadable`, `newer`, `lastFailure`,
`save(name:core:) -> Bool`, `open(_:port:) -> Bool`, `delete(_:) -> Bool`; limit 12. Presenter init gains
`lowPowerMode: (@MainActor () -> Bool)? = nil` (default `ProcessInfo.processInfo.isLowPowerModeEnabled`).
