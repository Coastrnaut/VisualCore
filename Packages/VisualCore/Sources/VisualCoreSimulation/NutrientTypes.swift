// NutrientTypes — feature 221 (R02-F21) T-R02F21-002 (FR-R02F21-002, 003, 004, 006; clarifications Q3, Q4, Q5; research
// R4). The value types of the nutrient field: sources and sinks with their fractional carry, viability bands, the
// conservation account of each channel and the report of one frame step.

/// Whether a ``NutrientSource`` adds nutrient or removes it.
public enum NutrientSourceKind: String, Sendable, Codable, CaseIterable {
    /// Adds nutrient at its rate (capped at the cell and grid limits).
    case source
    /// Removes nutrient at its rate (at most what the cell holds).
    case sink
}

/// A local source or sink of one channel at one cell.
///
/// Over time it moves exactly ⌊rate · unit · elapsed⌋ quanta: each sub-step moves ⌊carry + rate · unit · h⌋ and keeps
/// the fraction in ``carry``.
public struct NutrientSource: Sendable, Equatable {
    /// The largest rate, in units per second.
    public static let maxRate = 1_000.0

    /// The cell (y · width + x); checked when the source is added to a field.
    public let cell: Int
    /// The channel; checked when the source is added to a field.
    public let channel: Int
    /// Whether it adds or removes nutrient.
    public let kind: NutrientSourceKind
    /// The rate in units per second.
    public let rate: Double
    /// The fraction of a quantum not yet moved, in 0 ..< 1.
    public internal(set) var carry: Double

    /// A source or sink of `rate` units per second.
    ///
    /// - Throws: `.parameter("rate")` unless the rate is finite with 0 < rate ≤ 1,000.
    public init(cell: Int, channel: Int, kind: NutrientSourceKind, rate: Double) throws(NutrientError) {
        guard rate.isFinite, rate > 0, rate <= Self.maxRate else { throw .parameter("rate") }
        self.cell = cell
        self.channel = channel
        self.kind = kind
        self.rate = rate
        self.carry = 0
    }

    /// A source with a stored carry (decoding); the carry must be finite in 0 ..< 1.
    init(cell: Int, channel: Int, kind: NutrientSourceKind, rate: Double, carry: Double) throws(NutrientError) {
        try self.init(cell: cell, channel: channel, kind: kind, rate: rate)
        guard carry.isFinite, carry >= 0, carry < 1 else { throw .parameter("carry") }
        self.carry = carry
    }
}

/// The range of a channel in which life thrives.
public struct ViabilityBand: Sendable, Equatable, Codable {
    /// The lowest fully viable amount, in units.
    public let low: Double
    /// The highest fully viable amount, in units.
    public let high: Double
    /// The width of the linear ramp to 0 on either side, in units (0 is a hard step).
    public let ramp: Double

    /// A band from `low` to `high` with a ramp of `ramp` units on either side.
    ///
    /// - Throws: `.parameter("band")` unless all three are finite, low ≤ high and ramp ≥ 0.
    public init(low: Double, high: Double, ramp: Double = 0) throws(NutrientError) {
        guard low.isFinite, high.isFinite, ramp.isFinite, low <= high, ramp >= 0 else { throw .parameter("band") }
        self.low = low
        self.high = high
        self.ramp = ramp
    }

    private enum CodingKeys: String, CodingKey { case low, high, ramp }

    /// Decodes a band and checks it with the same rules as ``init(low:high:ramp:)``.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(low: c.decode(Double.self, forKey: .low), high: c.decode(Double.self, forKey: .high),
                          ramp: c.decode(Double.self, forKey: .ramp))
        } catch let error as NutrientError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }

    /// 1 inside [low, high], falling linearly to 0 at low − ramp and high + ramp, 0 beyond; 0 for a non-finite amount.
    public func membership(_ units: Double) -> Double {
        guard units.isFinite else { return 0 }
        if units >= low && units <= high { return 1 }
        guard ramp > 0 else { return 0 }
        let outside = units < low ? low - units : units - high
        return outside >= ramp ? 0 : 1 - outside / ramp
    }
}

/// The conservation account of one channel, in quanta.
public struct NutrientAccount: Sendable, Equatable, Codable {
    /// Quanta added by ``NutrientField/add(_:channel:at:)`` and sources.
    public var added: Int64
    /// Quanta removed by ``NutrientField/remove(_:channel:at:)`` and sinks.
    public var removed: Int64
    /// Quanta faded by decay.
    public var faded: Int64
    /// Quanta eaten by network growth.
    public var eaten: Int64

    /// An empty account.
    public init(added: Int64 = 0, removed: Int64 = 0, faded: Int64 = 0, eaten: Int64 = 0) {
        self.added = added
        self.removed = removed
        self.faded = faded
        self.eaten = eaten
    }

    /// What the channel must hold, added − removed − faded − eaten.
    public var net: Int64 { added - removed - faded - eaten }
}

/// The conservation accounts of every channel of a field.
public struct NutrientLedger: Sendable, Equatable, Codable {
    /// One account per channel.
    public var accounts: [NutrientAccount]

    /// A ledger of `accounts`.
    public init(accounts: [NutrientAccount]) { self.accounts = accounts }
}

/// What one ``NutrientField/step(by:)`` did.
public struct NutrientStepReport: Sendable, Equatable {
    /// The number of sub-steps run.
    public let substeps: Int
    /// The time simulated, in seconds.
    public let simulated: Double
    /// The frame time not simulated (beyond 0.25 s or 256 sub-steps), in seconds.
    public let dropped: Double
    /// Quanta added by sources in this frame, per channel.
    public let added: [Int64]
    /// Quanta removed by sinks in this frame, per channel.
    public let removed: [Int64]
    /// Quanta faded by decay in this frame, per channel.
    public let faded: [Int64]
    /// Quanta eaten by growth in this frame, per channel.
    public let eaten: [Int64]
    /// Quanta sources could not add because a cell or grid total was at its limit.
    public let capped: Int64
    /// Quanta sinks could not remove because their cells were empty.
    public let short: Int64
    /// Cells the network grew in this frame.
    public let grown: Int

    /// A report of the given values.
    public init(substeps: Int, simulated: Double, dropped: Double, added: [Int64], removed: [Int64], faded: [Int64],
                eaten: [Int64], capped: Int64, short: Int64, grown: Int) {
        self.substeps = substeps
        self.simulated = simulated
        self.dropped = dropped
        self.added = added
        self.removed = removed
        self.faded = faded
        self.eaten = eaten
        self.capped = capped
        self.short = short
        self.grown = grown
    }
}
