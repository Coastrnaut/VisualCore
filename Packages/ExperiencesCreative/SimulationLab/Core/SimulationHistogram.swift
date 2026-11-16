// SimulationHistogram — feature 120 (A16-P04) T-A16-402 (FR-A16-420, SC-A16-402; clarification Q2; data-model
// "SimulationHistogram"; contracts/ui.md). Sixteen equal bins over the family's display range: the automaton's
// alive value over 0…1, reaction-diffusion v over 0…1 and the wave height over −1…1. A finite value outside the range
// falls into the end bins; NaN and infinite values are counted apart, so Σ bins + nonFinite = cells. App-local: a
// VisualCoreSimulation histogram is not added, because there is one consumer.
import Foundation
import VisualCoreSimulation

/// The value histogram of a simulation field.
public struct SimulationHistogram: Equatable, Sendable {
    /// The number of bins.
    public static let binCount = 16

    /// The count per bin (`binCount` entries, low to high).
    public let bins: [Int]
    /// The number of NaN or infinite values.
    public let nonFinite: Int
    /// The lower end of the range.
    public let low: Float
    /// The upper end of the range.
    public let high: Float

    /// The display range of `kind`: 0…1 (automaton, reaction-diffusion v) or −1…1 (wave).
    public static func range(_ kind: SimulationKind) -> (Float, Float) {
        kind == .wave ? (-1, 1) : (0, 1)
    }

    /// The channel histogrammed for `kind`: 1 (v) for reaction-diffusion, else 0.
    static func channel(_ kind: SimulationKind) -> Int { kind == .reactionDiffusion ? 1 : 0 }

    /// The bin of a finite `value` in low…high: clamp(⌊(value − low)/(high − low) · 16⌋, 0, 15).
    static func bin(_ value: Float, low: Float, high: Float) -> Int {
        let scaled = ((value - low) / (high - low) * Float(binCount)).rounded(.down)
        guard scaled.isFinite else { return scaled > 0 ? binCount - 1 : 0 }
        return min(max(Int(max(min(scaled, Float(binCount)), -1)), 0), binCount - 1)
    }

    /// The histogram of the current field of `field` for `kind`.
    public static func of(_ field: SimulationField, kind: SimulationKind) -> SimulationHistogram {
        let (low, high) = range(kind)
        let grid = field.current
        let c = min(channel(kind), grid.channels - 1)
        var bins = [Int](repeating: 0, count: binCount)
        var nonFinite = 0
        for cell in 0..<(grid.width * grid.height) {
            let value = grid.values[cell * grid.channels + c]
            if value.isFinite { bins[bin(value, low: low, high: high)] += 1 } else { nonFinite += 1 }
        }
        return SimulationHistogram(bins: bins, nonFinite: nonFinite, low: low, high: high)
    }

    /// The lowest bin index holding the largest count.
    public var fullestBin: Int {
        let top = bins.max() ?? 0
        return bins.firstIndex(of: top) ?? 0
    }

    /// The number of cells counted: Σ bins + nonFinite.
    public var total: Int { bins.reduce(0, +) + nonFinite }
}
