// ColorfallCanyonsFixtures — feature 341 (R02-G05-01) T-R02G0501-002 (SC-R02G0501-001 … 005). Seeded test levels shared by
// the Colorfall Canyons kernel tests. Deterministic: a SplitMix64 generator, no clock. Fixture seed 2_341.
//
// `fixture(_:)` builds a channel level with a known solution: rows 0, 2 and 3 are rock except a drain at the bottom
// right; row 1 holds the spring at column 0, a channel whose heights fall by one per column, a dam at column k that
// stands d = 0 … 2 above its upstream neighbour (so the fluid pools behind it) and the basin at the last column (height
// 0). The basin wants only the spring's colour, at least `fill` units, and can hold the whole supply. The known
// solution is: toggle the valve when the spring starts closed, carve the dam d + 1 times, then step the tick limit
// (the step stops at the win). Without the carves the fluid pools and the level fails on time.
//
// `randomLevel(_:)` builds an arbitrary valid level (any heights, rock, drains, springs, basins and limits) for the flow
// and replay checks; it has no known solution.
import Foundation
@testable import ColorfallCanyonsCore

/// A small deterministic generator (SplitMix64).
struct ColorfallCanyonsRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }

    /// A fair coin.
    mutating func bool() -> Bool { next() & 1 == 1 }
}

/// A seeded level with its known solution.
struct ColorfallCanyonsFixture {
    let level: ColorfallCanyonsLevel
    let solution: [ColorfallCanyonsAction]
    /// The dam cell the solution carves.
    let dam: Int
}

enum ColorfallCanyonsFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_341

    /// Fixture `index`: a deterministic channel level and its known solution.
    static func fixture(_ index: Int, tutorial: Bool = false) -> ColorfallCanyonsFixture {
        var random = ColorfallCanyonsRandom(seed: seed &+ UInt64(index) &* 7_919)
        let columns: Int = random.int(5...12)
        let rows: Int = 4
        let damColumn: Int = random.int(1...(columns - 2))
        let rise: Int = random.int(0...2)
        let color = ColorfallCanyonsColor(rawValue: random.int(0...2))!
        let release: Int = random.int(1...4)
        let flowRate: Int = random.int(release...8)
        let fill: Int = random.int(5...40)
        let supply: Int = fill + random.int(0...10)
        let open: Bool = random.bool()
        var grounds = [ColorfallCanyonsGround](repeating: .rock, count: columns * rows)
        var heights = [Int](repeating: 15, count: columns * rows)
        for column in 0..<columns {
            let cell: Int = columns + column
            grounds[cell] = .open
            heights[cell] = 13 - column
        }
        let dam: Int = columns + damColumn
        heights[dam] = heights[dam - 1] + rise
        let basinCell: Int = columns + columns - 1
        heights[basinCell] = 0
        let drain: Int = columns * rows - 1
        grounds[drain] = .drain
        heights[drain] = 0
        var shares = [0, 0, 0]
        shares[color.rawValue] = 1_000
        let spring = ColorfallCanyonsSpring(cell: columns, color: color, release: release, supply: supply, open: open)
        let basin = ColorfallCanyonsBasin(cell: basinCell, capacity: supply + 5, fill: fill, shares: shares,
                                          tolerance: random.int(0...500), isProtected: random.bool(), toleratedWrong: 0)
        let carves: Int = rise + 1
        let valve: Int = open ? 0 : 1
        let budget: Int = carves + valve + random.int(0...2)
        let tickLimit: Int = columns + fill + 20
        let level: ColorfallCanyonsLevel
        do {
            level = try ColorfallCanyonsLevel(id: "fixture-\(index)", seed: seed &+ UInt64(index), difficulty: 1 + index % 5,
                                              columns: columns, rows: rows, heights: heights, grounds: grounds,
                                              springs: [spring], basins: [basin], flowRate: flowRate, budget: budget,
                                              tickLimit: tickLimit, tutorial: tutorial)
        } catch {
            preconditionFailure("fixture \(index) is valid: \(error)")
        }
        var solution: [ColorfallCanyonsAction] = open ? [] : [.valve(0)]
        solution += Array(repeating: ColorfallCanyonsAction.carve(dam), count: carves)
        solution.append(.step(tickLimit))
        return ColorfallCanyonsFixture(level: level, solution: solution, dam: dam)
    }

    /// Random level `index`: arbitrary valid values, no known solution.
    static func randomLevel(_ index: Int, tutorial: Bool = false) -> ColorfallCanyonsLevel {
        var random = ColorfallCanyonsRandom(seed: seed &+ 1_000_003 &+ UInt64(index) &* 104_729)
        let columns: Int = random.int(4...12)
        let rows: Int = random.int(4...10)
        let count: Int = columns * rows
        var heights: [Int] = []
        var grounds: [ColorfallCanyonsGround] = []
        for _ in 0..<count {
            heights.append(random.int(0...15))
            let roll: Int = random.int(0...99)
            grounds.append(roll < 15 ? .rock : (roll < 22 ? .drain : .open))
        }
        grounds[random.int(0...(count - 1))] = .drain
        var open: [Int] = (0..<count).filter { grounds[$0] == .open }
        while open.count < 7 {
            let cell: Int = random.int(0...(count - 1))
            if grounds[cell] == .rock { grounds[cell] = .open }
            open = (0..<count).filter { grounds[$0] == .open }
        }
        var springs: [ColorfallCanyonsSpring] = []
        var basins: [ColorfallCanyonsBasin] = []
        func take() -> Int { open.remove(at: random.int(0...(open.count - 1))) }
        for _ in 0..<random.int(1...3) {
            springs.append(ColorfallCanyonsSpring(cell: take(), color: ColorfallCanyonsColor(rawValue: random.int(0...2))!,
                                                  release: random.int(1...4), supply: random.int(1...999),
                                                  open: random.bool()))
        }
        for b in 0..<random.int(1...4) {
            let a: Int = random.int(0...1_000)
            let c: Int = random.int(0...(1_000 - a))
            var shares = [a, c, 1_000 - a - c]
            if random.bool() { shares[random.int(0...2)] = 0; shares[0] += 1_000 - shares.reduce(0, +) }
            let capacity: Int = random.int(1...999)
            basins.append(ColorfallCanyonsBasin(cell: take(), capacity: capacity,
                                                fill: b == 0 ? random.int(1...capacity) : random.int(0...capacity),
                                                shares: shares, tolerance: random.int(0...500),
                                                isProtected: random.bool(), toleratedWrong: random.int(0...999)))
        }
        do {
            return try ColorfallCanyonsLevel(id: "random-\(index)", seed: seed &+ UInt64(index), difficulty: random.int(1...5),
                                             columns: columns, rows: rows, heights: heights, grounds: grounds,
                                             springs: springs, basins: basins, flowRate: random.int(1...8),
                                             budget: random.int(1...30), tickLimit: random.int(1...120),
                                             tutorial: tutorial)
        } catch {
            preconditionFailure("random level \(index) is valid: \(error)")
        }
    }
}
