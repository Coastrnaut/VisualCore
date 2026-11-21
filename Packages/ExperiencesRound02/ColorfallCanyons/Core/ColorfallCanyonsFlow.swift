// ColorfallCanyonsFlow — feature 341 (R02-G05-01) T-R02G0501-002 (FR-R02G0501-002, 003, 005; clarifications Q2, Q3).
// The exact fluid state of a Colorfall Canyons play and its fixed tick of 1/60 s. A tick is computed synchronously from
// the state at its start: (1) every open or spring cell with volume V > 0 and a downhill neighbour sends
// r = min(V, flow rate) units there — the downhill neighbour is the non-rock 4-neighbour with the lowest height strictly
// below the cell's own, ties in the order east, south, west, north; a cell without one holds its fluid (a pool); basins
// and drains never pass fluid on; (2) the r units are shared between the colours by largest remainder of r · m_c / V
// (floors first, the leftover units to the largest remainders, ties to the lower colour index); (3) every open spring
// with supply left adds min(release, supply) units of its colour to its own cell; (4) what reaches a drain is counted as
// spilled. Each colour is conserved exactly: released = held in cells (basins included) + spilled. After a tick the
// verdict is decided in this order: contamination, overflow, win (never at tick 0), time.
import Foundation

/// How a play stands after a tick.
public enum ColorfallCanyonsVerdict: Sendable, Equatable {
    /// Not decided yet.
    case running
    /// Every target basin is met with no failure.
    case won
    /// The play failed for the given reason.
    case failed(ColorfallCanyonsFailure)
}

/// Why a play failed.
public enum ColorfallCanyonsFailure: String, Sendable, Codable, CaseIterable {
    /// A protected basin holds more wrong colour than it tolerates.
    case contamination
    /// A basin holds more than its capacity.
    case overflow
    /// The tick limit was reached without a win.
    case time
}

/// The exact fluid state of a play: heights, valves, supplies, colour masses per cell, spilled and released units.
public struct ColorfallCanyonsFluid: Sendable, Hashable, Codable {
    /// The ticks run so far.
    public private(set) var tick: Int
    /// The current height of every cell (carving lowers them).
    public private(set) var heights: [Int]
    /// Whether each spring's valve is open.
    public private(set) var valves: [Bool]
    /// The units each spring can still release.
    public private(set) var supplies: [Int]
    /// The units of each colour in every cell, basins included: `masses[cell][color]`.
    public private(set) var masses: [[Int]]
    /// The units of each colour that reached a drain.
    public private(set) var spilled: [Int]
    /// The units of each colour the springs have released.
    public private(set) var released: [Int]

    /// The fluid at the start of `level`: its heights and valves, full supplies, no fluid anywhere, tick 0.
    public init(level: ColorfallCanyonsLevel) {
        tick = 0
        heights = level.heights
        valves = level.springs.map(\.open)
        supplies = level.springs.map(\.supply)
        masses = Array(repeating: [0, 0, 0], count: level.cellCount)
        spilled = [0, 0, 0]
        released = [0, 0, 0]
    }

    /// The volume of `cell`: the sum of its colours.
    public func volume(_ cell: Int) -> Int { masses[cell].reduce(0, +) }

    /// The cell an open or spring `cell` passes fluid to: the non-rock 4-neighbour with the lowest height strictly below
    /// its own, ties in the order east, south, west, north; nil for a pool, a basin, a drain or rock.
    public func downhill(of cell: Int, level: ColorfallCanyonsLevel) -> Int? {
        switch level.kind(of: cell) {
        case .open, .spring: break
        case .rock, .basin, .drain: return nil
        }
        var best: Int?
        var bestHeight: Int = heights[cell]
        for next in level.neighbours(of: cell) {
            if case .rock = level.kind(of: next) { continue }
            if heights[next] < bestHeight {
                best = next
                bestHeight = heights[next]
            }
        }
        return best
    }

    /// The share of an outflow of `r` units among the colours of `masses` (volume V = Σ masses > 0, r ≤ V): floor of
    /// r · m_c / V for each colour, then the leftover units one each to the largest remainders, ties to the lower colour.
    public static func share(_ r: Int, of masses: [Int]) -> [Int] {
        let volume: Int = masses.reduce(0, +)
        guard volume > 0, r > 0 else { return [0, 0, 0] }
        var parts: [Int] = masses.map { r * $0 / volume }
        let remainders: [Int] = masses.map { r * $0 % volume }
        var left: Int = r - parts.reduce(0, +)
        let order: [Int] = [0, 1, 2].sorted { a, b in
            remainders[a] != remainders[b] ? remainders[a] > remainders[b] : a < b
        }
        for c in order where left > 0 {
            parts[c] += 1
            left -= 1
        }
        return parts
    }

    /// Lowers `cell` by one height step (the caller checks ``ColorfallCanyonsLevel/isCarvable(_:heights:)``).
    mutating func carve(_ cell: Int) { heights[cell] -= 1 }

    /// Toggles the valve of spring `index`.
    mutating func toggle(_ index: Int) { valves[index].toggle() }

    /// Runs one synchronous tick of `level`.
    public mutating func tick(level: ColorfallCanyonsLevel) {
        var next: [[Int]] = masses
        for cell in 0..<level.cellCount {
            let v: Int = volume(cell)
            guard v > 0, let target = downhill(of: cell, level: level) else { continue }
            let parts: [Int] = Self.share(min(v, level.flowRate), of: masses[cell])
            for c in 0..<3 {
                next[cell][c] -= parts[c]
                next[target][c] += parts[c]
            }
        }
        for (index, spring) in level.springs.enumerated() where valves[index] && supplies[index] > 0 {
            let amount: Int = min(spring.release, supplies[index])
            supplies[index] -= amount
            next[spring.cell][spring.color.rawValue] += amount
            released[spring.color.rawValue] += amount
        }
        for cell in 0..<level.cellCount where level.grounds[cell] == .drain {
            for c in 0..<3 {
                spilled[c] += next[cell][c]
                next[cell][c] = 0
            }
        }
        masses = next
        tick += 1
    }

    /// Whether every colour is conserved exactly: released = Σ cells + spilled.
    public func isConserved() -> Bool {
        for c in 0..<3 {
            var held: Int = spilled[c]
            for cell in masses.indices { held += masses[cell][c] }
            guard held == released[c] else { return false }
        }
        return true
    }

    /// The verdict after the latest tick: contamination (a protected basin's wrong colour above its tolerated amount),
    /// then overflow (a basin above its capacity), then win (tick ≥ 1 and every basin's target met), then time (the tick
    /// limit reached), else running.
    public func verdict(level: ColorfallCanyonsLevel) -> ColorfallCanyonsVerdict {
        for basin in level.basins where basin.isProtected && basin.wrongMass(masses[basin.cell]) > basin.toleratedWrong {
            return .failed(.contamination)
        }
        for basin in level.basins where volume(basin.cell) > basin.capacity { return .failed(.overflow) }
        if tick >= 1, level.basins.allSatisfy({ $0.accepts(masses[$0.cell]) }) { return .won }
        if tick >= level.tickLimit { return .failed(.time) }
        return .running
    }
}
