// AuroraLoomWitnessTests — feature 302 (R02-G01-02) T-R02G0102-005 (FR-R02G0102-004; clarification Q4; research R6, R7).
// Witnesses of seeded fixture levels with hand-built shortest solutions: the stored form round-trips byte for byte with
// one trailing newline; the counterexample loses and names a ribbon, gate and tick in range; newer, damaged and edited
// stored forms are refused; a solution that does not win is refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreSimulation

@Suite struct AuroraLoomWitnessTests {
    /// The moves from `start` to `winning`: by ribbon, wave before phase, one per differing control.
    static func moves(from start: AuroraLoomSteps, to winning: AuroraLoomSteps) -> [AuroraLoomMove] {
        var result: [AuroraLoomMove] = []
        for ribbon in 0..<3 {
            if start.wave[ribbon] != winning.wave[ribbon] {
                result.append(AuroraLoomMove(ribbon: ribbon, control: .wave, step: winning.wave[ribbon]))
            }
            if start.phase[ribbon] != winning.phase[ribbon] {
                result.append(AuroraLoomMove(ribbon: ribbon, control: .phase, step: winning.phase[ribbon]))
            }
        }
        return result
    }

    /// Whether some proper prefix of `moves` already wins (the play would then refuse the next move).
    static func winsEarly(_ moves: [AuroraLoomMove], level: AuroraLoomLevel) -> Bool {
        var steps: AuroraLoomSteps = level.startSteps
        for index in 0..<(moves.count - 1) {
            let move: AuroraLoomMove = moves[index]
            switch move.control {
            case .wave: steps.wave[move.ribbon] = move.step
            case .phase: steps.phase[move.ribbon] = move.step
            }
            if AuroraLoomHarmony.wins(steps, level: level) { return true }
        }
        return false
    }

    /// A generated level built by hand from a fixture, or nil when the fixture does not suit (too many moves for the
    /// allowance, or an earlier prefix already wins).
    static func generated(_ fixture: AuroraLoomFixture, moves override: [AuroraLoomMove]? = nil) -> AuroraLoomGenerated? {
        let level: AuroraLoomLevel = fixture.level
        let moves: [AuroraLoomMove] = override ?? Self.moves(from: level.startSteps, to: fixture.winning)
        guard !moves.isEmpty, moves.count <= level.allowance, !winsEarly(moves, level: level) else { return nil }
        let solution = AuroraLoomSolution(shortest: moves.count, moves: moves, setting: fixture.winning, work: 17,
                                          winningSettings: [1, 1, 1], method: .grid)
        let difficulty = AuroraLoomDifficulty(level: level, solution: solution)
        let entry = AuroraLoomManifestEntry(number: 1, seed: level.seed, band: level.band, budget: level.allowance)
        return AuroraLoomGenerated(entry: entry, level: level, solution: solution, difficulty: difficulty, skipped: 0)
    }

    /// `count` seeded witnesses.
    static func witnesses(_ count: Int) throws -> [AuroraLoomWitness] {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var result: [AuroraLoomWitness] = []
        var draws: Int = 0
        while result.count < count {
            draws += 1
            precondition(draws < 10 * count, "too few suitable fixtures")
            guard let fixture = AuroraLoomFixture.make(&random), let generated = generated(fixture) else { continue }
            result.append(try AuroraLoomWitness(generated))
        }
        return result
    }

    /// The stored JSON of `witness` edited by `edit`.
    static func edited(_ witness: AuroraLoomWitness, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: witness.encoded()) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func fiftySeededWitnessesRoundTrip() throws {
        let witnesses: [AuroraLoomWitness] = try Self.witnesses(50)
        var tutorials: Int = 0
        for witness in witnesses {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: AuroraLoomWitness = try AuroraLoomWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            #expect(witness.fingerprints.count == witness.actions.count + 1)
            #expect(witness.actions.count == witness.difficulty.shortest)
            #expect(witness.method == .grid)
            #expect(witness.number == 1)
            if witness.level.tutorial { tutorials += 1 }
        }
        #expect(tutorials > 0 && tutorials < 50)
    }

    @Test func terminalHoldsAndCounterexampleLoses() throws {
        for witness in try Self.witnesses(20) {
            let level: AuroraLoomLevel = witness.level
            #expect(abs(witness.terminal.residual) <= level.tolerance)
            let mismatch: AuroraLoomMismatch = witness.counterexample.mismatch
            #expect(abs(mismatch.residual) > level.tolerance)
            #expect((0..<3).contains(mismatch.ribbon))
            #expect((0..<4).contains(mismatch.gate))
            #expect((0..<(2 * level.period)).contains(mismatch.tick))
            #expect(!AuroraLoomHarmony.wins(witness.counterexample.setting, level: level))
        }
    }

    @Test func refusals() throws {
        let witness: AuroraLoomWitness = try #require(try Self.witnesses(1).first)
        let newer: Data = try Self.edited(witness) { $0["schema"] = 2 }
        #expect(throws: AuroraLoomError.newerSchema(2)) { try AuroraLoomWitness.decode(newer) }
        let older: Data = try Self.edited(witness) { $0["schema"] = 0 }
        #expect(throws: AuroraLoomError.malformed("schema 0")) { try AuroraLoomWitness.decode(older) }
        let damaged: Data = witness.encoded().prefix(40)
        #expect(throws: AuroraLoomError.malformed("unreadable")) { try AuroraLoomWitness.decode(damaged) }
        let missing: Data = try Self.edited(witness) { $0.removeValue(forKey: "terminal") }
        #expect(throws: AuroraLoomError.malformed("unreadable")) { try AuroraLoomWitness.decode(missing) }

        let action: Data = try Self.edited(witness) { object in
            var actions: [[String: Any]] = object["actions"] as! [[String: Any]]
            let step: Int = actions[0]["step"] as! Int
            actions[0]["step"] = (step + 1) % 16
            object["actions"] = actions
        }
        #expect(throws: AuroraLoomError.self) { try AuroraLoomWitness.decode(action) }

        let fingerprint: Data = try Self.edited(witness) { object in
            var fingerprints: [String] = object["fingerprints"] as! [String]
            fingerprints[fingerprints.count - 1] = String(repeating: "0", count: 64)
            object["fingerprints"] = fingerprints
        }
        #expect(throws: AuroraLoomError.witness("fingerprints")) { try AuroraLoomWitness.decode(fingerprint) }

        let terminal: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["terminal"] as! [String: Any]
            value["residual"] = (value["residual"] as! Int) + 1
            object["terminal"] = value
        }
        #expect(throws: AuroraLoomError.witness("terminal")) { try AuroraLoomWitness.decode(terminal) }

        let counter: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["counterexample"] as! [String: Any]
            var mismatch: [String: Any] = value["mismatch"] as! [String: Any]
            mismatch["tick"] = (mismatch["tick"] as! Int) + 1
            value["mismatch"] = mismatch
            object["counterexample"] = value
        }
        #expect(throws: AuroraLoomError.witness("counterexample")) { try AuroraLoomWitness.decode(counter) }

        let shortest: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["difficulty"] as! [String: Any]
            value["shortest"] = (value["shortest"] as! Int) + 1
            object["difficulty"] = value
        }
        #expect(throws: AuroraLoomError.witness("difficulty")) { try AuroraLoomWitness.decode(shortest) }

        let tolerance: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["difficulty"] as! [String: Any]
            value["tolerance"] = (value["tolerance"] as! Int) + 1
            object["difficulty"] = value
        }
        #expect(throws: AuroraLoomError.witness("difficulty")) { try AuroraLoomWitness.decode(tolerance) }

        let levelEdit: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["level"] as! [String: Any]
            value["allowance"] = 64
            object["level"] = value
        }
        #expect(throws: AuroraLoomError.malformed("unreadable")) { try AuroraLoomWitness.decode(levelEdit) }
    }

    @Test func aSolutionThatDoesNotWinIsRefused() throws {
        var random: SeededRandom = SeededRandom(seed: 2_301)
        var checked: Int = 0
        while checked < 5 {
            guard let fixture = AuroraLoomFixture.make(&random) else { continue }
            let full: [AuroraLoomMove] = Self.moves(from: fixture.level.startSteps, to: fixture.winning)
            guard full.count >= 2 else { continue }
            let short: [AuroraLoomMove] = Array(full.dropLast())
            guard let generated = Self.generated(fixture, moves: short),
                  !AuroraLoomHarmony.wins(fixture.level.startSteps, level: fixture.level) else { continue }
            var last: AuroraLoomSteps = fixture.level.startSteps
            for move in short {
                if move.control == .wave { last.wave[move.ribbon] = move.step } else { last.phase[move.ribbon] = move.step }
            }
            guard !AuroraLoomHarmony.wins(last, level: fixture.level) else { continue }
            #expect(throws: AuroraLoomError.witness("replay")) { try AuroraLoomWitness(generated) }
            checked += 1
        }
    }

    @Test func reasonCodes() {
        #expect(AuroraLoomError.witness("replay").reasonCode == "r02-g01.witness")
        #expect(AuroraLoomError.witness("counterexample").reasonCode == "r02-g01.witness")
        #expect(AuroraLoomError.generation(1).reasonCode == "r02-g01.generation")
    }
}
