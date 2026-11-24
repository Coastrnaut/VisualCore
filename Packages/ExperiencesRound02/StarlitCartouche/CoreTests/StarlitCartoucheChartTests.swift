// StarlitCartoucheChartTests — feature 451 (R02-G16-01) T-R02G1601-003 (FR-R02G1601-002, 003, 004, 014;
// SC-R02G1601-003, 004; clarifications Q1 … Q4). The exact star chart against an independent recomputation: on 500
// seeded levels (250 fixtures and 250 levels built here from seed 2_451 with moving orbits, small ranges, tight windows
// and hazards on any corridor, symbol strokes included) and random leg sequences (random destination stars, unknown
// ones included, and random waits, out-of-range ones included), every star position, flyability, refusal, departure
// and arrival beat, hazard meeting (decided by listing every beat of [t₀, t₁] against every beat of each hazard
// interval on the same corridor), window and deadline decision, the failure order (departure, hazard, arrival,
// deadline, stroke), drawn set, missing, stray, mismatch, clearance (the least |beat − hazard beat| over the listed
// beats) and match equal `StarlitCartoucheChart`'s results. Hand cases: a range one unit inside and outside, a hazard
// one beat clear of and touching each end of a leg, arrival exactly on open, close and the deadline and one beat
// outside, departure on the origin's close and one beat after, a retraced stroke drawn once, a stray stroke, the wait
// range 0 … 8, and unknown star, same star and no corridor refusals. Explicit types and plain loops keep the type
// checker fast on CI.
//
// A star's window may close after the level's deadline (close ≤ 64), so a leg arriving after the deadline inside its
// target's window fails `deadline`; the tight levels draw such windows and every failure kind is seen.
import Foundation
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheChartTests {
    /// The independent reference computations and seeded level builders of this file.
    private enum Reference {
        /// The seed of the levels and leg sequences built here.
        static let seed: UInt64 = 2_451

        /// Star `star`'s position at `beat` (≥ 0): orbit[beat mod length], computed directly.
        static func position(_ level: StarlitCartoucheLevel, star: Int, beat: Int) -> StarlitCartoucheVector {
            let orbit: [StarlitCartoucheVector] = level.stars[star].orbit
            return orbit[beat % orbit.count]
        }

        /// The squared distance between stars `a` and `b` at `beat`.
        static func squaredDistance(_ level: StarlitCartoucheLevel, _ a: Int, _ b: Int, beat: Int) -> Int {
            let pa: StarlitCartoucheVector = position(level, star: a, beat: beat)
            let pb: StarlitCartoucheVector = position(level, star: b, beat: beat)
            let dx: Int = pa.x - pb.x
            let dy: Int = pa.y - pb.y
            let dz: Int = pa.z - pb.z
            return dx * dx + dy * dy + dz * dz
        }

        /// The corridor index joining `i` and `j`, by a scan of the corridor list.
        static func corridor(_ level: StarlitCartoucheLevel, _ i: Int, _ j: Int) -> Int? {
            var found: Int? = nil
            for index in level.corridors.indices {
                let c: StarlitCartoucheCorridor = level.corridors[index]
                if (c.a == i && c.b == j) || (c.a == j && c.b == i) {
                    found = index
                    break
                }
            }
            return found
        }

        /// The refusal name of a leg (clarification Q2's order), or nil when it is accepted.
        static func refusal(_ level: StarlitCartoucheLevel, star: Int, beat: Int, destination: Int,
                            wait: Int) -> String? {
            if destination < 0 || destination >= level.stars.count { return "unknown star" }
            if destination == star { return "same star" }
            guard let index = corridor(level, star, destination) else { return "no corridor" }
            if wait < 0 || wait > 8 { return "wait" }
            let c: StarlitCartoucheCorridor = level.corridors[index]
            let distance: Int = squaredDistance(level, c.a, c.b, beat: beat + wait)
            let limit: Int = level.range * level.range
            if distance > limit { return "out of range: \(distance) > \(limit)" }
            return nil
        }

        /// Whether the closed intervals meet, decided by listing every beat of each against every beat of the other.
        static func meets(_ a0: Int, _ a1: Int, _ b0: Int, _ b1: Int) -> Bool {
            for x in a0...a1 {
                for y in b0...b1 where x == y { return true }
            }
            return false
        }

        /// The least |x − y| over every beat x of [a0, a1] and y of [b0, b1], listed one by one.
        static func listedGap(_ a0: Int, _ a1: Int, _ b0: Int, _ b1: Int) -> Int {
            var best: Int = Int.max
            for x in a0...a1 {
                for y in b0...b1 {
                    let d: Int = x > y ? x - y : y - x
                    if d < best { best = d }
                }
            }
            return best
        }

        /// The failure of a leg in the clarified order: departure, hazard, arrival, deadline, stroke.
        static func failure(_ level: StarlitCartoucheLevel, from: Int, to: Int, corridor: Int, depart: Int,
                            arrive: Int) -> StarlitCartoucheFailure? {
            let origin: StarlitCartoucheStar = level.stars[from]
            if depart > origin.close { return .departure(star: from, beat: depart, close: origin.close) }
            for index in level.hazards.indices {
                let h: StarlitCartoucheHazard = level.hazards[index]
                if h.corridor == corridor && meets(depart, arrive, h.from, h.to) {
                    return .hazard(corridor: corridor, hazard: index, from: h.from, to: h.to)
                }
            }
            let target: StarlitCartoucheStar = level.stars[to]
            if arrive < target.open || arrive > target.close {
                return .arrival(star: to, beat: arrive, open: target.open, close: target.close)
            }
            if arrive > level.deadline { return .deadline(beat: arrive, deadline: level.deadline) }
            var inSymbol: Bool = false
            for stroke in level.symbol where stroke == corridor { inSymbol = true }
            if !inSymbol { return .stroke(corridor: corridor) }
            return nil
        }

        /// The tally name of a check result.
        static func kind(_ failure: StarlitCartoucheFailure?) -> String {
            guard let failure else { return "clear" }
            switch failure {
            case .departure: return "failure departure"
            case .hazard: return "failure hazard"
            case .arrival: return "failure arrival"
            case .deadline: return "failure deadline"
            case .stroke: return "failure stroke"
            case .budget: return "failure budget"
            }
        }

        /// The clearance of the flown legs over every hazard on their corridors, nil when none shares one.
        static func clearance(_ level: StarlitCartoucheLevel, legs: [StarlitCartoucheLeg]) -> Int? {
            var best: Int? = nil
            for leg in legs {
                for h in level.hazards where h.corridor == leg.corridor {
                    let g: Int = listedGap(leg.depart, leg.arrive, h.from, h.to)
                    if best == nil || g < best! { best = g }
                }
            }
            return best
        }

        /// The symbol strokes not in `drawn` and the drawn corridors not in the symbol, each ascending.
        static func missingAndStray(_ level: StarlitCartoucheLevel, drawn: [Int]) -> (missing: [Int], stray: [Int]) {
            var missing: [Int] = []
            var stray: [Int] = []
            for index in level.corridors.indices {
                var isStroke: Bool = false
                for stroke in level.symbol where stroke == index { isStroke = true }
                var isDrawn: Bool = false
                for d in drawn where d == index { isDrawn = true }
                if isStroke && !isDrawn { missing.append(index) }
                if isDrawn && !isStroke { stray.append(index) }
            }
            return (missing, stray)
        }

        /// A seeded level with moving orbits, a small range, tight windows and hazards on any corridor, or nil when
        /// the draw breaks a level rule.
        static func tightLevel(_ random: inout SeededRandom, index: Int) -> StarlitCartoucheLevel? {
            let count: Int = random.int(4...8)
            let deadline: Int = random.int(6...40)
            let start: Int = random.int(0...(count - 1))
            var glyphs: [StarlitCartoucheGlyphPoint] = []
            while glyphs.count < count {
                let g: StarlitCartoucheGlyphPoint = StarlitCartoucheGlyphPoint(random.int(0...4), random.int(0...4))
                if !glyphs.contains(g) { glyphs.append(g) }
            }
            var stars: [StarlitCartoucheStar] = []
            for i in 0..<count {
                var orbit: [StarlitCartoucheVector] = []
                let length: Int = random.int(1...4)
                for _ in 0..<length {
                    orbit.append(StarlitCartoucheVector(random.int(-5...5), random.int(-5...5), random.int(-5...5)))
                }
                let open: Int = i == start ? 0 : random.int(0...(deadline / 2))
                let last: Int = random.int(0...2) == 0 ? min(deadline + 8, 64) : deadline
                let close: Int = random.int(open...last)
                stars.append(StarlitCartoucheStar(orbit: orbit, glyph: glyphs[i], open: open, close: close))
            }
            let range: Int = random.int(2...12)
            var corridors: [StarlitCartoucheCorridor] = []
            let attempts: Int = random.int(4...14)
            for _ in 0..<attempts {
                let a: Int = random.int(0...(count - 1))
                let b: Int = random.int(0...(count - 1))
                if a == b { continue }
                var repeated: Bool = false
                for c in corridors where c.joins(a, b) { repeated = true }
                if !repeated { corridors.append(StarlitCartoucheCorridor(a, b, travel: random.int(1...3))) }
            }
            guard !corridors.isEmpty else { return nil }
            var hazards: [StarlitCartoucheHazard] = []
            let hazardCount: Int = random.int(0...5)
            for _ in 0..<hazardCount {
                let from: Int = random.int(0...24)
                hazards.append(StarlitCartoucheHazard(corridor: random.int(0...(corridors.count - 1)), from: from,
                                                      to: from + random.int(0...3)))
            }
            var symbol: [Int] = []
            for c in corridors.indices where random.int(0...1) == 1 && symbol.count < 12 { symbol.append(c) }
            if symbol.isEmpty { symbol.append(0) }
            let beacon: Int = random.int(0...(count - 1))
            do {
                return try StarlitCartoucheLevel(id: "tight-\(index)", seed: UInt64(index),
                                                 difficulty: random.int(1...5), stars: stars, range: range,
                                                 corridors: corridors, hazards: hazards, start: start, beacon: beacon,
                                                 deadline: deadline, symbol: symbol, budget: random.int(1...16))
            } catch {
                return nil
            }
        }

        /// The 500 levels: 250 fixtures (with their known legs) and 250 tight levels (no known legs).
        static func levels() -> [(level: StarlitCartoucheLevel, known: [StarlitCartoucheAction])] {
            var result: [(level: StarlitCartoucheLevel, known: [StarlitCartoucheAction])] = []
            let fixtures: [StarlitCartoucheFixture] = StarlitCartoucheFixture.all(count: 250)
            for fixture in fixtures { result.append((fixture.level, fixture.actions)) }
            var random: SeededRandom = SeededRandom(seed: seed)
            var index: Int = 0
            while result.count < 500 {
                if let level = tightLevel(&random, index: index) { result.append((level, [])) }
                index += 1
            }
            return result
        }

        /// A random destination (mostly a corridor neighbour of `star`, sometimes any index from −1 to n) and wait
        /// (mostly 0 … 8, sometimes −1 or 9).
        static func randomLeg(_ level: StarlitCartoucheLevel, star: Int,
                              _ random: inout SeededRandom) -> (destination: Int, wait: Int) {
            var neighbours: [Int] = []
            for c in level.corridors {
                if c.a == star { neighbours.append(c.b) }
                if c.b == star { neighbours.append(c.a) }
            }
            let destination: Int
            if random.int(0...9) < 7 && !neighbours.isEmpty {
                destination = neighbours[random.int(0...(neighbours.count - 1))]
            } else {
                destination = random.int(-1...level.stars.count)
            }
            let wait: Int
            if random.int(0...9) < 9 {
                wait = random.int(0...8)
            } else {
                wait = random.int(0...1) == 0 ? -1 : 9
            }
            return (destination, wait)
        }

        /// The chart's refusal name, or nil with the leg when accepted.
        static func chartLeg(_ level: StarlitCartoucheLevel, star: Int, beat: Int, destination: Int,
                             wait: Int) -> (leg: StarlitCartoucheLeg?, refusal: String?) {
            do {
                let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: star, at: beat,
                                                                             to: destination, wait: wait)
                return (leg, nil)
            } catch {
                if case .action(let name) = error { return (nil, name) }
                return (nil, "other: \(error)")
            }
        }

        /// A hand level of four stars on given orbits and windows; corridors 0–1 (1 beat), 1–2 (2 beats), 2–3
        /// (1 beat); symbol 0–1 and 1–2; beacon 2.
        static func windowLevel(orbits: [[StarlitCartoucheVector]], windows: [(Int, Int)], range: Int,
                                deadline: Int, hazards: [StarlitCartoucheHazard] = []) throws -> StarlitCartoucheLevel {
            var stars: [StarlitCartoucheStar] = []
            for i in 0..<4 {
                stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: StarlitCartoucheGlyphPoint(i, 0),
                                                  open: windows[i].0, close: windows[i].1))
            }
            let corridors: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(0, 1, travel: 1),
                                                         StarlitCartoucheCorridor(1, 2, travel: 2),
                                                         StarlitCartoucheCorridor(2, 3, travel: 1)]
            return try StarlitCartoucheLevel(id: "window", seed: 1, difficulty: 1, stars: stars, range: range,
                                             corridors: corridors, hazards: hazards, start: 0, beacon: 2,
                                             deadline: deadline, symbol: [0, 1], budget: 8)
        }

        /// Still orbits in a row along x, two units apart.
        static var rowOrbits: [[StarlitCartoucheVector]] {
            var orbits: [[StarlitCartoucheVector]] = []
            for i in 0..<4 { orbits.append([StarlitCartoucheVector(i * 2, 0, 0)]) }
            return orbits
        }
    }

    /// On the 500 levels every star position equals orbit[b mod length] and every corridor's flyability equals the
    /// squared-distance test, for beats 0 … 15.
    @Test func starPositionsAndFlyabilityMatchReference() {
        let levels: [(level: StarlitCartoucheLevel, known: [StarlitCartoucheAction])] = Reference.levels()
        #expect(levels.count == 500)
        var refused: Int = 0
        for entry in levels {
            let level: StarlitCartoucheLevel = entry.level
            for beat in 0..<16 {
                for star in level.stars.indices {
                    #expect(level.stars[star].position(at: beat) == Reference.position(level, star: star, beat: beat),
                            "\(level.id) star \(star) beat \(beat)")
                }
                for index in level.corridors.indices {
                    let c: StarlitCartoucheCorridor = level.corridors[index]
                    let expected: Bool = Reference.squaredDistance(level, c.a, c.b, beat: beat)
                        <= level.range * level.range
                    if !expected { refused += 1 }
                    #expect(StarlitCartoucheChart.flyable(level, corridor: index, at: beat) == expected,
                            "\(level.id) corridor \(index) beat \(beat)")
                }
            }
        }
        #expect(refused > 0, "some corridors are out of range at some beat")
    }

    /// On the 500 levels and their seeded leg sequences (fixtures' known legs first), every refusal, leg, failure and
    /// truth metric equals the reference; every refusal and failure kind occurs.
    @Test func legsFailuresAndReportsMatchReference() {
        let levels: [(level: StarlitCartoucheLevel, known: [StarlitCartoucheAction])] = Reference.levels()
        var random: SeededRandom = SeededRandom(seed: Reference.seed &+ 1)
        var tally: [String: Int] = [:]
        for entry in levels {
            let level: StarlitCartoucheLevel = entry.level
            var star: Int = level.start
            var beat: Int = 0
            var drawn: Set<Int> = []
            var legs: [StarlitCartoucheLeg] = []
            var plan: [(destination: Int, wait: Int)] = []
            for action in entry.known {
                if case .leg(let destination, let wait) = action { plan.append((destination, wait)) }
            }
            let extra: Int = random.int(1...10)
            for step in 0..<(plan.count + extra) {
                if beat > 80 { break }
                let next: (destination: Int, wait: Int)
                if step < plan.count {
                    next = plan[step]
                } else {
                    next = Reference.randomLeg(level, star: star, &random)
                }
                let expected: String? = Reference.refusal(level, star: star, beat: beat, destination: next.destination,
                                                          wait: next.wait)
                let actual: (leg: StarlitCartoucheLeg?, refusal: String?) = Reference.chartLeg(
                    level, star: star, beat: beat, destination: next.destination, wait: next.wait)
                #expect(actual.refusal == expected, "\(level.id) step \(step)")
                if let name = expected {
                    let key: String = name.hasPrefix("out of range") ? "out of range" : name
                    tally[key, default: 0] += 1
                    continue
                }
                guard let leg = actual.leg else { continue }
                let corridor: Int = Reference.corridor(level, star, next.destination) ?? -1
                let depart: Int = beat + next.wait
                let arrive: Int = depart + level.corridors[corridor].travel
                #expect(leg.from == star && leg.to == next.destination && leg.corridor == corridor, "\(level.id)")
                #expect(leg.wait == next.wait && leg.depart == depart && leg.arrive == arrive, "\(level.id)")
                let failure: StarlitCartoucheFailure? = Reference.failure(level, from: star, to: next.destination,
                                                                          corridor: corridor, depart: depart,
                                                                          arrive: arrive)
                #expect(StarlitCartoucheChart.check(level, leg: leg) == failure, "\(level.id) step \(step)")
                tally[Reference.kind(failure), default: 0] += 1
                star = leg.to
                beat = leg.arrive
                drawn.insert(leg.corridor)
                legs.append(leg)
                let report: StarlitCartoucheRouteReport = StarlitCartoucheChart.report(level, star: star, beat: beat,
                                                                                       drawn: drawn, legs: legs)
                let sortedDrawn: [Int] = drawn.sorted()
                let sets: (missing: [Int], stray: [Int]) = Reference.missingAndStray(level, drawn: sortedDrawn)
                #expect(report.star == star && report.beat == beat && report.drawn == sortedDrawn, "\(level.id)")
                #expect(report.missing == sets.missing && report.stray == sets.stray, "\(level.id)")
                #expect(report.mismatch == sets.missing.count + sets.stray.count, "\(level.id)")
                #expect(report.clearance == Reference.clearance(level, legs: legs), "\(level.id)")
                let matched: Bool = sets.missing.isEmpty && sets.stray.isEmpty && star == level.beacon
                #expect(report.matched == matched, "\(level.id)")
            }
        }
        let kinds: [String] = ["unknown star", "same star", "no corridor", "wait", "out of range", "clear",
                               "failure departure", "failure hazard", "failure arrival", "failure deadline",
                               "failure stroke"]
        for kind in kinds {
            #expect((tally[kind] ?? 0) > 0, "\(kind) occurs: \(tally)")
        }
    }

    /// A squared distance of exactly r² is in range; r² + 1 is refused, naming "out of range" and both numbers.
    @Test func rangeOneUnitInsideAndOutside() throws {
        var orbits: [[StarlitCartoucheVector]] = Reference.rowOrbits
        orbits[0] = [StarlitCartoucheVector(0, 0, 0)]
        orbits[1] = [StarlitCartoucheVector(2, 0, 0), StarlitCartoucheVector(2, 1, 0)]
        let windows: [(Int, Int)] = [(0, 20), (0, 20), (0, 20), (0, 20)]
        let level: StarlitCartoucheLevel = try Reference.windowLevel(orbits: orbits, windows: windows, range: 2,
                                                                     deadline: 20)
        #expect(StarlitCartoucheChart.flyable(level, corridor: 0, at: 0))
        #expect(!StarlitCartoucheChart.flyable(level, corridor: 0, at: 1))
        let inside: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 0, at: 0, to: 1, wait: 0)
        #expect(inside.depart == 0 && inside.arrive == 1)
        #expect(throws: StarlitCartoucheError.action("out of range: 5 > 4")) {
            try StarlitCartoucheChart.leg(level, from: 0, at: 0, to: 1, wait: 1)
        }
        #expect(throws: StarlitCartoucheError.action("out of range: 5 > 4")) {
            try StarlitCartoucheChart.leg(level, from: 0, at: 1, to: 1, wait: 0)
        }
        let later: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 0, at: 1, to: 1, wait: 1)
        #expect(later.depart == 2 && later.arrive == 3, "the orbit wraps back into range at beat 2")
    }

    /// A hazard one beat clear of each end of a leg leaves it clear (clearance 1); one touching either end fails it
    /// (clearance 0); the lowest meeting hazard is named.
    @Test func hazardClearOfAndTouchingEachEnd() throws {
        let cases: [(from: Int, to: Int, meets: Bool)] = [(1, 4, false), (8, 10, false), (1, 5, true), (7, 9, true),
                                                          (6, 6, true), (0, 20, true)]
        for item in cases {
            let hazard: StarlitCartoucheHazard = StarlitCartoucheHazard(corridor: 1, from: item.from, to: item.to)
            let level: StarlitCartoucheLevel = try StarlitCartoucheLevelTests.handLevel(hazards: [hazard])
            let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 0)
            #expect(leg.depart == 5 && leg.arrive == 7)
            let failure: StarlitCartoucheFailure? = StarlitCartoucheChart.check(level, leg: leg)
            if item.meets {
                #expect(failure == .hazard(corridor: 1, hazard: 0, from: item.from, to: item.to), "\(item)")
            } else {
                #expect(failure == nil, "\(item)")
            }
            let clearance: Int? = StarlitCartoucheChart.clearance(level, legs: [leg])
            #expect(clearance == (item.meets ? 0 : 1), "\(item)")
        }
        let two: [StarlitCartoucheHazard] = [StarlitCartoucheHazard(corridor: 0, from: 5, to: 7),
                                             StarlitCartoucheHazard(corridor: 1, from: 8, to: 9),
                                             StarlitCartoucheHazard(corridor: 1, from: 7, to: 7),
                                             StarlitCartoucheHazard(corridor: 1, from: 2, to: 5)]
        let level: StarlitCartoucheLevel = try StarlitCartoucheLevelTests.handLevel(hazards: two)
        let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 0)
        #expect(StarlitCartoucheChart.check(level, leg: leg) == .hazard(corridor: 1, hazard: 2, from: 7, to: 7))
        #expect(StarlitCartoucheChart.clearance(level, legs: [leg]) == 0)
        let other: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 2, at: 0, to: 3, wait: 0)
        #expect(StarlitCartoucheChart.clearance(level, legs: [other]) == nil, "no hazard on corridor 2")
    }

    /// Arrival exactly on the target's open, close and the deadline is allowed; one beat outside the window fails
    /// `arrival`; one beat after the deadline with the destination's window still open fails `deadline`.
    @Test func arrivalOnWindowEdgesAndDeadline() throws {
        let windows: [(Int, Int)] = [(0, 9), (0, 9), (7, 9), (0, 9)]
        let level: StarlitCartoucheLevel = try Reference.windowLevel(orbits: Reference.rowOrbits, windows: windows,
                                                                     range: 2, deadline: 9)
        let onOpen: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 0)
        #expect(onOpen.arrive == 7 && StarlitCartoucheChart.check(level, leg: onOpen) == nil)
        let early: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 4, to: 2, wait: 0)
        #expect(StarlitCartoucheChart.check(level, leg: early) == .arrival(star: 2, beat: 6, open: 7, close: 9))
        let onClose: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 2)
        #expect(onClose.arrive == 9 && onClose.arrive == level.deadline)
        #expect(StarlitCartoucheChart.check(level, leg: onClose) == nil)
        let late: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 0, at: 9, to: 1, wait: 0)
        #expect(late.arrive == 10)
        #expect(StarlitCartoucheChart.check(level, leg: late) == .arrival(star: 1, beat: 10, open: 0, close: 9))
        let narrow: [(Int, Int)] = [(0, 20), (0, 20), (7, 8), (0, 20)]
        let wide: StarlitCartoucheLevel = try Reference.windowLevel(orbits: Reference.rowOrbits, windows: narrow,
                                                                    range: 2, deadline: 12)
        let pastClose: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(wide, from: 1, at: 7, to: 2, wait: 0)
        #expect(StarlitCartoucheChart.check(wide, leg: pastClose) == .arrival(star: 2, beat: 9, open: 7, close: 8))
        let onDeadline: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(wide, from: 0, at: 11, to: 1, wait: 0)
        #expect(onDeadline.arrive == 12 && StarlitCartoucheChart.check(wide, leg: onDeadline) == nil)
        let pastDeadline: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(wide, from: 0, at: 12, to: 1, wait: 0)
        #expect(pastDeadline.arrive == 13)
        #expect(StarlitCartoucheChart.check(wide, leg: pastDeadline) == .deadline(beat: 13, deadline: 12))
    }

    /// Departure exactly on the origin's close is allowed; one beat after fails `departure`, before a hazard on the
    /// corridor and before the arrival window.
    @Test func departureOnOriginClose() throws {
        let windows: [(Int, Int)] = [(0, 20), (0, 5), (0, 20), (0, 20)]
        let level: StarlitCartoucheLevel = try Reference.windowLevel(orbits: Reference.rowOrbits, windows: windows,
                                                                     range: 2, deadline: 20)
        let onClose: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 0)
        #expect(onClose.depart == 5 && StarlitCartoucheChart.check(level, leg: onClose) == nil)
        let after: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 5, to: 2, wait: 1)
        #expect(StarlitCartoucheChart.check(level, leg: after) == .departure(star: 1, beat: 6, close: 5))
        let hazard: StarlitCartoucheHazard = StarlitCartoucheHazard(corridor: 1, from: 0, to: 20)
        let blocked: StarlitCartoucheLevel = try Reference.windowLevel(orbits: Reference.rowOrbits, windows: windows,
                                                                       range: 2, deadline: 20, hazards: [hazard])
        let both: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(blocked, from: 1, at: 5, to: 2, wait: 1)
        #expect(StarlitCartoucheChart.check(blocked, leg: both) == .departure(star: 1, beat: 6, close: 5))
        let hazardFirst: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(blocked, from: 1, at: 5, to: 2, wait: 0)
        #expect(StarlitCartoucheChart.check(blocked, leg: hazardFirst)
            == .hazard(corridor: 1, hazard: 0, from: 0, to: 20))
        #expect(StarlitCartoucheFailure.departure(star: 1, beat: 6, close: 5).code == "window")
    }

    /// A retraced stroke counts once; a stray corridor fails `stroke` and is reported stray.
    @Test func retracedAndStrayStrokes() throws {
        let level: StarlitCartoucheLevel = try StarlitCartoucheLevelTests.handLevel()
        var star: Int = 0
        var beat: Int = 0
        var drawn: Set<Int> = []
        var legs: [StarlitCartoucheLeg] = []
        let route: [Int] = [1, 0, 1]
        for destination in route {
            let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: star, at: beat, to: destination,
                                                                         wait: 0)
            #expect(StarlitCartoucheChart.check(level, leg: leg) == nil)
            drawn.insert(leg.corridor)
            legs.append(leg)
            star = leg.to
            beat = leg.arrive
        }
        let retraced: StarlitCartoucheRouteReport = StarlitCartoucheChart.report(level, star: star, beat: beat,
                                                                                 drawn: drawn, legs: legs)
        #expect(retraced.drawn == [0] && retraced.missing == [1] && retraced.stray.isEmpty)
        #expect(retraced.mismatch == 1 && !retraced.matched && retraced.beat == 3)
        let toTwo: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 1, at: 3, to: 2, wait: 0)
        drawn.insert(toTwo.corridor)
        legs.append(toTwo)
        let won: StarlitCartoucheRouteReport = StarlitCartoucheChart.report(level, star: 2, beat: 5, drawn: drawn,
                                                                            legs: legs)
        #expect(won.matched && won.mismatch == 0)
        let stray: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 2, at: 5, to: 3, wait: 0)
        #expect(StarlitCartoucheChart.check(level, leg: stray) == .stroke(corridor: 2))
        drawn.insert(stray.corridor)
        legs.append(stray)
        let strayReport: StarlitCartoucheRouteReport = StarlitCartoucheChart.report(level, star: 3, beat: 6,
                                                                                    drawn: drawn, legs: legs)
        #expect(strayReport.stray == [2] && strayReport.missing.isEmpty && strayReport.mismatch == 1)
        #expect(!strayReport.matched)
    }

    /// Waits 0 and 8 are accepted, −1 and 9 refused; an unknown star, the same star and a missing corridor are
    /// refused by name, in that order before the wait.
    @Test func refusalsByName() throws {
        let level: StarlitCartoucheLevel = try StarlitCartoucheLevelTests.handLevel()
        let zero: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 0, at: 0, to: 1, wait: 0)
        #expect(zero.depart == 0 && zero.arrive == 1)
        let eight: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: 0, at: 0, to: 1, wait: 8)
        #expect(eight.depart == 8 && eight.arrive == 9 && eight.wait == 8)
        let cases: [(destination: Int, wait: Int, name: String)] = [(1, 9, "wait"), (1, -1, "wait"),
                                                                     (4, 0, "unknown star"), (-1, 0, "unknown star"),
                                                                     (0, 0, "same star"), (2, 0, "no corridor"),
                                                                     (4, 9, "unknown star"), (0, 9, "same star"),
                                                                     (3, -1, "no corridor")]
        for item in cases {
            let result: (leg: StarlitCartoucheLeg?, refusal: String?) = Reference.chartLeg(
                level, star: 0, beat: 0, destination: item.destination, wait: item.wait)
            #expect(result.leg == nil && result.refusal == item.name, "\(item)")
        }
        #expect(StarlitCartoucheError.action("wait").reasonCode == "r02-g16.action")
        #expect(StarlitCartoucheChart.waits == 0...8)
    }
}
