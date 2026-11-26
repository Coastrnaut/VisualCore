// MicroscopicAuroraPuzzleTests — feature 481 (R02-G19-01) T-R02G1901-005 (FR-R02G1901-010; clarification Q5). The
// rules as an R02-F23 puzzle contract: the rules id and start position; the exact move order on a fixture level
// (placements by slot, usable cell row-major, strength 1 … 4 and sense clockwise then counterclockwise, skipping
// cells another well occupies and the slot's current well, then removals of occupied slots ascending) and its
// refusals (the play, slots, cells and strengths out of range, cells outside the enclosure or occupied, unchanged
// wells, removing an empty slot, no action left). Two walk tests of 200 seeded random walks each (seed 2_481, fixture
// levels; four arguments of 50 walks each): `agreesWithTheKernelOnSeededWalks` checks at every step that the legal
// moves equal an independent hand enumeration (its own enclosure test, `handApply`) in order, that sampled candidates
// (slots −1 … 3, rows and columns −1 … 24, strengths 0 … 5, unchanged and occupied wells, removals, the play) are
// accepted exactly as `handApply` accepts them with the same position, and that the goal equals
// `MicroscopicAuroraDish.report(level, wells:).wins`; `agreesWithThePlayOnSeededWalks` (DEPENDS ON
// `MicroscopicAuroraPlay`, agent B, T-R02G1901-004) checks step by step that the play accepts sampled legal moves with
// the same wells and actions spent, refuses every candidate the rules refuse (exhaustively on the first walk of each
// argument) and that the goal equals the play's `report.wins` and the outcome of its play action. One walk in three
// follows the fixture's known actions, so wins occur. Explicit types, plain loops; each test well under 10 s.
// Modelled on `ApsidesWorkshopRulesTests` (feature 471).
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

/// Shared helpers of the puzzle tests: fixtures, an independent legality check and candidate actions.
enum MicroscopicAuroraPuzzleTestSupport {
    typealias Rules = MicroscopicAuroraPuzzle
    typealias Position = MicroscopicAuroraPuzzle.Position
    typealias Action = MicroscopicAuroraAction
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell

    /// The walk seed.
    static let walkSeed: UInt64 = 2_481
    /// The number of seeded walks of each walk test.
    static let walkCount: Int = 200
    /// The fixtures the walks run on.
    static let fixtures: [MicroscopicAuroraFixture] = MicroscopicAuroraFixture.all(count: 24)
    /// The senses in the documented order.
    static let senses: [MicroscopicAuroraSense] = [.clockwise, .counterclockwise]

    /// Whether `cell` is on the 24 × 24 dish and its centre is within `radius` cells of the dish centre (own formula).
    static func handInside(_ cell: Cell, radius: Int) -> Bool {
        guard cell.row >= 0, cell.row <= 23, cell.column >= 0, cell.column <= 23 else { return false }
        let dx: Int = cell.column * 256 + 128 - 3072
        let dy: Int = cell.row * 256 + 128 - 3072
        return dx * dx + dy * dy <= radius * radius * 65_536
    }

    /// The position after `move` by the clarification's rules, written independently of the puzzle.
    static func handApply(_ move: Action, to state: Position, level: MicroscopicAuroraLevel) -> Position? {
        if state.wells.count != 3 || state.actionsSpent < 0 || state.actionsSpent >= level.budget { return nil }
        var wells: [Well?] = state.wells
        switch move {
        case .play:
            return nil
        case .place(let slot, let well):
            if slot < 0 || slot > 2 { return nil }
            if well.strength < 1 || well.strength > 4 { return nil }
            if !handInside(well.cell, radius: level.radius) { return nil }
            for other in 0...2 where other != slot {
                if let placed = wells[other], placed.cell == well.cell { return nil }
            }
            if wells[slot] == well { return nil }
            wells[slot] = well
        case .remove(let slot):
            if slot < 0 || slot > 2 { return nil }
            if wells[slot] == nil { return nil }
            wells[slot] = nil
        }
        return Position(wells: wells, actionsSpent: state.actionsSpent + 1)
    }

    /// The legal moves by hand: every placement accepted by `handApply` in slot, row, column, strength, sense order,
    /// then the removals accepted by `handApply` in slot order.
    static func handMoves(_ state: Position, level: MicroscopicAuroraLevel) -> [Action] {
        var result: [Action] = []
        for slot in 0...2 {
            for row in 0...23 {
                for column in 0...23 {
                    for strength in 1...4 {
                        for sense in senses {
                            let well: Well = Well(cell: Cell(row: row, column: column), strength: strength,
                                                  sense: sense)
                            let move: Action = .place(slot: slot, well: well)
                            if handApply(move, to: state, level: level) != nil { result.append(move) }
                        }
                    }
                }
            }
        }
        for slot in 0...2 {
            let move: Action = .remove(slot: slot)
            if handApply(move, to: state, level: level) != nil { result.append(move) }
        }
        return result
    }

    /// Every candidate around the ranges: placements in slots −1 … 3 on rows and columns −1 … 24 with strengths 0 … 5
    /// and either sense, removals of slots −1 … 3, and the play.
    static func allCandidates() -> [Action] {
        var result: [Action] = []
        for slot in -1...3 {
            for row in -1...24 {
                for column in -1...24 {
                    for strength in 0...5 {
                        for sense in senses {
                            let well: Well = Well(cell: Cell(row: row, column: column), strength: strength,
                                                  sense: sense)
                            result.append(.place(slot: slot, well: well))
                        }
                    }
                }
            }
        }
        for slot in -1...3 { result.append(.remove(slot: slot)) }
        result.append(.play)
        return result
    }

    /// One random candidate near the legality border: out-of-range values, unchanged wells, occupied cells,
    /// removals and the play.
    static func candidate(_ random: inout SeededRandom, state: Position) -> Action {
        let kind: Int = random.int(0...9)
        let slot: Int = random.int(-1...3)
        let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
        switch kind {
        case 0:
            return .play
        case 1, 2:
            return .remove(slot: slot)
        case 3:
            // The slot's current well (unchanged) when there is one.
            let own: Int = random.int(0...2)
            if let well = state.wells[own] { return .place(slot: own, well: well) }
            return .remove(slot: own)
        case 4:
            // Another slot's cell (occupied) when there is one.
            let own: Int = random.int(0...2)
            let other: Int = (own + random.int(1...2)) % 3
            if let well = state.wells[other] {
                return .place(slot: own, well: Well(cell: well.cell, strength: random.int(1...4), sense: sense))
            }
            return .remove(slot: other)
        default:
            let cell: Cell = Cell(row: random.int(-1...24), column: random.int(-1...24))
            return .place(slot: slot, well: Well(cell: cell, strength: random.int(0...5), sense: sense))
        }
    }

    /// The move a walk takes at `step`: the fixture's known action while following, else a random legal move.
    static func chosen(_ random: inout SeededRandom, legal: [Action], fixture: MicroscopicAuroraFixture,
                       follow: Bool, step: Int) -> Action? {
        if follow && step < fixture.actions.count - 1 { return fixture.actions[step] }
        if legal.isEmpty { return nil }
        return legal[random.int(0...(legal.count - 1))]
    }
}

@Suite("MicroscopicAuroraPuzzle")
struct MicroscopicAuroraPuzzleTests {
    typealias Support = MicroscopicAuroraPuzzleTestSupport
    typealias Rules = MicroscopicAuroraPuzzle
    typealias Position = MicroscopicAuroraPuzzle.Position
    typealias Action = MicroscopicAuroraAction
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell

    /// The walks of each argument whose every step tries every candidate.
    static let exhaustivePerQuarter: Int = 2
    /// The candidates per step of a later walk.
    static let sampledCandidates: Int = 24

    @Test func rulesIDAndStart() throws {
        let fixture: MicroscopicAuroraFixture = try #require(Support.fixtures.first)
        let rules: Rules = Rules(level: fixture.level)
        #expect(rules.rulesID == "r02-g19-microscopic-aurora")
        #expect(rules.initialState == Position(wells: fixture.level.wells, actionsSpent: 0))
        #expect(!rules.isSolved(rules.initialState))
    }

    @Test func moveOrderAndRefusals() throws {
        // A position with a well in slot 2 (not the start), so occupied cells and removals are exercised.
        let fixture: MicroscopicAuroraFixture = try #require(Support.fixtures.first)
        let level: MicroscopicAuroraLevel = fixture.level
        let rules: Rules = Rules(level: level)
        let occupied: Well = Well(cell: level.stencil[0], strength: 2, sense: .counterclockwise)
        let start: Position = Position(wells: [nil, nil, occupied], actionsSpent: 0)
        // The exact order, built by hand.
        var expected: [Action] = []
        for slot in 0...2 {
            for row in 0...23 {
                for column in 0...23 {
                    let cell: Cell = Cell(row: row, column: column)
                    if !Support.handInside(cell, radius: level.radius) { continue }
                    if slot != 2 && cell == occupied.cell { continue }
                    for strength in 1...4 {
                        for sense in Support.senses {
                            let well: Well = Well(cell: cell, strength: strength, sense: sense)
                            if start.wells[slot] != well { expected.append(.place(slot: slot, well: well)) }
                        }
                    }
                }
            }
        }
        expected.append(.remove(slot: 2))
        let moves: [Action] = rules.moves(in: start)
        #expect(moves == expected)
        #expect(moves.count == expected.count)
        // Refusals.
        let inside: Cell = level.stencil[0]
        let free: Cell = inside == occupied.cell ? level.stencil[1] : inside
        #expect(rules.apply(.play, to: start) == nil)
        #expect(rules.apply(.place(slot: -1, well: Well(cell: free, strength: 2, sense: .clockwise)), to: start) == nil)
        #expect(rules.apply(.place(slot: 3, well: Well(cell: free, strength: 2, sense: .clockwise)), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, well: Well(cell: free, strength: 0, sense: .clockwise)), to: start) == nil)
        #expect(rules.apply(.place(slot: 0, well: Well(cell: free, strength: 5, sense: .clockwise)), to: start) == nil)
        let corner: Well = Well(cell: Cell(row: 0, column: 0), strength: 1, sense: .clockwise)
        #expect(rules.apply(.place(slot: 0, well: corner), to: start) == nil)
        let offDish: Well = Well(cell: Cell(row: 24, column: 12), strength: 1, sense: .clockwise)
        #expect(rules.apply(.place(slot: 0, well: offDish), to: start) == nil)
        let negative: Well = Well(cell: Cell(row: 12, column: -1), strength: 1, sense: .clockwise)
        #expect(rules.apply(.place(slot: 0, well: negative), to: start) == nil)
        let onOccupied: Well = Well(cell: occupied.cell, strength: 1, sense: .clockwise)
        #expect(rules.apply(.place(slot: 0, well: onOccupied), to: start) == nil)
        #expect(rules.apply(.place(slot: 2, well: occupied), to: start) == nil)
        #expect(rules.apply(.remove(slot: 0), to: start) == nil)
        #expect(rules.apply(.remove(slot: -1), to: start) == nil)
        #expect(rules.apply(.remove(slot: 3), to: start) == nil)
        // Accepted: a change of strength or sense on the slot's own cell, a removal, a placement on a free cell.
        let stronger: Well = Well(cell: occupied.cell, strength: occupied.strength % 4 + 1, sense: occupied.sense)
        #expect(rules.apply(.place(slot: 2, well: stronger), to: start)
            == Position(wells: [start.wells[0], start.wells[1], stronger], actionsSpent: 1))
        let turned: MicroscopicAuroraSense = occupied.sense == .clockwise ? .counterclockwise : .clockwise
        let flipped: Well = Well(cell: occupied.cell, strength: occupied.strength, sense: turned)
        #expect(rules.apply(.place(slot: 2, well: flipped), to: start) != nil)
        #expect(rules.apply(.remove(slot: 2), to: start)
            == Position(wells: [start.wells[0], start.wells[1], nil], actionsSpent: 1))
        let fresh: Well = Well(cell: free, strength: 3, sense: .counterclockwise)
        #expect(rules.apply(.place(slot: 0, well: fresh), to: start)
            == Position(wells: [fresh, start.wells[1], start.wells[2]], actionsSpent: 1))
        // With the budget spent nothing is legal.
        let spent: Position = Position(wells: start.wells, actionsSpent: level.budget)
        #expect(rules.moves(in: spent).isEmpty)
        #expect(rules.apply(.place(slot: 0, well: fresh), to: spent) == nil)
        #expect(rules.apply(.remove(slot: 2), to: spent) == nil)
        // A position without three slots takes nothing and is never solved.
        let broken: Position = Position(wells: [nil, nil], actionsSpent: 0)
        #expect(rules.moves(in: broken).isEmpty)
        #expect(rules.apply(.place(slot: 0, well: fresh), to: broken) == nil)
        #expect(!rules.isSolved(broken))
        // The known winning wells are solved.
        #expect(rules.isSolved(Position(wells: fixture.winning, actionsSpent: 0)))
    }

    /// The walks of quarter `quarter` (walks 50·quarter … 50·quarter + 49 of the 200), with the random stream
    /// `SeedDerivation.derive(walkSeed, index: quarter)`; checked against the hand rules and the kernel's report.
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithTheKernelOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Support.walkSeed,
                                                                            index: UInt64(quarter)))
        let fixtures: [MicroscopicAuroraFixture] = Support.fixtures
        let perQuarter: Int = Support.walkCount / 4
        let all: [Action] = Support.allCandidates()
        var wins: Int = 0
        var steps: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: MicroscopicAuroraFixture = fixtures[walk % fixtures.count]
            let level: MicroscopicAuroraLevel = fixture.level
            let rules: Rules = Rules(level: level)
            var state: Position = rules.initialState
            let follow: Bool = walk % 3 == 0
            let exhaustive: Bool = walk - perQuarter * quarter < Self.exhaustivePerQuarter
            for step in 0..<(level.budget + 2) {
                let legal: [Action] = rules.moves(in: state)
                #expect(legal == Support.handMoves(state, level: level))
                #expect(rules.apply(.play, to: state) == nil)
                if exhaustive {
                    for candidate in all {
                        let byRules: Position? = rules.apply(candidate, to: state)
                        #expect(byRules == Support.handApply(candidate, to: state, level: level))
                    }
                } else {
                    let legalSet: Set<Action> = Set(legal)
                    for _ in 0..<Self.sampledCandidates {
                        let candidate: Action = Support.candidate(&random, state: state)
                        let byRules: Position? = rules.apply(candidate, to: state)
                        #expect(byRules == Support.handApply(candidate, to: state, level: level))
                        #expect((byRules != nil) == legalSet.contains(candidate))
                    }
                }
                let placed: [Well] = state.wells.compactMap { $0 }
                let solved: Bool = rules.isSolved(state)
                #expect(solved == MicroscopicAuroraDish.report(level, wells: placed).wins)
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
                // After the fixture's known actions the predicted play wins on the winning wells.
                var known: Position = rules.initialState
                for action in fixture.actions.dropLast() {
                    if let next = rules.apply(action, to: known) { known = next }
                }
                #expect(rules.isSolved(known))
                #expect(known.wells == fixture.winning)
            }
        }
        #expect(wins > 0)
        #expect(steps > perQuarter)
    }
}

/// DEPENDS ON `MicroscopicAuroraPlay` (agent B, T-R02G1901-004): the agreement with the play on 200 seeded walks.
@Suite("MicroscopicAuroraPuzzle and play")
struct MicroscopicAuroraPuzzlePlayTests {
    typealias Support = MicroscopicAuroraPuzzleTestSupport
    typealias Rules = MicroscopicAuroraPuzzle
    typealias Position = MicroscopicAuroraPuzzle.Position
    typealias Play = MicroscopicAuroraPlay
    typealias Action = MicroscopicAuroraAction

    /// The legal moves per step also tried with the play's `apply` (each recomputes the play's report).
    static let sampledLegal: Int = 6
    /// The candidates per step also tried with the play's `apply`.
    static let sampledCandidates: Int = 12

    /// A play of `level` begun and past its tutorial.
    static func started(_ level: MicroscopicAuroraLevel) -> Play {
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
        Position(wells: play.wells, actionsSpent: play.actionsSpent)
    }

    /// The walks of quarter `quarter`, with the random stream `SeedDerivation.derive(walkSeed, index: quarter)`.
    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(Support.walkSeed,
                                                                            index: UInt64(quarter)))
        let fixtures: [MicroscopicAuroraFixture] = Support.fixtures
        let perQuarter: Int = Support.walkCount / 4
        let all: [Action] = Support.allCandidates()
        var wins: Int = 0
        var steps: Int = 0
        for walk in (perQuarter * quarter)..<(perQuarter * (quarter + 1)) {
            let fixture: MicroscopicAuroraFixture = fixtures[walk % fixtures.count]
            let level: MicroscopicAuroraLevel = fixture.level
            let rules: Rules = Rules(level: level)
            var play: Play = Self.started(level)
            var state: Position = rules.initialState
            #expect(Self.position(play) == state)
            let follow: Bool = walk % 3 == 0
            let exhaustive: Bool = walk == perQuarter * quarter
            for step in 0..<(level.budget + 2) {
                let fingerprint: String = play.fingerprint
                let legal: [Action] = rules.moves(in: state)
                if exhaustive {
                    // Every candidate the rules refuse (the play included) the play refuses too.
                    for candidate in all where candidate != .play && rules.apply(candidate, to: state) == nil {
                        #expect(Self.applied(play, candidate, fingerprint: fingerprint) == nil)
                    }
                }
                if !legal.isEmpty {
                    for _ in 0..<Self.sampledLegal {
                        let move: Action = legal[random.int(0...(legal.count - 1))]
                        let after: Play? = Self.applied(play, move, fingerprint: fingerprint)
                        #expect(after != nil)
                        if let after { #expect(rules.apply(move, to: state) == Self.position(after)) }
                    }
                }
                for _ in 0..<Self.sampledCandidates {
                    let candidate: Action = Support.candidate(&random, state: state)
                    if candidate == .play { continue }
                    let byPlay: Bool = Self.applied(play, candidate, fingerprint: fingerprint) != nil
                    #expect(byPlay == (rules.apply(candidate, to: state) != nil))
                }
                // The goal equals the play's predicted report and the outcome of its play action.
                let solved: Bool = rules.isSolved(state)
                #expect(solved == play.report.wins)
                let ended: Play? = Self.applied(play, .play, fingerprint: fingerprint)
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
    }
}
