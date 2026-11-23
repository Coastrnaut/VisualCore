// BackwardsAuroraInvariantTests — feature 391 (R02-G10-01) T-R02G1001-006 (FR-R02G1001-012; the source's invariants
// R2-G10-INV-01 … 05 and INV-07 … 10 on Backwards Aurora). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,396: a known section's start or end ± 1, a section one sample too long, an end
// just outside the wave, a breaking limit ± 1, a budget ± 1), as the source asks. How each invariant maps onto this
// kernel (INV-06 content and INV-12 novelty belong to R02-G10-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock. The same reversals give the same fingerprints and records however many pauses
//   and reads lie between them; an idle play never spends or fails; the kernel sources hold no clock, time interval or
//   floating-point value.
// - INV-02 Input budget: exactly one reversal is spent per accepted action; refusals spend nothing; undo restores the
//   reversals of the moment it restores (gives one back) and redo spends it again; the reversals spent never exceed the
//   budget; the reversal that reaches the budget is applied and judged.
// - INV-03 Goal: the level is won exactly when every checkpoint has its target height and every bend is within the
//   bend limit (|b| ≤ L, equality included); matched checkpoints with one bend over L do not win.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior wave, reversals, stage, failure and fingerprint; redo the later one; a
//   new action clears redo; a won level is final; a paused play stays paused; a failed play returns to playing.
// - INV-07 Failure honesty: a tear names the 0-based reversal and the lowest seam whose bend exceeds the breaking limit
//   (|b| = B survives, B + 1 tears) and is judged before the win and the budget; the budget is named only when the
//   reversals spent equal the budget and the action neither tore nor won; a torn play undone still wins with its known
//   reversals (no hidden solution).
// - INV-08 Stability: over seeded traces the wave keeps its length and multiset of heights, every sample stays in
//   −64 … 64, every bend within 256 and both distance sums within 4,096; the counts stay consistent; nothing traps.
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer stored forms are refused as a
//   whole; a stored record trace up to a save point replays to the state at that point; a damaged trace is refused.
// - INV-10 Renderer purity: the kernel types are value types; reading, naming, copying and decoding change no
//   fingerprint; the kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation (no rendering, UI,
//   GL or Metal framework) and use no clock, random source, Double or Float.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden import names are built by concatenation
// so that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite struct BackwardsAuroraInvariantTests {
    typealias Play = BackwardsAuroraPlay
    typealias Action = BackwardsAuroraAction

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_396

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The true wave of the hand-made level: a straight rise that levels off (bends 0 except −2 at position 10).
    static let target: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20]

    /// The opening wave: the target with the section [2, 5] reversed (bends 6, −10, 0, 0, 10, −6 at 1 … 6).
    static let opening: [Int] = [0, 2, 10, 8, 6, 4, 12, 14, 16, 18, 20, 20]

    /// The winning reversal: [2, 5] restores the target.
    static let winning: Action = .reverse(2, 5)

    /// A reversal that tears from the opening wave: [6, 11] makes bends 18 at seam 5 and −16 at seam 6.
    static let tearing: Action = .reverse(6, 11)

    /// A reversal that makes bends 12 at seam 1 and −12 at seam 2 from the opening wave (B = 12 survives, 11 tears).
    static let edge: Action = .reverse(0, 1)

    /// Three reversals that neither tear (B = 12) nor win.
    static let wandering: [Action] = [.reverse(0, 1), .reverse(9, 10), .reverse(0, 1)]

    /// A hand-made 12-sample level: checkpoints 2 and 9, sections of 2 … 6 samples.
    static func sample(bendLimit: Int = 4, breakingLimit: Int = 12, budget: Int = 6,
                       tutorial: Bool = false) throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
        let start: BackwardsAuroraWave = try BackwardsAuroraWave(opening)
        let goal: BackwardsAuroraWave = try BackwardsAuroraWave(target)
        return try BackwardsAuroraLevel(id: "invariant", seed: seed, difficulty: 2, opening: start, target: goal,
                                        checkpoints: [2, 9], bendLimit: bendLimit, breakingLimit: breakingLimit,
                                        shortest: 2, longest: 6, budget: budget, tutorial: tutorial)
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: BackwardsAuroraLevel) throws(BackwardsAuroraError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: BackwardsAuroraLevel, _ actions: [Action]) throws(BackwardsAuroraError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(BackwardsAuroraError) -> Void) -> BackwardsAuroraError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is an `.action` refusal (any payload).
    static func isAction(_ error: BackwardsAuroraError?) -> Bool {
        if case .action = error { return true }
        return false
    }

    /// The section of `action`.
    static func section(_ action: Action) -> (start: Int, end: Int) {
        switch action {
        case let .reverse(start, end): return (start: start, end: end)
        }
    }

    /// The lowest seam of the section [start, end] of `wave` (already reversed) whose bend exceeds `limit`, or nil.
    static func invTornSeam(_ wave: BackwardsAuroraWave, start: Int, end: Int, limit: Int) -> Int? {
        let seams: [Int] = BackwardsAuroraWave.seams(start: start, end: end, count: wave.count)
        for k in seams where abs(wave.bend(at: k)) > limit { return k }
        return nil
    }

    /// Whether `wave` wins `level`, decided independently: every checkpoint at its target height and every bend within
    /// the bend limit.
    static func invWins(_ wave: BackwardsAuroraWave, _ level: BackwardsAuroraLevel) -> Bool {
        for position in level.checkpoints where wave.samples[position] != level.target.samples[position] {
            return false
        }
        for k in 1...(wave.count - 2) {
            let b: Int = wave.samples[k - 1] - 2 * wave.samples[k] + wave.samples[k + 1]
            if abs(b) > level.bendLimit { return false }
        }
        return true
    }

    /// The stage and failure an accepted `action` at reversal `moveIndex` must leave, judged independently (tear, then
    /// win, then budget).
    static func invJudge(_ play: Play, _ action: Action,
                         moveIndex: Int) -> (stage: BackwardsAuroraStage, failure: BackwardsAuroraFailure?) {
        let level: BackwardsAuroraLevel = play.level
        let s: (start: Int, end: Int) = section(action)
        if let seam = invTornSeam(play.wave, start: s.start, end: s.end, limit: level.breakingLimit) {
            return (.failed, .tear(moveIndex, seam))
        }
        if invWins(play.wave, level) { return (.won, nil) }
        if play.spent >= level.budget { return (.failed, .budget) }
        return (.playing, nil)
    }

    /// A seeded reversal for `play`: a known section's neighbour (start or end ± 1), a random section of an allowed
    /// length, a section one sample too long, a single sample or an end just outside the wave.
    static func invAction(_ play: Play, _ fixture: BackwardsAuroraFixture,
                          random: inout SeededRandom) -> Action {
        let level: BackwardsAuroraLevel = play.level
        let count: Int = level.count
        let roll: Int = random.int(0...19)
        if roll == 0 { return .reverse(-1, random.int(1...(count - 1))) }
        if roll == 1 { return .reverse(random.int(0...(count - 2)), count) }
        if roll == 2 {
            let start: Int = random.int(0...(count - 1))
            return .reverse(start, start)
        }
        if roll == 3 && level.longest < count {
            let start: Int = random.int(0...(count - level.longest - 1))
            return .reverse(start, start + level.longest)
        }
        if roll < 10 {
            let known: (start: Int, end: Int) = fixture.sections[random.int(0...(fixture.sections.count - 1))]
            let sign: Int = random.int(0...1) == 0 ? -1 : 1
            if random.int(0...2) == 0 { return .reverse(known.start, known.end) }
            if random.int(0...1) == 0 { return .reverse(known.start + sign, known.end) }
            return .reverse(known.start, known.end + sign)
        }
        let length: Int = random.int(level.shortest...level.longest)
        let start: Int = random.int(0...(count - length))
        return .reverse(start, start + length - 1)
    }

    /// What one seeded step did.
    enum StepKind: Equatable { case undo, redo, pause, resume, action }

    /// One seeded step: its kind, its action (if any), the play before it and its refusal (if any).
    typealias Step = (kind: StepKind, action: Action?, before: Play, error: BackwardsAuroraError?)

    /// One seeded step on `play`: an undo or redo when possible (always an undo from a failed play), a pause or resume,
    /// or a reversal. A refused step must leave the play unchanged.
    static func invStep(_ play: inout Play, _ fixture: BackwardsAuroraFixture, random: inout SeededRandom) -> Step {
        let before: Play = play
        let roll: Int = random.int(0...19)
        if play.stage == .failed && play.canUndo {
            let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 0 && play.canUndo {
            let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 1 && play.canRedo {
            let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in try play.redo() }
            return (.redo, nil, before, error)
        }
        if roll == 2 && play.stage == .playing {
            let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in try play.handle(.pause) }
            return (.pause, nil, before, error)
        }
        if play.stage == .paused {
            let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in try play.handle(.resume) }
            return (.resume, nil, before, error)
        }
        let action: Action = invAction(play, fixture, random: &random)
        let error: BackwardsAuroraError? = refusal { () throws(BackwardsAuroraError) in
            try play.apply(action, expecting: play.fingerprint)
        }
        if error != nil && play != before { Issue.record("a refused \(action) changed the play") }
        return (.action, action, before, error)
    }

    /// A seeded walk of at most `steps` steps on a playing play of the fixture's level; a won play ends the walk.
    static func invWalk(_ fixture: BackwardsAuroraFixture, steps: Int,
                        random: inout SeededRandom) throws(BackwardsAuroraError) -> Play {
        var play: Play = try playing(fixture.level)
        for _ in 0..<steps {
            if play.stage == .won { break }
            _ = invStep(&play, fixture, random: &random)
        }
        return play
    }

    /// Whether two plays hold the same kernel state.
    static func sameState(_ a: Play, _ b: Play) -> Bool {
        a.fingerprint == b.fingerprint && a.wave == b.wave && a.spent == b.spent && a.stage == b.stage
            && a.failure == b.failure
    }

    /// `play` resumed if it is paused. A trace records no pause, so a replay ends paused only when its last record was
    /// made while paused; plays are compared resumed.
    static func unpaused(_ play: Play) throws(BackwardsAuroraError) -> Play {
        var copy: Play = play
        if copy.stage == .paused { try copy.handle(.resume) }
        return copy
    }

    /// The fixture of the neighbouring checks: the fixtures from seed 2,396 on.
    static func neighbour(_ index: Int) -> BackwardsAuroraFixture {
        BackwardsAuroraFixtures.fixture(seed &+ UInt64(index))
    }

    /// The presentation sources of the Core (feature 393, R02-G10-03): the scene snapshot, geometry, shaders, adapter
    /// and scenarios use Doubles and the experience frameworks; they never decide a rule and are covered by their own
    /// tests and the renderer-purity tests, so the kernel scan skips them.
    static let presentationSources: Set<String> = [
        "BackwardsAuroraSceneSnapshot.swift", "BackwardsAuroraSceneGeometry.swift", "BackwardsAuroraShaders.swift",
        "BackwardsAuroraExperienceCore.swift", "BackwardsAuroraScenarios.swift",
        // Feature 394 (R02-G10-04): the picker, the freeze preview and the gesture controller (touch geometry in
        // Doubles, pointer events); presentation only, covered by their own tests and the renderer-purity tests.
        "BackwardsAuroraPicker.swift", "BackwardsAuroraFreezePreview.swift", "BackwardsAuroraGestureController.swift",
        // Feature 396 (R02-G10-06): the eased lights and the ambient sound recipe (Doubles, VisualCoreAudioDSP);
        // presentation only, covered by their own tests.
        "BackwardsAuroraLights.swift", "BackwardsAuroraSoundRecipe.swift",
    ]

    /// The Swift sources of the kernel (the Core directory next to this test directory, without the presentation
    /// sources).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: core.path).sorted()
        var sources: [(name: String, text: String)] = []
        for name in names where name.hasSuffix(".swift") && !presentationSources.contains(name) {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    // MARK: INV-01 Time

    /// INV-01 Time: no rule reads a clock; pauses and reads between actions change no fingerprint.
    @Test func testBackwardsAuroraTimeBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: the same reversals applied straight and after many pauses and reads.
        let actions: [Action] = [Self.wandering[1], Self.wandering[1], Self.edge, Self.winning, Self.edge]
        var straight: Play = try Self.playing(level)
        var framed: Play = try Self.playing(level)
        for action in actions {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                _ = framed.fingerprint
                _ = framed.distance
                _ = framed.worstBend
                try framed.handle(.pause)
                try framed.handle(.resume)
            }
            _ = level.targetDescription()
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.spent == straight.spent)
        }
        #expect(straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends reversals nor fails, however long it waits or how often it is paused.
        var idle: Play = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.spent == 0 && idle.failure == nil && idle.fingerprint == opening)
        #expect(idle.records.isEmpty && idle.remaining == level.budget)
        // The kernel holds no clock, time interval or floating-point value.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "Clock", "CFAbsoluteTime", "DispatchTime",
                                "Timer"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 4)
        for source in sources {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: accepted reversals repeated after seeded numbers of pauses and reads reach the same
        // fingerprint after every action and the same records.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            var a: Play = try Self.playing(fixture.level)
            var b: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(a, fixture, random: &random)
                let error: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    _ = b.matched
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.spent == b.spent && a.stage == b.stage)
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: one reversal per accepted action, none per refusal; the action reaching the budget is
    /// judged.
    @Test func testBackwardsAuroraInputbudgetBoundary() throws {
        // Direct: 3 reversals that neither tear nor win fail a budget-3 level on the third; more is refused.
        var spent: Play = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(spent.spent == 3 && spent.remaining == 0 && spent.stage == .failed && spent.failure == .budget)
        let held: Play = spent
        let late: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try spent.apply(Self.winning, expecting: spent.fingerprint)
        }
        #expect(late == .stage && spent == held)
        // With one reversal more of budget, the same three leave one; a win on the reversal reaching the budget wins.
        let spare: Play = try Self.played(try Self.sample(budget: 4), Self.wandering)
        #expect(spare.stage == .playing && spare.spent == 3 && spare.remaining == 1 && spare.failure == nil)
        let exact: Play = try Self.played(try Self.sample(budget: 1), [Self.winning])
        #expect(exact.stage == .won && exact.spent == 1 && exact.remaining == 0 && exact.failure == nil)
        // Refused actions spend nothing: stage, stale, range, length and no-op, in that order of validation.
        var loading: Play = Play(level: try Self.sample())
        let early: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try loading.apply(Self.winning, expecting: Self.staleFingerprint)
        }
        #expect(early == .stage && loading.spent == 0)
        var play: Play = try Self.playing(try Self.sample())
        let opening: Play = play
        let stale: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(-1, 3), expecting: Self.staleFingerprint)
        }
        let below: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(-1, 1), expecting: play.fingerprint)
        }
        let beyond: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(10, 12), expecting: play.fingerprint)
        }
        let single: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(4, 4), expecting: play.fingerprint)
        }
        let backwards: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(5, 2), expecting: play.fingerprint)
        }
        let long: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(0, 6), expecting: play.fingerprint)
        }
        let noop: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
            try play.apply(.reverse(10, 11), expecting: play.fingerprint)
        }
        #expect(stale == .stale && noop == .noop)
        #expect(Self.isAction(below) && Self.isAction(beyond) && Self.isAction(single) && Self.isAction(backwards))
        #expect(Self.isAction(long))
        #expect(play == opening && play.spent == 0 && play.remaining == 6 && play.records.isEmpty)
        // The longest allowed section is accepted and spends exactly one; undo gives it back, redo spends it again.
        try play.apply(.reverse(0, 5), expecting: play.fingerprint)
        #expect(play.spent == 1 && play.remaining == 5 && play.records.count == 1)
        try play.undo()
        #expect(play.spent == 0 && play.remaining == 6)
        try play.redo()
        #expect(play.spent == 1 && play.remaining == 5 && play.records.count == 3)
        // Seeded neighbours: over seeded walks the reversals stay within the budget, an accepted reversal spends
        // exactly one, refusals and pauses spend none, undo and redo move by one, a play at the budget is decided.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for index in 0..<40 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            let budget: Int = fixture.level.budget
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                #expect(walk.spent >= 0 && walk.spent <= budget)
                #expect(walk.remaining == budget - walk.spent)
                if step.error != nil {
                    #expect(walk == step.before)
                    continue
                }
                switch step.kind {
                case .action:
                    #expect(walk.spent == step.before.spent + 1)
                    #expect(walk.records.count == step.before.records.count + 1)
                    if walk.spent == budget { #expect(walk.stage == .won || walk.stage == .failed) }
                case .undo:
                    #expect(walk.spent == step.before.spent - 1)
                case .redo:
                    #expect(walk.spent == step.before.spent + 1)
                case .pause, .resume:
                    #expect(walk.spent == step.before.spent && walk.records == step.before.records)
                }
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won exactly when every checkpoint matches and every bend is within the bend limit.
    @Test func testBackwardsAuroraGoalBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: a fresh play is not won; the winning reversal wins at once.
        let fresh: Play = try Self.playing(level)
        #expect(fresh.stage == .playing && fresh.matched == [false, true] && !level.wins(fresh.wave))
        let won: Play = try Self.played(level, [Self.winning])
        #expect(won.stage == .won && won.wave == level.target && won.matched == [true, true])
        #expect(won.distance.numerator == 0 && won.distance.denominator == 130)
        #expect(fresh.distance.numerator == 16 && fresh.distance.denominator == 130)
        // Every checkpoint matched but one bend of 6 over the limit 4 does not win; smoothing it wins.
        var rough: Play = try Self.played(level, [Self.edge, Self.winning])
        #expect(rough.matched == [true, true] && rough.worstBend == 6 && rough.stage == .playing)
        try rough.apply(Self.edge, expecting: rough.fingerprint)
        #expect(rough.stage == .won && rough.wave == level.target && rough.spent == 3)
        // A smooth wave with a checkpoint off its target height does not win: the whole target reversed.
        let flipped: BackwardsAuroraWave = try BackwardsAuroraWave(Array(Self.target.reversed()))
        #expect(flipped.isSmooth(limit: level.bendLimit) && !level.wins(flipped) && !Self.invWins(flipped, level))
        // The bend limit is inclusive: the target's worst bend is 2, so L = 2 wins and L = 1 never can.
        let atLimit: Play = try Self.played(try Self.sample(bendLimit: 2), [Self.winning])
        #expect(atLimit.stage == .won && atLimit.worstBend == 2)
        let belowLimit: Play = try Self.played(try Self.sample(bendLimit: 1), [Self.winning])
        #expect(belowLimit.stage == .playing && belowLimit.matched == [true, true] && belowLimit.worstBend == 2)
        // Seeded neighbours: after every accepted reversal the play is won exactly when the independent judge says so;
        // each fixture's known reversals win only on the last one, and a neighbouring section (an end ± 1) in its place
        // wins only when the judge agrees.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                guard step.kind == .action, step.error == nil, let action = step.action else { continue }
                let judged: (stage: BackwardsAuroraStage, failure: BackwardsAuroraFailure?) =
                    Self.invJudge(walk, action, moveIndex: step.before.spent)
                #expect((walk.stage == .won) == (judged.stage == .won))
                if walk.stage == .won { #expect(Self.invWins(walk.wave, fixture.level) && walk.failure == nil) }
            }
            var known: Play = try Self.playing(fixture.level)
            for (offset, s) in fixture.sections.enumerated() {
                let last: Bool = offset == fixture.sections.count - 1
                if last {
                    let sign: Int = random.int(0...1) == 0 ? -1 : 1
                    var near: Play = known
                    let error: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
                        try near.apply(.reverse(s.start, s.end + sign), expecting: near.fingerprint)
                    }
                    if error == nil {
                        let wins: Bool = Self.invWins(near.wave, fixture.level)
                            && Self.invTornSeam(near.wave, start: s.start, end: s.end + sign,
                                                limit: fixture.level.breakingLimit) == nil
                        #expect((near.stage == .won) == wins)
                    }
                }
                try known.apply(.reverse(s.start, s.end), expecting: known.fingerprint)
                #expect((known.stage == .won) == last)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records and fingerprints; replay reproduces them.
    @Test func testBackwardsAuroraRepeatabilityBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: two independent runs with an undo and a redo agree record for record and replay agrees.
        var first: Play = try Self.played(level, Self.wandering)
        var second: Play = try Self.played(level, Self.wandering)
        try first.undo()
        try second.undo()
        try first.redo()
        try second.redo()
        try first.apply(Self.winning, expecting: first.fingerprint)
        try second.apply(Self.winning, expecting: second.fingerprint)
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.records.count == 6 && first.stage == second.stage)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(Self.sameState(replayed, first) && replayed.records == first.records)
        // An edited or forged record is refused: a changed next fingerprint, a changed action, a missing action.
        var forged: [BackwardsAuroraRecord] = first.records
        let one: BackwardsAuroraRecord = forged[0]
        forged[0] = BackwardsAuroraRecord(schema: one.schema, seed: one.seed, move: one.move, kind: one.kind,
                                          action: one.action, previous: one.previous, next: Self.staleFingerprint)
        #expect(Self.refusal { () throws(BackwardsAuroraError) in
            _ = try Play.replay(level: level, records: forged)
        } != nil)
        var swapped: [BackwardsAuroraRecord] = first.records
        swapped[1] = BackwardsAuroraRecord(schema: one.schema, seed: one.seed, move: 1, kind: .reverse,
                                           action: .reverse(1, 2), previous: first.records[1].previous,
                                           next: first.records[1].next)
        #expect(Self.refusal { () throws(BackwardsAuroraError) in
            _ = try Play.replay(level: level, records: swapped)
        } != nil)
        var bare: [BackwardsAuroraRecord] = first.records
        bare[0] = BackwardsAuroraRecord(schema: one.schema, seed: one.seed, move: one.move, kind: .reverse,
                                        action: nil, previous: one.previous, next: one.next)
        #expect(Self.refusal { () throws(BackwardsAuroraError) in
            _ = try Play.replay(level: level, records: bare)
        } != nil)
        // The same records on a neighbouring level (budget + 1) are refused: every fingerprint names the level.
        let otherLevel: BackwardsAuroraLevel = try Self.sample(budget: 7)
        #expect(Self.refusal { () throws(BackwardsAuroraError) in
            _ = try Play.replay(level: otherLevel, records: first.records)
        } != nil)
        // Seeded neighbours: two walks drawn from equal seeds agree; replay reproduces every walk.
        for index in 0..<30 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            var randomA: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            var randomB: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            let a: Play = try Self.invWalk(fixture, steps: 30, random: &randomA)
            let b: Play = try Self.invWalk(fixture, steps: 30, random: &randomB)
            #expect(a == b && a.records == b.records && a.fingerprint == b.fingerprint)
            let again: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(again.records == a.records && again.wave == a.wave && again.spent == a.spent)
            #expect((try Self.unpaused(again)).fingerprint == (try Self.unpaused(a)).fingerprint)
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: exact restore; redo the later state; a won level is final; failed returns to playing.
    @Test func testBackwardsAuroraUndoBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: each undo restores the exact earlier state, each redo the later one.
        var play: Play = try Self.playing(level)
        var states: [Play] = [play]
        for action in Self.wandering {
            try play.apply(action, expecting: play.fingerprint)
            states.append(play)
        }
        for back in stride(from: states.count - 2, through: 0, by: -1) {
            try play.undo()
            #expect(Self.sameState(play, states[back]))
        }
        #expect(!play.canUndo && play.canRedo)
        let nothing: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in try play.undo() }
        #expect(Self.isAction(nothing))
        for forward in 1..<states.count {
            try play.redo()
            #expect(Self.sameState(play, states[forward]))
        }
        // A new action clears redo.
        try play.undo()
        #expect(play.canRedo)
        try play.apply(Self.edge, expecting: play.fingerprint)
        #expect(!play.canRedo)
        let noRedo: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in try play.redo() }
        #expect(Self.isAction(noRedo))
        // A paused play stays paused through undo and redo.
        try play.handle(.pause)
        let paused: Play = play
        try play.undo()
        #expect(play.stage == .paused)
        try play.redo()
        #expect(play.stage == .paused && play.wave == paused.wave && play.spent == paused.spent)
        // A won level is final: undo and redo are refused.
        var won: Play = try Self.played(level, [Self.winning])
        let wonHeld: Play = won
        let finalUndo: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in try won.undo() }
        let finalRedo: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in try won.redo() }
        #expect(finalUndo == .stage && finalRedo == .stage && won == wonHeld && !won.canUndo)
        // A torn play returns to playing with the exact earlier state, and then still wins.
        var torn: Play = try Self.played(level, [Self.tearing])
        #expect(torn.stage == .failed && torn.canUndo)
        try torn.undo()
        #expect(Self.sameState(torn, states[0]) && torn.failure == nil)
        try torn.apply(Self.winning, expecting: torn.fingerprint)
        #expect(torn.stage == .won)
        // Seeded neighbours: along seeded walks of accepted actions (undoing every failure at once), the states are
        // kept; undoing back to the start restores each one exactly, in reverse.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        for index in 0..<30 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            var walk: Play = try Self.playing(fixture.level)
            var kept: [Play] = [walk]
            for _ in 0..<12 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(walk, fixture, random: &random)
                let error: BackwardsAuroraError? = Self.refusal { () throws(BackwardsAuroraError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                if error != nil { continue }
                if walk.stage == .failed {
                    let before: Play = kept[kept.count - 1]
                    try walk.undo()
                    #expect(Self.sameState(walk, before) && walk.stage == .playing)
                    try walk.redo()
                    #expect(walk.stage == .failed)
                    try walk.undo()
                    continue
                }
                kept.append(walk)
            }
            if walk.stage == .won { continue }
            for back in stride(from: kept.count - 1, through: 0, by: -1) {
                #expect(Self.sameState(walk, kept[back]))
                if back > 0 { try walk.undo() }
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a tear names the reversal and the lowest breaking seam; the budget only at the budget.
    @Test func testBackwardsAuroraFailurehonestyBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: [6, 11] from the opening tears at seam 5 (bend 18 > 12) on reversal 0, not at seam 6.
        let torn: Play = try Self.played(level, [Self.tearing])
        #expect(torn.stage == .failed && torn.failure == .tear(0, 5) && torn.failure?.code == "tear")
        #expect(abs(torn.wave.bend(at: 5)) == 18 && abs(torn.wave.bend(at: 6)) == 16)
        // After two reversals it names reversal 2 (the record of that reversal holds move 2).
        let later: Play = try Self.played(level, [Self.wandering[1], Self.wandering[1], Self.tearing])
        #expect(later.failure == .tear(2, 5) && later.records.last?.move == 2 && later.spent == 3)
        // The breaking limit is inclusive: [0, 1] makes bends 12 and −12; B = 12 survives, B = 11 tears at seam 1, the
        // lower of the two breaking seams.
        let survives: Play = try Self.played(level, [Self.edge])
        #expect(survives.stage == .playing && survives.failure == nil && survives.worstBend == 12)
        let breaks: Play = try Self.played(try Self.sample(breakingLimit: 11), [Self.edge])
        #expect(breaks.stage == .failed && breaks.failure == .tear(0, 1))
        // The tear is judged before the budget: a tearing last reversal names the tear.
        let lastTear: Play = try Self.played(try Self.sample(budget: 1), [Self.tearing])
        #expect(lastTear.failure == .tear(0, 5))
        // The budget is named only when the reversals spent equal the budget.
        let early: Play = try Self.played(try Self.sample(budget: 4), Self.wandering)
        #expect(early.stage == .playing && early.failure == nil)
        let budget: Play = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(budget.failure == .budget && budget.failure?.code == "budget" && budget.spent == 3)
        // No hidden solution: the torn play undone still wins with the known reversal.
        var retry: Play = torn
        try retry.undo()
        try retry.apply(Self.winning, expecting: retry.fingerprint)
        #expect(retry.stage == .won && retry.failure == nil)
        // Seeded neighbours: every failure met on a seeded walk is honest. A tear names the reversal just spent (its
        // record's move) and the lowest seam of its section whose bend exceeds B, every lower seam within B; the budget
        // is named only at spent == budget with no tear and no win.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 5)
        var tears: Int = 0
        var budgets: Int = 0
        for index in 0..<40 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            let other: BackwardsAuroraLevel = fixture.level
            var walk: Play = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                guard step.kind == .action, step.error == nil, let action = step.action else { continue }
                let judged: (stage: BackwardsAuroraStage, failure: BackwardsAuroraFailure?) =
                    Self.invJudge(walk, action, moveIndex: step.before.spent)
                #expect(walk.stage == judged.stage && walk.failure == judged.failure)
                switch walk.failure {
                case let .tear(move, seam):
                    tears += 1
                    let s: (start: Int, end: Int) = Self.section(action)
                    #expect(move == walk.spent - 1 && walk.records.last?.move == move)
                    #expect(abs(walk.wave.bend(at: seam)) > other.breakingLimit)
                    let seams: [Int] = BackwardsAuroraWave.seams(start: s.start, end: s.end, count: other.count)
                    #expect(seams.contains(seam))
                    for k in seams where k < seam { #expect(abs(walk.wave.bend(at: k)) <= other.breakingLimit) }
                case .budget:
                    budgets += 1
                    #expect(walk.spent == other.budget && !Self.invWins(walk.wave, other))
                case nil:
                    #expect(walk.spent < other.budget || walk.stage == .won)
                }
            }
        }
        #expect(tears > 0 && budgets > 0)
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: bounded values and no trap over seeded traces.
    @Test func testBackwardsAuroraStabilityBoundary() throws {
        // Direct example: the extreme wave (16 samples of −64 then 16 of 64 against the alternating target) stays
        // within the bounds: bends at most 256, distance sums at most 4,096.
        var alternating: [Int] = []
        for k in 0..<32 { alternating.append(k % 2 == 0 ? 64 : -64) }
        var blocks: [Int] = Array(repeating: -64, count: 16)
        blocks.append(contentsOf: Array(repeating: 64, count: 16))
        let extreme: BackwardsAuroraLevel = try BackwardsAuroraLevel(
            id: "extreme", seed: Self.seed, difficulty: 5, opening: try BackwardsAuroraWave(blocks),
            target: try BackwardsAuroraWave(alternating), checkpoints: [0, 31], bendLimit: 64,
            breakingLimit: 128, shortest: 2, longest: 32, budget: 40)
        #expect(extreme.target.worstBend == 256)
        let far: (numerator: Int, denominator: Int) = extreme.opening.distance(to: extreme.target)
        #expect(far.numerator <= 4_096 && far.denominator == 2_048)
        var play: Play = try Self.playing(extreme)
        try play.apply(.reverse(15, 16), expecting: play.fingerprint)
        #expect(play.stage == .failed && play.worstBend <= 256 && play.failure == .tear(0, 15))
        // Seeded neighbours: long seeded traces on the fixtures (and on the extreme level) never trap; the wave keeps
        // its length and heights; bends, distances and counts stay in bounds and agree.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 6)
        var fixtures: [BackwardsAuroraFixture] = []
        for index in 0..<40 { fixtures.append(Self.neighbour(index)) }
        let extremeFixture: BackwardsAuroraFixture = BackwardsAuroraFixture(
            level: extreme, sections: [(start: 15, end: 16), (start: 0, end: 31), (start: 8, end: 23)], waves: [])
        fixtures.append(extremeFixture)
        for fixture in fixtures {
            let other: BackwardsAuroraLevel = fixture.level
            let heights: [Int] = other.opening.samples.sorted()
            var walk: Play = try Self.playing(other)
            var accepted: Int = 0
            for _ in 0..<60 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                if step.error == nil && step.kind != .pause && step.kind != .resume { accepted += 1 }
                #expect(walk.wave.count == other.count && walk.wave.samples.sorted() == heights)
                for value in walk.wave.samples { #expect(BackwardsAuroraWave.sampleRange.contains(value)) }
                for bend in walk.wave.bends { #expect(abs(bend) <= 256) }
                #expect(walk.worstBend <= 256 && walk.worstBend == walk.wave.worstBend)
                let d: (numerator: Int, denominator: Int) = walk.distance
                #expect(d.numerator >= 0 && d.numerator <= 4_096 && d.denominator >= 1 && d.denominator <= 4_096)
                #expect(walk.spent >= 0 && walk.spent <= other.budget && walk.remaining == other.budget - walk.spent)
                #expect(walk.matched.count == other.checkpoints.count)
                #expect(walk.records.count == accepted)
            }
        }
    }

    // MARK: INV-09 Save

    /// The stored form of `level` with key `key` set to `value` (fingerprint kept), sorted keys.
    static func invEditing(_ level: BackwardsAuroraLevel, key: String, value: Any) throws -> Data {
        let object: Any = try JSONSerialization.jsonObject(with: level.encoded())
        guard var dictionary = object as? [String: Any] else { throw BackwardsAuroraError.malformed("not an object") }
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func invDecodeRefusal(_ data: Data) -> BackwardsAuroraError? {
        do {
            _ = try BackwardsAuroraLevel.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// INV-09 Save: the stored level round-trips; damaged forms are refused whole; stored traces replay to save points.
    @Test func testBackwardsAuroraSaveBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample(tutorial: true)
        // Direct example: byte-for-byte round trip.
        let stored: Data = level.encoded()
        let decoded: BackwardsAuroraLevel = try BackwardsAuroraLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored && decoded.fingerprint == level.fingerprint)
        let viaCodable: BackwardsAuroraLevel = try JSONDecoder().decode(BackwardsAuroraLevel.self, from: stored)
        #expect(viaCodable == level)
        // Truncated, edited and newer forms are refused as a whole.
        var high: [Int] = Self.opening
        high[0] = 65
        var unequal: [Int] = Self.target
        unequal[0] = 1
        #expect(Self.invDecodeRefusal(stored.prefix(stored.count / 2)) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(Data()) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "budget", value: 5)) == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "budget", value: 0))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "breakingLimit", value: 3))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "breakingLimit", value: 13))
                    == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "opening", value: high))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "target", value: unequal))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "checkpoints", value: [2] as [Int]))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "opening", value: Self.target))
                    == .malformed("r02-g10.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "schema", value: 2)) == .newerSchema(2))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "schema", value: 0)) == .malformed("schema 0"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "fingerprint", value: Self.staleFingerprint))
                    == .malformed("fingerprint"))
        // A stored record trace up to a save point replays to the state at that point.
        var play: Play = try Self.playing(level)
        var saves: [Play] = []
        let actions: [Action] = [Self.wandering[0], Self.wandering[1], Self.wandering[2], Self.wandering[1],
                                 Self.winning]
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
            saves.append(play)
        }
        #expect(play.stage == .won)
        let trace: Data = try JSONEncoder().encode(play.records)
        let loaded: [BackwardsAuroraRecord] = try JSONDecoder().decode([BackwardsAuroraRecord].self, from: trace)
        #expect(loaded == play.records)
        for point in 1...loaded.count {
            let resumed: Play = try Play.replay(level: decoded, records: Array(loaded.prefix(point)))
            #expect(Self.sameState(resumed, saves[point - 1]))
        }
        // A damaged trace is refused: unreadable bytes, and a record whose previous fingerprint was edited.
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([BackwardsAuroraRecord].self, from: trace.prefix(trace.count / 2))
        }
        var damaged: [BackwardsAuroraRecord] = loaded
        let r: BackwardsAuroraRecord = damaged[2]
        damaged[2] = BackwardsAuroraRecord(schema: r.schema, seed: r.seed, move: r.move, kind: r.kind,
                                           action: r.action, previous: Self.staleFingerprint, next: r.next)
        #expect(Self.refusal { () throws(BackwardsAuroraError) in
            _ = try Play.replay(level: decoded, records: damaged)
        } != nil)
        // Seeded neighbours: every seeded level round-trips; a seeded truncation, a budget ± 1 and a breaking limit ± 1
        // are refused; the stored trace of a seeded walk replays to the walk's state.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 7)
        for index in 0..<40 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            let other: BackwardsAuroraLevel = fixture.level
            let bytes: Data = other.encoded()
            let back: BackwardsAuroraLevel = try BackwardsAuroraLevel.decode(bytes)
            #expect(back == other && back.encoded() == bytes)
            let cut: Int = random.int(0...(bytes.count - 1))
            #expect(Self.invDecodeRefusal(bytes.prefix(cut)) != nil)
            for budget in [other.budget - 1, other.budget + 1] {
                #expect(Self.invDecodeRefusal(try Self.invEditing(other, key: "budget", value: budget)) != nil)
            }
            for limit in [other.breakingLimit - 1, other.breakingLimit + 1] {
                let edited: Data = try Self.invEditing(other, key: "breakingLimit", value: limit)
                #expect(Self.invDecodeRefusal(edited) != nil)
            }
            let walk: Play = try Self.invWalk(fixture, steps: 30, random: &random)
            let saved: Data = try JSONEncoder().encode(walk.records)
            let records: [BackwardsAuroraRecord] = try JSONDecoder().decode([BackwardsAuroraRecord].self, from: saved)
            let restored: Play = try Play.replay(level: back, records: records)
            #expect(restored.records == walk.records && restored.wave == walk.wave && restored.spent == walk.spent)
            #expect(restored.fingerprint == (walk.records.last?.next ?? restored.fingerprint))
            #expect((try Self.unpaused(restored)).fingerprint == (try Self.unpaused(walk)).fingerprint)
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: value types only; reading changes nothing; the kernel imports no rendering framework.
    @Test func testBackwardsAuroraRendererpurityBoundary() throws {
        let level: BackwardsAuroraLevel = try Self.sample()
        // Direct example: the kernel types are value types.
        let play: Play = try Self.played(level, [Self.edge])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.wave).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: Self.winning).displayStyle == .enum)
        #expect(Mirror(reflecting: BackwardsAuroraFailure.budget).displayStyle == .enum)
        #expect(Mirror(reflecting: BackwardsAuroraStage.playing).displayStyle == .enum)
        // The play holds no visual state: no field names a colour, vertex, texture, shader, frame, time or layer.
        let visual: [String] = ["colo", "vertex", "texture", "shader", "frame", "time", "layer", "pixel", "mesh"]
        for child in Mirror(reflecting: play).children {
            let label: String = (child.label ?? "").lowercased()
            for word in visual { #expect(!label.contains(word), "the play holds \(label)") }
        }
        // A copy is independent: changing it leaves the original as it was.
        let original: Play = play
        var copy: Play = play
        try copy.apply(Self.wandering[1], expecting: copy.fingerprint)
        #expect(play == original && copy.spent == play.spent + 1 && copy.wave != play.wave)
        // Reading names and descriptions and decoding the level change nothing.
        let fingerprint: String = play.fingerprint
        var words: [String] = [level.targetDescription(), level.bendDescription(play.wave)]
        for position in 0..<level.count { words.append(level.sampleName(position, wave: play.wave)) }
        for index in 0..<level.checkpoints.count { words.append(level.checkpointName(index, wave: play.wave)) }
        _ = play.matched
        _ = play.distance
        _ = play.worstBend
        #expect(words.count == 2 + level.count + level.checkpoints.count)
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: BackwardsAuroraLevel = try BackwardsAuroraLevel.decode(level.encoded())
        let rebuilt: Play = try Play.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // The same state reached by another path (a reversal and its undo) has the same fingerprint.
        var detour: Play = try Self.playing(level)
        try detour.apply(Self.wandering[1], expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
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
        #expect(sources.count >= 4)
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
        // Seeded neighbours: for seeded walks, reading every name and description, copying the wave and rebuilding it
        // from its samples change no fingerprint; a neighbouring section (an end ± 1) reversed on a copy leaves the
        // walk as it was; replaying the records on the decoded level gives the same fingerprint.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let fixture: BackwardsAuroraFixture = Self.neighbour(index)
            let other: BackwardsAuroraLevel = fixture.level
            let p: Play = try Self.invWalk(fixture, steps: 20, random: &random)
            let held: String = p.fingerprint
            let heldWave: BackwardsAuroraWave = p.wave
            for position in 0..<other.count { _ = other.sampleName(position, wave: p.wave) }
            for k in 1...(other.count - 2) { _ = other.bendName(k, wave: p.wave) }
            _ = other.bendDescription(p.wave)
            let twin: BackwardsAuroraWave = try BackwardsAuroraWave(p.wave.samples)
            #expect(twin == p.wave && twin.bends == p.wave.bends)
            let known: (start: Int, end: Int) = fixture.sections[random.int(0...(fixture.sections.count - 1))]
            let end: Int = min(other.count - 1, known.end + (random.int(0...1) == 0 ? -1 : 1))
            if known.start < end { _ = p.wave.reversed(start: known.start, end: end) }
            #expect(p.fingerprint == held && p.wave == heldWave)
            if !p.records.isEmpty {
                let otherDecoded: BackwardsAuroraLevel = try BackwardsAuroraLevel.decode(other.encoded())
                let again: Play = try Play.replay(level: otherDecoded, records: p.records)
                #expect(again.records == p.records && again.wave == heldWave)
                #expect((try Self.unpaused(again)).fingerprint == (try Self.unpaused(p)).fingerprint)
            }
        }
    }
}
