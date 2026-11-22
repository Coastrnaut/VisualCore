// FacetedForgeInvariantTests — feature 371 (R02-G08-01) T-R02G0801-006 (FR-R02G0801-012; the source's invariants
// R2-G08-INV-01 … 05 and INV-07 … 10 on Faceted Forge). Each named test gives a direct boundary example and a
// seeded check of neighbouring inputs (seed 2,376: the depth ± 1, a neighbouring direction, the piece index ± 1 of a
// crossing cut), as the source asks. How each invariant maps onto this kernel (INV-06 content and INV-12 novelty
// belong to R02-G08-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock; the 0.008333 s (120 Hz) timestep is presentation only. The same cuts give the
//   same fingerprints and records however many frames, pauses and reads lie between them; an idle play never fails;
//   the kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: the cuts spent never exceed the budget; every accepted cut spends one; refused cuts, undo
//   (which gives the cut back) and redo (which spends it again) change nothing else; the cut that reaches the budget is
//   applied and judged, so a win on it wins and anything else fails.
// - INV-03 Goal: the level is won exactly when the multiset of (share, face count) equals the target; in every state
//   the shares sum to one, the volumes to the crystal's and every edge lies on exactly two faces, so a win is only
//   awarded to a conserved, closed set of pieces; never before the first cut.
// - INV-04 Repeatability: the same cuts give the same records, fingerprints and outcome on independent runs and through
//   replay; an edited record is refused.
// - INV-05 Undo: undo restores the exact prior state and fingerprint; redo the later one; a new cut clears redo; a won
//   level is final; a paused play stays paused; a failed play returns to playing.
// - INV-07 Failure honesty: a sliver names the new piece below the limit and the cut index; the budget is named only
//   when the cuts equal the budget and the cut neither won nor made a sliver; a miss is refused by name exactly when
//   the plane does not cross the piece; a failed fixture is undone to the start and its known cuts still win (no hidden
//   solution).
// - INV-08 Stability: over seeded walks every corner is an exact fraction (denominator dividing 12) inside the box
//   −6 … 6, every volume positive, every share in (0, 1], every plane valid, pieces = cuts + 1, cuts in
//   0 … budget.
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer stored forms are refused as a
//   whole; a stored record trace up to a save point replays to the state at that point.
// - INV-10 Renderer purity: the kernel types are value types; the play holds no visual state; reading, naming,
//   copying and decoding change no fingerprint; a cut depends only on the piece, the direction and the depth; the
//   kernel sources use no clock, random source or UI framework.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import FacetedForgeCore

@Suite struct FacetedForgeInvariantTests {
    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_376

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The presentation timestep (120 Hz); no rule reads it.
    static let timestep: Double = 1.0 / 120.0

    /// The cube −a … a on every axis, as sorted half-spaces.
    static func cube(_ a: Int) -> [FacetedForgeHalfSpace] {
        let planes: [FacetedForgeHalfSpace] = FacetedForgeFixtures.slab(0, -a, a) + FacetedForgeFixtures.slab(1, -a, a)
            + FacetedForgeFixtures.slab(2, -a, a)
        return planes.sorted()
    }

    /// `count` target pieces of `share` with six faces (boxes).
    static func boxes(_ count: Int, _ share: FacetedForgeFraction) -> [FacetedForgeTargetPiece] {
        var target: [FacetedForgeTargetPiece] = []
        for _ in 0..<count { target.append(FacetedForgeTargetPiece(share: share, faces: 6)) }
        return target
    }

    /// A hand-made level: the cube −2 … 2 (volume 64), the target four quarter boxes, sliver limit 1/8 by default.
    /// ``winning`` wins it on its third cut.
    static func sample(budget: Int = 4, sliver: FacetedForgeFraction? = nil, target: [FacetedForgeTargetPiece]? = nil,
                       tutorial: Bool = false) throws -> FacetedForgeLevel {
        let limit: FacetedForgeFraction = try sliver ?? FacetedForgeFraction(1, 8)
        let goal: [FacetedForgeTargetPiece] = try target ?? boxes(4, FacetedForgeFraction(1, 4))
        return try FacetedForgeLevel(id: "sample", seed: seed, difficulty: 1, planes: cube(2), budget: budget,
                                     sliver: limit, target: goal, tutorial: tutorial)
    }

    /// A level of the same cube whose target is two half boxes, with sliver limit `sliver` (default 1/3).
    static func halves(budget: Int = 2, sliver: FacetedForgeFraction? = nil) throws -> FacetedForgeLevel {
        let limit: FacetedForgeFraction = try sliver ?? FacetedForgeFraction(1, 3)
        return try sample(budget: budget, sliver: limit, target: try boxes(2, FacetedForgeFraction(1, 2)))
    }

    /// Two half boxes, the target of a two-piece level.
    static func halfBoxes() throws -> [FacetedForgeTargetPiece] { try boxes(2, FacetedForgeFraction(1, 2)) }

    /// The sample's winning cuts: halve along x, halve the lower half along y, then halve the remaining half along y.
    static let winning: [FacetedForgeAction] = [.cut(0, 0, 0), .cut(0, 1, 0), .cut(0, 1, 0)]

    /// Three cuts that do not reach the sample's target: two diagonals, then an off-centre slice of the half prism.
    static let wandering: [FacetedForgeAction] = [.cut(0, 3, 0), .cut(1, 4, 0), .cut(0, 0, -1)]

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: FacetedForgeLevel) throws -> FacetedForgePlay {
        var play: FacetedForgePlay = FacetedForgePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: FacetedForgeLevel, _ actions: [FacetedForgeAction]) throws -> FacetedForgePlay {
        var play: FacetedForgePlay = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(FacetedForgeError) -> Void) -> FacetedForgeError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// A seeded cut for `play`: a crossing cut or one of its neighbours (depth ± 1, a neighbouring direction, the
    /// piece index ± 1), sometimes out of range.
    static func randomAction(_ play: FacetedForgePlay, random: inout FacetedForgeRandom) -> FacetedForgeAction {
        let roll: Int = random.int(0...19)
        if roll == 0 { return .cut(play.pieces.count, 0, 0) }
        if roll == 1 { return .cut(0, FacetedForgeDirection.all.count, 0) }
        if roll == 2 { return .cut(0, random.int(0...12), 25) }
        let (piece, direction, depth): (Int, Int, Int) = FacetedForgeFixtures.randomCut(play.pieces, &random)
        let sign: Int = random.int(0...1) == 0 ? -1 : 1
        let count: Int = play.pieces.count
        switch roll % 4 {
        case 0: return .cut(piece, direction, depth)
        case 1: return .cut(piece, direction, depth + sign)
        case 2: return .cut(piece, (direction + 13 + sign) % 13, depth)
        default: return .cut((piece + count + sign) % count, direction, depth)
        }
    }

    /// What one seeded step did.
    enum StepKind: Equatable { case undo, redo, pause, resume, action }

    /// One seeded step: its kind, its action (if any), the play before it and its refusal (if any).
    typealias Step = (kind: StepKind, action: FacetedForgeAction?, before: FacetedForgePlay, error: FacetedForgeError?)

    /// One seeded step on `play`: an undo or redo when possible (always an undo from a failed play), a pause or resume,
    /// or a cut. A refused step must leave the play unchanged.
    static func randomStep(_ play: inout FacetedForgePlay, random: inout FacetedForgeRandom) -> Step {
        let before: FacetedForgePlay = play
        let roll: Int = random.int(0...19)
        if play.stage == .failed && play.canUndo {
            let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 0 && play.canUndo {
            let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 1 && play.canRedo {
            let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in try play.redo() }
            return (.redo, nil, before, error)
        }
        if roll == 2 && play.stage == .playing {
            let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in try play.handle(.pause) }
            return (.pause, nil, before, error)
        }
        if play.stage == .paused {
            let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in try play.handle(.resume) }
            return (.resume, nil, before, error)
        }
        let action: FacetedForgeAction = randomAction(play, random: &random)
        let error: FacetedForgeError? = refusal { () throws(FacetedForgeError) in
            try play.apply(action, expecting: play.fingerprint)
        }
        if error != nil && play != before { Issue.record("a refused \(action) changed the play") }
        return (.action, action, before, error)
    }

    /// A seeded walk of at most `steps` steps on a playing play of `level`; a won play ends the walk.
    static func randomPlay(_ level: FacetedForgeLevel, steps: Int,
                           random: inout FacetedForgeRandom) throws -> FacetedForgePlay {
        var play: FacetedForgePlay = try playing(level)
        for _ in 0..<steps {
            if play.stage == .won { break }
            _ = randomStep(&play, random: &random)
        }
        return play
    }

    /// Whether two plays hold the same kernel state.
    static func sameState(_ a: FacetedForgePlay, _ b: FacetedForgePlay) -> Bool {
        a.fingerprint == b.fingerprint && a.pieces == b.pieces && a.shares == b.shares && a.cuts == b.cuts
            && a.stage == b.stage && a.failure == b.failure
    }

    /// Whether the pieces of `play` form the level's target multiset of (share, face count), computed independently.
    static func meetsTarget(_ play: FacetedForgePlay) throws -> Bool {
        var made: [FacetedForgeTargetPiece] = []
        for piece in play.pieces {
            let share: FacetedForgeFraction = try piece.volume.dividing(by: play.level.crystal.volume)
            made.append(FacetedForgeTargetPiece(share: share, faces: piece.faceCount))
        }
        return made.sorted() == play.level.target.sorted()
    }

    /// Whether `play` conserves the crystal (shares sum to one, volumes to the crystal's, shares match the volumes) and
    /// every piece is closed (every edge on exactly two faces).
    static func conserved(_ play: FacetedForgePlay) throws -> Bool {
        var shares: FacetedForgeFraction = .zero
        var volume: FacetedForgeFraction = .zero
        for (index, piece) in play.pieces.enumerated() {
            shares = try shares.adding(play.shares[index])
            volume = try volume.adding(piece.volume)
            if try piece.volume.dividing(by: play.level.crystal.volume) != play.shares[index] { return false }
            for incidence in piece.edgeIncidence where incidence != 2 { return false }
        }
        return shares == .one && volume == play.level.crystal.volume && play.pieces.count == play.shares.count
    }

    /// `play` resumed if it is paused (a trace records no trailing pause, so a replay ends unpaused).
    static func unpaused(_ play: FacetedForgePlay) throws -> FacetedForgePlay {
        var copy: FacetedForgePlay = play
        if copy.stage == .paused { try copy.handle(.resume) }
        return copy
    }

    /// The seeded levels of the neighbouring checks: the fixtures from seed 2,376 on.
    static func neighbour(_ index: Int) -> FacetedForgeLevel {
        FacetedForgeFixtures.fixture(seed &+ UInt64(index)).level
    }

    /// The presentation sources of the Core (feature 373, R02-G08-03: the scene snapshot, geometry, shaders, experience
    /// adapter and scenarios), which read the kernel and turn its exact values into Doubles for drawing; they are not
    /// kernel sources, and the renderer-purity tests of feature 373 cover them.
    static let presentationSources: Set<String> = [
        "FacetedForgeSceneSnapshot.swift", "FacetedForgeSceneGeometry.swift", "FacetedForgeShaders.swift",
        "FacetedForgeExperienceCore.swift", "FacetedForgeScenarios.swift",
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
    @Test func testFacetedForgeTimeBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample()
        // Direct example: the winning cuts applied straight and after many presentation frames, pauses and reads.
        var straight: FacetedForgePlay = try Self.playing(level)
        var framed: FacetedForgePlay = try Self.playing(level)
        var clock: Double = 0
        for action in Self.winning {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                clock += Self.timestep
                _ = framed.fingerprint
            }
            try framed.handle(.pause)
            _ = level.targetDescription()
            try framed.handle(.resume)
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.cuts == straight.cuts)
        }
        #expect(clock > 2.9 && straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends cuts nor fails, however long it waits or how often it is paused.
        var idle: FacetedForgePlay = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.cuts == 0 && idle.failure == nil && idle.fingerprint == opening)
        // The kernel holds no clock, time interval or floating-point value; the timestep cannot reach a rule.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "Clock", "0.008", "CFAbsoluteTime"]
        for source in try Self.kernelSources() {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: accepted cuts replayed after seeded numbers of frames, pauses and reads reach the same
        // fingerprint after every cut and the same records.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed)
        for index in 0..<30 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            var a: FacetedForgePlay = try Self.playing(other)
            var b: FacetedForgePlay = try Self.playing(other)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: FacetedForgeAction = Self.randomAction(a, random: &random)
                let error: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.cuts == b.cuts && a.stage == b.stage)
                if a.stage == .playing { #expect(a.cuts < other.budget) }
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: cuts never exceed the budget; the cut reaching it is judged, winning or failing.
    @Test func testFacetedForgeInputbudgetBoundary() throws {
        // Direct example: three non-winning cuts of a budget-3 level fail on the third; any further cut is refused.
        var spent: FacetedForgePlay = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(spent.cuts == 3 && spent.remaining == 0 && spent.stage == .failed && spent.failure == .budget)
        let held: FacetedForgePlay = spent
        let late: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try spent.apply(.cut(0, 0, 0), expecting: spent.fingerprint)
        }
        #expect(late == .stage && spent == held)
        // A win on the cut that reaches the budget wins; with one cut more of budget, one cut remains.
        let exact: FacetedForgePlay = try Self.played(try Self.sample(budget: 3), Self.winning)
        #expect(exact.stage == .won && exact.cuts == 3 && exact.remaining == 0 && exact.failure == nil)
        let spare: FacetedForgePlay = try Self.played(try Self.sample(budget: 4), Self.winning)
        #expect(spare.stage == .won && spare.remaining == 1)
        let short: FacetedForgePlay = try Self.played(try Self.sample(budget: 3), Array(Self.wandering.prefix(2)))
        #expect(short.stage == .playing && short.cuts == 2 && short.remaining == 1)
        // Refused cuts spend nothing; undo gives the cut back and redo spends it again.
        var play: FacetedForgePlay = try Self.playing(try Self.sample())
        let opening: FacetedForgePlay = play
        let miss: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try play.apply(.cut(0, 0, 2), expecting: play.fingerprint)
        }
        let range: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try play.apply(.cut(1, 0, 0), expecting: play.fingerprint)
        }
        let deep: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try play.apply(.cut(0, 0, 25), expecting: play.fingerprint)
        }
        let stale: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try play.apply(.cut(0, 0, 0), expecting: Self.staleFingerprint)
        }
        #expect(miss == .miss && range == .action("range") && deep == .action("range") && stale == .stale)
        #expect(play == opening && play.cuts == 0 && play.remaining == 4)
        try play.apply(.cut(0, 0, 0), expecting: play.fingerprint)
        #expect(play.cuts == 1 && play.remaining == 3)
        try play.undo()
        #expect(play.cuts == 0 && play.remaining == 4)
        try play.redo()
        #expect(play.cuts == 1 && play.remaining == 3)
        // Seeded neighbours: over seeded walks the cuts stay within the budget, the remaining cuts agree, an accepted
        // cut spends exactly one, and a play that reached the budget is decided.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 1)
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            var walk: FacetedForgePlay = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                #expect(walk.cuts >= 0 && walk.cuts <= other.budget)
                #expect(walk.remaining == other.budget - walk.cuts)
                if step.kind == .action && step.error == nil {
                    #expect(walk.cuts == step.before.cuts + 1)
                    if walk.cuts == other.budget { #expect(walk.stage == .won || walk.stage == .failed) }
                }
                if step.kind == .action && step.error != nil { #expect(walk.cuts == step.before.cuts) }
                if step.kind == .pause || step.kind == .resume { #expect(walk.cuts == step.before.cuts) }
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won exactly when the pieces equal the target, and only for a conserved, closed set of pieces.
    @Test func testFacetedForgeGoalBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample()
        // Direct example: a fresh play is not won; every prefix of the winning cuts keeps playing; the last wins.
        var play: FacetedForgePlay = try Self.playing(level)
        let freshMeets: Bool = try Self.meetsTarget(play)
        #expect(play.stage == .playing && play.cuts == 0 && !freshMeets)
        for (index, action) in Self.winning.enumerated() {
            try play.apply(action, expecting: play.fingerprint)
            let last: Bool = index == Self.winning.count - 1
            #expect((play.stage == .won) == last)
            #expect(try Self.conserved(play))
        }
        let quarter: FacetedForgeFraction = try FacetedForgeFraction(1, 4)
        #expect(play.pieces.count == 4 && play.shares == [FacetedForgeFraction](repeating: quarter, count: 4))
        // Equal shares with the wrong face counts do not win: two diagonal halves are prisms of five faces.
        let prisms: FacetedForgePlay = try Self.played(try Self.halves(), [.cut(0, 3, 0)])
        #expect(prisms.shares == [try FacetedForgeFraction(1, 2), try FacetedForgeFraction(1, 2)])
        #expect(prisms.pieces[0].faceCount == 5 && prisms.stage == .playing)
        let boxes: FacetedForgePlay = try Self.played(try Self.halves(), [.cut(0, 0, 0)])
        #expect(boxes.stage == .won && boxes.pieces[0].faceCount == 6)
        // A won level is final.
        var won: FacetedForgePlay = play
        let undo: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in try won.undo() }
        let more: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try won.apply(.cut(0, 2, 0), expecting: won.fingerprint)
        }
        #expect(undo == .stage && more == .stage && won == play)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        // Seeded neighbours: every fixture wins exactly on its last cut; replacing that cut by a neighbour (depth ± 1,
        // a neighbouring direction, piece index ± 1) wins only if the pieces still equal the target; in seeded walks
        // the play is won exactly when the pieces equal the target, and every state is conserved and closed.
        for index in 0..<40 {
            let fixture: FacetedForgeFixture = FacetedForgeFixtures.fixture(Self.seed &+ UInt64(index))
            var fixed: FacetedForgePlay = try Self.playing(fixture.level)
            for (step, action) in fixture.actions.enumerated() {
                try fixed.apply(action, expecting: fixed.fingerprint)
                #expect((fixed.stage == .won) == (step == fixture.actions.count - 1))
            }
            guard case .cut(let piece, let direction, let depth) = fixture.actions[fixture.actions.count - 1] else {
                continue
            }
            let prefix: [FacetedForgeAction] = Array(fixture.actions.dropLast())
            let base: FacetedForgePlay = try Self.played(fixture.level, prefix)
            let count: Int = base.pieces.count
            let neighbours: [FacetedForgeAction] = [.cut(piece, direction, depth - 1),
                                                    .cut(piece, direction, depth + 1),
                                                    .cut(piece, (direction + 1) % 13, depth),
                                                    .cut(piece, (direction + 12) % 13, depth),
                                                    .cut((piece + 1) % count, direction, depth),
                                                    .cut((piece + count - 1) % count, direction, depth)]
            for action in neighbours {
                var near: FacetedForgePlay = base
                let error: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
                    try near.apply(action, expecting: near.fingerprint)
                }
                if error != nil { continue }
                #expect((near.stage == .won) == (try Self.meetsTarget(near)) || near.failure != nil)
                #expect(try Self.conserved(near))
            }
        }
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            var walk: FacetedForgePlay = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                #expect(try Self.conserved(walk))
                if walk.stage == .won { #expect(try Self.meetsTarget(walk) && walk.failure == nil) }
                if walk.stage == .playing || walk.stage == .paused { #expect(!(try Self.meetsTarget(walk))) }
                guard step.kind == .action, step.error == nil else { continue }
                if walk.failure == nil { #expect((walk.stage == .won) == (try Self.meetsTarget(walk))) }
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same cuts give the same records, fingerprints and outcome; replay reproduces them.
    @Test func testFacetedForgeRepeatabilityBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample()
        // Direct example: two independent runs and a replay agree; an edited record is refused.
        let first: FacetedForgePlay = try Self.played(level, Self.winning)
        let second: FacetedForgePlay = try Self.played(try Self.sample(), Self.winning)
        #expect(first == second && first.records == second.records && first.fingerprint == second.fingerprint)
        let replayed: FacetedForgePlay = try FacetedForgePlay.replay(level: level, records: first.records)
        #expect(Self.sameState(replayed, first) && replayed.records == first.records)
        var edited: [FacetedForgeRecord] = first.records
        let original: FacetedForgeRecord = edited[1]
        edited[1] = FacetedForgeRecord(schema: original.schema, seed: original.seed, cut: original.cut,
                                       kind: original.kind, action: .cut(0, 1, 1), previous: original.previous,
                                       next: original.next)
        let refused: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            _ = try FacetedForgePlay.replay(level: level, records: edited)
        }
        #expect(refused != nil)
        var forged: [FacetedForgeRecord] = first.records
        forged[0] = FacetedForgeRecord(schema: forged[0].schema, seed: forged[0].seed, cut: forged[0].cut,
                                       kind: forged[0].kind, action: forged[0].action, previous: forged[0].previous,
                                       next: Self.staleFingerprint)
        let forgedError: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            _ = try FacetedForgePlay.replay(level: level, records: forged)
        }
        #expect(forgedError == .malformed("record 0"))
        // Seeded neighbours: two runs of the same seeded walk agree, and the replay of its records reproduces it.
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            var r1: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            var r2: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            let a: FacetedForgePlay = try Self.randomPlay(other, steps: 30, random: &r1)
            let b: FacetedForgePlay = try Self.randomPlay(other, steps: 30, random: &r2)
            #expect(a == b && a.records == b.records)
            let again: FacetedForgePlay = try FacetedForgePlay.replay(level: other, records: a.records)
            #expect(again.records == a.records && again.pieces == a.pieces && again.cuts == a.cuts)
            let resumed: FacetedForgePlay = try Self.unpaused(a)
            #expect(again.failure == a.failure && again.fingerprint == resumed.fingerprint)
            for record in a.records where record.kind == .cut {
                #expect(record.previous != record.next && record.schema == FacetedForgePlay.schema)
                #expect(record.seed == other.seed)
            }
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo and redo restore exact states; won is final; paused stays paused; failed returns to playing.
    @Test func testFacetedForgeUndoBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample()
        // Direct example.
        var play: FacetedForgePlay = try Self.playing(level)
        let nothing: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in try play.undo() }
        let nothingLater: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in try play.redo() }
        #expect(nothing == .action("nothing-to-undo") && nothingLater == .action("nothing-to-redo"))
        let opening: FacetedForgePlay = play
        try play.apply(.cut(0, 0, 0), expecting: play.fingerprint)
        let halved: FacetedForgePlay = play
        try play.undo()
        #expect(Self.sameState(play, opening) && play.canRedo)
        try play.redo()
        #expect(Self.sameState(play, halved))
        try play.undo()
        try play.apply(.cut(0, 1, 0), expecting: play.fingerprint)
        #expect(!play.canRedo)
        // A paused play stays paused through undo and redo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.pieces == opening.pieces && play.cuts == 0)
        try play.redo()
        #expect(play.stage == .paused && play.cuts == 1)
        try play.handle(.resume)
        // A sliver failure returns to playing on undo, at the state before the failing cut.
        var thin: FacetedForgePlay = try Self.playing(try Self.halves())
        let beforeSliver: FacetedForgePlay = thin
        try thin.apply(.cut(0, 0, 1), expecting: thin.fingerprint)
        #expect(thin.stage == .failed)
        try thin.undo()
        #expect(Self.sameState(thin, beforeSliver) && thin.stage == .playing && thin.failure == nil)
        // A won play is final.
        var won: FacetedForgePlay = try Self.played(level, Self.winning)
        let finalUndo: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in try won.undo() }
        #expect(finalUndo == .stage && won.stage == .won && !won.canUndo)
        // Seeded neighbours: every accepted cut that does not win is undone to the exact earlier state and redone to
        // the exact later one.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 4)
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            var walk: FacetedForgePlay = try Self.playing(other)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                guard step.kind == .action, step.error == nil, walk.stage != .won else { continue }
                let after: FacetedForgePlay = walk
                try walk.undo()
                #expect(Self.sameState(walk, step.before))
                if after.stage == .failed {
                    #expect(walk.stage == .playing)
                    try walk.apply(step.action ?? .cut(0, 0, 0), expecting: walk.fingerprint)
                } else {
                    try walk.redo()
                }
                #expect(Self.sameState(walk, after))
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a sliver names its piece and cut, the budget only when spent; a miss is refused by name.
    @Test func testFacetedForgeFailurehonestyBoundary() throws {
        // Direct example: a cut at x = 1 leaves a quarter, strictly below the limit 1/3: piece 2, cut 1 (index 1, 0).
        let thin: FacetedForgePlay = try Self.played(try Self.halves(), [.cut(0, 0, 1)])
        #expect(thin.stage == .failed && thin.failure == .sliver(1, 0) && thin.failure?.code == "sliver")
        #expect(thin.shares[1] == (try FacetedForgeFraction(1, 4)) && thin.cuts == 1)
        // A share exactly at the limit is allowed.
        let edge: FacetedForgePlay = try Self.played(try Self.halves(sliver: try FacetedForgeFraction(1, 4)),
                                                     [.cut(0, 0, 1)])
        #expect(edge.stage == .playing && edge.failure == nil)
        // A sliver on the cut that also reaches the budget is named a sliver (sliver before budget).
        let both: FacetedForgePlay = try Self.played(try Self.halves(budget: 1), [.cut(0, 0, 1)])
        #expect(both.failure == .sliver(1, 0))
        // The budget is named only when the cuts equal the budget.
        let spent: FacetedForgePlay = try Self.played(try Self.sample(budget: 3), Self.wandering)
        #expect(spent.failure == .budget && spent.failure?.code == "budget" && spent.cuts == 3)
        let early: FacetedForgePlay = try Self.played(try Self.sample(budget: 4), Self.wandering)
        #expect(early.failure == nil && early.stage == .playing)
        // A miss is refused by name and changes nothing; the reason codes are stable.
        var missed: FacetedForgePlay = try Self.playing(try Self.sample())
        let held: FacetedForgePlay = missed
        let error: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try missed.apply(.cut(0, 9, 6), expecting: missed.fingerprint)
        }
        #expect(error == .miss && error?.reasonCode == "r02-g08.miss" && missed == held && missed.failure == nil)
        #expect(FacetedForgeError.stage.reasonCode == "r02-g08.stage")
        #expect(FacetedForgeError.stale.reasonCode == "r02-g08.stale")
        #expect(FacetedForgeError.action("range").reasonCode == "r02-g08.action")
        // Seeded neighbours: every failure in a seeded walk is the true one, every miss is a plane that does not cross,
        // and a failed fixture undone to its start still wins with its known cuts (no hidden solution).
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 5)
        for index in 0..<40 {
            let fixture: FacetedForgeFixture = FacetedForgeFixtures.fixture(Self.seed &+ UInt64(index))
            let other: FacetedForgeLevel = fixture.level
            var walk: FacetedForgePlay = try Self.playing(other)
            var failures: Int = 0
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                guard step.kind == .action, let action = step.action, case .cut(let p, let d, let k) = action else {
                    continue
                }
                let ready: Bool = step.before.stage == .playing
                let inRange: Bool = FacetedForgePlay.inRange(action, pieces: step.before.pieces.count)
                if step.error == .miss {
                    #expect(inRange)
                    if inRange { #expect(!step.before.pieces[p].isCrossed(direction: d, depth: k)) }
                }
                if ready && inRange && !step.before.pieces[p].isCrossed(direction: d, depth: k) {
                    #expect(step.error == .miss)
                }
                if ready && !inRange { #expect(step.error == .action("range")) }
                guard step.error == nil else { continue }
                var newSlivers: [Int] = []
                for (i, piece) in walk.pieces.enumerated()
                where walk.shares[i] < other.sliver && !step.before.pieces.contains(piece) {
                    newSlivers.append(i)
                }
                switch walk.failure {
                case .sliver(let piece, let cut)?:
                    failures += 1
                    #expect(newSlivers.contains(piece) && cut == step.before.cuts)
                case .budget?:
                    failures += 1
                    let meets: Bool = try Self.meetsTarget(walk)
                    #expect(walk.cuts == other.budget && newSlivers.isEmpty && !meets)
                case nil:
                    #expect(newSlivers.isEmpty)
                }
            }
            if walk.stage == .won { continue }
            while walk.canUndo { try walk.undo() }
            if walk.stage == .paused { try walk.handle(.resume) }
            #expect(walk.cuts == 0 && walk.stage == .playing)
            for action in fixture.actions { try walk.apply(action, expecting: walk.fingerprint) }
            #expect(walk.stage == .won, "fixture \(index) after \(failures) failures")
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: exact corners inside the box, positive volumes, bounded shares and indices over seeded walks.
    @Test func testFacetedForgeStabilityBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample(budget: 12, target: try Self.halfBoxes())
        let low: FacetedForgeFraction = try FacetedForgeFraction(-6)
        let high: FacetedForgeFraction = try FacetedForgeFraction(6)
        // Direct example: a corner cut of the cube by x + y + z = 5 leaves a tetrahedron of volume 1/6 with exact
        // corners, inside the box; a cut at the depth limit −24 … 24 or beyond is refused, never wrapped.
        let corner: FacetedForgePlay = try Self.played(level, [.cut(0, 9, 5)])
        let sixth: FacetedForgeFraction = try FacetedForgeFraction(1, 6)
        #expect(corner.pieces.count == 2 && corner.pieces[1].volume == sixth)
        #expect(corner.pieces[1].faceCount == 4 && corner.pieces[0].faceCount == 7)
        var bounded: FacetedForgePlay = try Self.playing(level)
        let far: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try bounded.apply(.cut(0, 9, 24), expecting: bounded.fingerprint)
        }
        let beyond: FacetedForgeError? = Self.refusal { () throws(FacetedForgeError) in
            try bounded.apply(.cut(0, 9, -25), expecting: bounded.fingerprint)
        }
        #expect(far == .miss && beyond == .action("range"))
        // Fingerprints are stable: a rebuilt level and its plays agree; fingerprints are 64 lowercase hex digits.
        let rebuilt: FacetedForgeLevel = try Self.sample(budget: 12, target: try Self.halfBoxes())
        #expect(rebuilt.fingerprint == level.fingerprint)
        #expect(try Self.played(rebuilt, [.cut(0, 9, 5)]).fingerprint == corner.fingerprint)
        let hex: Set<Character> = Set("0123456789abcdef")
        #expect(corner.fingerprint.count == 64 && corner.fingerprint.allSatisfy(hex.contains))
        // Seeded neighbours: over seeded walks every corner is exact and inside the box, every volume positive, every
        // share in (0, 1], every plane valid, the pieces one more than the cuts; a rebuilt level keeps its fingerprint.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 6)
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            let again: FacetedForgeLevel = try FacetedForgeLevel(
                id: other.id, seed: other.seed, difficulty: other.difficulty, planes: other.planes,
                budget: other.budget, sliver: other.sliver, target: other.target, tutorial: other.tutorial)
            #expect(again.fingerprint == other.fingerprint)
            var walk: FacetedForgePlay = try Self.playing(other)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                _ = Self.randomStep(&walk, random: &random)
                #expect(walk.cuts >= 0 && walk.cuts <= other.budget && walk.pieces.count == walk.cuts + 1)
                #expect(walk.shares.count == walk.pieces.count)
                for (i, piece) in walk.pieces.enumerated() {
                    #expect(piece.volume.sign > 0 && walk.shares[i].sign > 0)
                    #expect(!(FacetedForgeFraction.one < walk.shares[i]))
                    #expect(piece.halfSpaces.allSatisfy(\.isValid) && piece.corners.count >= 4)
                    #expect(FacetedForgeLevel.faceCounts.contains(piece.faceCount))
                    for point in piece.corners {
                        for c in [point.x, point.y, point.z] {
                            #expect(12 % c.denominator == 0 && !(c < low) && !(high < c))
                        }
                    }
                }
            }
        }
    }

    // MARK: INV-09 Save

    /// The stored form of `level` with key `key` set to `value` (fingerprint kept), sorted keys.
    static func editing(_ level: FacetedForgeLevel, key: String, value: Any) throws -> Data {
        let object: Any = try JSONSerialization.jsonObject(with: level.encoded())
        guard var dictionary = object as? [String: Any] else { throw FacetedForgeError.malformed("not an object") }
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func decodeRefusal(_ data: Data) -> FacetedForgeError? {
        do {
            _ = try FacetedForgeLevel.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// INV-09 Save: the stored level round-trips; damaged forms are refused whole; stored traces replay to save points.
    @Test func testFacetedForgeSaveBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample(tutorial: true)
        // Direct example: byte-for-byte round trip.
        let stored: Data = level.encoded()
        let decoded: FacetedForgeLevel = try FacetedForgeLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let viaCodable: FacetedForgeLevel = try JSONDecoder().decode(FacetedForgeLevel.self, from: stored)
        #expect(viaCodable == level)
        // Truncated, edited and newer forms are refused as a whole.
        #expect(Self.decodeRefusal(stored.prefix(stored.count / 2)) == .malformed("unreadable"))
        #expect(Self.decodeRefusal(Data()) == .malformed("unreadable"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "budget", value: 5)) == .malformed("fingerprint"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "budget", value: 0)) == .malformed("r02-g08.level"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "sliver", value: "1/2")) == .malformed("r02-g08.level"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "sliver", value: "2/16")) == .malformed("unreadable"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "schema", value: 2)) == .newerSchema(2))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "fingerprint", value: Self.staleFingerprint))
                    == .malformed("fingerprint"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "planes", value: [] as [Any])) != nil)
        // A stored record trace up to a save point replays to the state at that point.
        var play: FacetedForgePlay = try Self.playing(level)
        var saves: [FacetedForgePlay] = []
        for action in Self.winning {
            try play.apply(action, expecting: play.fingerprint)
            saves.append(play)
        }
        let trace: Data = try JSONEncoder().encode(play.records)
        let loaded: [FacetedForgeRecord] = try JSONDecoder().decode([FacetedForgeRecord].self, from: trace)
        #expect(loaded == play.records)
        for point in 1...loaded.count {
            let resumed: FacetedForgePlay = try FacetedForgePlay.replay(level: decoded,
                                                                        records: Array(loaded.prefix(point)))
            #expect(Self.sameState(resumed, saves[point - 1]))
        }
        // Seeded neighbours: every seeded level round-trips; a seeded truncation and a budget ± 1 are refused; the
        // stored trace of a seeded walk replays to the walk's state.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 7)
        for index in 0..<40 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            let bytes: Data = other.encoded()
            let back: FacetedForgeLevel = try FacetedForgeLevel.decode(bytes)
            #expect(back == other && back.encoded() == bytes)
            let cut: Int = random.int(0...(bytes.count - 1))
            #expect(Self.decodeRefusal(bytes.prefix(cut)) != nil)
            for budget in [other.budget - 1, other.budget + 1] {
                #expect(Self.decodeRefusal(try Self.editing(other, key: "budget", value: budget)) != nil)
            }
            let walk: FacetedForgePlay = try Self.randomPlay(other, steps: 30, random: &random)
            let saved: Data = try JSONEncoder().encode(walk.records)
            let records: [FacetedForgeRecord] = try JSONDecoder().decode([FacetedForgeRecord].self, from: saved)
            let restored: FacetedForgePlay = try FacetedForgePlay.replay(level: back, records: records)
            #expect(restored.records == walk.records && restored.pieces == walk.pieces && restored.cuts == walk.cuts)
            #expect(restored.fingerprint == (try Self.unpaused(walk)).fingerprint)
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: the play holds no visual state; a cut depends only on piece, direction and depth.
    @Test func testFacetedForgeRendererpurityBoundary() throws {
        let level: FacetedForgeLevel = try Self.sample()
        // Direct example: the kernel types are value types and the play holds only rule state.
        var play: FacetedForgePlay = try Self.played(level, [.cut(0, 0, 0)])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.pieces[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play.shares[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: FacetedForgeAction.cut(0, 0, 0)).displayStyle == .enum)
        #expect(Mirror(reflecting: FacetedForgeFailure.budget).displayStyle == .enum)
        var labels: [String] = []
        for child in Mirror(reflecting: play).children { labels.append(child.label ?? "?") }
        #expect(labels.sorted() == ["cuts", "failure", "level", "pieces", "records", "redoStack", "shares", "stage",
                                    "undoStack"])
        // A copy is independent: changing it leaves the original as it was.
        let original: FacetedForgePlay = play
        var copy: FacetedForgePlay = play
        try copy.apply(.cut(0, 1, 0), expecting: copy.fingerprint)
        #expect(play == original && copy.cuts == play.cuts + 1 && copy.pieces != play.pieces)
        // Reading names and descriptions and decoding the level change nothing.
        let fingerprint: String = play.fingerprint
        var words: [String] = [level.targetDescription()]
        for (index, piece) in play.pieces.enumerated() {
            words.append(level.pieceName(index, share: play.shares[index], faces: piece.faceCount))
        }
        for direction in FacetedForgeDirection.all { words.append(direction.name) }
        #expect(words[0] == "4 pieces: a quarter of the crystal with 6 faces; a quarter of the crystal with 6 faces; "
                    + "a quarter of the crystal with 6 faces; a quarter of the crystal with 6 faces")
        #expect(words[1] == "piece 1: a half of the crystal, 6 faces")
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: FacetedForgeLevel = try FacetedForgeLevel.decode(level.encoded())
        let rebuilt: FacetedForgePlay = try FacetedForgePlay.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // A cut depends only on the piece, the direction and the depth: the same cube in a level of another budget,
        // sliver, target and tutorial splits into the same pieces, equal to the piece's own cut.
        let alien: FacetedForgeLevel = try Self.halves(budget: 7, sliver: try FacetedForgeFraction(1, 5))
        let elsewhere: FacetedForgePlay = try Self.played(alien, [.cut(0, 0, 0)])
        let halves: (below: FacetedForgePiece, above: FacetedForgePiece) = try level.crystal.cut(direction: 0, depth: 0)
        #expect(elsewhere.pieces == play.pieces)
        #expect(Set(play.pieces) == Set([halves.below, halves.above]))
        // The same state reached by another path (a cut and its undo) has the same fingerprint.
        var detour: FacetedForgePlay = try Self.playing(level)
        try detour.apply(.cut(0, 2, 1), expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
        play = original
        // The kernel sources import no UI or GPU framework, read no clock or random source and declare no class.
        let forbidden: [String] = ["import UIKit", "import SwiftUI", "import AppKit", "import Metal",
                                   "import QuartzCore", "import OpenGLES", "import GameKit", "import CoreMotion",
                                   "import Combine",
                                   "Date()", "Date.now", "CFAbsoluteTimeGetCurrent", "CACurrentMediaTime",
                                   "DispatchTime.now", "ContinuousClock", "SuspendingClock", "systemUptime",
                                   "SystemRandomNumberGenerator", ".random(", "arc4random", "UUID()"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 4)
        for source in sources {
            for token in forbidden {
                #expect(!source.text.contains(token), "\(source.name) uses \(token)")
            }
            for line in source.text.split(separator: "\n") {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                let isClass: Bool = trimmed.hasPrefix("class ") || trimmed.hasPrefix("final class ")
                    || trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public final class ")
                    || trimmed.hasPrefix("open class ")
                #expect(!isClass, "\(source.name) declares a reference type: \(trimmed)")
            }
        }
        // Seeded neighbours: for seeded walks, cutting each piece by a seeded neighbouring plane gives the same halves
        // from the piece, a copy of it and the piece rebuilt from its planes; reading names and replaying the records
        // leave the fingerprint and pieces unchanged.
        var random: FacetedForgeRandom = FacetedForgeRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let other: FacetedForgeLevel = Self.neighbour(index)
            let p: FacetedForgePlay = try Self.randomPlay(other, steps: 20, random: &random)
            let held: String = p.fingerprint
            let heldPieces: [FacetedForgePiece] = p.pieces
            for (i, piece) in p.pieces.enumerated() {
                _ = other.pieceName(i, share: p.shares[i], faces: piece.faceCount)
                let direction: Int = random.int(0...12)
                let depth: Int = random.int(-6...6)
                let rebuiltPiece: FacetedForgePiece = try FacetedForgePiece(halfSpaces: piece.halfSpaces)
                #expect(rebuiltPiece == piece)
                let one: (below: FacetedForgePiece, above: FacetedForgePiece)? = try? piece.cut(direction: direction,
                                                                                               depth: depth)
                let two: (below: FacetedForgePiece, above: FacetedForgePiece)? =
                    try? rebuiltPiece.cut(direction: direction, depth: depth)
                #expect(one?.below == two?.below && one?.above == two?.above)
                #expect((one == nil) == !piece.isCrossed(direction: direction, depth: depth))
            }
            #expect(p.fingerprint == held && p.pieces == heldPieces)
            if !p.records.isEmpty {
                let otherDecoded: FacetedForgeLevel = try FacetedForgeLevel.decode(other.encoded())
                let again: FacetedForgePlay = try FacetedForgePlay.replay(level: otherDecoded, records: p.records)
                let resumed: String = (try Self.unpaused(p)).fingerprint
                #expect(again.records == p.records && again.pieces == heldPieces && again.fingerprint == resumed)
            }
        }
    }
}
