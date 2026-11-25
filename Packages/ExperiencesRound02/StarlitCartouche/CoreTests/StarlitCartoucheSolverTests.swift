// StarlitCartoucheSolverTests — feature 452 (R02-G16-02) T-R02G1602-003 (FR-R02G1602-002; SC-R02G1602-001, 002, 005;
// clarification Q2). The time-expanded breadth-first solver of Starlit Cartouche. Hand levels (fixed orbits unless
// stated, every window [0, 64] and deadline 20 unless stated, budget 10;
// star 3 at (−8, −8, −8) on no corridor, since a level has at least 4 stars) with minima worked out by hand:
// - wait for range: stars 0 at (0, 0, 0), 1 cycling (8, 0, 0), (8, 0, 0), (1, 0, 0) and 2 at (8, 1, 0), range 2;
//   corridors 0 = 0–1 and 1 = 1–2, travel 1; symbol {0, 1}, beacon 2. Corridor 0 is flyable only at beats 2, 5, 8 …,
//   so the first leg waits 2 (arriving at beat 3, star 1 back at (8, 0, 0)) and the second leg leaves at once:
//   [leg(1, 2), leg(2, 0)]; two strokes need two legs. Depth 1 reaches 3 states (waits 2, 5, 8); work = 9 + 9 + 1.
// - wait out a hazard: stars 0, 1, 2 at (0, 0, 0), (1, 0, 0), (2, 0, 0), range 1; corridors 0 = 0–1 (travel 1) and
//   1 = 1–2 (travel 2); hazard on corridor 1 over [2, 5]; symbol {0, 1}, beacon 2. From beat 1 the second leg must
//   leave at beat 6 or later: [leg(1, 0), leg(2, 5)]. Depth 1 reaches 9 states; work = 9 + 9 + 6.
// - windows force an order: centre star 0 at (0, 0, 0), leaves 2 at (1, 0, 0) and 1 at (0, 1, 0), range 1; corridors
//   0 = 0–2 and 1 = 0–1, travel 1; star 1's window [0, 2], star 2's window [4, 64]; deadline 10 (it keeps the
//   enumeration small); symbol {0, 1}, beacon 0. Each leg moves between the centre and a leaf, so a route ending at
//   the centre has an even length, and two legs draw one stroke: at least 4. Star 2 first would reach star 1 after
//   its window closed, so star 1 comes first even though corridor 0 is tried first:
//   [leg(1, 0), leg(0, 0), leg(2, 1), leg(0, 0)] (the third leg waits 1 at beat 2, since leaving at once would
//   reach star 2 at beat 3, before its window opens).
// Then: the plan wins through the play (StarlitCartoucheSolver.wins) and an independent depth-first enumeration
// written here (no state merging; it applies `.leg(star, wait)` through StarlitCartouchePlay only, corridors touching
// the ship's star by index, then waits 0 … 8) of every leg sequence the play accepts finds no win shorter than the
// plan and, at the plan's size, finds the plan as its first win, on the hand levels and on seeded generator candidates
// (candidate 0 of 11 manifest entries of bands 1 and 2). The work bound (300 000) holds; a work bound one short of the
// plan's work and a leg bound one short of its size give no plan, the exact bounds give the same plan; a level with
// no route within the leg bound gives nil. The states counted at each smaller depth are one entry per depth, the
// start alone at depth 0, all positive. Explicit types, plain loops; no clock.
import Foundation
import Testing
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheSolverTests {
    typealias Level = StarlitCartoucheLevel
    typealias Action = StarlitCartoucheAction
    typealias Play = StarlitCartouchePlay

    /// The seed recorded on the hand levels.
    static let seed: UInt64 = 2_452
    /// The manifest entries whose candidate 0 is enumerated: band 1 (plans of 1 … 3 legs) and band 2 (3 and 4 legs),
    /// chosen among those with a candidate 0 for an enumeration of a few hundred accepted sequences or fewer.
    static let seededEntries: [Int] = [0, 1, 2, 3, 4, 6, 7, 10, 22, 23, 25]

    // MARK: - Hand levels

    /// A star with `orbit` and `glyph`, window [open, close].
    static func star(_ orbit: [StarlitCartoucheVector], _ gx: Int, _ gy: Int, open: Int = 0,
                     close: Int = 64) -> StarlitCartoucheStar {
        StarlitCartoucheStar(orbit: orbit, glyph: StarlitCartoucheGlyphPoint(gx, gy), open: open, close: close)
    }

    /// Star 3 of every hand level, joined by no corridor (a level needs at least 4 stars).
    static let isolated: StarlitCartoucheStar = star([StarlitCartoucheVector(-8, -8, -8)], 4, 4)

    /// A fixed point.
    static func at(_ x: Int, _ y: Int, _ z: Int) -> [StarlitCartoucheVector] { [StarlitCartoucheVector(x, y, z)] }

    /// The wait-for-range hand level (see the file header).
    static func waitForRange() throws -> Level {
        let cycling: [StarlitCartoucheVector] = [StarlitCartoucheVector(8, 0, 0), StarlitCartoucheVector(8, 0, 0),
                                                 StarlitCartoucheVector(1, 0, 0)]
        let stars: [StarlitCartoucheStar] = [star(at(0, 0, 0), 0, 0), star(cycling, 1, 0),
                                             star(at(8, 1, 0), 2, 0), Self.isolated]
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 1)]
        return try Level(id: "wait-for-range", seed: seed, difficulty: 1, stars: stars, range: 2,
                         corridors: corridors, hazards: [], start: 0, beacon: 2, deadline: 20, symbol: [0, 1],
                         budget: 10)
    }

    /// The wait-out-a-hazard hand level (see the file header).
    static func waitOutHazard(hazardTo: Int = 5) throws -> Level {
        let stars: [StarlitCartoucheStar] = [star(at(0, 0, 0), 0, 0), star(at(1, 0, 0), 1, 0),
                                             star(at(2, 0, 0), 2, 0), Self.isolated]
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                     StarlitCartoucheCorridor(1, 2, travel: 2)]
        let hazards: [StarlitCartoucheHazard] = [StarlitCartoucheHazard(corridor: 1, from: 2, to: hazardTo)]
        return try Level(id: "wait-out-hazard", seed: seed, difficulty: 1, stars: stars, range: 1,
                         corridors: corridors, hazards: hazards, start: 0, beacon: 2, deadline: 20, symbol: [0, 1],
                         budget: 10)
    }

    /// The windows-force-an-order hand level (see the file header).
    static func windowOrder() throws -> Level {
        let stars: [StarlitCartoucheStar] = [star(at(0, 0, 0), 0, 0), star(at(0, 1, 0), 1, 0, open: 0, close: 2),
                                             star(at(1, 0, 0), 2, 0, open: 4, close: 64), Self.isolated]
        let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 2, travel: 1),
                                                     StarlitCartoucheCorridor(0, 1, travel: 1)]
        return try Level(id: "window-order", seed: seed, difficulty: 1, stars: stars, range: 1,
                         corridors: corridors, hazards: [], start: 0, beacon: 0, deadline: 10, symbol: [0, 1],
                         budget: 10)
    }

    // MARK: - Independent enumeration

    /// The result of a depth-first enumeration of leg sequences of length ≤ `limit`.
    struct Enumeration {
        /// Accepted leg sequences (the play took the last leg) of each length 1 … limit.
        var accepted: [Int]
        /// The first win of length exactly `limit` in the fixed order, if any.
        var firstWin: [Action]?
        /// The shortest win seen at any length ≤ limit.
        var shortestWin: Int?
    }

    /// A play of `level` that accepts legs (begun, tutorial dismissed).
    static func started(_ level: Level) throws -> Play {
        var play = Play(level: level)
        try play.handle(.begin)
        if play.stage == .tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// Every leg the enumeration tries from `play`, in the fixed order: corridors touching the ship's star by index,
    /// then waits 0 … 8, each as `.leg(other star, wait)`.
    static func candidates(_ play: Play) -> [Action] {
        var actions: [Action] = []
        for corridor in play.level.corridors {
            guard corridor.a == play.star || corridor.b == play.star else { continue }
            let other: Int = corridor.a == play.star ? corridor.b : corridor.a
            for wait in 0...8 { actions.append(.leg(other, wait)) }
        }
        return actions
    }

    /// Depth-first over every accepted sequence below `play` (prefix `path`), no state merging.
    static func explore(_ play: Play, path: [Action], limit: Int, into result: inout Enumeration) {
        for action in candidates(play) {
            var child: Play = play
            do { try child.apply(action, expecting: child.fingerprint) } catch { continue }
            let sequence: [Action] = path + [action]
            result.accepted[sequence.count - 1] += 1
            if child.stage == .won {
                if result.shortestWin == nil || sequence.count < result.shortestWin! {
                    result.shortestWin = sequence.count
                }
                if sequence.count == limit, result.firstWin == nil { result.firstWin = sequence }
                continue
            }
            if child.stage == .playing, sequence.count < limit {
                explore(child, path: sequence, limit: limit, into: &result)
            }
        }
    }

    /// The enumeration of `level` up to `limit` legs.
    static func enumerate(_ level: Level, limit: Int) throws -> Enumeration {
        var result = Enumeration(accepted: [Int](repeating: 0, count: limit), firstWin: nil, shortestWin: nil)
        explore(try started(level), path: [], limit: limit, into: &result)
        return result
    }

    /// Checks `plan` of `level` against the enumeration: it wins, nothing shorter wins and it is the first win of its
    /// size in the fixed order.
    static func confirm(_ level: Level, _ plan: StarlitCartouchePlan) throws {
        #expect(StarlitCartoucheSolver.wins(level, actions: plan.legs), "\(level.id) plan does not win")
        let enumeration: Enumeration = try enumerate(level, limit: plan.size)
        let shortest: String = enumeration.shortestWin.map { String($0) } ?? "none"
        #expect(enumeration.shortestWin == plan.size, "\(level.id) shortest win \(shortest)")
        #expect(enumeration.firstWin == plan.legs, "\(level.id) first win differs from the plan")
        for depth in 0..<(plan.size - 1) {
            #expect(enumeration.accepted[depth] > 0, "\(level.id) nothing accepted at length \(depth + 1)")
        }
    }

    /// The candidate-0 levels of `seededEntries` (entries without a candidate 0 are skipped).
    static func seededLevels() -> [Level] {
        var levels: [Level] = []
        for index in seededEntries {
            if let level = StarlitCartoucheGenerator.candidate(StarlitCartoucheManifest.entries[index], index: 0) {
                levels.append(level)
            }
        }
        return levels
    }

    // MARK: - Tests

    @Test func waitForRangeHasTheHandMinimum() throws {
        let level: Level = try Self.waitForRange()
        let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level))
        #expect(plan.legs == [.leg(1, 2), .leg(2, 0)])
        #expect(plan.statesByDepth == [1, 3])
        #expect(plan.work == 19)
        try Self.confirm(level, plan)
    }

    @Test func waitOutHazardHasTheHandMinimum() throws {
        let level: Level = try Self.waitOutHazard()
        let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level))
        #expect(plan.legs == [.leg(1, 0), .leg(2, 5)])
        #expect(plan.statesByDepth == [1, 9])
        #expect(plan.work == 24)
        try Self.confirm(level, plan)
        #expect(!StarlitCartoucheSolver.wins(level, actions: [.leg(1, 0), .leg(2, 4)]))
    }

    @Test func windowsForceTheOrder() throws {
        let level: Level = try Self.windowOrder()
        let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level))
        #expect(plan.legs == [.leg(1, 0), .leg(0, 0), .leg(2, 1), .leg(0, 0)])
        #expect(plan.size == 4)
        try Self.confirm(level, plan)
        let reversed: [Action] = [.leg(2, 3), .leg(0, 0), .leg(1, 0), .leg(0, 0)]
        #expect(!StarlitCartoucheSolver.wins(level, actions: reversed))
    }

    @Test func enumerationAgreesOnSeededCandidates() throws {
        let levels: [Level] = Self.seededLevels()
        #expect(levels.count == Self.seededEntries.count)
        for level in levels {
            let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level), "\(level.id)")
            try Self.confirm(level, plan)
        }
    }

    @Test func workAndLegBoundsAreRespected() throws {
        var levels: [Level] = [try Self.waitForRange(), try Self.waitOutHazard(), try Self.windowOrder()]
        levels += Self.seededLevels()
        for level in levels {
            let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level), "\(level.id)")
            #expect(plan.work <= StarlitCartoucheSolver.workBound)
            #expect(plan.size <= StarlitCartoucheSolver.maxLegs)
            #expect(StarlitCartoucheSolver.plan(level, workBound: plan.work - 1) == nil, "\(level.id) work − 1")
            #expect(StarlitCartoucheSolver.plan(level, workBound: plan.work) == plan, "\(level.id) exact work")
            #expect(StarlitCartoucheSolver.plan(level, maxLegs: plan.size - 1) == nil, "\(level.id) size − 1")
            #expect(StarlitCartoucheSolver.plan(level, maxLegs: plan.size) == plan, "\(level.id) exact size")
        }
    }

    @Test func noRouteWithinTheLegBoundGivesNil() throws {
        // The window-order level needs 4 legs; 3 are not enough.
        #expect(StarlitCartoucheSolver.plan(try Self.windowOrder(), maxLegs: 3) == nil)
        // A hazard on corridor 1 over [2, 64] covers every beat a second leg could fly before the deadline.
        let blocked: Level = try Self.waitOutHazard(hazardTo: 64)
        #expect(StarlitCartoucheSolver.plan(blocked) == nil)
        let enumeration: Enumeration = try Self.enumerate(blocked, limit: 3)
        #expect(enumeration.shortestWin == nil)
    }

    @Test func statesByDepthAreConsistent() throws {
        var levels: [Level] = [try Self.waitForRange(), try Self.waitOutHazard(), try Self.windowOrder()]
        levels += Self.seededLevels()
        for level in levels {
            let plan: StarlitCartouchePlan = try #require(StarlitCartoucheSolver.plan(level), "\(level.id)")
            #expect(plan.statesByDepth.count == plan.size)
            #expect(plan.statesByDepth.first == 1)
            for count in plan.statesByDepth { #expect(count > 0) }
            #expect(plan.statesSearched == plan.statesByDepth.reduce(0, +))
        }
    }
}
