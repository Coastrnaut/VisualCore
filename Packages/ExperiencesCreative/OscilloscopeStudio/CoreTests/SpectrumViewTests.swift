// SpectrumViewTests — feature 063 (A08-P03) T-A08-302 (FR-A08-301, FR-A08-302, FR-A08-303; SC-A08-303;
// clarifications 4 and 5). The spectrum geometry, host-free and short: the log axis from 20 Hz to Nyquist, at most one
// point per pixel column keeping the strongest bin, the highest point at the strongest level, levels below −100 dBFS on
// the low edge, and the decade marks at the expected x for 48 kHz, 44.1 kHz and 16 kHz.
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct SpectrumViewTests {
    private let rect = (x: 10.0, y: 20.0, width: 400.0, height: 200.0)

    private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }

    /// 2,048 magnitudes at `floor` dBFS with the given bins set.
    private func magnitudes(floor: Float = -150, _ set: [Int: Float] = [:]) -> [Float] {
        var m = [Float](repeating: floor, count: 2_048)
        for (bin, level) in set { m[bin] = level }
        return m
    }

    @Test func theAxisIsLogarithmicFromTwentyHertzToNyquist() throws {
        #expect(SpectrumView.x(frequency: 20, sampleRate: 48_000, width: 400) == 0)
        #expect(near(try #require(SpectrumView.x(frequency: 24_000, sampleRate: 48_000, width: 400)), 400))
        #expect(SpectrumView.x(frequency: 19.9, sampleRate: 48_000, width: 400) == nil)
        #expect(SpectrumView.x(frequency: 24_001, sampleRate: 48_000, width: 400) == nil)
        #expect(SpectrumView.x(frequency: .nan, sampleRate: 48_000, width: 400) == nil)
        #expect(SpectrumView.x(frequency: 20, sampleRate: 40, width: 400) == nil)
        let x1k = try #require(SpectrumView.x(frequency: 1_000, sampleRate: 48_000, width: 400))
        #expect(near(x1k, log10(50) / log10(1_200) * 400))
        #expect(SpectrumView.minimumFrequency == 20 && SpectrumView.floorDB == -100)
        #expect(SpectrumView.levelMarks == [0, -20, -40, -60, -80, -100])
    }

    @Test func columnsAreAtMostOnePerPixelColumnAndSorted() {
        for width in [50, 300, 1_000] {
            let columns = SpectrumView.columns(magnitudesDB: magnitudes(), sampleRate: 48_000, size: 4_096,
                                               width: width)
            #expect(!columns.isEmpty && columns.count <= width)
            #expect(Set(columns.map(\.column)).count == columns.count)
            #expect(columns.map(\.column) == columns.map(\.column).sorted())
            #expect(columns.allSatisfy { (0..<width).contains($0.column) })
            let points = SpectrumView.points(columns, in: rect, columnCount: width)
            #expect(points.count == columns.count && points.count <= 2 * width)
        }
    }

    @Test func eachColumnKeepsItsStrongestBin() throws {
        // Bins 2,000 and 2,001 (about 23.4 kHz at 48 kHz) share one column of a 100-column axis.
        let rate = 48_000.0
        let width = 100
        let colA = Int(try #require(SpectrumView.x(frequency: 2_000 * rate / 4_096, sampleRate: rate, width: 100)))
        let colB = Int(try #require(SpectrumView.x(frequency: 2_001 * rate / 4_096, sampleRate: rate, width: 100)))
        #expect(colA == colB)
        let columns = SpectrumView.columns(magnitudesDB: magnitudes([2_000: -30, 2_001: -10]), sampleRate: rate,
                                           size: 4_096, width: width)
        let entry = try #require(columns.first { $0.column == colA })
        #expect(entry.levelDB == -10)
        let swapped = SpectrumView.columns(magnitudesDB: magnitudes([2_000: -10, 2_001: -30]), sampleRate: rate,
                                           size: 4_096, width: width)
        #expect(swapped.first { $0.column == colA }?.levelDB == -10)
    }

    @Test func theHighestPointIsTheStrongestLevel() throws {
        let strongest: Float = -12
        let m = magnitudes(floor: -90, [85: strongest, 300: -40, 1_500: -60])
        let columns = SpectrumView.columns(magnitudesDB: m, sampleRate: 48_000, size: 4_096, width: 320)
        let points = SpectrumView.points(columns, in: rect, columnCount: 320)
        let top = try #require(points.map(\.y).max())
        #expect(near(top, rect.y + (Double(strongest) + 100) / 100 * rect.height))
        // 0 dBFS maps to the high edge (y-up) and the column centre is used for x.
        let full = SpectrumView.points([(column: 0, levelDB: 0)], in: rect, columnCount: 320)
        #expect(full == [TracePoint(x: rect.x + 0.5 / 320 * rect.width, y: rect.y + rect.height)])
        #expect(SpectrumView.points(columns, in: rect, columnCount: 0).isEmpty)
    }

    @Test func levelsBelowTheFloorSitOnTheLowEdge() {
        let columns = SpectrumView.columns(magnitudesDB: magnitudes(floor: -200), sampleRate: 48_000, size: 4_096,
                                           width: 200)
        let points = SpectrumView.points(columns, in: rect, columnCount: 200)
        #expect(!points.isEmpty && points.allSatisfy { $0.y == rect.y })
        let above = SpectrumView.points([(column: 3, levelDB: 6)], in: rect, columnCount: 200)
        #expect(above.first?.y == rect.y + rect.height)
    }

    @Test func theWidthIsClampedAndOddInputsAreSafe() {
        let one = SpectrumView.columns(magnitudesDB: magnitudes(), sampleRate: 48_000, size: 4_096, width: 0)
        #expect(one.count == 1 && one.first?.column == 0)
        let wide = SpectrumView.columns(magnitudesDB: magnitudes(), sampleRate: 48_000, size: 4_096, width: 10_000)
        #expect(wide.count <= 4_096 && (wide.last?.column ?? 0) < 4_096)
        #expect(SpectrumView.columns(magnitudesDB: [], sampleRate: 48_000, size: 4_096, width: 100).isEmpty)
        var nan = magnitudes()
        nan[1_000] = .nan
        #expect(SpectrumView.columns(magnitudesDB: nan, sampleRate: 48_000, size: 4_096, width: 100)
            .allSatisfy { $0.levelDB.isFinite })
    }

    @Test func decadeMarksAt48kHzAnd44kHz() throws {
        for rate in [48_000.0, 44_100.0] {
            let marks = SpectrumView.decadeMarks(sampleRate: rate, width: 400)
            #expect(marks.map(\.frequency) == [100, 1_000, 10_000])
            #expect(zip(marks, marks.dropFirst()).allSatisfy { $0.x < $1.x })
            let nyquist = rate / 2
            let x1k = try #require(marks.first { $0.frequency == 1_000 }?.x)
            #expect(near(x1k, log10(50) / log10(nyquist / 20) * 400))
        }
        let x48 = try #require(SpectrumView.decadeMarks(sampleRate: 48_000, width: 400).first { $0.frequency == 1_000 })
        #expect(near(x48.x, log10(50) / log10(1_200) * 400))
    }

    @Test func theTenKilohertzMarkIsAbsentBelowItsNyquist() {
        let marks = SpectrumView.decadeMarks(sampleRate: 16_000, width: 400)
        #expect(marks.map(\.frequency) == [100, 1_000])
    }
}
