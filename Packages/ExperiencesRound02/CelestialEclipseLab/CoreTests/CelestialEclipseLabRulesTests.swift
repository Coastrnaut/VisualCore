// CelestialEclipseLabRulesTests — feature 461 (R02-G17-01) T-R02G1701-005 (FR-R02G1701-010). The rules as an R02-F23
// puzzle contract: the rules id and start position; the exact move order on a hand level (each movable body in index
// order, then offsets 0 … period − 1 other than the current phase) and its refusals (the run, fixed and unknown bodies,
// offsets outside the period or equal to the current one, no action left); the agreement with `CelestialEclipseLabPlay`
// step by step on 200 seeded random walks (seed 2_461, fixture levels; four tests of 50 walks each, feature 462): on
// the first 20 walks every candidate (phase changes of bodies −1 … n to offsets −1 … the longest period) is tried with
// `apply(_:expecting:)` on a copy of the play with its current fingerprint and the accepted candidates are exactly the
// legal moves in order; on the others every legal move and 8 sampled candidates are tried; applying the chosen move
// gives the same phases and actions spent as the play; at every step the goal equals the outcome of the play's run (on
// a copy: won exactly when the rules say solved); one walk in three follows the fixture's known phase changes, so wins
// occur. Explicit types, plain loops; each test well under 10 s. Modelled on `StarlitCartoucheRulesTests` (feature
// 451).
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite("CelestialEclipseLabRules")
struct CelestialEclipseLabRulesTests {
    typealias Rules = CelestialEclipseLabRules
    typealias Position = CelestialEclipseLabRules.Position
    typealias Play = CelestialEclipseLabPlay
    typealias Action = CelestialEclipseLabAction

    /// The walk seed.
    static let walkSeed: UInt64 = 2_461
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`.
    static let exhaustiveWalks: Int = 20
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8
    /// The fixtures the walks run on.
    static let fixtures: [CelestialEclipseLabFixture] = CelestialEclipseLabFixture.all(count: 40)

    /// The hand level: body 0 fixed (radius 2, a square orbit of period 4 at depth 10), body 1 movable (radius 2, a
    /// line x = −12, −9, …, 9 of period 8 at depth 0), horizon 8, the target body 0 in front of body 1 in ticks 2 … 5,
    /// starting phases [0, 3].
    static func handLevel(budget: Int = 3) throws -> CelestialEclipseLabLevel {
        let square: [CelestialEclipseLabVector] = [CelestialEclipseLabVector(-1, -1, 10),
                                                   CelestialEclipseLabVector(1, -1, 10),
                                                   CelestialEclipseLabVector(1, 1, 10),
                                                   CelestialEclipseLabVector(-1, 1, 10)]
        var line: [CelestialEclipseLabVector] = []
        for k in 0..<8 { line.append(CelestialEclipseLabVector(-12 + 3 * k, 0, 0)) }
        let bodies: [CelestialEclipseLabBody] = [CelestialEclipseLabBody(orbit: square, radius: 2, fixed: true),
                                                 CelestialEclipseLabBody(orbit: line, radius: 2)]
        return try CelestialEclipseLabLevel(
            id: "hand", seed: 1, difficulty: 1, bodies: bodies, horizon: 8,
            target: [CelestialEclipseLabTarget(front: 0, back: 1, open: 2, close: 5)], phases: [0, 3], budget: budget)
    }

    /// A play of `level` begun and past its tutorial.
    static func started(_ level: CelestialEclipseLabLevel) -> Play {
        var play: Play = Play(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// The play after `action` (tried on a copy with its current fingerprint), or nil when the play refuses it.
    static func applied(_ play: Play, _ action: Action) -> Play? {
        var copy: Play = play
        do {
            try copy.apply(action, expecting: play.fingerprint)
            return copy
        } catch {
            return nil
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: Play) -> Position {
        Position(phases: play.phases, actionsSpent: play.actionsSpent)
    }

    /// Every candidate phase change of `level`: bodies −1 … n, offsets −1 … the longest period.
    static func candidates(_ level: CelestialEclipseLabLevel) -> [Action] {
        var longest: Int = 0
        for body in level.bodies { longest = max(longest, body.period) }
        var result: [Action] = []
        for body in -1...level.bodies.count {
            for offset in -1...longest { result.append(.phase(body, offset)) }
        }
        return result
    }

    /// Whether the play's run (on a copy) wins.
    static func runWins(_ play: Play) -> Bool {
        guard let after = applied(play, .run) else { return false }
        return after.stage == .won
    }

    @Test func rulesIDAndStart() throws {
        let level: CelestialEclipseLabLevel = try Self.handLevel()
        let rules: Rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g17-celestial-eclipse-lab")
        #expect(rules.initialState == Position(phases: [0, 3], actionsSpent: 0))
        #expect(!rules.isSolved(rules.initialState))
    }

    @Test func handLevelMoveOrderAndRefusals() throws {
        let level: CelestialEclipseLabLevel = try Self.handLevel(budget: 1)
        let rules: Rules = Rules(level: level)
        let start: Position = rules.initialState
        var expected: [Action] = []
        for offset in 0..<8 where offset != 3 { expected.append(.phase(1, offset)) }
        #expect(rules.moves(in: start) == expected)
        #expect(rules.apply(.run, to: start) == nil)
        #expect(rules.apply(.phase(0, 1), to: start) == nil)
        #expect(rules.apply(.phase(2, 1), to: start) == nil)
        #expect(rules.apply(.phase(-1, 1), to: start) == nil)
        #expect(rules.apply(.phase(1, 3), to: start) == nil)
        #expect(rules.apply(.phase(1, 8), to: start) == nil)
        #expect(rules.apply(.phase(1, -1), to: start) == nil)
        let next: Position? = rules.apply(.phase(1, 0), to: start)
        #expect(next == Position(phases: [0, 0], actionsSpent: 1))
        if let next {
            // Phases [0, 0]: body 1 reaches x = −3 at tick 3, inside the window, so the predicted run wins.
            #expect(rules.isSolved(next))
            #expect(rules.moves(in: next).isEmpty)
            #expect(rules.apply(.phase(1, 1), to: next) == nil)
        }
    }

    /// The walks of quarter `quarter` (walks 50·quarter … 50·quarter + 49 of the 200), with the random stream
    /// `SeedDerivation.derive(walkSeed, index: quarter)`; four tests so each stays well under 10 s (feature 462 split
    /// the single 200-walk test, which took 12 s alone on the slower host of 2026-11-25).
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Self.walkSeed, index: UInt64(quarter)))
        let fixtures: [CelestialEclipseLabFixture] = Self.fixtures
        let perQuarter: Int = Self.walkCount / 4
        var wins: Int = 0
        var steps: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: CelestialEclipseLabFixture = fixtures[walk % fixtures.count]
            let level: CelestialEclipseLabLevel = fixture.level
            let rules: Rules = Rules(level: level)
            let all: [Action] = Self.candidates(level)
            var play: Play = Self.started(level)
            var state: Position = rules.initialState
            #expect(Self.position(play) == state)
            let follow: Bool = walk % 3 == 0
            for step in 0..<(level.budget + 2) {
                let legal: [Action] = rules.moves(in: state)
                #expect(rules.apply(.run, to: state) == nil)
                if walk < Self.exhaustiveWalks {
                    var accepted: [Action] = []
                    for candidate in all where Self.applied(play, candidate) != nil { accepted.append(candidate) }
                    #expect(accepted == legal)
                } else {
                    for move in legal { #expect(Self.applied(play, move) != nil) }
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: Action = all[random.int(0...(all.count - 1))]
                        let byPlay: Bool = Self.applied(play, candidate) != nil
                        let byRules: Bool = rules.apply(candidate, to: state) != nil
                        #expect(byPlay == byRules)
                        #expect(byRules == legal.contains(candidate))
                    }
                }
                // The goal equals the outcome of the play's run.
                #expect(rules.isSolved(state) == Self.runWins(play))
                if rules.isSolved(state) { wins += 1 }
                let move: Action
                if follow && step < fixture.actions.count - 1 {
                    move = fixture.actions[step]
                } else if legal.isEmpty {
                    break
                } else {
                    move = legal[random.int(0...(legal.count - 1))]
                }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): the rules refused \(move)")
                    break
                }
                try play.apply(move, expecting: play.fingerprint)
                state = next
                steps += 1
                #expect(Self.position(play) == state)
                #expect(play.stage == .playing)
            }
            if follow && fixture.actions.count - 1 <= level.budget + 2 {
                // After the fixture's known phase changes the predicted run wins.
                var known: Position = rules.initialState
                for action in fixture.actions.dropLast() {
                    if let next = rules.apply(action, to: known) { known = next }
                }
                #expect(rules.isSolved(known))
                #expect(known.phases == fixture.winning)
            }
        }
        #expect(wins > 0)
        #expect(steps > perQuarter)
    }
}
