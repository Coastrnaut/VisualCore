// CelestialEclipseLabInvariantTests — feature 461 (R02-G17-01) T-R02G1701-006 (FR-R02G1701-012; the source's invariants
// R2-G17-INV-01 … 05 and INV-07 … 10 on Celestial Eclipse Lab), modelled on StarlitCartoucheInvariantTests (feature
// 451). Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,466: fixtures
// drawn from it, random phases, unknown bodies −1 and n, fixed bodies, offsets −1 and period, the current offset, an
// action budget ± 1, horizons h ± 1, a reversed or shortened target, ids changed, a byte of a stored level changed).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G17-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; ticks are whole numbers 0 … horizon − 1. A body's position repeats with its
//   period and a phase one larger is the same as one tick later; every interval lies inside the horizon and one that
//   runs to the end stops at tick horizon − 1; the intervals of horizon h are those of horizon h + 1 clipped at h − 1.
//   The same actions give the same fingerprints and timelines however many pauses and reads lie between them; an idle
//   play never spends an action or fails; the kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: an accepted phase change spends exactly 1 action, the run none; refusals spend nothing and
//   change nothing; with no action left a phase change is refused `budget` while the run is still accepted; the
//   refusal order is stage, stale, action, budget.
// - INV-03 Goal: a run wins exactly when the timeline's events match the target in order inside their windows (judged
//   against an independent interval scan and judge); the known phases win; a reversed target is judged by the same
//   independent judge; a target shortened to a prefix keeps the known phases winning.
// - INV-04 Repeatability: the same inputs give the same records, fingerprints, timeline and outcome on independent runs
//   and through replay; a trace with a record removed, or the trace of another level, is refused.
// - INV-05 Undo: undo restores the exact prior fingerprint, phases, actions spent, timeline and failure; redo the later
//   one; a new action clears redo; a won level is final; a failed run returns to playing with the phases before it;
//   undo while paused stays paused.
// - INV-07 Failure honesty: a failed run names `unwanted`, `window` or `horizon` with the bodies, tick and window equal
//   to an independent judge; the phases and actions spent stay as they were; the last record ends at the current
//   fingerprint; refusals carry their `r02-g17.*` codes; undo from a failure returns to playing.
// - INV-08 Stability: an extreme valid level (6 bodies of radius 8 on orbits of 24 positions spanning coordinates ±32,
//   horizon 96, 6 targets, a 64-character id, the largest seed, budget 24) and the fixtures walk through at least 500
//   seeded states without a crash or overflow; every phase, interval, match count and budget value stays bounded.
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); any
//   single-byte edit is refused or decodes to the same level; truncated, newer, older and fingerprint-edited forms are
//   refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the timeline is a pure function of the level and the phases (never of time, call order or
//   presentation); names and descriptions read for drawing never change the play; a level differing only in its id
//   gives identical timelines and outcomes; the play is a value type; the kernel sources import only Foundation,
//   VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabInvariantTests {
    typealias Play = CelestialEclipseLabPlay
    typealias Level = CelestialEclipseLabLevel
    typealias Action = CelestialEclipseLabAction
    typealias Failure = CelestialEclipseLabFailure
    typealias Timeline = CelestialEclipseLabTimeline
    typealias Body = CelestialEclipseLabBody
    typealias Vec = CelestialEclipseLabVector
    typealias Target = CelestialEclipseLabTarget
    typealias Fixture = CelestialEclipseLabFixture
    typealias Record = CelestialEclipseLabRecord
    typealias Refusal = CelestialEclipseLabError
    typealias Sky = CelestialEclipseLabSky

    /// An interval without its visibility class, for comparisons with the independent scan.
    struct Span: Equatable {
        /// The body in front.
        let front: Int
        /// The body behind.
        let back: Int
        /// The first eclipse tick.
        let first: Int
        /// The last eclipse tick.
        let last: Int
    }

    /// The helpers, builders and independent computations of this file.
    private enum Inv {
        /// The invariant (neighbouring-input) seed.
        static let seed: UInt64 = 2_466

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The kernel sources the scans read when present (the Core directory next to this test directory).
        static let kernelFiles: [String] = ["CelestialEclipseLabError.swift", "CelestialEclipseLabLevel.swift",
                                            "CelestialEclipseLabSky.swift", "CelestialEclipseLabPlay.swift",
                                            "CelestialEclipseLabRules.swift"]

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 40, seed: seed)

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

        /// Whether `error` is a `.malformed` refusal (any payload).
        static func isMalformed(_ error: Refusal?) -> Bool {
            if case .malformed = error { return true }
            return false
        }

        /// A square orbit of four positions around (`cx`, `cy`) at depth `z`.
        static func square(_ cx: Int, _ cy: Int, z: Int) -> [Vec] {
            [Vec(cx - 1, cy - 1, z), Vec(cx + 1, cy - 1, z), Vec(cx + 1, cy + 1, z), Vec(cx - 1, cy + 1, z)]
        }

        /// The hand level: body 0 fixed (radius 2, a square orbit of period 4 around the origin at depth 10), body 1
        /// movable (radius 2, a line x = −12, −9, …, 9 of period 8 at depth 0), horizon 8, the target body 0 in front
        /// of body 1 in ticks 2 … 5. Phases [0, 3] fail `window` at tick 0; phases [0, 0] win (first eclipse at
        /// tick 3).
        static func hand(phases: [Int] = [0, 3], budget: Int = 3, id: String = "inv-hand",
                         seed: UInt64 = 1) throws(Refusal) -> Level {
            var line: [Vec] = []
            for k in 0..<8 { line.append(Vec(-12 + 3 * k, 0, 0)) }
            let bodies: [Body] = [Body(orbit: square(0, 0, z: 10), radius: 2, fixed: true),
                                  Body(orbit: line, radius: 2)]
            return try Level(id: id, seed: seed, difficulty: 1, bodies: bodies, horizon: 8,
                             target: [Target(front: 0, back: 1, open: 2, close: 5)], phases: phases, budget: budget)
        }

        /// A level whose bodies never meet: body 0 fixed around the origin, body 1 around (20, 0), radius 1 each; the
        /// target body 0 in front of body 1 in ticks 0 … 7, horizon 8. A run fails `horizon`.
        static func apart() throws(Refusal) -> Level {
            let bodies: [Body] = [Body(orbit: square(0, 0, z: 10), radius: 1, fixed: true),
                                  Body(orbit: square(20, 0, z: 0), radius: 1)]
            return try Level(id: "inv-apart", seed: 2, difficulty: 1, bodies: bodies, horizon: 8,
                             target: [Target(front: 0, back: 1, open: 0, close: 7)], phases: [0, 0], budget: 2)
        }

        /// A level whose bodies 0 and 1 (fixed, radius 2, the same square) always overlap while body 2 stays far
        /// away; the target is body 0 in front of body 2. A run fails `unwanted` on body 0 over body 1 at tick 0.
        static func crowded() throws(Refusal) -> Level {
            let bodies: [Body] = [Body(orbit: square(0, 0, z: 20), radius: 2, fixed: true),
                                  Body(orbit: square(0, 0, z: 10), radius: 2, fixed: true),
                                  Body(orbit: square(20, 0, z: 0), radius: 1)]
            return try Level(id: "inv-crowded", seed: 3, difficulty: 1, bodies: bodies, horizon: 8,
                             target: [Target(front: 0, back: 2, open: 0, close: 7)], phases: [0, 0, 0], budget: 2)
        }

        /// `level` with some values replaced.
        static func variant(_ level: Level, id: String? = nil, seed: UInt64? = nil, target: [Target]? = nil,
                            budget: Int? = nil) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: level.difficulty, bodies: level.bodies,
                      horizon: level.horizon, target: target ?? level.target, phases: level.phases,
                      budget: budget ?? level.budget, tutorial: level.tutorial)
        }

        /// The extreme valid level: 6 bodies of radius 8 on 24-position orbits spanning x and y −32 … 32, body i at
        /// depths 32 − 12 i and 30 − 12 i (body 0 fixed), horizon 96, six targets body 4 in front of body 5 at tick 95
        /// (never all matched, so the start cannot win), a 64-character id, the largest seed, budget 24, a tutorial.
        static func extreme() throws(Refusal) -> Level {
            var bodies: [Body] = []
            for i in 0..<6 {
                var orbit: [Vec] = []
                for k in 0..<24 {
                    let x: Int = (k * 7 + i * 5) % 65 - 32
                    let y: Int = (k * 11 + i * 3) % 65 - 32
                    let z: Int = 32 - 12 * i - (k % 2) * 2
                    orbit.append(Vec(x, y, z))
                }
                bodies.append(Body(orbit: orbit, radius: 8, fixed: i == 0))
            }
            var target: [Target] = []
            for _ in 0..<6 { target.append(Target(front: 4, back: 5, open: 95, close: 95)) }
            var phases: [Int] = []
            for _ in 0..<6 { phases.append(0) }
            return try Level(id: String(repeating: "z", count: 64), seed: UInt64.max, difficulty: 5, bodies: bodies,
                             horizon: 96, target: target, phases: phases, budget: 24, tutorial: true)
        }

        /// Seeded phases for `level`: fixed bodies keep their starting phase, movable ones take a random offset.
        static func randomPhases(_ level: Level, random: inout SeededRandom) -> [Int] {
            var phases: [Int] = []
            for index in level.bodies.indices {
                let body: Body = level.bodies[index]
                phases.append(body.fixed ? level.phases[index] : random.int(0...(body.period - 1)))
            }
            return phases
        }

        /// The phase changes that take `from` to `to`, in body order.
        static func changes(from: [Int], to: [Int]) -> [Action] {
            var actions: [Action] = []
            for index in from.indices where from[index] != to[index] { actions.append(.phase(index, to[index])) }
            return actions
        }

        /// A seeded action for `play`: mostly a valid phase change, sometimes an unknown body (−1 or n), a fixed body,
        /// an offset −1 or the period, the current offset, or the run.
        static func invAction(_ play: Play, random: inout SeededRandom) -> Action {
            let level: Level = play.level
            let count: Int = level.bodies.count
            let roll: Int = random.int(0...19)
            if roll == 0 { return .phase(random.int(0...1) == 0 ? -1 : count, 0) }
            let body: Int = random.int(0...(count - 1))
            let period: Int = level.bodies[body].period
            if roll == 1 { return .phase(body, random.int(0...1) == 0 ? -1 : period) }
            if roll == 2 { return .phase(body, play.phases[body]) }
            if roll == 3 { return .run }
            return .phase(body, random.int(0...(period - 1)))
        }

        /// A seeded walk of up to `steps` actions, undos, redos, pauses and resumes on `level` (refusals skipped).
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
                    let action: Action = invAction(play, random: &random)
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

        /// The lines of `text` that are not comments.
        static func codeLines(_ text: String) -> [String] {
            var lines: [String] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                lines.append(String(line))
            }
            return lines
        }

        // MARK: Independent computations

        /// The spans of `timeline`'s intervals.
        static func spans(_ timeline: Timeline) -> [Span] {
            spans(timeline.intervals)
        }

        /// The spans of `intervals`.
        static func spans(_ intervals: [CelestialEclipseLabInterval]) -> [Span] {
            var result: [Span] = []
            for interval in intervals {
                result.append(Span(front: interval.front, back: interval.back, first: interval.first,
                                   last: interval.last))
            }
            return result
        }

        /// A body's position by an independent computation: orbit[(tick + phase) mod period].
        static func invPosition(_ body: Body, tick: Int, phase: Int) -> Vec {
            let period: Int = body.orbit.count
            let index: Int = ((tick + phase) % period + period) % period
            return body.orbit[index]
        }

        /// The front and back of the pair (i, j) by an independent scan of the depths.
        static func invOrder(_ level: Level, _ i: Int, _ j: Int) -> (front: Int, back: Int) {
            var lowestI: Int = Int.max
            for p in level.bodies[i].orbit { lowestI = min(lowestI, p.z) }
            var highestJ: Int = Int.min
            for p in level.bodies[j].orbit { highestJ = max(highestJ, p.z) }
            return lowestI > highestJ ? (i, j) : (j, i)
        }

        /// The eclipse spans of `level` with `phases` by an independent tick-by-tick scan, ordered by first tick, then
        /// front, then back.
        static func invSpans(_ level: Level, phases: [Int]) -> [Span] {
            var result: [Span] = []
            let count: Int = level.bodies.count
            for i in 0..<count {
                for j in (i + 1)..<count {
                    let pair: (front: Int, back: Int) = invOrder(level, i, j)
                    let a: Body = level.bodies[pair.front]
                    let b: Body = level.bodies[pair.back]
                    let reach: Int = (a.radius + b.radius) * (a.radius + b.radius)
                    var start: Int = -1
                    for tick in 0..<level.horizon {
                        let pa: Vec = invPosition(a, tick: tick, phase: phases[pair.front])
                        let pb: Vec = invPosition(b, tick: tick, phase: phases[pair.back])
                        let dx: Int = pa.x - pb.x
                        let dy: Int = pa.y - pb.y
                        let meets: Bool = dx * dx + dy * dy < reach
                        if meets && start < 0 { start = tick }
                        if !meets && start >= 0 {
                            result.append(Span(front: pair.front, back: pair.back, first: start, last: tick - 1))
                            start = -1
                        }
                    }
                    if start >= 0 {
                        result.append(Span(front: pair.front, back: pair.back, first: start, last: level.horizon - 1))
                    }
                }
            }
            result.sort { lhs, rhs in
                if lhs.first != rhs.first { return lhs.first < rhs.first }
                if lhs.front != rhs.front { return lhs.front < rhs.front }
                return lhs.back < rhs.back
            }
            return result
        }

        /// The failure a run of `level` with `phases` ends with, by an independent judge (clarification Q3); nil
        /// when it wins.
        static func invJudge(_ level: Level, phases: [Int]) -> Failure? {
            var next: Int = 0
            for span in invSpans(level, phases: phases) {
                if next == level.target.count { return nil }
                let wanted: Target = level.target[next]
                if span.front == wanted.front && span.back == wanted.back {
                    if span.first >= wanted.open && span.first <= wanted.close {
                        next += 1
                        continue
                    }
                    return .window(front: wanted.front, back: wanted.back, tick: span.first, open: wanted.open,
                                   close: wanted.close)
                }
                return .unwanted(front: span.front, back: span.back, tick: span.first)
            }
            if next < level.target.count {
                let wanted: Target = level.target[next]
                return .horizon(front: wanted.front, back: wanted.back, open: wanted.open, close: wanted.close)
            }
            return nil
        }

        /// The spans of a longer horizon clipped to horizon `h`: those starting before h, ending at most at h − 1.
        static func clip(_ spans: [Span], to h: Int) -> [Span] {
            var result: [Span] = []
            for span in spans where span.first <= h - 1 {
                result.append(Span(front: span.front, back: span.back, first: span.first, last: min(span.last, h - 1)))
            }
            return result
        }

        /// The play of `level` with its phases set to `phases` (a budget-24 variant so every change fits), then run.
        static func runOf(_ level: Level, phases: [Int]) throws -> Play {
            let roomy: Level = try variant(level, budget: Level.budgets.upperBound)
            var actions: [Action] = changes(from: roomy.phases, to: phases)
            actions.append(.run)
            return try played(roomy, actions)
        }
    }

    // MARK: INV-01 Time

    @Test func testCelestialEclipseLabTimeBoundary() throws {
        // Direct boundary: hand level, phases [0, 4]: body 1 is at x = 0 and 3 in ticks 0 … 1 and back at x = −3 at
        // tick 7, the last tick of the horizon: intervals 0 … 1 and 7 … 7 (stopped at horizon − 1).
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        try play.apply(.phase(1, 4), expecting: play.fingerprint)
        let expected: [Span] = [Span(front: 0, back: 1, first: 0, last: 1), Span(front: 0, back: 1, first: 7, last: 7)]
        #expect(Inv.spans(play.timeline) == expected)
        #expect(Inv.invSpans(level, phases: [0, 4]) == expected)
        #expect(play.timeline.failure == .window(front: 0, back: 1, tick: 0, open: 2, close: 5))
        // Positions repeat with the period; a phase one larger is one tick later.
        for body in level.bodies {
            for tick in 0..<level.horizon {
                for phase in 0..<body.period {
                    #expect(body.position(at: tick + body.period, phase: phase)
                        == body.position(at: tick, phase: phase))
                    #expect(body.position(at: tick, phase: (phase + 1) % body.period)
                        == body.position(at: tick + 1, phase: phase))
                }
            }
        }
        // Pauses and reads between the same actions change nothing; an idle play spends nothing and never fails.
        let actions: [Action] = [.phase(1, 4), .phase(1, 0)]
        let direct: Play = try Inv.played(level, actions)
        var slow: Play = try Inv.playing(level)
        for action in actions {
            for _ in 0..<3 {
                try slow.handle(.pause)
                _ = level.progressDescription(timeline: slow.timeline, actionsLeft: slow.actionsLeft)
                try slow.handle(.resume)
            }
            try slow.apply(action, expecting: slow.fingerprint)
        }
        #expect(slow.fingerprint == direct.fingerprint)
        #expect(slow.timeline == direct.timeline && slow.phases == direct.phases)
        #expect(slow.actionsSpent == direct.actionsSpent)
        var idle: Play = try Inv.playing(level)
        for _ in 0..<10 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.actionsSpent == 0 && idle.failure == nil && idle.stage == .playing)
        #expect(idle.timeline == Sky.timeline(level, phases: level.phases))

        // Seeded neighbours: horizons h + 1 and h − 1 give the same intervals clipped at the shorter horizon.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var compared: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let base: Level = fixture.level
            let phases: [Int] = Inv.randomPhases(base, random: &random)
            let spans: [Span] = Inv.spans(Sky.intervals(base, phases: phases))
            #expect(spans == Inv.invSpans(base, phases: phases))
            for span in spans { #expect(span.first >= 0 && span.first <= span.last && span.last < base.horizon) }
            let longer: Level = try Level.probe(bodies: base.bodies, horizon: base.horizon + 1, target: base.target,
                                                phases: phases)
            #expect(Inv.clip(Inv.spans(Sky.intervals(longer, phases: phases)), to: base.horizon) == spans)
            compared += 1
            if base.horizon - 1 >= Level.horizons.lowerBound,
               let shorter = try? Level.probe(bodies: base.bodies, horizon: base.horizon - 1, target: base.target,
                                              phases: phases) {
                #expect(Inv.spans(Sky.intervals(shorter, phases: phases)) == Inv.clip(spans, to: base.horizon - 1))
                compared += 1
            }
        }
        #expect(compared >= 24)
        // No clock, time interval or floating-point value in the kernel sources.
        let tokens: [String] = ["Da" + "te(", "Continuous" + "Clock", "Suspending" + "Clock", "Time" + "Interval",
                                "CFAbsolute" + "Time", "Dispatch" + "Time", "Dou" + "ble", "Flo" + "at"]
        for source in try Inv.kernelSources() {
            for line in Inv.codeLines(source.text) {
                for token in tokens { #expect(!line.contains(token), "\(source.name): \(token)") }
            }
        }
    }

    // MARK: INV-02 Input budget

    @Test func testCelestialEclipseLabInputbudgetBoundary() throws {
        // Direct boundary: budget 1. The phase change spends the only action; the next is refused `budget`, a fixed
        // body or the current offset `action` (action before budget), a stale fingerprint `stale`; the run is free.
        let level: Level = try Inv.hand(budget: 1)
        var loading: Play = Play(level: level)
        #expect(Inv.refusal { () throws(Refusal) in try loading.apply(.phase(9, 9), expecting: Inv.staleFingerprint) }
            == .stage)
        var play: Play = try Inv.playing(level)
        #expect(play.actionsLeft == 1)
        try play.apply(.phase(1, 0), expecting: play.fingerprint)
        #expect(play.actionsSpent == 1 && play.actionsLeft == 0)
        let spent: Play = play
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.phase(1, 1), expecting: play.fingerprint) }
            == .budget)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.phase(0, 1), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.phase(1, 0), expecting: play.fingerprint)
        }))
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.phase(1, 1), expecting: Inv.staleFingerprint) }
            == .stale)
        #expect(play == spent)
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.actionsSpent == 1 && play.stage == .won)
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.run, expecting: play.fingerprint) } == .stage)

        // Seeded neighbours: a budget of exactly the needed changes wins, one less is refused on the last change, one
        // more leaves an action; random actions spend 1 per accepted change and nothing otherwise.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var tight: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let needed: Int = fixture.actions.count - 1
            let changes: [Action] = Array(fixture.actions.dropLast())
            let exact: Level = try Inv.variant(fixture.level, budget: needed)
            var won: Play = try Inv.played(exact, changes)
            #expect(won.actionsLeft == 0)
            try won.apply(.run, expecting: won.fingerprint)
            #expect(won.stage == .won && won.actionsSpent == needed)
            if needed + 1 <= Level.budgets.upperBound {
                let roomy: Level = try Inv.variant(fixture.level, budget: needed + 1)
                let left: Play = try Inv.played(roomy, changes)
                #expect(left.actionsLeft == 1)
            }
            if needed - 1 >= Level.budgets.lowerBound {
                let short: Level = try Inv.variant(fixture.level, budget: needed - 1)
                var cut: Play = try Inv.played(short, Array(changes.dropLast()))
                let before: Play = cut
                let last: Action = changes[changes.count - 1]
                #expect(Inv.refusal { () throws(Refusal) in try cut.apply(last, expecting: cut.fingerprint) }
                    == .budget)
                #expect(cut == before)
                try cut.apply(.run, expecting: cut.fingerprint)
                #expect(cut.actionsSpent == needed - 1)
                #expect(cut.failure == Inv.invJudge(short, phases: cut.phases))
                tight += 1
            }
            var walker: Play = try Inv.playing(fixture.level)
            for _ in 0..<12 {
                if walker.stage != .playing { break }
                let action: Action = Inv.invAction(walker, random: &random)
                let spentBefore: Int = walker.actionsSpent
                let copy: Play = walker
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walker.apply(action, expecting: walker.fingerprint)
                }
                if refused != nil {
                    #expect(walker == copy)
                } else if action == .run {
                    #expect(walker.actionsSpent == spentBefore)
                } else {
                    #expect(walker.actionsSpent == spentBefore + 1)
                }
                #expect(walker.actionsLeft >= 0 && walker.actionsLeft <= fixture.level.budget)
            }
        }
        #expect(tight > 0)
    }

    // MARK: INV-03 Goal

    @Test func testCelestialEclipseLabGoalBoundary() throws {
        // Direct boundary: phases [0, 0] put the first eclipse at tick 3 inside the window 2 … 5 (a win); the
        // starting phases [0, 3] put it at tick 0, one tick outside the window's reach (a failure).
        let level: Level = try Inv.hand()
        let won: Play = try Inv.played(level, [.phase(1, 0), .run])
        #expect(won.stage == .won && won.failure == nil && won.timeline.matched == 1 && won.timeline.wins)
        let failed: Play = try Inv.played(level, [.run])
        #expect(failed.stage == .failed && failed.failure != nil && failed.timeline.matched == 0)
        #expect(Inv.invJudge(level, phases: [0, 0]) == nil)
        for offset in 0..<8 {
            let judged: Failure? = Inv.invJudge(level, phases: [0, offset])
            #expect(Sky.timeline(level, phases: [0, offset]).failure == judged)
        }

        // Seeded neighbours: the known phases win; random phases win exactly when the independent judge says so; a
        // reversed target is judged the same way; a target cut to a prefix keeps the known phases winning.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var reversedLosses: Int = 0
        var reversedTried: Int = 0
        for fixture in Inv.fixtures {
            let level: Level = fixture.level
            let known: Play = try Inv.played(level, fixture.actions)
            #expect(known.stage == .won)
            #expect(Inv.invJudge(level, phases: fixture.winning) == nil)
            let phases: [Int] = Inv.randomPhases(level, random: &random)
            let run: Play = try Inv.runOf(level, phases: phases)
            let judged: Failure? = Inv.invJudge(level, phases: phases)
            #expect(run.failure == judged)
            #expect((run.stage == .won) == (judged == nil))
            if level.target.count >= 2 {
                var reversed: [Target] = []
                var index: Int = level.target.count - 1
                while index >= 0 {
                    reversed.append(level.target[index])
                    index -= 1
                }
                if reversed != level.target, let flipped = try? Inv.variant(level, target: reversed) {
                    let flippedRun: Play = try Inv.runOf(flipped, phases: fixture.winning)
                    let flippedJudge: Failure? = Inv.invJudge(flipped, phases: fixture.winning)
                    #expect(flippedRun.failure == flippedJudge)
                    reversedTried += 1
                    if flippedJudge != nil { reversedLosses += 1 }
                }
                let prefix: [Target] = Array(level.target.prefix(level.target.count - 1))
                if let cut = try? Inv.variant(level, target: prefix) {
                    #expect(Sky.timeline(cut, phases: fixture.winning).wins)
                }
            }
        }
        #expect(reversedTried == 0 || reversedLosses > 0)
    }

    // MARK: INV-04 Repeatability

    @Test func testCelestialEclipseLabRepeatabilityBoundary() throws {
        // Direct boundary: the same inputs on two plays and through replay give the same records and fingerprints.
        let level: Level = try Inv.hand()
        let actions: [Action] = [.phase(1, 4), .phase(1, 0), .run]
        let first: Play = try Inv.played(level, actions)
        let second: Play = try Inv.played(level, actions)
        #expect(first == second)
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.timeline == second.timeline && first.stage == .won)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(replayed.records == first.records && replayed.fingerprint == first.fingerprint)
        #expect(replayed.stage == first.stage && replayed.phases == first.phases)
        // The trace of another level (another seed) and a trace with a record removed are refused.
        let other: Level = try Inv.hand(id: "inv-other", seed: 7)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
            _ = try Play.replay(level: other, records: first.records)
        }))
        var gapped: [Record] = first.records
        var removable: Int = -1
        for index in gapped.indices where gapped[index].action == .phase(1, 4) { removable = index }
        #expect(removable >= 0 && removable < gapped.count - 1)
        if removable >= 0 {
            gapped.remove(at: removable)
            #expect(Inv.refusal { () throws(Refusal) in _ = try Play.replay(level: level, records: gapped) } != nil)
        }

        // Seeded neighbours: seeded walks repeated from the same generator state are equal and replay exactly; every
        // prefix of a trace replays to the fingerprint its last record names.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(20) {
            let saved: SeededRandom = random
            let a: Play = try Inv.invWalk(fixture.level, steps: 24, random: &random)
            var again: SeededRandom = saved
            let b: Play = try Inv.invWalk(fixture.level, steps: 24, random: &again)
            #expect(a == b)
            #expect(again == random)
            let back: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(back.fingerprint == a.fingerprint && back.records == a.records && back.timeline == a.timeline)
            if a.records.count >= 2 {
                let cut: Int = random.int(1...(a.records.count - 1))
                let prefix: [Record] = Array(a.records.prefix(cut))
                let partial: Play = try Play.replay(level: fixture.level, records: prefix)
                #expect(partial.fingerprint == prefix[prefix.count - 1].next)
            }
        }
    }

    // MARK: INV-05 Undo

    @Test func testCelestialEclipseLabUndoBoundary() throws {
        // Direct boundary: undo restores the exact earlier fingerprint, redo the later one; a new action clears redo.
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        #expect(!play.canUndo)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.undo() }))
        let start: String = play.fingerprint
        let startTimeline: Timeline = play.timeline
        try play.apply(.phase(1, 0), expecting: play.fingerprint)
        let after: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == start && play.phases == [0, 3] && play.actionsSpent == 0)
        #expect(play.timeline == startTimeline && play.canRedo)
        try play.redo()
        #expect(play.fingerprint == after && play.phases == [0, 0] && play.actionsSpent == 1)
        try play.undo()
        try play.apply(.phase(1, 1), expecting: play.fingerprint)
        #expect(!play.canRedo)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.redo() }))
        // A failed run returns to playing with the phases before it.
        var failing: Play = try Inv.playing(level)
        let beforeRun: String = failing.fingerprint
        try failing.apply(.run, expecting: failing.fingerprint)
        #expect(failing.stage == .failed && failing.canUndo)
        try failing.undo()
        #expect(failing.stage == .playing && failing.failure == nil && failing.phases == [0, 3])
        #expect(failing.fingerprint == beforeRun)
        // A won level is final.
        var won: Play = try Inv.played(level, [.phase(1, 0), .run])
        #expect(won.stage == .won && !won.canUndo)
        #expect(Inv.refusal { () throws(Refusal) in try won.undo() } == .stage)
        // Undo while paused stays paused.
        var paused: Play = try Inv.played(level, [.phase(1, 0)])
        try paused.handle(.pause)
        try paused.undo()
        #expect(paused.stage == .paused && paused.phases == [0, 3] && paused.actionsSpent == 0)

        // Seeded neighbours: every accepted action of a seeded walk undoes to the exact earlier state and redoes to the
        // exact later one.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var checked: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            var walker: Play = try Inv.playing(fixture.level)
            for _ in 0..<10 {
                if walker.stage != .playing { break }
                let action: Action = Inv.invAction(walker, random: &random)
                let earlier: Play = walker
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walker.apply(action, expecting: walker.fingerprint)
                }
                if refused != nil { continue }
                let later: Play = walker
                if walker.stage == .won {
                    #expect(!walker.canUndo)
                    break
                }
                try walker.undo()
                #expect(walker.fingerprint == earlier.fingerprint && walker.phases == earlier.phases)
                #expect(walker.actionsSpent == earlier.actionsSpent && walker.timeline == earlier.timeline)
                #expect(walker.failure == earlier.failure && walker.stage == .playing)
                try walker.redo()
                #expect(walker.fingerprint == later.fingerprint && walker.phases == later.phases)
                #expect(walker.actionsSpent == later.actionsSpent && walker.stage == later.stage)
                checked += 1
                if walker.stage == .failed { try walker.undo() }
            }
        }
        #expect(checked > 24)
    }

    // MARK: INV-07 Failure honesty

    @Test func testCelestialEclipseLabFailurehonestyBoundary() throws {
        // Direct boundary: one level per failure code, each named with its real bodies, tick and window.
        let windowLevel: Level = try Inv.hand()
        var window: Play = try Inv.playing(windowLevel)
        let phasesBefore: [Int] = window.phases
        try window.apply(.run, expecting: window.fingerprint)
        #expect(window.failure == .window(front: 0, back: 1, tick: 0, open: 2, close: 5))
        #expect(window.failure?.code == "window")
        #expect(window.phases == phasesBefore && window.actionsSpent == 0)
        #expect(window.records.last?.next == window.fingerprint)
        #expect(window.records.last?.action == .run)
        let apartLevel: Level = try Inv.apart()
        let apart: Play = try Inv.played(apartLevel, [.run])
        #expect(apart.failure == .horizon(front: 0, back: 1, open: 0, close: 7))
        #expect(apart.failure?.code == "horizon" && apart.timeline.intervals.isEmpty)
        let crowdedLevel: Level = try Inv.crowded()
        let crowded: Play = try Inv.played(crowdedLevel, [.run])
        #expect(crowded.failure == .unwanted(front: 0, back: 1, tick: 0))
        #expect(crowded.failure?.code == "unwanted")
        #expect(Inv.invJudge(windowLevel, phases: windowLevel.phases) == window.failure)
        #expect(Inv.invJudge(apartLevel, phases: apartLevel.phases) == apart.failure)
        #expect(Inv.invJudge(crowdedLevel, phases: crowdedLevel.phases) == crowded.failure)
        try window.undo()
        #expect(window.stage == .playing && window.failure == nil)
        // Refusals name their reasons.
        var refusing: Play = try Inv.playing(try Inv.hand(budget: 1))
        let unknown: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.phase(5, 0), expecting: refusing.fingerprint)
        }
        #expect(unknown?.reasonCode == "r02-g17.action")
        try refusing.apply(.phase(1, 1), expecting: refusing.fingerprint)
        let broke: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.phase(1, 2), expecting: refusing.fingerprint)
        }
        #expect(broke?.reasonCode == "r02-g17.budget")
        let stale: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.run, expecting: Inv.staleFingerprint)
        }
        #expect(stale?.reasonCode == "r02-g17.stale")

        // Seeded neighbours: random phases on the fixtures fail with exactly the independent judge's failure, the
        // phases unchanged by the run.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var codes: Set<String> = []
        for fixture in Inv.fixtures {
            for _ in 0..<3 {
                let phases: [Int] = Inv.randomPhases(fixture.level, random: &random)
                let run: Play = try Inv.runOf(fixture.level, phases: phases)
                let judged: Failure? = Inv.invJudge(fixture.level, phases: phases)
                #expect(run.failure == judged)
                #expect(run.phases == phases)
                #expect(run.stage == (judged == nil ? .won : .failed))
                if let judged { codes.insert(judged.code) }
            }
        }
        #expect(!codes.isEmpty)
        #expect(codes.isSubset(of: ["unwanted", "window", "horizon"]))
    }

    // MARK: INV-08 Stability

    @Test func testCelestialEclipseLabStabilityBoundary() throws {
        // Direct boundary: the extreme level builds, its bodies stay on the lattice at the last tick and far ticks,
        // and its starting timeline is bounded.
        let extreme: Level = try Inv.extreme()
        #expect(extreme.bodies.count == 6 && extreme.horizon == 96 && extreme.budget == 24)
        for body in extreme.bodies {
            #expect(body.radius == 8 && body.period == 24)
            for phase in 0..<body.period {
                for tick in [0, extreme.horizon - 1, 1_000_000] {
                    let p: Vec = body.position(at: tick, phase: phase)
                    #expect(Level.coordinates.contains(p.x) && Level.coordinates.contains(p.y))
                    #expect(p == Inv.invPosition(body, tick: tick, phase: phase))
                }
            }
        }
        #expect(Inv.spans(extreme.startTimeline) == Inv.invSpans(extreme, phases: extreme.phases))
        #expect(!extreme.startTimeline.wins)

        // Seeded neighbours: at least 500 seeded states on the extreme level and the fixtures stay bounded.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var levels: [Level] = [extreme]
        for fixture in Inv.fixtures.prefix(10) { levels.append(fixture.level) }
        var states: Int = 0
        var round: Int = 0
        while states < 500 {
            let level: Level = levels[round % levels.count]
            round += 1
            var play: Play = try Inv.playing(level)
            for _ in 0..<40 {
                let roll: Int = random.int(0...9)
                if roll == 0 {
                    _ = Inv.refusal { () throws(Refusal) in try play.undo() }
                } else if roll == 1 {
                    _ = Inv.refusal { () throws(Refusal) in try play.redo() }
                } else {
                    if play.stage != .playing { break }
                    let action: Action = Inv.invAction(play, random: &random)
                    _ = Inv.refusal { () throws(Refusal) in try play.apply(action, expecting: play.fingerprint) }
                }
                states += 1
                #expect(play.actionsSpent >= 0 && play.actionsSpent <= level.budget)
                #expect(play.actionsLeft >= 0 && play.actionsLeft <= level.budget)
                #expect(play.phases.count == level.bodies.count)
                for index in play.phases.indices {
                    #expect(play.phases[index] >= 0 && play.phases[index] < level.bodies[index].period)
                }
                #expect(play.timeline.matched >= 0 && play.timeline.matched <= level.target.count)
                for interval in play.timeline.intervals {
                    #expect(interval.first >= 0 && interval.first <= interval.last && interval.last < level.horizon)
                    #expect(interval.front != interval.back)
                    #expect(interval.front >= 0 && interval.front < level.bodies.count)
                    #expect(interval.back >= 0 && interval.back < level.bodies.count)
                }
                #expect(play.fingerprint.count == 64)
            }
        }
        #expect(states >= 500)
    }

    // MARK: INV-09 Save

    @Test func testCelestialEclipseLabSaveBoundary() throws {
        // Direct boundary: the stored form round-trips byte for byte; newer, older, truncated and fingerprint-edited
        // forms are refused.
        let level: Level = try Inv.hand()
        let data: Data = level.encoded()
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level && decoded.encoded() == data)
        let viaCodable: Level = try JSONDecoder().decode(Level.self, from: data)
        #expect(viaCodable == level)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"schema\":1"))
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(newer) } == .newerSchema(2))
        let older: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(older) }))
        let truncated: Data = data.prefix(data.count / 2)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(truncated) }))
        let marker: String = "\"fingerprint\":\""
        if let range = text.range(of: marker) {
            let digit: Character = text[range.upperBound]
            let replacement: String = digit == "0" ? "1" : "0"
            var edited: String = text
            edited.replaceSubrange(range.upperBound...range.upperBound, with: replacement)
            #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(edited.utf8)) }))
        } else {
            Issue.record("the stored form holds no fingerprint")
        }
        // A stored record trace replays to the same play.
        let played: Play = try Inv.played(level, [.phase(1, 4), .phase(1, 0)])
        let trace: Data = try JSONEncoder().encode(played.records)
        let restored: [Record] = try JSONDecoder().decode([Record].self, from: trace)
        let back: Play = try Play.replay(level: level, records: restored)
        #expect(back.fingerprint == played.fingerprint && back.records == played.records)
        let extreme: Level = try Inv.extreme()
        #expect(try Level.decode(extreme.encoded()) == extreme)

        // Seeded neighbours: any single-byte edit of a stored fixture level is refused or decodes to the same level.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var refused: Int = 0
        for fixture in Inv.fixtures.prefix(10) {
            let stored: Data = fixture.level.encoded()
            #expect(try Level.decode(stored) == fixture.level)
            for _ in 0..<24 {
                var bytes: [UInt8] = Array(stored)
                let position: Int = random.int(0...(bytes.count - 1))
                let value: UInt8 = UInt8(random.int(32...126))
                if bytes[position] == value { continue }
                bytes[position] = value
                do {
                    let edited: Level = try Level.decode(Data(bytes))
                    #expect(edited == fixture.level)
                } catch {
                    refused += 1
                }
            }
        }
        #expect(refused > 0)
    }

    // MARK: INV-10 Renderer purity

    @Test func testCelestialEclipseLabRendererpurityBoundary() throws {
        // Direct boundary: the timeline equals the sky's pure function of the phases; reading names and descriptions
        // leaves the play unchanged; the play is a value type.
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        try play.apply(.phase(1, 4), expecting: play.fingerprint)
        #expect(play.timeline == Sky.timeline(level, phases: play.phases))
        #expect(Sky.timeline(level, phases: play.phases) == Sky.timeline(level, phases: play.phases))
        let copy: Play = play
        let words: String = level.progressDescription(timeline: play.timeline, actionsLeft: play.actionsLeft)
        #expect(words == level.progressDescription(timeline: play.timeline, actionsLeft: play.actionsLeft))
        #expect(level.bodyName(1) == "body 1")
        #expect(level.eclipseName(front: 0, back: 1) == "body 0 in front of body 1")
        for interval in play.timeline.intervals { _ = level.intervalDescription(interval) }
        #expect(play == copy)
        var changed: Play = copy
        try changed.apply(.phase(1, 0), expecting: changed.fingerprint)
        #expect(play == copy && changed != copy)
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
        let allowed: Set<String> = ["Foundation", "VisualCoreMath", "VisualCoreSimulation"]
        for source in try Inv.kernelSources() {
            for line in Inv.codeLines(source.text) where line.hasPrefix("import ") {
                let module: String = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "\(source.name) imports \(module)")
            }
        }

        // Seeded neighbours: along seeded walks the timeline is the pure function of the phases, and a level that
        // differs only in its id gives the same timelines and outcomes for the same actions.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(20) {
            let renamed: Level = try Inv.variant(fixture.level, id: fixture.level.id + "-renamed")
            var a: Play = try Inv.playing(fixture.level)
            var b: Play = try Inv.playing(renamed)
            for _ in 0..<10 {
                if a.stage != .playing { break }
                let action: Action = Inv.invAction(a, random: &random)
                let refusedA: Refusal? = Inv.refusal { () throws(Refusal) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let refusedB: Refusal? = Inv.refusal { () throws(Refusal) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(refusedA == refusedB)
                #expect(a.timeline == Sky.timeline(fixture.level, phases: a.phases))
                #expect(Inv.spans(a.timeline) == Inv.invSpans(fixture.level, phases: a.phases))
                #expect(a.timeline == b.timeline && a.phases == b.phases && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsSpent == b.actionsSpent)
                let before: Play = a
                _ = fixture.level.progressDescription(timeline: a.timeline, actionsLeft: a.actionsLeft)
                for interval in a.timeline.intervals {
                    _ = fixture.level.eclipseName(front: interval.front, back: interval.back)
                }
                #expect(a == before)
            }
        }
    }
}
