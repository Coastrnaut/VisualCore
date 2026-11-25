// CelestialEclipseLabSkyTests — feature 461 (R02-G17-01) T-R02G1701-003 (FR-R02G1701-001, 002, 004, 005, 014;
// SC-R02G1701-003, 004; clarifications Q1, Q3). The exact sky against an independent recomputation: on 500 seeded
// levels (the fixtures of seed 2_461), each with its starting phases, its winning phases and two random phase vectors
// drawn from SeededRandom(seed: 2_461 + level index), every body position, overlap decision (strict d² < (ra + rb)²),
// depth order, visibility class, eclipse interval (first tick, last tick, deepest class), the timeline order (first
// tick, then front body, then back body), the matched prefix and the judge's outcome (match, window, unwanted, horizon;
// events after the last match ignored) equal a recomputation here by direct enumeration of every tick and every pair;
// the recomputation never calls `CelestialEclipseLabSky`. The 500 levels run in five tests of 100. Hand cases on tiny
// levels: a distance one unit inside the radius sum and exactly on it (touching is no eclipse), an eclipse under way at
// tick 0, an interval ending on the horizon's last tick, two events on one tick ordered by front then back, each class
// at its boundary and the deepest class of a run, an event on a window's opening and closing tick and one tick outside
// each, an unwanted event first, the horizon failure naming the next target, and events after the last match ignored.
// Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabSkyTests {
    /// The independent reference computations of this file (they never call `CelestialEclipseLabSky`).
    private enum Reference {
        /// The seed of the fixtures and of the random phase vectors.
        static let seed: UInt64 = 2_461
        /// The number of seeded levels.
        static let levelCount: Int = 500
        /// The levels per test.
        static let groupSize: Int = 100
        /// The seeded fixtures, built once.
        static let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: levelCount)

        /// The position of `body` at `tick` (≥ 0) with `phase` (≥ 0), found by stepping along the orbit.
        static func position(_ body: CelestialEclipseLabBody, tick: Int, phase: Int) -> CelestialEclipseLabVector {
            var index: Int = tick + phase
            while index >= body.orbit.count { index -= body.orbit.count }
            return body.orbit[index]
        }

        /// Whether body `a` is in front of body `b`: every depth of `a` exceeds every depth of `b`.
        static func isFront(_ level: CelestialEclipseLabLevel, _ a: Int, _ b: Int) -> Bool {
            for pa in level.bodies[a].orbit {
                for pb in level.bodies[b].orbit {
                    if pa.z <= pb.z { return false }
                }
            }
            return true
        }

        /// The squared projected distance of bodies `a` and `b` at `tick`.
        static func squaredDistance(_ level: CelestialEclipseLabLevel, _ a: Int, _ b: Int, tick: Int,
                                    phases: [Int]) -> Int {
            let pa: CelestialEclipseLabVector = position(level.bodies[a], tick: tick, phase: phases[a])
            let pb: CelestialEclipseLabVector = position(level.bodies[b], tick: tick, phase: phases[b])
            let dx: Int = pa.x - pb.x
            let dy: Int = pa.y - pb.y
            return dx * dx + dy * dy
        }

        /// Whether bodies `a` and `b` overlap at `tick`: strictly closer than the sum of their radii.
        static func overlaps(_ level: CelestialEclipseLabLevel, _ a: Int, _ b: Int, tick: Int, phases: [Int]) -> Bool {
            let reach: Int = level.bodies[a].radius + level.bodies[b].radius
            return squaredDistance(level, a, b, tick: tick, phases: phases) < reach * reach
        }

        /// The class of one eclipse tick of a front disc of radius `rf` over a back disc of radius `rb` at squared
        /// distance `d2`.
        static func visibility(rf: Int, rb: Int, d2: Int) -> CelestialEclipseLabVisibility {
            if rf >= rb {
                if d2 <= (rf - rb) * (rf - rb) { return .total }
                return .partial
            }
            if d2 <= (rb - rf) * (rb - rf) { return .annular }
            return .partial
        }

        /// The intervals of one front–back pair over every tick of the horizon, in tick order.
        static func pairIntervals(_ level: CelestialEclipseLabLevel, front: Int, back: Int,
                                  phases: [Int]) -> [CelestialEclipseLabInterval] {
            var marks: [Bool] = []
            for tick in 0..<level.horizon {
                marks.append(overlaps(level, front, back, tick: tick, phases: phases))
            }
            var result: [CelestialEclipseLabInterval] = []
            var tick: Int = 0
            while tick < level.horizon {
                if !marks[tick] {
                    tick += 1
                    continue
                }
                let first: Int = tick
                var deep: Bool = false
                var deepClass: CelestialEclipseLabVisibility = .partial
                while tick < level.horizon && marks[tick] {
                    let d2: Int = squaredDistance(level, front, back, tick: tick, phases: phases)
                    let now: CelestialEclipseLabVisibility = visibility(rf: level.bodies[front].radius,
                                                                        rb: level.bodies[back].radius, d2: d2)
                    if !deep && now != .partial {
                        deep = true
                        deepClass = now
                    }
                    tick += 1
                }
                result.append(CelestialEclipseLabInterval(front: front, back: back, first: first, last: tick - 1,
                                                          visibility: deepClass))
            }
            return result
        }

        /// Every interval of `level` with `phases`, emitted by scanning ticks, then front bodies, then back bodies.
        static func intervals(_ level: CelestialEclipseLabLevel, phases: [Int]) -> [CelestialEclipseLabInterval] {
            let count: Int = level.bodies.count
            var all: [CelestialEclipseLabInterval] = []
            for a in 0..<count {
                for b in 0..<count where a != b && isFront(level, a, b) {
                    all += pairIntervals(level, front: a, back: b, phases: phases)
                }
            }
            var ordered: [CelestialEclipseLabInterval] = []
            for tick in 0..<level.horizon {
                for front in 0..<count {
                    for back in 0..<count {
                        for interval in all where interval.first == tick && interval.front == front
                            && interval.back == back {
                            ordered.append(interval)
                        }
                    }
                }
            }
            return ordered
        }

        /// The judge over `ordered`: the matched prefix of the target and the failure (nil for a win).
        static func judge(_ level: CelestialEclipseLabLevel,
                          _ ordered: [CelestialEclipseLabInterval]) -> (Int, CelestialEclipseLabFailure?) {
            var matched: Int = 0
            for event in ordered {
                if matched == level.target.count { return (matched, nil) }
                let next: CelestialEclipseLabTarget = level.target[matched]
                let samePair: Bool = event.front == next.front && event.back == next.back
                if !samePair {
                    return (matched, .unwanted(front: event.front, back: event.back, tick: event.first))
                }
                if event.first < next.open || event.first > next.close {
                    return (matched, .window(front: next.front, back: next.back, tick: event.first, open: next.open,
                                             close: next.close))
                }
                matched += 1
            }
            if matched < level.target.count {
                let next: CelestialEclipseLabTarget = level.target[matched]
                return (matched, .horizon(front: next.front, back: next.back, open: next.open, close: next.close))
            }
            return (matched, nil)
        }

        /// The number of disagreements between the sky and the reference for `level` with `phases`: positions,
        /// overlaps, depth orders, classes, intervals, matched prefix and failure.
        static func mismatches(_ level: CelestialEclipseLabLevel, phases: [Int]) -> Int {
            var wrong: Int = 0
            let count: Int = level.bodies.count
            for body in 0..<count {
                for tick in 0..<level.horizon {
                    let expected: CelestialEclipseLabVector = position(level.bodies[body], tick: tick,
                                                                       phase: phases[body])
                    if level.bodies[body].position(at: tick, phase: phases[body]) != expected { wrong += 1 }
                }
            }
            for i in 0..<count {
                for j in (i + 1)..<max(count, i + 1) {
                    let front: Int = isFront(level, i, j) ? i : j
                    let back: Int = front == i ? j : i
                    let order: (front: Int, back: Int) = CelestialEclipseLabSky.order(level, i, j)
                    if order.front != front || order.back != back { wrong += 1 }
                    for tick in 0..<level.horizon {
                        let expected: Bool = overlaps(level, i, j, tick: tick, phases: phases)
                        let actual: Bool = CelestialEclipseLabSky.eclipses(level.bodies[i], level.bodies[j], at: tick,
                                                                           phases: (phases[i], phases[j]))
                        if actual != expected { wrong += 1 }
                        if expected {
                            let d2: Int = squaredDistance(level, front, back, tick: tick, phases: phases)
                            let rf: Int = level.bodies[front].radius
                            let rb: Int = level.bodies[back].radius
                            let seen: CelestialEclipseLabVisibility = CelestialEclipseLabSky.visibility(
                                front: level.bodies[front], back: level.bodies[back], squaredDistance: d2)
                            if seen != visibility(rf: rf, rb: rb, d2: d2) { wrong += 1 }
                        }
                    }
                }
            }
            let ordered: [CelestialEclipseLabInterval] = intervals(level, phases: phases)
            if CelestialEclipseLabSky.intervals(level, phases: phases) != ordered { wrong += 1 }
            let verdict: (Int, CelestialEclipseLabFailure?) = judge(level, ordered)
            let timeline: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(level, phases: phases)
            if timeline.intervals != ordered { wrong += 1 }
            if timeline.matched != verdict.0 { wrong += 1 }
            if timeline.failure != verdict.1 { wrong += 1 }
            if timeline.wins != (verdict.1 == nil) { wrong += 1 }
            return wrong
        }

        /// Checks levels `group * groupSize` … `(group + 1) * groupSize − 1`: the starting phases (never a win), the
        /// winning phases (always a win) and two random phase vectors each.
        static func checkGroup(_ group: Int) {
            var events: Int = 0
            for index in (group * groupSize)..<((group + 1) * groupSize) {
                let fixture: CelestialEclipseLabFixture = fixtures[index]
                let level: CelestialEclipseLabLevel = fixture.level
                var random: SeededRandom = SeededRandom(seed: seed &+ UInt64(index))
                var vectors: [[Int]] = [level.phases, fixture.winning]
                for _ in 0..<2 {
                    var phases: [Int] = []
                    for body in level.bodies { phases.append(random.int(0...(body.period - 1))) }
                    vectors.append(phases)
                }
                for phases in vectors {
                    let wrong: Int = mismatches(level, phases: phases)
                    #expect(wrong == 0, "level \(level.id) phases \(phases): \(wrong) mismatches")
                    events += intervals(level, phases: phases).count
                }
                #expect(judge(level, intervals(level, phases: level.phases)).1 != nil, "level \(level.id) starts won")
                #expect(judge(level, intervals(level, phases: fixture.winning)).1 == nil,
                        "level \(level.id) winning phases do not win")
            }
            #expect(events > 0)
        }
    }

    // MARK: - Hand-built levels

    /// A body standing still at (`x`, `y`, `z`): four equal orbit positions.
    static func still(_ x: Int, _ y: Int, z: Int, radius: Int, fixed: Bool = false) -> CelestialEclipseLabBody {
        var orbit: [CelestialEclipseLabVector] = []
        for _ in 0..<4 { orbit.append(CelestialEclipseLabVector(x, y, z)) }
        return CelestialEclipseLabBody(orbit: orbit, radius: radius, fixed: fixed)
    }

    /// A body moving through the projected `points` at depth `z`.
    static func path(_ points: [(Int, Int)], z: Int, radius: Int, fixed: Bool = false) -> CelestialEclipseLabBody {
        var orbit: [CelestialEclipseLabVector] = []
        for point in points { orbit.append(CelestialEclipseLabVector(point.0, point.1, z)) }
        return CelestialEclipseLabBody(orbit: orbit, radius: radius, fixed: fixed)
    }

    /// A body of period 8 far away (x = `away`) except at orbit index 0, where it stands at the origin, at depth `z`.
    static func blink(z: Int, radius: Int, away: Int = 20) -> CelestialEclipseLabBody {
        var points: [(Int, Int)] = [(0, 0)]
        for _ in 1..<8 { points.append((away, 0)) }
        return path(points, z: z, radius: radius)
    }

    /// A probe level of `bodies` (horizon 8 by default) that skips the "already won" rule; without a target, the
    /// target is body 0 in front of body 1 over the whole horizon.
    static func probe(_ bodies: [CelestialEclipseLabBody], horizon: Int = 8, target: [CelestialEclipseLabTarget]? = nil,
                      phases: [Int]? = nil) throws -> CelestialEclipseLabLevel {
        var start: [Int] = []
        for _ in bodies { start.append(0) }
        let whole: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 0,
                                                                            close: horizon - 1)]
        return try CelestialEclipseLabLevel.probe(bodies: bodies, horizon: horizon, target: target ?? whole,
                                                  phases: phases ?? start)
    }

    // MARK: - Seeded levels against the reference

    @Test func seededLevels0To99MatchTheReference() { Reference.checkGroup(0) }

    @Test func seededLevels100To199MatchTheReference() { Reference.checkGroup(1) }

    @Test func seededLevels200To299MatchTheReference() { Reference.checkGroup(2) }

    @Test func seededLevels300To399MatchTheReference() { Reference.checkGroup(3) }

    @Test func seededLevels400To499MatchTheReference() { Reference.checkGroup(4) }

    // MARK: - Hand cases

    @Test func touchingDiscsDoNotEclipseAndOneUnitInsideDoes() throws {
        let front: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: 2, fixed: true)
        // Radii 2 + 3: reach 5, so squared reach 25.
        let cases: [(Int, Int, Bool)] = [(4, 0, true), (5, 0, false), (6, 0, false), (3, 4, false), (3, 3, true),
                                         (0, -5, false), (0, -4, true)]
        for item in cases {
            let back: CelestialEclipseLabBody = Self.still(item.0, item.1, z: 0, radius: 3)
            let level: CelestialEclipseLabLevel = try Self.probe([front, back])
            #expect(CelestialEclipseLabSky.eclipses(front, back, at: 0, phases: (0, 0)) == item.2, "at \(item)")
            let intervals: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: [0, 0])
            #expect(intervals.count == (item.2 ? 1 : 0), "at \(item)")
        }
        // Radii 1 + 2: reach 3; squared distance 8 = 9 − 1 eclipses, 9 touches.
        let small: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: 1, fixed: true)
        #expect(CelestialEclipseLabSky.eclipses(small, Self.still(2, 2, z: 0, radius: 2), at: 0, phases: (0, 0)))
        #expect(!CelestialEclipseLabSky.eclipses(small, Self.still(3, 0, z: 0, radius: 2), at: 0, phases: (0, 0)))
        // Touching for the whole horizon leaves no event: the target is never met.
        let touching: CelestialEclipseLabLevel = try Self.probe([front, Self.still(3, 4, z: 0, radius: 3)])
        let timeline: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(touching, phases: [0, 0])
        #expect(timeline.intervals.isEmpty && timeline.matched == 0)
        #expect(timeline.failure == .horizon(front: 0, back: 1, open: 0, close: 7))
    }

    @Test func anEclipseUnderWayAtTickZeroStartsThereAndOneMayEndOnTheLastTick() throws {
        let front: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: 2, fixed: true)
        let back: CelestialEclipseLabBody = Self.path([(4, 0), (4, 0), (9, 0), (9, 0)], z: 0, radius: 3)
        let level: CelestialEclipseLabLevel = try Self.probe([front, back])
        let atZero: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: [0, 0])
        #expect(atZero == [
            CelestialEclipseLabInterval(front: 0, back: 1, first: 0, last: 1, visibility: .partial),
            CelestialEclipseLabInterval(front: 0, back: 1, first: 4, last: 5, visibility: .partial),
        ])
        let shifted: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: [0, 2])
        #expect(shifted == [
            CelestialEclipseLabInterval(front: 0, back: 1, first: 2, last: 3, visibility: .partial),
            CelestialEclipseLabInterval(front: 0, back: 1, first: 6, last: 7, visibility: .partial),
        ])
        // A body that never leaves gives one interval over the whole horizon.
        let still: CelestialEclipseLabLevel = try Self.probe([front, Self.still(1, 0, z: 0, radius: 3)])
        #expect(CelestialEclipseLabSky.intervals(still, phases: [0, 0]) == [
            CelestialEclipseLabInterval(front: 0, back: 1, first: 0, last: 7, visibility: .annular),
        ])
    }

    @Test func twoEventsOnOneTickAreOrderedByFrontThenBack() throws {
        // Body 0 is the farthest, body 2 the nearest; all three meet at the origin on ticks 2 and 6.
        let far: CelestialEclipseLabBody = Self.still(0, 0, z: 0, radius: 1)
        let middle: CelestialEclipseLabBody = Self.path([(20, 0), (20, 0), (0, 0), (20, 0)], z: 10, radius: 1)
        let near: CelestialEclipseLabBody = Self.path([(-20, 0), (-20, 0), (0, 0), (-20, 0)], z: 20, radius: 1)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 1, back: 0, open: 2, close: 2),
                                                   CelestialEclipseLabTarget(front: 2, back: 0, open: 2, close: 2)]
        let level: CelestialEclipseLabLevel = try Self.probe([far, middle, near], target: target)
        let intervals: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: [0, 0, 0])
        var expected: [CelestialEclipseLabInterval] = []
        for tick in [2, 6] {
            expected.append(CelestialEclipseLabInterval(front: 1, back: 0, first: tick, last: tick, visibility: .total))
            expected.append(CelestialEclipseLabInterval(front: 2, back: 0, first: tick, last: tick, visibility: .total))
            expected.append(CelestialEclipseLabInterval(front: 2, back: 1, first: tick, last: tick, visibility: .total))
        }
        #expect(intervals == expected)
        // The target in event order wins (the third event on tick 2 comes after the last match and is ignored).
        let wins: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(level, phases: [0, 0, 0])
        #expect(wins.wins && wins.matched == 2)
        // The same two eclipses in the other order: the first event (body 1 in front of body 0) is unwanted.
        let reversed: [CelestialEclipseLabTarget] = [target[1], target[0]]
        let other: CelestialEclipseLabLevel = try Self.probe([far, middle, near], target: reversed)
        let fails: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(other, phases: [0, 0, 0])
        #expect(fails.matched == 0 && fails.failure == .unwanted(front: 1, back: 0, tick: 2))
    }

    @Test func eachVisibilityClassAtItsBoundary() throws {
        // (front radius, back radius, x, y, class).
        let cases: [(Int, Int, Int, Int, CelestialEclipseLabVisibility)] = [
            (3, 1, 0, 0, .total), (3, 1, 2, 0, .total), (3, 1, 2, 1, .partial), (3, 1, 3, 0, .partial),
            (2, 2, 0, 0, .total), (2, 2, 1, 0, .partial),
            (1, 3, 2, 0, .annular), (1, 3, 1, 1, .annular), (1, 3, 2, 1, .partial),
            (1, 2, 1, 0, .annular), (1, 2, 1, 1, .partial), (1, 2, 0, 0, .annular),
        ]
        for item in cases {
            let front: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: item.0, fixed: true)
            let back: CelestialEclipseLabBody = Self.still(item.2, item.3, z: 0, radius: item.1)
            let d2: Int = item.2 * item.2 + item.3 * item.3
            #expect(CelestialEclipseLabSky.visibility(front: front, back: back, squaredDistance: d2) == item.4,
                    "case \(item)")
            let level: CelestialEclipseLabLevel = try Self.probe([front, back])
            let intervals: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(level, phases: [0, 0])
            #expect(intervals == [CelestialEclipseLabInterval(front: 0, back: 1, first: 0, last: 7,
                                                              visibility: item.4)], "case \(item)")
        }
    }

    @Test func anIntervalTakesTheDeepestClassOfItsTicks() throws {
        // Partial, deep, partial, apart: the run of ticks 0 … 2 (and 4 … 6) takes the deep class.
        let points: [(Int, Int)] = [(3, 0), (2, 0), (3, 0), (10, 0)]
        let total: CelestialEclipseLabLevel = try Self.probe([Self.still(0, 0, z: 10, radius: 3, fixed: true),
                                                              Self.path(points, z: 0, radius: 1)])
        #expect(CelestialEclipseLabSky.intervals(total, phases: [0, 0]) == [
            CelestialEclipseLabInterval(front: 0, back: 1, first: 0, last: 2, visibility: .total),
            CelestialEclipseLabInterval(front: 0, back: 1, first: 4, last: 6, visibility: .total),
        ])
        let annular: CelestialEclipseLabLevel = try Self.probe([Self.still(0, 0, z: 10, radius: 1, fixed: true),
                                                                Self.path(points, z: 0, radius: 3)])
        #expect(CelestialEclipseLabSky.intervals(annular, phases: [0, 0]) == [
            CelestialEclipseLabInterval(front: 0, back: 1, first: 0, last: 2, visibility: .annular),
            CelestialEclipseLabInterval(front: 0, back: 1, first: 4, last: 6, visibility: .annular),
        ])
        // Deep first, then partial: still deep.
        let early: CelestialEclipseLabLevel = try Self.probe([Self.still(0, 0, z: 10, radius: 3, fixed: true),
                                                              Self.path(points, z: 0, radius: 1)])
        #expect(CelestialEclipseLabSky.intervals(early, phases: [0, 1]).first?.visibility == .total)
        // Never deep: partial.
        let grazing: [(Int, Int)] = [(3, 0), (3, 1), (3, 0), (10, 0)]
        let shallow: CelestialEclipseLabLevel = try Self.probe([Self.still(0, 0, z: 10, radius: 2, fixed: true),
                                                                Self.path(grazing, z: 0, radius: 2)])
        #expect(CelestialEclipseLabSky.intervals(shallow, phases: [0, 0]).first?.visibility == .partial)
    }

    @Test func anEventOnEachEndOfTheWindowMatchesAndOneTickOutsideFails() throws {
        let front: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: 1, fixed: true)
        let back: CelestialEclipseLabBody = Self.blink(z: 0, radius: 1)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 3, close: 5)]
        // With phase p the only event is at tick (8 − p) mod 8.
        for tick in [3, 4, 5] {
            let phases: [Int] = [0, (8 - tick) % 8]
            let level: CelestialEclipseLabLevel = try Self.probe([front, back], target: target, phases: phases)
            let timeline: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(level, phases: phases)
            #expect(timeline.intervals.count == 1 && timeline.intervals[0].first == tick)
            #expect(timeline.wins && timeline.matched == 1, "event at tick \(tick)")
        }
        for tick in [2, 6, 0, 7] {
            let phases: [Int] = [0, (8 - tick) % 8]
            // Not a win, so the public initialiser accepts these starting phases.
            let level: CelestialEclipseLabLevel = try CelestialEclipseLabLevel(
                id: "window-\(tick)", seed: 0, difficulty: 1, bodies: [front, back], horizon: 8, target: target,
                phases: phases, budget: 1)
            let timeline: CelestialEclipseLabTimeline = level.startTimeline
            #expect(timeline.matched == 0, "event at tick \(tick)")
            #expect(timeline.failure == .window(front: 0, back: 1, tick: tick, open: 3, close: 5),
                    "event at tick \(tick)")
            #expect(timeline.failure?.code == "window")
        }
    }

    @Test func anUnwantedEventFirstFails() throws {
        // Body 0 nearest and still; body 1 meets it on tick 1, body 2 on tick 3; the target wants body 2 first.
        let near: CelestialEclipseLabBody = Self.still(0, 0, z: 20, radius: 1, fixed: true)
        let one: CelestialEclipseLabBody = Self.blink(z: 10, radius: 1)
        let two: CelestialEclipseLabBody = Self.blink(z: 0, radius: 1, away: -20)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 2, open: 0, close: 7)]
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabLevel(
            id: "unwanted", seed: 0, difficulty: 1, bodies: [near, one, two], horizon: 8, target: target,
            phases: [0, 7, 5], budget: 1)
        let timeline: CelestialEclipseLabTimeline = level.startTimeline
        #expect(timeline.intervals.map(\.first) == [1, 3])
        #expect(timeline.matched == 0 && timeline.failure == .unwanted(front: 0, back: 1, tick: 1))
        #expect(timeline.failure?.code == "unwanted")
        // After one match, an event of another pair is unwanted with the matched prefix kept.
        let two0: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 0, close: 7),
                                                 CelestialEclipseLabTarget(front: 1, back: 2, open: 0, close: 7)]
        let later: CelestialEclipseLabLevel = try Self.probe([near, one, two], target: two0, phases: [0, 7, 5])
        let after: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(later, phases: [0, 7, 5])
        #expect(after.matched == 1 && after.failure == .unwanted(front: 0, back: 2, tick: 3))
    }

    @Test func theHorizonFailureNamesTheNextTarget() throws {
        let front: CelestialEclipseLabBody = Self.still(0, 0, z: 10, radius: 1, fixed: true)
        let back: CelestialEclipseLabBody = Self.blink(z: 0, radius: 1)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 1, close: 3),
                                                   CelestialEclipseLabTarget(front: 0, back: 1, open: 5, close: 7)]
        // One event on tick 2 matches the first target; nothing comes for the second.
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabLevel(
            id: "horizon", seed: 0, difficulty: 1, bodies: [front, back], horizon: 8, target: target, phases: [0, 6],
            budget: 1)
        let timeline: CelestialEclipseLabTimeline = level.startTimeline
        #expect(timeline.matched == 1 && timeline.failure == .horizon(front: 0, back: 1, open: 5, close: 7))
        #expect(timeline.failure?.code == "horizon")
        // No event at all: the first target is named.
        let apart: CelestialEclipseLabLevel = try Self.probe([front, Self.still(20, 0, z: 0, radius: 1)],
                                                             target: target)
        let none: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(apart, phases: [0, 0])
        #expect(none.intervals.isEmpty && none.matched == 0)
        #expect(none.failure == .horizon(front: 0, back: 1, open: 1, close: 3))
    }

    @Test func eventsAfterTheLastMatchAreIgnored() throws {
        // Body 1 meets body 0 on tick 1; body 2 meets body 0 on ticks 3 and 7; only the first is the target.
        let near: CelestialEclipseLabBody = Self.still(0, 0, z: 20, radius: 1, fixed: true)
        let one: CelestialEclipseLabBody = Self.blink(z: 10, radius: 1)
        let two: CelestialEclipseLabBody = Self.path([(-20, 0), (-20, 0), (-20, 0), (0, 0)], z: 0, radius: 1)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: 0, back: 1, open: 0, close: 1)]
        let level: CelestialEclipseLabLevel = try Self.probe([near, one, two], target: target, phases: [0, 7, 0])
        let timeline: CelestialEclipseLabTimeline = CelestialEclipseLabSky.timeline(level, phases: [0, 7, 0])
        #expect(timeline.intervals.map(\.first) == [1, 3, 7])
        #expect(timeline.intervals[0] == CelestialEclipseLabInterval(front: 0, back: 1, first: 1, last: 1,
                                                                     visibility: .total))
        #expect(timeline.wins && timeline.matched == 1 && timeline.failure == nil)
    }
}
