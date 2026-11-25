// ApsidesWorkshopRulesTests — feature 471 (R02-G18-01) T-R02G1801-005 (FR-R02G1801-010). The rules as an R02-F23
// puzzle contract: the rules id and start position; the exact move order on a fixture level (periapsis tunings by
// eccentricity step then direction step, other than the current pair and valid, then size tunings ascending, other than
// the current size and valid) and its refusals (the play, steps out of range, unchanged tunings, tunings making the
// orbit invalid, no action left); the agreement with `ApsidesWorkshopPlay` step by step on 200 seeded random walks
// (seed 2_471, fixture levels; four tests of 50 walks each): on the first 2 walks of each test every candidate
// (periapsis tunings of steps −1 … 16 by −1 … 24, sizes 7 … 49, and the play) is tried with `apply(_:expecting:)` on a
// copy of the play with its current fingerprint and the accepted tunings are exactly the legal moves in order; on the
// others 12 sampled legal moves and 12 sampled candidates are tried (a legal list holds up to ~380 periapsis tunings,
// so applying all of them on every step would be slow); applying the chosen move gives the same orbit and actions
// spent as the play; at every step the goal equals the play's predicted report (`report.wins`) and the outcome of the
// play's play action (on a copy: won exactly when the rules say solved); one walk in three follows the fixture's known
// tunings, so wins occur. Explicit types, plain loops; each test well under 10 s. Modelled on
// `CelestialEclipseLabRulesTests` (feature 461).
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite("ApsidesWorkshopRules")
struct ApsidesWorkshopRulesTests {
    typealias Rules = ApsidesWorkshopRules
    typealias Position = ApsidesWorkshopRules.Position
    typealias Play = ApsidesWorkshopPlay
    typealias Action = ApsidesWorkshopAction
    typealias Orbit = ApsidesWorkshopOrbit

    /// The walk seed.
    static let walkSeed: UInt64 = 2_471
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks of each test whose every step tries every candidate with the play's `apply`.
    static let exhaustivePerQuarter: Int = 2
    /// The legal moves per step of a later walk also tried with the play's `apply`.
    static let sampledLegal: Int = 12
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 12
    /// The fixtures the walks run on.
    static let fixtures: [ApsidesWorkshopFixture] = ApsidesWorkshopFixture.all(count: 40)

    /// Every candidate action: periapsis tunings of steps −1 … 16 by −1 … 24, sizes 7 … 49, and the play.
    static let candidates: [Action] = {
        var result: [Action] = []
        for k in (Orbit.eccentricities.lowerBound - 1)...(Orbit.eccentricities.upperBound + 1) {
            for d in (Orbit.directions.lowerBound - 1)...(Orbit.directions.upperBound + 1) {
                result.append(.periapsis(k, d))
            }
        }
        for a in (Orbit.sizes.lowerBound - 1)...(Orbit.sizes.upperBound + 1) { result.append(.size(a)) }
        result.append(.play)
        return result
    }()

    /// A play of `level` begun and past its tutorial.
    static func started(_ level: ApsidesWorkshopLevel) -> Play {
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
        Position(orbit: play.orbit, actionsSpent: play.actionsSpent)
    }

    /// Whether the play's play action (on a copy) wins.
    static func playWins(_ play: Play) -> Bool {
        guard let after = applied(play, .play) else { return false }
        return after.stage == .won
    }

    @Test func rulesIDAndStart() throws {
        let fixture: ApsidesWorkshopFixture = try #require(Self.fixtures.first)
        let rules: Rules = Rules(level: fixture.level)
        #expect(rules.rulesID == "r02-g18-apsides-workshop")
        #expect(rules.initialState == Position(orbit: fixture.level.orbit, actionsSpent: 0))
        #expect(!rules.isSolved(rules.initialState))
    }

    @Test func moveOrderAndRefusals() throws {
        let fixture: ApsidesWorkshopFixture = try #require(Self.fixtures.first)
        let level: ApsidesWorkshopLevel = fixture.level
        let rules: Rules = Rules(level: level)
        let start: Position = rules.initialState
        let orbit: Orbit = start.orbit
        var expected: [Action] = []
        for k in 0...15 {
            for d in 0...23 where !(k == orbit.eccentricity && d == orbit.direction) {
                let s: Int = orbit.size
                if s * (20 - k) >= 60 && s * (20 + k) <= 1280 { expected.append(.periapsis(k, d)) }
            }
        }
        for a in 8...48 where a != orbit.size {
            let k: Int = orbit.eccentricity
            if a * (20 - k) >= 60 && a * (20 + k) <= 1280 { expected.append(.size(a)) }
        }
        #expect(rules.moves(in: start) == expected)
        #expect(rules.apply(.play, to: start) == nil)
        #expect(rules.apply(.periapsis(orbit.eccentricity, orbit.direction), to: start) == nil)
        #expect(rules.apply(.size(orbit.size), to: start) == nil)
        #expect(rules.apply(.periapsis(-1, 0), to: start) == nil)
        #expect(rules.apply(.periapsis(16, 0), to: start) == nil)
        #expect(rules.apply(.periapsis(0, -1), to: start) == nil)
        #expect(rules.apply(.periapsis(0, 24), to: start) == nil)
        #expect(rules.apply(.size(7), to: start) == nil)
        #expect(rules.apply(.size(49), to: start) == nil)
        // Size 48 with eccentricity 15 leaves the sky (48 · 35 > 1280); size 8 with eccentricity 15 dips into the star.
        let wide: Position = Position(orbit: Orbit(size: 48, eccentricity: 0, direction: 0), actionsSpent: 0)
        #expect(rules.apply(.periapsis(15, 0), to: wide) == nil)
        #expect(rules.apply(.periapsis(5, 0), to: wide) == Position(
            orbit: Orbit(size: 48, eccentricity: 5, direction: 0), actionsSpent: 1))
        let eccentric: Position = Position(orbit: Orbit(size: 20, eccentricity: 15, direction: 3), actionsSpent: 0)
        #expect(rules.apply(.size(8), to: eccentric) == nil)
        #expect(rules.apply(.size(48), to: eccentric) == nil)
        #expect(rules.apply(.size(12), to: eccentric) == Position(
            orbit: Orbit(size: 12, eccentricity: 15, direction: 3), actionsSpent: 1))
        // With the budget spent nothing is legal.
        let spent: Position = Position(orbit: orbit, actionsSpent: level.budget)
        #expect(rules.moves(in: spent).isEmpty)
        if let first = expected.first { #expect(rules.apply(first, to: spent) == nil) }
        // An invalid orbit is never solved and takes no tuning.
        let invalid: Position = Position(orbit: Orbit(size: 8, eccentricity: 15, direction: 0), actionsSpent: 0)
        #expect(!rules.isSolved(invalid))
        #expect(rules.moves(in: invalid).isEmpty)
    }

    /// The walks of quarter `quarter` (walks 50·quarter … 50·quarter + 49 of the 200), with the random stream
    /// `SeedDerivation.derive(walkSeed, index: quarter)`; four tests so each stays well under 10 s.
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Self.walkSeed, index: UInt64(quarter)))
        let fixtures: [ApsidesWorkshopFixture] = Self.fixtures
        let all: [Action] = Self.candidates
        let perQuarter: Int = Self.walkCount / 4
        var wins: Int = 0
        var steps: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: ApsidesWorkshopFixture = fixtures[walk % fixtures.count]
            let level: ApsidesWorkshopLevel = fixture.level
            let rules: Rules = Rules(level: level)
            var play: Play = Self.started(level)
            var state: Position = rules.initialState
            #expect(Self.position(play) == state)
            let follow: Bool = walk % 3 == 0
            let exhaustive: Bool = walk - perQuarter * quarter < Self.exhaustivePerQuarter
            for step in 0..<(level.budget + 2) {
                let legal: [Action] = rules.moves(in: state)
                #expect(rules.apply(.play, to: state) == nil)
                if exhaustive {
                    var accepted: [Action] = []
                    for candidate in all where candidate != .play && Self.applied(play, candidate) != nil {
                        accepted.append(candidate)
                    }
                    #expect(accepted == legal)
                } else {
                    if !legal.isEmpty {
                        for _ in 0..<Self.sampledLegal {
                            let move: Action = legal[random.int(0...(legal.count - 1))]
                            let after: Play? = Self.applied(play, move)
                            #expect(after != nil)
                            if let after { #expect(rules.apply(move, to: state) == Self.position(after)) }
                        }
                    }
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: Action = all[random.int(0...(all.count - 2))]
                        let byPlay: Bool = Self.applied(play, candidate) != nil
                        let byRules: Bool = rules.apply(candidate, to: state) != nil
                        #expect(byPlay == byRules)
                        #expect(byRules == legal.contains(candidate))
                    }
                }
                // The goal equals the play's predicted report and the outcome of its play action.
                let solved: Bool = rules.isSolved(state)
                #expect(solved == play.report.wins)
                #expect(solved == Self.playWins(play))
                if solved { wins += 1 }
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
            if follow {
                // After the fixture's known tunings the predicted play wins on the winning orbit.
                var known: Position = rules.initialState
                for action in fixture.actions.dropLast() {
                    if let next = rules.apply(action, to: known) { known = next }
                }
                #expect(rules.isSolved(known))
                #expect(known.orbit == fixture.winning)
            }
        }
        #expect(wins > 0)
        #expect(steps > perQuarter)
    }
}
