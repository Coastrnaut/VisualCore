// AmethystEscapeInvariantTests — feature 361 (R02-G07-01) T-R02G0701-006 (FR-R02G0701-012; the source's invariants
// R2-G07-INV-01 … 05 and INV-07 … 10 on Amethyst Escape). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,366), as the source asks. How each invariant maps onto this kernel (INV-06 content
// and INV-12 novelty belong to R02-G07-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock; a move counter decides. The same actions give the same fingerprints and records
//   however the calls are spaced (pauses, resumes and reads in between); an idle play never fails; the budget fails
//   exactly on the move that reaches it.
// - INV-02 Input budget: the moves spent never exceed the budget; every accepted rotate and advance spends one; refused
//   actions, undo (which gives the move back) and redo (which spends it again) change nothing else; the move that reaches
//   the budget ends the level unless it exits.
// - INV-03 Goal: the level is won only by the advance that carries the pearl out through the exit gap of the outermost
//   shell, never before the first move and never by a rotation; a fixture wins exactly on its last action.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and through
//   replay; an edited record is refused.
// - INV-05 Undo: undo restores the exact prior state and fingerprint; redo the later one; a new action clears redo; a won
//   level is final; a paused play stays paused; a failed play returns to playing.
// - INV-07 Failure honesty: every failure names its true reason — a wedge names the shell and the sector the pearl landed
//   in, the budget only when the moves equal the budget — and a stuck advance is refused by name without change.
// - INV-08 Stability: offsets stay in 0 ..< N, the pearl in a valid pocket and the moves in 0 … budget over seeded walks;
//   N turns of one shell return the crystal; rebuilt levels keep their fingerprint.
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer stored forms are refused; a
//   stored record trace up to a save point replays to the state at that point.
// - INV-10 Renderer purity: the kernel types are value types; reading, describing, copying and decoding change no
//   fingerprint; the kernel sources use no clock, random source or UI framework.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeInvariantTests {
    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_366

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// A hand-made level of N = 6 sectors and two shells, pearl at sector 0. Shell 0 (inner) has one aperture at own
    /// sector 2 and `innerWalls`; shell 1 (outer) has its exit gap at own sector 0 and a blocked wedge at own sector 3.
    /// ``winning`` wins on its sixth move; four advances wedge the pearl in shell 1, sector 3.
    static func sample(budget: Int = 10, innerWalls: [Int] = [], tutorial: Bool = false) throws -> AmethystEscapeLevel {
        let shells: [AmethystEscapeShell] = [AmethystEscapeShell(apertures: [2], walls: innerWalls, blocked: []),
                                             AmethystEscapeShell(apertures: [0], walls: [], blocked: [3])]
        return try AmethystEscapeLevel(id: "sample", seed: seed, difficulty: 1, sectors: 6, shells: shells, start: 0,
                                       budget: budget, tutorial: tutorial)
    }

    /// The sample's winning actions: roll to the aperture, turn shell 2 so the exit gap waits above it, step out, exit.
    static let winning: [AmethystEscapeAction] = [.advance, .advance, .rotate(1, 1), .rotate(1, 1), .advance, .advance]

    /// The sample's wedging actions: roll to the aperture, step out into own sector 2 of shell 2, roll into sector 3.
    static let wedging: [AmethystEscapeAction] = [.advance, .advance, .advance, .advance]

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: AmethystEscapeLevel) throws -> AmethystEscapePlay {
        var play = AmethystEscapePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: AmethystEscapeLevel, _ actions: [AmethystEscapeAction]) throws -> AmethystEscapePlay {
        var play: AmethystEscapePlay = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(AmethystEscapeError) -> Void) -> AmethystEscapeError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// A seeded action for `level`: mostly in range (rotations ±1 of any shell, advances), sometimes out of range.
    static func randomAction(_ level: AmethystEscapeLevel, random: inout AmethystEscapeRandom) -> AmethystEscapeAction {
        let roll: Int = random.int(0...19)
        if roll == 0 { return .rotate(level.shells.count, 1) }
        if roll == 1 { return .rotate(0, random.bool() ? 2 : 0) }
        if roll == 2 { return .rotate(-1, -1) }
        if roll <= 10 { return .advance }
        return .rotate(random.int(0..<level.shells.count), random.bool() ? 1 : -1)
    }

    /// What one seeded step did.
    enum StepKind: Equatable { case undo, redo, pause, resume, action }

    /// One seeded step: its kind, its action (if any), the play before it and its refusal (if any).
    typealias Step = (kind: StepKind, action: AmethystEscapeAction?, before: AmethystEscapePlay,
                      error: AmethystEscapeError?)

    /// One seeded step on `play`: an undo or redo when possible (always an undo from a failed play), a pause or resume,
    /// or an action. Returns the kind, the action (if any), the state before and the refusal (if any). A refused step
    /// must leave the play unchanged.
    static func randomStep(_ play: inout AmethystEscapePlay, random: inout AmethystEscapeRandom) -> Step {
        let before: AmethystEscapePlay = play
        let roll: Int = random.int(0...19)
        if play.stage == .failed && play.canUndo {
            let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 0 && play.canUndo {
            let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 1 && play.canRedo {
            let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in try play.redo() }
            return (.redo, nil, before, error)
        }
        if roll == 2 && play.stage == .playing {
            let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in try play.handle(.pause) }
            return (.pause, nil, before, error)
        }
        if play.stage == .paused {
            let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in try play.handle(.resume) }
            return (.resume, nil, before, error)
        }
        let action: AmethystEscapeAction = randomAction(play.level, random: &random)
        let error: AmethystEscapeError? = refusal { () throws(AmethystEscapeError) in
            try play.apply(action, expecting: play.fingerprint)
        }
        if error != nil && play != before { Issue.record("a refused \(action) changed the play") }
        return (.action, action, before, error)
    }

    /// A seeded walk of at most `steps` steps on a playing play of `level`; a won play ends the walk.
    static func randomPlay(_ level: AmethystEscapeLevel, steps: Int,
                           random: inout AmethystEscapeRandom) throws -> AmethystEscapePlay {
        var play: AmethystEscapePlay = try playing(level)
        for _ in 0..<steps {
            if play.stage == .won { break }
            _ = randomStep(&play, random: &random)
        }
        return play
    }

    /// Whether two plays hold the same kernel state.
    static func sameState(_ a: AmethystEscapePlay, _ b: AmethystEscapePlay) -> Bool {
        a.fingerprint == b.fingerprint && a.crystal == b.crystal && a.moves == b.moves && a.stage == b.stage
            && a.failure == b.failure
    }

    /// The seeded levels of the neighbouring checks: random levels and fixtures, alternately.
    static func neighbour(_ index: Int) -> AmethystEscapeLevel {
        index % 2 == 0 ? AmethystEscapeFixtures.randomLevel(2_366 + index)
            : AmethystEscapeFixtures.fixture(2_366 + index).level
    }

    // MARK: INV-01 Time

    /// INV-01 Time: a move counter decides; call timing does not change fingerprints; an idle play never fails.
    @Test func testAmethystEscapeTimeBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example: the same actions applied straight and with pauses, resumes and reads in between.
        var straight: AmethystEscapePlay = try Self.playing(level)
        var spaced: AmethystEscapePlay = try Self.playing(level)
        for action in Self.winning {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<5 {
                try spaced.handle(.pause)
                _ = spaced.fingerprint
                _ = level.description(ofShell: 1)
                try spaced.handle(.resume)
            }
            try spaced.apply(action, expecting: spaced.fingerprint)
            #expect(spaced.fingerprint == straight.fingerprint)
        }
        #expect(straight.stage == .won && spaced.stage == .won)
        #expect(straight.records == spaced.records)
        // An idle play neither spends moves nor fails, however long it waits or how often it is paused.
        var idle: AmethystEscapePlay = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.moves == 0 && idle.failure == nil && idle.fingerprint == opening)
        // The budget is decided by the move counter: two rotations of a budget-3 level keep playing, the third fails.
        var counted: AmethystEscapePlay = try Self.played(try Self.sample(budget: 3), [.rotate(0, 1), .rotate(0, 1)])
        #expect(counted.stage == .playing && counted.moves == 2)
        try counted.apply(.rotate(0, 1), expecting: counted.fingerprint)
        #expect(counted.stage == .failed && counted.failure == .budget && counted.moves == 3)
        // Seeded neighbours: accepted actions replayed with seeded pauses, resumes and reads in between reach the same
        // fingerprint after every action and the same records.
        var random = AmethystEscapeRandom(seed: Self.seed)
        for index in 0..<40 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var a: AmethystEscapePlay = try Self.playing(other)
            var b: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<40 {
                if a.stage != .playing { break }
                let action: AmethystEscapeAction = Self.randomAction(other, random: &random)
                let error: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let pauses: Int = random.int(0...3)
                for _ in 0..<pauses {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.moves == b.moves)
                if a.stage == .playing { #expect(a.moves < other.budget) }
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: moves never exceed the budget; the move reaching it ends the level unless it exits.
    @Test func testAmethystEscapeInputbudgetBoundary() throws {
        // Direct example: three rotations of a budget-3 level fail on the third; any further action is refused.
        var spent: AmethystEscapePlay = try Self.played(try Self.sample(budget: 3),
                                                        [.rotate(0, 1), .rotate(1, -1), .rotate(0, -1)])
        #expect(spent.moves == 3 && spent.remaining == 0 && spent.stage == .failed && spent.failure == .budget)
        let held: AmethystEscapePlay = spent
        let late: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try spent.apply(.advance, expecting: spent.fingerprint)
        }
        #expect(late == .stage && spent == held)
        // An exit on the move that reaches the budget wins; one move less of budget fails on the fifth move.
        let exact: AmethystEscapePlay = try Self.played(try Self.sample(budget: 6), Self.winning)
        #expect(exact.stage == .won && exact.moves == 6 && exact.remaining == 0 && exact.failure == nil)
        var short: AmethystEscapePlay = try Self.played(try Self.sample(budget: 5), Array(Self.winning.prefix(4)))
        #expect(short.stage == .playing && short.moves == 4 && short.remaining == 1)
        try short.apply(Self.winning[4], expecting: short.fingerprint)
        #expect(short.stage == .failed && short.failure == .budget && short.moves == 5)
        // Refused actions spend nothing; undo gives the move back and redo spends it again.
        var play: AmethystEscapePlay = try Self.playing(try Self.sample(innerWalls: [0]))
        let opening: AmethystEscapePlay = play
        let stuck: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try play.apply(.advance, expecting: play.fingerprint)
        }
        let range: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try play.apply(.rotate(2, 1), expecting: play.fingerprint)
        }
        let stale: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try play.apply(.rotate(0, 1), expecting: Self.staleFingerprint)
        }
        #expect(stuck == .stuck && range == .action("range") && stale == .stale)
        #expect(play == opening && play.moves == 0 && play.remaining == 10)
        try play.apply(.rotate(1, 1), expecting: play.fingerprint)
        #expect(play.moves == 1 && play.remaining == 9)
        try play.undo()
        #expect(play.moves == 0 && play.remaining == 10)
        try play.redo()
        #expect(play.moves == 1 && play.remaining == 9)
        // Seeded neighbours: over seeded walks the moves stay within the budget, the remaining moves agree, an accepted
        // action spends exactly one move, and a play that reached the budget is decided.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 1)
        for index in 0..<60 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var walk: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<80 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                #expect(walk.moves >= 0 && walk.moves <= other.budget)
                #expect(walk.remaining == other.budget - walk.moves)
                if step.kind == .action && step.error == nil {
                    #expect(walk.moves == step.before.moves + 1)
                    let reached: Bool = walk.moves == other.budget
                    if reached { #expect(walk.stage == .won || walk.stage == .failed) }
                    if reached && step.action == .advance
                        && step.before.crystal.transition(level: other) == .exited {
                        #expect(walk.stage == .won)
                    }
                }
                if step.kind == .pause || step.kind == .resume { #expect(walk.moves == step.before.moves) }
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won only by the advance out through the outermost shell's exit gap, never before the first move.
    @Test func testAmethystEscapeGoalBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example: a fresh play is not won; every prefix of the winning actions keeps playing; the last wins.
        var play: AmethystEscapePlay = try Self.playing(level)
        #expect(play.stage == .playing && play.moves == 0)
        for (index, action) in Self.winning.enumerated() {
            let transition: AmethystEscapeTransition = play.crystal.transition(level: level)
            try play.apply(action, expecting: play.fingerprint)
            let last: Bool = index == Self.winning.count - 1
            #expect((play.stage == .won) == last)
            if last {
                #expect(action == .advance && transition == .exited)
                #expect(play.crystal.pearl.shell == level.outermost)
                #expect(play.crystal.ownSector(play.crystal.pearl, level: level) == level.exitGap)
            }
        }
        // The exit gap must be lined up: without the two turns the pearl arrives in own sector 2 and does not exit.
        let unaligned: AmethystEscapePlay = try Self.played(level, [.advance, .advance, .advance])
        #expect(unaligned.stage == .playing && unaligned.crystal.pearl == AmethystEscapePocket(shell: 1, sector: 2))
        // A won level is final.
        var won: AmethystEscapePlay = play
        let undo: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in try won.undo() }
        let more: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try won.apply(.rotate(0, 1), expecting: won.fingerprint)
        }
        #expect(undo == .stage && more == .stage && won == play)
        try won.handle(.showResult)
        #expect(won.stage == .result)
        // Seeded neighbours: every fixture wins exactly on its last action and on no earlier one; replacing that last
        // advance with a rotation does not win; in seeded walks a play turns won exactly when an advance exits.
        for index in 0..<40 {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(2_366 + index)
            var fixed: AmethystEscapePlay = try Self.playing(fixture.level)
            #expect(fixed.stage == .playing)
            for (step, action) in fixture.actions.enumerated() {
                try fixed.apply(action, expecting: fixed.fingerprint)
                #expect((fixed.stage == .won) == (step == fixture.actions.count - 1))
            }
            var neighbour: [AmethystEscapeAction] = fixture.actions
            neighbour[neighbour.count - 1] = .rotate(0, 1)
            let missed: AmethystEscapePlay = try Self.played(fixture.level, neighbour)
            #expect(missed.stage != .won)
        }
        var random = AmethystEscapeRandom(seed: Self.seed &+ 2)
        for index in 0..<60 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var walk: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<80 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                guard step.kind == .action, step.error == nil, let action = step.action else {
                    #expect(walk.stage != .won)
                    continue
                }
                let exits: Bool = action == .advance && step.before.crystal.transition(level: other) == .exited
                #expect((walk.stage == .won) == exits)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records, fingerprints and outcome; replay reproduces them.
    @Test func testAmethystEscapeRepeatabilityBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example: two independent runs and a replay agree; an edited record is refused.
        let first: AmethystEscapePlay = try Self.played(level, Self.winning)
        let second: AmethystEscapePlay = try Self.played(try Self.sample(), Self.winning)
        #expect(first == second && first.records == second.records && first.fingerprint == second.fingerprint)
        let replayed: AmethystEscapePlay = try AmethystEscapePlay.replay(level: level, records: first.records)
        #expect(Self.sameState(replayed, first) && replayed.records == first.records)
        var edited: [AmethystEscapeRecord] = first.records
        let original: AmethystEscapeRecord = edited[2]
        edited[2] = AmethystEscapeRecord(schema: original.schema, seed: original.seed, move: original.move,
                                         kind: original.kind, action: .rotate(1, -1), previous: original.previous,
                                         next: original.next)
        let refused: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            _ = try AmethystEscapePlay.replay(level: level, records: edited)
        }
        #expect(refused != nil)
        var forged: [AmethystEscapeRecord] = first.records
        forged[0] = AmethystEscapeRecord(schema: original.schema, seed: original.seed, move: forged[0].move,
                                         kind: forged[0].kind, action: forged[0].action, previous: forged[0].previous,
                                         next: Self.staleFingerprint)
        let forgedError: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            _ = try AmethystEscapePlay.replay(level: level, records: forged)
        }
        #expect(forgedError == .malformed("record 0"))
        // Seeded neighbours: two runs of the same seeded walk agree, and the replay of its records reproduces it.
        for index in 0..<40 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var r1 = AmethystEscapeRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            var r2 = AmethystEscapeRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            let a: AmethystEscapePlay = try Self.randomPlay(other, steps: 60, random: &r1)
            let b: AmethystEscapePlay = try Self.randomPlay(other, steps: 60, random: &r2)
            #expect(a == b && a.records == b.records)
            let again: AmethystEscapePlay = try AmethystEscapePlay.replay(level: other, records: a.records)
            #expect(again.records == a.records && again.crystal == a.crystal && again.moves == a.moves)
            #expect(again.failure == a.failure)
            for record in a.records where record.kind == .rotate || record.kind == .advance {
                #expect(record.previous != record.next && record.schema == AmethystEscapePlay.schema)
                #expect(record.seed == other.seed)
            }
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo and redo restore exact states; won is final; paused stays paused; failed returns to playing.
    @Test func testAmethystEscapeUndoBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example.
        var play: AmethystEscapePlay = try Self.playing(level)
        let nothing: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in try play.undo() }
        let nothingLater: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in try play.redo() }
        #expect(nothing == .action("nothing-to-undo") && nothingLater == .action("nothing-to-redo"))
        let opening: AmethystEscapePlay = play
        try play.apply(.rotate(1, 1), expecting: play.fingerprint)
        let turned: AmethystEscapePlay = play
        try play.undo()
        #expect(Self.sameState(play, opening) && play.canRedo)
        try play.redo()
        #expect(Self.sameState(play, turned))
        try play.undo()
        try play.apply(.advance, expecting: play.fingerprint)
        #expect(!play.canRedo)
        // A paused play stays paused through undo and redo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.crystal == opening.crystal && play.moves == 0)
        try play.redo()
        #expect(play.stage == .paused && play.moves == 1)
        try play.handle(.resume)
        // A wedged play returns to playing on undo, at the state before the wedging move.
        var wedged: AmethystEscapePlay = try Self.played(level, Array(Self.wedging.prefix(3)))
        let beforeWedge: AmethystEscapePlay = wedged
        try wedged.apply(.advance, expecting: wedged.fingerprint)
        #expect(wedged.stage == .failed)
        try wedged.undo()
        #expect(Self.sameState(wedged, beforeWedge) && wedged.stage == .playing && wedged.failure == nil)
        // A won play is final.
        var won: AmethystEscapePlay = try Self.played(level, Self.winning)
        let finalUndo: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in try won.undo() }
        #expect(finalUndo == .stage && won.stage == .won && !won.canUndo)
        // Seeded neighbours: every accepted action that does not win is undone to the exact earlier state and redone to
        // the exact later one.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 4)
        for index in 0..<50 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var walk: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<50 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                guard step.kind == .action, step.error == nil, walk.stage != .won else { continue }
                let after: AmethystEscapePlay = walk
                try walk.undo()
                #expect(Self.sameState(walk, step.before))
                try walk.redo()
                #expect(Self.sameState(walk, after))
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: every failure names its reason, and a wedge its shell and sector.
    @Test func testAmethystEscapeFailurehonestyBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example: four advances wedge the pearl in shell 2 (outer), sector 4 of 6 (index 1, 3).
        let wedged: AmethystEscapePlay = try Self.played(level, Self.wedging)
        #expect(wedged.stage == .failed && wedged.failure == .wedge(1, 3) && wedged.failure?.code == "wedge")
        #expect(wedged.crystal.pearl == AmethystEscapePocket(shell: 1, sector: 3))
        #expect(level.shellName(1) == "shell 2 (outer)" && level.sectorName(3) == "sector 4 of 6")
        #expect(wedged.moves == 4 && wedged.moves < level.budget)
        // The budget is named only when the moves equal the budget.
        let spent: AmethystEscapePlay = try Self.played(try Self.sample(budget: 2), [.rotate(0, 1), .rotate(0, -1)])
        #expect(spent.failure == .budget && spent.failure?.code == "budget" && spent.moves == 2)
        let early: AmethystEscapePlay = try Self.played(try Self.sample(budget: 3), [.rotate(0, 1), .rotate(0, -1)])
        #expect(early.failure == nil && early.stage == .playing)
        // A wedge on the move that also reaches the budget is named a wedge (wedge before budget).
        let both: AmethystEscapePlay = try Self.played(try Self.sample(budget: 4), Self.wedging)
        #expect(both.failure == .wedge(1, 3))
        // A stuck advance is refused by name and changes nothing; the reason codes are stable.
        var stuck: AmethystEscapePlay = try Self.playing(try Self.sample(innerWalls: [0]))
        let held: AmethystEscapePlay = stuck
        let error: AmethystEscapeError? = Self.refusal { () throws(AmethystEscapeError) in
            try stuck.apply(.advance, expecting: stuck.fingerprint)
        }
        #expect(error == .stuck && error?.reasonCode == "r02-g07.stuck" && stuck == held && stuck.failure == nil)
        #expect(AmethystEscapeError.stage.reasonCode == "r02-g07.stage")
        #expect(AmethystEscapeError.stale.reasonCode == "r02-g07.stale")
        #expect(AmethystEscapeError.action("range").reasonCode == "r02-g07.action")
        // Seeded neighbours: whenever a seeded walk fails, the failure is the true one — a wedge names the shell and
        // sector of the blocked pocket the advance moved into; the budget only when the moves reach it and the move
        // neither exited nor wedged; a stuck refusal only when the transition is stuck.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 5)
        for index in 0..<60 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            var walk: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<80 {
                if walk.stage == .won { break }
                let step: Step = Self.randomStep(&walk, random: &random)
                guard step.kind == .action, let action = step.action else { continue }
                let transition: AmethystEscapeTransition = step.before.crystal.transition(level: other)
                if step.error == .stuck { #expect(action == .advance && transition == .stuck) }
                if action == .advance && transition == .stuck && step.before.stage == .playing {
                    #expect(step.error == .stuck)
                }
                guard step.error == nil, walk.stage == .failed, let failure = walk.failure else { continue }
                switch failure {
                case .wedge(let shell, let sector):
                    guard case .wedge(let pocket) = transition else {
                        Issue.record("a wedge failure without a wedge transition")
                        continue
                    }
                    #expect(action == .advance && shell == pocket.shell)
                    let own: Int = walk.crystal.ownSector(pocket, level: other)
                    #expect(sector == pocket.sector || sector == own)
                    #expect(other.shells[pocket.shell].isBlocked(own))
                case .budget:
                    #expect(walk.moves == other.budget)
                    #expect(transition != .exited || action != .advance)
                    if action == .advance, case .wedge = transition {
                        Issue.record("a wedging advance was named budget")
                    }
                }
            }
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: offsets in 0 ..< N, the pearl in a valid pocket and the moves in range over seeded walks.
    @Test func testAmethystEscapeStabilityBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample(budget: 20)
        // Direct example: a −1 turn from offset 0 wraps to N − 1; N turns of one shell return the crystal.
        let back: AmethystEscapePlay = try Self.played(level, [.rotate(1, -1)])
        #expect(back.crystal.offsets == [0, 5])
        var around: AmethystEscapePlay = try Self.playing(level)
        for _ in 0..<level.sectors { try around.apply(.rotate(0, 1), expecting: around.fingerprint) }
        #expect(around.crystal == AmethystEscapeCrystal(level: level) && around.moves == level.sectors)
        // The pearl rides its own shell: turning it keeps the pearl's own sector.
        let riding: AmethystEscapePlay = try Self.played(level, [.advance, .advance, .advance, .rotate(1, 1)])
        #expect(riding.crystal.pearl == AmethystEscapePocket(shell: 1, sector: 3))
        #expect(riding.crystal.ownSector(riding.crystal.pearl, level: level) == 2)
        // Fingerprints are stable: a rebuilt level and its plays agree; fingerprints are 64 lowercase hex digits.
        let rebuilt: AmethystEscapeLevel = try Self.sample(budget: 20)
        #expect(rebuilt.fingerprint == level.fingerprint)
        #expect(try Self.played(rebuilt, [.rotate(1, -1)]).fingerprint == back.fingerprint)
        let hex: Set<Character> = Set("0123456789abcdef")
        #expect(back.fingerprint.count == 64 && back.fingerprint.allSatisfy(hex.contains))
        // Seeded neighbours: over seeded walks every offset stays in 0 ..< N, the pearl in a valid pocket, the moves in
        // 0 … budget, and a rebuilt level keeps its fingerprint.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 6)
        for index in 0..<60 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            let again: AmethystEscapeLevel = try AmethystEscapeLevel(
                id: other.id, seed: other.seed, difficulty: other.difficulty, sectors: other.sectors,
                shells: other.shells, start: other.start, budget: other.budget, tutorial: other.tutorial)
            #expect(again.fingerprint == other.fingerprint)
            var walk: AmethystEscapePlay = try Self.playing(other)
            for _ in 0..<80 {
                if walk.stage == .won { break }
                _ = Self.randomStep(&walk, random: &random)
                #expect(walk.crystal.offsets.count == other.shells.count)
                for offset in walk.crystal.offsets { #expect(offset >= 0 && offset < other.sectors) }
                #expect(walk.crystal.pearl.shell >= 0 && walk.crystal.pearl.shell < other.shells.count)
                #expect(walk.crystal.pearl.sector >= 0 && walk.crystal.pearl.sector < other.sectors)
                #expect(walk.moves >= 0 && walk.moves <= other.budget)
                if walk.stage == .playing || walk.stage == .paused {
                    let own: Int = walk.crystal.ownSector(walk.crystal.pearl, level: other)
                    #expect(!other.shells[walk.crystal.pearl.shell].isBlocked(own))
                }
            }
        }
    }

    // MARK: INV-09 Save

    /// The stored form of `level` with key `key` set to `value` (fingerprint kept), sorted keys.
    static func editing(_ level: AmethystEscapeLevel, key: String, value: Any) throws -> Data {
        let object: Any = try JSONSerialization.jsonObject(with: level.encoded())
        guard var dictionary = object as? [String: Any] else { throw AmethystEscapeError.malformed("not an object") }
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func decodeRefusal(_ data: Data) -> AmethystEscapeError? {
        do {
            _ = try AmethystEscapeLevel.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// INV-09 Save: the stored level round-trips; damaged forms are refused; stored traces replay to their save point.
    @Test func testAmethystEscapeSaveBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample(tutorial: true)
        // Direct example: byte-for-byte round trip.
        let stored: Data = level.encoded()
        let decoded: AmethystEscapeLevel = try AmethystEscapeLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let viaCodable: AmethystEscapeLevel = try JSONDecoder().decode(AmethystEscapeLevel.self, from: stored)
        #expect(viaCodable == level)
        // Truncated, edited and newer forms are refused.
        #expect(Self.decodeRefusal(stored.prefix(stored.count / 2)) == .malformed("unreadable"))
        #expect(Self.decodeRefusal(Data()) == .malformed("unreadable"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "budget", value: 11)) == .malformed("fingerprint"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "budget", value: 0)) != nil)
        #expect(Self.decodeRefusal(try Self.editing(level, key: "schema", value: 2)) == .newerSchema(2))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "fingerprint", value: Self.staleFingerprint))
                    == .malformed("fingerprint"))
        #expect(Self.decodeRefusal(try Self.editing(level, key: "start", value: 9)) != nil)
        // A stored record trace up to a save point replays to the state at that point.
        var play: AmethystEscapePlay = try Self.playing(level)
        var saves: [AmethystEscapePlay] = []
        for action in Self.winning {
            try play.apply(action, expecting: play.fingerprint)
            saves.append(play)
        }
        let trace: Data = try JSONEncoder().encode(play.records)
        let loaded: [AmethystEscapeRecord] = try JSONDecoder().decode([AmethystEscapeRecord].self, from: trace)
        #expect(loaded == play.records)
        for point in 1...loaded.count {
            let resumed: AmethystEscapePlay = try AmethystEscapePlay.replay(level: decoded,
                                                                            records: Array(loaded.prefix(point)))
            #expect(Self.sameState(resumed, saves[point - 1]))
        }
        // Seeded neighbours: every seeded level round-trips; every truncation and a changed budget are refused; the
        // stored trace of a seeded walk replays to the walk's state.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 7)
        for index in 0..<40 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            let bytes: Data = other.encoded()
            let back: AmethystEscapeLevel = try AmethystEscapeLevel.decode(bytes)
            #expect(back == other && back.encoded() == bytes)
            let cut: Int = random.int(0..<bytes.count)
            #expect(Self.decodeRefusal(bytes.prefix(cut)) != nil)
            let budget: Int = other.budget == 60 ? 59 : other.budget + 1
            #expect(Self.decodeRefusal(try Self.editing(other, key: "budget", value: budget)) == .malformed("fingerprint"))
            let walk: AmethystEscapePlay = try Self.randomPlay(other, steps: 40, random: &random)
            let saved: Data = try JSONEncoder().encode(walk.records)
            let records: [AmethystEscapeRecord] = try JSONDecoder().decode([AmethystEscapeRecord].self, from: saved)
            let restored: AmethystEscapePlay = try AmethystEscapePlay.replay(level: back, records: records)
            #expect(restored.records == walk.records && restored.crystal == walk.crystal && restored.moves == walk.moves)
        }
    }

    // MARK: INV-10 Renderer purity

    /// The Swift sources of the kernel (the Core directory next to this test directory).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: core.path).sorted()
        var sources: [(name: String, text: String)] = []
        for name in names where name.hasSuffix(".swift") {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    /// INV-10 Renderer purity: the crystal state is a value; reading and describing it change no fingerprint.
    @Test func testAmethystEscapeRendererpurityBoundary() throws {
        let level: AmethystEscapeLevel = try Self.sample()
        // Direct example: the kernel types are value types.
        var play: AmethystEscapePlay = try Self.played(level, [.advance, .rotate(1, 1)])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: level.shells[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.crystal).displayStyle == .struct)
        #expect(Mirror(reflecting: play.crystal.pearl).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: AmethystEscapeAction.advance).displayStyle == .enum)
        #expect(Mirror(reflecting: AmethystEscapeFailure.budget).displayStyle == .enum)
        // A copy is independent: changing it leaves the original as it was.
        let original: AmethystEscapePlay = play
        var copy: AmethystEscapePlay = play
        try copy.apply(.rotate(0, 1), expecting: copy.fingerprint)
        #expect(play == original && copy.moves == play.moves + 1 && copy.crystal != play.crystal)
        // Reading descriptions, transitions and names, and decoding the level, change nothing.
        let fingerprint: String = play.fingerprint
        var words: [String] = []
        for shell in level.shells.indices { words.append(level.description(ofShell: shell)) }
        for sector in 0..<level.sectors { words.append(level.sectorName(sector)) }
        words.append(String(describing: play.crystal.transition(level: level)))
        words.append(String(describing: play.stage))
        words.append(String(describing: play.crystal))
        #expect(words[0] == "shell 1 (inner): openings at sectors 3; walls after sectors none; blocked sectors none")
        #expect(words[1] == "shell 2 (outer): exit gap at sector 1; walls after sectors none; blocked sectors 4")
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: AmethystEscapeLevel = try AmethystEscapeLevel.decode(level.encoded())
        #expect(play.crystal.transition(level: decoded) == play.crystal.transition(level: level))
        let rebuilt: AmethystEscapePlay = try AmethystEscapePlay.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // The same state reached by another path (an action and its undo) has the same fingerprint.
        var detour: AmethystEscapePlay = try Self.playing(level)
        try detour.apply(.rotate(1, -1), expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
        play = original
        // The kernel sources import no UI or GPU framework and read no clock or random source.
        let forbidden: [String] = ["import UIKit", "import SwiftUI", "import AppKit", "import Metal", "import QuartzCore",
                                   "import OpenGLES", "import GameKit", "import CoreMotion", "import Combine",
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
        // Seeded neighbours: for seeded walks, copies, a decoded level and reading descriptions and transitions leave the
        // fingerprint and crystal unchanged, and the replay of the records reaches the same fingerprint.
        var random = AmethystEscapeRandom(seed: Self.seed &+ 8)
        for index in 0..<40 {
            let other: AmethystEscapeLevel = Self.neighbour(index)
            let p: AmethystEscapePlay = try Self.randomPlay(other, steps: 40, random: &random)
            let held: String = p.fingerprint
            let heldCrystal: AmethystEscapeCrystal = p.crystal
            var read: Int = 0
            for shell in other.shells.indices { read += other.description(ofShell: shell).count }
            read += String(describing: p.crystal.transition(level: other)).count
            #expect(read > 0)
            let otherDecoded: AmethystEscapeLevel = try AmethystEscapeLevel.decode(other.encoded())
            #expect(p.crystal.transition(level: otherDecoded) == p.crystal.transition(level: other))
            #expect(p.fingerprint == held && p.crystal == heldCrystal)
            let pCopy: AmethystEscapePlay = p
            #expect(pCopy.fingerprint == held)
            if !p.records.isEmpty {
                let again: AmethystEscapePlay = try AmethystEscapePlay.replay(level: otherDecoded, records: p.records)
                #expect(again.records == p.records && again.crystal == heldCrystal)
            }
        }
    }
}
