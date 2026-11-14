// TestSignalTests — feature 061 (A08-P01) T-A08-102 (FR-A08-101, FR-A08-104; SC-A08-101; gap G-DEMOWAVES): sine,
// square and sweep renders equal `value(atFrame:channel:)` and the closed form within 1e-6; the square takes only
// ±amplitude with one sign change per half period; a 100 Hz → 10 kHz / 2 s sweep runs at 1 kHz after 1 s within 1 %;
// two channels keep their own frequencies; chunked rendering equals rendering at once; clamping and NaN defaults.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private func signChanges(_ samples: [Float]) -> Int {
    var count = 0
    for i in 1..<samples.count where (samples[i] >= 0) != (samples[i - 1] >= 0) { count += 1 }
    return count
}

@Test(arguments: TestSignal.Waveform.allCases)
func testSignalRenderMatchesClosedForm(waveform: TestSignal.Waveform) {
    var signal = TestSignal(waveform: waveform, frequency: 440, amplitude: 0.7, sampleRate: 48_000,
                            channelCount: 2, rightRatio: 1.5, rightPhase: 0.3)
    let reference = signal
    var left: [Float] = []
    var right: [Float] = []
    signal.render(frames: 4_800, left: &left, right: &right)
    #expect(left.count == 4_800 && right.count == 4_800)
    let a = 0.7, sr = 48_000.0
    for frame in stride(from: 0, to: 4_800, by: 7) {
        #expect(abs(left[frame] - reference.value(atFrame: frame, channel: 0)) <= 1e-6)
        #expect(abs(right[frame] - reference.value(atFrame: frame, channel: 1)) <= 1e-6)
        let t = Double(frame) / sr
        let expectedLeft: Double
        let expectedRight: Double
        switch waveform {
        case .sine:
            expectedLeft = a * sin(2 * .pi * 440 * t)
            expectedRight = a * sin(2 * .pi * 660 * t + 0.3)
        case .square:
            // Skip samples whose phase sits within rounding distance of a sign change.
            let p0 = (440 * t).truncatingRemainder(dividingBy: 0.5)
            let p1 = (660 * t + 0.3 / (2 * .pi)).truncatingRemainder(dividingBy: 0.5)
            if min(p0, 0.5 - p0) < 1e-6 || min(p1, 0.5 - p1) < 1e-6 { continue }
            expectedLeft = sin(2 * .pi * 440 * t) >= 0 ? a : -a
            expectedRight = sin(2 * .pi * 660 * t + 0.3) >= 0 ? a : -a
        case .sweep:
            let f0 = 440.0, f1 = 10_000.0, T = 2.0
            let k = log(f1 / f0)
            expectedLeft = a * sin(2 * .pi * f0 * T / k * (pow(f1 / f0, t / T) - 1))
            expectedRight = a * sin(2 * .pi * 1.5 * f0 * T / k * (pow(f1 / f0, t / T) - 1) + 0.3)
        }
        #expect(abs(Double(left[frame]) - expectedLeft) <= 1e-6, "frame \(frame)")
        #expect(abs(Double(right[frame]) - expectedRight) <= 1e-6, "frame \(frame)")
    }
}

@Test func testSignalSquareTakesOnlyAmplitudeAndFlipsPerHalfPeriod() {
    var signal = TestSignal(waveform: .square, frequency: 1_000, amplitude: 0.4, sampleRate: 48_000)
    var left: [Float] = []
    var right: [Float] = []
    signal.render(frames: 4_800, left: &left, right: &right)
    #expect(right.isEmpty)
    #expect(left.allSatisfy { $0 == 0.4 || $0 == -0.4 })
    // 0.1 s of 1 kHz: 100 periods, 200 half periods, so 199 or 200 sign changes after the first sample.
    let changes = signChanges(left)
    #expect(changes >= 199 && changes <= 200)
    // No two sign changes closer than half a period less one sample (24 − 1 samples at 48 kHz).
    var last = -100
    for i in 1..<left.count where (left[i] >= 0) != (left[i - 1] >= 0) {
        #expect(i - last >= 23)
        last = i
    }
}

@Test func testSignalSweepInstantaneousFrequencyAtOneSecond() {
    let sr = 48_000.0
    let signal = TestSignal(waveform: .sweep, frequency: 100, amplitude: 1, sampleRate: sr,
                            sweepEnd: 10_000, sweepDuration: 2)
    // Count zero crossings in ±5 ms around t = 1 s; f(1 s) = 100 · 100^0.5 = 1,000 Hz.
    let center = Int(sr)
    let half = 240
    var crossings: [Double] = []
    var previous = signal.value(atFrame: center - half, channel: 0)
    for frame in (center - half + 1)...(center + half) {
        let v = signal.value(atFrame: frame, channel: 0)
        if (v >= 0) != (previous >= 0) {
            crossings.append(Double(frame - 1) + Double(previous / (previous - v)))
        }
        previous = v
    }
    #expect(crossings.count >= 8)
    let spacing = (crossings.last! - crossings.first!) / Double(crossings.count - 1)
    let frequency = sr / (2 * spacing)
    #expect(abs(frequency - 1_000) / 1_000 < 0.01, "measured \(frequency)")
}

@Test func testSignalSweepLoopsEveryDuration() {
    let signal = TestSignal(waveform: .sweep, frequency: 100, sampleRate: 48_000, sweepEnd: 10_000, sweepDuration: 2)
    for frame in [0, 1, 17, 500, 12_345] {
        #expect(abs(signal.value(atFrame: frame, channel: 0) - signal.value(atFrame: frame + 96_000, channel: 0)) <= 1e-6)
    }
}

@Test func testSignalChannelsKeepOwnFrequencies() {
    var signal = TestSignal(waveform: .sine, frequency: 500, sampleRate: 48_000, channelCount: 2, rightRatio: 2)
    var left: [Float] = []
    var right: [Float] = []
    signal.render(frames: 9_600, left: &left, right: &right)
    let l = signChanges(left)
    let r = signChanges(right)
    #expect(abs(l - 200) <= 1)
    #expect(abs(r - 400) <= 1)
}

@Test(arguments: TestSignal.Waveform.allCases)
func testSignalChunkedRenderEqualsSingleRender(waveform: TestSignal.Waveform) {
    let base = TestSignal(waveform: waveform, frequency: 440, amplitude: 0.5, sampleRate: 44_100,
                          channelCount: 2, rightRatio: 1.25, rightPhase: 1)
    var whole = base
    var wl: [Float] = []
    var wr: [Float] = []
    whole.render(frames: 2_100, left: &wl, right: &wr)
    var chunked = base
    var cl: [Float] = []
    var cr: [Float] = []
    var l: [Float] = []
    var r: [Float] = []
    for _ in 0..<7 {
        chunked.render(frames: 300, left: &l, right: &r)
        #expect(l.count == 300 && r.count == 300)
        cl += l
        cr += r
    }
    #expect(cl == wl)
    #expect(cr == wr)
    #expect(chunked == whole)
}

@Test func testSignalClampsAndDefaults() {
    let low = TestSignal(waveform: .sine, frequency: 1, amplitude: -3, channelCount: 0, rightRatio: 0, sweepDuration: -1)
    #expect(low.frequency == 20)
    #expect(low.amplitude == 0)
    #expect(low.channelCount == 1)
    #expect(low.rightRatio == 0.01)
    #expect(low.sweepDuration > 0)
    let high = TestSignal(waveform: .sine, frequency: 99_000, amplitude: 9, channelCount: 5, rightRatio: 1_000,
                          sweepEnd: 1e9)
    #expect(high.frequency == 20_000)
    #expect(high.amplitude == 1)
    #expect(high.channelCount == 2)
    #expect(high.rightRatio == 100)
    #expect(high.sweepEnd == 20_000)
    let nan = TestSignal(waveform: .sweep, frequency: .nan, amplitude: .nan, sampleRate: .nan, rightRatio: .nan,
                         rightPhase: .nan, sweepEnd: .nan, sweepDuration: .nan)
    let defaults = TestSignal(waveform: .sweep, frequency: 1_000)
    #expect(nan.amplitude == defaults.amplitude)
    #expect(nan.sampleRate == 48_000)
    #expect(nan.rightRatio == 1)
    #expect(nan.rightPhase == 0)
    #expect(nan.sweepEnd == 10_000)
    #expect(nan.sweepDuration == 2)
    #expect(nan.frequency == defaults.frequency)
    #expect(nan.value(atFrame: 123, channel: 0).isFinite)
}

@Test func testSignalPeriods() {
    #expect(abs(TestSignal.periods(frequency: 1_000, sampleCount: 480, sampleRate: 48_000) - 10) < 1e-12)
    #expect(abs(TestSignal.periods(frequency: 440, sampleCount: 2_400, sampleRate: 48_000) - 22) < 1e-12)
    #expect(TestSignal.periods(frequency: 440, sampleCount: 100, sampleRate: 0) == 0)
}

@Test func testSignalStaysExactAtLargeFrames() {
    let signal = TestSignal(waveform: .sine, frequency: 1_000, amplitude: 1, sampleRate: 48_000)
    // 1,000 Hz at 48 kHz repeats every 48 frames exactly.
    let far = 48 * 1_000_000_000
    for offset in [0, 5, 13, 31] {
        #expect(abs(signal.value(atFrame: far + offset, channel: 0) - signal.value(atFrame: offset, channel: 0)) <= 1e-6)
    }
}
