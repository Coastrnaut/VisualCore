// SpectrumAnalyzerTests — feature 047 (A06-P01) T-A06-102 (FR-A06-110, 111; SC-A06-101): sine peaks at 48 kHz,
// N = 1,024 within one bin and at least 20 dB above every bin more than two bins away; silence has no peak.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 1_024, sampleRate: Double = 48_000) -> [Float] {
    (0..<count).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

@Test(arguments: [440.0, 1_000.0, 5_000.0])
func sinePeaksAtTheExpectedBin(frequency: Double) throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    let db = analyzer.magnitudesDB(sine(frequency))
    #expect(db.count == 512)
    let peak = try #require(SpectrumAnalyzer.peakBin(db))
    let expected = SpectrumAnalyzer.expectedBin(frequency: frequency, sampleRate: 48_000, size: 1_024)
    #expect(abs(peak - expected) <= 1)
    let others = db.indices.filter { abs($0 - peak) > 2 }.map { db[$0] }
    let maxOther = try #require(others.max())
    #expect(db[peak] - maxOther >= 20)
}

@Test func fullScaleBinCentredSineReadsAboutZeroDB() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    // Bin 32 centre: 32 · 48,000 / 1,024 = 1,500 Hz.
    let db = analyzer.magnitudesDB(sine(1_500, amplitude: 1))
    #expect(SpectrumAnalyzer.peakBin(db) == 32)
    #expect(abs(db[32]) < 0.5)
}

@Test func silenceHasNoPeak() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    #expect(SpectrumAnalyzer.peakBin(analyzer.magnitudesDB([Float](repeating: 0, count: 1_024))) == nil)
    #expect(SpectrumAnalyzer.peakBin(analyzer.magnitudesDB([])) == nil)
}

@Test func sizeMustBeAPowerOfTwoIn256To4096() {
    #expect(SpectrumAnalyzer(size: 100) == nil)
    #expect(SpectrumAnalyzer(size: 8_192) == nil)
    #expect(SpectrumAnalyzer(size: 128) == nil)
    #expect(SpectrumAnalyzer(size: 1_000) == nil)
    #expect(SpectrumAnalyzer(size: 256)?.size == 256)
    #expect(SpectrumAnalyzer(size: 4_096)?.size == 4_096)
}

@Test func expectedBinRounds() {
    #expect(SpectrumAnalyzer.expectedBin(frequency: 440, sampleRate: 48_000, size: 1_024) == 9)
    #expect(SpectrumAnalyzer.expectedBin(frequency: 1_000, sampleRate: 48_000, size: 1_024) == 21)
    #expect(SpectrumAnalyzer.expectedBin(frequency: 5_000, sampleRate: 48_000, size: 1_024) == 107)
}
