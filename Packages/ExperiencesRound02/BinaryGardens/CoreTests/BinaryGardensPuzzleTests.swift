// BinaryGardensPuzzleTests — feature 501 (R02-G21-01) T-R02G2101-005 (FR-R02G2101-010; research R14). The R02-F23
// puzzle contract of Binary Gardens: the rules id and the start position; the legal moves in the order of research R14
// (star 1 then star 2: rings ascending, phases 0 … 47, luminosities ascending; then tilts 0 … T_max), each skipping the
// current value, locked controls and separation breakers, compared with an independent enumeration; exactly 120 moves on
// the largest level (8 rings, 4 luminosities, T_max 6, everything adjustable, no separation); none with the budget spent
// or for a position without the level's shape; the run and refused moves give nil; the goal test is the predicted win;
// and agreement with the play on 200 seeded walks (a move is legal in the puzzle exactly when the play accepts it in
// `playing` with actions left, and both produce the same arrangement and actions spent). Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensPuzzleTests {
    typealias Puzzle = BinaryGardensPuzzle
    typealias Position = BinaryGardensPuzzle.Position
    typealias Action = BinaryGardensAction
    typealias Level = BinaryGardensLevel
    typealias Star = BinaryGardensStar
    typealias World = BinaryGardensWorld
    typealias Arrangement = BinaryGardensArrangement
    typealias Play = BinaryGardensPlay
    typealias Sky = BinaryGardensSky

    /// The fixtures of the feature seed used here.
    static let fixtures: [BinaryGardensFixture] = BinaryGardensFixture.all(count: 50)

    /// An independent enumeration of the legal moves: every candidate of R14's order whose new arrangement is in range,
    /// on an adjustable control, changed and keeps the separation (checked here by hand).
    static func handMoves(_ state: Position, level: Level) -> [Action] {
        guard state.actionsSpent < level.budget else { return [] }
        let a: Arrangement = state.arrangement
        var moves: [Action] = []
        func keeps(_ next: Arrangement) -> Bool { Sky.keepsSeparation(level, arrangement: next) }
        for star in 0..<2 {
            var rings: [Int] = a.rings
            for index in 0..<level.ringRadii.count where level.stars[star].ringAdjustable && index != a.rings[star] {
                rings[star] = index
                if keeps(Arrangement(rings: rings, phases: a.phases, luminosities: a.luminosities, tilt: a.tilt)) {
                    moves.append(.ring(star: star, index: index))
                }
            }
            var phases: [Int] = a.phases
            for step in 0..<48 where level.stars[star].phaseAdjustable && step != a.phases[star] {
                phases[star] = step
                if keeps(Arrangement(rings: a.rings, phases: phases, luminosities: a.luminosities, tilt: a.tilt)) {
                    moves.append(.phase(star: star, step: step))
                }
            }
            var luminosities: [Int] = a.luminosities
            for index in 0..<level.luminosityLevels.count
            where level.stars[star].luminosityAdjustable && index != a.luminosities[star] {
                luminosities[star] = index
                if keeps(Arrangement(rings: a.rings, phases: a.phases, luminosities: luminosities, tilt: a.tilt)) {
                    moves.append(.luminosity(star: star, index: index))
                }
            }
        }
        if level.maxTilt > 0 {
            for step in 0...level.maxTilt where step != a.tilt {
                if keeps(Arrangement(rings: a.rings, phases: a.phases, luminosities: a.luminosities, tilt: step)) {
                    moves.append(.tilt(step: step))
                }
            }
        }
        return moves
    }

    /// The largest level: rings 1, 6, 11, … 36, star speed 2, luminosities 1, 8, 27, 64, both stars fully adjustable,
    /// T_max 6, no separation, one world never blooming.
    static func largest(budget: Int = 24) throws -> Level {
        let stars: [Star] = [
            Star(ring: 0, phase: 0, luminosity: 0, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: true),
            Star(ring: 7, phase: 24, luminosity: 3, ringAdjustable: true, phaseAdjustable: true,
                 luminosityAdjustable: true),
        ]
        let world = World(radius: 50, phase: 0, speed: 1, lethalLow: 0, comfortLow: 1, comfortHigh: 199_999,
                          lethalHigh: 200_000, window: 1, bloomLow: 9_600_000, bloomHigh: 9_600_000)
        return try Level(id: "largest", seed: 1, difficulty: 5, ringRadii: [1, 6, 11, 16, 21, 26, 31, 36],
                         starSpeed: 2, luminosityLevels: [1, 8, 27, 64], stars: stars, maxTilt: 6, startTilt: 3,
                         minimumSeparation: 0, clampRadius: 2, worlds: [world], lethalTolerance: 3, budget: budget,
                         tutorial: false)
    }

    @Test func rulesIDAndStart() throws {
        let fixture: BinaryGardensFixture = Self.fixtures[0]
        let puzzle = Puzzle(level: fixture.level)
        #expect(puzzle.rulesID == "r02-g21-binary-gardens")
        #expect(puzzle.initialState == Position(arrangement: fixture.level.start, actionsSpent: 0))
        #expect(!puzzle.isSolved(puzzle.initialState))
        #expect(puzzle.isSolved(Position(arrangement: fixture.winning, actionsSpent: 0)))
        let data: Data = try JSONEncoder().encode(puzzle.initialState)
        #expect(try JSONDecoder().decode(Position.self, from: data) == puzzle.initialState)
    }

    @Test func moveOrderAndRefusals() throws {
        let level: Level = try Self.largest()
        let puzzle = Puzzle(level: level)
        let moves: [Action] = puzzle.moves(in: puzzle.initialState)
        #expect(moves.count == 120)
        #expect(moves == Self.handMoves(puzzle.initialState, level: level))
        #expect(moves.first == .ring(star: 0, index: 1) && moves.last == .tilt(step: 6))
        #expect(moves[7] == .phase(star: 0, step: 1) && moves[54] == .luminosity(star: 0, index: 1))
        #expect(moves[57] == .ring(star: 1, index: 0) && moves[114] == .tilt(step: 0))
        #expect(Set(moves).count == 120)
        for move in moves {
            let next: Position? = puzzle.apply(move, to: puzzle.initialState)
            #expect(next?.actionsSpent == 1)
            #expect(next.map { Sky.isWellFormed(level, $0.arrangement) } == true)
        }
        // Refused: the run, an unchanged value, out of range, a spent budget, a position without the level's shape.
        #expect(puzzle.apply(.run, to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.tilt(step: 3), to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.tilt(step: 7), to: puzzle.initialState) == nil)
        #expect(puzzle.apply(.ring(star: 2, index: 0), to: puzzle.initialState) == nil)
        let spent = Position(arrangement: level.start, actionsSpent: 24)
        #expect(puzzle.moves(in: spent).isEmpty && puzzle.apply(.tilt(step: 1), to: spent) == nil)
        let bad = Position(arrangement: Arrangement(rings: [0], phases: [0, 0], luminosities: [0, 0], tilt: 0),
                           actionsSpent: 0)
        #expect(puzzle.moves(in: bad).isEmpty && puzzle.apply(.tilt(step: 1), to: bad) == nil && !puzzle.isSolved(bad))
        let wild = Position(arrangement: Arrangement(rings: [0, 9], phases: [0, 0], luminosities: [0, 0], tilt: 0),
                            actionsSpent: 0)
        #expect(puzzle.moves(in: wild).isEmpty && !puzzle.isSolved(wild))
        #expect(puzzle.moves(in: Position(arrangement: level.start, actionsSpent: -1)).isEmpty)
        // Locked controls and separation breakers are skipped (the play's hand level: star 1's phase is locked, star 2
        // at phase 0 would break the separation).
        let hand: Level = try BinaryGardensPlayTests.hand()
        let handPuzzle = Puzzle(level: hand)
        let handMoves: [Action] = handPuzzle.moves(in: handPuzzle.initialState)
        #expect(handMoves == Self.handMoves(handPuzzle.initialState, level: hand))
        #expect(!handMoves.contains(.phase(star: 0, step: 5)) && !handMoves.contains(.phase(star: 1, step: 0)))
        #expect(!handMoves.contains(.luminosity(star: 1, index: 0)) && handMoves.contains(.phase(star: 1, step: 12)))
        #expect(handPuzzle.apply(.phase(star: 1, step: 0), to: handPuzzle.initialState) == nil)
        // Every fixture: the known actions are legal moves and reach a solved position.
        for fixture in Self.fixtures {
            let rules = Puzzle(level: fixture.level)
            var state: Position = rules.initialState
            #expect(rules.moves(in: state) == Self.handMoves(state, level: fixture.level))
            for action in fixture.actions.dropLast() {
                #expect(rules.moves(in: state).contains(action))
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("known action refused")
                    break
                }
                state = next
            }
            #expect(rules.isSolved(state) && state.arrangement == fixture.winning)
            #expect(rules.moves(in: state).count <= 120)
        }
    }

    @Test(arguments: [0, 1, 2, 3])
    func agreesWithThePlayOnSeededWalks(quarter: Int) throws {
        var random = SeededRandom(seed: 2_501 + UInt64(quarter))
        var compared: Int = 0
        for walk in 0..<50 {
            let fixture: BinaryGardensFixture = Self.fixtures[(walk + quarter * 50) % Self.fixtures.count]
            let rules = Puzzle(level: fixture.level)
            var play = Play(level: fixture.level)
            try play.handle(.begin)
            var state: Position = rules.initialState
            for _ in 0..<(fixture.level.budget + 6) {
                let legal: [Action] = rules.moves(in: state)
                let move: Action
                if !legal.isEmpty && random.int(0...2) > 0 {
                    move = legal[random.int(0...(legal.count - 1))]
                } else {
                    move = BinaryGardensPlayTests.randomAction(&random, level: fixture.level)
                }
                let next: Position? = rules.apply(move, to: state)
                var trial: Play = play
                let accepted: Bool = (try? trial.apply(move, expecting: trial.fingerprint)) != nil
                if case .run = move {
                    #expect(next == nil)
                    continue
                }
                #expect(accepted == (next != nil), "\(move)")
                #expect(legal.contains(move) == (next != nil))
                if let next, accepted {
                    #expect(next.arrangement == trial.arrangement && next.actionsSpent == trial.actionsSpent)
                    #expect(rules.isSolved(next) == trial.report.wins)
                    state = next
                    play = trial
                }
                compared += 1
            }
        }
        #expect(compared > 300)
    }
}
