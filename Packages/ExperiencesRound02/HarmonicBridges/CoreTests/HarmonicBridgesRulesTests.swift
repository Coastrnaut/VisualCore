// HarmonicBridgesRulesTests — feature 411 (R02-G12-01) T-R02G1201-005 (FR-R02G1201-010). The rules as an R02-F23 puzzle
// contract: the rules id and start position; the exact move order on the hand level (string order, then peg order,
// skipping locked strings and current pegs, then the test); the agreement with `HarmonicBridgesPlay` step by step on 200
// seeded random walks (seed 2_411, fixture levels): at every step the rules' legal moves are exactly the actions the
// play accepts among every tuning of strings −1 … count and pegs 0 … 13 and the test — on the first 20 walks each tried
// with `apply(_:expecting:)` on a copy of the play with its current fingerprint, on the others checked with the play's
// own validation (`check(_:)`, what `apply` runs after its stage and fingerprint checks) plus 8 sampled candidates tried
// with `apply` on a copy (every `apply` attempt hashes the fingerprint; trying every candidate on all 200 walks took
// 7 s in a debug build) — and applying a move gives the same pegs, actions spent and outcome as the play; one
// walk in three follows the fixture's known winning actions while the rules allow them, so both outcomes occur; and
// terminal positions (won, failed by a test, failed by the budget) have no moves and refuse every move. Explicit types,
// plain loops; each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import HarmonicBridgesCore

@Suite("HarmonicBridgesRules")
struct HarmonicBridgesRulesTests {
    typealias Rules = HarmonicBridgesRules
    typealias Position = HarmonicBridgesRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_411
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`; later walks use its `check`.
    static let exhaustiveWalks: Int = 20
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8

    /// A play of `level` started and past its tutorial.
    static func started(_ level: HarmonicBridgesLevel) -> HarmonicBridgesPlay {
        var play = HarmonicBridgesPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    static func accepts(_ play: HarmonicBridgesPlay, _ action: HarmonicBridgesAction, fingerprint: String) -> Bool {
        var copy: HarmonicBridgesPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// Whether `play` (playing) passes its own validation of `action`, without hashing a fingerprint.
    static func passesCheck(_ play: HarmonicBridgesPlay, _ action: HarmonicBridgesAction) -> Bool {
        guard play.stage == .playing else { return false }
        do {
            try play.check(action)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: HarmonicBridgesPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: HarmonicBridgesPlay) -> Position {
        Position(pegs: play.pegs, actionsSpent: play.actionsSpent, outcome: outcome(play))
    }

    /// Every candidate action: the tunings of strings −1 … `count` to pegs 0 … 13, in that order, then the test.
    static func candidates(_ count: Int) -> [HarmonicBridgesAction] {
        var result: [HarmonicBridgesAction] = []
        for string in -1...count {
            for peg in 0...13 { result.append(.tune(string, peg)) }
        }
        result.append(.test)
        return result
    }

    @Test("rules id and initial position")
    func initialPosition() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g12-harmonic-bridges")
        let start: Position = rules.initialState
        #expect(start.pegs == [2, 4, 3, 5])
        #expect(start.actionsSpent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
    }

    @Test("legal moves: string order, then peg order, skipping locked strings and current pegs, then the test")
    func handOrder() throws {
        let rules = Rules(level: HarmonicBridgesFixtures.handLevel(lockedLast: true))
        let moves: [HarmonicBridgesAction] = rules.moves(in: rules.initialState)
        // Strings 0, 1, 2 have 11 pegs each (all but the current one); string 3 is locked.
        #expect(moves.count == 3 * 11 + 1)
        #expect(moves[0] == .tune(0, 1))
        #expect(moves[1] == .tune(0, 3))
        #expect(moves[10] == .tune(0, 12))
        #expect(moves[11] == .tune(1, 1))
        #expect(moves[14] == .tune(1, 5))
        #expect(moves[32] == .tune(2, 12))
        #expect(moves[33] == .test)
        #expect(!moves.contains(.tune(3, 1)))
        #expect(rules.apply(.tune(3, 1), to: rules.initialState) == nil)
        #expect(rules.apply(.tune(0, 2), to: rules.initialState) == nil)
        #expect(rules.apply(.tune(0, 13), to: rules.initialState) == nil)
        #expect(rules.apply(.tune(4, 1), to: rules.initialState) == nil)

        let unlocked = Rules(level: HarmonicBridgesFixtures.handLevel())
        let all: [HarmonicBridgesAction] = unlocked.moves(in: unlocked.initialState)
        #expect(all.count == 4 * 11 + 1)
        #expect(all[33] == .tune(3, 1))
        #expect(all[44] == .test)
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        var checked: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: HarmonicBridgesFixture = HarmonicBridgesFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let level: HarmonicBridgesLevel = fixture.level
            let rules = Rules(level: level)
            var play: HarmonicBridgesPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            var known: [HarmonicBridgesAction] = []
            for action in fixture.winningActions { known.append(.tune(action.string, action.peg)) }
            known.append(.test)
            let candidates: [HarmonicBridgesAction] = Self.candidates(level.strings.count)
            var step: Int = 0
            while state.outcome == .playing {
                let fingerprint: String = play.fingerprint
                let moves: [HarmonicBridgesAction] = rules.moves(in: state)
                let legal: Set<HarmonicBridgesAction> = Set(moves)
                #expect(legal.count == moves.count, "walk \(walk) step \(step) duplicates")
                var accepted: [HarmonicBridgesAction] = []
                for action in candidates {
                    var yes: Bool = false
                    if walk < Self.exhaustiveWalks {
                        yes = Self.accepts(play, action, fingerprint: fingerprint)
                    } else {
                        yes = Self.passesCheck(play, action)
                    }
                    let applied: Bool = rules.apply(action, to: state) != nil
                    #expect(applied == yes, "walk \(walk) step \(step) \(action)")
                    if yes { accepted.append(action) }
                    checked += 1
                }
                if walk >= Self.exhaustiveWalks {
                    for _ in 0..<Self.sampledCandidates {
                        let action: HarmonicBridgesAction = candidates[random.int(0...(candidates.count - 1))]
                        let yes: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(yes == legal.contains(action), "walk \(walk) step \(step) sampled \(action)")
                        checked += 1
                    }
                }
                // The candidates are in the rules' order, so the accepted list equals the moves in order.
                #expect(accepted == moves, "walk \(walk) step \(step)")
                guard !moves.isEmpty else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                var move: HarmonicBridgesAction = moves[random.int(0...(moves.count - 1))]
                if walk % 3 == 0 && step < known.count && legal.contains(known[step]) { move = known[step] }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): rules refused a listed move \(move)")
                    break
                }
                do {
                    try play.apply(move, expecting: fingerprint)
                } catch {
                    Issue.record("walk \(walk) step \(step): play refused a legal move \(move): \(error)")
                    break
                }
                state = next
                let mirrored: Position = Self.position(play)
                #expect(state.pegs == mirrored.pegs, "walk \(walk) step \(step) pegs")
                #expect(state.actionsSpent == mirrored.actionsSpent, "walk \(walk) step \(step) actions")
                #expect(state.outcome == mirrored.outcome, "walk \(walk) step \(step) outcome")
                #expect(rules.isSolved(state) == (play.stage == .won), "walk \(walk) step \(step) solved")
                step += 1
                steps += 1
            }
            #expect(rules.moves(in: state).isEmpty, "walk \(walk) terminal")
            if state.outcome == .won { won += 1 }
            if state.outcome == .failed { failed += 1 }
        }
        #expect(won + failed == Self.walkCount)
        #expect(won > 0)
        #expect(failed > 0)
        #expect(steps >= Self.walkCount)
        #expect(checked > 10_000)
    }

    /// Checks that `state` is terminal: no moves, and every candidate refused.
    static func expectTerminal(_ rules: Rules, _ state: Position, _ label: String) {
        #expect(state.outcome != .playing, "\(label)")
        #expect(rules.moves(in: state).isEmpty, "\(label)")
        let candidates: [HarmonicBridgesAction] = Self.candidates(rules.level.strings.count)
        for action in candidates {
            #expect(rules.apply(action, to: state) == nil, "\(label) \(action)")
        }
    }

    @Test("terminal positions have no moves")
    func terminalPositions() throws {
        let rules = Rules(level: HarmonicBridgesFixtures.handLevel(budget: 2))
        // Won: tune string 3 to peg 1, then test.
        let tuned: Position = try #require(rules.apply(.tune(3, 1), to: rules.initialState))
        #expect(tuned.outcome == .playing)
        #expect(tuned.pegs == [2, 4, 3, 1])
        let won: Position = try #require(rules.apply(.test, to: tuned))
        #expect(won.outcome == .won)
        #expect(won.actionsSpent == 2)
        #expect(rules.isSolved(won))
        Self.expectTerminal(rules, won, "won")
        // Failed by a test: the starting pegs miss the goal in step 1.
        let broken: Position = try #require(rules.apply(.test, to: rules.initialState))
        #expect(broken.outcome == .failed)
        #expect(broken.actionsSpent == 1)
        #expect(!rules.isSolved(broken))
        Self.expectTerminal(rules, broken, "broken")
        // Failed by the budget: two tunings spend the budget of 2.
        let first: Position = try #require(rules.apply(.tune(0, 1), to: rules.initialState))
        let spent: Position = try #require(rules.apply(.tune(0, 2), to: first))
        #expect(spent.outcome == .failed)
        #expect(spent.actionsSpent == 2)
        Self.expectTerminal(rules, spent, "budget")
    }
}
