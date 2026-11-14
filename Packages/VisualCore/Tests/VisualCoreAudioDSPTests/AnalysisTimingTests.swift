// AnalysisTimingTests — feature 051 (A06-P05) T-A06-502 (FR-A06-501; SC-A06-502; clarification 5): after 10 warm-up
// calls, 500 calls of `analyze(_:time:elapsed:into:)` at level 0 (1,024 samples, 16 bands, 48 kHz) are timed with
// `ContinuousClock`; the mean per window is always printed and asserted below 0.5 ms only off CI.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

@Test func analysisTimingLevelZeroMeanBelowBudget() throws {
    let sampleRate = 48_000.0
    let extractor = try #require(AnalysisQuality.makeExtractor(level: 0, sampleRate: sampleRate))
    let samples = (0..<1_024).map { Float(0.5 * sin(2 * Double.pi * 1_000 * Double($0) / sampleRate)) }
    var out = AudioFeatures.silent(bandCount: extractor.layout.bandCount)
    let elapsed = 1.0 / 60.0
    let iterations = 500
    let mean: Double = samples.withUnsafeBufferPointer { buffer in
        for i in 0..<10 {
            extractor.analyze(buffer, time: Double(i) * elapsed, elapsed: elapsed, into: &out)
        }
        let clock = ContinuousClock()
        let start = clock.now
        for i in 0..<iterations {
            extractor.analyze(buffer, time: Double(10 + i) * elapsed, elapsed: elapsed, into: &out)
        }
        let duration = clock.now - start
        let c = duration.components
        let totalMs = Double(c.seconds) * 1_000 + Double(c.attoseconds) / 1e15
        return totalMs / Double(iterations)
    }
    print("analysis mean per window: \(String(format: "%.4f", mean)) ms")
    #expect(mean.isFinite && mean >= 0)
    // Repository rule: no wall-clock asserts on CI (runners are several times slower); CI only reports the value.
    if ProcessInfo.processInfo.environment["CI"] == nil {
        #expect(mean < 0.5)
    }
}
