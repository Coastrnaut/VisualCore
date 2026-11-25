// CelestialEclipseLabSolverTests — feature 462 (R02-G17-02) T-R02G1702-003 (FR-R02G1702-002; SC-R02G1702-001, 002,
// 005; clarification Q2). The phase-search solver of Celestial Eclipse Lab. Hand levels (horizon 8, budget 5, every
// orbit of period 4 written as one position followed by three copies of a second one, each body at one constant
// depth: body 0 at z 10, body 1 at 0, body 2 at −10, body 3 at −20, so a smaller body number is in front; every
// radius 1, so two bodies eclipse only on the same projected point; O = (0, 0); a body "at O at index 0" is at O on
// the ticks where (tick + phase) mod 4 = 0) with minima worked out by hand:
// - two winners: body 0 fixed at O; bodies 1 and 2 at O at index 0, else at (20, 0) and (−20, 0); target body 0 in
//   front of body 1 in [0, 3]; start phases (0, 1, 3): body 2 reaches O at tick 1 before body 1 (tick 3), an unwanted
//   event. Single changes that win: body 1 to 0 or 3 (its event first), body 2 to 1 (body 2 meets O on tick 3 with
//   body 1, and body 0 in front of body 1 sorts first). The plan is the first in the fixed order: [phase(1, 0)],
//   work 2. With body 1 fixed the only winning change is phase(2, 1), judged after phase(2, 0): work 3.
// - two changes: body 0 fixed at O; bodies 1, 2, 3 at O at index 0, else at (20, 0), (−20, 0), (0, 20); target body 0
//   in front of body 1 in [3, 3]; start (0, 1, 2, 2). The only winning setting is (0, 1, 1, 1): both blockers moved to
//   meet O on tick 3. Plan [phase(2, 1), phase(3, 1)]; depth 1 judges 9 settings; at depth 2 the subsets {1, 2} and
//   {1, 3} (9 each) and then {2, 3} up to (1, 1), the fifth: work 1 + 9 + 9 + 9 + 5 = 33. With body 2 fixed there is
//   no plan within the movable bodies.
// - fixed only: body 0 fixed, at O at index 0, else at (20, 20); body 1 constant at O; body 2 constant at
//   (−20, −20); target body 0 in front of body 1 in [0, 0]; start (1, 0, 0) puts the event on tick 3. Only body 0's
//   phase decides the tick, so there is no plan; unfixed, the plan is [phase(0, 0)], work 2.
// Every hand minimum is also derived by brute force here (every phase vector of the movable bodies judged by the
// kernel's whole-sky `CelestialEclipseLabSky.timeline`, never the solver's table). Then: the plan wins through the play
// (`CelestialEclipseLabSolver.wins`) and the kernel timeline, and no setting with fewer changes wins; the internal
// pair-interval table equals the kernel's intervals and judge on 30 seeded phase vectors (SeededRandom seed 2_462) of
// generated candidates of every band; on candidates of bands 1 … 3 the settings counted at each smaller depth equal
// the combinatorial count (sum over d-subsets of movable bodies of the product of period − 1) and an independent
// enumeration finds none of them winning; the work bound and the change bound give nil one short of the plan and the
// same plan at the exact bound. Explicit types and plain loops keep the type checker fast on CI; no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabSolverTests {
    typealias Level = CelestialEclipseLabLevel
    typealias Body = CelestialEclipseLabBody
    typealias Vector = CelestialEclipseLabVector
    typealias Action = CelestialEclipseLabAction
    typealias Solver = CelestialEclipseLabSolver
    typealias Sky = CelestialEclipseLabSky

    /// The seed of the hand levels and of the random phase vectors.
    static let seed: UInt64 = 2_462

    // MARK: - Hand levels

    /// A period-4 orbit at depth `z`: `(x, y)` at index 0, then `(rx, ry)` at indices 1 … 3.
    static func orbit(_ x: Int, _ y: Int, then rx: Int, _ ry: Int, z: Int) -> [Vector] {
        [Vector(x, y, z), Vector(rx, ry, z), Vector(rx, ry, z), Vector(rx, ry, z)]
    }

    /// A body of radius 1 on `orbit`.
    static func body(_ orbit: [Vector], fixed: Bool = false) -> Body {
        Body(orbit: orbit, radius: 1, fixed: fixed)
    }

    /// A hand level of `bodies`, a one-eclipse target body 0 in front of body 1 over [open, close], and `phases`.
    static func hand(_ id: String, _ bodies: [Body], open: Int, close: Int, phases: [Int]) throws -> Level {
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: open,
                                                                             close: close)]
        return try Level(id: id, seed: seed, difficulty: 1, bodies: bodies, horizon: 8, target: target,
                         phases: phases, budget: 5)
    }

    /// The two-winners hand level (see the file header), body 1 fixed when `fixingBody1`.
    static func twoWinners(fixingBody1: Bool = false) throws -> Level {
        let bodies: [Body] = [body(orbit(0, 0, then: 0, 0, z: 10), fixed: true),
                              body(orbit(0, 0, then: 20, 0, z: 0), fixed: fixingBody1),
                              body(orbit(0, 0, then: -20, 0, z: -10))]
        return try hand("two-winners", bodies, open: 0, close: 3, phases: [0, 1, 3])
    }

    /// The two-changes hand level (see the file header), body 2 fixed when `fixingBody2`.
    static func twoChanges(fixingBody2: Bool = false) throws -> Level {
        let bodies: [Body] = [body(orbit(0, 0, then: 0, 0, z: 10), fixed: true),
                              body(orbit(0, 0, then: 20, 0, z: 0)),
                              body(orbit(0, 0, then: -20, 0, z: -10), fixed: fixingBody2),
                              body(orbit(0, 0, then: 0, 20, z: -20))]
        return try hand("two-changes", bodies, open: 3, close: 3, phases: [0, 1, 2, 2])
    }

    /// The fixed-only hand level (see the file header), body 0 fixed unless `freeingBody0`.
    static func fixedOnly(freeingBody0: Bool = false) throws -> Level {
        let bodies: [Body] = [body(orbit(0, 0, then: 20, 20, z: 10), fixed: !freeingBody0),
                              body(orbit(0, 0, then: 0, 0, z: 0)),
                              body(orbit(-20, -20, then: -20, -20, z: -10))]
        return try hand("fixed-only", bodies, open: 0, close: 0, phases: [1, 0, 0])
    }

    // MARK: - Independent enumeration (the kernel's whole-sky timeline only)

    /// The settings within a number of changes of the start, by exact depth: how many, and how many win.
    struct Census {
        /// The settings differing from the start on exactly d movable bodies, by d.
        var counts: [Int]
        /// The winning settings among them, by d.
        var wins: [Int]
    }

    /// The movable bodies of `level`, in body order.
    static func movable(_ level: Level) -> [Int] {
        var result: [Int] = []
        for index in 0..<level.bodies.count where !level.bodies[index].fixed { result.append(index) }
        return result
    }

    /// Every phase vector differing from the start on at most `limit` movable bodies, judged by the kernel.
    static func census(_ level: Level, limit: Int) -> Census {
        var census = Census(counts: Array(repeating: 0, count: limit + 1), wins: Array(repeating: 0, count: limit + 1))
        var phases: [Int] = level.phases
        visit(level, movable(level), 0, 0, limit, &phases, &census)
        return census
    }

    /// The recursive step of ``census(_:limit:)`` over the movable body at `index`.
    static func visit(_ level: Level, _ movable: [Int], _ index: Int, _ changes: Int, _ limit: Int,
                      _ phases: inout [Int], _ census: inout Census) {
        if index == movable.count {
            census.counts[changes] += 1
            if Sky.timeline(level, phases: phases).wins { census.wins[changes] += 1 }
            return
        }
        visit(level, movable, index + 1, changes, limit, &phases, &census)
        guard changes < limit else { return }
        let body: Int = movable[index]
        let start: Int = level.phases[body]
        for offset in 0..<level.bodies[body].period where offset != start {
            phases[body] = offset
            visit(level, movable, index + 1, changes + 1, limit, &phases, &census)
        }
        phases[body] = start
    }

    /// The brute-force minimum number of movable bodies to change for a win, or nil when no setting wins.
    static func bruteMinimum(_ level: Level) -> Int? {
        let limit: Int = movable(level).count
        let all: Census = census(level, limit: limit)
        for depth in 0...limit where all.wins[depth] > 0 { return depth }
        return nil
    }

    /// The settings differing from the start on exactly d movable bodies, d = 0 … limit, counted combinatorially.
    static func combinatorial(_ level: Level, limit: Int) -> [Int] {
        var counts: [Int] = Array(repeating: 0, count: limit + 1)
        counts[0] = 1
        for body in movable(level) {
            let choices: Int = level.bodies[body].period - 1
            var depth: Int = limit
            while depth >= 1 {
                counts[depth] += counts[depth - 1] * choices
                depth -= 1
            }
        }
        return counts
    }

    /// The first winning single change in (body, offset) order, judged by the kernel, or nil.
    static func firstWinningSingle(_ level: Level) -> Action? {
        for body in movable(level) {
            var phases: [Int] = level.phases
            for offset in 0..<level.bodies[body].period where offset != level.phases[body] {
                phases[body] = offset
                if Sky.timeline(level, phases: phases).wins { return .phase(body, offset) }
            }
        }
        return nil
    }

    /// Checks that `plan` wins `level` through the play and the kernel, and that no setting with fewer changes wins.
    static func checkMinimal(_ plan: CelestialEclipseLabPlan, _ level: Level) {
        #expect(Solver.wins(level, actions: plan.actions))
        #expect(Sky.timeline(level, phases: plan.phases(from: level)).wins)
        #expect(plan.size >= 1)
        let smaller: Census = census(level, limit: plan.size - 1)
        let expected: [Int] = combinatorial(level, limit: plan.size - 1)
        #expect(smaller.wins.reduce(0, +) == 0)
        #expect(smaller.counts == expected)
        #expect(plan.settingsByDepth == expected)
        #expect(plan.settingsByDepth.first == 1)
        #expect(plan.work >= plan.settingsSearched + 1)
        #expect(plan.work <= plan.settingsSearched + combinatorial(level, limit: plan.size)[plan.size])
        var previous: Int = -1
        for action in plan.actions {
            guard case .phase(let body, let offset) = action else {
                Issue.record("a plan holds phase changes only")
                continue
            }
            #expect(body > previous)
            #expect(!level.bodies[body].fixed)
            #expect(offset != level.phases[body])
            previous = body
        }
    }

    // MARK: - Seeded candidates

    /// The first `candidates` valid generator candidates (of indices 0 … 15) of the first `entries` manifest entries
    /// of each band in `bands`.
    static func seeded(bands: ClosedRange<Int>, entries: Int, candidates: Int) -> [Level] {
        var levels: [Level] = []
        for band in bands {
            var taken: Int = 0
            for entry in CelestialEclipseLabManifest.entries where entry.band == band && taken < entries {
                taken += 1
                var found: Int = 0
                var index: Int = 0
                while found < candidates && index < 16 {
                    if let level = CelestialEclipseLabGenerator.candidate(entry, index: index) {
                        levels.append(level)
                        found += 1
                    }
                    index += 1
                }
            }
        }
        return levels
    }

    // MARK: - Hand-level tests

    /// One change is minimal: the two-winners level's plan is phase(1, 0) of size 1, as the brute force says.
    @Test func oneChangeIsMinimal() throws {
        let level: Level = try Self.twoWinners()
        let plan: CelestialEclipseLabPlan = try #require(Solver.plan(level))
        #expect(Self.bruteMinimum(level) == 1)
        #expect(plan.size == 1)
        #expect(plan.actions == [Action.phase(1, 0)])
        #expect(plan.settingsByDepth == [1])
        #expect(plan.work == 2)
        Self.checkMinimal(plan, level)
    }

    /// Two changes are minimal: the two-changes level's plan moves both blockers, after 33 settings judged.
    @Test func twoChangesAreMinimal() throws {
        let level: Level = try Self.twoChanges()
        let plan: CelestialEclipseLabPlan = try #require(Solver.plan(level))
        #expect(Self.bruteMinimum(level) == 2)
        #expect(plan.size == 2)
        #expect(plan.actions == [Action.phase(2, 1), Action.phase(3, 1)])
        #expect(plan.phases(from: level) == [0, 1, 1, 1])
        #expect(plan.settingsByDepth == [1, 9])
        #expect(plan.work == 33)
        Self.checkMinimal(plan, level)
    }

    /// A win that needs a fixed body has no plan within the movable bodies; unfixed, it has a one-change plan.
    @Test func fixedBodiesAreNeverChanged() throws {
        let fixed: Level = try Self.fixedOnly()
        #expect(Self.bruteMinimum(fixed) == nil)
        #expect(Solver.plan(fixed) == nil)
        let free: Level = try Self.fixedOnly(freeingBody0: true)
        let plan: CelestialEclipseLabPlan = try #require(Solver.plan(free))
        #expect(Self.bruteMinimum(free) == 1)
        #expect(plan.actions == [Action.phase(0, 0)])
        #expect(plan.work == 2)
        Self.checkMinimal(plan, free)

        let blocked: Level = try Self.twoChanges(fixingBody2: true)
        #expect(Self.bruteMinimum(blocked) == nil)
        #expect(Solver.plan(blocked) == nil)
    }

    /// The plan is the first winning setting in the fixed order: the lower body, then the lower offset.
    @Test func planIsFirstInFixedOrder() throws {
        let level: Level = try Self.twoWinners()
        // Three single changes win: phase(1, 0), phase(1, 3) and phase(2, 1).
        var winners: [Action] = []
        for body in Self.movable(level) {
            var phases: [Int] = level.phases
            for offset in 0..<level.bodies[body].period where offset != level.phases[body] {
                phases[body] = offset
                if Sky.timeline(level, phases: phases).wins { winners.append(.phase(body, offset)) }
            }
        }
        #expect(winners == [Action.phase(1, 0), Action.phase(1, 3), Action.phase(2, 1)])
        let plan: CelestialEclipseLabPlan = try #require(Solver.plan(level))
        #expect(plan.actions == [Action.phase(1, 0)])
        #expect(Self.firstWinningSingle(level) == Action.phase(1, 0))

        let fixing: Level = try Self.twoWinners(fixingBody1: true)
        let other: CelestialEclipseLabPlan = try #require(Solver.plan(fixing))
        #expect(other.actions == [Action.phase(2, 1)])
        #expect(Self.firstWinningSingle(fixing) == Action.phase(2, 1))
        #expect(other.work == 3)
        Self.checkMinimal(other, fixing)
    }

    /// The work bound and the change bound: one short of the plan gives nil, the exact bound the same plan.
    @Test func boundsAreRespected() throws {
        let level: Level = try Self.twoChanges()
        let plan: CelestialEclipseLabPlan = try #require(Solver.plan(level))
        #expect(plan.work <= Solver.workBound)
        #expect(Solver.plan(level, workBound: plan.work - 1) == nil)
        #expect(Solver.plan(level, workBound: 1) == nil)
        #expect(Solver.plan(level, workBound: plan.work) == plan)
        #expect(Solver.plan(level, maxChanges: plan.size - 1) == nil)
        #expect(Solver.plan(level, maxChanges: 0) == nil)
        #expect(Solver.plan(level, maxChanges: plan.size) == plan)

        let levels: [Level] = Self.seeded(bands: 1...3, entries: 2, candidates: 1)
        var checked: Int = 0
        for level in levels {
            let upper: Int = CelestialEclipseLabBandProfile.of(band: level.difficulty).planRange.upperBound
            guard let plan = Solver.plan(level, maxChanges: upper) else { continue }
            checked += 1
            #expect(plan.work <= Solver.workBound)
            #expect(Solver.plan(level, maxChanges: upper, workBound: plan.work - 1) == nil)
            #expect(Solver.plan(level, maxChanges: upper, workBound: plan.work) == plan)
            #expect(Solver.plan(level, maxChanges: plan.size - 1) == nil)
        }
        #expect(checked > 0)
    }

    // MARK: - Seeded tests

    /// The pair-interval table equals the kernel: merged intervals and the judge on 30 seeded settings per level.
    @Test func tableAgreesWithKernel() {
        var random = SeededRandom(seed: Self.seed)
        let levels: [Level] = Self.seeded(bands: 1...5, entries: 2, candidates: 1)
        #expect(levels.count >= 5)
        for level in levels {
            let table = Solver.Table(level)
            #expect(table.merged(level.phases) == Sky.intervals(level, phases: level.phases))
            #expect(table.wins(level, level.phases) == false)
            for _ in 0..<30 {
                var phases: [Int] = []
                for body in level.bodies { phases.append(random.int(0...(body.period - 1))) }
                let kernel: CelestialEclipseLabTimeline = Sky.timeline(level, phases: phases)
                #expect(table.merged(phases) == Sky.intervals(level, phases: phases))
                #expect(table.merged(phases) == kernel.intervals)
                #expect(table.wins(level, phases) == kernel.wins)
            }
        }
    }

    /// On seeded candidates of bands 1 … 3: the plan wins, its settings by depth equal the combinatorial count, and
    /// the independent enumeration finds no winning setting with fewer changes.
    @Test func seededPlansAreMinimal() {
        let levels: [Level] = Self.seeded(bands: 1...3, entries: 2, candidates: 2)
        var checked: Int = 0
        for level in levels {
            let upper: Int = CelestialEclipseLabBandProfile.of(band: level.difficulty).planRange.upperBound
            guard let plan = Solver.plan(level, maxChanges: upper) else { continue }
            checked += 1
            #expect(plan.size <= upper)
            Self.checkMinimal(plan, level)
            if plan.size == 1 { #expect(plan.actions.first == Self.firstWinningSingle(level)) }
        }
        #expect(checked > 0)
    }
}
