// ColorfallCanyonsFlowTests — feature 341 (R02-G05-01) T-R02G0501-003 (FR-R02G0501-002, 003; SC-R02G0501-003). The
// tick of clarification Q2 against an independent brute-force reference written here (500 seeded levels, valves as
// given and every valve toggled), exact per-colour conservation on every tick, the largest-remainder share, pools,
// the east-south-west-north tie order, rock, basins and drains, dry springs and closed valves, and the order of the
// verdict (contamination, overflow, win never at tick 0, time) with its boundaries one unit either side.
import Foundation
import XCTest
@testable import ColorfallCanyonsCore

/// An independent brute-force model of clarification Q2; it never calls the kernel's flow functions.
private struct ReferenceFlow: Equatable {
    var valves: [Bool]
    var supplies: [Int]
    var masses: [[Int]]
    var spilled: [Int] = [0, 0, 0]
    var released: [Int] = [0, 0, 0]

    /// 0 open, 1 rock, 2 drain, 3 spring, 4 basin — resolved from the level's raw values.
    let kinds: [Int]
    let heights: [Int]
    let columns: Int
    let rows: Int
    let flowRate: Int
    let springs: [(cell: Int, color: Int, release: Int)]

    static func == (a: ReferenceFlow, b: ReferenceFlow) -> Bool {
        a.valves == b.valves && a.supplies == b.supplies && a.masses == b.masses && a.spilled == b.spilled
            && a.released == b.released
    }

    init(level: ColorfallCanyonsLevel) {
        var kinds: [Int] = []
        for ground in level.grounds {
            switch ground {
            case .open: kinds.append(0)
            case .rock: kinds.append(1)
            case .drain: kinds.append(2)
            }
        }
        for basin in level.basins { kinds[basin.cell] = 4 }
        for spring in level.springs { kinds[spring.cell] = 3 }
        self.kinds = kinds
        heights = level.heights
        columns = level.columns
        rows = level.rows
        flowRate = level.flowRate
        springs = level.springs.map { ($0.cell, $0.color.rawValue, $0.release) }
        valves = level.springs.map(\.open)
        supplies = level.springs.map(\.supply)
        masses = Array(repeating: [0, 0, 0], count: level.columns * level.rows)
    }

    /// The downhill neighbour by explicit coordinates: east, south, west, north; strictly lowest; rock skipped.
    func downhill(_ cell: Int) -> Int? {
        guard kinds[cell] == 0 || kinds[cell] == 3 else { return nil }
        let row: Int = cell / columns
        let column: Int = cell % columns
        let candidates: [(Int, Int)] = [(row, column + 1), (row + 1, column), (row, column - 1), (row - 1, column)]
        var best: Int = -1
        var lowest: Int = heights[cell]
        for (r, c) in candidates {
            guard r >= 0, r < rows, c >= 0, c < columns else { continue }
            let next: Int = r * columns + c
            guard kinds[next] != 1 else { continue }
            if heights[next] < lowest {
                lowest = heights[next]
                best = next
            }
        }
        return best >= 0 ? best : nil
    }

    /// Largest remainder by repeated selection of the strictly largest remainder (lower index on ties).
    static func share(_ r: Int, of m: [Int]) -> [Int] {
        let v: Int = m[0] + m[1] + m[2]
        if v <= 0 || r <= 0 { return [0, 0, 0] }
        var parts: [Int] = [0, 0, 0]
        var rems: [Int] = [0, 0, 0]
        for c in 0..<3 {
            parts[c] = (r * m[c]) / v
            rems[c] = (r * m[c]) - parts[c] * v
        }
        var given: [Bool] = [false, false, false]
        var left: Int = r - parts[0] - parts[1] - parts[2]
        while left > 0 {
            var pick: Int = -1
            for c in 0..<3 where !given[c] {
                if pick < 0 || rems[c] > rems[pick] { pick = c }
            }
            given[pick] = true
            parts[pick] += 1
            left -= 1
        }
        return parts
    }

    mutating func tick() {
        let start: [[Int]] = masses
        var next: [[Int]] = masses
        for cell in 0..<start.count {
            let v: Int = start[cell][0] + start[cell][1] + start[cell][2]
            guard v > 0, let target = downhill(cell) else { continue }
            let parts: [Int] = Self.share(Swift.min(v, flowRate), of: start[cell])
            for c in 0..<3 {
                next[cell][c] -= parts[c]
                next[target][c] += parts[c]
            }
        }
        for i in 0..<springs.count where valves[i] && supplies[i] > 0 {
            let amount: Int = Swift.min(springs[i].release, supplies[i])
            supplies[i] -= amount
            next[springs[i].cell][springs[i].color] += amount
            released[springs[i].color] += amount
        }
        for cell in 0..<next.count where kinds[cell] == 2 {
            for c in 0..<3 {
                spilled[c] += next[cell][c]
                next[cell][c] = 0
            }
        }
        masses = next
    }
}

final class ColorfallCanyonsFlowTests: XCTestCase {
    // MARK: Helpers

    /// A hand-built level on a `columns` × `rows` grid, every cell open at `height` except the overrides.
    private func make(columns: Int = 5, rows: Int = 5, height: Int = 10, heights overrides: [Int: Int] = [:],
                      rock: [Int] = [], drains: [Int] = [24], springs: [ColorfallCanyonsSpring],
                      basins: [ColorfallCanyonsBasin], flowRate: Int = 8,
                      tickLimit: Int = 600) throws -> ColorfallCanyonsLevel {
        var heights = [Int](repeating: height, count: columns * rows)
        for (cell, h) in overrides { heights[cell] = h }
        var grounds = [ColorfallCanyonsGround](repeating: .open, count: columns * rows)
        for cell in rock { grounds[cell] = .rock }
        for cell in drains { grounds[cell] = .drain }
        return try ColorfallCanyonsLevel(id: "flow", seed: 1, difficulty: 1, columns: columns, rows: rows,
                                         heights: heights, grounds: grounds, springs: springs, basins: basins,
                                         flowRate: flowRate, budget: 5, tickLimit: tickLimit)
    }

    private func spring(_ cell: Int, _ color: ColorfallCanyonsColor = .cyan, release: Int = 1, supply: Int = 999,
                        open: Bool = true) -> ColorfallCanyonsSpring {
        ColorfallCanyonsSpring(cell: cell, color: color, release: release, supply: supply, open: open)
    }

    private func basin(_ cell: Int, capacity: Int = 999, fill: Int = 1, shares: [Int] = [1_000, 0, 0],
                       tolerance: Int = 0, isProtected: Bool = false,
                       toleratedWrong: Int = 0) -> ColorfallCanyonsBasin {
        ColorfallCanyonsBasin(cell: cell, capacity: capacity, fill: fill, shares: shares, tolerance: tolerance,
                              isProtected: isProtected, toleratedWrong: toleratedWrong)
    }

    private func run(_ fluid: inout ColorfallCanyonsFluid, _ level: ColorfallCanyonsLevel, ticks: Int) {
        for _ in 0..<ticks { fluid.tick(level: level) }
    }

    /// Runs kernel and reference side by side for `ticks` ticks, comparing every field and conservation each tick.
    private func compare(_ level: ColorfallCanyonsLevel, toggled: Bool, ticks: Int, index: Int) {
        var fluid = ColorfallCanyonsFluid(level: level)
        var reference = ReferenceFlow(level: level)
        if toggled {
            for s in level.springs.indices {
                fluid.toggle(s)
                reference.valves[s].toggle()
            }
        }
        for t in 1...ticks {
            fluid.tick(level: level)
            reference.tick()
            guard fluid.masses == reference.masses, fluid.spilled == reference.spilled,
                  fluid.released == reference.released, fluid.supplies == reference.supplies,
                  fluid.valves == reference.valves, fluid.heights == level.heights, fluid.tick == t else {
                XCTFail("level \(index) toggled \(toggled): kernel differs from the reference at tick \(t)")
                return
            }
            guard fluid.isConserved() else {
                XCTFail("level \(index) toggled \(toggled): isConserved false at tick \(t)")
                return
            }
            for c in 0..<3 {
                var held: Int = fluid.spilled[c]
                for cell in 0..<level.cellCount {
                    held += fluid.masses[cell][c]
                    if fluid.masses[cell][c] < 0 { XCTFail("level \(index): negative mass at tick \(t)"); return }
                }
                if held != fluid.released[c] {
                    XCTFail("level \(index) toggled \(toggled): colour \(c) drifts at tick \(t)")
                    return
                }
            }
            for cell in 0..<level.cellCount where level.grounds[cell] != .open && fluid.volume(cell) != 0 {
                XCTFail("level \(index): rock or drain cell \(cell) holds fluid at tick \(t)")
                return
            }
        }
    }

    // MARK: 1–2. Brute-force reference and exact conservation (SC-R02G0501-003)

    func testFiveHundredSeededLevelsMatchTheReferenceWithValvesAsGiven() {
        for index in 0..<500 {
            let level = ColorfallCanyonsFixtures.randomLevel(index)
            compare(level, toggled: false, ticks: level.tickLimit, index: index)
        }
    }

    func testFiveHundredSeededLevelsMatchTheReferenceWithEveryValveToggled() {
        for index in 0..<500 {
            let level = ColorfallCanyonsFixtures.randomLevel(index)
            compare(level, toggled: true, ticks: level.tickLimit, index: index)
        }
    }

    func testFixtureChannelsMatchTheReferenceToTheirTickLimit() {
        for index in 0..<50 {
            let level = ColorfallCanyonsFixtures.fixture(index).level
            compare(level, toggled: false, ticks: level.tickLimit, index: index)
            compare(level, toggled: true, ticks: level.tickLimit, index: index)
        }
    }

    func testTheReferenceItselfIsExercised() {
        // Guards the reference against a vacuous pass: over the seeded runs fluid moves, spills and is released.
        var moved = false
        var spilled = false
        for index in 0..<100 {
            let level = ColorfallCanyonsFixtures.randomLevel(index)
            var reference = ReferenceFlow(level: level)
            for s in level.springs.indices { reference.valves[s] = true }
            for _ in 0..<level.tickLimit { reference.tick() }
            let atSprings: Int = level.springs.reduce(0) { $0 + reference.masses[$1.cell].reduce(0, +) }
            let held: Int = reference.masses.reduce(0) { $0 + $1.reduce(0, +) }
            if held > atSprings { moved = true }
            if reference.spilled.reduce(0, +) > 0 { spilled = true }
        }
        XCTAssertTrue(moved)
        XCTAssertTrue(spilled)
    }

    // MARK: 3. The largest-remainder share (FR-R02G0501-003)

    func testShareMatchesLargestRemainderOverSeededCases() {
        var random = ColorfallCanyonsRandom(seed: 3_341)
        for _ in 0..<20_000 {
            var masses: [Int] = [random.int(0...999), random.int(0...999), random.int(0...999)]
            if random.int(0...3) == 0 { masses[random.int(0...2)] = 0 }
            if random.int(0...7) == 0 { masses = [0, 0, 0]; masses[random.int(0...2)] = random.int(1...999) }
            let volume: Int = masses.reduce(0, +)
            guard volume > 0 else { continue }
            let r: Int = random.int(0...3) == 0 ? random.int(1...min(volume, 8)) : random.int(1...volume)
            let parts = ColorfallCanyonsFluid.share(r, of: masses)
            XCTAssertEqual(parts.count, 3)
            XCTAssertEqual(parts.reduce(0, +), r, "\(masses) r \(r)")
            for c in 0..<3 {
                let floor: Int = r * masses[c] / volume
                XCTAssertLessThanOrEqual(parts[c], masses[c], "\(masses) r \(r)")
                XCTAssertTrue(parts[c] == floor || parts[c] == floor + 1, "\(masses) r \(r)")
                XCTAssertGreaterThanOrEqual(parts[c], 0)
            }
            // A colour that got the extra unit never has a smaller remainder than one that did not, and on a tie it has
            // the lower index.
            for c in 0..<3 {
                for d in 0..<3 where c != d {
                    let up: Bool = parts[c] == r * masses[c] / volume + 1
                    let flat: Bool = parts[d] == r * masses[d] / volume
                    guard up && flat else { continue }
                    let rc: Int = r * masses[c] % volume
                    let rd: Int = r * masses[d] % volume
                    XCTAssertTrue(rc > rd || (rc == rd && c < d), "\(masses) r \(r)")
                }
            }
            XCTAssertEqual(parts, ReferenceFlow.share(r, of: masses), "\(masses) r \(r)")
        }
    }

    func testShareHandWorkedCasesAndZeroCases() {
        XCTAssertEqual(ColorfallCanyonsFluid.share(0, of: [3, 4, 5]), [0, 0, 0])
        XCTAssertEqual(ColorfallCanyonsFluid.share(5, of: [0, 0, 0]), [0, 0, 0])
        XCTAssertEqual(ColorfallCanyonsFluid.share(0, of: [0, 0, 0]), [0, 0, 0])
        // Equal remainders: the leftover goes to the lower colour index.
        XCTAssertEqual(ColorfallCanyonsFluid.share(1, of: [1, 1, 1]), [1, 0, 0])
        XCTAssertEqual(ColorfallCanyonsFluid.share(2, of: [1, 1, 1]), [1, 1, 0])
        XCTAssertEqual(ColorfallCanyonsFluid.share(1, of: [0, 2, 2]), [0, 1, 0])
        // Largest remainder wins over index: 3 · [1, 2, 7] / 10 = [0.3, 0.6, 2.1] → floors [0, 0, 2], one left → coral.
        XCTAssertEqual(ColorfallCanyonsFluid.share(3, of: [1, 2, 7]), [0, 1, 2])
        // r = V passes everything.
        XCTAssertEqual(ColorfallCanyonsFluid.share(12, of: [5, 0, 7]), [5, 0, 7])
        // A single colour takes it all.
        XCTAssertEqual(ColorfallCanyonsFluid.share(4, of: [0, 0, 9]), [0, 0, 4])
    }

    // MARK: 4. Pools, tie order, rock, basins, drains (FR-R02G0501-002)

    func testFlatGroundPoolsAtTheSpring() throws {
        let level = try make(springs: [spring(12, release: 3)], basins: [basin(0)])
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: 30)
        XCTAssertEqual(fluid.masses[12], [90, 0, 0])
        XCTAssertEqual(fluid.masses.reduce(0) { $0 + $1.reduce(0, +) }, 90)
        XCTAssertNil(fluid.downhill(of: 12, level: level))
        XCTAssertTrue(fluid.isConserved())
    }

    func testTieOrderIsEastSouthWestNorth() throws {
        // Centre spring 12 on a 5 × 5 grid; its neighbours are east 13, south 17, west 11, north 7.
        let order: [Int] = [13, 17, 11, 7]
        for removed in 0..<4 {
            // The earlier neighbours of the order are rock, the remaining ones are equally low.
            let rock: [Int] = Array(order[0..<removed])
            var low: [Int: Int] = [:]
            for cell in order[removed...] { low[cell] = 3 }
            let level = try make(heights: low, rock: rock, springs: [spring(12, release: 2)], basins: [basin(0)])
            var fluid = ColorfallCanyonsFluid(level: level)
            XCTAssertEqual(fluid.downhill(of: 12, level: level), order[removed])
            run(&fluid, level, ticks: 2)
            XCTAssertEqual(fluid.masses[order[removed]], [2, 0, 0], "removed \(removed)")
            XCTAssertEqual(fluid.masses[12], [2, 0, 0])
            for cell in order where cell != order[removed] { XCTAssertEqual(fluid.volume(cell), 0) }
        }
    }

    func testStrictlyLowestBeatsTheOrder() throws {
        // East is lower than the cell, north is lower still: north wins despite coming last in the order.
        let level = try make(heights: [13: 5, 17: 6, 11: 7, 7: 2], springs: [spring(12)], basins: [basin(0)])
        let fluid = ColorfallCanyonsFluid(level: level)
        XCTAssertEqual(fluid.downhill(of: 12, level: level), 7)
        // A neighbour at the same height is not downhill.
        let flat = try make(heights: [13: 10, 17: 11], springs: [spring(12)], basins: [basin(0)])
        XCTAssertNil(ColorfallCanyonsFluid(level: flat).downhill(of: 12, level: flat))
    }

    func testRockNeverReceives() throws {
        // The only lower neighbour is rock: the spring pools; rock at height 0 stays empty.
        let level = try make(heights: [13: 0], rock: [13], springs: [spring(12, release: 4)], basins: [basin(0)])
        var fluid = ColorfallCanyonsFluid(level: level)
        XCTAssertNil(fluid.downhill(of: 12, level: level))
        run(&fluid, level, ticks: 20)
        XCTAssertEqual(fluid.volume(13), 0)
        XCTAssertEqual(fluid.masses[12], [80, 0, 0])
        XCTAssertNil(fluid.downhill(of: 13, level: level))
    }

    func testBasinsHoldAndDrainsSpill() throws {
        // Spring 12 → basin 13 (height 5), whose east neighbour 14 is lower still (height 0): the basin never passes on.
        let held = try make(heights: [13: 5, 14: 0], springs: [spring(12, release: 2)], basins: [basin(13)])
        var fluid = ColorfallCanyonsFluid(level: held)
        XCTAssertNil(fluid.downhill(of: 13, level: held))
        run(&fluid, held, ticks: 10)
        XCTAssertEqual(fluid.masses[13], [18, 0, 0])
        XCTAssertEqual(fluid.masses[12], [2, 0, 0])
        XCTAssertEqual(fluid.volume(14), 0)
        // Spring 12 → drain 13 (height 0): everything that arrives is spilled in the same tick and never passed on.
        let spill = try make(heights: [13: 0], drains: [13], springs: [spring(12, .coral, release: 3)],
                             basins: [basin(0)])
        var drained = ColorfallCanyonsFluid(level: spill)
        XCTAssertNil(drained.downhill(of: 13, level: spill))
        run(&drained, spill, ticks: 10)
        XCTAssertEqual(drained.spilled, [0, 27, 0])
        XCTAssertEqual(drained.masses[13], [0, 0, 0])
        XCTAssertEqual(drained.masses[12], [0, 3, 0])
        XCTAssertEqual(drained.released, [0, 30, 0])
        XCTAssertTrue(drained.isConserved())
    }

    func testFlowRateCapsTheOutflowAndMixesShare() throws {
        // Two springs of different colours feed one open cell 13 that drains east at flow rate 3.
        // 12 (cyan) and 18 (yellow) both flow into 13; 13 flows to drain 14 (height 0).
        let level = try make(heights: [13: 5, 14: 0], drains: [14],
                             springs: [spring(12, .cyan, release: 2), spring(18, .yellow, release: 1)],
                             basins: [basin(0)], flowRate: 3)
        var fluid = ColorfallCanyonsFluid(level: level)
        var reference = ReferenceFlow(level: level)
        for _ in 0..<40 {
            fluid.tick(level: level)
            reference.tick()
            XCTAssertEqual(fluid.masses, reference.masses)
            XCTAssertEqual(fluid.spilled, reference.spilled)
            XCTAssertLessThanOrEqual(fluid.spilled.reduce(0, +), fluid.released.reduce(0, +))
            XCTAssertTrue(fluid.isConserved())
        }
        XCTAssertGreaterThan(fluid.spilled[0], 0)
        XCTAssertGreaterThan(fluid.spilled[2], 0)
    }

    // MARK: 5. Dry springs and closed valves

    func testADrySpringReleasesNothingMore() throws {
        let level = try make(springs: [spring(12, .yellow, release: 2, supply: 3)], basins: [basin(0)])
        var fluid = ColorfallCanyonsFluid(level: level)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.released, [0, 0, 2])
        XCTAssertEqual(fluid.supplies, [1])
        fluid.tick(level: level)
        XCTAssertEqual(fluid.released, [0, 0, 3])
        XCTAssertEqual(fluid.supplies, [0])
        run(&fluid, level, ticks: 20)
        XCTAssertEqual(fluid.released, [0, 0, 3])
        XCTAssertEqual(fluid.supplies, [0])
        XCTAssertEqual(fluid.masses[12], [0, 0, 3])
        XCTAssertTrue(fluid.isConserved())
    }

    func testAClosedValveReleasesNothingUntilOpened() throws {
        let level = try make(springs: [spring(12, release: 4, supply: 50, open: false)], basins: [basin(0)])
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: 15)
        XCTAssertEqual(fluid.released, [0, 0, 0])
        XCTAssertEqual(fluid.supplies, [50])
        XCTAssertEqual(fluid.volume(12), 0)
        fluid.toggle(0)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.released, [4, 0, 0])
        fluid.toggle(0)
        run(&fluid, level, ticks: 5)
        XCTAssertEqual(fluid.released, [4, 0, 0])
        XCTAssertEqual(fluid.supplies, [46])
    }

    // MARK: 6. Verdict order and boundaries

    /// Spring 12 (release 1, flow rate 8) feeds basin 13: after tick t ≥ 1 the basin holds t − 1 units.
    private func feeding(_ b: ColorfallCanyonsBasin, color: ColorfallCanyonsColor = .cyan,
                         tickLimit: Int = 600) throws -> ColorfallCanyonsLevel {
        try make(heights: [13: 0], springs: [spring(12, color, release: 1)], basins: [b], tickLimit: tickLimit)
    }

    func testNoVerdictAtTickZero() throws {
        let level = try feeding(basin(13, fill: 1), tickLimit: 1)
        XCTAssertEqual(ColorfallCanyonsFluid(level: level).verdict(level: level), .running)
    }

    func testOverflowBoundaryOneUnitEitherSide() throws {
        let capacity = 6
        let level = try feeding(basin(13, capacity: capacity, fill: capacity, shares: [0, 1_000, 0], tolerance: 0))
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: capacity + 1)
        XCTAssertEqual(fluid.volume(13), capacity)
        XCTAssertEqual(fluid.verdict(level: level), .running) // wrong mix: not won, exactly at capacity: no overflow
        fluid.tick(level: level)
        XCTAssertEqual(fluid.volume(13), capacity + 1)
        XCTAssertEqual(fluid.verdict(level: level), .failed(.overflow))
    }

    func testOverflowBeatsWin() throws {
        // fill = capacity: at capacity it is a win; one unit over, the mix still met, it is an overflow first.
        let capacity = 5
        let level = try feeding(basin(13, capacity: capacity, fill: capacity))
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: capacity)
        XCTAssertEqual(fluid.volume(13), capacity - 1)
        XCTAssertEqual(fluid.verdict(level: level), .running)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.verdict(level: level), .won)
        fluid.tick(level: level)
        XCTAssertTrue(level.basins[0].accepts(fluid.masses[13]))
        XCTAssertEqual(fluid.verdict(level: level), .failed(.overflow))
    }

    func testContaminationBoundaryOneUnitEitherSide() throws {
        let tolerated = 4
        let level = try feeding(basin(13, fill: 999, shares: [0, 1_000, 0], isProtected: true,
                                      toleratedWrong: tolerated))
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: tolerated + 1)
        XCTAssertEqual(fluid.masses[13], [tolerated, 0, 0])
        XCTAssertEqual(fluid.verdict(level: level), .running)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.verdict(level: level), .failed(.contamination))
        // The same basin unprotected never fails on colour.
        let open = try feeding(basin(13, fill: 999, shares: [0, 1_000, 0], isProtected: false,
                                     toleratedWrong: tolerated))
        var free = ColorfallCanyonsFluid(level: open)
        run(&free, open, ticks: tolerated + 2)
        XCTAssertEqual(free.verdict(level: open), .running)
    }

    func testContaminationBeatsOverflow() throws {
        // capacity = toleratedWrong = 3: the fourth unit is both an overflow and a contamination.
        let level = try feeding(basin(13, capacity: 3, fill: 3, shares: [0, 0, 1_000], isProtected: true,
                                      toleratedWrong: 3))
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: 4)
        XCTAssertEqual(fluid.verdict(level: level), .running)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.volume(13), 4)
        XCTAssertEqual(fluid.verdict(level: level), .failed(.contamination))
    }

    func testContaminationBeatsWin() throws {
        // Cyan spring 12 and yellow spring 14 both feed basin 13; yellow is wrong but within the mix tolerance.
        let b = basin(13, fill: 2, shares: [1_000, 0, 0], tolerance: 500, isProtected: true, toleratedWrong: 0)
        let level = try make(heights: [13: 0], springs: [spring(12, .cyan), spring(14, .yellow)], basins: [b])
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: 2)
        XCTAssertEqual(fluid.masses[13], [1, 0, 1])
        XCTAssertTrue(level.basins[0].accepts(fluid.masses[13]))
        XCTAssertEqual(fluid.verdict(level: level), .failed(.contamination))
        // Unprotected, the same state is a win.
        let free = basin(13, fill: 2, shares: [1_000, 0, 0], tolerance: 500, isProtected: false, toleratedWrong: 0)
        let won = try make(heights: [13: 0], springs: [spring(12, .cyan), spring(14, .yellow)], basins: [free])
        var winning = ColorfallCanyonsFluid(level: won)
        run(&winning, won, ticks: 2)
        XCTAssertEqual(winning.verdict(level: won), .won)
    }

    func testTimeAtTheTickLimitAndWinBeatsTime() throws {
        let limit = 7
        let level = try feeding(basin(13, fill: 50), tickLimit: limit)
        var fluid = ColorfallCanyonsFluid(level: level)
        run(&fluid, level, ticks: limit - 1)
        XCTAssertEqual(fluid.verdict(level: level), .running)
        fluid.tick(level: level)
        XCTAssertEqual(fluid.verdict(level: level), .failed(.time))
        // Met exactly at the limit: the win comes first.
        let exact = try feeding(basin(13, fill: limit - 1), tickLimit: limit)
        var met = ColorfallCanyonsFluid(level: exact)
        run(&met, exact, ticks: limit - 1)
        XCTAssertEqual(met.verdict(level: exact), .running)
        met.tick(level: exact)
        XCTAssertEqual(met.verdict(level: exact), .won)
        // An overflow at the limit beats time.
        let over = try feeding(basin(13, capacity: limit - 2, fill: limit - 2, shares: [0, 1_000, 0]),
                               tickLimit: limit)
        var spilledOver = ColorfallCanyonsFluid(level: over)
        run(&spilledOver, over, ticks: limit)
        XCTAssertEqual(spilledOver.verdict(level: over), .failed(.overflow))
    }

    func testMixToleranceBoundary() throws {
        // Cyan 12 (release 1) and coral 14 (release 1) feed basin 13 equally: 500/500 per mille. Wanting 600/400 with
        // tolerance 100 is met exactly at the edge; tolerance 99 is not.
        for (tolerance, expected) in [(100, ColorfallCanyonsVerdict.won), (99, .running)] {
            let b = basin(13, fill: 2, shares: [600, 400, 0], tolerance: tolerance)
            let level = try make(heights: [13: 0], springs: [spring(12, .cyan), spring(14, .coral)], basins: [b])
            var fluid = ColorfallCanyonsFluid(level: level)
            run(&fluid, level, ticks: 2)
            XCTAssertEqual(fluid.masses[13], [1, 1, 0])
            XCTAssertEqual(fluid.verdict(level: level), expected, "tolerance \(tolerance)")
        }
    }
}
