// WaveKnotKeeperWitnessTests — feature 322 (R02-G03-02) T-R02G0302-005 (FR-R02G0302-004; SC-R02G0302-005; clarification
// Q4). Witnesses of five generated catalog levels, one per band (manifest indices 0, 25, 45, 65, 85; number 1 has a
// tutorial). The stored form round-trips byte for byte with one trailing newline; edited moves, fingerprints, level,
// terminal, near miss, crossing counterexample and difficulty are refused; newer and damaged stored forms are refused; the
// near miss does not win and its summary is the losing rope's; the crossing counterexample is refused by the rules with
// `r02-g03.move`; a solution that does not win or has no crossing counterexample is refused by `make`.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import WaveKnotKeeperCore

@Suite struct WaveKnotKeeperWitnessTests {
    /// The manifest indices used, one per band.
    static let indices: [Int] = [0, 25, 45, 65, 85]

    /// The generated levels of ``indices``, built once.
    static let generated: [WaveKnotKeeperGenerated] = {
        var result: [WaveKnotKeeperGenerated] = []
        for index in indices {
            do {
                result.append(try WaveKnotKeeperGenerator.generate(WaveKnotKeeperManifest.entries[index]))
            } catch {
                preconditionFailure("manifest index \(index) does not generate: \(error)")
            }
        }
        return result
    }()

    /// The witnesses of ``generated``.
    static func witnesses() throws -> [WaveKnotKeeperWitness] {
        var result: [WaveKnotKeeperWitness] = []
        for g in generated { result.append(try WaveKnotKeeperWitness.make(g)) }
        return result
    }

    /// The winning rope of `witness`: its moves applied to the level's start.
    static func winning(_ witness: WaveKnotKeeperWitness) -> [WaveKnotKeeperPoint] {
        var rope: [WaveKnotKeeperPoint] = witness.level.points
        for move in witness.moves { rope[move.point] = rope[move.point].moved(move.direction) }
        return rope
    }

    /// The stored JSON of `witness` edited by `edit`.
    static func edited(_ witness: WaveKnotKeeperWitness, _ edit: (inout [String: Any]) -> Void) throws -> Data {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: witness.encoded()) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The refusal `decode` raises for `data`, or nil when it decodes.
    static func refusal(_ data: Data) -> WaveKnotKeeperError? {
        do {
            _ = try WaveKnotKeeperWitness.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// A stored move edited to step the opposite way.
    static func reversed(_ move: [String: Any]) -> [String: Any] {
        var result: [String: Any] = move
        let raw: String = move["direction"] as! String
        result["direction"] = WaveKnotKeeperDirection(rawValue: raw)!.opposite.rawValue
        return result
    }

    @Test func witnessesRoundTripByteForByte() throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses()
        var bands: [Int] = []
        var tutorials: Int = 0
        for witness in witnesses {
            let data: Data = witness.encoded()
            #expect(data.last == 0x0A)
            #expect(data.dropLast().last != 0x0A)
            let decoded: WaveKnotKeeperWitness = try WaveKnotKeeperWitness.decode(data)
            #expect(decoded == witness)
            #expect(decoded.encoded() == data)
            #expect(witness.fingerprints.count == witness.moves.count + 1)
            #expect(witness.moves.count == witness.difficulty.shortest)
            #expect(witness.terminal.crossings == witness.level.target.crossings)
            #expect(witness.terminal.writhe == witness.level.target.writhe)
            #expect(witness.terminal.tension <= witness.level.tensionBound)
            #expect(witness.level.wins(Self.winning(witness)))
            bands.append(witness.level.band)
            if witness.level.tutorial { tutorials += 1 }
        }
        #expect(bands == [1, 2, 3, 4, 5])
        #expect(tutorials == 1)
    }

    @Test func nearMissDoesNotWin() throws {
        for witness in try Self.witnesses() {
            let level: WaveKnotKeeperLevel = witness.level
            let rules = WaveKnotKeeperRules(level: level)
            let winning: [WaveKnotKeeperPoint] = Self.winning(witness)
            let next: [WaveKnotKeeperPoint] = try #require(rules.apply(witness.nearMiss.move, to: winning))
            #expect(!level.wins(next))
            let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(next)
            #expect(witness.nearMiss.crossings == summary.crossings)
            #expect(witness.nearMiss.writhe == summary.writhe)
            #expect(witness.nearMiss.degenerate == summary.degenerate)
            // Every legal move before it in the rules' order still wins.
            for move in rules.moves(in: winning) {
                if move == witness.nearMiss.move { break }
                let other: [WaveKnotKeeperPoint] = try #require(rules.apply(move, to: winning))
                #expect(level.wins(other))
            }
        }
    }

    @Test func crossingCounterexampleIsRefusedByTheRules() throws {
        for witness in try Self.witnesses() {
            let crossing: WaveKnotKeeperCrossingExample = witness.crossing
            let refusal: WaveKnotKeeperError? = WaveKnotKeeperPlay.refusal(of: crossing.move, points: crossing.points,
                                                                           level: witness.level)
            #expect(refusal == .move("crossing"))
            #expect(refusal?.reasonCode == "r02-g03.move")
            #expect(WaveKnotKeeperRules(level: witness.level).apply(crossing.move, to: crossing.points) == nil)
            #expect(crossing.points.count == witness.level.points.count)
        }
    }

    @Test func schemaAndDamageRefusals() throws {
        let witness: WaveKnotKeeperWitness = try #require(try Self.witnesses().first)
        let newer: Data = try Self.edited(witness) { $0["schema"] = 2 }
        #expect(Self.refusal(newer) == .newerSchema(2))
        let older: Data = try Self.edited(witness) { $0["schema"] = 0 }
        #expect(Self.refusal(older) == .witness("damaged"))
        let damaged: Data = witness.encoded().prefix(40)
        #expect(Self.refusal(damaged) == .witness("damaged"))
        let missing: Data = try Self.edited(witness) { $0.removeValue(forKey: "terminal") }
        #expect(Self.refusal(missing) == .witness("damaged"))
        let garbage: Data = Data("not json".utf8)
        #expect(Self.refusal(garbage) == .witness("damaged"))
        #expect(WaveKnotKeeperError.witness("damaged").reasonCode == "r02-g03.witness")
    }

    @Test func editedPartsAreRefused() throws {
        let witnesses: [WaveKnotKeeperWitness] = try Self.witnesses()
        let witness: WaveKnotKeeperWitness = witnesses[witnesses.count - 1]

        let move: Data = try Self.edited(witness) { object in
            var moves: [[String: Any]] = object["moves"] as! [[String: Any]]
            moves[0] = Self.reversed(moves[0])
            object["moves"] = moves
        }
        let moveRefusal: WaveKnotKeeperError? = Self.refusal(move)
        let moveParts: [WaveKnotKeeperError] = [.witness("replay"), .witness("fingerprints")]
        #expect(moveRefusal.map { moveParts.contains($0) } == true)

        let fingerprint: Data = try Self.edited(witness) { object in
            var fingerprints: [String] = object["fingerprints"] as! [String]
            fingerprints[fingerprints.count - 1] = String(repeating: "0", count: 64)
            object["fingerprints"] = fingerprints
        }
        #expect(Self.refusal(fingerprint) == .witness("fingerprints"))

        let levelEdit: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["level"] as! [String: Any]
            value["allowance"] = (value["allowance"] as! Int) == 64 ? 63 : (value["allowance"] as! Int) + 1
            object["level"] = value
        }
        #expect(Self.refusal(levelEdit) == .witness("level"))

        let tension: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["terminal"] as! [String: Any]
            value["tension"] = (value["tension"] as! Int) + 1
            object["terminal"] = value
        }
        #expect(Self.refusal(tension) == .witness("terminal"))

        let writhe: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["terminal"] as! [String: Any]
            value["writhe"] = (value["writhe"] as! Int) + 1
            object["terminal"] = value
        }
        #expect(Self.refusal(writhe) == .witness("terminal"))

        let nearCrossings: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nearMiss"] as! [String: Any]
            value["crossings"] = (value["crossings"] as! Int) + 1
            object["nearMiss"] = value
        }
        #expect(Self.refusal(nearCrossings) == .witness("nearMiss"))

        let nearMove: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["nearMiss"] as! [String: Any]
            value["move"] = Self.reversed(value["move"] as! [String: Any])
            object["nearMiss"] = value
        }
        #expect(Self.refusal(nearMove) == .witness("nearMiss"))

        // A crossing example whose move the rules accept: the winning rope with the near miss's move.
        let winning: [WaveKnotKeeperPoint] = Self.winning(witness)
        let legal = WaveKnotKeeperCrossingExample(points: winning, move: witness.nearMiss.move)
        let legalObject: Any = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legal))
        let crossingLegal: Data = try Self.edited(witness) { $0["crossing"] = legalObject }
        #expect(Self.refusal(crossingLegal) == .witness("crossing"))

        let crossingPoints: Data = try Self.edited(witness) { object in
            var value: [String: Any] = object["crossing"] as! [String: Any]
            var points: [[String: Any]] = value["points"] as! [[String: Any]]
            points.removeLast()
            value["points"] = points
            object["crossing"] = value
        }
        #expect(Self.refusal(crossingPoints) == .witness("crossing"))

        let difficultyKeys: [String] = ["shortest", "work", "crossings", "points", "gates"]
        for key in difficultyKeys {
            let data: Data = try Self.edited(witness) { object in
                var value: [String: Any] = object["difficulty"] as! [String: Any]
                value[key] = (value[key] as! Int) + 1
                object["difficulty"] = value
            }
            #expect(Self.refusal(data) == .witness("difficulty"), "difficulty.\(key)")
        }
    }

    @Test func aReFingerprintedLevelDoesNotReplay() throws {
        let witness: WaveKnotKeeperWitness = try #require(try Self.witnesses().last)
        let old: WaveKnotKeeperLevel = witness.level
        let other = try WaveKnotKeeperLevel(id: old.id, seed: old.seed, band: old.band, points: old.points,
                                            gates: old.gates, target: old.target, tensionBound: old.tensionBound,
                                            allowance: old.allowance == 64 ? 63 : old.allowance + 1,
                                            tutorial: old.tutorial)
        let replacement: Any = try JSONSerialization.jsonObject(with: other.encoded())
        let data: Data = try Self.edited(witness) { $0["level"] = replacement }
        #expect(Self.refusal(data) == .witness("fingerprints"))
    }

    @Test func makeRefusesASolutionThatDoesNotWinOrHasNoCrossing() throws {
        for g in Self.generated {
            let s: WaveKnotKeeperSolution = g.solution
            let short = WaveKnotKeeperSolution(shortest: s.shortest - 1, moves: Array(s.moves.dropLast()),
                                               final: s.final, work: s.work, crossing: s.crossing)
            let notWinning = WaveKnotKeeperGenerated(entry: g.entry, level: g.level, solution: short,
                                                     difficulty: g.difficulty, skipped: g.skipped)
            #expect(throws: WaveKnotKeeperError.witness("replay")) { try WaveKnotKeeperWitness.make(notWinning) }

            let bare = WaveKnotKeeperSolution(shortest: s.shortest, moves: s.moves, final: s.final, work: s.work,
                                              crossing: nil)
            let noCrossing = WaveKnotKeeperGenerated(entry: g.entry, level: g.level, solution: bare,
                                                     difficulty: g.difficulty, skipped: g.skipped)
            #expect(throws: WaveKnotKeeperError.witness("crossing")) { try WaveKnotKeeperWitness.make(noCrossing) }
        }
    }

    @Test func reasonCodes() {
        #expect(WaveKnotKeeperError.witness("near-miss").reasonCode == "r02-g03.witness")
        #expect(WaveKnotKeeperError.witness("crossing").reasonCode == "r02-g03.witness")
        #expect(WaveKnotKeeperError.move("crossing").reasonCode == "r02-g03.move")
    }
}
