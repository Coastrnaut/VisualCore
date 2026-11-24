// VoxelOrigamiRulesTests — feature 441 (R02-G15-01) T-R02G1501-005 (FR-R02G1501-010). The rules as an R02-F23 puzzle
// contract: the rules id and start position; the exact move order on a hand level (every hinge that would swing a cube,
// ascending, then −1, +1; a leaf hinge is idle) and its refusals; the agreement with `VoxelOrigamiPlay` step by step on
// 200 seeded random walks (seed 2_441, fixture levels): on the first 20 walks every candidate (turns of hinges
// −1 … n by −2 … 2) is tried with `apply(_:expecting:)` on a copy of the play with its current fingerprint and the
// accepted candidates are exactly the legal moves in order; on the others every legal move and 8 sampled candidates are
// tried; applying the chosen move gives the same turns, actions spent and outcome as the play's stage; one walk in
// three follows the fixture's known winning turns, so wins, collision or sweep failures and budget failures occur;
// terminal positions have no moves and refuse every move; and the fixtures' known turns are legal at every step and
// reach won. Explicit types, plain loops; each test well under 10 s. Modelled on `MoonlitMechanismRulesTests`
// (feature 431).
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite("VoxelOrigamiRules")
struct VoxelOrigamiRulesTests {
    typealias Rules = VoxelOrigamiRules
    typealias Position = VoxelOrigamiRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_441
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`.
    static let exhaustiveWalks: Int = 20
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8

    /// An L of four cubes: 0 at the origin, 1 at +x, 2 at +x +x, 3 above 2; hinge 3 is a leaf (idle).
    static let cubes: [VoxelOrigamiCube] = [
        .root,
        VoxelOrigamiCube(parent: 0, direction: VoxelOrigamiVector(1, 0, 0), startTurn: 0),
        VoxelOrigamiCube(parent: 1, direction: VoxelOrigamiVector(1, 0, 0), startTurn: 0),
        VoxelOrigamiCube(parent: 2, direction: VoxelOrigamiVector(0, 1, 0), startTurn: 0),
    ]

    /// A square target (a 2 × 2 slab) the L cannot reach by hinge turns.
    static let square: [VoxelOrigamiVector] = [VoxelOrigamiVector(0, 0, 0), VoxelOrigamiVector(0, 1, 0),
                                               VoxelOrigamiVector(1, 0, 0), VoxelOrigamiVector(1, 1, 0)]

    /// The hand level: the L, the square target, any orientation, the given budget.
    static func handLevel(budget: Int = 3) throws -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: "hand", seed: 1, difficulty: 1, cubes: cubes, target: square, orientations: .any,
                              budget: budget)
    }

    /// A play of `level` started and past its tutorial.
    static func started(_ level: VoxelOrigamiLevel) -> VoxelOrigamiPlay {
        var play = VoxelOrigamiPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// The play after `action` (tried on a copy), or nil when the play refuses it.
    static func applied(_ play: VoxelOrigamiPlay, _ action: VoxelOrigamiAction,
                        fingerprint: String) -> VoxelOrigamiPlay? {
        var copy: VoxelOrigamiPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return copy
        } catch {
            return nil
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: VoxelOrigamiPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: VoxelOrigamiPlay) -> Position {
        Position(turns: play.turns, actionsSpent: play.actionsSpent, outcome: outcome(play))
    }

    /// Every candidate action of a level with `count` cubes: turns of hinges −1 … `count` by −2 … 2.
    static func candidates(_ count: Int) -> [VoxelOrigamiAction] {
        var result: [VoxelOrigamiAction] = []
        for hinge in -1...count {
            for step in -2...2 { result.append(.turn(hinge, step)) }
        }
        return result
    }

    @Test("rules id and initial position")
    func initialPosition() throws {
        let level: VoxelOrigamiLevel = try Self.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g15-voxel-origami")
        let start: Position = rules.initialState
        #expect(start.turns == [0, 0, 0, 0])
        #expect(start.actionsSpent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 10)
        for (index, fixture) in fixtures.enumerated() {
            let fixtureRules = Rules(level: fixture.level)
            #expect(fixtureRules.initialState.turns == fixture.level.startTurns, "fixture \(index) turns")
            #expect(fixtureRules.initialState == Self.position(Self.started(fixture.level)), "fixture \(index) start")
        }
    }

    @Test("legal moves: every hinge that would swing a cube, ascending, then −1, +1; refusals")
    func handOrder() throws {
        let rules = Rules(level: try Self.handLevel())
        let start: Position = rules.initialState
        #expect(rules.moves(in: start) == [.turn(1, -1), .turn(1, 1), .turn(2, -1), .turn(2, 1)])
        #expect(rules.apply(.turn(0, 1), to: start) == nil)
        #expect(rules.apply(.turn(-1, 1), to: start) == nil)
        #expect(rules.apply(.turn(3, 1), to: start) == nil)
        #expect(rules.apply(.turn(4, 1), to: start) == nil)
        #expect(rules.apply(.turn(1, 0), to: start) == nil)
        #expect(rules.apply(.turn(1, 2), to: start) == nil)
        #expect(rules.apply(.turn(2, -2), to: start) == nil)
        let turned: Position = try #require(rules.apply(.turn(2, 1), to: start))
        #expect(turned.turns == [0, 0, 1, 0])
        #expect(turned.actionsSpent == 1)
        #expect(turned.outcome == .playing)
        let back: Position = try #require(rules.apply(.turn(2, -1), to: start))
        #expect(back.turns == [0, 0, 3, 0])
        let wrapped: Position = try #require(rules.apply(.turn(2, 1), to: back))
        #expect(wrapped.turns == [0, 0, 0, 0])
        #expect(wrapped.actionsSpent == 2)
    }

    @Test("terminal positions: won and failed by the budget offer and accept nothing")
    func terminalPositions() throws {
        let rules = Rules(level: try Self.handLevel(budget: 2))
        let start: Position = rules.initialState
        let one: Position = try #require(rules.apply(.turn(1, 1), to: start))
        #expect(one.outcome == .playing)
        let spent: Position = try #require(rules.apply(.turn(1, -1), to: one))
        #expect(spent.outcome == .failed)
        #expect(spent.actionsSpent == 2)
        var terminals: [Position] = [spent]
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: 10)
        for fixture in fixtures {
            let fixtureRules = Rules(level: fixture.level)
            var state: Position = fixtureRules.initialState
            for action in fixture.actions {
                state = try #require(fixtureRules.apply(action, to: state))
            }
            #expect(state.outcome == .won)
            #expect(fixtureRules.moves(in: state).isEmpty)
            for candidate in Self.candidates(fixture.level.cubes.count) {
                #expect(fixtureRules.apply(candidate, to: state) == nil, "won refuses \(candidate)")
            }
        }
        terminals.append(Position(turns: [0, 0, 0, 0], actionsSpent: 0, outcome: .won))
        terminals.append(Position(turns: [0, 0, 0, 0], actionsSpent: 1, outcome: .failed))
        for terminal in terminals {
            #expect(rules.moves(in: terminal).isEmpty)
            for candidate in Self.candidates(4) {
                #expect(rules.apply(candidate, to: terminal) == nil, "terminal refuses \(candidate)")
            }
        }
    }

    @Test("rules and play agree step by step on 200 seeded walks")
    func agreementWithPlay() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: Self.walkCount)
        var random = SeededRandom(seed: Self.walkSeed)
        var wins: Int = 0
        var latticeFailures: Int = 0
        var budgetFailures: Int = 0
        for (walk, fixture) in fixtures.enumerated() {
            let level: VoxelOrigamiLevel = fixture.level
            let rules = Rules(level: level)
            let all: [VoxelOrigamiAction] = Self.candidates(level.cubes.count)
            var play: VoxelOrigamiPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            let followKnown: Bool = walk % 3 == 0
            var step: Int = 0
            while state.outcome == .playing {
                let moves: [VoxelOrigamiAction] = rules.moves(in: state)
                #expect(!moves.isEmpty, "walk \(walk) step \(step) has moves")
                if moves.isEmpty { break }
                let fingerprint: String = play.fingerprint
                if walk < Self.exhaustiveWalks {
                    var accepted: [VoxelOrigamiAction] = []
                    for candidate in all {
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        let byRules: Bool = rules.apply(candidate, to: state) != nil
                        #expect(byPlay == byRules, "walk \(walk) step \(step) \(candidate)")
                        if byPlay { accepted.append(candidate) }
                    }
                    #expect(accepted == moves, "walk \(walk) step \(step) accepted")
                } else {
                    for move in moves {
                        #expect(Self.applied(play, move, fingerprint: fingerprint) != nil,
                                "walk \(walk) step \(step) play accepts \(move)")
                    }
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: VoxelOrigamiAction = all[random.int(0...(all.count - 1))]
                        let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                        #expect(byPlay == moves.contains(candidate), "walk \(walk) step \(step) \(candidate)")
                    }
                }
                var move: VoxelOrigamiAction = moves[random.int(0...(moves.count - 1))]
                if followKnown, step < fixture.actions.count, moves.contains(fixture.actions[step]) {
                    move = fixture.actions[step]
                }
                let next: Position = try #require(rules.apply(move, to: state), "walk \(walk) step \(step) rules")
                try play.apply(move, expecting: fingerprint)
                state = next
                #expect(state.turns == play.turns, "walk \(walk) step \(step) turns")
                #expect(state.actionsSpent == play.actionsSpent, "walk \(walk) step \(step) actions spent")
                #expect(state.outcome == Self.outcome(play), "walk \(walk) step \(step) outcome")
                step += 1
                #expect(step <= level.budget, "walk \(walk) within budget")
                if step > level.budget { break }
            }
            #expect(rules.moves(in: state).isEmpty, "walk \(walk) terminal has no moves")
            for candidate in all {
                #expect(rules.apply(candidate, to: state) == nil, "walk \(walk) terminal refuses \(candidate)")
            }
            switch play.failure {
            case .collision, .sweep: latticeFailures += 1
            case .budget: budgetFailures += 1
            case nil: if state.outcome == .won { wins += 1 }
            }
        }
        #expect(wins > 0)
        #expect(latticeFailures > 0)
        #expect(budgetFailures > 0)
        #expect(wins + latticeFailures + budgetFailures == Self.walkCount)
    }

    @Test("the fixtures' known turns are legal at every step and reach won")
    func knownTurnsSolve() throws {
        let fixtures: [VoxelOrigamiFixture] = VoxelOrigamiFixture.all(count: Self.walkCount)
        for (index, fixture) in fixtures.enumerated() {
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            for (step, action) in fixture.actions.enumerated() {
                #expect(state.outcome == .playing, "fixture \(index) step \(step) still playing")
                #expect(rules.moves(in: state).contains(action), "fixture \(index) step \(step) legal")
                state = try #require(rules.apply(action, to: state), "fixture \(index) step \(step) applies")
            }
            #expect(rules.isSolved(state), "fixture \(index) solved")
            #expect(state.actionsSpent == fixture.actions.count, "fixture \(index) actions spent")
            #expect(fixture.level.report(turns: state.turns).matched, "fixture \(index) shape matches")
        }
    }
}
