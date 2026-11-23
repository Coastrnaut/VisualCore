// EchoCartographerRulesAgreementTests — feature 401 (R02-G11-01) T-R02G1101-005 (FR-R02G1101-010). The rules agree with
// `EchoCartographerPlay` step by step on 200 seeded random walks (seed 2_401, fixture levels): at every step of the
// first 8 walks the rules' legal moves are exactly the pulses and claims the play accepts among every pulse and claim
// cell one outside the chamber, and at every step of the other walks for 24 sampled pulse or claim cells (each tried on
// a copy of the play with its current fingerprint); markers are never moves although the play accepts them; applying a
// move gives the same energy, located beacons, knowledge and outcome as the play. One walk in three follows the
// fixture's known actions while the rules allow them, so both outcomes occur. Explicit types, plain loops; a few
// seconds (every play attempt hashes the fingerprint, so trying every cell on all 200 walks took 23 s in a debug build).
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite("EchoCartographerRulesAgreement")
struct EchoCartographerRulesAgreementTests {
    typealias Rules = EchoCartographerRules
    typealias Position = EchoCartographerRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_401
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every pulse and claim cell on the play; later walks try sampled cells.
    static let exhaustiveWalks: Int = 8
    /// The sampled candidates per step of a walk past `exhaustiveWalks`.
    static let sampledCandidates: Int = 24

    /// A play of `level` started and past its tutorial.
    static func started(_ level: EchoCartographerLevel) -> EchoCartographerPlay {
        var play = EchoCartographerPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    static func accepts(_ play: EchoCartographerPlay, _ action: EchoCartographerAction, fingerprint: String) -> Bool {
        var copy: EchoCartographerPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: EchoCartographerPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: EchoCartographerPlay) -> Position {
        let located: [Int] = Array(play.located.keys).sorted()
        return Position(knowledge: play.knowledge, located: located, energy: play.energy, outcome: outcome(play))
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        var checked: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: EchoCartographerFixture = EchoCartographerFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let level: EchoCartographerLevel = fixture.level
            let rules = Rules(level: level)
            var play: EchoCartographerPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            var known: [EchoCartographerAction] = []
            for cell in fixture.pulses { known.append(.pulse(cell.x, cell.y)) }
            for cell in fixture.claims { known.append(.claim(cell.x, cell.y)) }
            var step: Int = 0
            while state.outcome == .playing {
                let fingerprint: String = play.fingerprint
                let moves: [EchoCartographerAction] = rules.moves(in: state)
                let legal: Set<EchoCartographerAction> = Set(moves)
                #expect(legal.count == moves.count, "walk \(walk) step \(step) duplicates")
                if walk < Self.exhaustiveWalks {
                    var accepted: Int = 0
                    for y in -1...level.chamber.height {
                        for x in -1...level.chamber.width {
                            let candidates: [EchoCartographerAction] = [.pulse(x, y), .claim(x, y)]
                            for action in candidates {
                                let yes: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                                #expect(yes == legal.contains(action), "walk \(walk) step \(step) \(action)")
                                if yes { accepted += 1 }
                                checked += 1
                            }
                        }
                    }
                    #expect(accepted == moves.count, "walk \(walk) step \(step)")
                } else {
                    for _ in 0..<Self.sampledCandidates {
                        let x: Int = random.int(-1...level.chamber.width)
                        let y: Int = random.int(-1...level.chamber.height)
                        let action: EchoCartographerAction = random.int(0...1) == 0 ? .pulse(x, y) : .claim(x, y)
                        let yes: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(yes == legal.contains(action), "walk \(walk) step \(step) \(action)")
                        checked += 1
                    }
                }
                let marker: EchoCartographerAction = .mark(level.entry.x, level.entry.y)
                #expect(!legal.contains(marker), "walk \(walk) step \(step)")
                #expect(rules.apply(marker, to: state) == nil, "walk \(walk) step \(step)")
                guard !moves.isEmpty else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                var move: EchoCartographerAction = moves[random.int(0...(moves.count - 1))]
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
                #expect(state.energy == mirrored.energy, "walk \(walk) step \(step) energy")
                #expect(state.located == mirrored.located, "walk \(walk) step \(step) located")
                #expect(state.knowledge == mirrored.knowledge, "walk \(walk) step \(step) knowledge")
                #expect(state.outcome == mirrored.outcome, "walk \(walk) step \(step) outcome")
                step += 1
                steps += 1
            }
            #expect(rules.moves(in: state).isEmpty)
            if state.outcome == .won { won += 1 }
            if state.outcome == .failed { failed += 1 }
        }
        #expect(won + failed == Self.walkCount)
        #expect(won > 0)
        #expect(failed > 0)
        #expect(steps >= Self.walkCount)
        #expect(checked > 10_000)
    }
}
