// SimulationHistogramTests — feature 120 (A16-P04) T-A16-402 (FR-A16-420; SC-A16-402; clarification Q2). The
// 16-bin histogram, host-free and short: known grids give known counts; Σ bins + nonFinite equals the cell count;
// finite values outside the range fall into the end bins; NaN and infinity are counted apart; the ranges are 0…1
// (automaton, reaction-diffusion v) and −1…1 (wave); the fullest bin is the lowest index with the largest count.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct SimulationHistogramTests {
    /// A 1-channel field over `values` (a 4 × 4 grid).
    private func field(_ values: [Float]) -> SimulationField {
        SimulationField(current: FieldGrid(width: 4, height: 4, channels: 1, values: values)!)
    }

    @Test func theRangesFollowTheFamily() {
        let automaton = SimulationHistogram.range(.automaton)
        let reaction = SimulationHistogram.range(.reactionDiffusion)
        let wave = SimulationHistogram.range(.wave)
        #expect(automaton.0 == 0 && automaton.1 == 1)
        #expect(reaction.0 == 0 && reaction.1 == 1)
        #expect(wave.0 == -1 && wave.1 == 1)
        #expect(SimulationHistogram.binCount == 16)
    }

    @Test func automatonCellsFallInTheEndBins() {
        var values = [Float](repeating: 0, count: 16)
        for i in 0..<4 { values[i] = 1 }
        let h = SimulationHistogram.of(field(values), kind: .automaton)
        #expect(h.bins.count == 16 && h.bins[0] == 12 && h.bins[15] == 4 && h.nonFinite == 0)
        #expect(h.total == 16 && h.fullestBin == 0 && h.low == 0 && h.high == 1)
    }

    @Test func waveValuesAreClampedAndNonFiniteCountedApart() {
        let values: [Float] = [-2, -1, -0.99, 0, 0.0625, 0.99, 1, 2, .nan, .infinity, -.infinity, 0.5, 0.5, 0.5, -0.5,
                               0.124]
        let h = SimulationHistogram.of(field(values), kind: .wave)
        #expect(h.nonFinite == 3)
        #expect(h.bins[0] == 3)   // −2, −1, −0.99
        #expect(h.bins[8] == 3)   // 0, 0.0625, 0.124
        #expect(h.bins[12] == 3)  // 0.5 × 3
        #expect(h.bins[4] == 1)   // −0.5
        #expect(h.bins[15] == 3)  // 0.99, 1, 2
        #expect(h.bins.reduce(0, +) + h.nonFinite == 16 && h.total == 16)
        #expect(h.fullestBin == 0)
    }

    @Test func reactionDiffusionCountsV() {
        var grid = FieldGrid(width: 4, height: 4, channels: 2)
        for cell in 0..<16 {
            grid.values[cell * 2] = 7                         // u is ignored
            grid.values[cell * 2 + 1] = cell < 10 ? 0.25 : 0.5
        }
        let h = SimulationHistogram.of(SimulationField(current: grid), kind: .reactionDiffusion)
        #expect(h.bins[4] == 10 && h.bins[8] == 6 && h.total == 16 && h.fullestBin == 4)
    }

    @Test func aTieGoesToTheLowestBin() {
        var values = [Float](repeating: 0, count: 16)
        for i in 0..<8 { values[i] = 1 }
        #expect(SimulationHistogram.of(field(values), kind: .automaton).fullestBin == 0)
        let empty = SimulationHistogram.of(field([Float](repeating: .nan, count: 16)), kind: .automaton)
        #expect(empty.nonFinite == 16 && empty.fullestBin == 0 && empty.total == 16)
    }

    @Test func everyStandardStartCountsEveryCell() throws {
        for kind in SimulationKind.allCases {
            var m = try SimulationModel(spec: .standard(kind), running: false)
            for _ in 0..<3 {
                let h = SimulationHistogram.of(m.field, kind: kind)
                #expect(h.bins.reduce(0, +) + h.nonFinite == 4096)
                m.step()
            }
        }
    }
}
