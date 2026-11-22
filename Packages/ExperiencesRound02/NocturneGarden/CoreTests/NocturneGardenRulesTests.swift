// NocturneGardenRulesTests — feature 381 (R02-G09-01) T-R02G0901-005 (FR-R02G0901-010). The rules as an R02-F23 puzzle
// contract: the rules id and start; the legal move order and exact counts on the smallest bed (plants by kind, row,
// column, size; then move, resize, remove by bloom; then sun), with supply, own cell, own size and own elevation left
// out; refusals of out-of-range, no-supply and no-op actions; every fixture's winning actions legal in order and
// winning exactly on the last one; terminal positions without moves; and 200 seeded random walks (seed 2_381) that
// agree step by step with `NocturneGardenPlay`: listed moves are the actions the play accepts (every listed move at the
// start of a few walks, sampled candidates in range and out of range elsewhere), the move count equals its formula,
// and the position after each move matches the play's blooms, sun, moves and outcome. Explicit types, plain loops; each
// test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite("NocturneGardenRules")
struct NocturneGardenRulesTests {
    typealias Rules = NocturneGardenRules
    typealias Position = NocturneGardenRules.Position

    /// The walk seed.
    static let walkSeed: UInt64 = 2_381
    /// The number of seeded walks.
    static let walkCount: Int = 200
    /// The walks whose every step lists all moves and checks them against the play's acceptance.
    static let listedWalks: Int = 12
    /// The walks whose first step tries every listed move on the play.
    static let exhaustiveWalks: Int = 3
    /// The number of fixture levels checked.
    static let fixtureCount: Int = 100

    /// The smallest bed: 16 × 12, one bell and two roses, sizes 1 and 3, elevations 2 and 4 (opening 2), target the
    /// corner cell, nothing forbidden, budget 40.
    static func smallLevel() throws -> NocturneGardenLevel {
        try NocturneGardenLevel(id: "rules-small", seed: 7, difficulty: 1, width: 16, height: 12, target: [0],
                                forbidden: [], supply: [.bell: 1, .rose: 2], sizes: [1, 3], elevations: [2, 4],
                                sun: 2, budget: 40, required: .whole, leakAllowance: 0)
    }

    /// A play of `level` started and past its tutorial.
    static func started(_ level: NocturneGardenLevel) -> NocturneGardenPlay {
        var play = NocturneGardenPlay(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// Whether `play` accepts `action` (tried on a copy).
    static func accepts(_ play: NocturneGardenPlay, _ action: NocturneGardenAction, fingerprint: String) -> Bool {
        var copy: NocturneGardenPlay = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return true
        } catch {
            return false
        }
    }

    /// The rules' outcome of `play`'s stage.
    static func outcome(_ play: NocturneGardenPlay) -> Position.Outcome {
        switch play.stage {
        case .won: return .won
        case .failed: return .failed
        default: return .playing
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: NocturneGardenPlay) -> Position {
        Position(blooms: play.blooms, sun: play.elevation, moves: play.moves, outcome: outcome(play))
    }

    /// The sort key of an action in the documented move order.
    static func key(_ action: NocturneGardenAction) -> [Int] {
        switch action {
        case let .plant(kind, column, row, size): return [0, kind.order, row, column, size]
        case let .move(bloom, column, row): return [1, bloom, row, column]
        case let .resize(bloom, size): return [2, bloom, size]
        case let .remove(bloom): return [3, bloom]
        case let .sun(elevation): return [4, elevation]
        }
    }

    /// Whether `lhs` comes strictly before `rhs` in the documented move order.
    static func before(_ lhs: NocturneGardenAction, _ rhs: NocturneGardenAction) -> Bool {
        let a: [Int] = key(lhs)
        let b: [Int] = key(rhs)
        var index: Int = 0
        while index < a.count && index < b.count {
            if a[index] != b[index] { return a[index] < b[index] }
            index += 1
        }
        return a.count < b.count
    }

    /// The number of legal moves in a playing `state`, by formula.
    static func expectedCount(_ rules: Rules, _ state: Position) -> Int {
        let level: NocturneGardenLevel = rules.level
        let cells: Int = level.width * level.height
        let sizes: Int = level.sizes.count
        var kinds: Int = 0
        for kind in NocturneGardenKind.allCases where rules.available(kind, in: state) > 0 { kinds += 1 }
        let blooms: Int = state.blooms.count
        return kinds * cells * sizes + blooms * (cells - 1) + blooms * (sizes - 1) + blooms
            + (level.elevations.count - 1)
    }

    /// A random candidate action, operands sometimes one outside their range.
    static func candidate(_ random: inout SeededRandom, _ level: NocturneGardenLevel,
                          blooms: Int) -> NocturneGardenAction {
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        let pick: Int = random.int(0...9)
        if pick < 4 {
            return .plant(kinds[random.int(0...5)], random.int(-1...level.width), random.int(-1...level.height),
                          random.int(0...4))
        }
        if pick < 6 {
            return .move(random.int(-1...blooms), random.int(-1...level.width), random.int(-1...level.height))
        }
        if pick < 7 { return .resize(random.int(-1...blooms), random.int(0...4)) }
        if pick < 8 { return .remove(random.int(-1...blooms)) }
        return .sun(random.int(0...5))
    }

    @Test("rules id and initial position")
    func initialPosition() throws {
        let level: NocturneGardenLevel = try Self.smallLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g09-nocturne-garden")
        let start: Position = rules.initialState
        #expect(start.blooms.isEmpty)
        #expect(start.sun == 2)
        #expect(start.moves == 0)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
        #expect(start == Self.position(Self.started(level)))
    }

    @Test("legal moves on the smallest bed: exact order and counts")
    func smallBedOrderAndCounts() throws {
        let rules = Rules(level: try Self.smallLevel())
        let start: Position = rules.initialState
        let first: [NocturneGardenAction] = rules.moves(in: start)
        #expect(first.count == 2 * 192 * 2 + 1)
        #expect(first[0] == .plant(.bell, 0, 0, 1))
        #expect(first[1] == .plant(.bell, 0, 0, 3))
        #expect(first[2] == .plant(.bell, 1, 0, 1))
        #expect(first[32] == .plant(.bell, 0, 1, 1))
        #expect(first[384] == .plant(.rose, 0, 0, 1))
        #expect(first[767] == .plant(.rose, 15, 11, 3))
        #expect(first[768] == .sun(4))
        for index in 1..<first.count { #expect(Self.before(first[index - 1], first[index])) }

        guard let one = rules.apply(.plant(.rose, 5, 4, 1), to: start) else {
            Issue.record("plant refused")
            return
        }
        #expect(one.outcome == .playing)
        #expect(one.moves == 1)
        let second: [NocturneGardenAction] = rules.moves(in: one)
        #expect(second.count == 768 + 191 + 1 + 1 + 1)
        #expect(!second.contains(.move(0, 5, 4)))
        #expect(second.contains(.move(0, 6, 4)))
        #expect(second[768] == .move(0, 0, 0))
        #expect(second[768 + 191] == .resize(0, 3))
        #expect(second[768 + 192] == .remove(0))
        #expect(second[768 + 193] == .sun(4))
        for index in 1..<second.count { #expect(Self.before(second[index - 1], second[index])) }

        guard let two = rules.apply(.plant(.rose, 2, 1, 3), to: one) else {
            Issue.record("second plant refused")
            return
        }
        #expect(two.blooms[0] == NocturneGardenBloom(kind: .rose, column: 2, row: 1, size: 3))
        let third: [NocturneGardenAction] = rules.moves(in: two)
        #expect(third.count == 384 + 2 * 191 + 2 + 2 + 1)
        #expect(third[0] == .plant(.bell, 0, 0, 1))
        #expect(third[383] == .plant(.bell, 15, 11, 3))
        #expect(third[384] == .move(0, 0, 0))
        #expect(!third.contains(.plant(.rose, 0, 0, 1)))
        #expect(third[384 + 382] == .resize(0, 1))
        #expect(third[384 + 383] == .resize(1, 3))
        #expect(third.last == .sun(4))
        for index in 1..<third.count { #expect(Self.before(third[index - 1], third[index])) }
        #expect(third.count == Self.expectedCount(rules, two))
    }

    @Test("out-of-range, no-supply and no-op actions are refused")
    func refusals() throws {
        let rules = Rules(level: try Self.smallLevel())
        let start: Position = rules.initialState
        let refusedAtStart: [NocturneGardenAction] = [
            .plant(.tulip, 0, 0, 1), .plant(.bell, -1, 0, 1), .plant(.bell, 16, 0, 1), .plant(.bell, 0, 12, 1),
            .plant(.bell, 0, 0, 2), .move(0, 1, 1), .resize(0, 1), .remove(0), .sun(2), .sun(3), .sun(5),
        ]
        for action in refusedAtStart { #expect(rules.apply(action, to: start) == nil, "\(action)") }
        guard let one = rules.apply(.plant(.bell, 3, 3, 1), to: start) else {
            Issue.record("plant refused")
            return
        }
        let refusedLater: [NocturneGardenAction] = [
            .plant(.bell, 4, 4, 1), .move(0, 3, 3), .move(1, 4, 4), .move(0, 16, 3), .resize(0, 1), .resize(0, 2),
            .resize(1, 3), .remove(1), .remove(-1),
        ]
        for action in refusedLater { #expect(rules.apply(action, to: one) == nil, "\(action)") }
        #expect(rules.apply(.remove(0), to: one)?.blooms.isEmpty == true)
    }

    @Test("fixture winning actions are legal in order and win exactly on the last one")
    func fixtureSolutions() {
        for fixture in NocturneGardenFixtures.fixtures(Self.fixtureCount) {
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            for index in fixture.actions.indices {
                let action: NocturneGardenAction = fixture.actions[index]
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
            #expect(state.moves == fixture.actions.count)
        }
    }

    @Test("terminal positions offer no moves and refuse every action")
    func terminalPositions() throws {
        let rules = Rules(level: try Self.smallLevel())
        let bloom = NocturneGardenBloom(kind: .rose, column: 4, row: 4, size: 1)
        let playing = Position(blooms: [bloom], sun: 2, moves: 1, outcome: .playing)
        let listed: [NocturneGardenAction] = rules.moves(in: playing)
        #expect(!listed.isEmpty)
        for outcome in [Position.Outcome.won, .failed] {
            let state = Position(blooms: [bloom], sun: 2, moves: 1, outcome: outcome)
            #expect(rules.moves(in: state).isEmpty)
            for index in stride(from: 0, to: listed.count, by: 37) {
                #expect(rules.apply(listed[index], to: state) == nil)
            }
            #expect(rules.apply(listed[listed.count - 1], to: state) == nil)
            #expect(rules.isSolved(state) == (outcome == .won))
        }
    }

    @Test("the budget fails on the exact move and the leak is judged before the win")
    func budgetAndLeak() throws {
        let level = try NocturneGardenLevel(id: "rules-budget", seed: 9, difficulty: 1, width: 16, height: 12,
                                            target: [0], forbidden: [], supply: [.fern: 1], sizes: [1],
                                            elevations: [1, 2, 3], sun: 1, budget: 2, required: .whole,
                                            leakAllowance: 0)
        let rules = Rules(level: level)
        var play: NocturneGardenPlay = Self.started(level)
        var state: Position = rules.initialState
        let actions: [NocturneGardenAction] = [.sun(2), .sun(3)]
        for action in actions {
            guard let next = rules.apply(action, to: state) else {
                Issue.record("refused \(action)")
                return
            }
            try play.apply(action, expecting: play.fingerprint)
            state = next
            #expect(state == Self.position(play))
        }
        #expect(state.outcome == .failed)
        #expect(rules.moves(in: state).isEmpty)

        var offset: UInt64 = 1
        while NocturneGardenFixtures.fixture(Self.walkSeed &+ offset).level.budget < 2 { offset += 1 }
        let fixture: NocturneGardenFixture = NocturneGardenFixtures.fixture(Self.walkSeed &+ offset)
        let leakRules = Rules(level: fixture.level)
        var leakPlay: NocturneGardenPlay = Self.started(fixture.level)
        var leakState: Position = leakRules.initialState
        var steps: Int = 0
        for action in leakRules.moves(in: leakState) {
            guard let next = leakRules.apply(action, to: leakState), next.outcome == .failed else { continue }
            try leakPlay.apply(action, expecting: leakPlay.fingerprint)
            leakState = next
            steps += 1
            break
        }
        #expect(steps == 1)
        if steps == 1 {
            #expect(leakState == Self.position(leakPlay))
            if case .leak(let move)? = leakPlay.failure { #expect(move == 0) } else { Issue.record("not a leak") }
        }
    }

    @Test("200 seeded walks agree with the play step by step")
    func walksAgreeWithPlay() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        var checked: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: NocturneGardenFixture = NocturneGardenFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let level: NocturneGardenLevel = fixture.level
            let rules = Rules(level: level)
            let followsFixture: Bool = walk % 3 == 0
            var play: NocturneGardenPlay = Self.started(level)
            var state: Position = rules.initialState
            #expect(state == Self.position(play), "walk \(walk) start")
            var step: Int = 0
            while state.outcome == .playing {
                let fingerprint: String = play.fingerprint
                var move: NocturneGardenAction?
                if walk < Self.listedWalks {
                    let moves: [NocturneGardenAction] = rules.moves(in: state)
                    #expect(moves.count == Self.expectedCount(rules, state), "walk \(walk) step \(step)")
                    let legal: Set<NocturneGardenAction> = Set(moves)
                    #expect(legal.count == moves.count, "walk \(walk) step \(step) duplicates")
                    if walk < Self.exhaustiveWalks && step == 0 {
                        for action in moves {
                            #expect(Self.accepts(play, action, fingerprint: fingerprint), "walk \(walk) \(action)")
                            checked += 1
                        }
                    }
                    for _ in 0..<24 {
                        let action: NocturneGardenAction = Self.candidate(&random, level, blooms: state.blooms.count)
                        let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        #expect(accepted == legal.contains(action), "walk \(walk) step \(step) \(action)")
                        checked += 1
                    }
                    if !moves.isEmpty { move = moves[random.int(0...(moves.count - 1))] }
                } else {
                    for _ in 0..<64 {
                        let action: NocturneGardenAction = Self.candidate(&random, level, blooms: state.blooms.count)
                        let accepted: Bool = Self.accepts(play, action, fingerprint: fingerprint)
                        let legal: Bool = rules.apply(action, to: state) != nil
                        #expect(accepted == legal, "walk \(walk) step \(step) \(action)")
                        checked += 1
                        if legal && move == nil && random.int(0...2) == 0 { move = action }
                    }
                }
                if followsFixture && step < fixture.actions.count
                    && rules.apply(fixture.actions[step], to: state) != nil {
                    move = fixture.actions[step]
                }
                if move == nil {
                    let moves: [NocturneGardenAction] = rules.moves(in: state)
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
            #expect(state.moves <= level.budget)
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
