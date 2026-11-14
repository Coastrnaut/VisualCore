// BandLayoutTests — feature 048 (A06-P02) T-A06-202 (FR-A06-202, FR-A06-206; research D2, D3): band layouts at
// (48 kHz, 1,024), (44.1 kHz, 1,024), (48 kHz, 4,096) and (8 kHz, 256) are contiguous, increasing, non-empty and within
// 1…N/2−1; invalid input gives nil; powerSpectrum equals 10^(magnitudesDB/10) within 1e-4 relative above −100 dB.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

struct BandLayoutCase: Sendable, CustomStringConvertible {
    let sampleRate: Double
    let size: Int
    var description: String { "\(sampleRate) Hz, N = \(size)" }
}

let bandLayoutCases = [
    BandLayoutCase(sampleRate: 48_000, size: 1_024),
    BandLayoutCase(sampleRate: 44_100, size: 1_024),
    BandLayoutCase(sampleRate: 48_000, size: 4_096),
    BandLayoutCase(sampleRate: 8_000, size: 256),
]

private func checkBinRules(_ layout: BandLayout, bandCount: Int) {
    #expect(layout.bins.count == bandCount)
    #expect(layout.bandCount == bandCount)
    for (index, range) in layout.bins.enumerated() {
        #expect(!range.isEmpty)
        #expect(range.lowerBound >= 1)
        #expect(range.upperBound <= layout.size / 2)
        if index > 0 { #expect(range.lowerBound == layout.bins[index - 1].upperBound) }
    }
}

@Test(arguments: bandLayoutCases)
func defaultLayoutsObeyTheBinRules(_ c: BandLayoutCase) throws {
    let layout = try #require(BandLayout(sampleRate: c.sampleRate, size: c.size))
    checkBinRules(layout, bandCount: 16)
    #expect(layout.lowestFrequency == 40)
    #expect(layout.highestFrequency == min(16_000, c.sampleRate / 2))
    #expect(layout.sampleRate == c.sampleRate)
    #expect(layout.size == c.size)
}

@Test(arguments: [1, 8, 32, 64])
func otherBandCountsObeyTheBinRules(bandCount: Int) throws {
    let layout = try #require(BandLayout(bandCount: bandCount, sampleRate: 48_000, size: 4_096))
    checkBinRules(layout, bandCount: bandCount)
}

@Test func binCentresBeyondTheNarrowLowBandsFallInTheirBand() throws {
    // N = 4,096 at 48 kHz: bin width 11.7 Hz. A 1 kHz centre must be in the band whose edges hold 1 kHz.
    let layout = try #require(BandLayout(sampleRate: 48_000, size: 4_096))
    let ratio = layout.highestFrequency / layout.lowestFrequency
    let edges = (0...16).map { layout.lowestFrequency * pow(ratio, Double($0) / 16) }
    let bin = SpectrumAnalyzer.expectedBin(frequency: 1_000, sampleRate: 48_000, size: 4_096)
    let centre = Double(bin) * 48_000 / 4_096
    let band = try #require(layout.bins.firstIndex { $0.contains(bin) })
    #expect(edges[band] <= centre && centre < edges[band + 1])
}

@Test func invalidInputGivesNil() {
    #expect(BandLayout(bandCount: 0, sampleRate: 48_000, size: 1_024) == nil)
    #expect(BandLayout(bandCount: 65, sampleRate: 48_000, size: 1_024) == nil)
    #expect(BandLayout(sampleRate: 0, size: 1_024) == nil)
    #expect(BandLayout(sampleRate: -48_000, size: 1_024) == nil)
    #expect(BandLayout(sampleRate: .nan, size: 1_024) == nil)
    #expect(BandLayout(sampleRate: .infinity, size: 1_024) == nil)
    #expect(BandLayout(sampleRate: 48_000, size: 1_000) == nil)
    #expect(BandLayout(sampleRate: 48_000, size: 128) == nil)
    #expect(BandLayout(sampleRate: 48_000, size: 8_192) == nil)
    #expect(BandLayout(lowestFrequency: 0, sampleRate: 48_000, size: 1_024) == nil)
    #expect(BandLayout(lowestFrequency: -40, sampleRate: 48_000, size: 1_024) == nil)
    #expect(BandLayout(lowestFrequency: 16_000, sampleRate: 48_000, size: 1_024) == nil)
    #expect(BandLayout(lowestFrequency: 5_000, sampleRate: 8_000, size: 256) == nil)  // above fs/2 = 4 kHz
    // 64 bands from 3 kHz to 4 kHz at N = 256, fs = 8 kHz: only 32 usable bins remain.
    #expect(BandLayout(bandCount: 64, lowestFrequency: 3_000, sampleRate: 8_000, size: 256) == nil)
}

// MARK: - SpectrumAnalyzer.powerSpectrum(_:into:workspace:)

private func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 1_024, sampleRate: Double = 48_000) -> [Float] {
    (0..<count).map { amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / sampleRate)) }
}

private func power(_ analyzer: SpectrumAnalyzer, _ workspace: SpectrumWorkspace, _ frame: [Float]) -> [Float] {
    var result = [Float](repeating: -1, count: analyzer.size / 2)
    frame.withUnsafeBufferPointer { src in
        result.withUnsafeMutableBufferPointer { analyzer.powerSpectrum(src, into: $0, workspace: workspace) }
    }
    return result
}

@Test func powerSpectrumMatchesMagnitudesDB() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    let workspace = try #require(SpectrumWorkspace(size: 1_024))
    let frame = sine(1_000)
    let db = analyzer.magnitudesDB(frame)
    let p = power(analyzer, workspace, frame)
    #expect(p.count == 512)
    var compared = 0
    // Bins above −60 dB: below that, single-precision rounding of the two code paths differs by more than 1e-4 relative
    // (absolute differences stay under 1e-11 of full scale).
    for k in db.indices where db[k] > -60 {
        let expected = pow(10, db[k] / 10)
        #expect(abs(p[k] - expected) <= 1e-4 * expected, "bin \(k)")
        compared += 1
    }
    #expect(compared > 0)
    // A second call reuses the workspace and gives the same result.
    #expect(power(analyzer, workspace, frame) == p)
}

@Test func fullScaleBinCentredSineHasPowerAboutOne() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    let workspace = try #require(SpectrumWorkspace(size: 1_024))
    let p = power(analyzer, workspace, sine(1_500, amplitude: 1))  // bin 32 centre
    #expect(abs(p[32] - 1) < 0.15)
}

@Test func powerSpectrumPadsShortFramesAndZeroesNonFiniteSamples() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 256))
    let workspace = try #require(SpectrumWorkspace(size: 256))
    #expect(power(analyzer, workspace, []).allSatisfy { $0 == 0 })
    #expect(power(analyzer, workspace, [Float](repeating: .nan, count: 300)).allSatisfy { $0 == 0 })
    let short = sine(1_000, count: 100)
    let padded = short + [Float](repeating: 0, count: 156)
    #expect(power(analyzer, workspace, short) == power(analyzer, workspace, padded))
    let long = sine(1_000, count: 400)
    #expect(power(analyzer, workspace, long) == power(analyzer, workspace, Array(long.prefix(256))))
    var dirty = padded
    dirty[10] = .infinity
    var clean = padded
    clean[10] = 0
    #expect(power(analyzer, workspace, dirty) == power(analyzer, workspace, clean))
}

@Test func workspaceSizeRuleMatchesTheAnalyzer() {
    #expect(SpectrumWorkspace(size: 128) == nil)
    #expect(SpectrumWorkspace(size: 1_000) == nil)
    #expect(SpectrumWorkspace(size: 8_192) == nil)
    #expect(SpectrumWorkspace(size: 256)?.size == 256)
    #expect(SpectrumWorkspace(size: 4_096)?.size == 4_096)
}
