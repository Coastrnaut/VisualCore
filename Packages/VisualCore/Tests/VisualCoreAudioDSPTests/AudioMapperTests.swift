// AudioMapperTests — feature 049 (A06-P03) T-A06-302 (FR-A06-301, FR-A06-302; SC-A06-301): a settled gain-1 mapping
// maps normalised 0 / 0.5 / 1 to the range minimum / midpoint / maximum within 1e-6; gain 2 doubles before the clamp;
// 1,000 seeded random feature sets stay within the range; one update of exactly `attack` (or `release`) seconds reaches
// 1 − 1/e (or decays to 1/e); reset returns to the range minimum; setMapping keeps the smoothing state.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

/// A small deterministic generator for the random-input test (SplitMix64).
private struct AudioMapperSplitMix64 {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A uniform value in 0…1.
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
}

/// A beat-only feature set with the given beat energy (normalises exactly to `beat` for `.beat`).
private func audioMapperBeat(_ beat: Float) -> AudioFeatures {
    AudioFeatures(timestamp: 0, rms: 0, peak: 0, bandEnergies: [Float](repeating: 0, count: 16), flux: 0,
                  onset: false, beatEnergy: beat)
}

@Test func audioMapperSettledGainOneIsLinearToRange() throws {
    let range = 2.0...3.0
    for kind in AudioFeatureKind.allCases {
        for n in [Float(0), 0.5, 1] {
            let features: AudioFeatures
            switch kind {
            case .level, .peak:
                let db = -60 + 60 * n
                features = audioMappingFeatures(rmsDB: db, peakDB: db)
            case .beat:
                features = audioMapperBeat(n)
            case .low, .lowMid, .highMid, .high:
                features = audioMappingFeatures(bandEnergy: pow(10, (-80 + 80 * n) / 10) / 4)
            }
            var mapper = AudioMapper(mapping: try #require(AudioMapping(feature: kind, gain: 1)))
            var value = 0.0
            for _ in 0..<3 { value = mapper.value(for: features, range: range, elapsed: 10) }
            let expected = range.lowerBound + Double(n) * (range.upperBound - range.lowerBound)
            #expect(abs(value - expected) <= 1e-6, "\(kind) at n = \(n): \(value)")
        }
    }
}

@Test func audioMapperGainTwoDoublesBeforeClamp() throws {
    let range = 0.0...10.0
    var mapper = AudioMapper(mapping: try #require(AudioMapping(feature: .beat, gain: 2)))
    #expect(abs(mapper.value(for: audioMapperBeat(0.25), range: range, elapsed: 10) - 5) <= 1e-6)
    #expect(abs(mapper.value(for: audioMapperBeat(0.75), range: range, elapsed: 10) - 10) <= 1e-6)
    var clamped = AudioMapper(mapping: try #require(AudioMapping(feature: .beat, gain: 2, clampLow: 0.2,
                                                                 clampHigh: 0.6)))
    #expect(abs(clamped.value(for: audioMapperBeat(0.05), range: range, elapsed: 10) - 2) <= 1e-6)
    #expect(abs(clamped.value(for: audioMapperBeat(0.5), range: range, elapsed: 10) - 6) <= 1e-6)
}

@Test func audioMapperRandomFeaturesStayInRange() throws {
    var random = AudioMapperSplitMix64(state: 0x0049_A060_0302)
    let range = -1.5...2.5
    var mappers = try AudioFeatureKind.allCases.map {
        AudioMapper(mapping: try #require(AudioMapping(feature: $0, gain: 4, attack: 0.001, release: 0.001)))
    }
    for _ in 0..<1_000 {
        let features = AudioFeatures(
            timestamp: 0, rms: random.unit() * 2, peak: random.unit() * 2,
            bandEnergies: (0..<16).map { _ in random.unit() * 4 }, flux: 0, onset: false,
            beatEnergy: random.unit() * 3 - 1)
        let elapsed = Double(random.unit()) * 0.1
        for i in mappers.indices {
            let value = mappers[i].value(for: features, range: range, elapsed: elapsed)
            #expect(range.contains(value))
            #expect((0...1).contains(mappers[i].smoothed))
        }
    }
}

@Test func audioMapperAttackAndReleaseStepTiming() throws {
    let attack = 0.1
    let release = 0.4
    let range = 0.0...1.0
    var mapper = AudioMapper(mapping: try #require(AudioMapping(feature: .beat, gain: 1, attack: attack,
                                                                release: release)))
    _ = mapper.value(for: audioMapperBeat(1), range: range, elapsed: attack)
    #expect(abs(mapper.smoothed - (1 - exp(-1.0))) <= 1e-3)
    _ = mapper.value(for: audioMapperBeat(1), range: range, elapsed: 10)
    #expect(abs(mapper.smoothed - 1) <= 1e-6)
    _ = mapper.value(for: audioMapperBeat(0), range: range, elapsed: release)
    #expect(abs(mapper.smoothed - exp(-1.0)) <= 1e-3)
}

@Test func audioMapperResetReturnsToRangeMinimum() throws {
    let range = 3.0...7.0
    var mapper = AudioMapper(mapping: try #require(AudioMapping(feature: .beat, gain: 1)))
    _ = mapper.value(for: audioMapperBeat(1), range: range, elapsed: 10)
    #expect(mapper.smoothed > 0.99)
    mapper.reset()
    #expect(mapper.smoothed == 0)
    #expect(mapper.value(for: audioMapperBeat(1), range: range, elapsed: 0) == range.lowerBound)
    #expect(mapper.value(for: audioMapperBeat(0), range: range, elapsed: 1) == range.lowerBound)
}

@Test func audioMapperSetMappingKeepsSmoothingState() throws {
    var mapper = AudioMapper(mapping: try #require(AudioMapping(feature: .beat, gain: 1)))
    _ = mapper.value(for: audioMapperBeat(0.5), range: 0...1, elapsed: 10)
    let held = mapper.smoothed
    let next = try #require(AudioMapping(feature: .level, gain: 3, attack: 0.5, release: 1))
    mapper.setMapping(next)
    #expect(mapper.mapping == next)
    #expect(mapper.smoothed == held)
}
