// BackwardsAuroraRulesTests — feature 391 (R02-G10-01) T-R02G1001-005 (FR-R02G1001-010). The rules as an R02-F23
// puzzle contract: the rules id and start; the legal move order (start, then end) and exact counts against a formula
// and a brute force over every (start, end) pair, palindromes left out; refusals of out-of-range, wrong-length and
// palindrome reversals; every fixture's known reversals legal in order and winning exactly on the last one; terminal
// positions without moves; the tear judged before the budget and naming the lowest breaking seam, and the budget, both
// as the play judges them; and 200 seeded random walks (seed 2_391) that agree step by step with `BackwardsAuroraPlay`:
// listed moves are the actions the play accepts (every listed move at the start of a few walks, sampled candidates in
// range and out of range elsewhere), the move count equals its formula, and the position after each move matches the
// play's wave, reversals spent and outcome. Explicit types, plain loops; each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import BackwardsAuroraCore

@Suite("BackwardsAuroraRules")
struct BackwardsAuroraRulesTests {
    typealias Rules = BackwardsAuroraRules
    typealias Position = BackwardsAuroraRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_391
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step lists all moves and checks them against the formula and the play's acceptance.
    static let listedWalks: Int = 12
    /// The walks whose first step tries every listed move on the play.
    static let exhaustiveWalks: Int = 4
    /// The number of fixture levels checked.
    static let fixtureCount: Int = 100

    /// The straight target 0, 2, 4, … 22 (every bend 0).
    static let straight: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    /// The straight target with the section [2, 5] reversed.
    static let folded: [Int] = [0, 2, 10, 8, 6, 4, 12, 14, 16, 18, 20, 22]

    /// A level of the folded opening and the straight target, checkpoints 2 and 9, bend limit 4.
    static func level(opening: [Int] = folded, target: [Int] = straight, breakingLimit: Int = 40, shortest: Int = 2,
                      longest: Int = 12, budget: Int = 3) throws -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: "rules-level", seed: 9, difficulty: 1, opening: BackwardsAuroraWave(opening),
                                 target: BackwardsAuroraWave(target), checkpoints: [2, 9], bendLimit: 4,
                                 breakingLimit: breakingLimit, shortest: shortest, longest: longest, budget: budget)
    }

    /// A play of `level` started and past its tutorial.
    static func started(_ level: BackwardsAuroraLevel) -> BackwardsAuroraPlay {
        var play = BackwardsAuroraPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    static func accepts(_ play: BackwardsAuroraPlay, _ action: BackwardsAuroraAction, fingerprint: String) -> Bool {
        var copy: BackwardsAuroraPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: BackwardsAuroraPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: BackwardsAuroraPlay) -> Position {
        Position(wave: play.wave, spent: play.spent, outcome: outcome(play))
    }

    /// The section of a reversal.
    static func section(_ action: BackwardsAuroraAction) -> (start: Int, end: Int) {
        switch action {
        case let .reverse(start, end): return (start: start, end: end)
        }
    }

    /// Whether `lhs` comes strictly before `rhs`: by start, then end.
    static func before(_ lhs: BackwardsAuroraAction, _ rhs: BackwardsAuroraAction) -> Bool {
        let a: (start: Int, end: Int) = section(lhs)
        let b: (start: Int, end: Int) = section(rhs)
        if a.start != b.start { return a.start < b.start }
        return a.end < b.end
    }

    /// Whether samples[start … end] reads the same both ways, by comparing with its reverse.
    static func palindrome(_ samples: [Int], _ start: Int, _ end: Int) -> Bool {
        let slice: [Int] = Array(samples[start...end])
        return slice == Array(slice.reversed())
    }

    /// The number of legal moves in a playing `state`, by formula: Σ over lengths shortest … longest of (N − length +
    /// 1), less the palindromic sections of those lengths.
    static func expectedCount(_ level: BackwardsAuroraLevel, _ state: Position) -> Int {
        let count: Int = state.wave.count
        var total: Int = 0
        for length in level.shortest...level.longest {
            total += count - length + 1
            for start in 0...(count - length) where palindrome(state.wave.samples, start, start + length - 1) {
                total -= 1
            }
        }
        return total
    }

    /// A random candidate reversal, ends sometimes one outside the wave.
    static func candidate(_ random: inout SeededRandom, count: Int) -> BackwardsAuroraAction {
        .reverse(random.int(-1...count), random.int(-1...count))
    }

    @Test("rules id and initial position")
    func initialPosition() throws {
        let level: BackwardsAuroraLevel = try Self.level()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g10-backwards-aurora")
        let start: Position = rules.initialState
        #expect(start.wave == level.opening)
        #expect(start.spent == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
    }

    @Test("legal moves: exact order and counts against the formula and a brute force")
    func orderAndCounts() throws {
        let rules = Rules(level: try Self.level())
        let start: Position = rules.initialState
        let all: [BackwardsAuroraAction] = rules.moves(in: start)
        #expect(all.count == 66)
        #expect(all[0] == .reverse(0, 1))
        #expect(all[10] == .reverse(0, 11))
        #expect(all[11] == .reverse(1, 2))
        #expect(all[65] == .reverse(10, 11))
        for index in 1..<all.count { #expect(Self.before(all[index - 1], all[index])) }

        let narrow = Rules(level: try Self.level(shortest: 3, longest: 5))
        let some: [BackwardsAuroraAction] = narrow.moves(in: narrow.initialState)
        #expect(some.count == 10 + 9 + 8)
        #expect(some[0] == .reverse(0, 2))
        #expect(some[1] == .reverse(0, 3))
        #expect(some[2] == .reverse(0, 4))
        #expect(some[3] == .reverse(1, 3))
        #expect(some.last == .reverse(9, 11))

        // Repeated heights: the opening 3, 2, 1, 0, 3, 3, 4, … has palindromic sections that are left out.
        let target: [Int] = [0, 1, 2, 3, 3, 3, 4, 5, 6, 7, 8, 9]
        let opening: [Int] = [3, 2, 1, 0, 3, 3, 4, 5, 6, 7, 8, 9]
        let repeated: BackwardsAuroraLevel = try Self.level(opening: opening, target: target, shortest: 2,
                                                            longest: 8)
        let repeatedRules = Rules(level: repeated)
        let state: Position = repeatedRules.initialState
        let listed: [BackwardsAuroraAction] = repeatedRules.moves(in: state)
        #expect(!listed.contains(.reverse(4, 5)))
        #expect(!listed.contains(.reverse(3, 5)) == Self.palindrome(opening, 3, 5))
        #expect(listed.count == Self.expectedCount(repeated, state))
        #expect(listed.count < 11 + 10 + 9 + 8 + 7 + 6 + 5)
        for index in 1..<listed.count { #expect(Self.before(listed[index - 1], listed[index])) }

        // Brute force: every pair of ends is legal exactly when it is listed.
        for rulesUnderTest in [rules, narrow, repeatedRules] {
            let position: Position = rulesUnderTest.initialState
            let legal: Set<BackwardsAuroraAction> = Set(rulesUnderTest.moves(in: position))
            var accepted: Int = 0
            for start in -1...12 {
                for end in -1...12 {
                    let action: BackwardsAuroraAction = .reverse(start, end)
                    let applied: Bool = rulesUnderTest.apply(action, to: position) != nil
                    #expect(applied == legal.contains(action), "\(action)")
                    if applied { accepted += 1 }
                }
            }
            #expect(accepted == legal.count)
            #expect(accepted == Self.expectedCount(rulesUnderTest.level, position))
        }
    }

    @Test("out-of-range, wrong-length and palindrome reversals are refused as the play refuses them")
    func refusals() throws {
        let opening: [Int] = [3, 2, 1, 0, 3, 3, 4, 5, 6, 7, 8, 9]
        let level: BackwardsAuroraLevel = try Self.level(opening: opening, target: [0, 1, 2, 3, 3, 3, 4, 5, 6, 7, 8, 9],
                                                         shortest: 2, longest: 5)
        let rules = Rules(level: level)
        let start: Position = rules.initialState
        let play: BackwardsAuroraPlay = Self.started(level)
        let refused: [BackwardsAuroraAction] = [
            .reverse(-1, 1), .reverse(10, 12), .reverse(3, 3), .reverse(5, 4), .reverse(0, 5), .reverse(0, 11),
            .reverse(4, 5),
        ]
        for action in refused {
            #expect(rules.apply(action, to: start) == nil, "\(action)")
            #expect(!Self.accepts(play, action, fingerprint: play.fingerprint), "\(action)")
        }
        #expect(rules.apply(.reverse(0, 4), to: start) != nil)
        #expect(rules.apply(.reverse(3, 4), to: start)?.wave.samples == [3, 2, 1, 3, 0, 3, 4, 5, 6, 7, 8, 9])
    }

    @Test("fixture reversals are legal in order and win exactly on the last one")
    func fixtureSolutions() {
        for fixture in BackwardsAuroraFixtures.fixtures(Self.fixtureCount) {
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            for index in fixture.sections.indices {
                let action: BackwardsAuroraAction = .reverse(fixture.sections[index].start, fixture.sections[index].end)
                #expect(state.outcome == .playing, "\(fixture.level.id) step \(index)")
                #expect(rules.moves(in: state).contains(action), "\(fixture.level.id) step \(index)")
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("\(fixture.level.id) refused step \(index)")
                    break
                }
                state = next
                #expect(state.wave == fixture.waves[index], "\(fixture.level.id) step \(index)")
            }
            #expect(state.outcome == .won, "\(fixture.level.id)")
            #expect(rules.isSolved(state))
            #expect(state.spent == fixture.sections.count)
            #expect(state.wave == fixture.level.target)
        }
    }

    @Test("terminal positions offer no moves and refuse every action")
    func terminalPositions() throws {
        let level: BackwardsAuroraLevel = try Self.level()
        let rules = Rules(level: level)
        let listed: [BackwardsAuroraAction] = rules.moves(in: rules.initialState)
        #expect(!listed.isEmpty)
        for outcome in [Position.Outcome.won, .failed] {
            let state = Position(wave: level.opening, spent: 1, outcome: outcome)
            #expect(rules.moves(in: state).isEmpty)
            for action in listed { #expect(rules.apply(action, to: state) == nil) }
            #expect(rules.isSolved(state) == (outcome == .won))
        }
        guard let won = rules.apply(.reverse(2, 5), to: rules.initialState) else {
            Issue.record("winning reversal refused")
            return
        }
        #expect(won.outcome == .won)
        #expect(rules.moves(in: won).isEmpty)
    }

    @Test("the tear is judged before the budget and names the lowest seam; the budget fails on the exact reversal")
    func tearAndBudget() throws {
        // Budget 1 and breaking limit 4: a tearing reversal on the last reversal fails by tear, not budget.
        let level: BackwardsAuroraLevel = try Self.level(breakingLimit: 4, budget: 1)
        let rules = Rules(level: level)
        let start: Position = rules.initialState
        var tears: Int = 0
        var budgets: Int = 0
        var wins: Int = 0
        for action in rules.moves(in: start) {
            guard let next = rules.apply(action, to: start) else {
                Issue.record("refused \(action)")
                continue
            }
            var play: BackwardsAuroraPlay = Self.started(level)
            try play.apply(action, expecting: play.fingerprint)
            #expect(next == Self.position(play), "\(action)")
            let ends: (start: Int, end: Int) = Self.section(action)
            var lowest: Int?
            for k in BackwardsAuroraWave.seams(start: ends.start, end: ends.end, count: next.wave.count)
            where lowest == nil && abs(next.wave.bend(at: k)) > level.breakingLimit {
                lowest = k
            }
            #expect(rules.tearSeam(next.wave, start: ends.start, end: ends.end) == lowest, "\(action)")
            if let seam = lowest {
                tears += 1
                #expect(next.outcome == .failed)
                #expect(play.failure == .tear(0, seam), "\(action)")
            } else if next.outcome == .won {
                wins += 1
                #expect(play.failure == nil)
            } else {
                budgets += 1
                #expect(next.outcome == .failed)
                #expect(play.failure == .budget, "\(action)")
            }
            #expect(next.spent == 1)
        }
        #expect(tears > 0)
        #expect(budgets > 0)
        #expect(wins == 1)

        // Budget 3, no tear possible: the third non-winning reversal fails by budget, not before.
        let roomy = Rules(level: try Self.level(breakingLimit: 128, budget: 3))
        var play: BackwardsAuroraPlay = Self.started(roomy.level)
        var state: Position = roomy.initialState
        let walk: [BackwardsAuroraAction] = [.reverse(0, 1), .reverse(0, 1), .reverse(10, 11)]
        for index in walk.indices {
            guard let next = roomy.apply(walk[index], to: state) else {
                Issue.record("refused step \(index)")
                return
            }
            try play.apply(walk[index], expecting: play.fingerprint)
            state = next
            #expect(state == Self.position(play), "step \(index)")
            #expect(state.outcome == (index == 2 ? .failed : .playing))
        }
        #expect(play.failure == .budget)
        #expect(roomy.moves(in: state).isEmpty)
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var tornWalks: Int = 0
        var steps: Int = 0
        var checked: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: BackwardsAuroraFixture = BackwardsAuroraFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let level: BackwardsAuroraLevel = fixture.level
            let rules = Rules(level: level)
            let followsFixture: Bool = walk % 3 == 0
            var play: BackwardsAuroraPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            var step: Int = 0
            while state.outcome == .playing {
                let fingerprint: String = play.fingerprint
                var move: BackwardsAuroraAction?
                if walk < Self.listedWalks {
                    let moves: [BackwardsAuroraAction] = rules.moves(in: state)
                    #expect(moves.count == Self.expectedCount(level, state), "walk \(walk) step \(step)")
                    let legal: Set<BackwardsAuroraAction> = Set(moves)
                    #expect(legal.count == moves.count, "walk \(walk) step \(step) duplicates")
                    if walk < Self.exhaustiveWalks && step == 0 {
                        for action in moves {
                            #expect(Self.accepts(play, action, fingerprint: fingerprint), "walk \(walk) \(action)")
                            checked += 1
                        }
                    }
                    for _ in 0..<24 {
                        let action: BackwardsAuroraAction = Self.candidate(&random, count: level.count)
                        let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(accepted == legal.contains(action), "walk \(walk) step \(step) \(action)")
                        checked += 1
                    }
                    if !moves.isEmpty { move = moves[random.int(0...(moves.count - 1))] }
                } else {
                    for _ in 0..<24 {
                        let action: BackwardsAuroraAction = Self.candidate(&random, count: level.count)
                        let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        let legal: Bool = rules.apply(action, to: state) != nil
                        #expect(accepted == legal, "walk \(walk) step \(step) \(action)")
                        checked += 1
                        if legal && move == nil && random.int(0...2) == 0 { move = action }
                    }
                }
                if followsFixture && step < fixture.sections.count {
                    let known: BackwardsAuroraAction = .reverse(fixture.sections[step].start,
                                                                fixture.sections[step].end)
                    if rules.apply(known, to: state) != nil { move = known }
                }
                if move == nil {
                    let moves: [BackwardsAuroraAction] = rules.moves(in: state)
                    if !moves.isEmpty { move = moves[random.int(0...(moves.count - 1))] }
                }
                guard let chosen = move else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                guard let next = rules.apply(chosen, to: state) else {
                    Issue.record("walk \(walk) step \(step): rules refused a legal move \(chosen)")
                    break
                }
                do {
                    try play.apply(chosen, expecting: fingerprint)
                } catch {
                    Issue.record("walk \(walk) step \(step): play refused a legal move \(chosen): \(error)")
                    break
                }
                state = next
                #expect(state == Self.position(play), "walk \(walk) step \(step)")
                step += 1
                steps += 1
            }
            #expect(rules.moves(in: state).isEmpty)
            #expect(state.spent <= level.budget)
            if state.outcome == .won { won += 1 }
            if state.outcome == .failed { failed += 1 }
            if case .tear? = play.failure { tornWalks += 1 }
        }
        #expect(won + failed == Self.walkCount)
        #expect(won > 0)
        #expect(failed > 0)
        #expect(tornWalks > 0)
        #expect(steps >= Self.walkCount)
        #expect(checked > 5_000)
    }
}
