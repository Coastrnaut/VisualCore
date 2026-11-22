// AmethystEscapeRulesTests — feature 361 (R02-G07-01) T-R02G0701-005 (FR-R02G0701-010). The rules as an R02-F23 puzzle
// contract: the legal move order, terminal positions without moves, refusals, the fixture solutions winning exactly on
// their last move, the budget, and 200 seeded random walks that agree step by step with a direct crystal simulation.
import Testing
import VisualCoreSimulation
@testable import AmethystEscapeCore

@Suite("AmethystEscapeRules")
struct AmethystEscapeRulesTests {
    /// The number of fixture levels checked.
    static let fixtureCount: Int = 40

    /// The rotations every playing position lists, innermost shell first, +1 before −1.
    private static func rotations(_ level: AmethystEscapeLevel) -> [AmethystEscapeAction] {
        var result: [AmethystEscapeAction] = []
        for shell in level.shells.indices {
            result.append(.rotate(shell, 1))
            result.append(.rotate(shell, -1))
        }
        return result
    }

    @Test("rules id and initial position")
    func initialPosition() {
        let level: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(0).level
        let rules = AmethystEscapeRules(level: level)
        #expect(rules.rulesID == "r02-g07-amethyst-escape")
        let start: AmethystEscapeRules.Position = rules.initialState
        #expect(start.crystal == AmethystEscapeCrystal(level: level))
        #expect(start.moves == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
    }

    @Test("legal moves: rotations per shell in order, then advance unless stuck")
    func legalMoveOrder() {
        for index in 0..<60 {
            let level: AmethystEscapeLevel = AmethystEscapeFixtures.randomLevel(index)
            let rules = AmethystEscapeRules(level: level)
            let state: AmethystEscapeRules.Position = rules.initialState
            var expected: [AmethystEscapeAction] = Self.rotations(level)
            let stuck: Bool = state.crystal.transition(level: level) == .stuck
            if !stuck { expected.append(.advance) }
            #expect(rules.moves(in: state) == expected, "level \(index)")
            if stuck {
                #expect(!rules.moves(in: state).contains(.advance))
                #expect(rules.apply(.advance, to: state) == nil)
            }
        }
    }

    @Test("a stuck advance is absent from the legal moves and refused")
    func stuckAdvanceAbsent() {
        // Shell 0: no aperture at own sector 0 and wall 0 present, so the opening advance is stuck.
        let shells: [AmethystEscapeShell] = [AmethystEscapeShell(apertures: [3], walls: [0]),
                                             AmethystEscapeShell(apertures: [0])]
        let level: AmethystEscapeLevel
        do {
            level = try AmethystEscapeLevel(id: "stuck", seed: 1, difficulty: 1, sectors: 6, shells: shells, start: 0,
                                            budget: 10, tutorial: false)
        } catch {
            Issue.record("level is valid: \(error)")
            return
        }
        let rules = AmethystEscapeRules(level: level)
        let state: AmethystEscapeRules.Position = rules.initialState
        #expect(state.crystal.transition(level: level) == .stuck)
        #expect(rules.moves(in: state) == Self.rotations(level))
        #expect(rules.apply(.advance, to: state) == nil)
        // Turning shell 0 by +1 carries the pearl along, so its own sector stays 0: still stuck.
        let turned: AmethystEscapeRules.Position? = rules.apply(.rotate(0, 1), to: state)
        #expect(turned?.moves == 1)
        if let turned {
            #expect(!rules.moves(in: turned).contains(.advance))
        }
    }

    @Test("terminal positions offer no moves and refuse every move")
    func terminalPositions() {
        let level: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(1).level
        let rules = AmethystEscapeRules(level: level)
        let crystal = AmethystEscapeCrystal(level: level)
        let won = AmethystEscapeRules.Position(crystal: crystal, moves: 3, outcome: .won)
        let failed = AmethystEscapeRules.Position(crystal: crystal, moves: 3, outcome: .failed)
        #expect(rules.moves(in: won).isEmpty)
        #expect(rules.moves(in: failed).isEmpty)
        #expect(rules.isSolved(won))
        #expect(!rules.isSolved(failed))
        let candidates: [AmethystEscapeAction] = Self.rotations(level) + [.advance]
        for move in candidates {
            #expect(rules.apply(move, to: won) == nil)
            #expect(rules.apply(move, to: failed) == nil)
        }
    }

    @Test("out-of-range rotations are refused")
    func refusals() {
        let level: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(2).level
        let rules = AmethystEscapeRules(level: level)
        let state: AmethystEscapeRules.Position = rules.initialState
        let bad: [AmethystEscapeAction] = [.rotate(-1, 1), .rotate(level.shells.count, 1), .rotate(0, 0),
                                           .rotate(0, 2), .rotate(0, -2)]
        for move in bad {
            #expect(rules.apply(move, to: state) == nil, "\(move)")
            #expect(!rules.moves(in: state).contains(move))
        }
    }

    @Test("fixture solutions win exactly on their last move through the rules")
    func fixtureSolutions() {
        for index in 0..<Self.fixtureCount {
            let fixture: AmethystEscapeFixture = AmethystEscapeFixtures.fixture(index)
            let rules = AmethystEscapeRules(level: fixture.level)
            var state: AmethystEscapeRules.Position = rules.initialState
            for (step, action) in fixture.actions.enumerated() {
                #expect(rules.moves(in: state).contains(action), "fixture \(index) step \(step)")
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("fixture \(index) step \(step) refused")
                    break
                }
                state = next
                #expect(state.moves == step + 1)
                let last: Bool = step == fixture.actions.count - 1
                #expect(state.outcome == (last ? .won : .playing), "fixture \(index) step \(step)")
            }
            #expect(rules.isSolved(state), "fixture \(index)")
            #expect(rules.moves(in: state).isEmpty)
        }
    }

    @Test("spending the last of the budget without ending the play fails it")
    func budgetExhaustion() {
        let level: AmethystEscapeLevel = AmethystEscapeFixtures.fixture(3).level
        let rules = AmethystEscapeRules(level: level)
        var state: AmethystEscapeRules.Position = rules.initialState
        for step in 1...level.budget {
            guard let next = rules.apply(.rotate(0, 1), to: state) else {
                Issue.record("rotation \(step) refused")
                return
            }
            state = next
            #expect(state.moves == step)
            #expect(state.outcome == (step == level.budget ? .failed : .playing))
        }
        #expect(rules.moves(in: state).isEmpty)
        #expect(!rules.isSolved(state))
    }

    /// The outcome of a direct crystal simulation step.
    private enum DirectOutcome { case playing, won, failed }

    @Test("200 seeded random walks agree with a direct crystal simulation")
    func randomWalks() {
        var random = AmethystEscapeRandom(seed: AmethystEscapeFixtures.seed &+ 361)
        for walk in 0..<200 {
            let level: AmethystEscapeLevel = walk % 2 == 0
                ? AmethystEscapeFixtures.randomLevel(walk)
                : AmethystEscapeFixtures.fixture(walk % Self.fixtureCount).level
            let rules = AmethystEscapeRules(level: level)
            var state: AmethystEscapeRules.Position = rules.initialState
            var crystal = AmethystEscapeCrystal(level: level)
            var spent: Int = 0
            var outcome: DirectOutcome = .playing
            while outcome == .playing {
                let legal: [AmethystEscapeAction] = rules.moves(in: state)
                #expect(!legal.isEmpty, "walk \(walk)")
                if legal.isEmpty { break }
                // Prefer advances so walks reach exits and wedges, not only the budget.
                let advance: Bool = legal.last == .advance && random.int(0...2) != 0
                let move: AmethystEscapeAction = advance ? .advance : legal[random.int(0..<legal.count)]
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) refused a listed move")
                    break
                }
                // Direct simulation.
                spent += 1
                switch move {
                case let .rotate(shell, step):
                    crystal = crystal.rotating(shell: shell, step: step, level: level)
                case .advance:
                    switch crystal.transition(level: level) {
                    case let .moved(pocket): crystal = crystal.placing(pearl: pocket)
                    case .exited: outcome = .won
                    case let .wedge(pocket):
                        crystal = crystal.placing(pearl: pocket)
                        outcome = .failed
                    case .stuck:
                        Issue.record("walk \(walk) advanced while stuck")
                        outcome = .failed
                    }
                }
                if outcome == .playing && spent == level.budget { outcome = .failed }
                state = next
                #expect(state.crystal.offsets == crystal.offsets, "walk \(walk) move \(spent)")
                #expect(state.crystal.pearl == crystal.pearl, "walk \(walk) move \(spent)")
                #expect(state.moves == spent)
                let expected: AmethystEscapeRules.Position.Outcome
                switch outcome {
                case .playing: expected = .playing
                case .won: expected = .won
                case .failed: expected = .failed
                }
                #expect(state.outcome == expected, "walk \(walk) move \(spent)")
            }
            #expect(rules.moves(in: state).isEmpty)
            #expect(state.moves <= level.budget)
        }
    }
}
