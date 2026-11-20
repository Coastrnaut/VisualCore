// Heightfield — feature 217 (R02-F17) T-R02F17-002 (FR-R02F17-001, FR-R02F17-006, FR-R02F17-008; clarification Q1;
// research R1, R7). Terrain, water, suspended sediment and up to four dye channels on a width × height grid, every
// amount an `Int64` count of quanta (65,536 per height unit, cell size 1). Every change moves whole quanta — between
// cells in a step, or in and out through the ledgered edits below — so each quantity's grid total equals its ledger
// account exactly, on every device. The 2⁴⁰ bound holds for every cell and every grid total, so flow can never push a
// cell past it. Cells are indexed y·width + x; fluxes are kept four per cell in the order up (y − 1), right (x + 1),
// down (y + 1), left (x − 1). Drawing hands the heights to the existing `FieldGrid` passes.

/// A conserving shallow-water heightfield with dye and erosion.
public struct Heightfield: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1
    /// Quanta per height unit.
    public static let quantaPerUnit: Int64 = 65_536
    /// The most quanta a cell, or a quantity's grid total, may hold.
    public static let maxAmount: Int64 = 1 << 40
    /// The smallest side.
    public static let minSide = 4
    /// The largest side.
    public static let maxSide = 1_024
    /// The most cells.
    public static let maxCells = 262_144
    /// The most dye channels.
    public static let maxDyeChannels = 4
    /// The largest flux kept on an edge.
    public static let maxFlux = 1_000_000.0

    /// Cells across.
    public let width: Int
    /// Cells down.
    public let height: Int
    /// The number of dye channels, 0 … ``maxDyeChannels``.
    public let dyeChannels: Int
    /// What happens at the border.
    public let edges: HeightfieldEdges
    /// The flow and erosion constants.
    public let parameters: HeightfieldParameters
    /// Every quantum added, removed or drained.
    public internal(set) var ledger: HeightfieldLedger

    var terrainQ: [Int64]
    var waterQ: [Int64]
    var sedimentQ: [Int64]
    /// Channel-major: channel k of cell c is at k · cells + c.
    var dyeQ: [Int64]
    /// Four per cell: up, right, down, left.
    var fluxes: [Double]

    /// Creates a dry, flat grid at height 0; refuses sides outside 4 … 1,024 or more than 262,144 cells with
    /// ``HeightfieldError/gridSize``, a dye channel count outside 0 … 4 with ``HeightfieldError/dyeChannel(_:)`` and
    /// parameters outside their ranges with ``HeightfieldError/invalidParameter(_:)``.
    public init(width: Int, height: Int, dyeChannels: Int = 0, edges: HeightfieldEdges = .walled,
                parameters: HeightfieldParameters = .init()) throws(HeightfieldError) {
        guard (Self.minSide...Self.maxSide).contains(width), (Self.minSide...Self.maxSide).contains(height),
              width * height <= Self.maxCells else { throw .gridSize }
        guard (0...Self.maxDyeChannels).contains(dyeChannels) else { throw .dyeChannel(dyeChannels) }
        self.parameters = try parameters.validated()
        self.width = width
        self.height = height
        self.dyeChannels = dyeChannels
        self.edges = edges
        let cells = width * height
        ledger = HeightfieldLedger(dyeChannels: dyeChannels)
        terrainQ = Array(repeating: 0, count: cells)
        waterQ = Array(repeating: 0, count: cells)
        sedimentQ = Array(repeating: 0, count: cells)
        dyeQ = Array(repeating: 0, count: cells * dyeChannels)
        fluxes = Array(repeating: 0, count: cells * 4)
    }

    /// The number of cells.
    public var cellCount: Int { width * height }

    /// The index of cell (x, y), y·width + x (not checked).
    public func cell(x: Int, y: Int) -> Int { y * width + x }

    /// Terrain at `cell` in quanta (0 outside the grid).
    public func terrain(at cell: Int) -> Int64 { contains(cell) ? terrainQ[cell] : 0 }
    /// Water at `cell` in quanta (0 outside the grid).
    public func water(at cell: Int) -> Int64 { contains(cell) ? waterQ[cell] : 0 }
    /// Suspended sediment at `cell` in quanta (0 outside the grid).
    public func sediment(at cell: Int) -> Int64 { contains(cell) ? sedimentQ[cell] : 0 }
    /// Dye `channel` at `cell` in quanta (0 outside the grid or the channels).
    public func dye(_ channel: Int, at cell: Int) -> Int64 {
        guard contains(cell), channel >= 0, channel < dyeChannels else { return 0 }
        return dyeQ[channel * cellCount + cell]
    }
    /// The four outflow fluxes of `cell` (up, right, down, left); zeros outside the grid.
    public func flux(at cell: Int) -> [Double] {
        contains(cell) ? Array(fluxes[(cell * 4)..<(cell * 4 + 4)]) : [0, 0, 0, 0]
    }

    /// The water surface at `cell`, (terrain + water) in height units.
    public func surface(at cell: Int) -> Double {
        Double(terrain(at: cell) + water(at: cell)) / Double(Self.quantaPerUnit)
    }

    /// The grid's water in quanta.
    public var totalWater: Int64 { waterQ.reduce(0, +) }
    /// The grid's rock (terrain plus suspended sediment) in quanta.
    public var totalRock: Int64 { terrainQ.reduce(0, +) + sedimentQ.reduce(0, +) }
    /// The grid's dye of `channel` in quanta (0 for a channel outside the range).
    public func totalDye(_ channel: Int) -> Int64 {
        guard channel >= 0, channel < dyeChannels else { return 0 }
        return dyeQ[(channel * cellCount)..<((channel + 1) * cellCount)].reduce(0, +)
    }

    /// Whether every quantity's grid total equals its ledger account's net exactly.
    public var isBalanced: Bool {
        guard totalWater == ledger.water.net, totalRock == ledger.rock.net else { return false }
        for k in 0..<dyeChannels where totalDye(k) != ledger.dye[k].net { return false }
        return true
    }

    // MARK: Ledgered edits

    /// Adds terrain at `cell`, counted as rock added.
    public mutating func add(terrain amount: Int64, at cell: Int) throws(HeightfieldError) {
        try check(cell)
        try checkAdd(amount, to: terrainQ[cell] + sedimentQ[cell], total: totalRock)
        terrainQ[cell] += amount
        ledger.rock.added += amount
    }

    /// Adds water at `cell`, counted as water added.
    public mutating func add(water amount: Int64, at cell: Int) throws(HeightfieldError) {
        try check(cell)
        try checkAdd(amount, to: waterQ[cell], total: totalWater)
        waterQ[cell] += amount
        ledger.water.added += amount
    }

    /// Adds dye of `channel` at `cell`, counted as that dye added.
    public mutating func add(dye amount: Int64, channel: Int, at cell: Int) throws(HeightfieldError) {
        try check(cell)
        try checkChannel(channel)
        try checkAdd(amount, to: dyeQ[channel * cellCount + cell], total: totalDye(channel))
        dyeQ[channel * cellCount + cell] += amount
        ledger.dye[channel].added += amount
    }

    /// Removes up to `amount` water at `cell` and returns what was removed, counted as water removed.
    @discardableResult
    public mutating func remove(water amount: Int64, at cell: Int) throws(HeightfieldError) -> Int64 {
        try check(cell)
        guard amount >= 0 else { throw .amountLimit }
        let taken = min(amount, waterQ[cell])
        waterQ[cell] -= taken
        ledger.water.removed += taken
        return taken
    }

    /// Removes up to `amount` terrain at `cell` (never below the floor 0) and returns what was removed, counted as rock
    /// removed.
    @discardableResult
    public mutating func remove(terrain amount: Int64, at cell: Int) throws(HeightfieldError) -> Int64 {
        try check(cell)
        guard amount >= 0 else { throw .amountLimit }
        let taken = min(amount, terrainQ[cell])
        terrainQ[cell] -= taken
        ledger.rock.removed += taken
        return taken
    }

    /// Removes up to `amount` dye of `channel` at `cell` and returns what was removed, counted as that dye removed.
    @discardableResult
    public mutating func remove(dye amount: Int64, channel: Int, at cell: Int) throws(HeightfieldError) -> Int64 {
        try check(cell)
        try checkChannel(channel)
        guard amount >= 0 else { throw .amountLimit }
        let index = channel * cellCount + cell
        let taken = min(amount, dyeQ[index])
        dyeQ[index] -= taken
        ledger.dye[channel].removed += taken
        return taken
    }

    // MARK: Drawing

    /// The heights for the existing field passes: four channels (terrain, water depth, sediment, total dye), in height
    /// units, cell (x, y) at row y.
    public func fieldGrid() -> FieldGrid {
        var grid = FieldGrid(width: width, height: height, channels: 4)
        let unit = Double(Self.quantaPerUnit)
        for c in 0..<cellCount {
            var dyeSum: Int64 = 0
            for k in 0..<dyeChannels { dyeSum += dyeQ[k * cellCount + c] }
            grid.values[c * 4] = Float(Double(terrainQ[c]) / unit)
            grid.values[c * 4 + 1] = Float(Double(waterQ[c]) / unit)
            grid.values[c * 4 + 2] = Float(Double(sedimentQ[c]) / unit)
            grid.values[c * 4 + 3] = Float(Double(dyeSum) / unit)
        }
        return grid
    }

    /// One channel per dye, in height units, or nil without dye.
    public func dyeField() -> FieldGrid? {
        guard dyeChannels > 0 else { return nil }
        var grid = FieldGrid(width: width, height: height, channels: dyeChannels)
        let unit = Double(Self.quantaPerUnit)
        for c in 0..<cellCount {
            for k in 0..<dyeChannels {
                grid.values[c * dyeChannels + k] = Float(Double(dyeQ[k * cellCount + c]) / unit)
            }
        }
        return grid
    }

    // MARK: Checks

    func contains(_ cell: Int) -> Bool { cell >= 0 && cell < cellCount }

    private func check(_ cell: Int) throws(HeightfieldError) {
        guard contains(cell) else { throw .cellRange(cell) }
    }

    private func checkChannel(_ channel: Int) throws(HeightfieldError) {
        guard channel >= 0, channel < dyeChannels else { throw .dyeChannel(channel) }
    }

    private func checkAdd(_ amount: Int64, to cellAmount: Int64, total: Int64) throws(HeightfieldError) {
        guard amount >= 0, amount <= Self.maxAmount, cellAmount + amount <= Self.maxAmount,
              total + amount <= Self.maxAmount else { throw .amountLimit }
    }
}
