# Contract: A06-P01 framework additions

```swift
// VisualCoreAudioDSP (pure)
public final class SampleRingBuffer: @unchecked Sendable {        // SPSC; Atomic indices
  public init(capacity: Int)                                       // rounded up to a power of two, 1,024…262,144
  public var capacity: Int { get }; public var totalWritten: Int { get }
  public func write(_ samples: UnsafeBufferPointer<Float>)         // never blocks, never allocates; drops oldest
  public func latest(_ count: Int, into out: inout [Float]) -> Int // copies up to count newest samples (oldest first)
}
public struct DemoSignal: Sendable {
  public enum Mode: Int, Sendable, CaseIterable { case sequence, tone440, tone1k, silence }
  public init(seed: UInt64, mode: Mode, sampleRate: Double = 48_000)
  public mutating func render(into out: UnsafeMutableBufferPointer<Float>)   // deterministic continuation
}
public struct SpectrumAnalyzer: Sendable {
  public init?(size: Int)                                          // power of two 256…4,096
  public func magnitudesDB(_ frame: [Float]) -> [Float]            // N/2 bins, Hann window
  public static func peakBin(_ magnitudesDB: [Float]) -> Int?      // nil when all below −100 dB (silence)
  public static func expectedBin(frequency: Double, sampleRate: Double, size: Int) -> Int
}
// VisualCoreAudio (iOS)
public enum AudioSourceState: Equatable, Sendable { case idle, running, failed(String) }
@MainActor public protocol AudioSource: AnyObject {
  var sampleRate: Double { get }; var state: AudioSourceState { get }
  func start(into buffer: SampleRingBuffer) throws; func stop()
}
@MainActor public final class DemoAudioSource: AudioSource { public init(signal: DemoSignal) }
@MainActor public final class FileAudioSource: AudioSource { public init(url: URL) throws }       // throws for undecodable
@MainActor public final class MicrophoneAudioSource: AudioSource { public init(permission: any MicrophonePermission) }
public enum MicrophonePermissionState: Equatable, Sendable { case notDetermined, granted, denied, restricted }
@MainActor public protocol MicrophonePermission: AnyObject { var state: MicrophonePermissionState { get }; func request() async -> MicrophonePermissionState }
@MainActor public final class SystemMicrophonePermission: MicrophonePermission { public init() }
```
