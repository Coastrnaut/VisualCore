// ChronoConstellatorTimelineTests — feature 351 (R02-G06-01) T-R02G0601-003 (FR-R02G0601-002 … 005; SC-R02G0601-001,
// 003; clarifications Q2 … Q4). The timeline against an independent step-by-step reference written here (each star
// advances one loop step per tick unless a hold covers that tick) on 500 seeded random levels and timelines run to their
// tick limit, in four groups; `held(star:through:)` counted exactly; the edits in use equal the changed phases plus the
// holds; the refusals of settingPhase, adding and releasing (range, same-phase, overlap including touching holds,
// no-hold, budget, a hold past the tick limit) leave the timeline unchanged; the evaluation order collision, then win,
// then time, with the lowest pair and the cell named; two stars swapping neighbouring cells are no collision; nothing is
// judged at tick 0; the timeline fingerprint is stable and changes with any phase or hold. Seeds 2_351 and 2_356.
// Explicit types, plain loops, no sleeps; each test well under 10 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

/// An independent step-by-step model of clarification Q2; it never calls the timeline's position or held functions.
private struct ReferenceSky {
    /// The loop index of every star.
    var indices: [Int]
    /// The held ticks of every star, indexed by tick (0 … tick limit).
    let heldTicks: [[Bool]]
    /// The loops.
    let loops: [[Int]]
    /// The current tick.
    var tick: Int = 0

    init(level: ChronoConstellatorLevel, phases: [Int], holds: [ChronoConstellatorHold]) {
        indices = phases
        loops = level.stars.map(\.loop)
        var heldTicks: [[Bool]] = Array(repeating: Array(repeating: false, count: level.tickLimit + 1),
                                        count: level.stars.count)
        for hold in holds {
            for t in hold.start..<(hold.start + hold.length) { heldTicks[hold.star][t] = true }
        }
        self.heldTicks = heldTicks
    }

    /// The cell of every star now.
    var cells: [Int] {
        var result: [Int] = []
        for star in loops.indices { result.append(loops[star][indices[star]]) }
        return result
    }

    /// Advances one tick: every star not held on the new tick moves one loop step.
    mutating func step() {
        tick += 1
        for star in loops.indices where !heldTicks[star][tick] {
            indices[star] = (indices[star] + 1) % loops[star].count
        }
    }
}

@Suite struct ChronoConstellatorTimelineTests {
    /// The number of random levels per group, and the groups.
    static let groupSize: Int = 125
    static let groups: [Int] = [0, 1, 2, 3]

    /// A level on a 6 × 5 grid built from `stars`.
    static func level(_ stars: [ChronoConstellatorStar], budget: Int = 3,
                      tickLimit: Int = 100) throws(ChronoConstellatorError) -> ChronoConstellatorLevel {
        try ChronoConstellatorLevel(id: "hand", seed: 2_351, difficulty: 1, columns: 6, rows: 5, stars: stars,
                                    budget: budget, tickLimit: tickLimit)
    }

    /// The clockwise 2 × 2 loop with top-left (`column`, `row`) on the 6-column grid.
    static func square(_ column: Int, _ row: Int) -> [Int] {
        ChronoConstellatorFixtures.rectangle(column: column, row: row, width: 2, height: 2, columns: 6)
    }

    /// Star 0 on [0, 1, 7, 6] and star 1 on the 8-cell loop round (3, 1) … (5, 3).
    static func sample(budget: Int = 3, tickLimit: Int = 100) throws(ChronoConstellatorError) -> ChronoConstellatorLevel {
        let a: [Int] = square(0, 0)
        let b: [Int] = ChronoConstellatorFixtures.rectangle(column: 3, row: 1, width: 3, height: 3, columns: 6)
        return try level([ChronoConstellatorStar(loop: a, phase: 0, target: a[2]),
                          ChronoConstellatorStar(loop: b, phase: 1, target: b[5])], budget: budget, tickLimit: tickLimit)
    }

    /// The refusal `edit` throws, or nil when it is accepted.
    static func refusal(_ edit: () throws(ChronoConstellatorError) -> ChronoConstellatorTimeline) -> ChronoConstellatorError? {
        do {
            _ = try edit()
            return nil
        } catch {
            return error
        }
    }

    // MARK: Positions against the reference

    @Test(arguments: groups)
    func positionsEqualTheStepByStepReference(group: Int) {
        var compared: Int = 0
        for index in (group * Self.groupSize)..<((group + 1) * Self.groupSize) {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var random = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed &+ UInt64(index))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
            var reference = ReferenceSky(level: level, phases: timeline.phases, holds: timeline.holds)
            #expect(timeline.positions(at: 0, level: level) == reference.cells, "level \(index) tick 0")
            for tick in 1...level.tickLimit {
                reference.step()
                let cells: [Int] = timeline.positions(at: tick, level: level)
                if cells != reference.cells {
                    Issue.record("level \(index) tick \(tick): \(cells) != \(reference.cells)")
                    break
                }
                for star in level.stars.indices
                where timeline.isHeld(star: star, on: tick) != reference.heldTicks[star][tick] {
                    Issue.record("level \(index) star \(star) tick \(tick): isHeld differs")
                }
                compared += 1
            }
        }
        #expect(compared > 0)
    }

    @Test func neighbourSeedTimelinesAlsoEqualTheReference() {
        for index in 0..<40 {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var random = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.neighbourSeed &+ UInt64(index))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
            var reference = ReferenceSky(level: level, phases: timeline.phases, holds: timeline.holds)
            for tick in 1...level.tickLimit {
                reference.step()
                if timeline.positions(at: tick, level: level) != reference.cells {
                    Issue.record("neighbour level \(index) tick \(tick)")
                    break
                }
            }
        }
    }

    @Test func heldCountsExactly() {
        var holdsSeen: Int = 0
        for index in 0..<120 {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var random = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed &+ UInt64(index))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
            holdsSeen += timeline.holds.count
            let reference = ReferenceSky(level: level, phases: timeline.phases, holds: timeline.holds)
            for star in level.stars.indices {
                var count: Int = 0
                #expect(timeline.held(star: star, through: 0) == 0)
                for tick in 1...level.tickLimit {
                    if reference.heldTicks[star][tick] { count += 1 }
                    if timeline.held(star: star, through: tick) != count {
                        Issue.record("level \(index) star \(star) tick \(tick): \(timeline.held(star: star, through: tick)) != \(count)")
                        break
                    }
                }
            }
        }
        #expect(holdsSeen > 50)
    }

    @Test func heldCountsAHandBuiltTimeline() throws {
        let level: ChronoConstellatorLevel = try Self.sample()
        var timeline = ChronoConstellatorTimeline(level: level)
        timeline = try timeline.adding(ChronoConstellatorHold(star: 0, start: 3, length: 4), level: level)
        timeline = try timeline.adding(ChronoConstellatorHold(star: 0, start: 10, length: 2), level: level)
        let expected: [Int] = [0, 0, 0, 1, 2, 3, 4, 4, 4, 4, 5, 6, 6, 6]
        for tick in expected.indices { #expect(timeline.held(star: 0, through: tick) == expected[tick], "tick \(tick)") }
        #expect(timeline.held(star: 1, through: 13) == 0)
        // Star 0 at [0, 1, 7, 6]: moves on ticks 1, 2, 7, 8, 9, 12, 13.
        let cells: [Int] = [0, 1, 7, 7, 7, 7, 7, 6, 0, 1, 1, 1, 7, 6]
        for tick in cells.indices { #expect(timeline.position(star: 0, at: tick, level: level) == cells[tick], "tick \(tick)") }
    }

    // MARK: Edits in use

    @Test func editsInUseEqualChangedPhasesPlusHolds() {
        for index in 0..<300 {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var random = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.neighbourSeed &+ UInt64(index))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
            var changed: Int = 0
            for star in level.stars.indices where timeline.phases[star] != level.stars[star].phase { changed += 1 }
            #expect(timeline.editsInUse(level: level) == changed + timeline.holds.count, "level \(index)")
            #expect(timeline.editsInUse(level: level) <= level.budget, "level \(index)")
            #expect(timeline.holds == timeline.holds.sorted(), "level \(index)")
        }
    }

    @Test func restoringADefaultPhaseAndReleasingLowerTheEdits() throws {
        let level: ChronoConstellatorLevel = try Self.sample(budget: 2)
        let start = ChronoConstellatorTimeline(level: level)
        #expect(start.editsInUse(level: level) == 0)
        let phased: ChronoConstellatorTimeline = try start.settingPhase(star: 0, to: 1, level: level)
        #expect(phased.editsInUse(level: level) == 1)
        // A second change of the same star stays one edit.
        let rephased: ChronoConstellatorTimeline = try phased.settingPhase(star: 0, to: 2, level: level)
        #expect(rephased.editsInUse(level: level) == 1)
        let held: ChronoConstellatorTimeline = try rephased.adding(ChronoConstellatorHold(star: 1, start: 5, length: 3),
                                                                   level: level)
        #expect(held.editsInUse(level: level) == 2)
        let restored: ChronoConstellatorTimeline = try held.settingPhase(star: 0, to: 0, level: level)
        #expect(restored.editsInUse(level: level) == 1)
        let released: ChronoConstellatorTimeline = try restored.releasing(star: 1, start: 5, level: level)
        #expect(released.editsInUse(level: level) == 0)
        #expect(released == start)
        #expect(released.fingerprint == start.fingerprint)
    }

    // MARK: Refusals

    @Test func settingPhaseRefusals() throws {
        let level: ChronoConstellatorLevel = try Self.sample(budget: 1)
        let timeline = ChronoConstellatorTimeline(level: level)
        let before: String = timeline.fingerprint
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: -1, to: 0, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 2, to: 0, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 0, to: -1, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 0, to: 4, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 1, to: 8, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 0, to: 0, level: level) } == .action("same-phase"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 1, to: 1, level: level) } == .action("same-phase"))
        // Edges accepted.
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 0, to: 3, level: level) } == nil)
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.settingPhase(star: 1, to: 7, level: level) } == nil)
        // Budget 1: one changed phase fits, a second star's change does not, nor does a hold.
        let one: ChronoConstellatorTimeline = try timeline.settingPhase(star: 0, to: 2, level: level)
        let oneBefore: String = one.fingerprint
        let budget: ChronoConstellatorError? = Self.refusal { () throws(ChronoConstellatorError) in
            try one.settingPhase(star: 1, to: 0, level: level)
        }
        #expect(budget == .budget)
        #expect(budget?.reasonCode == "r02-g06.budget")
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try one.adding(ChronoConstellatorHold(star: 1, start: 1, length: 1), level: level) } == .budget)
        #expect(one.fingerprint == oneBefore)
        #expect(one.phases == [2, 1])
        #expect(one.holds.isEmpty)
        #expect(timeline.fingerprint == before)
        #expect(timeline == ChronoConstellatorTimeline(level: level))
    }

    @Test func addingRefusalsIncludingTouchingHolds() throws {
        let level: ChronoConstellatorLevel = try Self.sample(budget: 5, tickLimit: 100)
        let timeline: ChronoConstellatorTimeline = try ChronoConstellatorTimeline(level: level)
            .adding(ChronoConstellatorHold(star: 0, start: 10, length: 5), level: level) // ticks 10 … 14
        let before: ChronoConstellatorTimeline = timeline
        func add(_ star: Int, _ start: Int, _ length: Int) -> ChronoConstellatorError? {
            Self.refusal { () throws(ChronoConstellatorError) in
                try timeline.adding(ChronoConstellatorHold(star: star, start: start, length: length), level: level)
            }
        }
        // Range: star, start, length and a hold past the tick limit.
        #expect(add(-1, 1, 1) == .action("range"))
        #expect(add(2, 1, 1) == .action("range"))
        #expect(add(1, 0, 1) == .action("range"))
        #expect(add(1, -3, 2) == .action("range"))
        #expect(add(1, 1, 0) == .action("range"))
        #expect(add(1, 1, 61) == .action("range"))
        #expect(add(1, 100, 2) == .action("range"))
        #expect(add(1, 42, 60) == .action("range"))
        #expect(add(1, 101, 1) == .action("range"))
        #expect(add(1, 100, 1) == nil)
        #expect(add(1, 41, 60) == nil)
        #expect(add(1, 1, 60) == nil)
        // Overlap and touching (no tick of gap) on the same star.
        #expect(add(0, 10, 5) == .action("overlap"))
        #expect(add(0, 12, 1) == .action("overlap"))
        #expect(add(0, 14, 3) == .action("overlap"))
        #expect(add(0, 8, 10) == .action("overlap"))
        #expect(add(0, 15, 1) == .action("overlap"))
        #expect(add(0, 5, 5) == .action("overlap"))
        #expect(add(0, 9, 1) == .action("overlap"))
        // One tick of gap is accepted; another star's holds never overlap.
        #expect(add(0, 16, 1) == nil)
        #expect(add(0, 4, 5) == nil)
        #expect(add(0, 1, 8) == nil)
        #expect(add(1, 10, 5) == nil)
        #expect(add(1, 9, 7) == nil)
        #expect(timeline == before)
        #expect(timeline.holds == [ChronoConstellatorHold(star: 0, start: 10, length: 5)])
        #expect(timeline.fingerprint == before.fingerprint)
    }

    @Test func aHoldPastTheTickLimitIsRefused() throws {
        for limit in [1, 2, 7, 60, 1_200] {
            let level: ChronoConstellatorLevel = try Self.sample(tickLimit: limit)
            let timeline = ChronoConstellatorTimeline(level: level)
            #expect(Self.refusal { () throws(ChronoConstellatorError) in
                try timeline.adding(ChronoConstellatorHold(star: 0, start: limit, length: 2), level: level) } == .action("range"))
            #expect(Self.refusal { () throws(ChronoConstellatorError) in
                try timeline.adding(ChronoConstellatorHold(star: 0, start: limit + 1, length: 1), level: level) } == .action("range"))
            #expect(Self.refusal { () throws(ChronoConstellatorError) in
                try timeline.adding(ChronoConstellatorHold(star: 0, start: limit, length: 1), level: level) } == nil)
            let longest: Int = min(60, limit)
            #expect(Self.refusal { () throws(ChronoConstellatorError) in
                try timeline.adding(ChronoConstellatorHold(star: 1, start: limit - longest + 1, length: longest), level: level) } == nil)
        }
    }

    @Test func releasingRefusals() throws {
        let level: ChronoConstellatorLevel = try Self.sample()
        let timeline: ChronoConstellatorTimeline = try ChronoConstellatorTimeline(level: level)
            .adding(ChronoConstellatorHold(star: 0, start: 10, length: 5), level: level)
        let before: ChronoConstellatorTimeline = timeline
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.releasing(star: -1, start: 10, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.releasing(star: 2, start: 10, level: level) } == .action("range"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.releasing(star: 0, start: 11, level: level) } == .action("no-hold"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.releasing(star: 0, start: 9, level: level) } == .action("no-hold"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in try timeline.releasing(star: 1, start: 10, level: level) } == .action("no-hold"))
        #expect(Self.refusal { () throws(ChronoConstellatorError) in
            try ChronoConstellatorTimeline(level: level).releasing(star: 0, start: 10, level: level) } == .action("no-hold"))
        #expect(ChronoConstellatorError.action("no-hold").reasonCode == "r02-g06.action")
        #expect(timeline == before)
        let released: ChronoConstellatorTimeline = try timeline.releasing(star: 0, start: 10, level: level)
        #expect(released.holds.isEmpty)
        #expect(timeline.holds.count == 1)
    }

    // MARK: Evaluation order

    @Test func collisionNamesTheLowestPairAndTheCell() throws {
        // Three loops share cell 7: [0, 1, 7, 6], [1, 2, 8, 7], [7, 8, 14, 13]; all reach 7 on tick 1.
        let a: [Int] = Self.square(0, 0)
        let b: [Int] = Self.square(1, 0)
        let c: [Int] = Self.square(1, 1)
        #expect(a == [0, 1, 7, 6])
        #expect(b == [1, 2, 8, 7])
        #expect(c == [7, 8, 14, 13])
        let level: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 1, target: 0),
                                                             ChronoConstellatorStar(loop: b, phase: 2, target: 2),
                                                             ChronoConstellatorStar(loop: c, phase: 3, target: 14)])
        let timeline = ChronoConstellatorTimeline(level: level)
        #expect(timeline.positions(at: 0, level: level) == [1, 8, 13])
        #expect(ChronoConstellatorEvaluation.verdict(positions: timeline.positions(at: 0, level: level), tick: 0,
                                                     level: level) == .running)
        let one: [Int] = timeline.positions(at: 1, level: level)
        #expect(one == [7, 7, 7])
        #expect(ChronoConstellatorEvaluation.verdict(positions: one, tick: 1, level: level) == .failed(.collision(0, 1, 7)))
        // Holding star 0 on tick 1 leaves stars 1 and 2 on cell 7.
        let held: ChronoConstellatorTimeline = try timeline.adding(ChronoConstellatorHold(star: 0, start: 1, length: 1),
                                                                   level: level)
        let two: [Int] = held.positions(at: 1, level: level)
        #expect(two == [1, 7, 7])
        #expect(ChronoConstellatorEvaluation.verdict(positions: two, tick: 1, level: level) == .failed(.collision(1, 2, 7)))
        // Hand positions on a five-star level: the first pair a < b in order wins the naming.
        let five: ChronoConstellatorLevel = try Self.level([
            ChronoConstellatorStar(loop: Self.square(0, 0), phase: 0, target: 0),
            ChronoConstellatorStar(loop: Self.square(2, 0), phase: 0, target: 2),
            ChronoConstellatorStar(loop: Self.square(4, 0), phase: 0, target: 4),
            ChronoConstellatorStar(loop: Self.square(0, 2), phase: 0, target: 12),
            ChronoConstellatorStar(loop: Self.square(2, 2), phase: 0, target: 14)])
        #expect(ChronoConstellatorEvaluation.verdict(positions: [5, 9, 3, 9, 3], tick: 4, level: five) == .failed(.collision(1, 3, 9)))
        #expect(ChronoConstellatorEvaluation.verdict(positions: [3, 9, 3, 9, 20], tick: 4, level: five) == .failed(.collision(0, 2, 3)))
        #expect(ChronoConstellatorEvaluation.verdict(positions: [1, 2, 4, 6, 6], tick: 4, level: five) == .failed(.collision(3, 4, 6)))
        #expect(ChronoConstellatorEvaluation.verdict(positions: [8, 8, 8, 8, 8], tick: 4, level: five) == .failed(.collision(0, 1, 8)))
        #expect(ChronoConstellatorFailure.collision(0, 1, 8).code == "collision")
        #expect(ChronoConstellatorFailure.time.code == "time")
    }

    @Test func collisionBeforeWinBeforeTime() throws {
        // A collision on the tick limit is a collision, not time.
        let a: [Int] = Self.square(0, 0)
        let b: [Int] = Self.square(1, 0)
        let crash: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 0, target: 0),
                                                             ChronoConstellatorStar(loop: b, phase: 3, target: 2)],
                                                            tickLimit: 1)
        let crashLine = ChronoConstellatorTimeline(level: crash)
        #expect(crashLine.positions(at: 1, level: crash) == [1, 1])
        #expect(ChronoConstellatorEvaluation.verdict(positions: crashLine.positions(at: 1, level: crash), tick: 1,
                                                     level: crash) == .failed(.collision(0, 1, 1)))
        // A win on the tick limit is a win, not time; one tick earlier is undecided.
        let c: [Int] = ChronoConstellatorFixtures.rectangle(column: 3, row: 1, width: 3, height: 3, columns: 6)
        let win: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 0, target: a[2]),
                                                           ChronoConstellatorStar(loop: c, phase: 0, target: c[2])],
                                                          tickLimit: 2)
        let winLine = ChronoConstellatorTimeline(level: win)
        #expect(ChronoConstellatorEvaluation.verdict(positions: winLine.positions(at: 1, level: win), tick: 1,
                                                     level: win) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: winLine.positions(at: 2, level: win), tick: 2,
                                                     level: win) == .won)
        // The same sky one step short of the targets on the limit fails on time.
        let late: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 0, target: a[3]),
                                                            ChronoConstellatorStar(loop: c, phase: 0, target: c[3])],
                                                           tickLimit: 2)
        let lateLine = ChronoConstellatorTimeline(level: late)
        #expect(ChronoConstellatorEvaluation.verdict(positions: lateLine.positions(at: 1, level: late), tick: 1,
                                                     level: late) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: lateLine.positions(at: 2, level: late), tick: 2,
                                                     level: late) == .failed(.time))
        #expect(ChronoConstellatorEvaluation.verdict(positions: lateLine.positions(at: 3, level: late), tick: 3,
                                                     level: late) == .won)
        // Collision and time agree with an independent first-decision scan on seeded random skies.
        var collisions: Int = 0
        var times: Int = 0
        for index in 0..<60 {
            let level: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var random = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed &+ UInt64(index))
            let timeline: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(level, random: &random)
            var reference = ReferenceSky(level: level, phases: timeline.phases, holds: timeline.holds)
            for tick in 1...level.tickLimit {
                reference.step()
                let cells: [Int] = reference.cells
                var expected: ChronoConstellatorVerdict = .running
                var crashed = false
                for x in cells.indices where !crashed {
                    for y in (x + 1)..<cells.count where !crashed && cells[x] == cells[y] {
                        expected = .failed(.collision(x, y, cells[x]))
                        crashed = true
                    }
                }
                if !crashed {
                    if cells == level.stars.map(\.target) {
                        expected = .won
                    } else if tick == level.tickLimit {
                        expected = .failed(.time)
                    }
                }
                let verdict: ChronoConstellatorVerdict = ChronoConstellatorEvaluation.verdict(
                    positions: timeline.positions(at: tick, level: level), tick: tick, level: level)
                #expect(verdict == expected, "level \(index) tick \(tick)")
                if verdict != .running {
                    if case .failed(.collision) = verdict { collisions += 1 }
                    if verdict == .failed(.time) { times += 1 }
                    break
                }
            }
        }
        #expect(collisions > 0)
        #expect(times > 0)
    }

    @Test func swappingNeighbourCellsIsNoCollision() throws {
        // Star 0 at cell 1 moves to 7 while star 1 at 7 moves to 1.
        let a: [Int] = Self.square(0, 0)
        let b: [Int] = Self.square(1, 0)
        let level: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 1, target: 0),
                                                             ChronoConstellatorStar(loop: b, phase: 3, target: 2)],
                                                            tickLimit: 10)
        let timeline = ChronoConstellatorTimeline(level: level)
        #expect(timeline.positions(at: 0, level: level) == [1, 7])
        #expect(timeline.positions(at: 1, level: level) == [7, 1])
        #expect(ChronoConstellatorEvaluation.verdict(positions: timeline.positions(at: 1, level: level), tick: 1,
                                                     level: level) == .running)
        // On tick 2 they part again (6 and 2), still no collision.
        #expect(timeline.positions(at: 2, level: level) == [6, 2])
        #expect(ChronoConstellatorEvaluation.verdict(positions: timeline.positions(at: 2, level: level), tick: 2,
                                                     level: level) == .running)
    }

    @Test func nothingIsJudgedAtTickZero() throws {
        let a: [Int] = Self.square(0, 0)
        let b: [Int] = Self.square(1, 0)
        // Start phases on one cell (1): not a collision at tick 0.
        let together: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 1, target: 0),
                                                                ChronoConstellatorStar(loop: b, phase: 0, target: 2)])
        let start = ChronoConstellatorTimeline(level: together)
        #expect(start.positions(at: 0, level: together) == [1, 1])
        #expect(ChronoConstellatorEvaluation.verdict(positions: start.positions(at: 0, level: together), tick: 0,
                                                     level: together) == .running)
        // Start phases already on the targets: not a win at tick 0; on tick 1 they have moved on.
        let aligned: ChronoConstellatorLevel = try Self.level([ChronoConstellatorStar(loop: a, phase: 0, target: 0),
                                                               ChronoConstellatorStar(loop: b, phase: 1, target: 2)],
                                                              tickLimit: 1)
        let line = ChronoConstellatorTimeline(level: aligned)
        #expect(line.positions(at: 0, level: aligned) == [0, 2])
        #expect(ChronoConstellatorEvaluation.verdict(positions: [0, 2], tick: 0, level: aligned) == .running)
        #expect(ChronoConstellatorEvaluation.verdict(positions: line.positions(at: 1, level: aligned), tick: 1,
                                                     level: aligned) == .failed(.time))
        // Holding both stars on tick 1 keeps them aligned: the win comes on tick 1.
        let kept: ChronoConstellatorTimeline = try ChronoConstellatorTimeline(level: aligned)
            .adding(ChronoConstellatorHold(star: 0, start: 1, length: 1), level: aligned)
            .adding(ChronoConstellatorHold(star: 1, start: 1, length: 1), level: aligned)
        #expect(kept.positions(at: 1, level: aligned) == [0, 2])
        #expect(ChronoConstellatorEvaluation.verdict(positions: kept.positions(at: 1, level: aligned), tick: 1,
                                                     level: aligned) == .won)
        // Negative ticks are not judged either.
        #expect(ChronoConstellatorEvaluation.verdict(positions: [1, 1], tick: -1, level: together) == .running)
    }

    // MARK: Fingerprint

    @Test func theFingerprintIsStableAndChangesWithAnyPhaseOrHold() throws {
        let level: ChronoConstellatorLevel = try Self.sample(budget: 4)
        let base = ChronoConstellatorTimeline(level: level)
        let stamp: String = base.fingerprint
        #expect(stamp.count == 64)
        #expect(stamp.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(ChronoConstellatorTimeline(level: level).fingerprint == stamp)
        #expect(base.fingerprint == stamp)
        var seen = Set<String>([stamp])
        // Every other phase of every star gives a new fingerprint.
        for star in level.stars.indices {
            for offset in 0..<level.stars[star].length where offset != level.stars[star].phase {
                let changed: ChronoConstellatorTimeline = try base.settingPhase(star: star, to: offset, level: level)
                #expect(seen.insert(changed.fingerprint).inserted, "star \(star) phase \(offset)")
            }
        }
        // Every hold differing in star, start or length gives a new fingerprint.
        for star in level.stars.indices {
            for start in [1, 2, 50] {
                for length in [1, 2, 60] where start + length - 1 <= level.tickLimit {
                    let held: ChronoConstellatorTimeline = try base.adding(
                        ChronoConstellatorHold(star: star, start: start, length: length), level: level)
                    #expect(seen.insert(held.fingerprint).inserted, "hold \(star) \(start) \(length)")
                    #expect(try held.releasing(star: star, start: start, level: level).fingerprint == stamp)
                }
            }
        }
        // Holds added in either order give one fingerprint (they are kept sorted).
        let first = ChronoConstellatorHold(star: 1, start: 20, length: 3)
        let second = ChronoConstellatorHold(star: 0, start: 5, length: 2)
        let ab: ChronoConstellatorTimeline = try base.adding(first, level: level).adding(second, level: level)
        let ba: ChronoConstellatorTimeline = try base.adding(second, level: level).adding(first, level: level)
        #expect(ab == ba)
        #expect(ab.fingerprint == ba.fingerprint)
        // Seeded timelines: equal timelines share a fingerprint, the two seeds' differing timelines do not.
        var differing: Int = 0
        for index in 0..<100 {
            let random: ChronoConstellatorLevel = ChronoConstellatorFixtures.randomLevel(index)
            var x = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed &+ UInt64(index))
            var y = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.neighbourSeed &+ UInt64(index))
            var again = ChronoConstellatorRandom(seed: ChronoConstellatorFixtures.seed &+ UInt64(index))
            let one: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(random, random: &x)
            let two: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(random, random: &y)
            let same: ChronoConstellatorTimeline = ChronoConstellatorFixtures.randomTimeline(random, random: &again)
            #expect(one.fingerprint == same.fingerprint)
            #expect((one == two) == (one.fingerprint == two.fingerprint), "level \(index)")
            if one != two { differing += 1 }
        }
        #expect(differing > 50)
    }
}
