# Contract: A07-P03 core additions (module AudioOdysseyCore)

```swift
public enum EnvelopeChannel: Int, CaseIterable, Codable, Sendable { case low, mid, high, transient, overall }
public enum Sensitivity: Int, CaseIterable, Codable, Sendable { case low, medium, high; public var gain: Double }
public enum Easing: Int, CaseIterable, Codable, Sendable { case gentle, standard, brisk; public var accelerationFactor: Double }
public struct ChannelMapping: Codable, Equatable, Sendable { public var channel: EnvelopeChannel; public var sensitivity: Sensitivity }
public struct WorldMapping: Codable, Equatable, Sendable { public var primary, light: ChannelMapping; public static func defaults(for: JourneyWorld) -> WorldMapping }
public struct AudioEnvelope: Equatable, Sendable {
  public private(set) var low, mid, high, transient: Double; public var overall: Double; public private(set) var timestamp: Double
  public init()
  public mutating func update(bandEnergies: [Float], flux: Float, onset: Bool, time: Double, elapsed: Double)
  public func value(_ channel: EnvelopeChannel) -> Double
}
public struct WorldResponse: Equatable, Sendable {
  public init(world: JourneyWorld, reduceMotion: Bool, reduceFlashing: Bool)
  public private(set) var primary: Double; public private(set) var light: Double
  public mutating func update(primaryTarget: Double, lightTarget: Double)   // 0…1, clamped, step-limited
}
```
