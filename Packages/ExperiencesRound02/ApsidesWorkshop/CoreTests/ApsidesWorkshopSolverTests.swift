// ApsidesWorkshopSolverTests — feature 472 (R02-G18-02) T-R02G1802-003 (FR-R02G1802-002; SC-R02G1802-001, 002, 005;
// clarifications Q2, Q5). The bounded depth search of Apsides Workshop. Hand levels (period 16, no planets, budget 4,
// apsis targets with a single distance, so only the orbit's steps decide) with minima worked out by hand:
// - one knob tuning: start (size 20, k 5, d 0); periapsis in sector 2 at exactly 300 twentieths. Only k 5 gives
//   20(20 − k) = 300 and only d 6 … 8 lie in sector 2; a size alone keeps sector 0. The first winner in the order is
//   periapsis(5, 6): work 1 + 5·24 + 5 + 1 = 127.
// - one size tuning: the same start; apoapsis in sector 4 (d 0) at exactly 750. No knob at size 20 reaches 750
//   (20(20 + k) = 750 has no step); size 30 does (30·25). Work 1 + 383 knobs + 21 sizes (8 … 29 without 20) + 1 = 406.
// - both levers, size first: the same start; periapsis in sector 2 at 300 and apoapsis in sector 6 at 900, so
//   a(20 − k) = 300 and a(20 + k) = 900 give a = 30, k = 10; d 6 … 8 put both in their sectors. Plan
//   [size(30), periapsis(10, 6)] (k 10 ≥ 5), work 1 + 423 + 8 120 + 1 = 8 545 (counted again by enumeration below).
// - both levers, knob first: start (40, 8, 0); periapsis in sector 2 at 768, apoapsis in sector 6 at 1 152, so a = 48,
//   k = 4. Size first would pass (48, 8, 0), invalid (48·28 > 1280), so the plan is [periapsis(4, 6), size(48)],
//   work 1 + 348 + 13 673 + 1 = 14 023.
// Then: `orbits(from:depth:)` equals an independent enumeration for several starts, and over every valid start the
// largest counts are exactly 423 (depth 1) and 13 880 (depth 2); the apsis shortcut of `wins` agrees with the kernel's
// full report on seeded orbits (SeededRandom seed 2_472) of generated levels of every band; on those levels every orbit
// with fewer tunings than the plan, judged by the full report alone, loses, and the counts per depth are exact; every
// orbit before the plan in the fixed order loses; the two-tuning order passes only valid orbits over many seeded pairs;
// the work bound gives nil one short of the plan's work and the same plan at it. Plain loops, explicit types, no clock.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopSolverTests {
    typealias Level = ApsidesWorkshopLevel
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Target = ApsidesWorkshopTarget
    typealias Action = ApsidesWorkshopAction
    typealias Solver = ApsidesWorkshopSolver
    typealias Sky = ApsidesWorkshopSky
    typealias Generated = ApsidesWorkshopGenerated

    /// The seed of the random orbits and pairs.
    static let seed: UInt64 = 2_472

    // MARK: - Independent helpers

    /// Validity written out from the rules (a(20 − k) ≥ 60, a(20 + k) ≤ 1280, steps in range).
    static func valid(_ a: Int, _ k: Int, _ d: Int) -> Bool {
        a >= 8 && a <= 48 && k >= 0 && k <= 15 && d >= 0 && d <= 23 && a * (20 - k) >= 60 && a * (20 + k) <= 1280
    }

    /// The number of levers (knob, size) in which `orbit` differs from `start`.
    static func levers(_ start: Orbit, _ orbit: Orbit) -> Int {
        let knob: Int = start.eccentricity != orbit.eccentricity || start.direction != orbit.direction ? 1 : 0
        let size: Int = start.size != orbit.size ? 1 : 0
        return knob + size
    }

    /// Every valid orbit differing from `start` in exactly `depth` levers, in the documented order: depth 1 the knob
    /// settings (eccentricity, then direction) then the sizes; depth 2 size, then eccentricity, then direction.
    static func enumerate(_ start: Orbit, depth: Int) -> [Orbit] {
        var knobs: [Orbit] = []
        var sizes: [Orbit] = []
        var both: [Orbit] = []
        for a in 8...48 {
            for k in 0...15 {
                for d in 0...23 where valid(a, k, d) {
                    let orbit: Orbit = Orbit(size: a, eccentricity: k, direction: d)
                    let count: Int = levers(start, orbit)
                    if count == 2 {
                        both.append(orbit)
                    } else if count == 1 && a == start.size {
                        knobs.append(orbit)
                    } else if count == 1 {
                        sizes.append(orbit)
                    }
                }
            }
        }
        if depth == 1 { return knobs + sizes }
        if depth == 2 { return both }
        return []
    }

    /// The full report alone decides (no shortcut).
    static func fullWins(_ level: Level, _ orbit: Orbit) -> Bool {
        Sky.report(level, orbit: orbit).wins
    }

    /// Whether the apsis targets hold, from the orbit's steps (an independent prefilter for long prefixes).
    static func apsesHold(_ level: Level, _ orbit: Orbit) -> Bool {
        for target in level.targets where target.kind != .sweep {
            let peri: Bool = target.kind == .periapsis
            let sector: Int = peri ? orbit.direction / 3 : ((orbit.direction + 12) / 3) % 8
            let distance: Int = peri ? orbit.size * (20 - orbit.eccentricity) : orbit.size * (20 + orbit.eccentricity)
            if sector != target.sector || distance < target.low || distance > target.high { return false }
        }
        return true
    }

    /// A random valid orbit.
    static func randomOrbit(_ random: inout SeededRandom) -> Orbit {
        while true {
            let a: Int = random.int(8...48)
            let k: Int = random.int(0...15)
            let d: Int = random.int(0...23)
            if valid(a, k, d) { return Orbit(size: a, eccentricity: k, direction: d) }
        }
    }

    /// The orbit after `action` from `orbit` (tunings only).
    static func after(_ orbit: Orbit, _ action: Action) -> Orbit {
        switch action {
        case .periapsis(let k, let d): return Orbit(size: orbit.size, eccentricity: k, direction: d)
        case .size(let a): return Orbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
        case .play: return orbit
        }
    }

    // MARK: - Hand levels

    static let start: Orbit = Orbit(size: 20, eccentricity: 5, direction: 0)

    static func hand(_ id: String, _ targets: [Target], start: Orbit = start) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, period: 16, planets: [], targets: targets, orbit: start,
                  budget: 4)
    }

    static func periapsis(_ sector: Int, _ distance: Int) -> Target {
        Target(kind: .periapsis, sector: sector, low: distance, high: distance)
    }

    static func apoapsis(_ sector: Int, _ distance: Int) -> Target {
        Target(kind: .apoapsis, sector: sector, low: distance, high: distance)
    }

    struct HandCase {
        let level: Level
        let actions: [Action]
        let orbit: Orbit
        let work: Int
    }

    static func handCases() throws -> [HandCase] {
        let knob: Level = try hand("hand-knob", [periapsis(2, 300)])
        let size: Level = try hand("hand-size", [apoapsis(4, 750)])
        let both: Level = try hand("hand-both", [periapsis(2, 300), apoapsis(6, 900)])
        let knobFirst: Level = try hand("hand-knob-first", [periapsis(2, 768), apoapsis(6, 1152)],
                                        start: Orbit(size: 40, eccentricity: 8, direction: 0))
        return [
            HandCase(level: knob, actions: [.periapsis(5, 6)], orbit: Orbit(size: 20, eccentricity: 5, direction: 6),
                     work: 127),
            HandCase(level: size, actions: [.size(30)], orbit: Orbit(size: 30, eccentricity: 5, direction: 0),
                     work: 406),
            HandCase(level: both, actions: [.size(30), .periapsis(10, 6)],
                     orbit: Orbit(size: 30, eccentricity: 10, direction: 6), work: 8_545),
            HandCase(level: knobFirst, actions: [.periapsis(4, 6), .size(48)],
                     orbit: Orbit(size: 48, eccentricity: 4, direction: 6), work: 14_023),
        ]
    }

    @Test func handLevelsHaveTheirKnownMinima() throws {
        for item in try Self.handCases() {
            let plan: ApsidesWorkshopPlan = try #require(Solver.plan(item.level), "\(item.level.id)")
            #expect(plan.actions == item.actions, "\(item.level.id)")
            #expect(plan.orbit == item.orbit, "\(item.level.id)")
            #expect(plan.work == item.work, "\(item.level.id)")
            #expect(plan.size == item.actions.count)
            #expect(Solver.replayWins(item.level, actions: plan.actions), "\(item.level.id)")
            #expect(Self.fullWins(item.level, plan.orbit))
            // The independent order puts the plan at index work − 2 of the depth's list (start counted first).
            var expectedByDepth: [Int] = [1]
            var before: Int = 1
            for depth in 1..<max(1, plan.size) {
                let count: Int = Self.enumerate(item.level.orbit, depth: depth).count
                expectedByDepth.append(count)
                before += count
            }
            #expect(plan.orbitsByDepth == expectedByDepth, "\(item.level.id)")
            let list: [Orbit] = Self.enumerate(item.level.orbit, depth: plan.size)
            let index: Int = list.firstIndex(of: plan.orbit) ?? -1
            #expect(before + index + 1 == plan.work, "\(item.level.id)")
        }
    }

    @Test func noOrbitWithFewerLeversWinsAHandLevel() throws {
        for item in try Self.handCases() {
            #expect(!Self.fullWins(item.level, item.level.orbit))
            #expect(!Solver.replayWins(item.level, actions: []))
            if item.actions.count == 2 {
                for orbit in Self.enumerate(item.level.orbit, depth: 1) {
                    #expect(!Self.fullWins(item.level, orbit), "\(item.level.id) \(orbit)")
                }
                // Either tuning alone does not win through the play either.
                #expect(!Solver.replayWins(item.level, actions: [item.actions[0]]))
            }
        }
    }

    @Test func theKnobFirstOrderIsRequiredWhereSizeFirstIsInvalid() throws {
        let item: HandCase = try Self.handCases()[3]
        #expect(!Orbit(size: 48, eccentricity: 8, direction: 0).isValid)
        #expect(!Solver.replayWins(item.level, actions: [.size(48), .periapsis(4, 6)]))
        #expect(Solver.replayWins(item.level, actions: [.periapsis(4, 6), .size(48)]))
    }

    // MARK: - The orbit lists

    @Test func orbitListsEqualAnIndependentEnumeration() {
        var starts: [Orbit] = [
            Orbit(size: 20, eccentricity: 5, direction: 0), Orbit(size: 20, eccentricity: 0, direction: 0),
            Orbit(size: 8, eccentricity: 0, direction: 0), Orbit(size: 48, eccentricity: 6, direction: 23),
            Orbit(size: 48, eccentricity: 0, direction: 12), Orbit(size: 12, eccentricity: 15, direction: 11),
            Orbit(size: 36, eccentricity: 15, direction: 5), Orbit(size: 40, eccentricity: 8, direction: 0),
        ]
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for _ in 0..<4 { starts.append(Self.randomOrbit(&random)) }
        for start in starts {
            let one: [Orbit] = Solver.orbits(from: start, depth: 1)
            let two: [Orbit] = Solver.orbits(from: start, depth: 2)
            #expect(one == Self.enumerate(start, depth: 1), "\(start)")
            #expect(two == Self.enumerate(start, depth: 2), "\(start)")
            #expect(one.count <= 423 && two.count <= 13_880, "\(start)")
            #expect(Set(one).count == one.count && Set(two).count == two.count)
            #expect(Solver.orbits(from: start, depth: 0).isEmpty && Solver.orbits(from: start, depth: 3).isEmpty)
        }
        #expect(Solver.orbits(from: Orbit(size: 20, eccentricity: 0, direction: 0), depth: 1).count == 423)
        #expect(Solver.orbits(from: Orbit(size: 48, eccentricity: 0, direction: 12), depth: 2).count == 13_880)
    }

    @Test func theLargestCountsOverEveryValidStartAreTheBounds() {
        // Valid knob settings per size and valid sizes per eccentricity, then the counts of every start by arithmetic.
        var knobsAt: [Int: Int] = [:]
        for a in 8...48 {
            var count: Int = 0
            for k in 0...15 where Self.valid(a, k, 0) { count += 24 }
            knobsAt[a] = count
        }
        var largestOne: Int = 0
        var largestTwo: Int = 0
        for a in 8...48 {
            for k in 0...15 where Self.valid(a, k, 0) {
                var one: Int = (knobsAt[a] ?? 0) - 1
                var two: Int = 0
                for b in 8...48 where b != a {
                    let keeps: Int = Self.valid(b, k, 0) ? 1 : 0
                    one += keeps
                    two += (knobsAt[b] ?? 0) - keeps
                }
                largestOne = max(largestOne, one)
                largestTwo = max(largestTwo, two)
            }
        }
        #expect(largestOne == 423)
        #expect(largestTwo == 13_880)
        #expect(1 + largestOne + largestTwo <= Solver.workBound)
    }

    // MARK: - Generated levels

    /// One generated level of the first entry of every band (no previous level).
    static let generated: [Generated] = {
        var result: [Generated] = []
        for band in 1...5 {
            guard let entry = ApsidesWorkshopManifest.entries.first(where: { $0.band == band }) else { continue }
            if let level = try? ApsidesWorkshopGenerator.generate(entry, previous: nil) { result.append(level) }
        }
        return result
    }()

    @Test func everyBandGeneratesALevel() {
        #expect(Self.generated.count == 5)
        var sizes: Set<Int> = []
        for item in Self.generated { sizes.insert(item.plan.size) }
        #expect(sizes == [1, 2])
    }

    @Test func theApsisShortcutAgreesWithTheFullReport() {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var levels: [Level] = Self.generated.map(\.level)
        if let cases = try? Self.handCases() { levels += cases.map(\.level) }
        var winsSeen: Int = 0
        var prunedSeen: Int = 0
        for level in levels {
            var orbits: [Orbit] = []
            for _ in 0..<80 { orbits.append(Self.randomOrbit(&random)) }
            if let plan = Solver.plan(level) {
                // The winner and its neighbours: every direction, and the sizes and steps one away.
                let w: Orbit = plan.orbit
                for d in 0...23 { orbits.append(Orbit(size: w.size, eccentricity: w.eccentricity, direction: d)) }
                for delta in [-2, -1, 1, 2] {
                    orbits.append(Orbit(size: w.size + delta, eccentricity: w.eccentricity, direction: w.direction))
                    orbits.append(Orbit(size: w.size, eccentricity: w.eccentricity + delta, direction: w.direction))
                }
            }
            for orbit in orbits where orbit.isValid {
                let full: Bool = Self.fullWins(level, orbit)
                #expect(Solver.wins(level, orbit: orbit) == full, "\(level.id) \(orbit)")
                if full { winsSeen += 1 }
                if !Self.apsesHold(level, orbit) { prunedSeen += 1 }
            }
        }
        #expect(winsSeen >= levels.count)
        #expect(prunedSeen > 0)
    }

    @Test func noOrbitWithFewerTuningsWinsAGeneratedLevel() {
        for item in Self.generated {
            let level: Level = item.level
            let plan: ApsidesWorkshopPlan = item.plan
            #expect(Solver.plan(level) == plan, "\(level.id)")
            #expect(Solver.replayWins(level, actions: plan.actions), "\(level.id)")
            #expect(Self.fullWins(level, plan.orbit))
            #expect(Self.levers(level.orbit, plan.orbit) == plan.size)
            #expect(Solver.tunings(from: level.orbit, to: plan.orbit) == plan.actions)
            #expect(!Self.fullWins(level, level.orbit), "\(level.id)")
            var expectedByDepth: [Int] = [1]
            for depth in 1..<max(1, plan.size) {
                let list: [Orbit] = Self.enumerate(level.orbit, depth: depth)
                expectedByDepth.append(list.count)
                for orbit in list {
                    #expect(!Self.fullWins(level, orbit), "\(level.id) \(orbit)")
                }
            }
            #expect(plan.orbitsByDepth == expectedByDepth, "\(level.id)")
            #expect(plan.orbitsSearched == expectedByDepth.reduce(0, +))
        }
    }

    @Test func thePlanIsTheFirstWinningOrbitInTheFixedOrder() {
        for item in Self.generated {
            let level: Level = item.level
            let plan: ApsidesWorkshopPlan = item.plan
            let list: [Orbit] = Self.enumerate(level.orbit, depth: plan.size)
            let index: Int? = list.firstIndex(of: plan.orbit)
            #expect(index != nil, "\(level.id)")
            guard let index else { continue }
            #expect(plan.work == plan.orbitsSearched + index + 1, "\(level.id)")
            // Every orbit before it loses: the apsis prefilter rejects most; the full report judges the rest.
            for position in 0..<index where Self.apsesHold(level, list[position]) {
                #expect(!Self.fullWins(level, list[position]), "\(level.id) \(list[position])")
            }
        }
    }

    // MARK: - Tuning order and the work bound

    @Test func everyTwoTuningOrderPassesOnlyValidOrbits() {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var sizeFirst: Int = 0
        var knobFirst: Int = 0
        var otherOrderInvalid: Int = 0
        var pairs: Int = 0
        while pairs < 4_000 {
            let start: Orbit = Self.randomOrbit(&random)
            let target: Orbit = Self.randomOrbit(&random)
            let count: Int = Self.levers(start, target)
            let actions: [Action] = Solver.tunings(from: start, to: target)
            #expect(actions.count == count, "\(start) \(target)")
            var orbit: Orbit = start
            for action in actions {
                orbit = Self.after(orbit, action)
                #expect(orbit.isValid, "\(start) \(target) \(actions)")
            }
            #expect(orbit == target)
            guard count == 2 else { continue }
            pairs += 1
            let viaSize: Orbit = Orbit(size: target.size, eccentricity: start.eccentricity, direction: start.direction)
            let viaKnob: Orbit = Orbit(size: start.size, eccentricity: target.eccentricity, direction: target.direction)
            if case .size = actions[0] {
                sizeFirst += 1
                #expect(target.eccentricity >= start.eccentricity)
                if !viaKnob.isValid { otherOrderInvalid += 1 }
            } else {
                knobFirst += 1
                #expect(target.eccentricity < start.eccentricity)
                if !viaSize.isValid { otherOrderInvalid += 1 }
            }
        }
        #expect(sizeFirst > 0 && knobFirst > 0)
        #expect(otherOrderInvalid > 0)
    }

    @Test func theWorkBoundIsRespected() throws {
        var levels: [Level] = Self.generated.map(\.level)
        levels += try Self.handCases().map(\.level)
        for level in levels {
            let plan: ApsidesWorkshopPlan = try #require(Solver.plan(level), "\(level.id)")
            #expect(plan.work <= Solver.workBound)
            #expect(Solver.plan(level, workBound: plan.work - 1) == nil, "\(level.id)")
            #expect(Solver.plan(level, workBound: plan.work) == plan, "\(level.id)")
            #expect(Solver.plan(level, workBound: 1) == nil)
        }
    }

    @Test func aLevelWithoutAPlanWithinTwoTuningsGivesNil() throws {
        // Periapsis distance 300 and apoapsis 901 need a(20 − k) = 300 and a(20 + k) = 901: no whole steps.
        let level: Level = try Self.hand("hand-none", [Self.periapsis(2, 300), Self.apoapsis(6, 901)])
        #expect(Solver.plan(level) == nil)
    }
}
