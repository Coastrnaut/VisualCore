// StarlitCartoucheInvariantTests — feature 451 (R02-G16-01) T-R02G1601-006 (FR-R02G1601-012; the source's invariants
// R2-G16-INV-01 … 05 and INV-07 … 10 on Starlit Cartouche), modelled on VoxelOrigamiInvariantTests (feature 441). Each
// named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,456: fixtures drawn from
// it, unknown stars −1 and n, the ship's own star, waits −1 and 9, waits w and w + 1, an action budget ± 1, every leg
// from a fixture's last state before its win, windows tightened and hazards added by the seed, a byte of a stored level
// changed). How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G16-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; beats are whole numbers. A leg departs at the ship's beat plus its wait and
//   arrives exactly its corridor's travel later; a wait one beat longer moves both by exactly one. The same legs give
//   the same beats, fingerprints, reports and records however many pauses, reads and 0.008333 s presentation frames lie
//   between them; an idle play never spends an action or fails; the kernel sources hold no clock, time interval or
//   floating-point value.
// - INV-02 Input budget: an accepted leg (clear or failing) spends exactly 1 action; refusals (an unknown star, the
//   ship's own star, no corridor, a wait outside 0 … 8, a stale fingerprint, the wrong stage) spend nothing; the leg
//   that spends the last of the budget is applied and judged (a win on it wins, else it fails `budget(spent)`) and
//   every later action is refused by stage.
// - INV-03 Goal: a play wins exactly when the drawn strokes equal the symbol and the ship is at the beacon, judged
//   against an independent step and failure computation; one stroke missing, or every stroke drawn away from the
//   beacon, is not a win; every leg from a fixture's last state before its win wins, fails or plays on exactly as the
//   independent computation says.
// - INV-04 Repeatability: the same legs give the same records, fingerprints and outcome on independent runs and through
//   replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior star, beat, strokes, legs, actions spent, report, failure and
//   fingerprint; redo the later one; a new leg clears redo; a won level is final; a failed play (a window, hazard,
//   deadline, stroke or budget failure) returns to playing with its action refunded; undo while paused stays paused.
// - INV-07 Failure honesty: a failing leg names its real cause in the chart's order — `departure`, `hazard` (the lowest
//   hazard meeting the leg), `arrival`, `deadline`, `stroke` — equal to an independent computation; the ship, beat,
//   strokes and legs stay as they were; the failing action is the last record; a budget failure names the action count;
//   a refusal names its reason with the code `r02-g16.action`; undo from a failure returns to playing.
// - INV-08 Stability: an extreme valid level (12 stars on orbits of 4 positions at the corners ±8, 24 corridors, 8
//   hazards, a 64-character id, the largest seed, range 12, deadline 64, budget 16) and the fixtures walk through at
//   least 500 seeded states without a crash or overflow; every star, corridor, beat, leg and report value stays valid
//   and bounded.
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); any
//   single-byte edit of the stored JSON is refused or decodes to the same level; truncated, newer, older and
//   fingerprint-edited forms are refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report is a pure function of the level, the ship's star and beat, the strokes and the
//   legs (never of time, call order or presentation); names, descriptions and star positions sampled for drawing never
//   change the play; a level differing only in its id gives identical outcomes; the play is a value type; the kernel
//   sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheInvariantTests {
    typealias Play = StarlitCartouchePlay
    typealias Level = StarlitCartoucheLevel
    typealias Action = StarlitCartoucheAction
    typealias Failure = StarlitCartoucheFailure
    typealias Report = StarlitCartoucheRouteReport
    typealias Star = StarlitCartoucheStar
    typealias Vec = StarlitCartoucheVector
    typealias Corridor = StarlitCartoucheCorridor
    typealias Hazard = StarlitCartoucheHazard
    typealias Leg = StarlitCartoucheLeg
    typealias Fixture = StarlitCartoucheFixture
    typealias Record = StarlitCartoucheRecord
    typealias Refusal = StarlitCartoucheError

    /// The helpers, builders and independent computations of this file.
    private enum Inv {
        /// The invariant (neighbouring-input) seed.
        static let seed: UInt64 = 2_456

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The kernel sources the scans read when present (the Core directory next to this test directory).
        static let kernelFiles: [String] = ["StarlitCartoucheChart.swift", "StarlitCartoucheError.swift",
                                            "StarlitCartoucheLevel.swift", "StarlitCartouchePlay.swift"]

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 60, seed: seed)

        /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
        static func playing(_ level: Level) throws(Refusal) -> Play {
            var play: Play = Play(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            return play
        }

        /// A playing play of `level` with `actions` applied in order.
        static func played(_ level: Level, _ actions: [Action]) throws(Refusal) -> Play {
            var play: Play = try playing(level)
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            return play
        }

        /// The refusal of `body`, or nil when it was accepted.
        static func refusal(_ body: () throws(Refusal) -> Void) -> Refusal? {
            do {
                try body()
                return nil
            } catch {
                return error
            }
        }

        /// Whether `error` is an `.action` refusal (any payload).
        static func isAction(_ error: Refusal?) -> Bool {
            if case .action = error { return true }
            return false
        }

        /// `level` with some values replaced.
        static func variant(_ level: Level, id: String? = nil, stars: [Star]? = nil, hazards: [Hazard]? = nil,
                            budget: Int? = nil) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: level.seed, difficulty: level.difficulty, stars: stars ?? level.stars,
                      range: level.range, corridors: level.corridors, hazards: hazards ?? level.hazards,
                      start: level.start, beacon: level.beacon, deadline: level.deadline, symbol: level.symbol,
                      budget: budget ?? level.budget, tutorial: level.tutorial)
        }

        /// A hand level: four still stars in a row (x = 0, 2, 4, 6; range 2, so every corridor is always flyable),
        /// corridors 0–1 (travel 1), 1–2 (travel 2) and 2–3 (travel 1), the symbol 0–1 and 1–2, start 0.
        static func hand(beacon: Int = 2, budget: Int = 8, deadline: Int = 20, opens: [Int] = [0, 0, 0, 0],
                         closes: [Int] = [20, 20, 20, 20], hazards: [Hazard] = []) throws(Refusal) -> Level {
            var stars: [Star] = []
            for i in 0..<4 {
                stars.append(Star(orbit: [Vec(i * 2, 0, 0)], glyph: StarlitCartoucheGlyphPoint(i, 0), open: opens[i],
                                  close: closes[i]))
            }
            let corridors: [Corridor] = [Corridor(0, 1, travel: 1), Corridor(1, 2, travel: 2),
                                         Corridor(2, 3, travel: 1)]
            return try Level(id: "inv-hand", seed: seed, difficulty: 1, stars: stars, range: 2, corridors: corridors,
                             hazards: hazards, start: 0, beacon: beacon, deadline: deadline, symbol: [0, 1],
                             budget: budget)
        }

        /// `level` with seeded tighter windows (the start's opens at 0) and one more hazard on a seeded corridor.
        static func tight(_ level: Level, random: inout SeededRandom) throws(Refusal) -> Level {
            var stars: [Star] = []
            for index in level.stars.indices {
                let star: Star = level.stars[index]
                let open: Int = index == level.start ? 0 : random.int(0...3)
                let close: Int = min(open + random.int(2...(level.deadline + 4)), 64)
                stars.append(Star(orbit: star.orbit, glyph: star.glyph, open: open, close: close))
            }
            var hazards: [Hazard] = level.hazards
            if hazards.count < Level.maxHazards {
                let from: Int = random.int(0...10)
                hazards.append(Hazard(corridor: random.int(0...(level.corridors.count - 1)), from: from,
                                      to: from + random.int(0...3)))
            }
            return try variant(level, stars: stars, hazards: hazards)
        }

        /// The stars joined to `star` by a corridor.
        static func neighbours(_ level: Level, of star: Int) -> [Int] {
            var result: [Int] = []
            for corridor in level.corridors {
                if corridor.a == star { result.append(corridor.b) }
                if corridor.b == star { result.append(corridor.a) }
            }
            return result
        }

        /// A seeded leg from `star`: mostly a corridor's other end with a short wait, sometimes an unknown star (−1 or
        /// n), the ship's own star, a star without a corridor, a wait of −1 or 9 or a long wait.
        static func invAction(_ level: Level, star: Int, random: inout SeededRandom) -> Action {
            let count: Int = level.stars.count
            let roll: Int = random.int(0...19)
            if roll == 0 { return .leg(random.int(0...1) == 0 ? -1 : count, random.int(0...2)) }
            if roll == 1 { return .leg(star, random.int(0...2)) }
            if roll == 2 { return .leg(random.int(0...(count - 1)), random.int(0...1) == 0 ? -1 : 9) }
            let wait: Int = roll == 3 ? random.int(4...8) : random.int(0...3)
            let near: [Int] = neighbours(level, of: star)
            if roll == 4 || near.isEmpty { return .leg(random.int(0...(count - 1)), wait) }
            return .leg(near[random.int(0...(near.count - 1))], wait)
        }

        /// A seeded walk of up to `steps` legs, undos, redos, pauses and resumes on `level` (refusals skipped).
        static func invWalk(_ level: Level, steps: Int, random: inout SeededRandom) throws -> Play {
            var play: Play = try playing(level)
            for _ in 0..<steps {
                let roll: Int = random.int(0...19)
                if roll < 2 {
                    _ = refusal { () throws(Refusal) in try play.undo() }
                } else if roll == 2 {
                    _ = refusal { () throws(Refusal) in try play.redo() }
                } else if roll == 3 {
                    _ = refusal { () throws(Refusal) in try play.handle(.pause) }
                } else if roll == 4 {
                    _ = refusal { () throws(Refusal) in try play.handle(.resume) }
                } else {
                    if play.stage == .paused { try play.handle(.resume) }
                    if play.stage != .playing { continue }
                    let action: Action = invAction(level, star: play.star, random: &random)
                    _ = refusal { () throws(Refusal) in try play.apply(action, expecting: play.fingerprint) }
                }
            }
            return play
        }

        /// The kernel sources present in the Core directory next to this test directory.
        static func kernelSources() throws -> [(name: String, text: String)] {
            let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            var sources: [(name: String, text: String)] = []
            for name in kernelFiles {
                let url: URL = core.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                sources.append((name, try String(contentsOf: url, encoding: .utf8)))
            }
            return sources
        }

        // MARK: Independent computations

        /// The state an independent walk of clear legs reaches: the ship's star, beat and strokes drawn.
        struct State: Equatable {
            /// The ship's star.
            var star: Int
            /// The current beat.
            var beat: Int
            /// The strokes drawn.
            var drawn: Set<Int>
        }

        /// The independent state after `actions` (each a clear leg by the fixture's own step).
        static func invRun(_ level: Level, _ actions: [Action]) -> State {
            var state: State = State(star: level.start, beat: 0, drawn: [])
            for action in actions {
                guard case .leg(let destination, let wait) = action,
                      let next = Fixture.step(level, star: state.star, beat: state.beat, destination: destination,
                                              wait: wait) else { continue }
                state = State(star: next.star, beat: next.beat, drawn: state.drawn.union([next.corridor]))
            }
            return state
        }

        /// The fixture's legs up to and including the first that wins (independently: every symbol stroke drawn and
        /// the ship at the beacon); a retraced route can win before its last leg.
        static func winning(_ fixture: Fixture) -> [Action] {
            let level: Level = fixture.level
            let symbol: Set<Int> = Set(level.symbol)
            var prefix: [Action] = []
            for action in fixture.actions {
                prefix.append(action)
                let state: State = invRun(level, prefix)
                if state.drawn == symbol && state.star == level.beacon { break }
            }
            return prefix
        }

        /// The failure of a leg by an independent computation in the chart's order (departure, hazard by listing
        /// every beat of the leg, arrival, deadline, stroke), or nil when it is clear.
        static func invFailure(_ level: Level, from: Int, to: Int, corridor: Int, depart: Int,
                               arrive: Int) -> Failure? {
            let origin: Star = level.stars[from]
            if depart > origin.close { return .departure(star: from, beat: depart, close: origin.close) }
            for index in level.hazards.indices {
                let hazard: Hazard = level.hazards[index]
                guard hazard.corridor == corridor else { continue }
                var meets: Bool = false
                for t in depart...arrive where t >= hazard.from && t <= hazard.to { meets = true }
                if meets { return .hazard(corridor: corridor, hazard: index, from: hazard.from, to: hazard.to) }
            }
            let target: Star = level.stars[to]
            if arrive < target.open || arrive > target.close {
                return .arrival(star: to, beat: arrive, open: target.open, close: target.close)
            }
            if arrive > level.deadline { return .deadline(beat: arrive, deadline: level.deadline) }
            var inSymbol: Bool = false
            for stroke in level.symbol where stroke == corridor { inSymbol = true }
            if !inSymbol { return .stroke(corridor: corridor) }
            return nil
        }

        /// The independently expected outcome of `action` from `state` with `spent` actions spent: nil when refused,
        /// else the next state, the failure and whether it wins.
        static func invOutcome(_ level: Level, _ state: State, spent: Int,
                               _ action: Action) -> (state: State, failure: Failure?, won: Bool)? {
            guard case .leg(let destination, let wait) = action,
                  let next = Fixture.step(level, star: state.star, beat: state.beat, destination: destination,
                                          wait: wait) else { return nil }
            let depart: Int = state.beat + wait
            if let failure = invFailure(level, from: state.star, to: next.star, corridor: next.corridor,
                                        depart: depart, arrive: next.beat) {
                return (state, failure, false)
            }
            let after: State = State(star: next.star, beat: next.beat, drawn: state.drawn.union([next.corridor]))
            if after.drawn == Set(level.symbol) && after.star == level.beacon { return (after, nil, true) }
            if spent + 1 >= level.budget { return (after, .budget(spent + 1), false) }
            return (after, nil, false)
        }

        /// The play's state as an independent `State`.
        static func state(of play: Play) -> State { State(star: play.star, beat: play.beat, drawn: play.drawn) }

        /// The extreme valid level: 12 stars on 4-position orbits at the corners ±8, 24 corridors, 8 hazards, a
        /// 64-character id, the largest seed, range 12, deadline 64, budget 16, a symbol of 12 strokes.
        static func extreme() throws(Refusal) -> Level {
            var stars: [Star] = []
            for i in 0..<12 {
                var orbit: [Vec] = []
                for k in 0..<4 {
                    let x: Int = (i + k) % 2 == 0 ? 8 : -8
                    let y: Int = (i / 2 + k) % 2 == 0 ? 8 : -8
                    let z: Int = (i / 4 + k / 2) % 2 == 0 ? -8 : 8
                    orbit.append(Vec(x, y, z))
                }
                stars.append(Star(orbit: orbit, glyph: StarlitCartoucheGlyphPoint(i % 5, i / 5), open: 0, close: 64))
            }
            var corridors: [Corridor] = []
            for a in 0..<12 {
                for b in (a + 1)..<12 where corridors.count < Level.maxCorridors {
                    corridors.append(Corridor(a, b, travel: 1 + (a + b) % 3))
                }
            }
            var hazards: [Hazard] = []
            for h in 0..<Level.maxHazards { hazards.append(Hazard(corridor: h * 3, from: h * 8, to: h * 8 + 2)) }
            var symbol: [Int] = []
            for stroke in 0..<12 { symbol.append(stroke) }
            return try Level(id: String(repeating: "z", count: 64), seed: UInt64.max, difficulty: 5, stars: stars,
                             range: 12, corridors: corridors, hazards: hazards, start: 0, beacon: 11, deadline: 64,
                             symbol: symbol, budget: 16, tutorial: true)
        }
    }

    // MARK: INV-01 Time

    @Test func testStarlitCartoucheTimeBoundary() throws {
        // Direct boundary: 0 → 1 after 2 beats departs at 2 and arrives at 3 (travel 1); 1 → 2 after 1 beat departs at
        // 4 and arrives at 6 (travel 2).
        let level: Level = try Inv.hand()
        let play: Play = try Inv.played(level, [.leg(1, 2), .leg(2, 1)])
        #expect(play.legs.count == 2, "both legs are flown")
        #expect(play.legs[0].depart == 2 && play.legs[0].arrive == 3, "the first leg departs at 2 and arrives at 3")
        #expect(play.legs[1].depart == 4 && play.legs[1].arrive == 6, "the second leg departs at 4 and arrives at 6")
        #expect(play.beat == 6 && play.stage == .won, "the ship is at the beacon at beat 6")
        // The same legs with pauses, reads and 0.008333 s presentation frames in between give the same play.
        let step: Double = 0.008333
        let fixture: Fixture = Inv.fixtures[0]
        let actions: [Action] = Inv.winning(fixture)
        let plain: Play = try Inv.played(fixture.level, actions)
        var busy: Play = try Inv.playing(fixture.level)
        var elapsed: Double = 0
        for action in actions {
            for frame in 0..<120 {
                elapsed += step
                _ = busy.fingerprint
                _ = busy.report
                _ = busy.actionsLeft
                for star in fixture.level.stars { _ = star.position(at: busy.beat + frame) }
            }
            try busy.handle(.pause)
            try busy.handle(.resume)
            try busy.apply(action, expecting: busy.fingerprint)
        }
        #expect(elapsed > 0.9, "presentation frames elapsed")
        #expect(busy == plain, "pauses, reads and presentation frames never change the play")
        #expect(busy.records == plain.records, "records are independent of when legs came")
        #expect(plain.stage == .won, "the known legs win regardless of when")
        #expect(plain.beat == Inv.invRun(fixture.level, actions).beat, "the beat equals an independent count")
        // An idle play never spends an action or fails.
        var idle: Play = try Inv.playing(fixture.level)
        let before: String = idle.fingerprint
        for _ in 0..<1_000 {
            _ = idle.report
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.fingerprint == before && idle.beat == 0, "an idle play keeps its fingerprint and beat")
        #expect(idle.actionsSpent == 0 && idle.failure == nil, "an idle play spends nothing and never fails")
        // The kernel sources hold no clock, time interval or floating-point value.
        let tokens: [String] = ["Da" + "te(", "Dou" + "ble", "Flo" + "at", "Time" + "Interval", "Dispatch" + "Time",
                                "Continuous" + "Clock", "CFAbsolute" + "Time", "random" + "Element", ".ran" + "dom("]
        let sources: [(name: String, text: String)] = try Inv.kernelSources()
        #expect(sources.count >= 4, "the kernel sources are present")
        for source in sources {
            for token in tokens {
                #expect(!source.text.contains(token), "\(source.name) holds a clock or floating-point token")
            }
        }
        // Neighbouring inputs: waits w and w + 1 move departure and arrival by exactly one beat; every flown leg
        // departs at the previous arrival plus its wait and arrives its travel later; the same walk twice is equal.
        for index in 0..<30 {
            let level: Level = Inv.fixtures[index].level
            for destination in Inv.neighbours(level, of: level.start) {
                for wait in 0..<8 {
                    let a: Leg = try StarlitCartoucheChart.leg(level, from: level.start, at: 0, to: destination,
                                                               wait: wait)
                    let b: Leg = try StarlitCartoucheChart.leg(level, from: level.start, at: 0, to: destination,
                                                               wait: wait + 1)
                    #expect(b.depart == a.depart + 1 && b.arrive == a.arrive + 1, "one more beat of wait moves by one")
                    #expect(a.arrive - a.depart == level.corridors[a.corridor].travel, "arrival = departure + travel")
                }
            }
            var first: SeededRandom = SeededRandom(seed: Inv.seed &+ UInt64(index))
            var second: SeededRandom = SeededRandom(seed: Inv.seed &+ UInt64(index))
            let x: Play = try Inv.invWalk(level, steps: 40, random: &first)
            let y: Play = try Inv.invWalk(level, steps: 40, random: &second)
            #expect(x == y && x.fingerprint == y.fingerprint, "equal inputs give equal plays")
            var previous: Int = 0
            for leg in x.legs {
                #expect(leg.depart == previous + leg.wait, "a leg departs at the previous arrival plus its wait")
                #expect(leg.arrive == leg.depart + level.corridors[leg.corridor].travel, "a leg arrives travel later")
                previous = leg.arrive
            }
            #expect(x.beat == previous, "the beat is the latest arrival")
        }
    }

    // MARK: INV-02 Input budget

    @Test func testStarlitCartoucheInputbudgetBoundary() throws {
        // Direct boundary: a budget of 2 spent exactly by the winning legs still wins.
        let exact: Play = try Inv.played(try Inv.hand(budget: 2), [.leg(1, 0), .leg(2, 0)])
        #expect(exact.stage == .won && exact.actionsLeft == 0 && exact.failure == nil, "a win on the last action wins")
        // Three legs that never win fail on exactly the third, naming the action count; one over is refused by stage.
        var play: Play = try Inv.playing(try Inv.hand(budget: 3))
        let steps: [Action] = [.leg(1, 0), .leg(0, 0), .leg(1, 0)]
        for (index, action) in steps.enumerated() {
            try play.apply(action, expecting: play.fingerprint)
            #expect(play.actionsSpent == index + 1, "each leg spends exactly one action")
            if index < 2 { #expect(play.stage == .playing, "the budget is not spent yet") }
        }
        #expect(play.stage == .failed && play.failure == .budget(3), "the leg spending the last of the budget fails")
        let after: String = play.fingerprint
        let late: Refusal? = Inv.refusal { () throws(Refusal) in try play.apply(.leg(2, 0), expecting: after) }
        #expect(late == .stage, "an action beyond the budget is refused by stage")
        #expect(play.fingerprint == after && play.actionsSpent == 3, "a refused action changes nothing")
        // A failing leg is accepted and spends exactly one action.
        var stray: Play = try Inv.played(try Inv.hand(beacon: 0), [.leg(1, 0), .leg(2, 0)])
        try stray.apply(.leg(3, 0), expecting: stray.fingerprint)
        #expect(stray.actionsSpent == 3 && stray.failure == .stroke(corridor: 2), "a failing leg spends one")
        // Neighbouring inputs: budgets of the winning count and one less; seeded refusals spend nothing.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures {
            let actions: [Action] = Inv.winning(fixture)
            let budgeted: Level = try Inv.variant(fixture.level, budget: actions.count)
            let won: Play = try Inv.played(budgeted, actions)
            #expect(won.stage == .won && won.actionsLeft == 0 && won.failure == nil, "the exact budget still wins")
            if actions.count >= 2 {
                let short: Level = try Inv.variant(fixture.level, budget: actions.count - 1)
                let failed: Play = try Inv.played(short, Array(actions.dropLast()))
                #expect(failed.stage == .failed && failed.failure == .budget(short.budget),
                        "one action short fails on the exact action, naming the count")
                #expect(failed.actionsSpent == short.budget, "the budget fails after exactly its count")
                var over: Play = failed
                let overError: Refusal? = Inv.refusal { () throws(Refusal) in
                    try over.apply(actions[actions.count - 1], expecting: over.fingerprint)
                }
                #expect(overError == .stage && over == failed, "one over the budget is refused and changes nothing")
            }
            var walk: Play = try Inv.playing(fixture.level)
            for _ in 0..<20 {
                guard walk.stage == .playing else { break }
                let action: Action = Inv.invAction(fixture.level, star: walk.star, random: &random)
                let spent: Int = walk.actionsSpent
                let print: String = walk.fingerprint
                let expected: (state: Inv.State, failure: Failure?, won: Bool)? =
                    Inv.invOutcome(fixture.level, Inv.state(of: walk), spent: spent, action)
                let error: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                #expect((error == nil) == (expected != nil), "a leg is accepted exactly when the independent step is")
                if error == nil {
                    #expect(walk.actionsSpent == spent + 1, "an accepted leg spends exactly one")
                    #expect(walk.records.count == spent + 1, "an accepted leg is recorded once")
                } else {
                    #expect(Inv.isAction(error), "an invalid leg is refused as an action")
                    #expect(walk.actionsSpent == spent && walk.fingerprint == print, "a refusal spends nothing")
                }
            }
            if walk.stage == .playing {
                let print: String = walk.fingerprint
                let target: Int = Inv.neighbours(fixture.level, of: walk.star).first ?? 0
                let stale: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walk.apply(.leg(target, 0), expecting: Inv.staleFingerprint)
                }
                #expect(stale == .stale && walk.fingerprint == print, "a stale fingerprint is refused, unchanged")
            }
        }
        // Wrong stage: loading and paused refuse legs.
        let level: Level = try Inv.hand()
        var loading: Play = Play(level: level)
        let early: Refusal? = Inv.refusal { () throws(Refusal) in
            try loading.apply(.leg(1, 0), expecting: loading.fingerprint)
        }
        #expect(early == .stage, "a leg before begin is refused by stage")
        var paused: Play = try Inv.playing(level)
        try paused.handle(.pause)
        let pausedError: Refusal? = Inv.refusal { () throws(Refusal) in
            try paused.apply(.leg(1, 0), expecting: paused.fingerprint)
        }
        #expect(pausedError == .stage && paused.actionsSpent == 0, "a paused play refuses legs and spends nothing")
    }

    // MARK: INV-03 Goal

    @Test func testStarlitCartoucheGoalBoundary() throws {
        // Direct boundary: both strokes drawn with the ship at the beacon wins; one stroke missing does not.
        let level: Level = try Inv.hand()
        let won: Play = try Inv.played(level, [.leg(1, 0), .leg(2, 0)])
        #expect(won.stage == .won && won.report.matched && won.report.mismatch == 0, "the cartouche drawn wins")
        let half: Play = try Inv.played(level, [.leg(1, 0)])
        #expect(half.stage == .playing && !half.report.matched, "one stroke missing is not a win")
        #expect(half.report.missing == [1], "the missing stroke is named")
        // Every stroke drawn away from the beacon is not a win; flying back to the beacon (retracing) is.
        let away: Play = try Inv.played(try Inv.hand(beacon: 0), [.leg(1, 0), .leg(2, 0)])
        #expect(away.report.missing.isEmpty && away.report.stray.isEmpty, "every stroke is drawn")
        #expect(away.stage == .playing && !away.report.matched, "off the beacon is not a win")
        let home: Play = try Inv.played(try Inv.hand(beacon: 0), [.leg(1, 0), .leg(2, 0), .leg(1, 0), .leg(0, 0)])
        #expect(home.stage == .won && home.drawn == [0, 1], "the retraced route home wins with each stroke once")
        // At the beacon with a stroke missing is not a win either.
        let early: Play = try Inv.played(try Inv.hand(beacon: 1), [.leg(1, 0)])
        #expect(early.star == 1 && early.stage == .playing && !early.report.matched, "at the beacon, a stroke short")
        // Neighbouring inputs: every leg (unknown stars, the ship's own star, waits −1 … 9) from each fixture's last
        // state before its win, judged against the independent step, failure and match.
        for fixture in Inv.fixtures {
            let actions: [Action] = Inv.winning(fixture)
            let roomy: Level = try Inv.variant(fixture.level, budget: Level.budgets.upperBound)
            let base: Play = try Inv.played(roomy, Array(actions.dropLast()))
            let state: Inv.State = Inv.invRun(roomy, Array(actions.dropLast()))
            #expect(base.stage == .playing && !base.report.matched, "the state before the win has not won")
            #expect(Inv.state(of: base) == state, "the play's state equals the independent state")
            for destination in -1...roomy.stars.count {
                for wait in [-1, 0, 1, 2, 5, 8, 9] {
                    let action: Action = .leg(destination, wait)
                    var play: Play = base
                    let error: Refusal? = Inv.refusal { () throws(Refusal) in
                        try play.apply(action, expecting: play.fingerprint)
                    }
                    guard let expected = Inv.invOutcome(roomy, state, spent: base.actionsSpent, action) else {
                        #expect(Inv.isAction(error) && play == base, "a refused leg is an action refusal, unchanged")
                        continue
                    }
                    #expect(error == nil, "a leg the independent step flies is accepted")
                    #expect(Inv.state(of: play) == expected.state, "the play moves exactly as the independent step")
                    #expect(play.failure == expected.failure, "the failure equals the independent failure")
                    #expect((play.stage == .won) == expected.won, "the play wins exactly as the independent match")
                    #expect(play.report.matched == expected.won, "the report matches exactly when the play wins")
                    if expected.failure == nil && !expected.won {
                        #expect(play.stage == .playing, "a clear leg without the full cartouche plays on")
                    }
                    if action == actions[actions.count - 1] { #expect(play.stage == .won, "the winning leg wins") }
                }
            }
        }
    }

    // MARK: INV-04 Repeatability

    @Test func testStarlitCartoucheRepeatabilityBoundary() throws {
        // Direct boundary: the known legs replay to the same play.
        let fixture: Fixture = Inv.fixtures[3]
        let actions: [Action] = Inv.winning(fixture)
        let won: Play = try Inv.played(fixture.level, actions)
        let replayed: Play = try Play.replay(level: fixture.level, records: won.records)
        #expect(replayed == won, "a known trace replays to the same play")
        #expect(replayed.fingerprint == won.fingerprint, "a known trace replays to the same fingerprint")
        let independent: Play = try Inv.played(fixture.level, actions)
        #expect(independent.records == won.records, "independent runs give the same records")
        // Neighbouring inputs: seeded walks replay; edited and forged records are refused.
        for index in 0..<Inv.fixtures.count {
            let level: Level = Inv.fixtures[index].level
            var random: SeededRandom = SeededRandom(seed: Inv.seed &+ UInt64(index))
            let walk: Play = try Inv.invWalk(level, steps: 30, random: &random)
            let again: Play = try Play.replay(level: level, records: walk.records)
            #expect(again.records == walk.records, "a replay reproduces every record")
            #expect(Inv.state(of: again) == Inv.state(of: walk) && again.legs == walk.legs, "a replay reproduces legs")
            #expect(again.failure == walk.failure && again.report == walk.report, "a replay reproduces the outcome")
            guard let last = walk.records.last else { continue }
            #expect(again.records.last?.next == last.next, "a replay reproduces the last fingerprint")
            var edited: [Record] = walk.records
            edited[edited.count - 1] = Record(schema: last.schema, seed: last.seed, index: last.index, kind: last.kind,
                                              action: last.action, previous: last.previous,
                                              next: Inv.staleFingerprint)
            let editedError: Refusal? = Inv.refusal { () throws(Refusal) in
                _ = try Play.replay(level: level, records: edited)
            }
            #expect(editedError != nil, "an edited record is refused")
            let head: Record = walk.records[0]
            var forged: [Record] = walk.records
            forged[0] = Record(schema: head.schema, seed: head.seed &+ 1, index: head.index, kind: head.kind,
                               action: head.action, previous: head.previous, next: head.next)
            let forgedError: Refusal? = Inv.refusal { () throws(Refusal) in
                _ = try Play.replay(level: level, records: forged)
            }
            #expect(forgedError == .malformed("seed 0"), "a record of another level seed is refused")
            var schemaForged: [Record] = walk.records
            schemaForged[0] = Record(schema: head.schema + 1, seed: head.seed, index: head.index, kind: head.kind,
                                     action: head.action, previous: head.previous, next: head.next)
            let schemaError: Refusal? = Inv.refusal { () throws(Refusal) in
                _ = try Play.replay(level: level, records: schemaForged)
            }
            #expect(schemaError == .malformed("schema 0"), "a record of another schema is refused")
        }
    }

    // MARK: INV-05 Undo

    @Test func testStarlitCartoucheUndoBoundary() throws {
        // Direct boundary: a won level is final.
        let fixture: Fixture = Inv.fixtures[4]
        var won: Play = try Inv.played(fixture.level, Inv.winning(fixture))
        let wonError: Refusal? = Inv.refusal { () throws(Refusal) in try won.undo() }
        #expect(wonError == .stage && !won.canUndo, "a won level refuses undo")
        // A stray stroke undone returns to playing with its action refunded; redo restores the failure exactly.
        let level: Level = try Inv.hand(beacon: 0)
        var failed: Play = try Inv.played(level, [.leg(1, 0), .leg(2, 0)])
        let before: Play = failed
        try failed.apply(.leg(3, 0), expecting: failed.fingerprint)
        #expect(failed.stage == .failed, "the stray leg fails")
        let failedPrint: String = failed.fingerprint
        try failed.undo()
        #expect(failed.stage == .playing && failed.failure == nil, "undo from failed returns to playing")
        #expect(failed.actionsSpent == 2 && failed.star == 2 && failed.beat == 3, "undo refunds the action")
        #expect(failed.fingerprint == before.fingerprint, "undo restores the earlier fingerprint")
        try failed.redo()
        #expect(failed.fingerprint == failedPrint && failed.stage == .failed, "redo restores the failure")
        try failed.undo()
        try failed.apply(.leg(1, 0), expecting: failed.fingerprint)
        #expect(!failed.canRedo, "a new leg clears redo")
        // A budget failure undone returns to playing with one action left.
        var spent: Play = try Inv.played(try Inv.hand(budget: 1), [.leg(1, 0)])
        #expect(spent.failure == .budget(1), "a budget of one fails on its only leg")
        try spent.undo()
        #expect(spent.stage == .playing && spent.actionsLeft == 1, "undo of a budget failure refunds the action")
        // Undo while paused stays paused.
        var paused: Play = try Inv.played(try Inv.hand(), [.leg(1, 0)])
        try paused.handle(.pause)
        try paused.undo()
        #expect(paused.stage == .paused && paused.star == 0 && paused.beat == 0, "undo while paused stays paused")
        try paused.redo()
        #expect(paused.stage == .paused && paused.star == 1 && paused.beat == 1, "redo while paused stays paused")
        // Neighbouring inputs: every accepted leg of seeded walks undoes and redoes exactly.
        for index in 0..<Inv.fixtures.count {
            let level: Level = Inv.fixtures[index].level
            var random: SeededRandom = SeededRandom(seed: Inv.seed &+ UInt64(index))
            var play: Play = try Inv.playing(level)
            for _ in 0..<25 {
                guard play.stage == .playing else { break }
                let earlier: Play = play
                let action: Action = Inv.invAction(level, star: play.star, random: &random)
                let error: Refusal? = Inv.refusal { () throws(Refusal) in
                    try play.apply(action, expecting: play.fingerprint)
                }
                guard error == nil else { continue }
                let later: Play = play
                #expect(!play.canRedo, "a new leg clears redo")
                if later.stage == .won {
                    #expect(!play.canUndo, "a won play is final")
                    break
                }
                try play.undo()
                #expect(play.fingerprint == earlier.fingerprint, "undo restores the exact earlier fingerprint")
                #expect(Inv.state(of: play) == Inv.state(of: earlier) && play.legs == earlier.legs,
                        "undo restores the star, beat, strokes and legs")
                #expect(play.actionsSpent == earlier.actionsSpent, "undo restores the actions spent")
                #expect(play.report == earlier.report && play.failure == earlier.failure, "undo restores the report")
                try play.redo()
                #expect(play.fingerprint == later.fingerprint, "redo restores the exact later fingerprint")
                #expect(Inv.state(of: play) == Inv.state(of: later) && play.report == later.report,
                        "redo restores the state and report")
                #expect(play.failure == later.failure, "redo restores the failure")
                if play.stage == .failed {
                    try play.undo()
                    #expect(play.stage == .playing && play.failure == nil, "a failed play undone returns to playing")
                }
            }
        }
    }

    // MARK: INV-07 Failure honesty

    @Test func testStarlitCartoucheFailurehonestyBoundary() throws {
        // Direct boundary: each failure kind names its star or corridor, its beats and its bound; the ship, beat,
        // strokes and legs stay; the failing action is the last record; undo returns to playing.
        let hazard: Hazard = Hazard(corridor: 0, from: 2, to: 4)
        let cases: [(level: Level, action: Action, failure: Failure, code: String)] = [
            (try Inv.hand(closes: [2, 20, 20, 20]), .leg(1, 3), .departure(star: 0, beat: 3, close: 2), "window"),
            (try Inv.hand(hazards: [hazard]), .leg(1, 1), .hazard(corridor: 0, hazard: 0, from: 2, to: 4), "hazard"),
            (try Inv.hand(opens: [0, 3, 0, 0]), .leg(1, 0), .arrival(star: 1, beat: 1, open: 3, close: 20), "window"),
            (try Inv.hand(deadline: 5), .leg(1, 5), .deadline(beat: 6, deadline: 5), "deadline"),
        ]
        for item in cases {
            var play: Play = try Inv.playing(item.level)
            let start: Play = play
            try play.apply(item.action, expecting: play.fingerprint)
            #expect(play.stage == .failed && play.failure == item.failure, "the failure names its real cause")
            #expect(play.failure?.code == item.code, "the failure has its stable code")
            #expect(Inv.state(of: play) == Inv.state(of: start) && play.legs.isEmpty, "a failed leg leaves the ship")
            #expect(play.records.last?.action == item.action && play.records.last?.kind == .leg,
                    "the failing action is the last record")
            try play.undo()
            #expect(play.fingerprint == start.fingerprint && play.stage == .playing, "undo from failed returns")
        }
        // Clear neighbours of each case: on the window's close, one beat clear of the hazard, on the window's open.
        let clearCases: [(level: Level, action: Action)] = [
            (try Inv.hand(closes: [2, 20, 20, 20]), .leg(1, 2)), (try Inv.hand(hazards: [hazard]), .leg(1, 0)),
            (try Inv.hand(hazards: [hazard]), .leg(1, 5)), (try Inv.hand(opens: [0, 3, 0, 0]), .leg(1, 2)),
            (try Inv.hand(deadline: 5), .leg(1, 4)),
        ]
        for item in clearCases {
            let play: Play = try Inv.played(item.level, [item.action])
            #expect(play.stage == .playing && play.failure == nil, "the neighbouring leg is clear")
        }
        let stray: Play = try Inv.played(try Inv.hand(beacon: 0), [.leg(1, 0), .leg(2, 0), .leg(3, 0)])
        #expect(stray.failure == .stroke(corridor: 2) && stray.failure?.code == "stroke", "a stray stroke is named")
        #expect(stray.star == 2 && stray.drawn == [0, 1], "a stray stroke is never drawn")
        // A refusal names its reason and the code r02-g16.action, and the play is unchanged.
        var refused: Play = try Inv.playing(try Inv.hand())
        let reasons: [(action: Action, reason: String)] = [(.leg(4, 0), "unknown star"), (.leg(0, 0), "same star"),
                                                           (.leg(2, 0), "no corridor"), (.leg(1, 9), "wait")]
        for item in reasons {
            let print: String = refused.fingerprint
            let error: Refusal? = Inv.refusal { () throws(Refusal) in try refused.apply(item.action, expecting: print) }
            #expect(error == .action(item.reason) && error?.reasonCode == "r02-g16.action", "a refusal is named")
            #expect(refused.fingerprint == print && refused.records.isEmpty, "a refusal changes nothing")
        }
        // Neighbouring inputs: seeded legs on fixtures with tightened windows and an added hazard fail exactly as the
        // independent computation says; every failure kind is seen.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var seen: Set<String> = []
        for fixture in Inv.fixtures {
            let level: Level = try Inv.tight(fixture.level, random: &random)
            var play: Play = try Inv.playing(level)
            for _ in 0..<30 {
                guard play.stage == .playing else { break }
                let earlier: Play = play
                let action: Action = Inv.invAction(level, star: play.star, random: &random)
                let error: Refusal? = Inv.refusal { () throws(Refusal) in
                    try play.apply(action, expecting: play.fingerprint)
                }
                let expected: (state: Inv.State, failure: Failure?, won: Bool)? =
                    Inv.invOutcome(level, Inv.state(of: earlier), spent: earlier.actionsSpent, action)
                guard let outcome = expected else {
                    #expect(Inv.isAction(error) && play == earlier, "a refused leg names an action refusal")
                    continue
                }
                #expect(error == nil, "a flyable leg is accepted")
                #expect(play.failure == outcome.failure, "the failure equals the independent failure")
                guard let failure = play.failure else { continue }
                seen.insert(failure.code)
                #expect(play.stage == .failed && play.records.last?.action == action, "the failing action is recorded")
                if case .budget(let count) = failure {
                    #expect(count == play.actionsSpent && count == level.budget, "a budget failure names the count")
                } else {
                    #expect(Inv.state(of: play) == Inv.state(of: earlier) && play.legs == earlier.legs,
                            "a failed leg leaves the ship, beat, strokes and legs")
                }
                try play.undo()
                #expect(play.stage == .playing && play.failure == nil, "undo from failed returns to playing")
                #expect(play.fingerprint == earlier.fingerprint, "undo from failed restores the earlier play")
            }
        }
        for code in ["window", "hazard", "deadline", "stroke", "budget"] {
            #expect(seen.contains(code), "the seeded legs meet a \(code) failure")
        }
    }

    // MARK: INV-08 Stability

    @Test func testStarlitCartoucheStabilityBoundary() throws {
        // Direct boundary: the extreme valid level and far beats stay in range without overflow.
        let extreme: Level = try Inv.extreme()
        #expect(extreme.stars.count == 12 && extreme.corridors.count == 24 && extreme.hazards.count == 8,
                "the extreme level holds the most stars, corridors and hazards")
        for star in extreme.stars {
            for beat in [0, 1, 63, 64, 1_000_003, Int.max / 2] {
                let p: Vec = star.position(at: beat)
                #expect(Level.coordinates.contains(p.x) && Level.coordinates.contains(p.y)
                        && Level.coordinates.contains(p.z), "a position stays within −8 … 8 at any beat")
            }
        }
        #expect(Vec(-8, -8, -8).squaredDistance(to: Vec(8, 8, 8)) == 768, "the largest squared distance is exact")
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var levels: [Level] = [extreme]
        for fixture in Inv.fixtures { levels.append(fixture.level) }
        // Neighbouring inputs: seeded walks on the extreme level and the fixtures; at least 500 states checked.
        var states: Int = 0
        for (position, level) in levels.enumerated() {
            let count: Int = level.stars.count
            var play: Play = try Inv.playing(level)
            let steps: Int = position == 0 ? 60 : 12
            for _ in 0..<steps {
                if play.stage == .failed { try play.undo() }
                guard play.stage == .playing else { break }
                let action: Action = Inv.invAction(level, star: play.star, random: &random)
                _ = Inv.refusal { () throws(Refusal) in try play.apply(action, expecting: play.fingerprint) }
                states += 1
                #expect(play.actionsSpent >= 0 && play.actionsSpent <= level.budget, "actions spent within budget")
                #expect(play.star >= 0 && play.star < count, "the ship's star is a real star")
                #expect(play.beat >= 0 && play.beat <= level.deadline, "the beat stays within 0 … the deadline")
                for corridor in play.drawn {
                    #expect(level.symbol.contains(corridor), "a drawn stroke is a real symbol stroke")
                }
                for leg in play.legs {
                    #expect(leg.corridor >= 0 && leg.corridor < level.corridors.count, "a leg's corridor is real")
                    #expect(leg.from >= 0 && leg.from < count && leg.to >= 0 && leg.to < count, "its stars are real")
                    #expect(Level.travels.contains(leg.arrive - leg.depart), "a leg's travel stays in 1 … 3")
                    #expect(StarlitCartoucheChart.waits.contains(leg.wait), "a leg's wait stays in 0 … 8")
                }
                let report: Report = play.report
                #expect(report.mismatch == report.missing.count + report.stray.count, "mismatch = missing + stray")
                #expect(report.drawn == play.drawn.sorted() && report.stray.isEmpty, "the report's strokes are valid")
                #expect(report.missing.count <= level.symbol.count, "missing strokes are bounded by the symbol")
                if let clearance = report.clearance { #expect(clearance >= 0, "the clearance is non-negative") }
                for star in level.stars {
                    let p: Vec = star.position(at: play.beat)
                    #expect(Level.coordinates.contains(p.x) && Level.coordinates.contains(p.y)
                            && Level.coordinates.contains(p.z), "every star stays within −8 … 8")
                }
                #expect(play.fingerprint.count == 64, "the fingerprint is a SHA-256 hex")
            }
        }
        #expect(states >= 500, "at least 500 seeded states are checked")
    }

    // MARK: INV-09 Save

    @Test func testStarlitCartoucheSaveBoundary() throws {
        // Direct boundary: a stored level round-trips byte for byte; truncated, newer, older and edited forms are
        // refused.
        let level: Level = Inv.fixtures[6].level
        let data: Data = level.encoded()
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level && decoded.encoded() == data, "a stored level round-trips byte for byte")
        let coded: Level = try JSONDecoder().decode(Level.self, from: try JSONEncoder().encode(level))
        #expect(coded == level && coded.fingerprint == level.fingerprint, "a level round-trips through Codable")
        let half: Data = data.prefix(data.count / 2)
        let truncated: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Level.decode(half) }
        #expect(truncated != nil, "a truncated stored level is refused")
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"schema\":1"), "the stored form names its schema")
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        let newerError: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(newer.utf8)) }
        #expect(newerError == .newerSchema(2), "a newer stored level is refused")
        let older: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        let olderError: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(older.utf8)) }
        #expect(olderError == .malformed("schema 0"), "a schema below 1 is refused")
        let forged: String = text.replacingOccurrences(of: level.fingerprint, with: Inv.staleFingerprint)
        let forgedError: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(forged.utf8)) }
        #expect(forgedError == .malformed("fingerprint"), "an edited fingerprint is refused")
        // Neighbouring inputs: seeded single-byte edits are refused or decode to the same level.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        let replacements: [UInt8] = Array("0123456789-\",:[]{}aeftnrsluxyz ".utf8)
        for fixture in Inv.fixtures.prefix(8) {
            let stored: [UInt8] = Array(fixture.level.encoded())
            #expect((try Level.decode(Data(stored))) == fixture.level, "every fixture round-trips")
            for _ in 0..<250 {
                var edited: [UInt8] = stored
                let position: Int = random.int(0...(stored.count - 1))
                let byte: UInt8 = replacements[random.int(0...(replacements.count - 1))]
                guard byte != edited[position] else { continue }
                edited[position] = byte
                do {
                    let back: Level = try Level.decode(Data(edited))
                    #expect(back == fixture.level, "a decoded single-byte edit is the same level")
                } catch {
                    #expect(!error.reasonCode.isEmpty, "a single-byte edit is refused with a reason")
                }
            }
        }
        // A stored record trace replays to the same play.
        var trace: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(10) {
            let walk: Play = try Inv.invWalk(fixture.level, steps: 20, random: &trace)
            let recordData: Data = try JSONEncoder().encode(walk.records)
            let records: [Record] = try JSONDecoder().decode([Record].self, from: recordData)
            #expect(records == walk.records, "records round-trip")
            let back: Play = try Play.replay(level: try Level.decode(fixture.level.encoded()), records: records)
            #expect(back.records == walk.records, "a stored trace replays to the same records")
            #expect(Inv.state(of: back) == Inv.state(of: walk) && back.failure == walk.failure,
                    "a stored trace replays to the same play")
        }
    }

    // MARK: INV-10 Renderer purity

    @Test func testStarlitCartoucheRendererpurityBoundary() throws {
        // Direct boundary: naming, describing and sampling star positions never changes a play.
        let fixture: Fixture = Inv.fixtures[7]
        let actions: [Action] = Inv.winning(fixture)
        let play: Play = try Inv.played(fixture.level, Array(actions.dropLast()))
        let print: String = play.fingerprint
        let report: Report = play.report
        for index in fixture.level.stars.indices {
            #expect(fixture.level.starName(index) == "star \(index)", "stars named in words")
            for frame in 0..<120 { _ = fixture.level.stars[index].position(at: play.beat + frame) }
        }
        for index in fixture.level.corridors.indices { _ = fixture.level.corridorName(index) }
        _ = fixture.level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        #expect(play.fingerprint == print && play.report == report, "names, descriptions and sampling change nothing")
        // The play is a value type: a changed copy leaves the original alone.
        var copy: Play = play
        try copy.apply(actions[actions.count - 1], expecting: copy.fingerprint)
        #expect(copy.stage == .won && play.fingerprint == print, "a copy's action never changes the original")
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
        let allowed: Set<String> = ["Foundation", "VisualCoreMath", "VisualCoreSimulation"]
        for source in try Inv.kernelSources() {
            for line in source.text.split(separator: "\n") where line.hasPrefix("import ") {
                let module: String = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "\(source.name) imports only the allowed modules")
            }
        }
        // Neighbouring inputs: the report is a pure function of the level, star, beat, strokes and legs, in any call
        // order; a level differing only in its id gives identical outcomes; describing never feeds back.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures {
            let renamed: Level = try Inv.variant(fixture.level, id: "renamed-" + fixture.level.id)
            var a: Play = try Inv.playing(fixture.level)
            var b: Play = try Inv.playing(renamed)
            var visited: [Play] = [a]
            for _ in 0..<15 {
                if a.stage == .failed {
                    try a.undo()
                    try b.undo()
                }
                guard a.stage == .playing else { break }
                let action: Action = Inv.invAction(fixture.level, star: a.star, random: &random)
                let first: Refusal? = Inv.refusal { () throws(Refusal) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let describedBefore: String = a.fingerprint
                _ = fixture.level.progressDescription(report: a.report, actionsLeft: a.actionsLeft)
                for index in fixture.level.stars.indices {
                    _ = fixture.level.starName(index)
                    _ = fixture.level.stars[index].position(at: a.beat)
                }
                #expect(a.fingerprint == describedBefore, "describing never changes the fingerprint")
                let second: Refusal? = Inv.refusal { () throws(Refusal) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(first == second, "a renamed level accepts and refuses alike")
                #expect(Inv.state(of: a) == Inv.state(of: b) && a.legs == b.legs, "a renamed level flies alike")
                #expect(a.report == b.report && a.failure == b.failure && a.stage == b.stage,
                        "a renamed level gives identical reports and outcomes")
                #expect(a.report == StarlitCartoucheChart.report(fixture.level, star: a.star, beat: a.beat,
                                                                  drawn: a.drawn, legs: a.legs),
                        "the report is a function of the route")
                #expect(fixture.level.progressDescription(report: a.report, actionsLeft: a.actionsLeft)
                        == renamed.progressDescription(report: b.report, actionsLeft: b.actionsLeft),
                        "descriptions depend only on the report")
                visited.append(a)
            }
            // The same routes asked again in reverse order give the same reports.
            var position: Int = visited.count - 1
            while position >= 0 {
                let p: Play = visited[position]
                let again: Report = StarlitCartoucheChart.report(fixture.level, star: p.star, beat: p.beat,
                                                                 drawn: p.drawn, legs: p.legs)
                #expect(again == p.report, "a report never depends on call order")
                position -= 1
            }
        }
    }
}
