// MushroomWeatherPuzzleTests — feature 491 (R02-G20-01) T-R02G2001-005 (FR-R02G2001-010; clarification Q5). The
// rules as an R02-F23 puzzle contract: the rules id and start position; the exact move order on a fixture level
// (placements by slot and placeable cell row-major, skipping colony cells, cells another pod occupies and the slot's
// current cell, then removals of occupied slots ascending, vent changes ascending and the other moonlight levels) and
// its refusals (the run, slots, vents and moonlight out of range, cells off the floor, blocked, on a colony or
// occupied, unchanged values, removing an empty slot, no action left). Two walk tests of 200 seeded random walks each
// (seed 2_491, fixture levels; four arguments of 50 walks each): `agreesWithTheKernelOnSeededWalks` checks at every
// step that the legal moves equal an independent hand enumeration (its own floor and colony test, `handApply`) in
// order, that sampled candidates (slots −1 … P, rows and columns −1 … size, vents −1 … count, moonlight −1 … 4,
// unchanged and occupied values, removals, the run) are accepted exactly as `handApply` accepts them with the same
// position, and that the goal equals `MushroomWeatherForest.report(level, arrangement:).wins`;
// `agreesWithThePlayOnSeededWalks` checks step by step that the play accepts every legal move with the same arrangement
// and actions spent (on the first walk of each argument; sampled later), refuses every candidate the rules refuse
// (exhaustively on the first walk of each argument), that with the budget spent the rules offer no move and the play
// refuses each arrangement action, and that the goal equals the play's `report.wins` and the outcome of its run. One
// walk in three follows the fixture's known actions, so wins occur. Explicit types, plain loops; each test well under
// 10 s. Modelled on `MicroscopicAuroraPuzzleTests` (feature 481).
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

/// Shared helpers of the puzzle tests: fixtures, an independent legality check and candidate actions.
enum MushroomWeatherPuzzleTestSupport {
    typealias Rules = MushroomWeatherPuzzle
    typealias Position = MushroomWeatherPuzzle.Position
    typealias Action = MushroomWeatherAction
    typealias Cell = MushroomWeatherCell
    typealias Arrangement = MushroomWeatherArrangement

    /// The walk seed.
    static let walkSeed: UInt64 = 2_491
    /// The number of seeded walks of each walk test.
    static let walkCount: Int = 200
    /// The fixtures the walks run on.
    static let fixtures: [MushroomWeatherFixture] = MushroomWeatherFixture.all(count: 24)

    /// Whether a pod may stand on `cell` (own test): inside the grid, not blocked and no colony on it.
    static func handPlaceable(_ cell: Cell, level: MushroomWeatherLevel) -> Bool {
        if cell.row < 0 || cell.row >= level.rows || cell.column < 0 || cell.column >= level.columns { return false }
        for blocked in level.blocked where blocked == cell { return false }
        for colony in level.colonies where colony.cell == cell { return false }
        return true
    }

    /// The position after `move` by the clarification's rules, written independently of the puzzle.
    static func handApply(_ move: Action, to state: Position, level: MushroomWeatherLevel) -> Position? {
        let slots: Int = level.podRules.slots
        let ventCount: Int = level.vents.count
        let start: Arrangement = state.arrangement
        if start.pods.count != slots || start.ventsOpen.count != ventCount { return nil }
        if start.moonlight < 0 || start.moonlight > 3 { return nil }
        if state.actionsSpent < 0 || state.actionsSpent >= level.budget { return nil }
        var pods: [Cell?] = start.pods
        var vents: [Bool] = start.ventsOpen
        var moonlight: Int = start.moonlight
        switch move {
        case .run:
            return nil
        case .place(let slot, let cell):
            if slot < 0 || slot >= slots { return nil }
            if !handPlaceable(cell, level: level) { return nil }
            for other in 0..<slots where other != slot {
                if pods[other] == cell { return nil }
            }
            if pods[slot] == cell { return nil }
            pods[slot] = cell
        case .remove(let slot):
            if slot < 0 || slot >= slots { return nil }
            if pods[slot] == nil { return nil }
            pods[slot] = nil
        case .vent(let index, let open):
            if index < 0 || index >= ventCount { return nil }
            if vents[index] == open { return nil }
            vents[index] = open
        case .moonlight(let value):
            if value < 0 || value > 3 { return nil }
            if value == moonlight { return nil }
            moonlight = value
        }
        return Position(arrangement: Arrangement(pods: pods, ventsOpen: vents, moonlight: moonlight),
                        actionsSpent: state.actionsSpent + 1)
    }

    /// The legal moves by hand: every placement accepted by `handApply` in slot, row, column order, then the
    /// removals, vent changes (closed then open, per vent) and moonlight levels accepted by `handApply`, in order.
    static func handMoves(_ state: Position, level: MushroomWeatherLevel) -> [Action] {
        var result: [Action] = []
        for slot in 0..<level.podRules.slots {
            for row in 0..<level.rows {
                for column in 0..<level.columns {
                    let move: Action = .place(slot: slot, cell: Cell(row: row, column: column))
                    if handApply(move, to: state, level: level) != nil { result.append(move) }
                }
            }
        }
        for slot in 0..<level.podRules.slots {
            let move: Action = .remove(slot: slot)
            if handApply(move, to: state, level: level) != nil { result.append(move) }
        }
        for index in 0..<level.vents.count {
            for open in [false, true] {
                let move: Action = .vent(index: index, open: open)
                if handApply(move, to: state, level: level) != nil { result.append(move) }
            }
        }
        for value in 0...3 {
            let move: Action = .moonlight(level: value)
            if handApply(move, to: state, level: level) != nil { result.append(move) }
        }
        return result
    }

    /// Every candidate around the ranges of `level`: placements in slots −1 … P on rows −1 … rows and columns
    /// −1 … columns, removals of slots −1 … P, vents −1 … count either way, moonlight −1 … 4, and the run.
    static func allCandidates(_ level: MushroomWeatherLevel) -> [Action] {
        var result: [Action] = []
        let slots: Int = level.podRules.slots
        for slot in -1...slots {
            for row in -1...level.rows {
                for column in -1...level.columns {
                    result.append(.place(slot: slot, cell: Cell(row: row, column: column)))
                }
            }
        }
        for slot in -1...slots { result.append(.remove(slot: slot)) }
        for index in -1...level.vents.count {
            result.append(.vent(index: index, open: false))
            result.append(.vent(index: index, open: true))
        }
        for value in -1...4 { result.append(.moonlight(level: value)) }
        result.append(.run)
        return result
    }

    /// One random candidate near the legality border: out-of-range values, unchanged values, occupied and colony
    /// cells, removals and the run.
    static func candidate(_ random: inout SeededRandom, state: Position, level: MushroomWeatherLevel) -> Action {
        let slots: Int = level.podRules.slots
        let pods: [Cell?] = state.arrangement.pods
        let kind: Int = random.int(0...11)
        switch kind {
        case 0:
            return .run
        case 1:
            return .remove(slot: random.int(-1...slots))
        case 2:
            // The slot's current cell (unchanged) when there is one.
            let own: Int = random.int(0...(slots - 1))
            if let cell = pods[own] { return .place(slot: own, cell: cell) }
            return .remove(slot: own)
        case 3:
            // Another slot's cell (occupied) when there is one.
            let own: Int = random.int(0...(slots - 1))
            let other: Int = (own + random.int(1...max(1, slots - 1))) % slots
            if other != own, let cell = pods[other] { return .place(slot: own, cell: cell) }
            return .remove(slot: other)
        case 4:
            // A colony's cell.
            let colony: MushroomWeatherColony = level.colonies[random.int(0...(level.colonies.count - 1))]
            return .place(slot: random.int(0...(slots - 1)), cell: colony.cell)
        case 5, 6:
            return .vent(index: random.int(-1...level.vents.count), open: random.int(0...1) == 1)
        case 7:
            return .moonlight(level: random.int(-1...4))
        default:
            let cell: Cell = Cell(row: random.int(-1...level.rows), column: random.int(-1...level.columns))
            return .place(slot: random.int(-1...slots), cell: cell)
        }
    }

    /// The move a walk takes at `step`: the fixture's known action while following, else a random legal move.
    static func chosen(_ random: inout SeededRandom, legal: [Action], fixture: MushroomWeatherFixture,
                       follow: Bool, step: Int) -> Action? {
        if follow && step < fixture.actions.count - 1 { return fixture.actions[step] }
        if legal.isEmpty { return nil }
        return legal[random.int(0...(legal.count - 1))]
    }
}

@Suite("MushroomWeatherPuzzle")
struct MushroomWeatherPuzzleTests {
    typealias Support = MushroomWeatherPuzzleTestSupport
    typealias Rules = MushroomWeatherPuzzle
    typealias Position = MushroomWeatherPuzzle.Position
    typealias Action = MushroomWeatherAction
    typealias Cell = MushroomWeatherCell
    typealias Arrangement = MushroomWeatherArrangement

    /// The walks of each argument whose every step tries every candidate.
    static let exhaustivePerQuarter: Int = 2
    /// The candidates per step of a later walk.
    static let sampledCandidates: Int = 24

    @Test func rulesIDAndStart() throws {
        let fixture: MushroomWeatherFixture = try #require(Support.fixtures.first)
        let rules: Rules = Rules(level: fixture.level)
        #expect(rules.rulesID == "r02-g20-mushroom-weather")
        #expect(rules.initialState == Position(arrangement: fixture.level.start, actionsSpent: 0))
        #expect(!rules.isSolved(rules.initialState))
    }

    @Test func moveOrderAndRefusals() throws {
        // A fixture with a blocked cell and at least two slots; a pod placed in the last slot so occupied cells and
        // removals are exercised.
        let fixture: MushroomWeatherFixture = try #require(Support.fixtures.first { !$0.level.blocked.isEmpty })
        let level: MushroomWeatherLevel = fixture.level
        let rules: Rules = Rules(level: level)
        let slots: Int = level.podRules.slots
        let last: Int = slots - 1
        let colonyCells: Set<Cell> = Set(level.colonies.map(\.cell))
        var free: [Cell] = []
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: Cell = Cell(row: row, column: column)
                if level.isFloor(cell) && !colonyCells.contains(cell) { free.append(cell) }
            }
        }
        let occupied: Cell = free[0]
        var pods: [Cell?] = Array(repeating: nil, count: slots)
        pods[last] = occupied
        let vents: [Bool] = level.start.ventsOpen
        let moon: Int = level.start.moonlight
        let start: Position = Position(arrangement: Arrangement(pods: pods, ventsOpen: vents, moonlight: moon),
                                       actionsSpent: 0)
        // The exact order, built by hand.
        var expected: [Action] = []
        for slot in 0..<slots {
            for row in 0..<level.rows {
                for column in 0..<level.columns {
                    let cell: Cell = Cell(row: row, column: column)
                    if !Support.handPlaceable(cell, level: level) { continue }
                    if cell == occupied { continue }
                    expected.append(.place(slot: slot, cell: cell))
                }
            }
        }
        expected.append(.remove(slot: last))
        for index in 0..<vents.count { expected.append(.vent(index: index, open: !vents[index])) }
        for value in 0...3 where value != moon { expected.append(.moonlight(level: value)) }
        let moves: [Action] = rules.moves(in: start)
        #expect(moves == expected)
        #expect(moves.count == slots * (free.count - 1) + 1 + vents.count + 3)
        #expect(moves.count <= FairnessBudget.maxBranching)
        // Refusals.
        let target: Cell = free[1]
        let blocked: Cell = level.blocked[0]
        let colony: Cell = level.colonies[0].cell
        #expect(rules.apply(.run, to: start) == nil)
        #expect(rules.apply(.place(slot: -1, cell: target), to: start) == nil)
        #expect(rules.apply(.place(slot: slots, cell: target), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: blocked), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: colony), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: Cell(row: -1, column: 0)), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: Cell(row: 0, column: level.columns)), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: Cell(row: level.rows, column: 0)), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, cell: occupied), to: start) == nil)
        #expect(rules.apply(.place(slot: last, cell: occupied), to: start) == nil)
        #expect(rules.apply(.remove(slot: 0), to: start) == nil)
        #expect(rules.apply(.remove(slot: -1), to: start) == nil)
        #expect(rules.apply(.remove(slot: slots), to: start) == nil)
        #expect(rules.apply(.vent(index: -1, open: true), to: start) == nil)
        #expect(rules.apply(.vent(index: vents.count, open: true), to: start) == nil)
        #expect(rules.apply(.vent(index: 0, open: vents[0]), to: start) == nil)
        #expect(rules.apply(.moonlight(level: -1), to: start) == nil)
        #expect(rules.apply(.moonlight(level: 4), to: start) == nil)
        #expect(rules.apply(.moonlight(level: moon), to: start) == nil)
        // Accepted: a move of the last pod, a removal, a placement on a free cell, a vent change, a moonlight change.
        var moved: [Cell?] = pods
        moved[last] = target
        #expect(rules.apply(.place(slot: last, cell: target), to: start)
            == Position(arrangement: Arrangement(pods: moved, ventsOpen: vents, moonlight: moon), actionsSpent: 1))
        #expect(rules.apply(.remove(slot: last), to: start)
            == Position(arrangement: Arrangement(pods: Array(repeating: nil, count: slots), ventsOpen: vents,
                                                 moonlight: moon), actionsSpent: 1))
        var placed: [Cell?] = pods
        placed[0] = target
        #expect(rules.apply(.place(slot: 0, cell: target), to: start)
            == Position(arrangement: Arrangement(pods: placed, ventsOpen: vents, moonlight: moon), actionsSpent: 1))
        var flipped: [Bool] = vents
        flipped[0] = !vents[0]
        #expect(rules.apply(.vent(index: 0, open: !vents[0]), to: start)
            == Position(arrangement: Arrangement(pods: pods, ventsOpen: flipped, moonlight: moon), actionsSpent: 1))
        let other: Int = (moon + 1) % 4
        #expect(rules.apply(.moonlight(level: other), to: start)
            == Position(arrangement: Arrangement(pods: pods, ventsOpen: vents, moonlight: other), actionsSpent: 1))
        // With the budget spent nothing is legal.
        let spent: Position = Position(arrangement: start.arrangement, actionsSpent: level.budget)
        #expect(rules.moves(in: spent).isEmpty)
        #expect(rules.apply(.place(slot: 0, cell: target), to: spent) == nil)
        #expect(rules.apply(.remove(slot: last), to: spent) == nil)
        #expect(rules.apply(.vent(index: 0, open: !vents[0]), to: spent) == nil)
        #expect(rules.apply(.moonlight(level: other), to: spent) == nil)
        // An arrangement without the level's shape takes nothing and is never solved.
        let broken: Position = Position(arrangement: Arrangement(pods: [nil], ventsOpen: [], moonlight: 0),
                                        actionsSpent: 0)
        #expect(rules.moves(in: broken).isEmpty)
        #expect(rules.apply(.place(slot: 0, cell: target), to: broken) == nil)
        #expect(!rules.isSolved(broken))
        // The known winning arrangement is solved.
        #expect(rules.isSolved(Position(arrangement: fixture.winning, actionsSpent: 0)))
    }

    /// The walks of quarter `quarter` (walks 50·quarter … 50·quarter + 49 of the 200), with the random stream
    /// `SeedDerivation.derive(walkSeed, index: quarter)`; checked against the hand rules and the kernel's report.
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithTheKernelOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Support.walkSeed,
                                                                            index: UInt64(quarter)))
        let fixtures: [MushroomWeatherFixture] = Support.fixtures
        let perQuarter: Int = Support.walkCount / 4
        var wins: Int = 0
        var steps: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: MushroomWeatherFixture = fixtures[walk % fixtures.count]
            let level: MushroomWeatherLevel = fixture.level
            let rules: Rules = Rules(level: level)
            var state: Position = rules.initialState
            let follow: Bool = walk % 3 == 0
            let exhaustive: Bool = walk - perQuarter * quarter < Self.exhaustivePerQuarter
            let all: [Action] = exhaustive ? Support.allCandidates(level) : []
            for step in 0..<(level.budget + 2) {
                let legal: [Action] = rules.moves(in: state)
                #expect(legal == Support.handMoves(state, level: level))
                #expect(rules.apply(.run, to: state) == nil)
                if exhaustive {
                    for candidate in all {
                        let byRules: Position? = rules.apply(candidate, to: state)
                        #expect(byRules == Support.handApply(candidate, to: state, level: level))
                    }
                } else {
                    let legalSet: Set<Action> = Set(legal)
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: Action = Support.candidate(&random, state: state, level: level)
                        let byRules: Position? = rules.apply(candidate, to: state)
                        #expect(byRules == Support.handApply(candidate, to: state, level: level))
                        #expect((byRules != nil) == legalSet.contains(candidate))
                    }
                }
                let solved: Bool = rules.isSolved(state)
                #expect(solved == MushroomWeatherForest.report(level, arrangement: state.arrangement).wins)
                if solved { wins += 1 }
                guard let move = Support.chosen(&random, legal: legal, fixture: fixture, follow: follow,
                                                step: step) else { break }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): the rules refused \(move)")
                    break
                }
                #expect(next.actionsSpent == state.actionsSpent + 1)
                state = next
                steps += 1
            }
            if follow {
                // After the fixture's known actions the predicted run wins on the winning arrangement.
                var known: Position = rules.initialState
                for action in fixture.actions.dropLast() {
                    let next: Position? = rules.apply(action, to: known)
                    #expect(next != nil)
                    if let next { known = next }
                }
                #expect(rules.isSolved(known))
                #expect(known.arrangement == fixture.winning)
                #expect(known.actionsSpent <= level.budget)
            }
        }
        #expect(wins > 0)
        #expect(steps > perQuarter)
    }
}

/// The agreement with the play (`MushroomWeatherPlay`, T-R02G2001-004) on 200 seeded walks.
@Suite("MushroomWeatherPuzzle and play")
struct MushroomWeatherPuzzlePlayTests {
    typealias Support = MushroomWeatherPuzzleTestSupport
    typealias Rules = MushroomWeatherPuzzle
    typealias Position = MushroomWeatherPuzzle.Position
    typealias Play = MushroomWeatherPlay
    typealias Action = MushroomWeatherAction

    /// The legal moves per step of a later walk also tried with the play's `apply` (each recomputes the report).
    static let sampledLegal: Int = 6
    /// The candidates per step also tried with the play's `apply`.
    static let sampledCandidates: Int = 12

    /// A play of `level` begun and past its tutorial.
    static func started(_ level: MushroomWeatherLevel) -> Play {
        var play: Play = Play(level: level)
        try? play.handle(.begin)
        if level.tutorial { try? play.handle(.dismissTutorial) }
        return play
    }

    /// The play after `action` (tried on a copy with `fingerprint`), or nil when the play refuses it.
    static func applied(_ play: Play, _ action: Action, fingerprint: String) -> Play? {
        var copy: Play = play
        do {
            try copy.apply(action, expecting: fingerprint)
            return copy
        } catch {
            return nil
        }
    }

    /// The rules' position of `play`.
    static func position(_ play: Play) -> Position {
        Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
    }

    /// The walks of quarter `quarter`, with the random stream `SeedDerivation.derive(walkSeed, index: quarter)`.
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Support.walkSeed,
                                                                            index: UInt64(quarter)))
        let fixtures: [MushroomWeatherFixture] = Support.fixtures
        let perQuarter: Int = Support.walkCount / 4
        var wins: Int = 0
        var steps: Int = 0
        var spentChecks: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: MushroomWeatherFixture = fixtures[walk % fixtures.count]
            let level: MushroomWeatherLevel = fixture.level
            let rules: Rules = Rules(level: level)
            var play: Play = Self.started(level)
            var state: Position = rules.initialState
            #expect(Self.position(play) == state)
            let follow: Bool = walk % 3 == 0
            let exhaustive: Bool = walk == perQuarter * quarter
            let all: [Action] = exhaustive ? Support.allCandidates(level) : []
            for step in 0..<(level.budget + 2) {
                let fingerprint: String = play.fingerprint
                let legal: [Action] = rules.moves(in: state)
                if exhaustive {
                    // The play accepts exactly the legal moves, with the same position.
                    for candidate in all where candidate != .run {
                        let byRules: Position? = rules.apply(candidate, to: state)
                        let after: Play? = Self.applied(play, candidate, fingerprint: fingerprint)
                        #expect((after != nil) == (byRules != nil))
                        if let after { #expect(byRules == Self.position(after)) }
                    }
                } else if !legal.isEmpty {
                    for _ in 0..<Self.sampledLegal {
                        let move: Action = legal[random.int(0...(legal.count - 1))]
                        let after: Play? = Self.applied(play, move, fingerprint: fingerprint)
                        #expect(after != nil)
                        if let after { #expect(rules.apply(move, to: state) == Self.position(after)) }
                    }
                }
                for _ in 0..<Self.sampledCandidates {
                    let candidate: Action = Support.candidate(&random, state: state, level: level)
                    if candidate == .run { continue }
                    let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                    #expect(byPlay == (rules.apply(candidate, to: state) != nil))
                }
                if state.actionsSpent == level.budget {
                    // With the budget spent the rules offer nothing and the play refuses every arrangement action.
                    #expect(legal.isEmpty)
                    #expect(play.actionsLeft == 0)
                    let probes: [Action] = [.remove(slot: 0), .vent(index: 0, open: true), .vent(index: 0, open: false),
                                            .moonlight(level: 0), .moonlight(level: 3)]
                    for probe in probes {
                        #expect(Self.applied(play, probe, fingerprint: fingerprint) == nil)
                    }
                    spentChecks += 1
                }
                // The goal equals the play's predicted report and the outcome of its run.
                let solved: Bool = rules.isSolved(state)
                #expect(solved == play.report.wins)
                let ended: Play? = Self.applied(play, .run, fingerprint: fingerprint)
                #expect(ended != nil)
                if let ended { #expect((ended.stage == .won) == solved) }
                if solved { wins += 1 }
                guard let move = Support.chosen(&random, legal: legal, fixture: fixture, follow: follow,
                                                step: step) else { break }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): the rules refused \(move)")
                    break
                }
                try play.apply(move, expecting: fingerprint)
                state = next
                steps += 1
                #expect(Self.position(play) == state)
                #expect(play.stage == .playing)
            }
        }
        #expect(wins > 0)
        #expect(steps > perQuarter)
        #expect(spentChecks > 0)
    }
}
