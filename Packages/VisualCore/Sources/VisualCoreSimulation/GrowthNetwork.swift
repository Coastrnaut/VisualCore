// GrowthNetwork — feature 221 (R02-F21) T-R02F21-002 (FR-R02F21-005; clarification Q4; research R6). The settings and
// cells of a network that grows over a nutrient field: from seeds into viable 4-neighbours holding at least `cost`
// quanta of the food channel, ranked by food (most first) then cell index, up to `perFrame` new cells a frame and
// `limit` cells in all; each new cell links to its lowest-index network neighbour, so the network is a forest of trees.
// The growth itself runs inside ``NutrientField/step(by:)``.

/// A network that grows over a ``NutrientField``.
public struct GrowthNetwork: Sendable, Equatable {
    /// The largest size limit.
    public static let maxCells = 65_536
    /// The largest per-frame limit.
    public static let maxPerFrame = 1_024

    /// The most cells the network may hold, seeds included.
    public let limit: Int
    /// The most cells it may grow in one frame.
    public let perFrame: Int
    /// The least viability a cell needs to be grown into, in 0 < threshold ≤ 1.
    public let threshold: Double
    /// The channel the network eats.
    public let foodChannel: Int
    /// The quanta of the food channel a new cell eats from itself (it needs at least this much).
    public let cost: Int64
    /// The network's cells in the order they joined.
    public internal(set) var cells: [Int]
    /// For each entry of ``cells``, the cell it linked to, or −1 for a seed.
    public internal(set) var parents: [Int]
    /// Membership of ``cells`` for constant-time lookup.
    var members: Set<Int>

    /// An empty network with the given settings.
    ///
    /// - Throws: `.growth("limit")` unless 1 … 65,536; `.growth("perFrame")` unless 1 … 1,024; `.growth("threshold")`
    ///   unless finite with 0 < threshold ≤ 1; `.growth("foodChannel")` for a negative channel (the upper bound is
    ///   checked by ``NutrientField/setNetwork(_:)``); `.growth("cost")` unless 0 … 2⁴⁰ quanta.
    public init(limit: Int, perFrame: Int, threshold: Double, foodChannel: Int, cost: Int64) throws(NutrientError) {
        guard limit >= 1, limit <= Self.maxCells else { throw .growth("limit") }
        guard perFrame >= 1, perFrame <= Self.maxPerFrame else { throw .growth("perFrame") }
        guard threshold.isFinite, threshold > 0, threshold <= 1 else { throw .growth("threshold") }
        guard foodChannel >= 0 else { throw .growth("foodChannel") }
        guard cost >= 0, cost <= NutrientField.maxAmount else { throw .growth("cost") }
        self.limit = limit
        self.perFrame = perFrame
        self.threshold = threshold
        self.foodChannel = foodChannel
        self.cost = cost
        self.cells = []
        self.parents = []
        self.members = []
    }

    /// The number of cells in the network.
    public var count: Int { cells.count }

    /// Whether `cell` belongs to the network.
    public func contains(_ cell: Int) -> Bool { members.contains(cell) }

    /// Appends `cell` linked to `parent` (−1 for a seed); the caller has checked every rule.
    mutating func append(_ cell: Int, parent: Int) {
        cells.append(cell)
        parents.append(parent)
        members.insert(cell)
    }

    /// Networks are equal when settings, cells and parents are equal (membership follows from the cells).
    public static func == (a: GrowthNetwork, b: GrowthNetwork) -> Bool {
        a.limit == b.limit && a.perFrame == b.perFrame && a.threshold == b.threshold && a.foodChannel == b.foodChannel
            && a.cost == b.cost && a.cells == b.cells && a.parents == b.parents
    }
}
