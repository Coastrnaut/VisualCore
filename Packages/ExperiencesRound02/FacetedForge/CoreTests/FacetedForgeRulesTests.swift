// FacetedForgeRulesTests — feature 371 (R02-G08-01) T-R02G0801-005. The rules as an R02-F23 puzzle contract: the rules
// id and start, the legal move order, terminal positions without moves, the fixture solutions winning exactly on their
// last move, and 200 seeded random walks (seed 2_376) that agree step by step with `FacetedForgePlay`: the legal
// moves equal the cuts the play accepts (every cut at a few start positions, sampled cuts plus the chosen move
// elsewhere), and the position after each move matches the play's pieces, cuts and outcome.
import Testing
import VisualCoreSimulation
@testable import FacetedForgeCore

@Suite("FacetedForgeRules")
struct FacetedForgeRulesTests {
    /// The walk seed.
    static let walkSeed: UInt64 = 2_376
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The number of fixture levels checked.
    static let fixtureCount: Int = 40

    /// A play of `level` started and past its tutorial.
    private static func started(_ level: FacetedForgeLevel) -> FacetedForgePlay {
        var play = FacetedForgePlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    private static func accepts(_ play: FacetedForgePlay, _ action: FacetedForgeAction, fingerprint: String) -> Bool {
        var copy: FacetedForgePlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    private static func outcome(_ play: FacetedForgePlay) -> FacetedForgeRules.Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// Whether `lhs` comes strictly before `rhs` in (piece, direction, depth) order.
    private static func before(_ lhs: FacetedForgeAction, _ rhs: FacetedForgeAction) -> Bool {
        guard case .cut(let p0, let d0, let h0) = lhs, case .cut(let p1, let d1, let h1) = rhs else { return false }
        if p0 != p1 { return p0 < p1 }
        if d0 != d1 { return d0 < d1 }
        return h0 < h1
    }

    @Test("rules id and initial position")
    func initialPosition() {
        let level: FacetedForgeLevel = FacetedForgeFixtures.fixture(1).level
        let rules = FacetedForgeRules(level: level)
        #expect(rules.rulesID == "r02-g08-faceted-forge")
        let start: FacetedForgeRules.Position = rules.initialState
        #expect(start.pieces == [level.crystal])
        #expect(start.cuts == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
    }

    @Test("legal moves: strictly ordered by piece, direction, depth and all crossing")
    func legalMoveOrder() {
        for fixture in FacetedForgeFixtures.fixtures(20) {
            let rules = FacetedForgeRules(level: fixture.level)
            var state: FacetedForgeRules.Position = rules.initialState
            for action in fixture.actions {
                let moves: [FacetedForgeAction] = rules.moves(in: state)
                #expect(!moves.isEmpty)
                for index in moves.indices {
                    if index > 0 { #expect(Self.before(moves[index - 1], moves[index])) }
                    guard case .cut(let piece, let direction, let depth) = moves[index] else { continue }
                    #expect(state.pieces[piece].isCrossed(direction: direction, depth: depth))
                }
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("fixture \(fixture.level.id) refused \(action)")
                    break
                }
                state = next
            }
        }
    }

    @Test("fixture solutions are legal move sequences that win exactly on their last move")
    func fixtureSolutions() {
        for fixture in FacetedForgeFixtures.fixtures(Self.fixtureCount) {
            let rules = FacetedForgeRules(level: fixture.level)
            var state: FacetedForgeRules.Position = rules.initialState
            for (index, action) in fixture.actions.enumerated() {
                #expect(state.outcome == .playing, "\(fixture.level.id) step \(index)")
                #expect(rules.moves(in: state).contains(action), "\(fixture.level.id) step \(index)")
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("\(fixture.level.id) refused step \(index)")
                    break
                }
                state = next
            }
            #expect(state.outcome == .won, "\(fixture.level.id)")
            #expect(rules.isSolved(state))
            #expect(state.cuts == fixture.actions.count)
        }
    }

    @Test("terminal positions offer no moves and refuse every cut")
    func terminalPositions() {
        let fixture: FacetedForgeFixture = FacetedForgeFixtures.fixture(1)
        let rules = FacetedForgeRules(level: fixture.level)
        let pieces: [FacetedForgePiece] = rules.initialState.pieces
        for outcome in [FacetedForgeRules.Position.Outcome.won, .failed] {
            let state = FacetedForgeRules.Position(pieces: pieces, cuts: 1, outcome: outcome)
            #expect(rules.moves(in: state).isEmpty)
            let playing = FacetedForgeRules.Position(pieces: pieces, cuts: 1, outcome: .playing)
            for move in rules.moves(in: playing).prefix(20) {
                #expect(rules.apply(move, to: state) == nil)
            }
            #expect(!rules.isSolved(state) || outcome == .won)
        }
    }

    @Test("out-of-range and missing cuts are refused")
    func refusals() {
        let rules = FacetedForgeRules(level: FacetedForgeFixtures.fixture(2).level)
        let state: FacetedForgeRules.Position = rules.initialState
        #expect(rules.apply(.cut(1, 0, 0), to: state) == nil)
        #expect(rules.apply(.cut(-1, 0, 0), to: state) == nil)
        #expect(rules.apply(.cut(0, 13, 0), to: state) == nil)
        #expect(rules.apply(.cut(0, 0, 25), to: state) == nil)
        #expect(rules.apply(.cut(0, 0, 24), to: state) == nil)
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = FacetedForgeRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: FacetedForgeFixture = FacetedForgeFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let rules = FacetedForgeRules(level: fixture.level)
            var play: FacetedForgePlay = Self.started(fixture.level)
            var state: FacetedForgeRules.Position = rules.initialState
            var step: Int = 0
            while state.outcome == .playing {
                let moves: [FacetedForgeAction] = rules.moves(in: state)
                let legal: Set<FacetedForgeAction> = Set(moves)
                let fingerprint: String = play.fingerprint
                if walk < 8 && step == 0 {
                    for piece in state.pieces.indices {
                        for direction in FacetedForgeDirection.all.indices {
                            for depth in FacetedForgeHalfSpace.depths {
                                let action: FacetedForgeAction = .cut(piece, direction, depth)
                                let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                                #expect(accepted == legal.contains(action), "walk \(walk) \(action)")
                            }
                        }
                    }
                } else {
                    for _ in 0..<6 {
                        let action: FacetedForgeAction = .cut(random.int(-1...state.pieces.count),
                                                              random.int(-1...13), random.int(-25...25))
                        let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(accepted == legal.contains(action), "walk \(walk) step \(step) \(action)")
                    }
                }
                guard !moves.isEmpty else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                let move: FacetedForgeAction = random.pick(moves)
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): rules refused a listed move \(move)")
                    break
                }
                do {
                    try play.apply(move, expecting: fingerprint)
                } catch {
                    Issue.record("walk \(walk) step \(step): play refused a listed move \(move): \(error)")
                    break
                }
                state = next
                #expect(state.pieces == play.pieces, "walk \(walk) step \(step)")
                #expect(state.cuts == play.cuts, "walk \(walk) step \(step)")
                #expect(state.outcome == Self.outcome(play), "walk \(walk) step \(step)")
                step += 1
                steps += 1
            }
            #expect(rules.moves(in: state).isEmpty)
            if state.outcome == .won { won += 1 }
            if state.outcome == .failed { failed += 1 }
        }
        #expect(won + failed == Self.walkCount)
        #expect(failed > 0)
        #expect(steps >= Self.walkCount)
    }
}
