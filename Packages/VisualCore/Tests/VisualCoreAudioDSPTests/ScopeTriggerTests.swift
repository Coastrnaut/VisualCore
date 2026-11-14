// ScopeTriggerTests — feature 061 (A08-P01) T-A08-102 (FR-A08-103, FR-A08-104; SC-A08-103, SC-A08-104; gap
// G-TRIGGER): over 100 windows of a 1 kHz sine plus seeded −40 dBFS noise every rising trigger is within one sample of
// the true upward zero crossing; the falling slope finds downward crossings; a flat line and an unreachable level give
// nil; a NaN level is refused; `TimebaseWindow` sample counts at 44.1, 48 and 96 kHz and the 4,096 cap.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

/// Tiny deterministic linear congruential generator (Numerical Recipes constants) for the noise.
private struct LCG {
    var state: UInt32
    mutating func nextUnit() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Float(state >> 8) / Float(1 << 24) * 2 - 1   // −1 ..< 1
    }
}

private func noisySine(count: Int, frequency: Double, sampleRate: Double, amplitude: Double, phase: Double,
                       noise: Float, rng: inout LCG) -> [Float] {
    (0..<count).map { i in
        Float(amplitude * sin(2 * .pi * frequency * Double(i) / sampleRate + phase)) + noise * rng.nextUnit()
    }
}

@Test func scopeTriggerRisingWithinOneSampleOverNoisyWindows() throws {
    let sr = 48_000.0, f = 1_000.0
    let settings = try #require(TriggerSettings(level: 0, slope: .rising))
    var rng = LCG(state: 0x0A08_0102)
    for window in 0..<100 {
        let phase = Double(window) * 0.37
        let samples = noisySine(count: 960, frequency: f, sampleRate: sr, amplitude: 0.5, phase: phase, noise: 0.01,
                                rng: &rng)
        let found = try #require(ScopeTrigger.find(in: samples, settings: settings, searchRange: 0..<480),
                                 "window \(window)")
        // True upward zero crossings: 2π f t + phase = 2π k.
        let period = sr / f
        let first = (1 - (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1)) * period
        let candidates = (0..<20).map { first + Double($0) * period - period }
        let nearest = candidates.min { abs($0 - Double(found)) < abs($1 - Double(found)) }!
        // The noiseless trigger fires on the first sample at or after the true crossing (ceil); noise may move it by
        // at most one sample either way.
        let ideal = nearest.rounded(.up)
        #expect(abs(Double(found) - ideal) <= 1.0, "window \(window): \(found) vs \(nearest)")
        #expect(found < 480 && found >= 430)   // the most recent crossing in the range (period 48 samples)
    }
}

@Test func scopeTriggerFallingSlope() throws {
    let sr = 48_000.0
    let settings = try #require(TriggerSettings(level: 0, slope: .falling))
    let samples = (0..<960).map { Float(0.5 * sin(2 * .pi * 1_000 * Double($0) / sr)) }
    let found = try #require(ScopeTrigger.find(in: samples, settings: settings, searchRange: 0..<480))
    // Downward zero crossings at 24 + 48k; the last one below 480 is 456.
    #expect(abs(found - 456) <= 1)
    #expect(samples[found] <= 0 && samples[found - 1] > 0)
}

@Test func scopeTriggerFlatLineIsNil() throws {
    let settings = try #require(TriggerSettings(level: 0))
    let flat = [Float](repeating: 0.2, count: 1_000)
    #expect(ScopeTrigger.find(in: flat, settings: settings, searchRange: 0..<1_000) == nil)
    let zero = [Float](repeating: 0, count: 1_000)
    #expect(ScopeTrigger.find(in: zero, settings: settings, searchRange: 0..<1_000) == nil)
}

@Test func scopeTriggerUnreachableLevelIsNil() throws {
    let settings = try #require(TriggerSettings(level: 0.9))
    let samples = (0..<960).map { Float(0.5 * sin(2 * .pi * 1_000 * Double($0) / 48_000)) }
    #expect(ScopeTrigger.find(in: samples, settings: settings, searchRange: 0..<960) == nil)
}

@Test func scopeTriggerHysteresisRejectsNoiseNearLevel() throws {
    let settings = try #require(TriggerSettings(level: 0, hysteresis: 0.02))
    // Dithering ±0.01 around the level never arms the trigger.
    let samples = (0..<500).map { Float($0 % 2 == 0 ? 0.01 : -0.01) }
    #expect(ScopeTrigger.find(in: samples, settings: settings, searchRange: 0..<500) == nil)
}

@Test func scopeTriggerEmptyOrOutOfBoundsRange() throws {
    let settings = try #require(TriggerSettings(level: 0))
    let samples = (0..<96).map { Float(0.5 * sin(2 * .pi * 1_000 * Double($0) / 48_000)) }
    #expect(ScopeTrigger.find(in: samples, settings: settings, searchRange: 10..<10) == nil)
    #expect(ScopeTrigger.find(in: samples, settings: settings, searchRange: 500..<600) == nil)
    #expect(ScopeTrigger.find(in: [], settings: settings, searchRange: 0..<10) == nil)
    // A range past the end is clipped to the samples.
    let clipped = try #require(ScopeTrigger.find(in: samples, settings: settings, searchRange: 0..<1_000))
    #expect(abs(clipped - 48) <= 1)
}

@Test func triggerSettingsValidation() throws {
    #expect(TriggerSettings(level: .nan) == nil)
    #expect(TriggerSettings(level: .infinity) == nil)
    let s = try #require(TriggerSettings(channel: 7, level: 3, slope: .falling, hysteresis: 2, mode: .normal))
    #expect(s.channel == 1)
    #expect(s.level == 1)
    #expect(s.hysteresis == 0.5)
    #expect(s.slope == .falling && s.mode == .normal)
    let d = try #require(TriggerSettings())
    #expect(d.channel == 0 && d.level == 0 && d.hysteresis == 0.02 && d.slope == .rising && d.mode == .auto)
    let n = try #require(TriggerSettings(level: -5, hysteresis: .nan))
    #expect(n.level == -1 && n.hysteresis == 0.02)
}

@Test func timebaseWindowSampleCounts() {
    #expect(TimebaseWindow.maxSamples == 4_096)
    let oneMs = TimebaseWindow(secondsPerDivision: 0.001)
    #expect(oneMs.divisions == 10)
    #expect(oneMs.sampleCount(sampleRate: 48_000) == 480)
    #expect(oneMs.sampleCount(sampleRate: 44_100) == 441)
    #expect(oneMs.sampleCount(sampleRate: 96_000) == 960)
    #expect(!oneMs.isShortened(sampleRate: 96_000))
    let tenth = TimebaseWindow(secondsPerDivision: 0.000_1)
    #expect(tenth.sampleCount(sampleRate: 44_100) == 44)   // round(44.1)
    #expect(tenth.sampleCount(sampleRate: 48_000) == 48)
    let fiveMs = TimebaseWindow(secondsPerDivision: 0.005)
    #expect(fiveMs.sampleCount(sampleRate: 44_100) == 2_205)
    #expect(fiveMs.sampleCount(sampleRate: 48_000) == 2_400)
    #expect(!fiveMs.isShortened(sampleRate: 48_000))
    #expect(fiveMs.sampleCount(sampleRate: 96_000) == 4_096)
    #expect(fiveMs.isShortened(sampleRate: 96_000))
    #expect(TimebaseWindow(secondsPerDivision: 0).sampleCount(sampleRate: 48_000) == 1)
    #expect(TimebaseWindow(secondsPerDivision: .nan).sampleCount(sampleRate: 48_000) == 1)
}
