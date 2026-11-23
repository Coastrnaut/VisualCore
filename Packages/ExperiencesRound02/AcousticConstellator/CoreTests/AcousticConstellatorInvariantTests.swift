// AcousticConstellatorInvariantTests — feature 421 (R02-G13-01) T-R02G1301-006 (FR-R02G1301-012; the source's
// invariants R2-G13-INV-01 … 05 and INV-07 … 10 on Acoustic Constellator). Each named test gives a direct boundary
// example and a seeded check of neighbouring inputs (seed 2,426: an unknown star, a nudge step of 0 or ±2, an action
// budget ± 1, a threshold one above the largest winning one, a window one tick short of the hold, a digit of a stored
// level changed, stars moved), as the source asks. How each invariant maps onto this kernel (INV-06 content and INV-12
// novelty belong to R02-G13-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock and no presentation timestep decides anything; the rules count ticks of the
//   12-step phase clock (AcousticConstellatorClock, integer steps, not a time source). The same actions give the same
//   fingerprints, reports and records however many pauses and reads lie between them; an idle play never spends an
//   action or fails; a listen runs at most W ticks (exactly W when it ends incoherent); the kernel sources hold no
//   clock, time interval or floating-point value.
// - INV-02 Input budget: a link, an unlink, a nudge and a listen each spend exactly 1 action; refusals (an unknown star,
//   a self link, an existing link, the degree or link limit, removing a missing or fixed link, a nudge step other than
//   ±1, a stale fingerprint, the wrong stage) spend nothing; the action that spends the last of the budget is applied
//   and judged (a listen on it wins or fails by its own cause, any other action on it fails the budget) and every later
//   action is refused by stage.
// - INV-03 Goal: the level is won exactly when every symbol pair is linked and the order parameter reaches the threshold
//   on H consecutive ticks within the window; a missing pair loses before any tick; the largest winning threshold wins
//   and one above it does not; a window one tick shorter than the winning tick does not win.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior links, phases, actions spent, report, stage, failure and fingerprint; redo
//   the later one; a new action clears redo; a won level is final; a paused play stays paused; a failed play returns to
//   playing.
// - INV-07 Failure honesty: a failing listen names its real cause — the lowest symbol pair really unlinked; the tick on
//   which a link really snapped (its |gap| above σ) and the symbol's stars really fell apart; an incoherent run that
//   really is the longest coherent run, shorter than H, over the whole window — and equals an independent listen; a
//   budget failure names the index of the action that spent the last of the budget; a failed play undone still wins
//   with its known actions (no hidden solution).
// - INV-08 Stability: extreme valid levels (8 stars, rates and phases 11, K 8, D 4, E 16, σ 5, θ 64, H 12, W 48,
//   budget 40, 6 fixed links, a 10-pair symbol) run without a crash or overflow; every phase stays 0 … 11, every order
//   parameter n²R² = A + B√3 stays within 0 … n² (|A| ≤ n², |B| ≤ n(n − 1)/2), the actions spent 0 … budget, the links
//   within E and every star within D; the report equals an independent computation (the pull table from the rounded
//   sine, |Σ e^{iπφ/6}|² in floating point, connectivity by relaxation to a fixed point).
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited, out-of-range and newer stored forms are
//   refused as a whole (no level is returned); a stored record trace up to a save point replays to the state at that
//   point; a damaged trace is refused.
// - INV-10 Renderer purity: the kernel types are value types; the drawing positions of the stars never change a rule
//   outcome (moved stars give identical reports, failures and outcomes); reading, naming and copying change no
//   fingerprint; the kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation and use no clock,
//   random source, Double or Float. The scanned kernel list is Error, Dynamics, Level, Play and Rules.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden import names are built by concatenation
// so that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorInvariantTests {
    typealias Play = AcousticConstellatorPlay
    typealias Level = AcousticConstellatorLevel
    typealias Action = AcousticConstellatorAction
    typealias Failure = AcousticConstellatorFailure
    typealias Star = AcousticConstellatorStar
    typealias Link = AcousticConstellatorLink
    typealias Listen = AcousticConstellatorListen
    typealias Outcome = AcousticConstellatorOutcome

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_426

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The known winning actions on the hand level: link star 1 to star 2, then a listen.
    static let winning: [Action] = [.link(1, 2), .listen]

    /// Actions on the hand level that wander (star 2 nudged away and back) and then win.
    static let wanderThenWin: [Action] = [.nudge(2, 1), .nudge(2, -1), .link(1, 2), .listen]

    /// The kernel sources the scans read (the Core directory next to this test directory).
    static let kernelFiles: [String] = ["AcousticConstellatorError.swift", "AcousticConstellatorDynamics.swift",
                                        "AcousticConstellatorLevel.swift", "AcousticConstellatorPlay.swift",
                                        "AcousticConstellatorRules.swift"]

    // MARK: Helpers

    /// The fixture of neighbouring index `index` (seed 2,426 onwards).
    static func neighbour(_ index: Int) -> AcousticConstellatorFixture {
        AcousticConstellatorFixtures.fixture(seed &+ UInt64(index))
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: Level) throws(AcousticConstellatorError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: Level, _ actions: [Action]) throws(AcousticConstellatorError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(AcousticConstellatorError) -> Void) -> AcousticConstellatorError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func decodeRefusal(_ data: Data) -> AcousticConstellatorError? {
        do {
            _ = try Level.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is a `.malformed` refusal (any payload).
    static func isMalformed(_ error: AcousticConstellatorError?) -> Bool {
        if case .malformed = error { return true }
        return false
    }

    /// `level` with some values replaced (the id, seed, difficulty, links, symbol, K, D, E, σ and tutorial kept).
    static func variant(_ level: Level, stars: [Star]? = nil, threshold: Int? = nil, hold: Int? = nil,
                        window: Int? = nil, budget: Int? = nil) throws(AcousticConstellatorError) -> Level {
        try Level(id: level.id, seed: level.seed, difficulty: level.difficulty, stars: stars ?? level.stars,
                  fixedLinks: level.fixedLinks, symbol: level.symbol, coupling: level.coupling,
                  degreeLimit: level.degreeLimit, linkLimit: level.linkLimit, snapLimit: level.snapLimit,
                  threshold: threshold ?? level.threshold, hold: hold ?? level.hold, window: window ?? level.window,
                  budget: budget ?? level.budget, tutorial: level.tutorial)
    }

    /// The known winning actions of `fixture` as play actions.
    static func winningActions(_ fixture: AcousticConstellatorFixture) -> [Action] {
        var actions: [Action] = []
        for entry in fixture.winningActions {
            switch entry.kind {
            case "link": actions.append(.link(entry.a, entry.b))
            case "unlink": actions.append(.unlink(entry.a, entry.b))
            case "nudge": actions.append(.nudge(entry.a, entry.b))
            default: actions.append(.listen)
            }
        }
        return actions
    }

    /// A seeded action on `level`: mostly links, unlinks and ±1 nudges on known stars, sometimes a listen, an unknown
    /// star or a nudge step of 0 or ±2.
    static func invAction(_ level: Level, random: inout SeededRandom) -> Action {
        let roll: Int = random.int(0...19)
        let count: Int = level.stars.count
        if roll < 2 { return .listen }
        if roll == 2 { return .link(count, random.int(0...(count - 1))) }
        if roll == 3 { return .nudge(random.int(0...(count - 1)), [0, 2, -2][random.int(0...2)]) }
        if roll < 11 { return .link(random.int(0...(count - 1)), random.int(0...(count - 1))) }
        if roll < 14 { return .unlink(random.int(0...(count - 1)), random.int(0...(count - 1))) }
        return .nudge(random.int(0...(count - 1)), random.int(0...1) == 0 ? -1 : 1)
    }

    /// A seeded walk of up to `steps` actions on `level` (refusals skipped), from stage `playing`.
    static func invWalk(_ level: Level, steps: Int, random: inout SeededRandom) throws -> Play {
        var play: Play = try playing(level)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            let action: Action = invAction(level, random: &random)
            _ = refusal { () throws(AcousticConstellatorError) in try play.apply(action, expecting: play.fingerprint) }
        }
        return play
    }

    /// The kernel sources (the listed files of the Core directory next to this test directory).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        var sources: [(name: String, text: String)] = []
        for name in kernelFiles {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    /// The hand drift level: stars of rates 0, 0 and 5 at phase 0, no fixed links, symbol 0–1 and 1–2, K 1, D 2, E 2,
    /// σ 2, θ 9, H 2, W 4, budget 5. Linked and listened, star 2 drifts 5 steps on tick 1 and link 1–2 snaps.
    static func driftLevel() throws(AcousticConstellatorError) -> Level {
        let stars: [Star] = [Star(x: 0, y: 0, z: 0, rate: 0, phase: 0), Star(x: 1, y: 1, z: 1, rate: 0, phase: 0),
                             Star(x: 2, y: 2, z: 2, rate: 5, phase: 0)]
        return try Level(id: "drift-three", seed: seed, difficulty: 1, stars: stars, fixedLinks: [],
                         symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], coupling: 1, degreeLimit: 2, linkLimit: 2,
                         snapLimit: 2, threshold: 9, hold: 2, window: 4, budget: 5)
    }

    /// The hand limit level: four stars of rate 1 at phase 0, no fixed links, symbol 0–1 and 1–2, K 2, D 2, E 3, σ 2,
    /// θ 16, H 2, W 4, budget 10.
    static func limitLevel() throws(AcousticConstellatorError) -> Level {
        var stars: [Star] = []
        for index in 0..<4 { stars.append(Star(x: index, y: 0, z: 0, rate: 1, phase: 0)) }
        return try Level(id: "limit-four", seed: seed, difficulty: 1, stars: stars, fixedLinks: [],
                         symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], coupling: 2, degreeLimit: 2, linkLimit: 3,
                         snapLimit: 2, threshold: 16, hold: 2, window: 4, budget: 10)
    }

    /// The extreme level: 8 stars of rate 11 at `phases` (default all 11), six fixed links on the path 0 … 6, a 10-pair
    /// symbol (the path 0 … 7 plus 0–2, 2–4 and 4–6), K 8, D 4, E 16, σ 5, θ `threshold`, H 12, W 48, budget 40.
    static func extremeLevel(phases: [Int]? = nil, threshold: Int = 64) throws(AcousticConstellatorError) -> Level {
        var stars: [Star] = []
        for index in 0..<8 {
            stars.append(Star(x: 11, y: 11 - index, z: index, rate: 11, phase: phases?[index] ?? 11))
        }
        var fixed: [Link] = []
        for index in 0..<6 { fixed.append(Link(a: index, b: index + 1)) }
        var symbol: [Link] = []
        for index in 0..<7 { symbol.append(Link(a: index, b: index + 1)) }
        symbol.append(Link(a: 0, b: 2))
        symbol.append(Link(a: 2, b: 4))
        symbol.append(Link(a: 4, b: 6))
        return try Level(id: "extreme-eight", seed: seed, difficulty: 5, stars: stars, fixedLinks: fixed,
                         symbol: symbol, coupling: 8, degreeLimit: 4, linkLimit: 16, snapLimit: 5,
                         threshold: threshold, hold: 12, window: 48, budget: 40)
    }

    /// The links the extreme level's symbol needs beyond its fixed links.
    static let extremePlacements: [Action] = [.link(6, 7), .link(0, 2), .link(2, 4), .link(4, 6)]

    // MARK: Independent computations

    /// The signed gap from `from` to `to`, reduced to −5 … 6 without the kernel.
    static func invGap(_ from: Int, _ to: Int) -> Int {
        let d: Int = ((to - from) % 12 + 12) % 12
        return d > 6 ? d - 12 : d
    }

    /// s(d) = sign(d) · round(2·sin(π|d|/6)), from the sine, not from the kernel table.
    static func invCoupling(_ gap: Int) -> Int {
        let magnitude: Int = Int((2.0 * sin(Double(abs(gap)) * Double.pi / 6.0)).rounded())
        return gap < 0 ? -magnitude : magnitude
    }

    /// One tick, computed independently: pulls over `links` from the phases before the tick, steps floored in floating
    /// point and clamped to −1 … 1.
    static func invTick(_ phases: [Int], rates: [Int], links: [Link], coupling: Int) -> [Int] {
        var next: [Int] = phases
        for star in 0..<phases.count {
            var pull: Int = 0
            for link in links where link.a == star || link.b == star {
                let other: Int = link.a == star ? link.b : link.a
                pull += invCoupling(invGap(phases[star], phases[other]))
            }
            let raw: Int = Int((Double(coupling * pull) / 4.0).rounded(.down))
            let step: Int = max(-1, min(1, raw))
            next[star] = ((phases[star] + rates[star] + step) % 12 + 12) % 12
        }
        return next
    }

    /// |Σ e^{iπφ/6}|² in floating point.
    static func invOrder(_ phases: [Int]) -> Double {
        var re: Double = 0
        var im: Double = 0
        for phase in phases {
            re += cos(Double(phase) * Double.pi / 6.0)
            im += sin(Double(phase) * Double.pi / 6.0)
        }
        return re * re + im * im
    }

    /// Whether `links` join every star of `stars`, by relaxation to a fixed point (no queue).
    static func invJoins(_ stars: [Int], links: [Link], count: Int) -> Bool {
        guard let first = stars.first else { return true }
        var reached: [Bool] = Array(repeating: false, count: count)
        reached[first] = true
        var changed: Bool = true
        while changed {
            changed = false
            for link in links where reached[link.a] != reached[link.b] {
                reached[link.a] = true
                reached[link.b] = true
                changed = true
            }
        }
        for star in stars where !reached[star] { return false }
        return true
    }

    /// A listen of `links` from `phases` on `level`, computed independently: the phases and coherence per tick, the
    /// longest coherent run and the outcome.
    static func invListen(_ level: Level, links: [Link], phases: [Int])
        -> (phases: [[Int]], coherent: [Bool], longest: Int, outcome: Outcome) {
        var missing: [Link] = []
        for pair in level.symbol where !links.contains(pair) { missing.append(pair) }
        if let lowest = missing.min() { return ([phases], [false], 0, .missing(lowest)) }
        var symbolStars: [Int] = []
        for pair in level.symbol {
            if !symbolStars.contains(pair.a) { symbolStars.append(pair.a) }
            if !symbolStars.contains(pair.b) { symbolStars.append(pair.b) }
        }
        var alive: [Bool] = Array(repeating: true, count: links.count)
        var current: [Int] = phases
        var allPhases: [[Int]] = [phases]
        var coherent: [Bool] = [false]
        var run: Int = 0
        var longest: Int = 0
        for tick in 1...level.window {
            var remaining: [Link] = []
            for index in 0..<links.count where alive[index] { remaining.append(links[index]) }
            current = invTick(current, rates: level.naturalRates, links: remaining, coupling: level.coupling)
            allPhases.append(current)
            var firstSnapped: Int? = nil
            for index in 0..<links.count where alive[index] {
                if abs(invGap(current[links[index].a], current[links[index].b])) > level.snapLimit {
                    alive[index] = false
                    if firstSnapped == nil { firstSnapped = index }
                }
            }
            var left: [Link] = []
            for index in 0..<links.count where alive[index] { left.append(links[index]) }
            if !invJoins(symbolStars, links: left, count: current.count) {
                coherent.append(false)
                return (allPhases, coherent, longest, .disconnected(tick: tick, link: links[firstSnapped ?? 0]))
            }
            var whole: Bool = true
            for pair in level.symbol where !left.contains(pair) { whole = false }
            let isCoherent: Bool = whole && invOrder(current) >= Double(level.threshold) - 1e-9
            coherent.append(isCoherent)
            run = isCoherent ? run + 1 : 0
            longest = max(longest, run)
            if run >= level.hold { return (allPhases, coherent, longest, .won(tick: tick)) }
        }
        return (allPhases, coherent, longest, .incoherent(longestRun: longest))
    }

    /// Checks `report` (a listen of `links` from `phases` on `level`) against the independent computation.
    static func invCheckReport(_ report: Listen, _ level: Level, links: [Link], phases: [Int]) {
        let expected: (phases: [[Int]], coherent: [Bool], longest: Int, outcome: Outcome) =
            invListen(level, links: links, phases: phases)
        #expect(report.phases == expected.phases)
        #expect(report.coherent == expected.coherent)
        #expect(report.longestRun == expected.longest)
        #expect(report.outcome == expected.outcome)
        for (tick, parts) in report.order.enumerated() {
            let exact: Double = Double(parts[0]) + Double(parts[1]) * 3.0.squareRoot()
            #expect(abs(exact - invOrder(report.phases[tick])) < 1e-9)
        }
    }

    /// The failure a listen outcome names (nil for a win).
    static func failure(of outcome: Outcome) -> Failure? {
        switch outcome {
        case .won: return nil
        case .missing(let pair): return .missing(pair)
        case .disconnected(let tick, let link): return .disconnected(tick: tick, link: link)
        case .incoherent(let run): return .incoherent(run)
        }
    }

    // MARK: INV-01 Time

    /// INV-01 Time: no rule reads a clock; pauses and reads between actions change no fingerprint, report or outcome;
    /// an idle play never spends or fails; a listen runs at most W ticks.
    @Test func testAcousticConstellatorTimeBoundary() throws {
        let level: Level = AcousticConstellatorFixtures.handLevel()
        // Direct example: the same actions applied straight and after many pauses and reads.
        var straight: Play = try Self.playing(level)
        var framed: Play = try Self.playing(level)
        for action in Self.wanderThenWin {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                _ = framed.fingerprint
                _ = framed.progressDescription
                _ = framed.label
                try framed.handle(.pause)
                try framed.handle(.resume)
            }
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.report == straight.report)
            #expect(framed.actionsSpent == straight.actionsSpent)
        }
        #expect(straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends an action nor fails, however long it waits or how often it is paused.
        var idle: Play = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.actionsSpent == 0 && idle.failure == nil)
        #expect(idle.fingerprint == opening && idle.records.isEmpty)
        #expect(idle.report == level.listen(links: level.fixedLinks, phases: level.startingPhases))
        // Window ticks bound the listen: the hand win stops on its hold tick 3 of W 6; held to W 3 it still wins on the
        // last tick; a listen that never holds runs exactly W ticks.
        #expect(straight.report.outcome == .won(tick: 3) && straight.report.lastTick == 3)
        let tight: Play = try Self.played(try Self.variant(level, window: 3), Self.winning)
        #expect(tight.stage == .won && tight.report.lastTick == 3)
        let never: Play = try Self.played(try Self.variant(level, threshold: 9, hold: 6, window: 6),
                                          [.link(1, 2), .nudge(2, 1), .nudge(2, 1), .nudge(2, 1), .listen])
        if case .incoherent = never.report.outcome { #expect(never.report.lastTick == 6) }
        // The kernel holds no clock, time interval or floating-point value. "Clock" alone is not scanned: the kernel's
        // AcousticConstellatorClock is the integer 12-step phase clock, not a time source.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "ContinuousClock", "SuspendingClock",
                                "CFAbsoluteTime", "DispatchTime", "Timer", "deltaTime", "timestep"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count == Self.kernelFiles.count)
        for source in sources {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: accepted actions repeated after seeded numbers of pauses and reads reach the same
        // fingerprint and report after every action and the same records; every listen stays within its window.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            var a: Play = try Self.playing(fixture.level)
            var b: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    _ = b.progressDescription
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.report == b.report && a.stage == b.stage)
                #expect(a.report.lastTick <= fixture.level.window)
                if case .incoherent = a.report.outcome { #expect(a.report.lastTick == fixture.level.window) }
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: each link, unlink, nudge and listen spends 1; refusals spend nothing; the last action of the
    /// budget is judged and later actions are refused by stage.
    @Test func testAcousticConstellatorInputbudgetBoundary() throws {
        // Direct example: refusals on a fresh play of the hand level spend nothing.
        let level: Level = AcousticConstellatorFixtures.handLevel()
        var fresh: Play = try Self.playing(level)
        let opening: String = fresh.fingerprint
        let refused: [(Action, AcousticConstellatorError)] = [
            (.link(0, 3), .action("star")), (.link(-1, 2), .action("star")), (.link(1, 1), .action("self")),
            (.link(1, 0), .action("exists")), (.unlink(0, 1), .action("fixed")), (.unlink(0, 2), .action("missing")),
            (.nudge(0, 0), .action("step")), (.nudge(0, 2), .action("step")), (.nudge(0, -2), .action("step")),
            (.nudge(3, 1), .action("star")),
        ]
        for entry in refused {
            let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                try fresh.apply(entry.0, expecting: fresh.fingerprint)
            }
            #expect(error == entry.1)
        }
        let stale: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            try fresh.apply(.nudge(0, 1), expecting: Self.staleFingerprint)
        }
        #expect(stale == .stale)
        var loading: Play = Play(level: level)
        let early: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            try loading.apply(.listen, expecting: loading.fingerprint)
        }
        #expect(early == .stage && loading.actionsSpent == 0 && loading.records.isEmpty)
        #expect(fresh.fingerprint == opening && fresh.actionsSpent == 0 && fresh.records.isEmpty)
        // The degree and link limits: on the limit level star 1 at D 2 refuses a third link, and a fourth link is over E 3.
        var limits: Play = try Self.played(try Self.limitLevel(), [.link(0, 1), .link(1, 2)])
        let degree: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            try limits.apply(.link(1, 3), expecting: limits.fingerprint)
        }
        #expect(degree == .action("degree") && limits.actionsSpent == 2)
        try limits.apply(.link(2, 3), expecting: limits.fingerprint)
        let over: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            try limits.apply(.link(0, 3), expecting: limits.fingerprint)
        }
        #expect(over == .action("limit") && limits.actionsSpent == 3 && limits.links.count == 3)
        // Steps −1 and +1 are inside the range; each accepted action spends exactly 1 action.
        try fresh.apply(.nudge(0, -1), expecting: fresh.fingerprint)
        #expect(fresh.actionsSpent == 1 && fresh.actionsLeft == level.budget - 1 && fresh.phases[0] == 11)
        try fresh.apply(.nudge(0, 1), expecting: fresh.fingerprint)
        #expect(fresh.actionsSpent == 2 && fresh.phases[0] == 0)
        try fresh.undo()
        #expect(fresh.actionsSpent == 1)
        try fresh.redo()
        #expect(fresh.actionsSpent == 2)
        // Budget 2: the second nudge spends the last action and fails the budget at index 1; then every action is
        // refused by stage and spends nothing.
        var spent: Play = try Self.played(try Self.variant(level, budget: 2), [.nudge(2, 1)])
        #expect(spent.stage == .playing && spent.actionsLeft == 1)
        try spent.apply(.nudge(2, -1), expecting: spent.fingerprint)
        #expect(spent.stage == .failed && spent.failure == .budget(1) && spent.actionsLeft == 0)
        let after: [Action] = [.listen, .link(1, 2)]
        for action in after {
            let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                try spent.apply(action, expecting: spent.fingerprint)
            }
            #expect(error == .stage && spent.actionsSpent == 2 && spent.records.count == 2)
        }
        // A winning listen on the last action wins; a failing listen on the last action fails by its cause (not the
        // budget).
        let lastWin: Play = try Self.played(try Self.variant(level, budget: 2), Self.winning)
        #expect(lastWin.stage == .won && lastWin.failure == nil && lastWin.actionsLeft == 0)
        let lastMiss: Play = try Self.played(try Self.variant(level, budget: 1), [.listen])
        #expect(lastMiss.stage == .failed && lastMiss.failure == .missing(Link(a: 1, b: 2)))
        // Seeded neighbours: budgets of the known actions' count and one either side; an unknown star and nudge steps
        // 0 and ±2 refused on a seeded star.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            let actions: [Action] = Self.winningActions(fixture)
            let needed: Int = actions.count
            let exact: Play = try Self.played(try Self.variant(fixture.level, budget: needed), actions)
            #expect(exact.stage == .won && exact.actionsSpent == needed && exact.actionsLeft == 0)
            if needed + 1 <= Level.budgets.upperBound {
                let roomy: Play = try Self.played(try Self.variant(fixture.level, budget: needed + 1), actions)
                #expect(roomy.stage == .won && roomy.actionsLeft == 1)
            }
            var short: Play = try Self.playing(try Self.variant(fixture.level, budget: needed - 1))
            for action in actions.dropLast() { try short.apply(action, expecting: short.fingerprint) }
            #expect(short.stage == .failed && short.failure == .budget(needed - 2))
            #expect(short.records.last?.index == needed - 2)
            let late: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                try short.apply(.listen, expecting: short.fingerprint)
            }
            #expect(late == .stage && short.actionsSpent == needed - 1)
            var probe: Play = try Self.playing(fixture.level)
            let count: Int = fixture.level.stars.count
            let star: Int = random.int(0...(count - 1))
            let outside: [Action] = [.nudge(star, 0), .nudge(star, 2), .nudge(star, -2), .nudge(count, 1),
                                     .link(star, count), .link(star, star), .unlink(count, star)]
            for action in outside {
                let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                    try probe.apply(action, expecting: probe.fingerprint)
                }
                #expect(error == .action("step") || error == .action("star") || error == .action("self"))
            }
            #expect(probe.actionsSpent == 0 && probe.records.isEmpty)
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won only when every symbol pair is linked and the order parameter reaches θ on H consecutive ticks;
    /// the largest winning threshold wins and one above does not.
    @Test func testAcousticConstellatorGoalBoundary() throws {
        // Direct example: on the hand level linking star 1 to star 2 completes the symbol; the stars meet on tick 1 at
        // order 9 (θ 9 = n²) and hold for ticks 1 … 3.
        let level: Level = AcousticConstellatorFixtures.handLevel()
        let won: Play = try Self.played(level, Self.winning)
        #expect(won.stage == .won && won.failure == nil && won.matchesSymbol)
        #expect(won.report.order[1] == [9, 0] && won.report.coherent == [false, true, true, true])
        // A missing pair loses before any tick, even with the phases already equal enough.
        let bare: Play = try Self.played(level, [.listen])
        #expect(bare.failure == .missing(Link(a: 1, b: 2)) && bare.report.lastTick == 0)
        let removed: Play = try Self.played(level, [.link(1, 2), .unlink(2, 1), .listen])
        #expect(removed.failure == .missing(Link(a: 1, b: 2)))
        // The hold: H 4 with W 4 wins on its last tick; H counted on consecutive coherent ticks only.
        let longer: Play = try Self.played(try Self.variant(level, hold: 4, window: 4), Self.winning)
        #expect(longer.report.outcome == .won(tick: 4))
        // Seeded neighbours: at the winning state every threshold up to the fixture's (the largest winning one) wins,
        // one above it fails as the independent listen says; a window one tick shorter than the winning tick fails; the
        // bare level never wins.
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            let actions: [Action] = Self.winningActions(fixture)
            let n: Int = fixture.level.stars.count
            let lowest: Play = try Self.played(try Self.variant(fixture.level, threshold: 1), actions)
            #expect(lowest.stage == .won)
            let atCritical: Play = try Self.played(fixture.level, actions)
            #expect(atCritical.stage == .won)
            if fixture.level.threshold < n * n {
                let above: Level = try Self.variant(fixture.level, threshold: fixture.level.threshold + 1)
                let missed: Play = try Self.played(above, actions)
                let expected: Outcome = Self.invListen(above, links: missed.links, phases: missed.phases).outcome
                #expect(missed.stage == .failed && missed.failure == Self.failure(of: expected))
                #expect(missed.failure != nil)
            }
            guard case .won(let tick) = atCritical.report.outcome else {
                Issue.record("fixture \(index) does not win")
                continue
            }
            if tick - 1 >= fixture.level.hold {
                let shorter: Play = try Self.played(try Self.variant(fixture.level, window: tick - 1), actions)
                #expect(shorter.stage == .failed && shorter.failure == .incoherent(fixture.level.hold - 1))
            }
            let opening: Play = try Self.played(fixture.level, [.listen])
            #expect(opening.stage == .failed)
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records, fingerprints and outcome; replay reproduces them;
    /// an edited or forged record is refused.
    @Test func testAcousticConstellatorRepeatabilityBoundary() throws {
        // Direct example: two independent runs and a replay of the hand level's wandering win.
        let level: Level = AcousticConstellatorFixtures.handLevel()
        let first: Play = try Self.played(level, Self.wanderThenWin)
        let second: Play = try Self.played(level, Self.wanderThenWin)
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.stage == .won && second.stage == .won && first.report == second.report)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(replayed.records == first.records && replayed.fingerprint == first.fingerprint)
        // An edited next fingerprint, an edited previous fingerprint and a forged seed are refused.
        let original: AcousticConstellatorRecord = first.records[1]
        var editedNext: [AcousticConstellatorRecord] = first.records
        editedNext[1] = AcousticConstellatorRecord(schema: original.schema, seed: original.seed, index: original.index,
                                                   kind: original.kind, action: original.action,
                                                   previous: original.previous, next: Self.staleFingerprint)
        let nextError: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            _ = try Play.replay(level: level, records: editedNext)
        }
        #expect(nextError == .malformed("record 1"))
        var editedPrevious: [AcousticConstellatorRecord] = first.records
        editedPrevious[1] = AcousticConstellatorRecord(schema: original.schema, seed: original.seed,
                                                       index: original.index, kind: original.kind,
                                                       action: original.action, previous: Self.staleFingerprint,
                                                       next: original.next)
        let previousError: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            _ = try Play.replay(level: level, records: editedPrevious)
        }
        #expect(previousError == .malformed("replay"))
        var forged: [AcousticConstellatorRecord] = first.records
        let head: AcousticConstellatorRecord = first.records[0]
        forged[0] = AcousticConstellatorRecord(schema: head.schema, seed: head.seed &+ 1, index: head.index,
                                               kind: head.kind, action: head.action, previous: head.previous,
                                               next: head.next)
        let seedError: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            _ = try Play.replay(level: level, records: forged)
        }
        #expect(seedError == .malformed("seed 0"))
        // Seeded neighbours: two walks from the same seed agree; the replay agrees; a record whose next fingerprint is
        // edited at a seeded index is refused.
        var pick: SeededRandom = SeededRandom(seed: Self.seed &+ 3)
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            var randomA: SeededRandom = SeededRandom(seed: Self.seed &+ 100 &+ UInt64(index))
            var randomB: SeededRandom = SeededRandom(seed: Self.seed &+ 100 &+ UInt64(index))
            let a: Play = try Self.invWalk(fixture.level, steps: 20, random: &randomA)
            let b: Play = try Self.invWalk(fixture.level, steps: 20, random: &randomB)
            #expect(a.records == b.records && a.fingerprint == b.fingerprint && a.stage == b.stage)
            #expect(a.failure == b.failure && a.report == b.report)
            if a.records.isEmpty { continue }
            let again: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(again.records == a.records && again.fingerprint == a.fingerprint)
            let at: Int = pick.int(0...(a.records.count - 1))
            let record: AcousticConstellatorRecord = a.records[at]
            var edited: [AcousticConstellatorRecord] = a.records
            edited[at] = AcousticConstellatorRecord(schema: record.schema, seed: record.seed, index: record.index,
                                                    kind: record.kind, action: record.action,
                                                    previous: record.previous, next: Self.staleFingerprint)
            let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                _ = try Play.replay(level: fixture.level, records: edited)
            }
            #expect(error == .malformed("record \(at)"))
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo and redo restore exact moments; a new action clears redo; a won play is final; a paused play
    /// stays paused; a failed play returns to playing.
    @Test func testAcousticConstellatorUndoBoundary() throws {
        let level: Level = AcousticConstellatorFixtures.handLevel()
        // Direct example: a link undone and redone.
        var play: Play = try Self.playing(level)
        let nothing: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in try play.undo() }
        #expect(nothing == .action("undo"))
        let before: String = play.fingerprint
        try play.apply(.link(1, 2), expecting: play.fingerprint)
        let after: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == before && play.links == level.fixedLinks && play.actionsSpent == 0)
        #expect(play.phases == level.startingPhases && play.stage == .playing)
        #expect(play.report == level.listen(links: level.fixedLinks, phases: level.startingPhases))
        try play.redo()
        #expect(play.fingerprint == after && play.links == [Link(a: 0, b: 1), Link(a: 1, b: 2)])
        #expect(play.actionsSpent == 1)
        // A new action clears redo.
        try play.undo()
        try play.apply(.nudge(2, 1), expecting: play.fingerprint)
        let cleared: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            try play.redo()
        }
        #expect(cleared == .action("redo") && !play.canRedo)
        // A paused play stays paused through undo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.actionsSpent == 0 && play.phases == level.startingPhases)
        try play.handle(.resume)
        // A failed listen undone returns to playing at the exact prior moment.
        let ready: String = play.fingerprint
        try play.apply(.listen, expecting: play.fingerprint)
        #expect(play.stage == .failed)
        try play.undo()
        #expect(play.stage == .playing && play.fingerprint == ready && play.failure == nil)
        // A won play is final.
        for action in Self.winning { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        let final: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in try play.undo() }
        #expect(final == .stage && play.stage == .won)
        // Seeded neighbours: after every accepted action of seeded walks, undo restores the moment before (fingerprint,
        // links, phases, actions spent, report, failure) and redo the moment after.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let held: Play = walk
                let error: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                if error != nil {
                    #expect(walk == held)
                    continue
                }
                if walk.stage == .won {
                    #expect(!walk.canUndo)
                    break
                }
                let later: String = walk.fingerprint
                let wasFailed: Bool = walk.stage == .failed
                try walk.undo()
                #expect(walk.fingerprint == held.fingerprint && walk.links == held.links)
                #expect(walk.phases == held.phases && walk.actionsSpent == held.actionsSpent)
                #expect(walk.report == held.report && walk.failure == held.failure && walk.stage == .playing)
                if wasFailed { break }
                try walk.redo()
                #expect(walk.fingerprint == later)
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a failing listen names its real cause (missing pair, disconnecting tick and link,
    /// incoherent run) and equals an independent listen; a budget failure names its action; a failed play undone still
    /// wins with its known actions.
    @Test func testAcousticConstellatorFailurehonestyBoundary() throws {
        // Direct example, missing: the hand level's bare listen names pair 1–2, the only symbol pair not linked.
        let level: Level = AcousticConstellatorFixtures.handLevel()
        var play: Play = try Self.played(level, [.listen])
        #expect(play.failure == .missing(Link(a: 1, b: 2)))
        #expect(!play.links.contains(Link(a: 1, b: 2)) && play.links.contains(Link(a: 0, b: 1)))
        #expect(play.progressDescription.contains("missing link star 1 to star 2"))
        // No hidden solution: undone, the known actions win.
        try play.undo()
        for action in Self.winning { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        // Disconnected: on the drift level star 2 moves 5 steps on tick 1, link 1–2's gap 5 exceeds σ 2 and snaps, and
        // star 2 is cut off from the symbol on that tick.
        let drift: Level = try Self.driftLevel()
        let cut: Play = try Self.played(drift, [.link(0, 1), .link(1, 2), .listen])
        #expect(cut.failure == .disconnected(tick: 1, link: Link(a: 1, b: 2)))
        #expect(cut.report.phases[1] == [0, 0, 5] && cut.report.snapped[1] == [1])
        #expect(abs(Self.invGap(cut.report.phases[1][1], cut.report.phases[1][2])) > drift.snapLimit)
        #expect(!Self.invJoins([0, 1, 2], links: [Link(a: 0, b: 1)], count: 3))
        // Incoherent: three uncoupled stars (K 1, pulls of ±1 floor to 0 or −1) of rates 0, 4 and 8 never reach θ 9;
        // the named run is the longest coherent run over all W ticks.
        let spread: Level = try Level(id: "spread-three", seed: Self.seed, difficulty: 1,
                                      stars: [Star(x: 0, y: 0, z: 0, rate: 0, phase: 0),
                                              Star(x: 1, y: 0, z: 0, rate: 4, phase: 0),
                                              Star(x: 2, y: 0, z: 0, rate: 8, phase: 0)],
                                      fixedLinks: [], symbol: [Link(a: 0, b: 1), Link(a: 0, b: 2)], coupling: 1,
                                      degreeLimit: 2, linkLimit: 2, snapLimit: 5, threshold: 9, hold: 2, window: 6,
                                      budget: 5)
        let flat: Play = try Self.played(spread, [.link(0, 1), .link(0, 2), .listen])
        let expectedFlat: (phases: [[Int]], coherent: [Bool], longest: Int, outcome: Outcome) =
            Self.invListen(spread, links: flat.links, phases: flat.phases)
        #expect(flat.failure == Self.failure(of: expectedFlat.outcome))
        if case .incoherent(let run) = flat.failure {
            #expect(run < spread.hold && run == expectedFlat.longest && flat.report.lastTick == spread.window)
        } else {
            Issue.record("the spread level should end incoherent, got \(String(describing: flat.failure))")
        }
        // A budget failure names the index of the action that spent the last of the budget (its record's index).
        let spent: Play = try Self.played(try Self.variant(level, budget: 2), [.nudge(0, 1), .nudge(0, -1)])
        #expect(spent.failure == .budget(1) && spent.records.last?.index == 1)
        // Seeded neighbours: after seeded walks a listen's named failure equals the independent listen; a missing pair is
        // the lowest unlinked symbol pair; a disconnecting link really snapped on its tick; an incoherent run is the
        // longest run, shorter than H. The opening listen of every fixture fails honestly and, undone, the known actions
        // win.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 5)
        for index in 0..<30 {
            let fixture: AcousticConstellatorFixture = Self.neighbour(index)
            let other: Level = fixture.level
            for _ in 0..<4 {
                var walk: Play = try Self.playing(other)
                for _ in 0..<random.int(0...8) {
                    let action: Action = Self.invAction(other, random: &random)
                    if action == .listen { continue }
                    _ = Self.refusal { () throws(AcousticConstellatorError) in
                        try walk.apply(action, expecting: walk.fingerprint)
                    }
                    if walk.stage != .playing { break }
                }
                if walk.stage != .playing { continue }
                let links: [Link] = walk.links
                let phases: [Int] = walk.phases
                try walk.apply(.listen, expecting: walk.fingerprint)
                let expected: Outcome = Self.invListen(other, links: links, phases: phases).outcome
                #expect(walk.failure == Self.failure(of: expected))
                switch walk.failure {
                case .missing(let pair):
                    #expect(other.symbol.contains(pair) && !links.contains(pair))
                    for lower in other.symbol where lower < pair { #expect(links.contains(lower)) }
                case .disconnected(let tick, let link):
                    let at: [Int] = walk.report.phases[tick]
                    #expect(abs(Self.invGap(at[link.a], at[link.b])) > other.snapLimit, "link really snapped")
                    #expect(walk.report.snapped[tick].contains { links[$0] == link })
                case .incoherent(let run):
                    #expect(run < other.hold && run == walk.report.longestRun)
                    #expect(walk.report.lastTick == other.window)
                case .budget, nil:
                    break
                }
            }
            let opening: Play = try Self.played(other, [.listen])
            let expected: Outcome = Self.invListen(other, links: other.fixedLinks.sorted(),
                                                   phases: other.startingPhases).outcome
            #expect(opening.failure == Self.failure(of: expected) && opening.failure != nil)
            var retry: Play = opening
            try retry.undo()
            for action in Self.winningActions(fixture) { try retry.apply(action, expecting: retry.fingerprint) }
            #expect(retry.stage == .won && retry.failure == nil)
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: extreme valid levels run without a crash or overflow; every reported number is bounded and the
    /// report equals an independent computation.
    @Test func testAcousticConstellatorStabilityBoundary() throws {
        // Direct example: the extreme level, all 8 stars at phase 11 and rate 11, the 10-pair symbol completed: the
        // order parameter is n² = 64 on every tick, and the hold 12 wins on tick 12.
        let extreme: Level = try Self.extremeLevel()
        let full: Play = try Self.played(extreme, Self.extremePlacements + [.listen])
        #expect(full.report.outcome == .won(tick: 12) && full.stage == .won)
        for parts in full.report.order { #expect(parts == [64, 0]) }
        #expect(full.links.count == 10 && full.matchesSymbol)
        // The same level with spread phases, as many extra links as D and E allow, and a listen of the full window:
        // no crash or overflow, every number in range.
        let spreadPhases: [Int] = [0, 11, 3, 8, 5, 1, 10, 6]
        let spread: Level = try Self.extremeLevel(phases: spreadPhases)
        var crowded: Play = try Self.played(spread, Self.extremePlacements)
        for a in 0..<8 {
            for b in (a + 1)..<8 {
                _ = Self.refusal { () throws(AcousticConstellatorError) in
                    try crowded.apply(.link(a, b), expecting: crowded.fingerprint)
                }
            }
        }
        #expect(crowded.links.count <= 16)
        for star in 0..<8 {
            var degree: Int = 0
            for link in crowded.links where link.touches(star) { degree += 1 }
            #expect(degree <= 4)
        }
        Self.invCheckReport(crowded.report, spread, links: crowded.links, phases: crowded.phases)
        try crowded.apply(.listen, expecting: crowded.fingerprint)
        #expect(crowded.report.lastTick <= 48 && crowded.stage != .playing)
        // Seeded neighbours: after every accepted action of seeded walks every number stays in range and the report
        // equals the independent computation.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 6)
        var walks: [(level: Level, play: Play)] = [(spread, try Self.playing(spread))]
        for index in 0..<30 {
            let other: Level = Self.neighbour(index).level
            walks.append((other, try Self.playing(other)))
        }
        for entry in walks {
            let other: Level = entry.level
            let n: Int = other.stars.count
            var walk: Play = entry.play
            for _ in 0..<20 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(other, random: &random)
                _ = Self.refusal { () throws(AcousticConstellatorError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                #expect(walk.actionsSpent >= 0 && walk.actionsSpent <= other.budget)
                #expect(walk.actionsLeft >= 0 && walk.actionsLeft <= other.budget)
                #expect(walk.links.count <= other.linkLimit && walk.phases.count == n)
                for phase in walk.phases { #expect(phase >= 0 && phase <= 11) }
                #expect(walk.report.lastTick <= other.window)
                for tickPhases in walk.report.phases {
                    for phase in tickPhases { #expect(phase >= 0 && phase <= 11) }
                }
                for parts in walk.report.order {
                    #expect(abs(parts[0]) <= n * n && abs(parts[1]) <= n * (n - 1) / 2)
                    let value: Double = Double(parts[0]) + Double(parts[1]) * 3.0.squareRoot()
                    #expect(value >= -1e-9 && value <= Double(n * n) + 1e-9)
                }
                #expect(walk.report.longestRun >= 0 && walk.report.longestRun <= other.hold)
                Self.invCheckReport(walk.report, other, links: walk.links, phases: walk.phases)
            }
        }
    }

    // MARK: INV-09 Save

    /// INV-09 Save: the stored level round-trips byte for byte; damaged stored forms are refused whole; a stored record
    /// trace replays to the state at its save point and a damaged trace is refused.
    @Test func testAcousticConstellatorSaveBoundary() throws {
        // Direct example: the hand level round-trips, and each damage is refused with its reason.
        let level: Level = AcousticConstellatorFixtures.handLevel()
        let stored: Data = level.encoded()
        let decoded: Level = try Level.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let text: String = try #require(String(data: stored, encoding: .utf8))
        #expect(text.contains("\"threshold\":9") && text.contains("\"schema\":1") && text.contains("\"budget\":5"))
        let edited: Data = Data(text.replacingOccurrences(of: "\"threshold\":9", with: "\"threshold\":8").utf8)
        #expect(Self.decodeRefusal(edited) == .malformed("fingerprint"))
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Self.decodeRefusal(newer) == .newerSchema(2))
        let outOfRange: Data = Data(text.replacingOccurrences(of: "\"budget\":5", with: "\"budget\":41").utf8)
        #expect(Self.decodeRefusal(outOfRange) == .malformed("r02-g13.level"))
        let truncated: Data = stored.prefix(stored.count - 1)
        #expect(Self.decodeRefusal(truncated) == .malformed("unreadable"))
        let damaged: [Data] = [edited, newer, outOfRange, truncated]
        for data in damaged {
            let viaCodable: Level? = try? JSONDecoder().decode(Level.self, from: data)
            #expect(viaCodable == nil)
        }
        // The extreme level round-trips too.
        let extreme: Level = try Self.extremeLevel()
        #expect(try Level.decode(extreme.encoded()) == extreme)
        // A stored record trace replays to the state at each save point; a damaged trace is refused.
        let play: Play = try Self.played(level, Self.wanderThenWin)
        for cut in 1...play.records.count {
            let prefix: [AcousticConstellatorRecord] = Array(play.records.prefix(cut))
            let trace: Data = try JSONEncoder().encode(prefix)
            let loaded: [AcousticConstellatorRecord] = try JSONDecoder().decode([AcousticConstellatorRecord].self,
                                                                                from: trace)
            let restored: Play = try Play.replay(level: decoded, records: loaded)
            #expect(restored.fingerprint == prefix[cut - 1].next && restored.records == prefix)
        }
        let trace: Data = try JSONEncoder().encode(play.records)
        let traceText: String = try #require(String(data: trace, encoding: .utf8))
        let brokenTrace: Data = Data(traceText.replacingOccurrences(of: play.records[2].next,
                                                                    with: Self.staleFingerprint).utf8)
        let loadedBroken: [AcousticConstellatorRecord] = try JSONDecoder().decode([AcousticConstellatorRecord].self,
                                                                                 from: brokenTrace)
        let traceError: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
            _ = try Play.replay(level: decoded, records: loadedBroken)
        }
        #expect(Self.isMalformed(traceError))
        // Seeded neighbours: every fixture round-trips byte for byte; a digit changed to another digit at three seeded
        // positions, and a seeded truncation, are each refused whole; a seeded walk's trace replays.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 7)
        let zero: UInt8 = 48
        let nine: UInt8 = 57
        for index in 0..<30 {
            let other: Level = Self.neighbour(index).level
            let bytes: Data = other.encoded()
            let again: Level = try Level.decode(bytes)
            #expect(again == other && again.encoded() == bytes)
            var digits: [Int] = []
            for (position, byte) in bytes.enumerated() where byte >= zero && byte <= nine { digits.append(position) }
            for _ in 0..<3 {
                let position: Int = digits[random.int(0...(digits.count - 1))]
                var changed: [UInt8] = Array(bytes)
                let old: Int = Int(changed[position] - zero)
                changed[position] = zero + UInt8((old + random.int(1...9)) % 10)
                let error: AcousticConstellatorError? = Self.decodeRefusal(Data(changed))
                #expect(error != nil, "digit at \(position) changed was accepted")
            }
            let length: Int = random.int(0...(bytes.count - 1))
            #expect(Self.decodeRefusal(bytes.prefix(length)) != nil, "truncation to \(length) was accepted")
            let walk: Play = try Self.invWalk(other, steps: 12, random: &random)
            if walk.records.isEmpty { continue }
            let walkTrace: Data = try JSONEncoder().encode(walk.records)
            let walkLoaded: [AcousticConstellatorRecord] = try JSONDecoder().decode([AcousticConstellatorRecord].self,
                                                                                    from: walkTrace)
            let restored: Play = try Play.replay(level: again, records: walkLoaded)
            #expect(restored.fingerprint == walk.fingerprint && restored.report == walk.report)
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: value types only; star positions decide nothing; reading changes nothing; the kernel
    /// imports no rendering framework.
    @Test func testAcousticConstellatorRendererpurityBoundary() throws {
        let level: Level = AcousticConstellatorFixtures.handLevel()
        // Direct example: the kernel types are value types.
        let play: Play = try Self.played(level, [.nudge(2, 1)])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.report).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: level.stars[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: level.symbol[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: Action.listen).displayStyle == .enum)
        #expect(Mirror(reflecting: Failure.budget(0)).displayStyle == .enum)
        #expect(Mirror(reflecting: Outcome.won(tick: 1)).displayStyle == .enum)
        #expect(Mirror(reflecting: AcousticConstellatorStage.playing).displayStyle == .enum)
        // The play holds no visual state: no field names a colour, vertex, texture, shader, frame, time or layer.
        let visual: [String] = ["colo", "vertex", "texture", "shader", "frame", "time", "layer", "pixel", "mesh"]
        for child in Mirror(reflecting: play).children {
            let label: String = (child.label ?? "").lowercased()
            for word in visual { #expect(!label.contains(word), "the play holds \(label)") }
        }
        // Moved stars: the same actions give identical reports, links, phases, stages and failures.
        var moved: [Star] = []
        for (index, star) in level.stars.enumerated() {
            moved.append(Star(x: 11 - star.x, y: index, z: 11 - star.z, rate: star.rate, phase: star.phase))
        }
        let elsewhere: Level = try Self.variant(level, stars: moved)
        #expect(elsewhere.fingerprint != level.fingerprint)
        let phaseSets: [[Int]] = [level.startingPhases, [1, 1, 1], [0, 6, 11], [11, 0, 3]]
        let linkSets: [[Link]] = [level.fixedLinks, [Link(a: 0, b: 1), Link(a: 1, b: 2)]]
        for phases in phaseSets {
            for links in linkSets {
                #expect(elsewhere.listen(links: links, phases: phases) == level.listen(links: links, phases: phases))
            }
        }
        let sequences: [[Action]] = [[.listen], Self.wanderThenWin]
        for actions in sequences {
            let here: Play = try Self.played(level, actions)
            let there: Play = try Self.played(elsewhere, actions)
            #expect(here.report == there.report && here.links == there.links && here.phases == there.phases)
            #expect(here.stage == there.stage && here.failure == there.failure)
            #expect(here.actionsSpent == there.actionsSpent && here.label == there.label)
        }
        // A copy is independent, and reading names, descriptions and labels changes nothing.
        let original: Play = play
        var copy: Play = play
        try copy.apply(.nudge(2, 1), expecting: copy.fingerprint)
        #expect(play == original && copy.phases[2] == 3 && play.phases[2] == 2)
        let fingerprint: String = play.fingerprint
        var words: [String] = [play.progressDescription, play.label]
        for star in 0..<level.stars.count { words.append(level.starName(star, phase: play.phases[star])) }
        for link in play.links { words.append(level.linkName(link, phases: play.phases)) }
        _ = play.matchesSymbol
        _ = play.canUndo
        _ = play.canRedo
        #expect(words.count == 2 + level.stars.count + play.links.count)
        #expect(play.fingerprint == fingerprint && play == original)
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation, read no clock or random
        // source, use no Double or Float and declare no class. Forbidden import lines are built by concatenation.
        let prefix: String = "import" + " "
        let frameworks: [String] = ["UIKit", "SwiftUI", "AppKit", "Metal", "MetalKit", "QuartzCore", "OpenGLES",
                                    "GLKit", "CoreGraphics", "SpriteKit", "SceneKit", "GameKit", "CoreMotion",
                                    "Combine", "VisualCoreRendering", "CoreImage", "AVFoundation"]
        var forbidden: [String] = []
        for name in frameworks { forbidden.append(prefix + name) }
        let calls: [String] = ["Date()", "Date.now", "CFAbsoluteTimeGetCurrent", "CACurrentMediaTime",
                               "DispatchTime.now", "ContinuousClock", "SuspendingClock", "systemUptime",
                               "SystemRandomNumberGenerator", ".random(", "arc4random", "UUID()", "Double", "Float",
                               "CGFloat"]
        forbidden.append(contentsOf: calls)
        let allowedImports: Set<String> = [prefix + "Foundation", prefix + "VisualCoreMath",
                                           prefix + "VisualCoreSimulation"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count == Self.kernelFiles.count)
        for source in sources {
            for token in forbidden {
                #expect(!source.text.contains(token), "\(source.name) uses \(token)")
            }
            for line in source.text.split(separator: "\n") {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(prefix) {
                    #expect(allowedImports.contains(trimmed), "\(source.name) imports \(trimmed)")
                }
                let isClass: Bool = trimmed.hasPrefix("class ") || trimmed.hasPrefix("final class ")
                    || trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public final class ")
                    || trimmed.hasPrefix("open class ")
                #expect(!isClass, "\(source.name) declares a reference type: \(trimmed)")
            }
        }
        // Seeded neighbours: stars moved to seeded positions (rates and phases kept) give the same outcome after every
        // action of the same seeded walk; reading the words on the moved level changes no fingerprint.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let other: Level = Self.neighbour(index).level
            var positions: [Star] = []
            for star in other.stars {
                positions.append(Star(x: random.int(0...11), y: random.int(0...11), z: random.int(0...11),
                                      rate: star.rate, phase: star.phase))
            }
            let shifted: Level = try Self.variant(other, stars: positions)
            var a: Play = try Self.playing(other)
            var b: Play = try Self.playing(shifted)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(other, random: &random)
                let errorA: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let errorB: AcousticConstellatorError? = Self.refusal { () throws(AcousticConstellatorError) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(errorA == errorB)
                #expect(a.report == b.report && a.links == b.links && a.phases == b.phases && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsSpent == b.actionsSpent)
                let held: String = b.fingerprint
                _ = b.progressDescription
                for star in 0..<shifted.stars.count { _ = shifted.starName(star, phase: b.phases[star]) }
                for link in b.links { _ = shifted.linkName(link, phases: b.phases) }
                #expect(b.fingerprint == held)
            }
        }
    }
}
