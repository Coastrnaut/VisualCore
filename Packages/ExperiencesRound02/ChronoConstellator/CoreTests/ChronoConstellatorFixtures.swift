// ChronoConstellatorFixtures — feature 351 (R02-G06-01) T-R02G0601-002 (SC-R02G0601-001 … 005). Seeded test levels shared
// by the Chrono Constellator kernel tests. Deterministic: a SplitMix64 generator, no clock. Fixture seed 2_351.
//
// `fixture(_:)` builds a level with a known winning timeline: n = 2 … 5 stars each circle a rectangle of its own in a
// vertical strip of the grid (the loops share no cell, so no collision can happen), at a win tick T = 1 … min L − 1 (plus k, below). The
// solution's phase of star i is (index of its target − T) mod L_i; star 0 also takes one hold of length k (k may be 0:
// no hold) starting at tick 1, so its solution phase is shifted forward by k and T grows by k. The level's default
// phases are the solution's phases shifted by 1 … L − 1 for every star (so the default timeline does not win at T), the
// budget is n + 1 and the tick limit is T + 0 … 40. Because T − k < min L, no earlier tick aligns every star (while it is
// held, star 0 stands T − k < L₀ steps short of its target): the first win is exactly at T.
//
// `randomLevel(_:)` builds an arbitrary valid level whose loops may share cells (rectangles anywhere), for the timeline,
// collision and replay checks; it has no known solution. `randomTimeline(_:level:random:)` adds seeded phases and holds
// within the budget.
import Foundation
@testable import ChronoConstellatorCore

/// A small deterministic generator (SplitMix64).
struct ChronoConstellatorRandom {
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

    /// A uniform integer in the non-empty half-open `range`.
    mutating func int(_ range: Range<Int>) -> Int { int(range.lowerBound...(range.upperBound - 1)) }

    /// A fair coin.
    mutating func bool() -> Bool { next() & 1 == 1 }
}

/// A fixture level with its known winning timeline.
struct ChronoConstellatorFixture {
    /// The level.
    let level: ChronoConstellatorLevel
    /// The winning start phase of every star.
    let phases: [Int]
    /// The winning holds (none or one, on star 0 from tick 1).
    let holds: [ChronoConstellatorHold]
    /// The first tick on which every star stands on its target under the winning timeline.
    let winTick: Int
}

enum ChronoConstellatorFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_351
    /// The neighbouring-input seed.
    static let neighbourSeed: UInt64 = 2_356

    /// The clockwise loop round the rectangle with top-left (`column`, `row`), `width` × `height` cells (both ≥ 2).
    static func rectangle(column: Int, row: Int, width: Int, height: Int, columns: Int) -> [Int] {
        var cells: [Int] = []
        for c in column..<(column + width) { cells.append(row * columns + c) }
        for r in (row + 1)..<(row + height) { cells.append(r * columns + column + width - 1) }
        for c in stride(from: column + width - 2, through: column, by: -1) { cells.append((row + height - 1) * columns + c) }
        for r in stride(from: row + height - 2, through: row + 1, by: -1) { cells.append(r * columns + column) }
        return cells
    }

    /// Fixture `index`: a level with a known winning timeline (see the file header).
    static func fixture(_ index: Int) -> ChronoConstellatorFixture {
        var random = ChronoConstellatorRandom(seed: seed &+ UInt64(index) &* 7_919)
        let count: Int = random.int(2...5)
        let columns: Int = min(12, max(5, 2 * count + random.int(0...2)))
        let rows: Int = random.int(5...10)
        let strip: Int = columns / count
        var loops: [[Int]] = []
        for star in 0..<count {
            let width: Int = random.int(2...max(2, min(strip, 4)))
            let height: Int = random.int(2...min(rows, 6))
            let column: Int = star * strip + random.int(0...(strip - width))
            let row: Int = random.int(0...(rows - height))
            loops.append(rectangle(column: column, row: row, width: width, height: height, columns: columns))
        }
        let shortest: Int = loops.map(\.count).min() ?? 4
        let base: Int = random.int(1...(shortest - 1))
        let k: Int = random.int(0...3)
        let winTick: Int = base + k
        var phases: [Int] = []
        var targets: [Int] = []
        for (star, loop) in loops.enumerated() {
            let targetIndex: Int = random.int(0..<loop.count)
            targets.append(loop[targetIndex])
            // Star 0 is held k ticks, so it must start k steps further on.
            let moved: Int = star == 0 ? winTick - k : winTick
            phases.append(((targetIndex - moved) % loop.count + loop.count) % loop.count)
        }
        var stars: [ChronoConstellatorStar] = []
        for (star, loop) in loops.enumerated() {
            let shift: Int = random.int(1...(loop.count - 1))
            stars.append(ChronoConstellatorStar(loop: loop, phase: (phases[star] + shift) % loop.count,
                                                target: targets[star]))
        }
        let level: ChronoConstellatorLevel
        do {
            level = try ChronoConstellatorLevel(id: "fixture-\(index)", seed: seed &+ UInt64(index), difficulty: 1,
                                                columns: columns, rows: rows, stars: stars, budget: count + 1,
                                                tickLimit: winTick + random.int(0...40), tutorial: index % 4 == 0)
        } catch {
            preconditionFailure("fixture \(index) is a valid level: \(error)")
        }
        let holds: [ChronoConstellatorHold] = k > 0 ? [ChronoConstellatorHold(star: 0, start: 1, length: k)] : []
        return ChronoConstellatorFixture(level: level, phases: phases, holds: holds, winTick: winTick)
    }

    /// The winning timeline of `fixture`, built through the timeline's own checked edits.
    static func winningTimeline(_ fixture: ChronoConstellatorFixture) -> ChronoConstellatorTimeline {
        var timeline = ChronoConstellatorTimeline(level: fixture.level)
        do {
            for star in fixture.phases.indices where timeline.phases[star] != fixture.phases[star] {
                timeline = try timeline.settingPhase(star: star, to: fixture.phases[star], level: fixture.level)
            }
            for hold in fixture.holds { timeline = try timeline.adding(hold, level: fixture.level) }
        } catch {
            preconditionFailure("the winning timeline of \(fixture.level.id) is within its budget: \(error)")
        }
        return timeline
    }

    /// An arbitrary valid level `index` whose rectangle loops may share cells.
    static func randomLevel(_ index: Int) -> ChronoConstellatorLevel {
        var random = ChronoConstellatorRandom(seed: seed &+ 100_000 &+ UInt64(index) &* 104_729)
        while true {
            let columns: Int = random.int(5...12)
            let rows: Int = random.int(5...10)
            let count: Int = random.int(2...5)
            var stars: [ChronoConstellatorStar] = []
            var used = Set<Int>()
            for _ in 0..<count {
                let width: Int = random.int(2...min(columns, 6))
                let height: Int = random.int(2...min(rows, 5))
                let loop = rectangle(column: random.int(0...(columns - width)), row: random.int(0...(rows - height)),
                                     width: width, height: height, columns: columns)
                let free: [Int] = loop.filter { !used.contains($0) }
                guard let target = free.isEmpty ? nil : free[random.int(0..<free.count)] else { continue }
                used.insert(target)
                stars.append(ChronoConstellatorStar(loop: loop, phase: random.int(0..<loop.count), target: target))
            }
            if stars.count < 2 { continue }
            if let level = try? ChronoConstellatorLevel(id: "random-\(index)", seed: UInt64(index), difficulty: 1,
                                                       columns: columns, rows: rows, stars: stars,
                                                       budget: random.int(1...20), tickLimit: random.int(1...1_200)) {
                return level
            }
        }
    }

    /// Seeded phases and holds for `level` within its budget (each edit tried once; refused edits are skipped).
    static func randomTimeline(_ level: ChronoConstellatorLevel,
                               random: inout ChronoConstellatorRandom) -> ChronoConstellatorTimeline {
        var timeline = ChronoConstellatorTimeline(level: level)
        for star in level.stars.indices where random.bool() {
            if let next = try? timeline.settingPhase(star: star, to: random.int(0..<level.stars[star].length),
                                                     level: level) { timeline = next }
        }
        for _ in 0..<random.int(0...6) {
            let hold = ChronoConstellatorHold(star: random.int(0..<level.stars.count),
                                              start: random.int(1...max(1, level.tickLimit)),
                                              length: random.int(1...60))
            if let next = try? timeline.adding(hold, level: level) { timeline = next }
        }
        return timeline
    }
}
