// WaveKnotKeeperHintsTests — feature 325 (R02-G03-05) T-R02G0305-002 (FR-R02G0305-002, 003; SC-R02G0305-002, 003;
// clarifications Q1, Q5; research R1, R4). The solver from a given rope equals the certified search from the start on all
// 100 levels; on 2,000 seeded reachable states over all 100 certified levels the level-3 hint's move shortens the
// remaining shortest solution by exactly one (or wins when one move remained), levels 1 and 2 agree with level 3 and
// `withinMoves` is right; no hint outside `playing`; on 500 seeded failures the explanation equals the formula from the
// kernel's summary exactly. The certified levels are read from the witness files in docs/games/wave-knot-keeper/levels/,
// which WaveKnotKeeperCatalogTests proves equal to the regenerated catalog byte for byte. Seed 2_325 (`SeededRandom`).
// Test data uses explicit types and plain loops (CI type-check rule); no clock.
@testable import WaveKnotKeeperCore
import Foundation
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let hintsWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/wave-knot-keeper/levels", isDirectory: true)

/// The 100 certified witnesses, decoded once per test process, in manifest order.
private let hintsWitnesses: Result<[WaveKnotKeeperWitness], any Error> = Result {
    var result: [WaveKnotKeeperWitness] = []
    for entry in WaveKnotKeeperManifest.entries {
        let name: String = String(WaveKnotKeeperGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintsWitnessDirectory.appendingPathComponent(name))
        result.append(try WaveKnotKeeperWitness.decode(data))
    }
    return result
}

/// A hint-cache key: hints are a function of the rope and the moves spent (for a fixed level).
private struct HintKey: Hashable {
    /// The rope.
    let points: [WaveKnotKeeperPoint]
    /// The moves spent.
    let spent: Int
}

@Suite("Wave Knot Keeper hints and failure explanations")
struct WaveKnotKeeperHintsTests {
    /// The suite's seed.
    static let seed: UInt64 = 2_325

    /// The text of a hint with no short solution.
    static let noShortSolution: String = "No short solution from here; undo or retry"

    /// A new play of `level` in stage `playing`.
    static func started(_ level: WaveKnotKeeperLevel) throws -> WaveKnotKeeperPlay {
        var play: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The certified witnesses of levels `numbers`.
    static func witnesses(_ numbers: ClosedRange<Int>) throws -> [WaveKnotKeeperWitness] {
        let all: [WaveKnotKeeperWitness] = try hintsWitnesses.get()
        #expect(all.count == 100)
        var result: [WaveKnotKeeperWitness] = []
        for witness in all where numbers.contains(witness.number) { result.append(witness) }
        return result
    }

    /// A random legal move on `points` of `level` whose result does not win, or nil after 400 tries.
    static func randomLosingMove(_ random: inout SeededRandom, points: [WaveKnotKeeperPoint],
                                 level: WaveKnotKeeperLevel) -> WaveKnotKeeperMove? {
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        for _ in 0..<400 {
            let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: random.int(0...(points.count - 1)),
                                                              direction: directions[random.int(0...5)])
            if WaveKnotKeeperPlay.refusal(of: move, points: points, level: level) != nil { continue }
            var moved: [WaveKnotKeeperPoint] = points
            moved[move.point] = points[move.point].moved(move.direction)
            if !level.wins(moved) { return move }
        }
        return nil
    }

    /// The expected failure text of `summary` against `target`, computed independently of the explanation.
    static func expectedText(_ summary: WaveKnotKeeperSummary, _ target: WaveKnotKeeperTarget) -> String {
        if summary.degenerate {
            return "Two strands overlap in the view, so the crossings cannot be counted. "
                + "Undo the last move or retry the level."
        }
        return "The rope has " + String(summary.crossings) + " crossings and writhe " + String(summary.writhe)
            + "; the target is " + String(target.crossings) + " and " + String(target.writhe)
            + ". Undo the last move or retry the level."
    }

    // MARK: Certified solutions through the new path

    @Test("solve(_:depth:) keeps the certified solution and equals solve(_:from:depth:) from the start (5 × 20 levels)",
          arguments: [1, 2, 3, 4, 5])
    func certifiedSolutionsUnchanged(band: Int) throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses((band * 20 - 19)...(band * 20))
        #expect(witnesses.count == 20)
        for witness in witnesses {
            let level: WaveKnotKeeperLevel = witness.level
            let plain: WaveKnotKeeperSolution = try #require(WaveKnotKeeperSolver.solve(level))
            #expect(plain.moves == witness.moves, "level \(witness.number)")
            #expect(plain.shortest == witness.difficulty.shortest, "level \(witness.number)")
            #expect(plain.work == witness.difficulty.work, "level \(witness.number)")
            #expect(plain.crossing == witness.crossing, "level \(witness.number)")
            let fromStart: WaveKnotKeeperSolution = try #require(
                WaveKnotKeeperSolver.solve(level, from: level.points))
            #expect(fromStart == plain, "level \(witness.number)")
            // From the winning rope nothing is left to do.
            let done: WaveKnotKeeperSolution? = WaveKnotKeeperSolver.solve(level, from: plain.final)
            #expect(done?.shortest == 0, "level \(witness.number)")
            #expect(done?.moves.isEmpty == true, "level \(witness.number)")
            // One move short of the depth finds nothing.
            #expect(WaveKnotKeeperSolver.solve(level, from: level.points, depth: plain.shortest - 1) == nil)
        }
    }

    // MARK: Hints on reachable states

    /// The 2,000 reachable states run as twenty chunks of 100 (5 levels × 20 states each; seed 2,325 + chunk) so each
    /// case stays short. A state is 0 … 2 random legal non-winning moves from the level's start. A state met again in
    /// the same level (the same rope and moves spent; hints are a function of both) reuses its three hints, and a rope
    /// reached again after a hint reuses its solve: the count of checked states stays 2,000. Each new state costs one
    /// search for its hints and one after following the level-3 hint.
    @Test("2,000 seeded reachable states (20 × 100): the level-3 hint shortens the remaining solution by one",
          arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19])
    func hintsOnReachableStates(chunk: Int) throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses((chunk * 5 + 1)...(chunk * 5 + 5))
        #expect(witnesses.count == 5)
        var random: SeededRandom = SeededRandom(seed: Self.seed + UInt64(chunk))
        var states: Int = 0
        var followed: Int = 0
        for witness in witnesses {
            let level: WaveKnotKeeperLevel = witness.level
            var hints: [HintKey: [WaveKnotKeeperHint]] = [:]
            var shortest: [[WaveKnotKeeperPoint]: Int] = [:]
            for _ in 0..<20 {
                var play: WaveKnotKeeperPlay = try Self.started(level)
                let length: Int = random.int(0...2)
                for _ in 0..<length {
                    guard let move = Self.randomLosingMove(&random, points: play.points, level: level) else { break }
                    try play.apply(move, expecting: play.fingerprint)
                }
                #expect(play.stage == .playing, "level \(witness.number)")
                states += 1
                let before: String = play.fingerprint
                let key: HintKey = HintKey(points: play.points, spent: play.spent)
                let triple: [WaveKnotKeeperHint]
                if let cached = hints[key] {
                    triple = cached
                } else {
                    // One search serves the three levels through the public hint's own derivation; the public
                    // `hint(level:play:)` (the same search plus that derivation) is compared on each level's first
                    // state at all three levels.
                    let solution: WaveKnotKeeperSolution? = WaveKnotKeeperSolver.solve(level, from: play.points)
                    let hint1: WaveKnotKeeperHint = try #require(
                        WaveKnotKeeperHints.hint(level: 1, play: play, solution: solution))
                    let hint2: WaveKnotKeeperHint = try #require(
                        WaveKnotKeeperHints.hint(level: 2, play: play, solution: solution))
                    let hint3: WaveKnotKeeperHint = try #require(
                        WaveKnotKeeperHints.hint(level: 3, play: play, solution: solution))
                    if hints.isEmpty {
                        #expect(WaveKnotKeeperHints.hint(level: 1, play: play) == hint1, "level \(witness.number)")
                        #expect(WaveKnotKeeperHints.hint(level: 2, play: play) == hint2, "level \(witness.number)")
                        #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == hint3, "level \(witness.number)")
                    }
                    triple = [hint1, hint2, hint3]
                    hints[key] = triple
                }
                // Hints never change the play.
                #expect(play.fingerprint == before)
                let hint1: WaveKnotKeeperHint = triple[0]
                let hint2: WaveKnotKeeperHint = triple[1]
                let hint: WaveKnotKeeperHint = triple[2]
                #expect(hint.level == 3 && hint1.level == 1 && hint2.level == 2)
                #expect(hint1.point == hint.point && hint2.point == hint.point, "level \(witness.number)")
                #expect(hint2.axis == hint.axis, "level \(witness.number)")
                #expect(hint1.axis == nil && hint1.direction == nil && hint2.direction == nil)
                #expect(hint1.remaining == hint.remaining && hint2.remaining == hint.remaining)
                #expect(hint1.withinMoves == hint.withinMoves && hint2.withinMoves == hint.withinMoves)
                let left: Int = level.allowance - play.spent
                guard hint.withinMoves else {
                    // No winning rope within depth 3 (remaining 4), or it is longer than the moves left.
                    #expect(hint.remaining > min(WaveKnotKeeperSolver.maximumDepth, left), "level \(witness.number)")
                    #expect(hint.text == Self.noShortSolution)
                    #expect(hint1.text == Self.noShortSolution && hint2.text == Self.noShortSolution)
                    continue
                }
                let direction: WaveKnotKeeperDirection = try #require(hint.direction)
                #expect(hint.axis == WaveKnotKeeperHint.axis(of: direction))
                #expect(hint.remaining >= 1 && hint.remaining <= min(WaveKnotKeeperSolver.maximumDepth, left))
                #expect(hint1.text == "Move point " + String(hint.point + 1))
                #expect(hint.text.hasPrefix("Move point " + String(hint.point + 1) + " "))
                try play.apply(WaveKnotKeeperMove(point: hint.point, direction: direction), expecting: before)
                followed += 1
                if hint.remaining == 1 {
                    #expect(play.stage == .won, "level \(witness.number)")
                    #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
                } else {
                    #expect(play.stage == .playing, "level \(witness.number)")
                    let after: Int
                    if let cached = shortest[play.points] {
                        after = cached
                    } else {
                        let solution: WaveKnotKeeperSolution = try #require(
                            WaveKnotKeeperSolver.solve(level, from: play.points), "level \(witness.number)")
                        after = solution.shortest
                        shortest[play.points] = after
                    }
                    #expect(after == hint.remaining - 1, "level \(witness.number)")
                    // The remaining count was the shortest: nothing wins in one move fewer after the hint either.
                    #expect(WaveKnotKeeperSolver.solve(level, from: play.points, depth: after - 1) == nil)
                }
            }
        }
        #expect(states == 100)
        // Most states are within reach (a start is 1 … 3 moves from a win and a state at most 2 moves from the start).
        #expect(followed >= 50, "followed \(followed) of 100")
    }

    // MARK: No hint outside playing

    @Test("No hint while loading, in the tutorial, paused, won or after the result")
    func noHintOutsidePlaying() throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses(1...100)
        for number in [1, 2, 3, 21, 50, 99] {
            let witness: WaveKnotKeeperWitness = witnesses[number - 1]
            let level: WaveKnotKeeperLevel = witness.level
            var play: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: level)
            #expect(WaveKnotKeeperHints.hint(level: 1, play: play) == nil)
            try play.handle(.begin)
            if level.tutorial {
                #expect(play.stage == .tutorial)
                #expect(WaveKnotKeeperHints.hint(level: 1, play: play) == nil)
                try play.handle(.dismissTutorial)
            }
            #expect(WaveKnotKeeperHints.hint(level: 3, play: play)?.withinMoves == true)
            // Levels outside 1 … 3 are clamped.
            #expect(WaveKnotKeeperHints.hint(level: 0, play: play)?.level == 1)
            #expect(WaveKnotKeeperHints.hint(level: 9, play: play)?.level == 3)
            try play.handle(.pause)
            #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
            try play.handle(.resume)
            for move in witness.moves where play.stage == .playing {
                try play.apply(move, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
            #expect(WaveKnotKeeperFailureExplanation(play: play) == nil)
            try play.handle(.showResult)
            #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
            #expect(WaveKnotKeeperFailureExplanation(play: play) == nil)
        }
    }

    @Test("Hint texts at each level and for every direction")
    func hintTexts() {
        let down: WaveKnotKeeperHint = WaveKnotKeeperHint(level: 3, point: 3, axis: 1, direction: .minusY, remaining: 2,
                                                          withinMoves: true)
        #expect(down.text == "Move point 4 down (\u{2212}y)")
        #expect(WaveKnotKeeperHint(level: 2, point: 3, axis: 1, direction: nil, remaining: 2, withinMoves: true).text
            == "Move point 4 along y")
        #expect(WaveKnotKeeperHint(level: 1, point: 3, axis: nil, direction: nil, remaining: 2, withinMoves: true).text
            == "Move point 4")
        #expect(WaveKnotKeeperHint(level: 3, point: 3, axis: 1, direction: .minusY, remaining: 5, withinMoves: false).text
            == Self.noShortSolution)
        #expect(WaveKnotKeeperHint(level: 1, point: -1, axis: nil, direction: nil, remaining: 4, withinMoves: false).text
            == Self.noShortSolution)
        let names: [String] = ["right (+x)", "left (\u{2212}x)", "up (+y)", "down (\u{2212}y)", "over (+z)",
                               "under (\u{2212}z)"]
        let axes: [Int] = [0, 0, 1, 1, 2, 2]
        let directions: [WaveKnotKeeperDirection] = [.plusX, .minusX, .plusY, .minusY, .plusZ, .minusZ]
        for index in 0..<6 {
            let hint: WaveKnotKeeperHint = WaveKnotKeeperHint(level: 3, point: 0, axis: axes[index],
                                                              direction: directions[index], remaining: 1,
                                                              withinMoves: true)
            #expect(hint.text == "Move point 1 " + names[index])
            #expect(WaveKnotKeeperHint.axis(of: directions[index]) == axes[index])
        }
        #expect(WaveKnotKeeperHint(level: 2, point: 9, axis: 2, direction: nil, remaining: 1, withinMoves: true).text
            == "Move point 10 along z")
    }

    // MARK: Failures

    /// The 500 failures run as five chunks of 100 (20 levels × 5 each; seed 2,325 + 100 + chunk).
    @Test("500 seeded failures (5 × 100) are explained exactly from the kernel's summary", arguments: [0, 1, 2, 3, 4])
    func failuresExplained(chunk: Int) throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses((chunk * 20 + 1)...(chunk * 20 + 20))
        #expect(witnesses.count == 20)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 100 + UInt64(chunk))
        var explained: Int = 0
        for witness in witnesses {
            let level: WaveKnotKeeperLevel = witness.level
            var made: Int = 0
            var attempts: Int = 0
            while made < 5 && attempts < 50 {
                attempts += 1
                var play: WaveKnotKeeperPlay = try Self.started(level)
                #expect(WaveKnotKeeperFailureExplanation(play: play) == nil)
                while play.stage == .playing {
                    guard let move = Self.randomLosingMove(&random, points: play.points, level: level) else { break }
                    try play.apply(move, expecting: play.fingerprint)
                }
                guard play.stage == .failed else { continue }
                made += 1
                #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
                let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(play.points)
                let explanation: WaveKnotKeeperFailureExplanation = try #require(
                    WaveKnotKeeperFailureExplanation(play: play))
                #expect(explanation.summary == summary, "level \(witness.number)")
                #expect(explanation.target == level.target, "level \(witness.number)")
                #expect(explanation.text == Self.expectedText(summary, level.target), "level \(witness.number)")
                try play.handle(.showResult)
                #expect(WaveKnotKeeperFailureExplanation(play: play) == explanation)
                #expect(WaveKnotKeeperHints.hint(level: 3, play: play) == nil)
                explained += 1
            }
            #expect(made == 5, "level \(witness.number)")
        }
        #expect(explained == 100)
    }

    @Test("Failure texts for a counted and a degenerate projection")
    func failureTextFormat() throws {
        let target: WaveKnotKeeperTarget = try WaveKnotKeeperTarget(crossings: 3, writhe: -3)
        #expect(Self.expectedText(WaveKnotKeeperSummary(crossings: 1, writhe: 1, degenerate: false), target)
            == "The rope has 1 crossings and writhe 1; the target is 3 and -3. Undo the last move or retry the level.")
        #expect(Self.expectedText(WaveKnotKeeperSummary(crossings: 0, writhe: 0, degenerate: true), target)
            == "Two strands overlap in the view, so the crossings cannot be counted. Undo the last move or retry the level.")
    }
}
