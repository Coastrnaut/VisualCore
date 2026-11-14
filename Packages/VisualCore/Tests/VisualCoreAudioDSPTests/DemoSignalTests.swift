// DemoSignalTests — feature 047 (A06-P01) T-A06-102 (FR-A06-102; SC-A06-103): determinism per seed and mode,
// chunk-independent continuation, tone and silence levels.
import Testing
@testable import VisualCoreAudioDSP

private func render(_ signal: inout DemoSignal, _ count: Int) -> [Float] {
    var out = [Float](repeating: .nan, count: count)
    out.withUnsafeMutableBufferPointer { signal.render(into: $0) }
    return out
}

private func render(seed: UInt64, mode: DemoSignal.Mode, count: Int) -> [Float] {
    var signal = DemoSignal(seed: seed, mode: mode)
    return render(&signal, count)
}

@Test(arguments: DemoSignal.Mode.allCases)
func sameSeedSameSamples(mode: DemoSignal.Mode) {
    #expect(render(seed: 7, mode: mode, count: 48_000) == render(seed: 7, mode: mode, count: 48_000))
}

@Test func differentSeedsDiffer() {
    #expect(render(seed: 1, mode: .sequence, count: 4_800) != render(seed: 2, mode: .sequence, count: 4_800))
}

@Test(arguments: DemoSignal.Mode.allCases)
func chunkedRenderingContinuesExactly(mode: DemoSignal.Mode) {
    let whole = render(seed: 42, mode: mode, count: 30_000)
    var signal = DemoSignal(seed: 42, mode: mode)
    var chunked: [Float] = []
    for size in [1, 511, 4_096, 24_000, 1_392] { chunked += render(&signal, size) }
    #expect(chunked == whole)
}

@Test func tone440PeaksAtBin9() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    let db = analyzer.magnitudesDB(render(seed: 0, mode: .tone440, count: 1_024))
    #expect(SpectrumAnalyzer.peakBin(db) == 9)
}

@Test func tone1kPeaksAtBin21() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 1_024))
    let db = analyzer.magnitudesDB(render(seed: 0, mode: .tone1k, count: 1_024))
    #expect(SpectrumAnalyzer.peakBin(db) == 21)
}

@Test func levelsMatchTheModes() {
    #expect(render(seed: 3, mode: .silence, count: 2_048).allSatisfy { $0 == 0 })
    let tone = render(seed: 3, mode: .tone440, count: 48_000)
    #expect(abs((tone.map(abs).max() ?? 0) - 0.5) < 0.001)
    let sequence = render(seed: 3, mode: .sequence, count: 48_000)
    let peak = sequence.map(abs).max() ?? 0
    #expect(peak > 0.2 && peak <= DemoSignal.sequenceAmplitude + DemoSignal.noiseAmplitude + 1e-6)
}

@Test func sequencePlaysPentatonicNotesEveryHalfSecond() throws {
    let analyzer = try #require(SpectrumAnalyzer(size: 4_096))
    var signal = DemoSignal(seed: 11, mode: .sequence)
    let samples = render(&signal, 48_000 * 2)
    let allowed = Set(DemoSignal.pentatonic.map { SpectrumAnalyzer.expectedBin(frequency: $0, sampleRate: 48_000, size: 4_096) })
    for note in 0..<4 {
        let start = note * 24_000 + 8_000   // inside the note, away from the boundary
        let db = analyzer.magnitudesDB(Array(samples[start..<(start + 4_096)]))
        let peak = try #require(SpectrumAnalyzer.peakBin(db))
        #expect(allowed.contains { abs($0 - peak) <= 1 })
    }
}
