// NutrientField — feature 221 (R02-F21) T-R02F21-002 (FR-R02F21-001…005, 008; clarifications Q1…Q4; research R1, R7).
// A walled grid of 2 … 512 cells per side (at most 262,144 cells) with 1 … 4 channels of Int64 quanta (65,536 per unit);
// a cell and a channel's grid total hold at most 2⁴⁰ quanta. Each channel diffuses at rate D (cells² per second,
// 0 … 1,000) and decays at rate λ (per second, 0 … 100). Every quantum added, removed, faded or eaten is counted in the
// ledger, so each channel's total equals its account's net exactly. Cell (x, y) has index y · width + x, the order of
// `FieldGrid` (row 0 at the bottom) and `GridGraph`. The step lives in NutrientField+Step.swift, growth in
// NutrientField+Growth.swift and the stored form in NutrientField+Coding.swift.
import Foundation

/// A grid of nutrient channels with exact diffusion, sources, sinks, decay, viability and network growth.
public struct NutrientField: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1
    /// Quanta per unit of nutrient.
    public static let quantaPerUnit: Int64 = 65_536
    /// The most quanta a cell, or a channel's grid total, may hold.
    public static let maxAmount: Int64 = 1 << 40
    /// The smallest side.
    public static let minSide = 2
    /// The largest side.
    public static let maxSide = 512
    /// The most cells.
    public static let maxCells = 262_144
    /// The most channels.
    public static let maxChannels = 4
    /// The largest diffusion rate, in cells² per second.
    public static let maxDiffusion = 1_000.0
    /// The largest decay rate, per second.
    public static let maxDecay = 100.0
    /// The longest frame simulated; the rest is dropped and reported.
    public static let maxFrame = 0.25
    /// The most sub-steps in one frame.
    public static let maxSubsteps = 256
    /// The most sources and sinks.
    public static let maxSources = 256

    /// Cells along x.
    public let width: Int
    /// Cells along y.
    public let height: Int
    /// The number of channels.
    public let channels: Int
    /// The diffusion rate D of each channel, in cells² per second.
    public let diffusion: [Double]
    /// The decay rate λ of each channel, per second.
    public let decay: [Double]
    /// The sources and sinks, in the order they were added.
    public internal(set) var sources: [NutrientSource]
    /// The viability band of each channel, or nil for a channel without one.
    public internal(set) var bands: [ViabilityBand?]
    /// The growth network, if any.
    public internal(set) var network: GrowthNetwork?
    /// The conservation account of every channel.
    public internal(set) var ledger: NutrientLedger

    /// Amounts in quanta, channel-major: channel k, cell c at k · cellCount + c.
    var amountQ: [Int64]
    /// Each channel's grid total in quanta.
    var totalQ: [Int64]

    /// An empty field.
    ///
    /// - Throws: `.gridSize` unless each side is 2 … 512 with at most 262,144 cells; `.channel(n)` unless 1 … 4
    ///   channels; `.parameter("diffusion")` unless one finite rate 0 … 1,000 per channel; `.parameter("decay")` unless
    ///   one finite rate 0 … 100 per channel (nil gives zeros).
    public init(width: Int, height: Int, channels: Int = 1, diffusion: [Double],
                decay: [Double]? = nil) throws(NutrientError) {
        guard width >= Self.minSide, width <= Self.maxSide, height >= Self.minSide, height <= Self.maxSide,
              width * height <= Self.maxCells else { throw .gridSize }
        guard channels >= 1, channels <= Self.maxChannels else { throw .channel(channels) }
        guard diffusion.count == channels,
              diffusion.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= Self.maxDiffusion }) else {
            throw .parameter("diffusion")
        }
        let rates = decay ?? [Double](repeating: 0, count: channels)
        guard rates.count == channels, rates.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= Self.maxDecay }) else {
            throw .parameter("decay")
        }
        self.width = width
        self.height = height
        self.channels = channels
        self.diffusion = diffusion
        self.decay = rates
        self.sources = []
        self.bands = [ViabilityBand?](repeating: nil, count: channels)
        self.network = nil
        self.ledger = NutrientLedger(accounts: [NutrientAccount](repeating: NutrientAccount(), count: channels))
        self.amountQ = [Int64](repeating: 0, count: channels * width * height)
        self.totalQ = [Int64](repeating: 0, count: channels)
    }

    /// The number of cells, width · height.
    public var cellCount: Int { width * height }

    /// The index of cell (x, y), y · width + x (not range-checked).
    public func cell(x: Int, y: Int) -> Int { y * width + x }

    /// The quanta of `channel` at `cell`; 0 for a channel or cell out of range.
    public func amount(_ channel: Int, at cell: Int) -> Int64 {
        guard channel >= 0, channel < channels, cell >= 0, cell < cellCount else { return 0 }
        return amountQ[channel * cellCount + cell]
    }

    /// The grid total of `channel` in quanta; 0 for a channel out of range.
    public func total(_ channel: Int) -> Int64 {
        guard channel >= 0, channel < channels else { return 0 }
        return totalQ[channel]
    }

    /// Whether every channel's summed cells equal both its kept total and its account's net, and no cell is negative.
    public var isBalanced: Bool {
        let n = cellCount
        for k in 0..<channels {
            var sum: Int64 = 0
            for c in 0..<n {
                let a = amountQ[k * n + c]
                if a < 0 { return false }
                sum += a
            }
            if sum != totalQ[k] || sum != ledger.accounts[k].net { return false }
        }
        return true
    }

    /// Checks a channel and a cell.
    func check(channel: Int, cell: Int) throws(NutrientError) {
        guard channel >= 0, channel < channels else { throw .channel(channel) }
        guard cell >= 0, cell < cellCount else { throw .cellRange(cell) }
    }

    /// Adds `quanta` of `channel` at `cell`, counted as added.
    ///
    /// - Throws: `.channel`, `.cellRange`, or `.amountLimit` for a negative amount or one that would take the cell or
    ///   the channel's total past 2⁴⁰ quanta (nothing changes then).
    public mutating func add(_ quanta: Int64, channel: Int, at cell: Int) throws(NutrientError) {
        try check(channel: channel, cell: cell)
        let i = channel * cellCount + cell
        guard quanta >= 0, quanta <= Self.maxAmount - amountQ[i], quanta <= Self.maxAmount - totalQ[channel] else {
            throw .amountLimit
        }
        amountQ[i] += quanta
        totalQ[channel] += quanta
        ledger.accounts[channel].added += quanta
    }

    /// Removes up to `quanta` of `channel` at `cell` and returns what was taken (at most what the cell holds), counted
    /// as removed.
    ///
    /// - Throws: `.channel`, `.cellRange`, or `.amountLimit` for a negative amount.
    @discardableResult
    public mutating func remove(_ quanta: Int64, channel: Int, at cell: Int) throws(NutrientError) -> Int64 {
        try check(channel: channel, cell: cell)
        guard quanta >= 0 else { throw .amountLimit }
        let i = channel * cellCount + cell
        let taken = min(quanta, amountQ[i])
        amountQ[i] -= taken
        totalQ[channel] -= taken
        ledger.accounts[channel].removed += taken
        return taken
    }

    /// Adds a source or sink.
    ///
    /// - Throws: `.sourceLimit` past 256; `.channel` or `.cellRange` for the source's channel or cell.
    public mutating func addSource(_ source: NutrientSource) throws(NutrientError) {
        guard sources.count < Self.maxSources else { throw .sourceLimit }
        try check(channel: source.channel, cell: source.cell)
        sources.append(source)
    }

    /// Sets (or with nil clears) the viability band of `channel`.
    ///
    /// - Throws: `.channel` for a channel out of range.
    public mutating func setBand(_ band: ViabilityBand?, channel: Int) throws(NutrientError) {
        guard channel >= 0, channel < channels else { throw .channel(channel) }
        bands[channel] = band
    }

    /// The viability of `cell` in 0 … 1: the least membership over the channels that have a band, 1 without bands;
    /// 0 for a cell out of range.
    public func viability(at cell: Int) -> Double {
        guard cell >= 0, cell < cellCount else { return 0 }
        var result = 1.0
        let unit = Double(Self.quantaPerUnit)
        for k in 0..<channels {
            guard let band = bands[k] else { continue }
            result = min(result, band.membership(Double(amountQ[k * cellCount + cell]) / unit))
        }
        return result
    }

    /// Sets (or with nil clears) the growth network, replacing any previous one.
    ///
    /// - Throws: `.growth("foodChannel")` when its food channel is not a channel of this field; `.cellRange` for a
    ///   network cell outside the grid; `.growth("limit")` when it already holds more cells than its limit.
    public mutating func setNetwork(_ network: GrowthNetwork?) throws(NutrientError) {
        if let network {
            guard network.foodChannel < channels else { throw .growth("foodChannel") }
            guard network.count <= network.limit else { throw .growth("limit") }
            for c in network.cells where c < 0 || c >= cellCount { throw .cellRange(c) }
            for p in network.parents where p < -1 || p >= cellCount { throw .cellRange(p) }
        }
        self.network = network
    }

    /// Places a seed of the network at `cell`.
    ///
    /// - Throws: `.growth("network")` without a network; `.cellRange`; `.growth("seed")` on a network cell;
    ///   `.growth("limit")` when the network is full.
    public mutating func seed(at cell: Int) throws(NutrientError) {
        guard var grown = network else { throw .growth("network") }
        guard cell >= 0, cell < cellCount else { throw .cellRange(cell) }
        guard !grown.contains(cell) else { throw .growth("seed") }
        guard grown.count < grown.limit else { throw .growth("limit") }
        grown.append(cell, parent: -1)
        network = grown
    }

    /// `channel` in units as a one-channel `FieldGrid` (cell (x, y) at y · width + x, row 0 at the bottom); nil for a
    /// channel out of range.
    public func fieldGrid(channel: Int) -> FieldGrid? {
        guard channel >= 0, channel < channels else { return nil }
        let unit = Double(Self.quantaPerUnit)
        var values: [Float] = []
        values.reserveCapacity(cellCount)
        for c in 0..<cellCount { values.append(Float(Double(amountQ[channel * cellCount + c]) / unit)) }
        return FieldGrid(width: width, height: height, channels: 1, values: values)
    }

    /// The viability of every cell as a one-channel `FieldGrid` in the same order.
    public func viabilityGrid() -> FieldGrid {
        var values: [Float] = []
        values.reserveCapacity(cellCount)
        for c in 0..<cellCount { values.append(Float(viability(at: c))) }
        guard let grid = FieldGrid(width: width, height: height, channels: 1, values: values) else {
            preconditionFailure("NutrientField sizes are always valid FieldGrid sizes")
        }
        return grid
    }
}
