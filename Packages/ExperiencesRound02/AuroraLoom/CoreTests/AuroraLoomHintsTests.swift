// AuroraLoomHintsTests — feature 305 (R02-G01-05) T-R02G0105-002 (FR-R02G0105-002, 003; SC-R02G0105-002, 003;
// clarifications Q1, Q5; research R1). The solver from given steps equals the solver from the start on the catalog; on
// 2,000 seeded reachable states over all 100 certified levels the level-3 hint's move shortens the remaining shortest
// solution by exactly one, levels 1 and 2 agree with level 3 and `withinMoves` is right; no hint outside `playing`; on 500
// seeded failures the explanation names the kernel's failure exactly. Test data uses explicit types and plain loops (CI
// type-check rule).
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

/// The catalog, generated once per test process.
private let hintsCatalog: Result<[AuroraLoomGenerated], any Error> = Result { try AuroraLoomGenerator.catalog() }

@Suite("Aurora Loom hints and failure explanations")
struct AuroraLoomHintsTests {
    /// A new play of `level` in stage `playing`.
    static func started(_ level: AuroraLoomLevel) throws -> AuroraLoomPlay {
        var play: AuroraLoomPlay = AuroraLoomPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A random legal move (a changed step) for `steps`.
    static func randomMove(_ random: inout SeededRandom, steps: AuroraLoomSteps) -> AuroraLoomMove {
        let ribbon: Int = random.int(0...2)
        let control: AuroraLoomControl = random.int(0...1) == 0 ? .wave : .phase
        let current: Int = control == .wave ? steps.wave[ribbon] : steps.phase[ribbon]
        let step: Int = (current + random.int(1...15)) % 16
        return AuroraLoomMove(ribbon: ribbon, control: control, step: step)
    }

    @Test("solve(_:) equals solve(_:from: startSteps) and the certified solution on all 100 levels")
    func solveFromStartMatches() throws {
        let catalog: [AuroraLoomGenerated] = try hintsCatalog.get()
        #expect(catalog.count == 100)
        for generated in catalog {
            let level: AuroraLoomLevel = generated.level
            let plain: AuroraLoomSolution? = AuroraLoomSolver.solve(level)
            let fromStart: AuroraLoomSolution? = AuroraLoomSolver.solve(level, from: level.startSteps)
            #expect(plain == fromStart)
            #expect(plain == generated.solution)
            // From the winning setting nothing is left to do.
            if let solution = plain {
                let done: AuroraLoomSolution? = AuroraLoomSolver.solve(level, from: solution.setting)
                #expect(done?.shortest == 0)
                #expect(done?.moves.isEmpty == true)
            }
        }
    }

    /// The 2,000 reachable states run as four chunks of 500 (seeds 2,305 … 2,308) so each test stays well under 10 s.
    static let stateChunks: [Int] = [0, 1, 2, 3]

    @Test("2,000 seeded reachable states (4 × 500): the level-3 hint shortens the remaining solution by one",
          arguments: stateChunks)
    func hintsOnReachableStates(chunk: Int) throws {
        let catalog: [AuroraLoomGenerated] = try hintsCatalog.get()
        var random: SeededRandom = SeededRandom(seed: UInt64(2_305 + chunk))
        var checked: Int = 0
        var outsideMoves: Int = 0
        var index: Int = 0
        while checked < 500 {
            let level: AuroraLoomLevel = catalog[index % 100].level
            index += 1
            var play: AuroraLoomPlay = try Self.started(level)
            let count: Int = random.int(0...(level.allowance - 1))
            var made: Int = 0
            while made < count && play.stage == .playing {
                let move: AuroraLoomMove = Self.randomMove(&random, steps: play.steps)
                try play.apply(move, expecting: play.fingerprint)
                made += 1
            }
            guard play.stage == .playing else {
                #expect(AuroraLoomHints.hint(level: 3, play: play) == nil)
                continue
            }
            checked += 1
            guard let three = AuroraLoomHints.hint(level: 3, play: play),
                  let two = AuroraLoomHints.hint(level: 2, play: play),
                  let one = AuroraLoomHints.hint(level: 1, play: play) else {
                Issue.record("no hint on \(level.id) after \(made) moves")
                continue
            }
            #expect(three.remaining > 0)
            #expect(three.withinMoves == (three.remaining <= level.allowance - play.spent))
            if !three.withinMoves {
                outsideMoves += 1
                #expect(three.text == "No solution fits in the moves left; undo a move.")
            }
            #expect(one.level == 1 && two.level == 2 && three.level == 3)
            #expect(one.ribbon == three.ribbon && two.ribbon == three.ribbon)
            #expect(one.control == nil && one.step == nil)
            #expect(two.control == three.control && two.step == nil)
            #expect(one.remaining == three.remaining && two.remaining == three.remaining)
            // Following the level-3 hint leaves a shortest remaining solution exactly one move shorter.
            guard let control = three.control, let step = three.step else {
                Issue.record("level-3 hint without a move")
                continue
            }
            var next: AuroraLoomPlay = play
            try next.apply(AuroraLoomMove(ribbon: three.ribbon, control: control, step: step),
                           expecting: next.fingerprint)
            let after: AuroraLoomSolution? = AuroraLoomSolver.solve(level, from: next.steps)
            #expect(after?.shortest == three.remaining - 1, "level \(level.id) after \(made) moves")
            if three.remaining == 1 { #expect(next.stage == .won) }
            if next.stage == .won { #expect(AuroraLoomHints.hint(level: 1, play: next) == nil) }
        }
        #expect(checked == 500)
        #expect(outsideMoves > 0, "some state should have no solution within the moves left")
    }

    @Test("Hint texts, clamping and no hint outside playing")
    func hintTextsAndStages() throws {
        let catalog: [AuroraLoomGenerated] = try hintsCatalog.get()
        let level: AuroraLoomLevel = catalog[0].level
        let fresh: AuroraLoomPlay = AuroraLoomPlay(level: level)
        #expect(AuroraLoomHints.hint(level: 1, play: fresh) == nil)
        var play: AuroraLoomPlay = try Self.started(level)
        guard let three = AuroraLoomHints.hint(level: 9, play: play),
              let one = AuroraLoomHints.hint(level: -2, play: play),
              let control = three.control, let step = three.step else {
            Issue.record("no hint at the start of level 1")
            return
        }
        #expect(three.level == 3 && one.level == 1)
        #expect(one.text == "Ribbon \(one.ribbon + 1) is furthest from harmony.")
        let two: AuroraLoomHint = AuroraLoomHint(level: 2, ribbon: 1, control: .wave, step: nil, remaining: 2,
                                                 withinMoves: true)
        #expect(two.text == "Change ribbon 2's wave.")
        #expect(three.text == "Set ribbon \(three.ribbon + 1)'s \(control.rawValue) to \(step).")
        try play.handle(.pause)
        #expect(AuroraLoomHints.hint(level: 3, play: play) == nil)
        try play.handle(.resume)
        // Win by the certified moves: no hint once won or showing the result.
        for move in catalog[0].solution.moves {
            try play.apply(move, expecting: play.fingerprint)
        }
        #expect(play.stage == .won)
        #expect(AuroraLoomHints.hint(level: 3, play: play) == nil)
        #expect(AuroraLoomFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(AuroraLoomHints.hint(level: 3, play: play) == nil)
        #expect(AuroraLoomFailureExplanation(play: play) == nil)
    }

    @Test("500 seeded failures: the explanation names the kernel's failure")
    func failureExplanations() throws {
        let catalog: [AuroraLoomGenerated] = try hintsCatalog.get()
        var random: SeededRandom = SeededRandom(seed: 2_305)
        for round in 0..<500 {
            let level: AuroraLoomLevel = catalog[random.int(0...99)].level
            var play: AuroraLoomPlay = try Self.started(level)
            #expect(AuroraLoomFailureExplanation(play: play) == nil)
            while play.stage == .playing {
                var move: AuroraLoomMove = Self.randomMove(&random, steps: play.steps)
                var trial: AuroraLoomSteps = play.steps
                AuroraLoomPlay.set(&trial, ribbon: move.ribbon, control: move.control, step: move.step)
                while AuroraLoomHarmony.wins(trial, level: level) {
                    move = Self.randomMove(&random, steps: play.steps)
                    trial = play.steps
                    AuroraLoomPlay.set(&trial, ribbon: move.ribbon, control: move.control, step: move.step)
                }
                try play.apply(move, expecting: play.fingerprint)
            }
            #expect(play.stage == .failed)
            #expect(AuroraLoomHints.hint(level: 3, play: play) == nil)
            guard let explanation = AuroraLoomFailureExplanation(play: play), let failure = play.failure else {
                Issue.record("no explanation in round \(round)")
                continue
            }
            #expect(explanation.mismatch == failure)
            #expect(explanation.mismatch == AuroraLoomHarmony.worst(play.steps, level: level))
            #expect(explanation.tolerance == level.tolerance)
            let excess: Int = abs(failure.residual) - level.tolerance
            #expect(excess > 0)
            #expect(explanation.hundredthsOutside >= 1)
            #expect(explanation.hundredthsOutside * 4_096 >= excess * 100)
            #expect((explanation.hundredthsOutside - 1) * 4_096 < max(excess * 100, 1))
            let text: String = explanation.text
            #expect(text.hasPrefix("Ribbon \(failure.ribbon + 1) is furthest off at gate \(failure.gate + 1), tick \(failure.tick): 0."))
            #expect(text.hasSuffix(" of a turn outside the tolerance after the last move. Undo or retry."))
            try play.handle(.showResult)
            #expect(AuroraLoomFailureExplanation(play: play) == explanation)
        }
    }

    @Test("Failure text format")
    func failureTextFormat() throws {
        let catalog: [AuroraLoomGenerated] = try hintsCatalog.get()
        let level: AuroraLoomLevel = catalog[0].level
        var play: AuroraLoomPlay = try Self.started(level)
        var random: SeededRandom = SeededRandom(seed: 305)
        while play.stage == .playing {
            let move: AuroraLoomMove = Self.randomMove(&random, steps: play.steps)
            var trial: AuroraLoomSteps = play.steps
            AuroraLoomPlay.set(&trial, ribbon: move.ribbon, control: move.control, step: move.step)
            if AuroraLoomHarmony.wins(trial, level: level) { continue }
            try play.apply(move, expecting: play.fingerprint)
        }
        guard let explanation = AuroraLoomFailureExplanation(play: play) else {
            Issue.record("no explanation")
            return
        }
        let hundredths: Int = explanation.hundredthsOutside
        let cents: String = hundredths % 100 < 10 ? "0\(hundredths % 100)" : "\(hundredths % 100)"
        let expected: String = "Ribbon \(explanation.mismatch.ribbon + 1) is furthest off at gate "
            + "\(explanation.mismatch.gate + 1), tick \(explanation.mismatch.tick): \(hundredths / 100).\(cents) of a turn outside the tolerance after the "
            + "last move. Undo or retry."
        #expect(explanation.text == expected)
    }
}
