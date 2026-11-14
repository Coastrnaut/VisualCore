# Contract: A08-P01 public API (VisualCore) and experience actions

## VisualCoreAudioDSP (new, public, `///`-documented)

- `public struct TestSignal: Sendable, Equatable` — `enum Waveform: Int, CaseIterable { case sine, square, sweep }`;
  `init(waveform:frequency:amplitude:sampleRate:channelCount:rightRatio:rightPhase:sweepEnd:sweepDuration:)` (nil-free;
  values clamped to the data-model ranges); `mutating func render(frames: Int, left: inout [Float], right: inout [Float])`;
  `func value(atFrame: Int, channel: Int) -> Float` (closed form for tests); `static func periods(frequency:sampleCount:sampleRate:) -> Double`.
- `public final class StereoSampleBuffer: @unchecked Sendable` — `init(capacityFrames:)`, `capacityFrames`,
  `totalFrames`, `write(left:right:)`, `frames(from:count:left:right:) -> Int`, `latestFrames(_:left:right:) -> Int`.
- `public struct TriggerSettings: Sendable, Equatable`, `public enum TriggerSlope`, `public enum TriggerMode`,
  `public enum ScopeTrigger` — `static func find(in samples: [Float], settings:, searchRange: Range<Int>) -> Int?`.
- `public struct TimebaseWindow: Sendable, Equatable` — `secondsPerDivision`, `divisions` (10), `maxSamples` (4,096),
  `sampleCount(sampleRate:) -> Int`, `isShortened(sampleRate:) -> Bool`.

## VisualCoreAudio (new, public)

- `@MainActor public protocol StereoAudioSource: AnyObject` — `sampleRate`, `state: AudioSourceState`, `channelCount`,
  `start(into: StereoSampleBuffer) throws`, `stop()`.
- `TestSignalAudioSource(signal:)` (1,024-frame blocks at real-time pace, catch-up ≤ 8 blocks, first block written by
  `start`); `StereoFileAudioSource(url:) throws` (`AudioSourceError.undecodable`; looped at real-time pace; mono files
  `channelCount` 1).

## Experience actions (`a08.oscilloscope-studio`)

`source.select [0…2]`, `signal.waveform [0…2]`, `signal.frequency [0…3]`, `gain.select [0…4]`, `timebase.select [0…5]`,
`trigger.level [−1…1]`, `trigger.slope [0…1]`, `trigger.mode [0…1]`; refused values give typed rejections with codes
`a08.*`. Snapshot schema 1 = `ScopeState`.
