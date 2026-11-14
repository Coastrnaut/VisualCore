// FeatureExtractorTests — feature 048 (A06-P02) T-A06-204 (FR-A06-203, 205, 206; SC-A06-202, 203): the extractor on
// synthetic signals at 48 kHz with 512-sample hops — silence, tones in their bands, a click train's onsets, a steady
// tone, non-finite samples, short input and reset. Each test analyses at most four seconds of signal (well under 1 s).
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private let rate = 48_000.0
private let hop = 512

/// Runs `signal` through `extractor` hop by hop; each update sees the newest `extractor.size` samples ending at the
/// hop and is stamped with the window's centre (the peak of its Hann weight, where an event counts most).
private func run(_ extractor: FeatureExtractor, _ signal: [Float]) -> [AudioFeatures] {
    var out: [AudioFeatures] = []
    var end = hop
    signal.withUnsafeBufferPointer { all in
        while end <= all.count {
            let start = max(0, end - extractor.size)
            let window = UnsafeBufferPointer(rebasing: all[start..<end])
            out.append(extractor.analyze(window, time: Double(end - extractor.size / 2) / rate, elapsed: Double(hop) / rate))
            end += hop
        }
    }
    return out
}

private func tone(_ frequency: Double, seconds: Double, amplitude: Float = 0.5) -> [Float] {
    (0..<Int(seconds * rate)).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / rate)) }
}

@Test func silenceGivesZeroFeatures() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    for f in run(extractor, [Float](repeating: 0, count: 24_000)) {
        #expect(f.rms == 0)
        #expect(f.peak == 0)
        #expect(f.flux == 0)
        #expect(!f.onset)
        #expect(f.beatEnergy == 0)
        #expect((0..<extractor.layout.bandCount).allSatisfy { f.bandDB($0) <= LevelMeter.floorDB })
    }
}

@Test(arguments: [100.0, 1_000.0, 5_000.0])
func aToneFillsItsOwnBand(frequency: Double) throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    let f = try #require(run(extractor, tone(frequency, seconds: 0.1)).last)
    let centre = Int((frequency * Double(extractor.size) / rate).rounded())
    let band = try #require(extractor.layout.bins.firstIndex { $0.contains(centre) })
    let loudest = try #require(f.bandEnergies.indices.max { f.bandEnergies[$0] < f.bandEnergies[$1] })
    #expect(loudest == band, "\(frequency) Hz")
    // A 1,024-sample window holds no whole number of periods of 100 Hz, so the window's RMS may differ by ±4 % in power.
    #expect(abs(f.rmsDB - LevelMeter.dBFS(Float(0.5 / 2.0.squareRoot()))) < 0.5)
}

@Test func bandEnergiesSumToTheCoveredBinsPower() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    let signal = tone(440, seconds: 0.05).enumerated().map { $1 + 0.2 * Float(sin(Double($0) * 0.9)) }
    let f = try #require(run(extractor, signal).last)
    let analyzer = try #require(SpectrumAnalyzer(size: extractor.size))
    let workspace = try #require(SpectrumWorkspace(size: extractor.size))
    var power = [Float](repeating: 0, count: extractor.size / 2)
    let window = Array(signal.suffix(extractor.size))
    window.withUnsafeBufferPointer { w in
        power.withUnsafeMutableBufferPointer { analyzer.powerSpectrum(w, into: $0, workspace: workspace) }
    }
    let covered = extractor.layout.bins.flatMap { Array($0) }.reduce(Float(0)) { $0 + power[$1] }
    let sum = f.bandEnergies.reduce(0, +)
    #expect(abs(sum - covered) <= 1e-4 * covered)
}

@Test func everyClickOfATrainIsAnOnsetWithinOneHop() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    var signal = [Float](repeating: 0, count: Int(4 * rate))
    let clicks = stride(from: Int(0.25 * rate), to: signal.count - hop, by: Int(0.5 * rate)).map { $0 }
    for c in clicks { for i in 0..<8 { signal[c + i] = 0.8 } }
    let features = run(extractor, signal)
    let onsetTimes = features.filter(\.onset).map(\.timestamp)
    #expect(onsetTimes.count == clicks.count, "\(onsetTimes)")
    for (c, t) in zip(clicks, onsetTimes) {
        let click = Double(c) / rate
        #expect(abs(t - click) <= Double(hop) / rate + 1e-9, "click \(click) onset \(t)")
    }
}

@Test func aSteadyToneHasNoOnsetAfterItsFirstWindow() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    let features = run(extractor, tone(1_000, seconds: 1))
    #expect(features.dropFirst(2).allSatisfy { !$0.onset })
}

@Test func nonFiniteSamplesCountAsSilence() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    var signal = [Float](repeating: 0, count: 4_096)
    signal[100] = .nan
    signal[2_000] = .infinity
    for f in run(extractor, signal) {
        #expect(f.rms == 0)
        #expect(f.peak == 0)
        #expect(f.bandEnergies.allSatisfy { $0 == 0 })
    }
}

@Test func fewerSamplesThanAWindowArePadded() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    let short = tone(1_000, seconds: Double(256) / rate)
    let f = short.withUnsafeBufferPointer { extractor.analyze($0, time: 0.01, elapsed: 0.01) }
    #expect(f.peak > 0.4)
    let expected = (short.reduce(Float(0)) { $0 + $1 * $1 } / Float(extractor.size)).squareRoot()
    #expect(abs(f.rms - expected) <= 1e-6 * max(1, expected))
    let empty: [Float] = []
    let g = empty.withUnsafeBufferPointer { extractor.analyze($0, time: 0.02, elapsed: 0.01) }
    #expect(g.rms == 0)
}

@Test func resetForgetsTheBeatAndTheHistory() throws {
    let extractor = try #require(FeatureExtractor(sampleRate: rate))
    var signal = [Float](repeating: 0, count: 12_000)
    for i in 6_000..<6_008 { signal[i] = 0.8 }
    let features = run(extractor, signal)
    #expect(features.contains { $0.onset })
    #expect(features.contains { $0.beatEnergy > 0.5 })
    extractor.reset()
    #expect(extractor.features == .silent(bandCount: extractor.layout.bandCount))
    // After a reset the first window has no previous one, so a loud start is no onset.
    let loud = tone(1_000, seconds: Double(1_024) / rate)
    let f = loud.withUnsafeBufferPointer { extractor.analyze($0, time: 1, elapsed: 0.01) }
    #expect(!f.onset)
    #expect(f.flux == 0)
}

@Test func invalidConfigurationsAreRefused() {
    #expect(FeatureExtractor(size: 1_000, sampleRate: rate) == nil)
    #expect(FeatureExtractor(sampleRate: 0) == nil)
    #expect(FeatureExtractor(sampleRate: rate, bandCount: 0) == nil)
    #expect(FeatureExtractor(sampleRate: rate)?.layout.bandCount == 16)
}
