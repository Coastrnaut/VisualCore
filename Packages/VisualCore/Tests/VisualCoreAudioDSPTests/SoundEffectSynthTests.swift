// SoundEffectSynthTests — feature 077 (A10-P03) T-A10-302 (FR-A10-301, FR-A10-302; SC-A10-302; research D1): the
// synthesised sound effects are deterministic, have duration × rate samples, stay finite and within ±gain, start and
// end in silence, follow the exponential frequency sweep for every waveform, add seeded noise deterministically, and
// render nothing for an invalid effect.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private let rate = SoundEffectSynth.defaultSampleRate

private func sweep(_ waveform: SoundWaveform, noise: Double = 0) -> SoundEffect {
    SoundEffect(waveform: waveform, startFrequency: 200, endFrequency: 2_000, duration: 0.5, attack: 0.05,
                release: 0.05, noise: noise, gain: 0.6)
}

/// Counts sign changes between consecutive non-zero samples of `samples[range]`.
private func zeroCrossings(_ samples: [Float], _ range: Range<Int>) -> Int {
    var count = 0
    var previous: Float = 0
    for sample in samples[range] where sample != 0 {
        if previous != 0, (sample > 0) != (previous > 0) { count += 1 }
        previous = sample
    }
    return count
}

/// Cycles of the exponential sweep `start → end` over `duration` between times `t0` and `t1` (seconds).
private func expectedCycles(_ effect: SoundEffect, from t0: Double, to t1: Double) -> Double {
    let ratio = effect.endFrequency / effect.startFrequency
    let scale = effect.startFrequency * effect.duration / log(ratio)
    return scale * (pow(ratio, t1 / effect.duration) - pow(ratio, t0 / effect.duration))
}

@Test(arguments: SoundWaveform.allCases)
func renderingIsIdenticalTwice(waveform: SoundWaveform) {
    let effect = sweep(waveform, noise: 0.3)
    #expect(SoundEffectSynth.render(effect) == SoundEffectSynth.render(effect))
}

@Test(arguments: [0.02, 0.1, 0.37, 1.0])
func sampleCountIsDurationTimesRate(duration: Double) {
    let effect = SoundEffect(waveform: .square, startFrequency: 440, endFrequency: 440, duration: duration)
    #expect(SoundEffectSynth.render(effect).count == Int((duration * rate).rounded()))
    #expect(SoundEffectSynth.render(effect, sampleRate: 22_050).count == Int((duration * 22_050).rounded()))
}

@Test(arguments: SoundWaveform.allCases)
func samplesAreFiniteAndWithinGain(waveform: SoundWaveform) {
    for noise in [0.0, 0.5, 1.0] {
        for gain in [0.0, 0.3, 0.9] {
            let effect = SoundEffect(waveform: waveform, startFrequency: 40, endFrequency: 4_000, duration: 0.2,
                                     attack: 0.002, release: 0.002, noise: noise, gain: gain)
            let samples = SoundEffectSynth.render(effect)
            #expect(!samples.isEmpty)
            #expect(samples.allSatisfy { $0.isFinite && abs($0) <= Float(gain) })
        }
    }
}

@Test(arguments: SoundWaveform.allCases)
func firstAndLastTwoMillisecondsAreNearSilence(waveform: SoundWaveform) {
    let effect = sweep(waveform, noise: 0.5)
    let samples = SoundEffectSynth.render(effect)
    let edge = Int(0.002 * rate)
    let limit = Float(0.05 * effect.gain)
    #expect(samples.first == 0)
    #expect(samples.last == 0)
    #expect(samples.prefix(edge).allSatisfy { abs($0) <= limit })
    #expect(samples.suffix(edge).allSatisfy { abs($0) <= limit })
    // Shortest fades: the envelope still starts and ends at exactly zero.
    let short = SoundEffect(waveform: waveform, startFrequency: 300, endFrequency: 300, duration: 0.05,
                            attack: 0.002, release: 0.002, gain: 0.9)
    let shortSamples = SoundEffectSynth.render(short)
    #expect(shortSamples.first == 0)
    #expect(shortSamples.last == 0)
}

@Test(arguments: SoundWaveform.allCases)
func zeroCrossingsFollowTheSweep(waveform: SoundWaveform) {
    for effect in [sweep(waveform),
                   SoundEffect(waveform: waveform, startFrequency: 3_000, endFrequency: 300, duration: 0.4,
                               attack: 0.01, release: 0.01, gain: 0.5)] {
        let samples = SoundEffectSynth.render(effect)
        let quarters = 4
        let length = samples.count / quarters
        for quarter in 0..<quarters {
            let range = (quarter * length)..<((quarter + 1) * length)
            let expected = 2 * expectedCycles(effect, from: Double(range.lowerBound) / rate,
                                              to: Double(range.upperBound) / rate)
            let measured = Double(zeroCrossings(samples, range))
            #expect(abs(measured - expected) <= 0.05 * expected,
                    "\(waveform) quarter \(quarter): \(measured) crossings, expected \(expected)")
        }
    }
}

@Test func noiseChangesTheBufferDeterministically() {
    let clean = SoundEffectSynth.render(sweep(.sine))
    let noisy = SoundEffectSynth.render(sweep(.sine, noise: 0.5))
    #expect(noisy != clean)
    #expect(noisy == SoundEffectSynth.render(sweep(.sine, noise: 0.5)))
    // The noise is seeded by the effect: another effect gets another noise sequence.
    let pureNoise = SoundEffect(waveform: .sine, startFrequency: 200, endFrequency: 2_000, duration: 0.5,
                                attack: 0.05, release: 0.05, noise: 1, gain: 0.6)
    let otherNoise = SoundEffect(waveform: .sine, startFrequency: 201, endFrequency: 2_000, duration: 0.5,
                                 attack: 0.05, release: 0.05, noise: 1, gain: 0.6)
    #expect(SoundEffectSynth.render(pureNoise) != SoundEffectSynth.render(otherNoise))
    #expect(SoundEffectSynth.noiseSeed(pureNoise) == SoundEffectSynth.noiseSeed(pureNoise))
    #expect(SoundEffectSynth.noiseSeed(pureNoise) != SoundEffectSynth.noiseSeed(otherNoise))
}

@Test func invalidEffectsRenderAnEmptyBuffer() {
    let valid = sweep(.triangle)
    #expect(valid.isValid)
    var invalid: [SoundEffect] = []
    for frequency in [39.9, 4_000.1, .nan, .infinity] {
        var start = valid
        start.startFrequency = frequency
        var end = valid
        end.endFrequency = frequency
        invalid += [start, end]
    }
    for duration in [0.019, 1.01, .nan] {
        var effect = valid
        effect.duration = duration
        invalid.append(effect)
    }
    for fade in [0.0019, -1, .nan] {
        var attack = valid
        attack.attack = fade
        var release = valid
        release.release = fade
        invalid += [attack, release]
    }
    for noise in [-0.01, 1.01, .nan] {
        var effect = valid
        effect.noise = noise
        invalid.append(effect)
    }
    for gain in [-0.01, 0.91, .nan] {
        var effect = valid
        effect.gain = gain
        invalid.append(effect)
    }
    for effect in invalid {
        #expect(!effect.isValid)
        #expect(SoundEffectSynth.render(effect).isEmpty)
    }
    for sampleRate in [0.0, -48_000, .nan, .infinity] {
        #expect(SoundEffectSynth.render(valid, sampleRate: sampleRate).isEmpty)
    }
}

@Test func effectsRoundTripThroughCodable() throws {
    let effect = sweep(.square, noise: 0.25)
    let decoded = try JSONDecoder().decode(SoundEffect.self, from: JSONEncoder().encode(effect))
    #expect(decoded == effect)
    #expect(SoundWaveform(rawValue: "triangle") == .triangle)
}
