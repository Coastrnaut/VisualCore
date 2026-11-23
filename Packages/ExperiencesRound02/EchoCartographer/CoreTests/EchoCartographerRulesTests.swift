// EchoCartographerRulesTests — feature 401 (R02-G11-01) T-R02G1101-005 (FR-R02G1101-010). The rules as an R02-F23
// puzzle contract, on their own: the rules id and start position; the legal move order (pulses, then claims, each in
// cell-index order) and exact counts on the hand level after known steps, and against a brute force over every pulse,
// claim and marker cell one outside the chamber, on the hand level and seeded fixtures (seed 2_401) along seeded random
// walks; claims near only located beacons left out while a claim near a located and an unlocated beacon stays; a miss
// that spends min(miss cost, energy) and reveals nothing; every fixture's known actions (pulses, then claims) legal in
// order and winning exactly on the last; terminal positions without moves; the energy failure. The agreement with
// `EchoCartographerPlay` (200 seeded walks) is in EchoCartographerRulesAgreementTests. Explicit types, plain loops;
// each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite("EchoCartographerRules")
struct EchoCartographerRulesTests {
    typealias Rules = EchoCartographerRules
    typealias Position = EchoCartographerRules.Position

    /// The number of fixture levels checked.
    static let fixtureCount: Int = 100
    /// The brute-force walk seed.
    static let walkSeed: UInt64 = 2_401
    /// The number of brute-force walks.
    static let walkCount: Int = 60

    /// The cell of a pulse, claim or marker.
    static func cell(_ action: EchoCartographerAction) -> EchoCartographerCell {
        switch action {
        case let .pulse(x, y), let .claim(x, y), let .mark(x, y): return EchoCartographerCell(x: x, y: y)
        }
    }

    /// Whether `action` is a pulse.
    static func isPulse(_ action: EchoCartographerAction) -> Bool {
        if case .pulse = action { return true }
        return false
    }

    /// The legal moves of `state` by brute force, independently of the rules: every pulse from an inside cell known
    /// open, then every claim on an inside cell not known wall that has an unlocated beacon within the tolerance or no
    /// beacon at all within it; each group in row-major order.
    static func bruteForce(_ level: EchoCartographerLevel, _ state: Position) -> [EchoCartographerAction] {
        guard state.outcome == .playing else { return [] }
        var pulses: [EchoCartographerAction] = []
        var claims: [EchoCartographerAction] = []
        for y in 0..<level.chamber.height {
            for x in 0..<level.chamber.width {
                let cell = EchoCartographerCell(x: x, y: y)
                let known: EchoCartographerKnown = state.knowledge[y * level.chamber.width + x]
                if known == .open { pulses.append(.pulse(x, y)) }
                if known == .wall { continue }
                var near: Int = 0
                var nearUnlocated: Int = 0
                for (index, beacon) in level.beacons.enumerated() {
                    let distance: Int = max(abs(beacon.x - cell.x), abs(beacon.y - cell.y))
                    if distance > level.tolerance { continue }
                    near += 1
                    if !state.located.contains(index) { nearUnlocated += 1 }
                }
                if near == 0 || nearUnlocated > 0 { claims.append(.claim(x, y)) }
            }
        }
        return pulses + claims
    }

    /// Checks `rules.moves(in: state)` against the brute force, in order, and that `apply` accepts exactly the listed
    /// moves among every pulse, claim and marker one cell around the chamber.
    static func checkMoves(_ rules: Rules, _ state: Position, _ label: String) {
        let level: EchoCartographerLevel = rules.level
        let listed: [EchoCartographerAction] = rules.moves(in: state)
        let expected: [EchoCartographerAction] = bruteForce(level, state)
        #expect(listed == expected, "\(label)")
        let legal: Set<EchoCartographerAction> = Set(listed)
        #expect(legal.count == listed.count, "\(label) duplicates")
        var accepted: Int = 0
        for y in -1...level.chamber.height {
            for x in -1...level.chamber.width {
                let candidates: [EchoCartographerAction] = [.pulse(x, y), .claim(x, y), .mark(x, y)]
                for action in candidates {
                    let applied: Bool = rules.apply(action, to: state) != nil
                    #expect(applied == legal.contains(action), "\(label) \(action)")
                    if applied { accepted += 1 }
                }
            }
        }
        #expect(accepted == legal.count, "\(label)")
    }

    @Test("rules id and initial position")
    func initialPosition() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let rules = Rules(level: level)
        #expect(rules.rulesID == "r02-g11-echo-cartographer")
        let start: Position = rules.initialState
        #expect(start.knowledge == level.openingKnowledge)
        #expect(start.knowledge[level.entry] == .open)
        #expect(start.knowledge.revealed.open == 1)
        #expect(start.knowledge.revealed.wall == 0)
        #expect(start.located.isEmpty)
        #expect(start.energy == 6)
        #expect(start.outcome == .playing)
        #expect(!rules.isSolved(start))
    }

    @Test("legal moves: exact order and counts on the hand level")
    func handOrderAndCounts() throws {
        let rules = Rules(level: EchoCartographerFixtures.handLevel())
        let start: Position = rules.initialState
        let opening: [EchoCartographerAction] = rules.moves(in: start)
        // One pulse (the entry), then a claim on each of the 35 cells (nothing known wall, nothing located).
        #expect(opening.count == 36)
        #expect(opening[0] == .pulse(0, 0))
        #expect(opening[1] == .claim(0, 0))
        #expect(opening[2] == .claim(1, 0))
        #expect(opening[8] == .claim(0, 1))
        #expect(opening[35] == .claim(6, 4))
        Self.checkMoves(rules, start, "hand start")

        // The pulse from the entry: east reveals (1, 0), (2, 0) open and (3, 0) wall; south (0, 1) … (0, 4) open.
        let pulsed: Position = try #require(rules.apply(.pulse(0, 0), to: start))
        #expect(pulsed.energy == 5)
        #expect(pulsed.outcome == .playing)
        #expect(pulsed.knowledge.revealed.open == 7)
        #expect(pulsed.knowledge.revealed.wall == 1)
        #expect(pulsed.knowledge[EchoCartographerCell(x: 3, y: 0)] == .wall)
        let afterPulse: [EchoCartographerAction] = rules.moves(in: pulsed)
        let expectedPulses: [EchoCartographerAction] = [.pulse(0, 0), .pulse(1, 0), .pulse(2, 0), .pulse(0, 1),
                                                        .pulse(0, 2), .pulse(0, 3), .pulse(0, 4)]
        #expect(Array(afterPulse.prefix(7)) == expectedPulses)
        #expect(afterPulse.count == 7 + 34)
        #expect(!afterPulse.contains(.claim(3, 0)))
        #expect(rules.apply(.claim(3, 0), to: pulsed) == nil)
        #expect(rules.apply(.pulse(1, 1), to: pulsed) == nil)
        Self.checkMoves(rules, pulsed, "hand pulsed")

        // The level orders its beacons by row, then column: beacon 0 is (6, 0), beacon 1 is (2, 2).
        #expect(rules.level.beacons == [EchoCartographerCell(x: 6, y: 0), EchoCartographerCell(x: 2, y: 2)])
        // A hit on (2, 2) locates beacon 1, free, and makes its cell known open; its 3 × 3 neighbourhood (near only
        // the located beacon) leaves the claims.
        let hit: Position = try #require(rules.apply(.claim(2, 2), to: pulsed))
        #expect(hit.located == [1])
        #expect(hit.energy == 5)
        #expect(hit.knowledge[EchoCartographerCell(x: 2, y: 2)] == .open)
        let afterHit: [EchoCartographerAction] = rules.moves(in: hit)
        #expect(afterHit.filter { Self.isPulse($0) }.count == 8)
        #expect(afterHit.count == 8 + 25)
        for y in 1...3 {
            for x in 1...3 {
                #expect(!afterHit.contains(.claim(x, y)), "(\(x), \(y))")
                #expect(rules.apply(.claim(x, y), to: hit) == nil, "(\(x), \(y))")
            }
        }
        Self.checkMoves(rules, hit, "hand hit")
        for index in 1..<afterHit.count {
            let a: EchoCartographerAction = afterHit[index - 1]
            let b: EchoCartographerAction = afterHit[index]
            if Self.isPulse(a) == Self.isPulse(b) {
                #expect(Self.cell(a) < Self.cell(b), "\(a) before \(b)")
            } else {
                #expect(Self.isPulse(a) && !Self.isPulse(b), "\(a) before \(b)")
            }
        }
    }

    @Test("a claim near a located and an unlocated beacon stays legal and locates the unlocated one")
    func claimsNearLocatedBeacons() throws {
        // Tolerance 2: (4, 1) is within 2 of (2, 2) and of (6, 0).
        let rules = Rules(level: EchoCartographerFixtures.handLevel(tolerance: 2, energy: 6))
        let first: Position = try #require(rules.apply(.claim(2, 2), to: rules.initialState))
        #expect(first.located == [1])
        // (0, 4) is within 2 of (2, 2) only: refused now.
        #expect(rules.apply(.claim(0, 4), to: first) == nil)
        #expect(!rules.moves(in: first).contains(.claim(0, 4)))
        #expect(rules.moves(in: first).contains(.claim(4, 1)))
        let second: Position = try #require(rules.apply(.claim(4, 1), to: first))
        #expect(second.located == [0, 1])
        #expect(second.knowledge[EchoCartographerCell(x: 6, y: 0)] == .open)
        #expect(second.outcome == .won)
        #expect(rules.isSolved(second))
        #expect(second.energy == 6)
        // The nearest unlocated beacon is the one located: (3, 1) is 1 from (2, 2) and 3 from (6, 0).
        let nearest: Position = try #require(rules.apply(.claim(3, 1), to: rules.initialState))
        #expect(nearest.located == [1])
    }

    @Test("a miss spends min(miss cost, energy) and reveals nothing")
    func misses() throws {
        let rules = Rules(level: EchoCartographerFixtures.handLevel(tolerance: 1, energy: 3, missCost: 2))
        let start: Position = rules.initialState
        // (0, 4) is 2 from (2, 2) and 6 from (6, 0): a miss.
        let missed: Position = try #require(rules.apply(.claim(0, 4), to: start))
        #expect(missed.energy == 1)
        #expect(missed.knowledge == start.knowledge)
        #expect(missed.located.isEmpty)
        #expect(missed.outcome == .playing)
        // The second miss costs only the 1 energy left, and fails with both beacons hidden.
        let again: Position = try #require(rules.apply(.claim(0, 4), to: missed))
        #expect(again.energy == 0)
        #expect(again.knowledge == start.knowledge)
        #expect(again.outcome == .failed)
        #expect(rules.moves(in: again).isEmpty)
    }

    @Test("fixture actions are legal in order and win exactly on the last one")
    func fixtureSolutions() throws {
        var solved: Int = 0
        var starved: Int = 0
        for fixture in EchoCartographerFixtures.fixtures(Self.fixtureCount) {
            let rules = Rules(level: fixture.level)
            // A fixture whose energy only pays its pulses fails on the last pulse (energy 0, beacons hidden): the
            // known actions cannot win it. Checked as a failure and counted.
            if fixture.level.energy <= fixture.pulses.count {
                var state: Position = rules.initialState
                for cell in fixture.pulses {
                    state = try #require(rules.apply(.pulse(cell.x, cell.y), to: state))
                }
                #expect(state.energy == 0, "\(fixture.level.id)")
                #expect(state.outcome == .failed, "\(fixture.level.id)")
                #expect(rules.moves(in: state).isEmpty, "\(fixture.level.id)")
                starved += 1
                continue
            }
            solved += 1
            var state: Position = rules.initialState
            var actions: [EchoCartographerAction] = []
            for cell in fixture.pulses { actions.append(.pulse(cell.x, cell.y)) }
            for cell in fixture.claims { actions.append(.claim(cell.x, cell.y)) }
            for index in actions.indices {
                let action: EchoCartographerAction = actions[index]
                #expect(state.outcome == .playing, "\(fixture.level.id) step \(index)")
                #expect(rules.moves(in: state).contains(action), "\(fixture.level.id) step \(index)")
                guard let next = rules.apply(action, to: state) else {
                    Issue.record("\(fixture.level.id) refused step \(index)")
                    break
                }
                state = next
                let last: Bool = index == actions.count - 1
                #expect(state.outcome == (last ? .won : .playing), "\(fixture.level.id) step \(index)")
            }
            #expect(rules.isSolved(state), "\(fixture.level.id)")
            #expect(state.located == Array(0..<fixture.level.beacons.count), "\(fixture.level.id)")
            #expect(state.energy == fixture.level.energy - fixture.pulses.count, "\(fixture.level.id)")
            #expect(rules.moves(in: state).isEmpty)
        }
        #expect(solved + starved == Self.fixtureCount)
        #expect(solved >= Self.fixtureCount / 2)
    }

    @Test("seeded walks: moves match the brute force at every step")
    func walksMatchBruteForce() {
        var random = SeededRandom(seed: Self.walkSeed)
        var won: Int = 0
        var failed: Int = 0
        var steps: Int = 0
        for walk in 0..<Self.walkCount {
            let fixture: EchoCartographerFixture = EchoCartographerFixtures.fixture(Self.walkSeed &+ UInt64(walk))
            let rules = Rules(level: fixture.level)
            var state: Position = rules.initialState
            var step: Int = 0
            while state.outcome == .playing {
                Self.checkMoves(rules, state, "walk \(walk) step \(step)")
                let moves: [EchoCartographerAction] = rules.moves(in: state)
                guard !moves.isEmpty else {
                    Issue.record("walk \(walk) step \(step): no moves while playing")
                    break
                }
                var move: EchoCartographerAction = moves[random.int(0...(moves.count - 1))]
                if walk % 3 == 0 {
                    let known: Int = fixture.pulses.count
                    if step < known {
                        move = .pulse(fixture.pulses[step].x, fixture.pulses[step].y)
                    } else if step - known < fixture.claims.count {
                        move = .claim(fixture.claims[step - known].x, fixture.claims[step - known].y)
                    }
                }
                guard let next = rules.apply(move, to: state) else {
                    Issue.record("walk \(walk) step \(step): refused a listed move \(move)")
                    break
                }
                #expect(next.energy >= 0)
                #expect(next.energy <= state.energy)
                #expect(next.located.count >= state.located.count)
                state = next
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
    }

    @Test("terminal positions offer no moves and refuse every action")
    func terminalPositions() {
        let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        let rules = Rules(level: level)
        let listed: [EchoCartographerAction] = rules.moves(in: rules.initialState)
        #expect(!listed.isEmpty)
        for outcome in [Position.Outcome.won, .failed] {
            let state = Position(knowledge: level.openingKnowledge, located: [0], energy: 2, outcome: outcome)
            #expect(rules.moves(in: state).isEmpty)
            for action in listed { #expect(rules.apply(action, to: state) == nil, "\(outcome) \(action)") }
            #expect(rules.isSolved(state) == (outcome == .won))
        }
    }

    @Test("energy failure: the last energy spent with a beacon hidden fails; a hit on the last beacon wins")
    func energyFailure() throws {
        // Energy 1: the pulse spends it with both beacons hidden.
        let tight = Rules(level: EchoCartographerFixtures.handLevel(energy: 1))
        let pulsed: Position = try #require(tight.apply(.pulse(0, 0), to: tight.initialState))
        #expect(pulsed.energy == 0)
        #expect(pulsed.outcome == .failed)
        #expect(tight.moves(in: pulsed).isEmpty)
        #expect(tight.apply(.claim(2, 2), to: pulsed) == nil)
        // Energy 1: hits are free, so both claims locate and the second wins with the energy untouched.
        let first: Position = try #require(tight.apply(.claim(2, 2), to: tight.initialState))
        #expect(first.outcome == .playing)
        let won: Position = try #require(tight.apply(.claim(6, 0), to: first))
        #expect(won.outcome == .won)
        #expect(won.energy == 1)
        // Miss cost 3 with 2 energy: the miss spends 2 and fails.
        let costly = Rules(level: EchoCartographerFixtures.handLevel(energy: 2, missCost: 3))
        let missed: Position = try #require(costly.apply(.claim(0, 4), to: costly.initialState))
        #expect(missed.energy == 0)
        #expect(missed.outcome == .failed)
        // Markers are never moves.
        #expect(costly.apply(.mark(0, 0), to: costly.initialState) == nil)
    }
}
