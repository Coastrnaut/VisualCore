# Contract: A06-P02 framework additions (VisualCoreAudioDSP, pure)

```swift
public enum LevelMeter {
  public static let floorDB: Float                                       // −120
  public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float  // non-finite → 0; empty → 0
  public static func peak(_ samples: UnsafeBufferPointer<Float>) -> Float
  public static func dBFS(_ amplitude: Float) -> Float                   // 20·log10, floored
}
public struct BandLayout: Sendable, Equatable {
  public init?(bandCount: Int = 16, lowestFrequency: Double = 40, highestFrequency: Double = 16_000,
               sampleRate: Double, size: Int)
  public let bandCount: Int; public let sampleRate: Double; public let size: Int
  public let bins: [Range<Int>]
}
public final class SpectrumWorkspace { public init?(size: Int) }          // buffers for one size
extension SpectrumAnalyzer {
  public func powerSpectrum(_ frame: UnsafeBufferPointer<Float>, into power: UnsafeMutableBufferPointer<Float>,
                            workspace: SpectrumWorkspace)                 // N/2 linear powers; no allocation
}
public struct FeatureSmoother: Sendable, Equatable {
  public init(attack: Double, release: Double); public private(set) var value: Float
  @discardableResult public mutating func update(target: Float, elapsed: Double) -> Float
  public mutating func reset()
}
public struct OnsetDetector: Sendable {
  public init(historyCount: Int = 43, multiple: Float = 1.5, minimum: Float = 1e-4, minimumInterval: Double = 0.1)
  public mutating func update(flux: Float, time: Double) -> Bool
  public mutating func reset()
}
public struct AudioFeatures: Sendable, Equatable {
  public var timestamp: Double; public var rms: Float; public var peak: Float; public var bandEnergies: [Float]
  public var flux: Float; public var onset: Bool; public var beatEnergy: Float
  public var rmsDB: Float { get }; public var peakDB: Float { get }; public func bandDB(_ index: Int) -> Float
  public static func silent(bandCount: Int) -> AudioFeatures
}
public final class FeatureExtractor {
  public static let beatAttack: Double; public static let beatRelease: Double   // 0.01, 0.25
  public init?(size: Int = 1_024, sampleRate: Double, bandCount: Int = 16)
  public let layout: BandLayout; public private(set) var features: AudioFeatures
  @discardableResult public func analyze(_ samples: UnsafeBufferPointer<Float>, time: Double, elapsed: Double) -> AudioFeatures
  public func reset()
}
```

Threading: `FeatureExtractor`, `SpectrumWorkspace` are single-thread (render side), not Sendable.
