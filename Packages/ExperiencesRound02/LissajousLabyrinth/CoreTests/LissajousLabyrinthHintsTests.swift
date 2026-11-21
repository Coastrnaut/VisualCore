// LissajousLabyrinthHintsTests — feature 315 (R02-G02-05) T-R02G0205-002 (FR-R02G0205-002, 003; SC-R02G0205-002,
// 003; clarifications Q1, Q5; research R1, R2). The solver from given dials equals the certified search from the start
// on all 100 levels; on 2,000 seeded reachable states over all 100 certified levels the level-3 hint's action shortens
// the remaining shortest solution by exactly one (or wins when one action remained), levels 1 and 2 agree with level 3
// and `withinActions` is right; no hint outside `playing`; on 500 seeded failures the explanation names the kernel's
// failure exactly. The certified levels are read from the witness files in docs/games/lissajous-labyrinth/levels/,
// which LissajousLabyrinthCatalogTests proves equal to the regenerated catalog byte for byte; each level's winning set
// is computed once per test process. Test data uses explicit types and plain loops (CI type-check rule).
@testable import LissajousLabyrinthCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let hintsWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

/// The 100 certified witnesses, decoded once per test process, in manifest order.
private let hintsWitnesses: Result<[LissajousLabyrinthWitness], any Error> = Result {
    var result: [LissajousLabyrinthWitness] = []
    for entry in LissajousLabyrinthManifest.entries {
        let name: String = String(LissajousLabyrinthGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintsWitnessDirectory.appendingPathComponent(name))
        result.append(try LissajousLabyrinthWitness.decode(data))
    }
    return result
}

/// One level's winning set, computed at most once (the slot is locked while it is computed).
private final class HintsWinningSlot: Sendable {
    /// The cached winning set.
    let value: Mutex<[LissajousLabyrinthDials]?> = Mutex(nil)
    /// The cached distance map (see `hintsDistances`).
    let distances: Mutex<[Int]?> = Mutex(nil)
}

/// The winning sets of the 100 levels by index (number − 1).
private let hintsWinningSlots: [HintsWinningSlot] = {
    var slots: [HintsWinningSlot] = []
    for _ in 0..<100 { slots.append(HintsWinningSlot()) }
    return slots
}()

/// The winning set of certified level `number` (1 … 100), computed once.
private func hintsWinning(_ number: Int, _ level: LissajousLabyrinthLevel) -> [LissajousLabyrinthDials] {
    hintsWinningSlots[number - 1].value.withLock { cached in
        if let cached { return cached }
        let settings: [LissajousLabyrinthDials] = LissajousLabyrinthSolver.winningSettings(level).settings
        cached = settings
        return settings
    }
}

/// The fewest actions from every dense dial index to a winning setting of certified level `number` (−1 when none is
/// reachable or the index is illegal): a breadth-first search from the whole winning set over the successor table
/// (moves are reversible, so the graph is undirected), computed once. Independent of the solver's single-source search.
private func hintsDistances(_ number: Int, _ level: LissajousLabyrinthLevel) -> [Int] {
    let winning: [LissajousLabyrinthDials] = hintsWinning(number, level)
    return hintsWinningSlots[number - 1].distances.withLock { cached in
        if let cached { return cached }
        let table: (offsets: [Int32], codes: [Int32]) = LissajousLabyrinthSolver.successors
        var distance: [Int] = [Int](repeating: -1, count: table.offsets.count - 1)
        var frontier: [Int] = []
        for dials in winning {
            let slot: Int = LissajousLabyrinthSolver.index(dials)
            distance[slot] = 0
            frontier.append(slot)
        }
        var depth: Int = 0
        while !frontier.isEmpty {
            depth += 1
            var next: [Int] = []
            for from in frontier {
                for k in Int(table.offsets[from])..<Int(table.offsets[from + 1]) {
                    let to: Int = Int(table.codes[k]) >> 6
                    if distance[to] < 0 {
                        distance[to] = depth
                        next.append(to)
                    }
                }
            }
            frontier = next
        }
        cached = distance
        return distance
    }
}

@Suite("Lissajous Labyrinth hints and failure explanations")
struct LissajousLabyrinthHintsTests {
    /// A new play of `level` in stage `playing`.
    static func started(_ level: LissajousLabyrinthLevel) throws -> LissajousLabyrinthPlay {
        var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A random legal action from `dials` whose result is not in `winning`, or nil after 200 tries.
    static func randomLosingAction(_ random: inout SeededRandom, dials: LissajousLabyrinthDials,
                                   rules: LissajousLabyrinthRules,
                                   winning: Set<LissajousLabyrinthDials>) -> LissajousLabyrinthAction? {
        let moves: [LissajousLabyrinthAction] = rules.moves(in: dials)
        if moves.isEmpty { return nil }
        for _ in 0..<200 {
            let action: LissajousLabyrinthAction = moves[random.int(0...(moves.count - 1))]
            guard let reached = rules.apply(action, to: dials) else { continue }
            if !winning.contains(reached) { return action }
        }
        return nil
    }

    /// The certified witnesses of levels `numbers`.
    static func witnesses(_ numbers: ClosedRange<Int>) throws -> [LissajousLabyrinthWitness] {
        let all: [LissajousLabyrinthWitness] = try hintsWitnesses.get()
        #expect(all.count == 100)
        var result: [LissajousLabyrinthWitness] = []
        for witness in all where numbers.contains(witness.number) { result.append(witness) }
        return result
    }

    /// The expected failure text of `verdict`, computed independently of the explanation.
    static func expectedText(_ verdict: LissajousLabyrinthVerdict) -> String? {
        switch verdict {
        case .contact(let obstacle, let tick):
            let percent: Int = Int((Double(tick) * 100.0 / 4_096.0).rounded(.down))
            return "The path touches obstacle " + String(obstacle + 1) + " at " + String(percent)
                + " % of the lap. Undo the last change or retry the level."
        case .missed(let checkpoint):
            return "Checkpoint " + String(checkpoint + 1)
                + " is not reached in order. Undo the last change or retry the level."
        case .won:
            return nil
        }
    }

    // MARK: Certified solutions through the new path

    @Test("solve(_:) keeps the certified solution and equals solve(_:from:winning:) from the start (5 × 20 levels)",
          arguments: [1, 2, 3, 4, 5])
    func certifiedSolutionsUnchanged(band: Int) throws {
        let witnesses: [LissajousLabyrinthWitness] = try Self.witnesses((band * 20 - 19)...(band * 20))
        #expect(witnesses.count == 20)
        for witness in witnesses {
            let level: LissajousLabyrinthLevel = witness.level
            let winning: [LissajousLabyrinthDials] = hintsWinning(witness.number, level)
            let plain: LissajousLabyrinthSolution = try #require(LissajousLabyrinthSolver.solve(level))
            #expect(plain.actions == witness.actions, "level \(witness.number)")
            #expect(plain.shortest == witness.actions.count, "level \(witness.number)")
            #expect(plain.winningSettings == witness.difficulty.winningSettings, "level \(witness.number)")
            let fromStart: LissajousLabyrinthSolution = try #require(
                LissajousLabyrinthSolver.solve(level, from: level.start, winning: winning))
            #expect(fromStart.actions == plain.actions, "level \(witness.number)")
            #expect(fromStart.setting == plain.setting, "level \(witness.number)")
            #expect(fromStart.winningSettings == plain.winningSettings, "level \(witness.number)")
            #expect(fromStart.work == 0, "level \(witness.number)")
            // From the winning setting nothing is left to do.
            let done: LissajousLabyrinthSolution? = LissajousLabyrinthSolver.solve(level, from: plain.setting,
                                                                                   winning: winning)
            #expect(done?.shortest == 0, "level \(witness.number)")
            #expect(done?.actions.isEmpty == true, "level \(witness.number)")
            // No winning set, no solution.
            #expect(LissajousLabyrinthSolver.solve(level, from: level.start, winning: []) == nil)
        }
    }

    // MARK: Hints on reachable states

    /// The 2,000 reachable states run as ten bands of 200 (10 levels × 20 states each; seed 2,315 + band) so each test
    /// stays well under 10 s.
    @Test("2,000 seeded reachable states (10 × 200): the level-3 hint shortens the remaining solution by one",
          arguments: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    func hintsOnReachableStates(band: Int) throws {
        let witnesses: [LissajousLabyrinthWitness] = try Self.witnesses((band * 10 + 1)...(band * 10 + 10))
        #expect(witnesses.count == 10)
        var random: SeededRandom = SeededRandom(seed: UInt64(2_315 + band))
        var checked: Int = 0
        var outside: Int = 0
        for witness in witnesses {
            let level: LissajousLabyrinthLevel = witness.level
            let winning: [LissajousLabyrinthDials] = hintsWinning(witness.number, level)
            let winningSet: Set<LissajousLabyrinthDials> = Set(winning)
            let distance: [Int] = hintsDistances(witness.number, level)
            let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
            for _ in 0..<20 {
                var play: LissajousLabyrinthPlay = try Self.started(level)
                let length: Int = random.int(0...(level.allowance - 1))
                for _ in 0..<length {
                    guard let action = Self.randomLosingAction(&random, dials: play.dials, rules: rules,
                                                               winning: winningSet) else { break }
                    try play.apply(action, expecting: play.fingerprint)
                }
                #expect(play.stage == .playing, "level \(witness.number)")
                let hint: LissajousLabyrinthHint = try #require(
                    LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning), "level \(witness.number)")
                let value: Int = try #require(hint.value)
                #expect(hint.level == 3)
                #expect(hint.raise == (value > play.dials[hint.dial]))
                #expect(hint.remaining >= 1)
                let here: Int = distance[LissajousLabyrinthSolver.index(play.dials)]
                #expect(hint.remaining == here, "level \(witness.number)")
                let left: Int = level.allowance - play.spent
                #expect(hint.withinActions == (hint.remaining <= left))
                if hint.withinActions {
                    let name: String = LissajousLabyrinthHint.title(hint.dial)
                    #expect(hint.text == "Set " + name + " to " + String(value) + ".")
                } else {
                    outside += 1
                    #expect(hint.text == "No solution fits in the actions left; undo or retry.")
                }
                // Levels 1 and 2 agree with level 3.
                let one: LissajousLabyrinthHint = try #require(
                    LissajousLabyrinthHints.hint(level: 1, play: play, winning: winning))
                #expect(one.level == 1 && one.dial == hint.dial && one.raise == nil && one.value == nil)
                #expect(one.remaining == hint.remaining && one.withinActions == hint.withinActions)
                let two: LissajousLabyrinthHint = try #require(
                    LissajousLabyrinthHints.hint(level: 2, play: play, winning: winning))
                #expect(two.level == 2 && two.dial == hint.dial && two.raise == hint.raise && two.value == nil)
                if hint.withinActions {
                    #expect(one.text == "Turn " + LissajousLabyrinthHint.title(hint.dial) + ".")
                    let verb: String = hint.raise == true ? "Raise " : "Lower "
                    #expect(two.text == verb + LissajousLabyrinthHint.title(hint.dial) + ".")
                }
                // Applying the level-3 action shortens the remaining solution by exactly one.
                let action: LissajousLabyrinthAction = LissajousLabyrinthAction(dial: hint.dial, value: value)
                let reached: LissajousLabyrinthDials = try #require(rules.apply(action, to: play.dials))
                if hint.remaining == 1 {
                    #expect(winningSet.contains(reached), "level \(witness.number)")
                    var next: LissajousLabyrinthPlay = play
                    try next.apply(action, expecting: next.fingerprint)
                    #expect(next.stage == .won, "level \(witness.number)")
                } else {
                    #expect(distance[LissajousLabyrinthSolver.index(reached)] == hint.remaining - 1,
                            "level \(witness.number)")
                }
                checked += 1
            }
        }
        #expect(checked == 200)
        // The share of states beyond the actions left is recorded for the evidence (often zero).
        #expect(outside >= 0)
    }

    @Test("A hint that does not fit in the actions left says so")
    func hintOutsideTheActionsLeft() throws {
        // Walk away from the winning set (each action to the first successor farthest from it, never winning) until the
        // shortest remaining solution exceeds the actions left; the first level where this happens is used.
        var found: Bool = false
        for witness in try Self.witnesses(1...100) where !found {
            let level: LissajousLabyrinthLevel = witness.level
            let winning: [LissajousLabyrinthDials] = hintsWinning(witness.number, level)
            let distance: [Int] = hintsDistances(witness.number, level)
            let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
            var play: LissajousLabyrinthPlay = try Self.started(level)
            while play.stage == .playing && play.spent < level.allowance - 1 {
                if distance[LissajousLabyrinthSolver.index(play.dials)] > level.allowance - play.spent {
                    found = true
                    break
                }
                var best: LissajousLabyrinthAction? = nil
                var bestDistance: Int = -1
                for action in rules.moves(in: play.dials) {
                    guard let reached = rules.apply(action, to: play.dials) else { continue }
                    let d: Int = distance[LissajousLabyrinthSolver.index(reached)]
                    if d > bestDistance {
                        best = action
                        bestDistance = d
                    }
                }
                try play.apply(try #require(best), expecting: play.fingerprint)
            }
            guard found else { continue }
            #expect(play.stage == .playing)
            for hintLevel in 1...3 {
                let hint: LissajousLabyrinthHint = try #require(
                    LissajousLabyrinthHints.hint(level: hintLevel, play: play, winning: winning))
                #expect(!hint.withinActions)
                #expect(hint.remaining == distance[LissajousLabyrinthSolver.index(play.dials)])
                #expect(hint.text == "No solution fits in the actions left; undo or retry.")
            }
        }
        #expect(found)
    }

    @Test("The successor table equals the rules' moves on all 20,736 dial indices")
    func successorsMatchTheRules() throws {
        let table: (offsets: [Int32], codes: [Int32]) = LissajousLabyrinthSolver.successors
        let level: LissajousLabyrinthLevel = try Self.witnesses(1...1)[0].level
        let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
        var mismatches: Int = 0
        var legal: Int = 0
        for slot in 0..<(table.offsets.count - 1) {
            let dials: LissajousLabyrinthDials = LissajousLabyrinthSolver.dials(slot)
            #expect(LissajousLabyrinthSolver.index(dials) == slot)
            if dials.isValid { legal += 1 }
            let moves: [LissajousLabyrinthAction] = rules.moves(in: dials)
            let start: Int = Int(table.offsets[slot]), end: Int = Int(table.offsets[slot + 1])
            if end - start != moves.count {
                mismatches += 1
                continue
            }
            for (k, move) in moves.enumerated() {
                let code: Int = Int(table.codes[start + k])
                let reached: LissajousLabyrinthDials? = rules.apply(move, to: dials)
                let dial: LissajousLabyrinthDial = LissajousLabyrinthDial.allCases[(code & 63) / 16]
                let target: Int = reached.map(LissajousLabyrinthSolver.index) ?? -1
                if dial != move.dial || code & 15 != move.value || target != code >> 6 {
                    mismatches += 1
                }
            }
        }
        #expect(legal == 14_080)
        #expect(mismatches == 0)
    }

    @Test("Hint levels clamp to 1 … 3 and there is no hint outside playing or without a winning set")
    func clampingAndStages() throws {
        let witness: LissajousLabyrinthWitness = try Self.witnesses(2...2)[0]
        let level: LissajousLabyrinthLevel = witness.level
        let winning: [LissajousLabyrinthDials] = hintsWinning(2, level)
        var loading: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: level)
        #expect(LissajousLabyrinthHints.hint(level: 3, play: loading, winning: winning) == nil)
        try loading.handle(.begin)
        if level.tutorial {
            #expect(LissajousLabyrinthHints.hint(level: 3, play: loading, winning: winning) == nil)
            try loading.handle(.dismissTutorial)
        }
        var play: LissajousLabyrinthPlay = loading
        #expect(LissajousLabyrinthHints.hint(level: 0, play: play, winning: winning)?.level == 1)
        #expect(LissajousLabyrinthHints.hint(level: -4, play: play, winning: winning)?.level == 1)
        #expect(LissajousLabyrinthHints.hint(level: 9, play: play, winning: winning)?.level == 3)
        #expect(LissajousLabyrinthHints.hint(level: 3, play: play, winning: []) == nil)
        let first: LissajousLabyrinthHint = try #require(
            LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning))
        #expect(first.dial == witness.actions[0].dial && first.value == witness.actions[0].value)
        #expect(first.remaining == witness.actions.count)
        try play.handle(.pause)
        #expect(LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning) == nil)
        try play.handle(.resume)
        for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning) == nil)
        #expect(LissajousLabyrinthFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning) == nil)
        #expect(LissajousLabyrinthFailureExplanation(play: play) == nil)
    }

    @Test("Dial titles and hint texts")
    func hintTexts() {
        #expect(LissajousLabyrinthHint.title(.frequencyA) == "Frequency A")
        #expect(LissajousLabyrinthHint.title(.frequencyB) == "Frequency B")
        #expect(LissajousLabyrinthHint.title(.phaseA) == "Phase A")
        #expect(LissajousLabyrinthHint.title(.phaseC) == "Phase C")
        let one: LissajousLabyrinthHint = LissajousLabyrinthHint(level: 1, dial: .phaseC, raise: nil, value: nil,
                                                                 remaining: 2, withinActions: true)
        #expect(one.text == "Turn Phase C.")
        let two: LissajousLabyrinthHint = LissajousLabyrinthHint(level: 2, dial: .frequencyB, raise: false, value: nil,
                                                                 remaining: 2, withinActions: true)
        #expect(two.text == "Lower Frequency B.")
        let three: LissajousLabyrinthHint = LissajousLabyrinthHint(level: 3, dial: .frequencyA, raise: true, value: 7,
                                                                   remaining: 2, withinActions: true)
        #expect(three.text == "Set Frequency A to 7.")
        let none: LissajousLabyrinthHint = LissajousLabyrinthHint(level: 3, dial: .phaseA, raise: true, value: 7,
                                                                  remaining: 9, withinActions: false)
        #expect(none.text == "No solution fits in the actions left; undo or retry.")
    }

    // MARK: Failure explanations

    /// The 500 seeded failures run as five bands of 100 (20 levels × 5 failures; seed 2,315 + 10 + band).
    @Test("500 seeded failures (5 × 100): the explanation names the kernel's failure exactly",
          arguments: [1, 2, 3, 4, 5])
    func failuresExplained(band: Int) throws {
        let witnesses: [LissajousLabyrinthWitness] = try Self.witnesses((band * 20 - 19)...(band * 20))
        #expect(witnesses.count == 20)
        var random: SeededRandom = SeededRandom(seed: UInt64(2_315 + 10 + band))
        var explained: Int = 0
        for witness in witnesses {
            let level: LissajousLabyrinthLevel = witness.level
            let winning: [LissajousLabyrinthDials] = hintsWinning(witness.number, level)
            let winningSet: Set<LissajousLabyrinthDials> = Set(winning)
            let rules: LissajousLabyrinthRules = LissajousLabyrinthRules(level: level)
            for _ in 0..<5 {
                var play: LissajousLabyrinthPlay = try Self.started(level)
                while play.stage == .playing {
                    #expect(LissajousLabyrinthFailureExplanation(play: play) == nil)
                    let action: LissajousLabyrinthAction = try #require(
                        Self.randomLosingAction(&random, dials: play.dials, rules: rules, winning: winningSet))
                    try play.apply(action, expecting: play.fingerprint)
                }
                #expect(play.stage == .failed, "level \(witness.number)")
                #expect(play.spent == level.allowance)
                #expect(LissajousLabyrinthHints.hint(level: 3, play: play, winning: winning) == nil)
                let failure: LissajousLabyrinthVerdict = try #require(play.failure)
                #expect(failure == LissajousLabyrinthLap.verdict(play.dials, level: level))
                let explanation: LissajousLabyrinthFailureExplanation = try #require(
                    LissajousLabyrinthFailureExplanation(play: play))
                #expect(explanation.verdict == failure)
                #expect(explanation.text == Self.expectedText(failure), "level \(witness.number)")
                var shown: LissajousLabyrinthPlay = play
                try shown.handle(.showResult)
                #expect(LissajousLabyrinthFailureExplanation(play: shown) == explanation)
                #expect(LissajousLabyrinthHints.hint(level: 3, play: shown, winning: winning) == nil)
                explained += 1
            }
        }
        #expect(explained == 100)
    }

    @Test("Failure text format at the lap's edges")
    func failureTextFormat() {
        let cases: [(LissajousLabyrinthVerdict, String)] = [
            (.contact(obstacle: 0, tick: 0),
             "The path touches obstacle 1 at 0 % of the lap. Undo the last change or retry the level."),
            (.contact(obstacle: 2, tick: 40),
             "The path touches obstacle 3 at 0 % of the lap. Undo the last change or retry the level."),
            (.contact(obstacle: 1, tick: 41),
             "The path touches obstacle 2 at 1 % of the lap. Undo the last change or retry the level."),
            (.contact(obstacle: 4, tick: 4_095),
             "The path touches obstacle 5 at 99 % of the lap. Undo the last change or retry the level."),
            (.missed(checkpoint: 0), "Checkpoint 1 is not reached in order. Undo the last change or retry the level."),
            (.missed(checkpoint: 3), "Checkpoint 4 is not reached in order. Undo the last change or retry the level."),
        ]
        for (verdict, text) in cases {
            #expect(Self.expectedText(verdict) == text)
        }
    }
}
