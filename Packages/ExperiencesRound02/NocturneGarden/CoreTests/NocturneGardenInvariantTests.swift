// NocturneGardenInvariantTests — feature 381 (R02-G09-01) T-R02G0901-006 (FR-R02G0901-012; the source's invariants
// R2-G09-INV-01 … 05 and INV-07 … 10 on Nocturne Garden). Each named test gives a direct boundary example and a
// seeded check of neighbouring inputs (seed 2,386: an anchor column or row ± 1, a size ± 1, a neighbouring sun
// elevation, a bloom number ± 1), as the source asks. How each invariant maps onto this kernel (INV-06 content and
// INV-12 novelty belong to R02-G09-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock; the 120 Hz timestep is presentation only. The same actions give the same
//   fingerprints and records however many frames, pauses and reads lie between them; an idle play never fails; the
//   kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: the moves spent never exceed the budget and equal the accepted actions since the start less
//   those undone; every accepted action spends one; refusals spend nothing; undo gives the move back and redo spends it
//   again; the action that reaches the budget is applied and judged, so a win on it wins and anything else fails.
// - INV-03 Goal: the level is won exactly when at least one bloom is planted, the match |M ∩ T| / |M ∪ T| reaches p / q
//   (cross multiplication, equality included) and the leak is within the allowance; never before the first plant.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior state and fingerprint; redo the later one; a new action clears redo; a
//   won level is final; a paused play stays paused; a failed play returns to playing.
// - INV-07 Failure honesty: a leak names the 0-based move and is judged before the win; its reason gives the exact
//   leak, the move, the action with its bloom (or the sun) and the allowance; the budget is named only when the moves
//   equal the budget and the action neither won nor leaked; a failed fixture undone to its start still wins with its
//   known actions (no hidden solution).
// - INV-08 Stability: over seeded walks the mask equals the union of the blooms' shadows recomputed from scratch and
//   lies inside the bed; the blooms stay sorted, in the bed, of allowed sizes and within the supply; the counts (moves,
//   remaining, match, leak, deviation, records) stay consistent.
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer stored forms are refused as a
//   whole; a stored record trace up to a save point replays to the state at that point.
// - INV-10 Renderer purity: the kernel types are value types; the play holds no visual state; reading, naming, copying
//   and decoding change no fingerprint; a shadow depends only on the bloom (kind, anchor, size) and the sun; the kernel
//   sources import only Foundation, VisualCoreMath and VisualCoreSimulation (no rendering, UIKit, GL or Metal
//   framework) and use no clock, random source, Double or Float.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenInvariantTests {
    typealias Play = NocturneGardenPlay

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_386

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The presentation timestep (120 Hz); no rule reads it.
    static let timestep: Double = 1.0 / 120.0

    /// The bed of the hand-made levels.
    static let bedWidth: Int = 16
    static let bedHeight: Int = 12

    /// A tulip of size 1 at (3, 1) and a rose of size 1 at (11, 1); under sun 2 their shadows are disjoint.
    static let tulip: NocturneGardenBloom = NocturneGardenBloom(kind: .tulip, column: 3, row: 1, size: 1)
    static let rose: NocturneGardenBloom = NocturneGardenBloom(kind: .rose, column: 11, row: 1, size: 1)

    /// The cells of `bloom` in the hand-made bed under `elevation`.
    static func invCells(_ bloom: NocturneGardenBloom, _ elevation: Int) -> Set<Int> {
        bloom.cells(elevation: elevation, width: bedWidth, height: bedHeight)
    }

    /// The sample's target: the tulip's and the rose's shadows under sun 2.
    static func invTarget() -> Set<Int> {
        invCells(tulip, 2).union(invCells(rose, 2))
    }

    /// The sample's forbidden cells: the tulip's taller shadow under sun 3, outside the target.
    static func invForbidden() -> Set<Int> {
        invCells(tulip, 3).subtracting(invTarget())
    }

    /// A hand-made 16 × 12 level: the target is the tulip's and the rose's shadows under sun 2 (opening sun 2), the
    /// forbidden cells lie just above the tulip's shadow (reached by sun 3). ``winning`` wins it on its second action.
    static func sample(budget: Int = 6, required: NocturneGardenRatio = .whole, allowance: Int = 0,
                       tutorial: Bool = false) throws(NocturneGardenError) -> NocturneGardenLevel {
        try NocturneGardenLevel(id: "invariant", seed: seed, difficulty: 2, width: bedWidth, height: bedHeight,
                                target: invTarget(), forbidden: invForbidden(),
                                supply: [.tulip: 2, .rose: 2], sizes: [1, 2], elevations: [1, 2, 3], sun: 2,
                                budget: budget, required: required, leakAllowance: allowance, tutorial: tutorial)
    }

    /// The sample's winning actions: plant the tulip, then the rose.
    static let winning: [NocturneGardenAction] = [.plant(.tulip, 3, 1, 1), .plant(.rose, 11, 1, 1)]

    /// Three actions that neither win nor leak: a rose high on the right, a lower sun, a tulip low in the middle.
    static let wandering: [NocturneGardenAction] = [.plant(.rose, 12, 6, 1), .sun(1), .plant(.tulip, 8, 0, 1)]

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: NocturneGardenLevel) throws(NocturneGardenError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: NocturneGardenLevel,
                       _ actions: [NocturneGardenAction]) throws(NocturneGardenError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(NocturneGardenError) -> Void) -> NocturneGardenError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// The union of the blooms' shadows under `elevation`, recomputed from scratch.
    static func invUnion(_ blooms: [NocturneGardenBloom], _ elevation: Int,
                         _ level: NocturneGardenLevel) -> Set<Int> {
        var cells: Set<Int> = []
        for bloom in blooms {
            cells.formUnion(bloom.cells(elevation: elevation, width: level.width, height: level.height))
        }
        return cells
    }

    /// Whether `cells` meet the level's required match, decided independently: |M ∩ T|·q ≥ p·|M ∪ T|, |M ∪ T| > 0.
    static func invMet(_ cells: Set<Int>, _ level: NocturneGardenLevel) -> Bool {
        let shared: Int = cells.intersection(level.target).count
        let either: Int = cells.union(level.target).count
        return either > 0 && shared * level.required.denominator >= level.required.numerator * either
    }

    /// The stage and failure an accepted action at move `moveIndex` must leave, judged independently (leak, then win,
    /// then budget).
    static func invJudge(_ play: Play,
                         moveIndex: Int) -> (stage: NocturneGardenStage, failure: NocturneGardenFailure?) {
        let level: NocturneGardenLevel = play.level
        let cells: Set<Int> = invUnion(play.blooms, play.elevation, level)
        let leak: Int = cells.intersection(level.forbidden).count
        if leak > level.leakAllowance { return (.failed, .leak(moveIndex)) }
        if !play.blooms.isEmpty && invMet(cells, level) { return (.won, nil) }
        if play.moves >= level.budget { return (.failed, .budget) }
        return (.playing, nil)
    }

    /// The words the failure reason must give for `action`, from the plays before and after it.
    static func invWords(_ action: NocturneGardenAction, before: Play, after: Play) -> String {
        let level: NocturneGardenLevel = after.level
        let verb: String
        let bloom: NocturneGardenBloom
        switch action {
        case let .plant(kind, column, row, size):
            verb = "planting"
            bloom = NocturneGardenBloom(kind: kind, column: column, row: row, size: size)
        case let .move(index, column, row):
            verb = "moving"
            let old: NocturneGardenBloom = before.blooms[index]
            bloom = NocturneGardenBloom(kind: old.kind, column: column, row: row, size: old.size)
        case let .resize(index, size):
            verb = "resizing"
            let old: NocturneGardenBloom = before.blooms[index]
            bloom = NocturneGardenBloom(kind: old.kind, column: old.column, row: old.row, size: size)
        case let .remove(index):
            return "removing " + level.bloomName(index, bloom: before.blooms[index])
        case let .sun(elevation):
            return "setting " + NocturneGardenLevel.sunName(elevation)
        }
        guard let index = after.blooms.firstIndex(of: bloom) else { return verb }
        return verb + " " + level.bloomName(index, bloom: bloom)
    }

    /// A seeded action for `play`: a plant anywhere in the bed or a neighbour of a planted bloom (column or row ± 1,
    /// size ± 1, bloom number ± 1), a remove or a neighbouring sun; sometimes out of range.
    static func invAction(_ play: Play, random: inout SeededRandom) -> NocturneGardenAction {
        let level: NocturneGardenLevel = play.level
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        let count: Int = play.blooms.count
        let roll: Int = random.int(0...19)
        if roll == 0 { return .plant(kinds[random.int(0...5)], level.width, random.int(0...3), 1) }
        if roll == 1 { return .resize(count, 1) }
        if roll == 2 { return .sun(random.int(0...5)) }
        if count == 0 || roll % 4 == 0 {
            return .plant(kinds[random.int(0...5)], random.int(0...(level.width - 1)),
                          random.int(0...(level.height / 2)), random.int(1...3))
        }
        let index: Int = random.int(0...(count - 1))
        let bloom: NocturneGardenBloom = play.blooms[index]
        let sign: Int = random.int(0...1) == 0 ? -1 : 1
        switch roll % 4 {
        case 1:
            if random.int(0...1) == 0 { return .move(index, bloom.column + sign, bloom.row) }
            return .move(index, bloom.column, bloom.row + sign)
        case 2:
            return .resize(index, bloom.size + sign)
        default:
            if random.int(0...3) == 0 { return .remove((index + count + sign) % count) }
            return .sun(play.elevation + sign)
        }
    }

    /// What one seeded step did.
    enum StepKind: Equatable { case undo, redo, pause, resume, action }

    /// One seeded step: its kind, its action (if any), the play before it and its refusal (if any).
    typealias Step = (kind: StepKind, action: NocturneGardenAction?, before: Play, error: NocturneGardenError?)

    /// One seeded step on `play`: an undo or redo when possible (always an undo from a failed play), a pause or resume,
    /// or an action. A refused step must leave the play unchanged.
    static func invStep(_ play: inout Play, random: inout SeededRandom) -> Step {
        let before: Play = play
        let roll: Int = random.int(0...19)
        if play.stage == .failed && play.canUndo {
            let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 0 && play.canUndo {
            let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 1 && play.canRedo {
            let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in try play.redo() }
            return (.redo, nil, before, error)
        }
        if roll == 2 && play.stage == .playing {
            let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in try play.handle(.pause) }
            return (.pause, nil, before, error)
        }
        if play.stage == .paused {
            let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in try play.handle(.resume) }
            return (.resume, nil, before, error)
        }
        let action: NocturneGardenAction = invAction(play, random: &random)
        let error: NocturneGardenError? = refusal { () throws(NocturneGardenError) in
            try play.apply(action, expecting: play.fingerprint)
        }
        if error != nil && play != before { Issue.record("a refused \(action) changed the play") }
        return (.action, action, before, error)
    }

    /// A seeded walk of at most `steps` steps on a playing play of `level`; a won play ends the walk.
    static func invWalk(_ level: NocturneGardenLevel, steps: Int,
                        random: inout SeededRandom) throws(NocturneGardenError) -> Play {
        var play: Play = try playing(level)
        for _ in 0..<steps {
            if play.stage == .won { break }
            _ = invStep(&play, random: &random)
        }
        return play
    }

    /// Whether two plays hold the same kernel state.
    static func sameState(_ a: Play, _ b: Play) -> Bool {
        a.fingerprint == b.fingerprint && a.blooms == b.blooms && a.elevation == b.elevation && a.moves == b.moves
            && a.stage == b.stage && a.failure == b.failure && a.failureReason == b.failureReason && a.mask == b.mask
    }

    /// `play` resumed if it is paused. A trace records no pause, so a replay ends paused only when its last record was
    /// made while paused; plays are compared resumed, and a replay's fingerprint is its last record's next one.
    static func unpaused(_ play: Play) throws(NocturneGardenError) -> Play {
        var copy: Play = play
        if copy.stage == .paused { try copy.handle(.resume) }
        return copy
    }

    /// The fixture of the neighbouring checks: the fixtures from seed 2,386 on.
    static func neighbourFixture(_ index: Int) -> NocturneGardenFixture {
        NocturneGardenFixtures.fixture(seed &+ UInt64(index))
    }

    /// The level of ``neighbourFixture(_:)``.
    static func neighbour(_ index: Int) -> NocturneGardenLevel {
        neighbourFixture(index).level
    }

    /// The presentation sources of the Core (feature 383, R02-G09-03: the scene snapshot, geometry, shaders,
    /// experience adapter and scenarios; feature 384: the picker, drag preview and gesture controller), which read the
    /// kernel and turn its cells into Doubles for drawing; they are not kernel sources, and the renderer-purity tests
    /// of feature 383 cover them.
    static let presentationSources: Set<String> = [
        "NocturneGardenSceneSnapshot.swift", "NocturneGardenSceneGeometry.swift", "NocturneGardenShaders.swift",
        "NocturneGardenExperienceCore.swift", "NocturneGardenScenarios.swift",
        // Feature 384 (R02-G09-04): the picker, the drag preview and the gesture controller (touch geometry in Doubles,
        // pointer events); presentation only, covered by their own tests and the renderer-purity tests.
        "NocturneGardenPicker.swift", "NocturneGardenDragPreview.swift", "NocturneGardenGestureController.swift",
        // Feature 386 (R02-G09-06): the eased lights and the ambient recipe (presentation levels and frequencies in
        // Doubles); presentation only, covered by their own tests.
        "NocturneGardenLights.swift", "NocturneGardenSoundRecipe.swift",
        // Feature 388 (R02-G09-08): the golden frame descriptions (projected pixel positions in Doubles; debug and
        // automation builds only, forbidden in the Release binary); presentation only, covered by their own tests.
        "NocturneGardenGolden.swift",
    ]

    /// The Swift sources of the kernel (the Core directory next to this test directory, less the presentation
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

    /// INV-01 Time: the 120 Hz timestep is presentation only; frame and call spacing change no fingerprint.
    @Test func testNocturneGardenTimeBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample()
        // Direct example: the winning actions applied straight and after many presentation frames, pauses and reads.
        var straight: Play = try Self.playing(level)
        var framed: Play = try Self.playing(level)
        var clock: Double = 0
        for action in Self.winning {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                clock += Self.timestep
                _ = framed.fingerprint
                _ = framed.match
            }
            try framed.handle(.pause)
            _ = level.targetDescription()
            try framed.handle(.resume)
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.moves == straight.moves)
        }
        #expect(clock > 1.9 && straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends moves nor fails, however long it waits or how often it is paused.
        var idle: Play = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.moves == 0 && idle.failure == nil && idle.fingerprint == opening)
        // The kernel holds no clock, time interval or floating-point value; the timestep cannot reach a rule.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "Clock", "0.008", "CFAbsoluteTime",
                                "DispatchTime"]
        for source in try Self.kernelSources() {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: accepted actions replayed after seeded numbers of frames, pauses and reads reach the same
        // fingerprint after every action and the same records.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for index in 0..<30 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            var a: Play = try Self.playing(other)
            var b: Play = try Self.playing(other)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: NocturneGardenAction = Self.invAction(a, random: &random)
                let error: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    _ = b.deviation
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.moves == b.moves && a.stage == b.stage)
                if a.stage == .playing { #expect(a.moves < other.budget) }
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: moves never exceed the budget; the action reaching it is judged, winning or failing.
    @Test func testNocturneGardenInputbudgetBoundary() throws {
        // Direct example: three actions that neither win nor leak fail a budget-3 level on the third; more is refused.
        var spent: Play = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(spent.moves == 3 && spent.remaining == 0 && spent.stage == .failed && spent.failure == .budget)
        let held: Play = spent
        let late: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try spent.apply(.sun(3), expecting: spent.fingerprint)
        }
        #expect(late == .stage && spent == held)
        // A win on the action that reaches the budget wins; with one move more of budget, one move remains.
        let exact: Play = try Self.played(try Self.sample(budget: 2), Self.winning)
        #expect(exact.stage == .won && exact.moves == 2 && exact.remaining == 0 && exact.failure == nil)
        let spare: Play = try Self.played(try Self.sample(budget: 3), Self.winning)
        #expect(spare.stage == .won && spare.remaining == 1)
        let short: Play = try Self.played(try Self.sample(budget: 3), Array(Self.wandering.prefix(2)))
        #expect(short.stage == .playing && short.moves == 2 && short.remaining == 1)
        // Refused actions spend nothing; undo gives the move back and redo spends it again.
        var play: Play = try Self.playing(try Self.sample())
        let opening: Play = play
        let anchor: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.plant(.tulip, 16, 0, 1), expecting: play.fingerprint)
        }
        let size: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.plant(.tulip, 3, 1, 3), expecting: play.fingerprint)
        }
        let bloom: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.remove(0), expecting: play.fingerprint)
        }
        let supply: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.plant(.lily, 3, 1, 1), expecting: play.fingerprint)
        }
        let noop: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.sun(2), expecting: play.fingerprint)
        }
        let stale: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try play.apply(.sun(1), expecting: Self.staleFingerprint)
        }
        #expect(anchor == .action("anchor") && size == .action("size") && bloom == .action("bloom"))
        #expect(supply == .supply && noop == .noop && stale == .stale)
        #expect(play == opening && play.moves == 0 && play.remaining == 6 && play.records.isEmpty)
        try play.apply(.plant(.tulip, 3, 1, 1), expecting: play.fingerprint)
        #expect(play.moves == 1 && play.remaining == 5)
        try play.undo()
        #expect(play.moves == 0 && play.remaining == 6)
        try play.redo()
        #expect(play.moves == 1 && play.remaining == 5 && play.records.count == 3)
        // Seeded neighbours: over seeded walks the moves stay within the budget, the remaining moves agree, an accepted
        // action spends exactly one, refusals and pauses spend none, and a play that reached the budget is decided.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            var walk: Play = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, random: &random)
                #expect(walk.moves >= 0 && walk.moves <= other.budget)
                #expect(walk.remaining == other.budget - walk.moves)
                if step.kind == .action && step.error == nil {
                    #expect(walk.moves == step.before.moves + 1)
                    #expect(walk.records.count == step.before.records.count + 1)
                    if walk.moves == other.budget { #expect(walk.stage == .won || walk.stage == .failed) }
                }
                if step.kind == .action && step.error != nil {
                    #expect(walk.moves == step.before.moves && walk.records == step.before.records)
                }
                if step.kind == .pause || step.kind == .resume { #expect(walk.moves == step.before.moves) }
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won exactly when a bloom is planted, the match reaches p / q and the leak is within the allowance.
    @Test func testNocturneGardenGoalBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample()
        // Direct example: a fresh play is not won; the first plant keeps playing; the second wins (match 1/1).
        var play: Play = try Self.playing(level)
        #expect(play.stage == .playing && play.moves == 0 && play.blooms.isEmpty && !Self.invMet([], level))
        for (index, action) in Self.winning.enumerated() {
            try play.apply(action, expecting: play.fingerprint)
            #expect((play.stage == .won) == (index == Self.winning.count - 1))
        }
        #expect(play.match.shared == level.target.count && play.match.either == level.target.count && play.leak == 0)
        // The required fraction is a boundary: the tulip alone has match |tulip| / |target|; exactly that wins and one
        // shared cell more does not.
        let tulipCells: Int = Self.invCells(Self.tulip, 2).count
        let targetCells: Int = Self.invTarget().count
        #expect(Self.invCells(Self.tulip, 2).isDisjoint(with: Self.invCells(Self.rose, 2)))
        let atRatio: NocturneGardenRatio = try NocturneGardenRatio(tulipCells, targetCells)
        let aboveRatio: NocturneGardenRatio = try NocturneGardenRatio(tulipCells + 1, targetCells)
        let equal: Play = try Self.played(try Self.sample(required: atRatio), [Self.winning[0]])
        let above: Play = try Self.played(try Self.sample(required: aboveRatio), [Self.winning[0]])
        #expect(equal.stage == .won && equal.match.shared == tulipCells && equal.match.either == targetCells)
        #expect(above.stage == .playing)
        // A matching mask with the leak over the allowance does not win: a larger tulip covers the target's tulip part
        // and some forbidden cells; the leak is judged first.
        let big: Play = try Self.played(try Self.sample(required: atRatio), [.plant(.tulip, 3, 1, 2)])
        let bigCells: Set<Int> = Self.invCells(NocturneGardenBloom(kind: .tulip, column: 3, row: 1, size: 2), 2)
        let bigLeak: Int = bigCells.intersection(Self.invForbidden()).count
        if bigLeak > 0 {
            #expect(big.stage == .failed && big.failure == .leak(0))
            let allowed: Play = try Self.played(try Self.sample(required: atRatio, allowance: bigLeak),
                                                [.plant(.tulip, 3, 1, 2)])
            #expect((allowed.stage == .won) == Self.invMet(bigCells, allowed.level))
        }
        // A won level is final.
        var won: Play = play
        let undo: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in try won.undo() }
        let more: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try won.apply(.sun(3), expecting: won.fingerprint)
        }
        #expect(undo == .stage && more == .stage && won == play)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        // Seeded neighbours: every fixture wins exactly on its last action; replacing that plant by a neighbour (column
        // or row ± 1, size ± 1) or following it with a neighbouring sun gives exactly the independently judged outcome.
        for index in 0..<40 {
            let fixture: NocturneGardenFixture = Self.neighbourFixture(index)
            var fixed: Play = try Self.playing(fixture.level)
            for (step, action) in fixture.actions.enumerated() {
                try fixed.apply(action, expecting: fixed.fingerprint)
                #expect((fixed.stage == .won) == (step == fixture.actions.count - 1))
            }
            guard case let .plant(kind, column, row, size) = fixture.actions[fixture.actions.count - 1] else {
                continue
            }
            let base: Play = try Self.played(fixture.level, Array(fixture.actions.dropLast()))
            let neighbours: [NocturneGardenAction] = [.plant(kind, column - 1, row, size),
                                                      .plant(kind, column + 1, row, size),
                                                      .plant(kind, column, row - 1, size),
                                                      .plant(kind, column, row + 1, size),
                                                      .plant(kind, column, row, size - 1),
                                                      .plant(kind, column, row, size + 1),
                                                      .sun(base.elevation - 1),
                                                      .sun(base.elevation + 1)]
            for action in neighbours {
                var near: Play = base
                let error: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
                    try near.apply(action, expecting: near.fingerprint)
                }
                if error != nil { continue }
                let judged: (stage: NocturneGardenStage, failure: NocturneGardenFailure?) =
                    Self.invJudge(near, moveIndex: base.moves)
                #expect(near.stage == judged.stage && near.failure == judged.failure, "fixture \(index) \(action)")
            }
        }
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            var walk: Play = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, random: &random)
                let cells: Set<Int> = Self.invUnion(walk.blooms, walk.elevation, other)
                let within: Bool = cells.intersection(other.forbidden).count <= other.leakAllowance
                if walk.stage == .won { #expect(Self.invMet(cells, other) && within && !walk.blooms.isEmpty) }
                if walk.stage == .playing || walk.stage == .paused {
                    #expect(!(Self.invMet(cells, other) && within && !walk.blooms.isEmpty) && within)
                }
                guard step.kind == .action, step.error == nil else { continue }
                let judged: (stage: NocturneGardenStage, failure: NocturneGardenFailure?) =
                    Self.invJudge(walk, moveIndex: step.before.moves)
                #expect(walk.stage == judged.stage && walk.failure == judged.failure)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records, fingerprints and outcome; replay reproduces them.
    @Test func testNocturneGardenRepeatabilityBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample()
        // Direct example: two independent runs and a replay agree; an edited record is refused.
        let first: Play = try Self.played(level, Self.winning)
        let second: Play = try Self.played(try Self.sample(), Self.winning)
        #expect(first == second && first.records == second.records && first.fingerprint == second.fingerprint)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(Self.sameState(replayed, first) && replayed.records == first.records)
        var edited: [NocturneGardenRecord] = first.records
        let original: NocturneGardenRecord = edited[1]
        edited[1] = NocturneGardenRecord(schema: original.schema, seed: original.seed, move: original.move,
                                         kind: original.kind, action: .plant(.rose, 12, 1, 1),
                                         previous: original.previous, next: original.next)
        let refused: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            _ = try Play.replay(level: level, records: edited)
        }
        #expect(refused == .malformed("record 1"))
        var forged: [NocturneGardenRecord] = first.records
        forged[0] = NocturneGardenRecord(schema: forged[0].schema, seed: forged[0].seed, move: forged[0].move,
                                         kind: forged[0].kind, action: forged[0].action,
                                         previous: forged[0].previous, next: Self.staleFingerprint)
        let forgedError: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            _ = try Play.replay(level: level, records: forged)
        }
        #expect(forgedError == .malformed("record 0"))
        // Seeded neighbours: two runs of the same seeded walk agree, and the replay of its records reproduces it.
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            var r1: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            var r2: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            let a: Play = try Self.invWalk(other, steps: 30, random: &r1)
            let b: Play = try Self.invWalk(other, steps: 30, random: &r2)
            #expect(a == b && a.records == b.records)
            let again: Play = try Play.replay(level: other, records: a.records)
            #expect(again.records == a.records && again.blooms == a.blooms && again.moves == a.moves)
            let resumed: Play = try Self.unpaused(a)
            #expect(again.failure == a.failure && again.mask == a.mask)
            #expect(again.fingerprint == (a.records.last?.next ?? again.fingerprint))
            #expect((try Self.unpaused(again)).fingerprint == resumed.fingerprint)
            for record in a.records where record.action != nil {
                #expect(record.previous != record.next && record.schema == Play.schema)
                #expect(record.seed == other.seed)
            }
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo and redo restore exact states; won is final; paused stays paused; failed returns to playing.
    @Test func testNocturneGardenUndoBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample()
        // Direct example.
        var play: Play = try Self.playing(level)
        let nothing: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in try play.undo() }
        let nothingLater: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in try play.redo() }
        #expect(nothing == .action("nothing-to-undo") && nothingLater == .action("nothing-to-redo"))
        let opening: Play = play
        try play.apply(.plant(.tulip, 3, 1, 1), expecting: play.fingerprint)
        let planted: Play = play
        try play.undo()
        #expect(Self.sameState(play, opening) && play.canRedo)
        try play.redo()
        #expect(Self.sameState(play, planted))
        try play.undo()
        try play.apply(.plant(.rose, 12, 6, 1), expecting: play.fingerprint)
        #expect(!play.canRedo)
        // A paused play stays paused through undo and redo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.blooms.isEmpty && play.moves == 0)
        try play.redo()
        #expect(play.stage == .paused && play.moves == 1)
        try play.handle(.resume)
        // A leak failure returns to playing on undo, at the state before the failing action.
        var leaky: Play = try Self.played(level, [Self.winning[0]])
        let beforeLeak: Play = leaky
        try leaky.apply(.sun(3), expecting: leaky.fingerprint)
        #expect(leaky.stage == .failed && leaky.failure == .leak(1))
        try leaky.undo()
        #expect(Self.sameState(leaky, beforeLeak) && leaky.stage == .playing && leaky.failure == nil)
        // A won play is final.
        var won: Play = try Self.played(level, Self.winning)
        let finalUndo: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in try won.undo() }
        #expect(finalUndo == .stage && won.stage == .won && !won.canUndo)
        // Seeded neighbours: every accepted action that does not win is undone to the exact earlier state and redone to
        // the exact later one.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            var walk: Play = try Self.playing(other)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, random: &random)
                guard step.kind == .action, step.error == nil, walk.stage != .won else { continue }
                let after: Play = walk
                try walk.undo()
                #expect(Self.sameState(walk, step.before))
                if after.stage == .failed { #expect(walk.stage == .playing && walk.failure == nil) }
                try walk.redo()
                #expect(Self.sameState(walk, after))
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a leak names its move and is exact; the budget only when spent; no hidden solution.
    @Test func testNocturneGardenFailurehonestyBoundary() throws {
        let leak: Int = Self.invForbidden().intersection(Self.invCells(Self.tulip, 3)).count
        #expect(leak > 0)
        // Direct example: the tulip under sun 3 leaks `leak` cells at move 2 (index 1), allowance 0.
        let leaky: Play = try Self.played(try Self.sample(), [Self.winning[0], .sun(3)])
        #expect(leaky.stage == .failed && leaky.failure == .leak(1) && leaky.failure?.code == "leak")
        #expect(leaky.leak == leak)
        #expect(leaky.failureReason == "the shadow leaked into \(NocturneGardenLevel.cellsText(leak)) of the forbidden "
                    + "regions at move 2 (setting \(NocturneGardenLevel.sunName(3))), 0 allowed")
        // A leak exactly at the allowance is allowed; one cell under it fails.
        let atAllowance: Play = try Self.played(try Self.sample(allowance: leak), [Self.winning[0], .sun(3)])
        #expect(atAllowance.stage == .playing && atAllowance.failure == nil && atAllowance.leak == leak)
        let under: Play = try Self.played(try Self.sample(allowance: leak - 1), [Self.winning[0], .sun(3)])
        #expect(under.failure == .leak(1) && under.failureReason?.hasSuffix("\(leak - 1) allowed") == true)
        // A leak on the action that also reaches the budget is named a leak (leak before budget).
        let both: Play = try Self.played(try Self.sample(budget: 2), [Self.winning[0], .sun(3)])
        #expect(both.failure == .leak(1))
        // The budget is named only when the moves equal the budget, in words.
        let spent: Play = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(spent.failure == .budget && spent.failure?.code == "budget" && spent.moves == 3)
        #expect(spent.failureReason == "all 3 moves were spent without a match of 1/1")
        let early: Play = try Self.played(try Self.sample(budget: 4), Self.wandering)
        #expect(early.failure == nil && early.stage == .playing && early.failureReason == nil)
        let single: Play = try Self.played(try Self.sample(budget: 1), [Self.wandering[0]])
        #expect(single.failureReason == "the only move was spent without a match of 1/1")
        // The reason codes are stable.
        #expect(NocturneGardenError.stage.reasonCode == "r02-g09.stage")
        #expect(NocturneGardenError.stale.reasonCode == "r02-g09.stale")
        #expect(NocturneGardenError.action("anchor").reasonCode == "r02-g09.action")
        #expect(NocturneGardenError.supply.reasonCode == "r02-g09.supply")
        // Seeded neighbours: every failure in a seeded walk is the true one with an exact reason, and a failed fixture
        // undone to its start still wins with its known actions (no hidden solution).
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 5)
        for index in 0..<40 {
            let fixture: NocturneGardenFixture = Self.neighbourFixture(index)
            let other: NocturneGardenLevel = fixture.level
            var walk: Play = try Self.playing(other)
            var failures: Int = 0
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, random: &random)
                guard step.kind == .action, let action = step.action, step.error == nil else { continue }
                let cells: Set<Int> = Self.invUnion(walk.blooms, walk.elevation, other)
                let leaked: Int = cells.intersection(other.forbidden).count
                #expect(walk.leak == leaked)
                switch walk.failure {
                case .leak(let move)?:
                    failures += 1
                    let words: String = Self.invWords(action, before: step.before, after: walk)
                    let expected: String = "the shadow leaked into \(NocturneGardenLevel.cellsText(leaked)) of the "
                        + "forbidden regions at move \(move + 1) (\(words)), \(other.leakAllowance) allowed"
                    #expect(move == step.before.moves && leaked > other.leakAllowance)
                    #expect(walk.failureReason == expected)
                case .budget?:
                    failures += 1
                    let spentText: String = other.budget == 1 ? "the only move was" : "all \(other.budget) moves were"
                    #expect(walk.moves == other.budget && leaked <= other.leakAllowance)
                    #expect(!(Self.invMet(cells, other) && !walk.blooms.isEmpty))
                    #expect(walk.failureReason == "\(spentText) spent without a match of \(other.required.text)")
                case nil:
                    #expect(leaked <= other.leakAllowance && walk.failureReason == nil)
                    #expect(walk.stage == .won || walk.moves < other.budget)
                }
            }
            if walk.stage == .won { continue }
            while walk.canUndo { try walk.undo() }
            if walk.stage == .paused { try walk.handle(.resume) }
            #expect(walk.moves == 0 && walk.stage == .playing && walk.blooms.isEmpty && walk.elevation == other.sun)
            for action in fixture.actions { try walk.apply(action, expecting: walk.fingerprint) }
            #expect(walk.stage == .won, "fixture \(index) after \(failures) failures")
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: the mask equals the recomputed union, inside the bed; counts stay consistent over walks.
    @Test func testNocturneGardenStabilityBoundary() throws {
        // Direct example: the largest lily at the bed's far corner under the lowest sun casts far outside the bed; the
        // mask is clipped to the bed and equals the recomputed union; anchors outside the bed are refused, never
        // wrapped.
        let corner: NocturneGardenLevel = try NocturneGardenLevel(
            id: "corner", seed: Self.seed, difficulty: 1, width: 32, height: 24, target: [0], forbidden: [],
            supply: [.lily: 2], sizes: [3], elevations: [1, 4], sun: 4, budget: 4, required: .whole, leakAllowance: 0)
        var edge: Play = try Self.played(corner, [.plant(.lily, 31, 23, 3)])
        let lily: NocturneGardenBloom = NocturneGardenBloom(kind: .lily, column: 31, row: 23, size: 3)
        let cast: [NocturneGardenLattice] = lily.castPolygon(elevation: 4)
        var highest: Int = 0
        for point in cast { highest = max(highest, point.y) }
        #expect(highest == 2 * 23 + 4 * 3 * 6)
        #expect(edge.mask.cells == Self.invUnion(edge.blooms, 4, corner) && !edge.mask.cells.isEmpty)
        #expect(edge.mask.cells.allSatisfy { $0 >= 0 && $0 < corner.cellCount })
        #expect(edge.mask.cells.contains(23 * 32 + 31))
        let outside: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try edge.apply(.move(0, 32, 23), expecting: edge.fingerprint)
        }
        let below: NocturneGardenError? = Self.refusal { () throws(NocturneGardenError) in
            try edge.apply(.move(0, 31, -1), expecting: edge.fingerprint)
        }
        #expect(outside == .action("anchor") && below == .action("anchor"))
        try edge.apply(.sun(1), expecting: edge.fingerprint)
        #expect(edge.mask.cells == Self.invUnion(edge.blooms, 1, corner))
        // Fingerprints are stable: a rebuilt level and its plays agree; fingerprints are 64 lowercase hex digits.
        let level: NocturneGardenLevel = try Self.sample()
        let rebuilt: NocturneGardenLevel = try Self.sample()
        #expect(rebuilt.fingerprint == level.fingerprint)
        let once: Play = try Self.played(level, Self.winning)
        #expect(try Self.played(rebuilt, Self.winning).fingerprint == once.fingerprint)
        let hex: Set<Character> = Set("0123456789abcdef")
        #expect(once.fingerprint.count == 64 && once.fingerprint.allSatisfy { hex.contains($0) })
        // Seeded neighbours: over seeded walks the mask equals the union recomputed from scratch, inside the bed; the
        // blooms stay sorted, in the bed, of allowed sizes and within the supply; the counts stay consistent; a
        // rebuilt level keeps its fingerprint.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 6)
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            let again: NocturneGardenLevel = try NocturneGardenLevel(
                id: other.id, seed: other.seed, difficulty: other.difficulty, width: other.width, height: other.height,
                target: other.target, forbidden: other.forbidden, supply: other.supply, sizes: other.sizes,
                elevations: other.elevations, sun: other.sun, budget: other.budget, required: other.required,
                leakAllowance: other.leakAllowance, tutorial: other.tutorial)
            #expect(again.fingerprint == other.fingerprint)
            var walk: Play = try Self.playing(other)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, random: &random)
                let cells: Set<Int> = Self.invUnion(walk.blooms, walk.elevation, other)
                #expect(walk.mask.cells == cells && walk.mask.width == other.width && walk.mask.height == other.height)
                #expect(cells.allSatisfy { $0 >= 0 && $0 < other.cellCount })
                #expect(walk.blooms == walk.blooms.sorted() && other.elevations.contains(walk.elevation))
                for bloom in walk.blooms {
                    #expect(bloom.column >= 0 && bloom.column < other.width)
                    #expect(bloom.row >= 0 && bloom.row < other.height)
                    #expect(other.sizes.contains(bloom.size))
                }
                for kind in NocturneGardenKind.allCases {
                    #expect(walk.available(kind) >= 0 && walk.planted(kind) <= other.supplyCount(kind))
                }
                #expect(walk.moves >= 0 && walk.moves <= other.budget && walk.remaining == other.budget - walk.moves)
                #expect(walk.match.shared == cells.intersection(other.target).count)
                #expect(walk.match.either == cells.union(other.target).count)
                #expect(walk.match.shared <= walk.match.either && walk.match.either >= other.target.count)
                #expect(walk.leak == cells.intersection(other.forbidden).count && walk.leak <= other.forbidden.count)
                #expect(walk.deviation >= 0 && walk.deviation <= other.width + other.height)
                if step.error == nil && (step.kind == .action || step.kind == .undo || step.kind == .redo) {
                    #expect(walk.records.count == step.before.records.count + 1)
                } else {
                    #expect(walk.records.count == step.before.records.count)
                }
            }
        }
    }

    // MARK: INV-09 Save

    /// The stored form of `level` with key `key` set to `value` (fingerprint kept), sorted keys.
    static func invEditing(_ level: NocturneGardenLevel, key: String, value: Any) throws -> Data {
        let object: Any = try JSONSerialization.jsonObject(with: level.encoded())
        guard var dictionary = object as? [String: Any] else { throw NocturneGardenError.malformed("not an object") }
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func invDecodeRefusal(_ data: Data) -> NocturneGardenError? {
        do {
            _ = try NocturneGardenLevel.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// INV-09 Save: the stored level round-trips; damaged forms are refused whole; stored traces replay to save points.
    @Test func testNocturneGardenSaveBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample(tutorial: true)
        // Direct example: byte-for-byte round trip.
        let stored: Data = level.encoded()
        let decoded: NocturneGardenLevel = try NocturneGardenLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let viaCodable: NocturneGardenLevel = try JSONDecoder().decode(NocturneGardenLevel.self, from: stored)
        #expect(viaCodable == level)
        // Truncated, edited and newer forms are refused as a whole.
        let farCell: Int = 11 * 16 + 15
        let targetCell: Int = level.target.sorted()[0]
        #expect(Self.invDecodeRefusal(stored.prefix(stored.count / 2)) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(Data()) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "budget", value: 5)) == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "budget", value: 0))
                    == .malformed("r02-g09.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "leakAllowance", value: -1))
                    == .malformed("r02-g09.level"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "target", value: [] as [Int]))
                    == .malformed("r02-g09.level"))
        let overlapping: [Int] = (level.forbidden.union([targetCell])).sorted()
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "forbidden", value: overlapping))
                    == .malformed("r02-g09.level"))
        let extended: [Int] = (level.forbidden.union([farCell])).sorted()
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "forbidden", value: extended))
                    == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "schema", value: 2)) == .newerSchema(2))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "fingerprint", value: Self.staleFingerprint))
                    == .malformed("fingerprint"))
        let zeroMatch: [String: Int] = ["numerator": 0, "denominator": 4]
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "required", value: zeroMatch))
                    == .malformed("unreadable"))
        // A stored record trace up to a save point replays to the state at that point.
        var play: Play = try Self.playing(level)
        var saves: [Play] = []
        let actions: [NocturneGardenAction] = [.plant(.rose, 12, 6, 1), .sun(1), .remove(0), .sun(2),
                                               Self.winning[0], Self.winning[1]]
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
            saves.append(play)
        }
        #expect(play.stage == .won)
        let trace: Data = try JSONEncoder().encode(play.records)
        let loaded: [NocturneGardenRecord] = try JSONDecoder().decode([NocturneGardenRecord].self, from: trace)
        #expect(loaded == play.records)
        for point in 1...loaded.count {
            let resumed: Play = try Play.replay(level: decoded, records: Array(loaded.prefix(point)))
            #expect(Self.sameState(resumed, saves[point - 1]))
        }
        // Seeded neighbours: every seeded level round-trips; a seeded truncation, a budget ± 1 and an allowance ± 1 are
        // refused; the stored trace of a seeded walk replays to the walk's state.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 7)
        for index in 0..<40 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            let bytes: Data = other.encoded()
            let back: NocturneGardenLevel = try NocturneGardenLevel.decode(bytes)
            #expect(back == other && back.encoded() == bytes)
            let cut: Int = random.int(0...(bytes.count - 1))
            #expect(Self.invDecodeRefusal(bytes.prefix(cut)) != nil)
            for budget in [other.budget - 1, other.budget + 1] {
                #expect(Self.invDecodeRefusal(try Self.invEditing(other, key: "budget", value: budget)) != nil)
            }
            for allowance in [other.leakAllowance - 1, other.leakAllowance + 1] {
                let edited: Data = try Self.invEditing(other, key: "leakAllowance", value: allowance)
                #expect(Self.invDecodeRefusal(edited) != nil)
            }
            let walk: Play = try Self.invWalk(other, steps: 30, random: &random)
            let saved: Data = try JSONEncoder().encode(walk.records)
            let records: [NocturneGardenRecord] = try JSONDecoder().decode([NocturneGardenRecord].self, from: saved)
            let restored: Play = try Play.replay(level: back, records: records)
            #expect(restored.records == walk.records && restored.blooms == walk.blooms && restored.moves == walk.moves)
            #expect(restored.fingerprint == (walk.records.last?.next ?? restored.fingerprint))
            #expect((try Self.unpaused(restored)).fingerprint == (try Self.unpaused(walk)).fingerprint)
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: the play holds no visual state; a shadow depends only on the bloom and the sun.
    @Test func testNocturneGardenRendererpurityBoundary() throws {
        let level: NocturneGardenLevel = try Self.sample()
        // Direct example: the kernel types are value types and the play holds only rule state.
        var play: Play = try Self.played(level, [Self.winning[0]])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.blooms[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play.mask).displayStyle == .struct)
        #expect(Mirror(reflecting: level.required).displayStyle == .struct)
        #expect(Mirror(reflecting: NocturneGardenAction.sun(1)).displayStyle == .enum)
        #expect(Mirror(reflecting: NocturneGardenFailure.budget).displayStyle == .enum)
        var labels: [String] = []
        for child in Mirror(reflecting: play).children { labels.append(child.label ?? "?") }
        #expect(labels.sorted() == ["blooms", "elevation", "failure", "failureReason", "level", "mask", "moves",
                                    "records", "redoStack", "stage", "undoStack"])
        // A copy is independent: changing it leaves the original as it was.
        let original: Play = play
        var copy: Play = play
        try copy.apply(.plant(.rose, 11, 1, 1), expecting: copy.fingerprint)
        #expect(play == original && copy.moves == play.moves + 1 && copy.blooms != play.blooms)
        // Reading names and descriptions and decoding the level change nothing.
        let fingerprint: String = play.fingerprint
        var words: [String] = [level.targetDescription()]
        words.append(level.bloomName(0, bloom: play.blooms[0]))
        words.append(level.matchText(shared: play.match.shared, either: play.match.either))
        words.append(level.leakText(play.leak))
        for cell in play.mask.cells.sorted() { words.append(level.cellName(cell) + " " + level.regionName(cell)) }
        for kind in NocturneGardenKind.allCases { words.append(kind.name + " " + kind.shape) }
        #expect(words[1] == "bloom 1: tulip at column 3, row 1, size 1")
        #expect(words[3] == "leak 0 cells, 0 allowed")
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: NocturneGardenLevel = try NocturneGardenLevel.decode(level.encoded())
        let rebuilt: Play = try Play.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // A shadow depends only on the bloom and the sun: the same tulip in a level of another target, forbidden cells,
        // supply, budget, match and tutorial casts the same cells, equal to the bloom's own cells.
        let alien: NocturneGardenLevel = try NocturneGardenLevel(
            id: "alien", seed: 7, difficulty: 5, width: Self.bedWidth, height: Self.bedHeight, target: [0, 1],
            forbidden: [], supply: [.tulip: 1], sizes: [1], elevations: [2], sun: 2, budget: 9,
            required: try NocturneGardenRatio(1, 3), leakAllowance: 4, tutorial: true)
        let elsewhere: Play = try Self.played(alien, [Self.winning[0]])
        #expect(elsewhere.mask.cells == play.mask.cells && play.mask.cells == Self.invCells(Self.tulip, 2))
        // The same state reached by another path (an action and its undo) has the same fingerprint.
        var detour: Play = try Self.playing(level)
        try detour.apply(.sun(3), expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
        play = original
        // The kernel sources import no rendering, UI, GL or Metal framework ("import Metal" also covers its kit, and keeps
        // this file clear of the compliance scan's renderer pattern), read no clock or random source, use no
        // Double or Float and declare no class.
        let forbidden: [String] = ["import UIKit", "import SwiftUI", "import AppKit", "import Metal",
                                   "import QuartzCore", "import OpenGLES", "import GLKit", "import CoreGraphics",
                                   "import SpriteKit", "import SceneKit", "import GameKit", "import CoreMotion",
                                   "import Combine", "import VisualCoreRendering",
                                   "Date()", "Date.now", "CFAbsoluteTimeGetCurrent", "CACurrentMediaTime",
                                   "DispatchTime.now", "ContinuousClock", "SuspendingClock", "systemUptime",
                                   "SystemRandomNumberGenerator", ".random(", "arc4random", "UUID()",
                                   "Double", "Float", "CGFloat"]
        let allowedImports: Set<String> = ["import Foundation", "import VisualCoreMath",
                                          "import VisualCoreSimulation"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 5)
        for source in sources {
            for token in forbidden {
                #expect(!source.text.contains(token), "\(source.name) uses \(token)")
            }
            for line in source.text.split(separator: "\n") {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("import ") {
                    #expect(allowedImports.contains(trimmed), "\(source.name) imports \(trimmed)")
                }
                let isClass: Bool = trimmed.hasPrefix("class ") || trimmed.hasPrefix("final class ")
                    || trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public final class ")
                    || trimmed.hasPrefix("open class ")
                #expect(!isClass, "\(source.name) declares a reference type: \(trimmed)")
            }
        }
        // Seeded neighbours: for seeded walks, each planted bloom and its neighbours (column ± 1, size ± 1) under a
        // neighbouring sun cast the same cells from the bloom, a copy of it and the bloom rebuilt from its values;
        // reading names and replaying the records leave the fingerprint and blooms unchanged.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let other: NocturneGardenLevel = Self.neighbour(index)
            let p: Play = try Self.invWalk(other, steps: 20, random: &random)
            let held: String = p.fingerprint
            let heldBlooms: [NocturneGardenBloom] = p.blooms
            for (i, bloom) in p.blooms.enumerated() {
                _ = other.bloomName(i, bloom: bloom)
                let sign: Int = random.int(0...1) == 0 ? -1 : 1
                let elevation: Int = min(4, max(1, p.elevation + sign))
                let near: NocturneGardenBloom = NocturneGardenBloom(kind: bloom.kind, column: bloom.column + sign,
                                                                    row: bloom.row,
                                                                    size: min(3, max(1, bloom.size - sign)))
                for candidate in [bloom, near] {
                    let twin: NocturneGardenBloom = NocturneGardenBloom(kind: candidate.kind, column: candidate.column,
                                                                        row: candidate.row, size: candidate.size)
                    let one: Set<Int> = candidate.cells(elevation: elevation, width: other.width, height: other.height)
                    let two: Set<Int> = twin.cells(elevation: elevation, width: other.width, height: other.height)
                    let direct: Set<Int> = NocturneGardenBloom.cells(
                        of: NocturneGardenBloom.cast(candidate.kind.outline, column: candidate.column,
                                                     row: candidate.row, size: candidate.size, elevation: elevation),
                        width: other.width, height: other.height)
                    #expect(one == two && one == direct)
                }
            }
            #expect(p.fingerprint == held && p.blooms == heldBlooms)
            if !p.records.isEmpty {
                let otherDecoded: NocturneGardenLevel = try NocturneGardenLevel.decode(other.encoded())
                let again: Play = try Play.replay(level: otherDecoded, records: p.records)
                let resumed: String = (try Self.unpaused(p)).fingerprint
                #expect(again.records == p.records && again.blooms == heldBlooms)
                #expect((try Self.unpaused(again)).fingerprint == resumed)
            }
        }
    }
}
