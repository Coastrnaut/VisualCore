// ChronoConstellatorSolverTests — feature 352 (R02-G06-02) T-R02G0602-003 (FR-R02G0602-002; SC-R02G0602-001, 002, 005;
// clarification Q2). The integer-tick phase search, seed 2_352: hand-built levels needing exactly 1, 2 and 3 edits (lower
// bound, witness phases, window, windows, blocked, work and m(T) values); a level the default timeline already wins gives
// nil; a level whose minimal windows all collide (two stars on one loop in opposite directions) gives nil; windowPhases
// changes only the off-target stars; isBlocked agrees with an independent tick-by-tick check; the witness replays through
// the play (phase actions, then one step of the tick limit) to a win; solve is deterministic. An independent brute force
// on generated band 1 … 3 levels and on seeded small random levels replays every phase-only timeline of at most m* changed
// stars (every offset) through ChronoConstellatorEvaluation to the tick limit: none with fewer than m* edits wins, and one
// with m* edits wins exactly when the solver certifies the level. On levels with m* = 2 (bands 2 and 3, hand-built and
// small random levels; on band 1, m* = 1 and a single hold is already m* edits) every single hold of starts 1 … 32 and
// lengths 1 … 32 the timeline accepts, added to every phase-only timeline of at most m* − 2 changed stars (at most m* − 1
// edits in all), never wins; the hand-built three-edit level adds the case m* = 3.
// Explicit types, plain loops; each test well under 10 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorSolverTests {
    typealias Level = ChronoConstellatorLevel
    typealias Solver = ChronoConstellatorSolver
    typealias Star = ChronoConstellatorStar

    /// The solver test seed.
    static let seed: UInt64 = 2_352

    // MARK: - Hand-built levels

    /// `count` stars (1 … 4) on disjoint 2 × 2 loops of a 12 × 5 grid, star i on the loop at column 3i with its target
    /// at loop index 0 and default phase (4 − i) mod 4, so star i alone stands on its target on the ticks T ≡ i (mod 4)
    /// (star 0 on T ≡ 0): no tick aligns two stars, m(T) ≥ count − 1 everywhere and no collision can happen.
    static func staggered(_ count: Int, tickLimit: Int = 20) throws(ChronoConstellatorError) -> Level {
        var stars: [Star] = []
        for index in 0..<count {
            let loop: [Int] = ChronoConstellatorFixtures.rectangle(column: 3 * index, row: 0, width: 2, height: 2,
                                                                   columns: 12)
            stars.append(Star(loop: loop, phase: (4 - index) % 4, target: loop[0]))
        }
        return try Level(id: "staggered-\(count)", seed: seed, difficulty: 1, columns: 12, rows: 5, stars: stars,
                         budget: 5, tickLimit: tickLimit)
    }

    /// Two stars on the same 2 × 2 loop of a 6 × 5 grid, star 1 travelling it in reverse. Star 0 circles [0, 1, 7, 6]
    /// from phase 0 with target 0; star 1 circles [6, 7, 1, 0] from phase 2 with target 7. Neither stands on its target
    /// at tick 1 and never both at once, so m* = 1. Any timeline aligning both at T has phases with an odd sum, and the
    /// two stars then meet on every tick of the other parity than T: each minimal window (T ≥ 2) first collides on tick
    /// 1 (T even) or 2 (T odd), before T.
    static func opposed() throws(ChronoConstellatorError) -> Level {
        let loop: [Int] = ChronoConstellatorFixtures.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 6)
        let reversed: [Int] = Array(loop.reversed())
        let stars: [Star] = [Star(loop: loop, phase: 0, target: loop[0]), Star(loop: reversed, phase: 2, target: reversed[1])]
        return try Level(id: "opposed", seed: seed, difficulty: 1, columns: 6, rows: 5, stars: stars, budget: 5,
                         tickLimit: 24)
    }

    // MARK: - Independent helpers

    /// The cell of star `star` at `tick` with start phase `phase` and an optional `hold`, computed here.
    static func cell(_ level: Level, star: Int, phase: Int, tick: Int, hold: ChronoConstellatorHold?) -> Int {
        let loop: [Int] = level.stars[star].loop
        var held: Int = 0
        if let hold, hold.star == star, hold.start <= tick { held = min(hold.end, tick) - hold.start + 1 }
        let step: Int = phase + tick - held
        return loop[((step % loop.count) + loop.count) % loop.count]
    }

    /// m(T) computed here: the stars not on their target at `tick` under the default phases.
    static func offTarget(_ level: Level, at tick: Int) -> [Int] {
        var stars: [Int] = []
        for index in level.stars.indices
        where cell(level, star: index, phase: level.stars[index].phase, tick: tick, hold: nil) != level.stars[index].target {
            stars.append(index)
        }
        return stars
    }

    /// The first tick on which `phases` and `hold` win, replayed through ChronoConstellatorEvaluation to the tick limit,
    /// or nil when the play fails first.
    static func winTick(_ level: Level, phases: [Int], hold: ChronoConstellatorHold? = nil) -> Int? {
        var positions: [Int] = Array(repeating: 0, count: level.stars.count)
        for tick in 1...level.tickLimit {
            for star in level.stars.indices {
                positions[star] = cell(level, star: star, phase: phases[star], tick: tick, hold: hold)
            }
            switch ChronoConstellatorEvaluation.verdict(positions: positions, tick: tick, level: level) {
            case .running: continue
            case .won: return tick
            case .failed: return nil
            }
        }
        return nil
    }

    /// The first tick 1 … `last` on which two stars with `phases` share a cell, computed here.
    static func firstCollision(_ level: Level, phases: [Int], through last: Int) -> Int? {
        if last < 1 { return nil }
        for tick in 1...last {
            var seen = Set<Int>()
            for star in level.stars.indices {
                let here: Int = cell(level, star: star, phase: phases[star], tick: tick, hold: nil)
                if seen.contains(here) { return tick }
                seen.insert(here)
            }
        }
        return nil
    }

    /// The phase that puts star `star` on its target at `tick`, computed here.
    static func aligningPhase(_ level: Level, star: Int, tick: Int) -> Int {
        let loop: [Int] = level.stars[star].loop
        var index: Int = 0
        for k in loop.indices where loop[k] == level.stars[star].target { index = k }
        return ((index - tick) % loop.count + loop.count) % loop.count
    }

    /// Every phase vector of `level` with at most `limit` stars changed from their default (every other offset), paired
    /// with its number of changed stars.
    static func phaseTimelines(_ level: Level, changing limit: Int) -> [([Int], Int)] {
        var result: [([Int], Int)] = [(level.stars.map(\.phase), 0)]
        for star in level.stars.indices {
            var grown: [([Int], Int)] = []
            for (phases, edits) in result where edits < limit {
                for offset in 0..<level.stars[star].length where offset != level.stars[star].phase {
                    var next: [Int] = phases
                    next[star] = offset
                    grown.append((next, edits + 1))
                }
            }
            result.append(contentsOf: grown)
        }
        return result
    }

    /// The independently computed facts of a level: m*, the windows, the blocked windows and the work.
    struct Search {
        let lowest: Int
        let windows: [Int]
        let blocked: [Int]
        let work: Int
    }

    static func search(_ level: Level) -> Search {
        var lowest: Int = Int.max
        for tick in 1...level.tickLimit { lowest = min(lowest, offTarget(level, at: tick).count) }
        var windows: [Int] = []
        var blocked: [Int] = []
        var work: Int = level.tickLimit
        for tick in 1...level.tickLimit where offTarget(level, at: tick).count == lowest {
            windows.append(tick)
            work += tick
            var phases: [Int] = level.stars.map(\.phase)
            for star in offTarget(level, at: tick) { phases[star] = aligningPhase(level, star: star, tick: tick) }
            if firstCollision(level, phases: phases, through: tick) != nil { blocked.append(tick) }
        }
        return Search(lowest: lowest, windows: windows, blocked: blocked, work: work)
    }

    /// The brute-force check of `level` over phase-only timelines; returns the independent m*.
    @discardableResult
    static func bruteForcePhases(_ level: Level) -> Int {
        let facts: Search = search(level)
        let solution: ChronoConstellatorSolution? = Solver.solve(level)
        if facts.lowest == 0 {
            #expect(solution == nil, "\(level.id): the default timeline aligns every star")
            return 0
        }
        let certified: Bool = facts.blocked.count < facts.windows.count
        #expect((solution != nil) == certified, "\(level.id): certified iff some window is unblocked")
        if let solution {
            #expect(solution.lowerBound == facts.lowest, "\(level.id)")
            #expect(solution.window == facts.windows.first { !facts.blocked.contains($0) }, "\(level.id)")
            #expect(solution.windows == facts.windows.count, "\(level.id)")
            #expect(solution.blocked == facts.blocked.count, "\(level.id)")
            #expect(solution.work == facts.work, "\(level.id)")
        }
        var winsAtBound: Int = 0
        for (phases, edits) in phaseTimelines(level, changing: facts.lowest) {
            if edits == facts.lowest && winsAtBound > 0 { continue }
            guard winTick(level, phases: phases) != nil else { continue }
            #expect(edits == facts.lowest, "\(level.id): \(phases) wins with \(edits) < m* = \(facts.lowest) edits")
            winsAtBound += 1
        }
        #expect((winsAtBound > 0) == certified, "\(level.id): a phase-only win with m* edits iff certified")
        return facts.lowest
    }

    /// The brute-force check of `level` over every single hold (start 1 … 32, length 1 … 32, accepted by the timeline)
    /// added to every phase-only timeline of at most m* − 2 changed stars, so at most m* − 1 edits in all: none wins.
    /// Returns the number of timelines checked (none when m* < 2: one edit is then already m*).
    @discardableResult
    static func bruteForceHolds(_ level: Level, lowest: Int) -> Int {
        guard lowest >= 2 else { return 0 }
        let base = ChronoConstellatorTimeline(level: level)
        var checked: Int = 0
        for (phases, edits) in phaseTimelines(level, changing: lowest - 2) {
            for star in level.stars.indices {
                for start in 1...32 {
                    for length in 1...32 {
                        let hold = ChronoConstellatorHold(star: star, start: start, length: length)
                        guard (try? base.adding(hold, level: level)) != nil else { continue }
                        checked += 1
                        if let tick = winTick(level, phases: phases, hold: hold) {
                            Issue.record("\(level.id): \(phases) with \(hold) (\(edits + 1) < m* = \(lowest) edits) wins at \(tick)")
                        }
                    }
                }
            }
        }
        #expect(checked > 0, "\(level.id): some hold was checked")
        return checked
    }

    /// Generated levels of manifest entries `numbers`.
    static func generated(_ numbers: [Int]) throws -> [Level] {
        var levels: [Level] = []
        for number in numbers {
            levels.append(try ChronoConstellatorGenerator.generate(ChronoConstellatorManifest.entries[number - 1]).level)
        }
        return levels
    }

    /// Small random levels (seed 2_352): 2 … 3 stars on rectangles of 2 … 3 × 2 … 3 cells anywhere on a 6 × 5 grid (loops
    /// may share cells), random phases, tick limit 12 … 120.
    static func smallRandomLevels(_ count: Int) -> [Level] {
        var random = ChronoConstellatorRandom(seed: seed)
        var levels: [Level] = []
        while levels.count < count {
            let stars: Int = random.int(2...3)
            var built: [Star] = []
            var used = Set<Int>()
            for _ in 0..<stars {
                let width: Int = random.int(2...3)
                let height: Int = random.int(2...3)
                var loop: [Int] = ChronoConstellatorFixtures.rectangle(column: random.int(0...(6 - width)),
                                                                       row: random.int(0...(5 - height)), width: width,
                                                                       height: height, columns: 6)
                if random.bool() { loop.reverse() }
                let free: [Int] = loop.filter { !used.contains($0) }
                if free.isEmpty { continue }
                let target: Int = free[random.int(0..<free.count)]
                used.insert(target)
                built.append(Star(loop: loop, phase: random.int(0..<loop.count), target: target))
            }
            if built.count < 2 { continue }
            if let level = try? Level(id: "small-\(levels.count)", seed: seed, difficulty: 1, columns: 6, rows: 5,
                                      stars: built, budget: 8, tickLimit: random.int(12...120)) {
                levels.append(level)
            }
        }
        return levels
    }

    // MARK: - Hand-built levels

    @Test func handBuiltLevelsNeedExactlyOneTwoAndThreeEdits() throws {
        // Two stars: star 1 aligned on T ≡ 1, star 0 on T ≡ 0 (mod 4); m* = 1 on T ≡ 0, 1.
        let two: Level = try Self.staggered(2)
        #expect(Solver.misaligned(two, at: 1) == 1)
        #expect(Solver.misaligned(two, at: 2) == 2)
        #expect(Solver.misaligned(two, at: 3) == 2)
        #expect(Solver.misaligned(two, at: 4) == 1)
        let first: ChronoConstellatorSolution = try #require(Solver.solve(two))
        #expect(first.lowerBound == 1)
        #expect(first.window == 1)
        #expect(first.phases == [3, 3])
        #expect(first.windows == 10)
        #expect(first.blocked == 0)
        // 20 ticks scanned plus the windows 1, 4, 5, 8, 9, 12, 13, 16, 17, 20.
        #expect(first.work == 20 + 105)

        // Three stars: T ≡ 3 aligns none (m = 3); every other tick aligns one (m* = 2).
        let three: Level = try Self.staggered(3)
        #expect(Solver.misaligned(three, at: 1) == 2)
        #expect(Solver.misaligned(three, at: 2) == 2)
        #expect(Solver.misaligned(three, at: 3) == 3)
        #expect(Solver.misaligned(three, at: 4) == 2)
        let second: ChronoConstellatorSolution = try #require(Solver.solve(three))
        #expect(second.lowerBound == 2)
        #expect(second.window == 1)
        #expect(second.phases == [3, 3, 3])
        #expect(second.windows == 15)
        #expect(second.blocked == 0)

        // Four stars: every tick aligns exactly one (m* = 3 everywhere).
        let four: Level = try Self.staggered(4)
        for tick in 1...20 { #expect(Solver.misaligned(four, at: tick) == 3) }
        let third: ChronoConstellatorSolution = try #require(Solver.solve(four))
        #expect(third.lowerBound == 3)
        #expect(third.window == 1)
        #expect(third.phases == [3, 3, 3, 3])
        #expect(third.windows == 20)
        #expect(third.blocked == 0)
        #expect(third.work == 20 + 210)

        // The exact counts, by brute force.
        #expect(Self.bruteForcePhases(two) == 1)
        #expect(Self.bruteForcePhases(three) == 2)
        #expect(Self.bruteForcePhases(four) == 3)
    }

    @Test func aLevelTheDefaultTimelineAlreadyWinsGivesNil() throws {
        // Both stars stand on their targets on T ≡ 0 (mod 4).
        var stars: [Star] = []
        for index in 0..<2 {
            let loop: [Int] = ChronoConstellatorFixtures.rectangle(column: 3 * index, row: 0, width: 2, height: 2,
                                                                   columns: 6)
            stars.append(Star(loop: loop, phase: 0, target: loop[0]))
        }
        let level = try Level(id: "aligned", seed: Self.seed, difficulty: 1, columns: 6, rows: 5, stars: stars,
                              budget: 3, tickLimit: 10)
        #expect(Solver.misaligned(level, at: 4) == 0)
        #expect(Solver.misaligned(level, at: 1) == 2)
        #expect(Solver.solve(level) == nil)
        #expect(Self.winTick(level, phases: [0, 0]) == 4)

        // Even when the default timeline aligns every star only on the very last tick.
        let late = try Level(id: "aligned-late", seed: Self.seed, difficulty: 1, columns: 6, rows: 5, stars: stars,
                             budget: 3, tickLimit: 4)
        #expect(Solver.solve(late) == nil)
    }

    @Test func aLevelWhoseMinimalWindowsAllCollideGivesNil() throws {
        let level: Level = try Self.opposed()
        #expect(Solver.misaligned(level, at: 1) == 2)
        var windows: Int = 0
        for tick in 1...level.tickLimit {
            let m: Int = Solver.misaligned(level, at: tick)
            #expect(m >= 1)
            guard m == 1 else { continue }
            windows += 1
            #expect(tick >= 2)
            #expect(Solver.isBlocked(level, window: tick), "window \(tick)")
            let phases: [Int] = Solver.windowPhases(level, window: tick)
            #expect(Self.firstCollision(level, phases: phases, through: tick) == (tick % 2 == 0 ? 1 : 2),
                    "window \(tick)")
        }
        #expect(windows == 12)
        #expect(Solver.solve(level) == nil)
        // No timeline of one phase change wins; two changes win at tick 1 (before the stars meet at tick 2), which is
        // why the solver refuses to certify this level rather than claim m* = 1.
        for (phases, edits) in Self.phaseTimelines(level, changing: 1) where edits <= 1 {
            #expect(Self.winTick(level, phases: phases) == nil, "\(phases)")
        }
        #expect(Self.winTick(level, phases: [3, 0]) == 1)
    }

    // MARK: - Window phases and blocking

    @Test func windowPhasesChangeOnlyTheOffTargetStars() {
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 1)
        for index in 0..<40 {
            let level: Level = ChronoConstellatorFixtures.randomLevel(index)
            for _ in 0..<8 {
                let tick: Int = random.int(1...level.tickLimit)
                let phases: [Int] = Solver.windowPhases(level, window: tick)
                let off: [Int] = Self.offTarget(level, at: tick)
                #expect(Solver.misaligned(level, at: tick) == off.count)
                for star in level.stars.indices {
                    if off.contains(star) {
                        #expect(phases[star] != level.stars[star].phase)
                        #expect(phases[star] == Self.aligningPhase(level, star: star, tick: tick))
                    } else {
                        #expect(phases[star] == level.stars[star].phase)
                    }
                    // Every star stands on its target at the window tick.
                    #expect(Self.cell(level, star: star, phase: phases[star], tick: tick, hold: nil)
                            == level.stars[star].target)
                }
            }
        }
    }

    @Test func isBlockedAgreesWithATickByTickCheck() {
        var random = ChronoConstellatorRandom(seed: Self.seed &+ 2)
        var blocked: Int = 0
        var open: Int = 0
        let levels: [Level] = (0..<40).map { ChronoConstellatorFixtures.randomLevel($0) } + Self.smallRandomLevels(40)
        for level in levels {
            for _ in 0..<6 {
                let tick: Int = random.int(1...min(level.tickLimit, 240))
                var phases: [Int] = level.stars.map(\.phase)
                for star in Self.offTarget(level, at: tick) {
                    phases[star] = Self.aligningPhase(level, star: star, tick: tick)
                }
                let expected: Bool = Self.firstCollision(level, phases: phases, through: tick) != nil
                #expect(Solver.isBlocked(level, window: tick) == expected, "\(level.id) window \(tick)")
                if expected { blocked += 1 } else { open += 1 }
            }
        }
        // Both outcomes are exercised.
        #expect(blocked > 0)
        #expect(open > 0)
    }

    // MARK: - The witness through the play

    @Test func theWitnessReplaysThroughThePlayToAWin() throws {
        var levels: [Level] = [try Self.staggered(2), try Self.staggered(3), try Self.staggered(4)]
        levels += try Self.generated([1, 2, 3, 21, 22, 41, 42])
        for level in levels {
            let solution: ChronoConstellatorSolution = try #require(Solver.solve(level))
            let witness: ChronoConstellatorTimeline = try #require(ChronoConstellatorGenerator.timeline(level,
                                                                                                        solution: solution))
            #expect(witness.editsInUse(level: level) == solution.lowerBound, "\(level.id)")
            #expect(witness.holds.isEmpty)
            let win: Int = try #require(ChronoConstellatorGenerator.winTick(level, timeline: witness), "\(level.id)")
            #expect(win <= solution.window, "\(level.id)")
            #expect(Self.winTick(level, phases: witness.phases) == win, "\(level.id)")

            var play = ChronoConstellatorPlay(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for star in level.stars.indices where witness.phases[star] != level.stars[star].phase {
                try play.apply(.phase(star, witness.phases[star]), expecting: play.fingerprint)
            }
            #expect(play.spent == solution.lowerBound)
            try play.apply(.step(level.tickLimit), expecting: play.fingerprint)
            #expect(play.stage == .won, "\(level.id)")
            #expect(play.tick == win, "\(level.id)")
            #expect(play.failure == nil)
        }
    }

    @Test func solveIsDeterministic() throws {
        var levels: [Level] = [try Self.staggered(3), try Self.opposed()]
        levels += Self.smallRandomLevels(20)
        for index in 0..<20 { levels.append(ChronoConstellatorFixtures.randomLevel(index)) }
        for level in levels {
            #expect(Solver.solve(level) == Solver.solve(level), "\(level.id)")
            #expect(Solver.windowPhases(level, window: 1) == Solver.windowPhases(level, window: 1))
        }
        // Rebuilt from the same values, the same answer.
        let again: Level = try Self.staggered(3)
        #expect(Solver.solve(again) == Solver.solve(try Self.staggered(3)))
    }

    // MARK: - Brute force

    @Test func bruteForceOnBandOneLevels() throws {
        for level in try Self.generated([1, 2, 3, 4, 5, 6]) {
            #expect(Self.bruteForcePhases(level) == 1, "\(level.id)")
        }
    }

    @Test func bruteForceOnBandTwoLevels() throws {
        for level in try Self.generated([21, 22, 23, 24]) {
            #expect(Self.bruteForcePhases(level) == 2, "\(level.id)")
        }
    }

    @Test func bruteForceOnBandThreeLevels() throws {
        for level in try Self.generated([41, 42, 43]) {
            #expect(Self.bruteForcePhases(level) == 2, "\(level.id)")
        }
    }

    @Test func bruteForceOnRawCandidates() throws {
        // Candidates as drawn, before the generator's filter (some uncertified, some m* = 0).
        var checked: Int = 0
        for number in [1, 21, 41] {
            let entry: ChronoConstellatorManifestEntry = ChronoConstellatorManifest.entries[number - 1]
            for index in 0..<6 {
                guard let level = ChronoConstellatorGenerator.candidate(entry, index: index) else { continue }
                Self.bruteForcePhases(level)
                checked += 1
            }
        }
        #expect(checked >= 12)
    }

    @Test func bruteForceOnSmallRandomLevels() {
        var certified: Int = 0
        var refused: Int = 0
        for level in Self.smallRandomLevels(60) {
            let lowest: Int = Self.bruteForcePhases(level)
            if lowest > 0 && Solver.solve(level) != nil { certified += 1 } else { refused += 1 }
        }
        #expect(certified > 0)
        #expect(refused > 0)
    }

    @Test func bruteForceHoldsOnBandTwoLevels() throws {
        for level in try Self.generated([21, 22, 23, 24]) {
            let lowest: Int = try #require(Solver.solve(level)).lowerBound
            #expect(lowest == 2)
            #expect(Self.bruteForceHolds(level, lowest: lowest) >= 3 * 1_024, "\(level.id)")
        }
    }

    @Test func bruteForceHoldsOnBandThreeLevels() throws {
        for level in try Self.generated([41, 42]) {
            let lowest: Int = try #require(Solver.solve(level)).lowerBound
            #expect(Self.bruteForceHolds(level, lowest: lowest) >= 3 * 1_024, "\(level.id)")
        }
    }

    @Test func bruteForceHoldsOnHandBuiltAndSmallLevels() throws {
        // m* = 2 and 3: one hold alone, and one hold with every single phase change.
        #expect(Self.bruteForceHolds(try Self.staggered(3), lowest: 2) > 0)
        #expect(Self.bruteForceHolds(try Self.staggered(4), lowest: 3) > 0)
        var checked: Int = 0
        for level in Self.smallRandomLevels(30) {
            guard let solution = Solver.solve(level), solution.lowerBound <= 2 else { continue }
            checked += Self.bruteForceHolds(level, lowest: solution.lowerBound)
        }
        #expect(checked > 0)
    }
}
