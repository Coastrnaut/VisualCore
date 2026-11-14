// LevelMeterTests — feature 048 (A06-P02) T-A06-202 (FR-A06-201, FR-A06-206; SC-A06-201): RMS and peak of sine
// (A/√2, A), square (A, A) and silence (0) within 1e-6 relative; non-finite samples count as 0; dBFS floor −120.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private func rms(_ samples: [Float]) -> Float { samples.withUnsafeBufferPointer { LevelMeter.rms($0) } }
private func peak(_ samples: [Float]) -> Float { samples.withUnsafeBufferPointer { LevelMeter.peak($0) } }

private func relativeError(_ value: Float, _ expected: Float) -> Float { abs(value - expected) / abs(expected) }

/// 1 kHz at 48 kHz: 48 samples per period, 20 whole periods; sample 12 is the crest.
private func sine(amplitude: Float) -> [Float] {
    (0..<960).map { amplitude * Float(sin(2 * Double.pi * 1_000 * Double($0) / 48_000)) }
}

private func square(amplitude: Float) -> [Float] {
    (0..<960).map { ($0 / 24) % 2 == 0 ? amplitude : -amplitude }
}

@Test(arguments: [Float(1), 0.5, 0.01])
func sineRMSAndPeak(amplitude: Float) {
    let samples = sine(amplitude: amplitude)
    #expect(relativeError(rms(samples), amplitude / Float(2).squareRoot()) <= 1e-6)
    #expect(relativeError(peak(samples), amplitude) <= 1e-6)
}

@Test(arguments: [Float(1), 0.25])
func squareRMSAndPeak(amplitude: Float) {
    let samples = square(amplitude: amplitude)
    #expect(relativeError(rms(samples), amplitude) <= 1e-6)
    #expect(relativeError(peak(samples), amplitude) <= 1e-6)
}

@Test func silenceAndEmptyMeasureExactlyZero() {
    let silence = [Float](repeating: 0, count: 1_024)
    #expect(rms(silence) == 0)
    #expect(peak(silence) == 0)
    #expect(rms([]) == 0)
    #expect(peak([]) == 0)
}

@Test func nonFiniteSamplesCountAsZero() {
    let samples: [Float] = [0.5, .nan, -0.5, .infinity, 0.5, -.infinity, -0.5, .nan]
    // Four finite samples of magnitude 0.5 over eight: √(4 · 0.25 / 8).
    #expect(relativeError(rms(samples), (1 / Float(8)).squareRoot()) <= 1e-6)
    #expect(peak(samples) == 0.5)
    #expect(rms([.nan, .infinity]) == 0)
    #expect(peak([.nan, -.infinity]) == 0)
}

@Test func dBFSIsFlooredAtMinus120() {
    #expect(LevelMeter.floorDB == -120)
    #expect(LevelMeter.dBFS(1) == 0)
    #expect(abs(LevelMeter.dBFS(0.5) - -6.0206) < 1e-3)
    #expect(abs(LevelMeter.dBFS(0.1) - -20) < 1e-4)
    #expect(LevelMeter.dBFS(0) == -120)
    #expect(LevelMeter.dBFS(-0.5) == -120)
    #expect(LevelMeter.dBFS(1e-9) == -120)
    #expect(LevelMeter.dBFS(.nan) == -120)
    #expect(LevelMeter.dBFS(.infinity) == -120)
}
