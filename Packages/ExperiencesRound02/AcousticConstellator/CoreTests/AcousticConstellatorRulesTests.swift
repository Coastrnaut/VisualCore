// AcousticConstellatorRulesTests — feature 421 (R02-G13-01) T-R02G1301-005 (FR-R02G1301-010). The rules as an R02-F23
// puzzle contract: the rules id and start position; the exact move order on the hand level (every valid link in pair
// order, every valid unlink of a placed link in pair order, every nudge in star order then −1, +1, then the listen);
// the agreement with `AcousticConstellatorPlay` step by step on 200 seeded random walks (seed 2_421, fixture levels):
// at every step the rules accept exactly the actions the play accepts among every link and unlink of stars −1 … count
// in either order, every nudge of stars −1 … count by −2 … 2 and the listen — on the first 10 walks each tried with
// `apply(_:expecting:)` on a copy of the play with its current fingerprint, on the others checked with the play's own
// validation (`check(_:)`, what `apply` runs after its stage and fingerprint checks) plus 8 sampled candidates tried
// with `apply` on a copy (every `apply` attempt hashes the fingerprint) — the accepted lower-star-first actions are the
// legal moves in order (so their counts agree and an action the play refuses is never listed), and applying a move
// gives the same links, phases, actions spent and outcome as the play; one walk in three follows the fixture's known
// winning actions while the rules allow them, so both outcomes occur; and terminal positions (won, failed by a listen,
// failed by the budget) have no moves and refuse every move. The play's isomorphism label is never read (its search
// visits up to 8! orderings). Explicit types, plain loops; each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

@Suite("AcousticConstellatorRules")
struct AcousticConstellatorRulesTests {
    typealias Rules = AcousticConstellatorRules
    typealias Position = AcousticConstellatorRules.Position
    typealias Link = AcousticConstellatorLink

    /// The walk seed.
    static let walkSeed: UInt64 = 2_421
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step tries every candidate with the play's `apply`; later walks use its `check`.
    static let exhaustiveWalks: Int = 10
    /// The candidates per step of a later walk also tried with the play's `apply`.
    static let sampledCandidates: Int = 8

    /// A play of `level` started and past its tutorial.
    static func started(_ level: AcousticConstellatorLevel) -> AcousticConstellatorPlay {
        var play = AcousticConstellatorPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    static func accepts(_ play: AcousticConstellatorPlay, _ action: AcousticConstellatorAction,
                        fingerprint: String) -> Bool {
        var copy: AcousticConstellatorPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// Whether `play` (playing) passes its own validation of `action`, without hashing a fingerprint.
    static func passesCheck(_ play: AcousticConstellatorPlay, _ action: AcousticConstellatorAction) -> Bool {
        guard play.stage == .playing else { return false }
        do {
            try play.check(action)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: AcousticConstellatorPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: AcousticConstellatorPlay) -> Position {
        Position(links: play.links, phases: play.phases, actionsSpent: play.actionsSpent, outcome: outcome(play))
    }

    /// Every candidate action: the links of stars −1 … `count` in either order, the unlinks likewise, the nudges of
    /// stars −1 … `count` by −2 … 2, in that order, then the listen.
    static func candidates(_ count: Int) -> [AcousticConstellatorAction] {
        var result: [AcousticConstellatorAction] = []
        for u in -1...count {
            for v in -1...count { result.append(.link(u, v)) }
        }
        for u in -1...count {
            for v in -1...count { result.append(.unlink(u, v)) }
        }
        for star in -1...count {
            for step in -2...2 { result.append(.nudge(star, step)) }
        }
        result.append(.listen)
        return result
    }

    /// Whether `action` names its stars lower first (always true for a nudge or the listen).
    static func lowerFirst(_ action: AcousticConstellatorAction) -> Bool {
        switch action {
        case .link(let u, let v), .unlink(let u, let v): return u < v
        case .nudge, .listen: return true
        }
    }

    /// A fixture action tuple as an action, links lower star first.
    static func action(_ tuple: (kind: String, a: Int, b: Int)) -> AcousticConstellatorAction {
        switch tuple.kind {
        case "link": return .link(min(tuple.a, tuple.b), max(tuple.a, tuple.b))
        case "unlink": return .unlink(min(tuple.a, tuple.b), max(tuple.a, tuple.b))
        case "nudge": return .nudge(tuple.a, tuple.b)
        default: return .listen
        }
    }

    @Test("rules id and initial position")
    func initialPosition() {
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g13-acoustic-constellator")
        let start: Position = rules.initialState
        #expect(start.links == [Link(a: 0, b: 1)])
        #expect(start.phases == [0, 0, 1])
        #expect(start.actionsSpent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
        for walk in 0..<10 {
            let fixture: AcousticConstellatorLevel = AcousticConstellatorFixtures.fixture(Self.walkSeed &+ UInt64(walk))
                .level
            let fixtureRules = Rules(level: fixture)
            #expect(fixtureRules.initialState.links == fixture.fixedLinks.sorted(), "fixture \(walk) links")
            #expect(fixtureRules.initialState.phases == fixture.startingPhases, "fixture \(walk) phases")
            #expect(fixtureRules.initialState == Self.position(Self.started(fixture)), "fixture \(walk) start")
        }
    }

    @Test("legal moves: links in pair order, placed unlinks in pair order, nudges by star then −1, +1, then the listen")
    func handOrder() throws {
        let rules = Rules(level: AcousticConstellatorFixtures.handLevel())
        let start: Position = rules.initialState
        // Link 0–1 is fixed, so it is neither linkable nor removable.
        let moves: [AcousticConstellatorAction] = rules.moves(in: start)
        #expect(moves == [.link(0, 2), .link(1, 2), .nudge(0, -1), .nudge(0, 1), .nudge(1, -1), .nudge(1, 1),
                          .nudge(2, -1), .nudge(2, 1), .listen])
        #expect(rules.apply(.link(0, 1), to: start) == nil)
        #expect(rules.apply(.unlink(0, 1), to: start) == nil)
        #expect(rules.apply(.unlink(1, 2), to: start) == nil)
        #expect(rules.apply(.link(0, 0), to: start) == nil)
        #expect(rules.apply(.link(0, 3), to: start) == nil)
        #expect(rules.apply(.link(-1, 2), to: start) == nil)
        #expect(rules.apply(.nudge(0, 0), to: start) == nil)
        #expect(rules.apply(.nudge(0, 2), to: start) == nil)
        #expect(rules.apply(.nudge(3, 1), to: start) == nil)
        // Either order names the same link.
        let linked: Position = try #require(rules.apply(.link(2, 1), to: start))
        #expect(rules.apply(.link(1, 2), to: start) == linked)
        #expect(linked.links == [Link(a: 0, b: 1), Link(a: 1, b: 2)])
        #expect(linked.actionsSpent == 1)
        // Star 1 is now at the degree limit 2, so only 0–2 is linkable; the placed 1–2 is removable.
        #expect(rules.moves(in: linked) == [.link(0, 2), .unlink(1, 2), .nudge(0, -1), .nudge(0, 1), .nudge(1, -1),
                                            .nudge(1, 1), .nudge(2, -1), .nudge(2, 1), .listen])
        let unlinked: Position = try #require(rules.apply(.unlink(2, 1), to: linked))
        #expect(unlinked.links == start.links)
        #expect(unlinked.actionsSpent == 2)
        // At the link limit 3 no link is offered.
        let full: Position = try #require(rules.apply(.link(0, 2), to: linked))
        #expect(full.links.count == 3)
        #expect(!rules.moves(in: full).contains { if case .link = $0 { return true } else { return false } })
        // A nudge wraps modulo 12.
        let nudged: Position = try #require(rules.apply(.nudge(0, -1), to: start))
        #expect(nudged.phases == [11, 0, 1])
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        var checked: Int = 0
        var unlinks: Int = 0
        for walk in 0..<Self.walkCount {
            let seed: UInt64 = Self.walkSeed &+ UInt64(walk)
            let fixture: AcousticConstellatorFixture = AcousticConstellatorFixtures.fixture(seed)
            let level: AcousticConstellatorLevel = fixture.level
            let rules = Rules(level: level)
            var play: AcousticConstellatorPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            var known: [AcousticConstellatorAction] = []
            for tuple in fixture.winningActions { known.append(Self.action(tuple)) }
            let candidates: [AcousticConstellatorAction] = Self.candidates(level.stars.count)
            var step: Int = 0
            while state.outcome == .playing {
                let fingerprint: String = play.fingerprint
                let moves: [AcousticConstellatorAction] = rules.moves(in: state)
                let legal: Set<AcousticConstellatorAction> = Set(moves)
                #expect(legal.count == moves.count, "walk \(walk) step \(step) duplicates")
                var accepted: [AcousticConstellatorAction] = []
                for action in candidates {
                    var yes: Bool = false
                    if walk < Self.exhaustiveWalks {
                        yes = Self.accepts(play, action, fingerprint: fingerprint)
                    } else {
                        yes = Self.passesCheck(play, action)
                    }
                    let applied: Bool = rules.apply(action, to: state) != nil
                    #expect(applied == yes, "walk \(walk) step \(step) \(action)")
                    if yes && Self.lowerFirst(action) { accepted.append(action) }
                    if !yes { #expect(!legal.contains(action), "walk \(walk) step \(step) refused \(action) listed") }
                    checked += 1
                }
                if walk >= Self.exhaustiveWalks {
                    for _ in 0..<Self.sampledCandidates {
                        let action: AcousticConstellatorAction = candidates[random.int(0...(candidates.count - 1))]
                        let yes: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(yes == (rules.apply(action, to: state) != nil),
                                "walk \(walk) step \(step) sampled \(action)")
                        if Self.lowerFirst(action) {
                            #expect(yes == legal.contains(action), "walk \(walk) step \(step) sampled \(action)")
                        }
                        checked += 1
                    }
                }
                // The candidates run in the rules' order, so the accepted lower-star-first list equals the moves.
                #expect(accepted == moves, "walk \(walk) step \(step)")
                #expect(accepted.count == moves.count, "walk \(walk) step \(step) count")
                guard !moves.isEmpty else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                var move: AcousticConstellatorAction = moves[random.int(0...(moves.count - 1))]
                if walk % 3 == 0 && step < known.count && legal.contains(known[step]) { move = known[step] }
                if case .unlink = move { unlinks += 1 }
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
                #expect(state.links == mirrored.links, "walk \(walk) step \(step) links")
                #expect(state.phases == mirrored.phases, "walk \(walk) step \(step) phases")
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
        #expect(unlinks > 0)
        #expect(steps >= Self.walkCount)
        #expect(checked > 10_000)
    }

    /// Checks that `state` is terminal: no moves, and every candidate refused.
    static func expectTerminal(_ rules: Rules, _ state: Position, _ label: String) {
        #expect(state.outcome != .playing, "\(label)")
        #expect(rules.moves(in: state).isEmpty, "\(label)")
        let candidates: [AcousticConstellatorAction] = Self.candidates(rules.level.stars.count)
        for action in candidates {
            #expect(rules.apply(action, to: state) == nil, "\(label) \(action)")
        }
    }

    @Test("terminal positions have no moves")
    func terminalPositions() throws {
        let rules = Rules(level: AcousticConstellatorFixtures.handLevel())
        // Won: link 1–2, then listen (the hold of 3 is reached on tick 3).
        let linked: Position = try #require(rules.apply(.link(1, 2), to: rules.initialState))
        #expect(linked.outcome == .playing)
        let won: Position = try #require(rules.apply(.listen, to: linked))
        #expect(won.outcome == .won)
        #expect(won.actionsSpent == 2)
        #expect(rules.isSolved(won))
        Self.expectTerminal(rules, won, "won")
        // Failed by a listen: the bare level misses the pair 1–2.
        let missing: Position = try #require(rules.apply(.listen, to: rules.initialState))
        #expect(missing.outcome == .failed)
        #expect(missing.actionsSpent == 1)
        #expect(!rules.isSolved(missing))
        Self.expectTerminal(rules, missing, "missing")
        // Failed by the budget: five nudges spend the budget of 5.
        var state: Position = rules.initialState
        for index in 0..<5 {
            #expect(state.outcome == .playing, "nudge \(index)")
            state = try #require(rules.apply(.nudge(2, index % 2 == 0 ? 1 : -1), to: state))
        }
        #expect(state.outcome == .failed)
        #expect(state.actionsSpent == 5)
        #expect(state.phases == [0, 0, 2])
        Self.expectTerminal(rules, state, "budget")
        // A listen on the last action of the budget still wins: the hand level with a budget of 4.
        let hand: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel()
        let tight = Rules(level: try AcousticConstellatorLevel(
            id: hand.id, seed: hand.seed, difficulty: hand.difficulty, stars: hand.stars, fixedLinks: hand.fixedLinks,
            symbol: hand.symbol, coupling: hand.coupling, degreeLimit: hand.degreeLimit, linkLimit: hand.linkLimit,
            snapLimit: hand.snapLimit, threshold: hand.threshold, hold: hand.hold, window: hand.window, budget: 4))
        var last: Position = try #require(tight.apply(.link(1, 2), to: tight.initialState))
        last = try #require(tight.apply(.nudge(0, 1), to: last))
        last = try #require(tight.apply(.nudge(0, -1), to: last))
        #expect(last.outcome == .playing)
        #expect(last.actionsSpent == 3)
        let lastWon: Position = try #require(tight.apply(.listen, to: last))
        #expect(lastWon.outcome == .won)
        #expect(lastWon.actionsSpent == 4)
        Self.expectTerminal(tight, lastWon, "last-action win")
    }
}
