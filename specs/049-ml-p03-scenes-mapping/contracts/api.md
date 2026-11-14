# Contract: A06-P03 framework additions (VisualCoreAudioDSP, pure)

```swift
public enum AudioFeatureKind: String, Codable, Sendable, CaseIterable {      // level, peak, beat, low, lowMid, highMid, high
  public static let levelWindowDB: ClosedRange<Float>                        // −60…0
  public static let regionWindowDB: ClosedRange<Float>                       // −80…0
  public func normalized(_ features: AudioFeatures) -> Float                 // 0…1
}
public struct AudioMapping: Codable, Sendable, Equatable {
  public static let schemaVersion: Int                                       // 1
  public static let gainRange: ClosedRange<Double>                           // 0…4
  public static let timeRange: ClosedRange<Double>                           // 0.001…5
  public var feature: AudioFeatureKind; public var gain: Double
  public var attack: Double; public var release: Double; public var clampLow: Double; public var clampHigh: Double
  public init?(feature:gain:attack:release:clampLow:clampHigh:)              // nil when invalid
  public init(from decoder:) throws                                          // validates; unsupported version throws
}
public struct AudioMapper: Sendable {
  public init(mapping: AudioMapping); public private(set) var mapping: AudioMapping
  public mutating func value(for features: AudioFeatures, range: ClosedRange<Double>, elapsed: Double) -> Double
  public mutating func reset()
  public var smoothed: Double { get }                                        // 0…1
}
```
