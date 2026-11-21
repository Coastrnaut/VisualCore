// WaveKnotKeeperRegressionSolverTests — feature 328 (R02-G03-08) T-R02G0308-002 (FR-R02G0308-001, 002;
// SC-R02G0308-001, 002).
// The solver regression of all 100 certified levels, one test per band of 20 (clarification Q1): the generated level
// equals the level of its witness file in docs/games/wave-knot-keeper/levels (part by part and by fingerprint); the
// witness replays on a fresh play to a win in exactly its recorded moves with its recorded fingerprints, terminal, near
// miss and crossing counterexample; `WaveKnotKeeperSolver.solve` returns exactly the certified shortest, its moves win,
// its work stays within 3,661 ropes expanded (1 + 60 + 3,600) and equals the certified solution's work. Then the
// alterations of clarification Q2, each applied to a copy of a certified level or witness, must be reported by the same
// `check(level:witness:)` with a message naming the level and the part ("level 44: allowance differs").
// Seed 2_328 picks the altered control point. Explicit types, plain loops, short runs; work is counted, never timed.
@testable import WaveKnotKeeperCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/wave-knot-keeper/levels", isDirectory: true)

/// The stored level form, field by field, with its fingerprint as plain text so a test can change any one value.
fileprivate struct WaveKnotKeeperRegressionLevelMirror: Codable, Equatable {
    var schema: Int
    var id: String
    var seed: UInt64
    var band: Int
    var points: [WaveKnotKeeperPoint]
    var gates: [WaveKnotKeeperGate]
    var target: WaveKnotKeeperTarget
    var tensionBound: Int
    var allowance: Int
    var tutorial: Bool
    var fingerprint: String
}

/// The stored witness form, mirrored field by field so a test can change one value and encode it again exactly.
fileprivate struct WaveKnotKeeperRegressionWitnessMirror: Codable, Equatable {
    var schema: Int
    var number: Int
    var level: WaveKnotKeeperRegressionLevelMirror
    var moves: [WaveKnotKeeperMove]
    var fingerprints: [String]
    var terminal: WaveKnotKeeperTerminal
    var nearMiss: WaveKnotKeeperNearMiss
    var crossing: WaveKnotKeeperCrossingExample
    var difficulty: WaveKnotKeeperDifficulty
    var skipped: Int

    /// The stored form: JSON with sorted keys, pretty-printed, without escaped slashes, followed by one newline.
    func encoded() throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        var data: Data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }
}

/// Solver results by level fingerprint, so an unaltered level is solved once per process.
private let regressionSolveCache: Mutex<[String: WaveKnotKeeperSolution]> =
    Mutex<[String: WaveKnotKeeperSolution]>([:])

@Suite struct WaveKnotKeeperRegressionSolverTests {
    /// The work bound of one solve: 1 + 60 + 3,600 ropes expanded for a rope of at most 10 points (clarification Q1).
    static let workBound: Int = 3_661

    /// The seed of this feature's choices (the altered control point).
    static let seed: UInt64 = 2_328

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(WaveKnotKeeperGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, as its mirror.
    fileprivate static func witness(_ number: Int) throws -> WaveKnotKeeperRegressionWitnessMirror {
        try JSONDecoder().decode(WaveKnotKeeperRegressionWitnessMirror.self, from: try witnessData(number))
    }

    /// The solver's result for `level`, computed once per level fingerprint.
    static func solved(_ level: WaveKnotKeeperLevel) -> WaveKnotKeeperSolution? {
        if let cached = regressionSolveCache.withLock({ $0[level.fingerprint] }) { return cached }
        guard let fresh = WaveKnotKeeperSolver.solve(level) else { return nil }
        regressionSolveCache.withLock { $0[level.fingerprint] = fresh }
        return fresh
    }

    /// Nil when `moves` applied in order on a fresh play of `level` win at the last move and not before.
    static func replayProblem(level: WaveKnotKeeperLevel, moves: [WaveKnotKeeperMove]) -> String? {
        var play: WaveKnotKeeperPlay
        do {
            play = try WaveKnotKeeperExperienceCore.freshPlay(of: level)
        } catch {
            return "fresh play refused (\(error.reasonCode))"
        }
        for index in 0..<moves.count {
            if play.stage != .playing {
                return "stage \(play.stage.rawValue) before move \(index + 1) of \(moves.count)"
            }
            do {
                try play.apply(moves[index], expecting: play.fingerprint)
            } catch {
                return "move \(index + 1) of \(moves.count) refused (\(error.reasonCode))"
            }
        }
        if play.stage != .won {
            return "no win after \(moves.count) moves (stage \(play.stage.rawValue))"
        }
        return nil
    }

    /// Every disagreement between `level` and its stored `witness`, each naming the level and the part; empty when the
    /// witness replays on the level to a win in exactly its recorded moves with its recorded fingerprints, terminal,
    /// near miss and crossing counterexample, and the solver reproduces its shortest, moves and work.
    fileprivate static func check(level: WaveKnotKeeperLevel, witness: WaveKnotKeeperRegressionWitnessMirror) -> [String] {
        var result: [String] = []
        let name: String = "level \(witness.number)"
        let stored: WaveKnotKeeperRegressionLevelMirror = witness.level

        // The level against the witness's level, part by part, then by fingerprint.
        if level.id != stored.id { result.append("\(name): id differs") }
        if level.seed != stored.seed { result.append("\(name): seed differs") }
        if level.band != stored.band { result.append("\(name): band differs") }
        if level.points.count != stored.points.count {
            result.append("\(name): control point count differs (\(level.points.count), witness \(stored.points.count))")
        } else {
            for index in 0..<level.points.count where level.points[index] != stored.points[index] {
                result.append("\(name): control point \(index + 1) differs")
            }
        }
        if level.gates.count != stored.gates.count {
            result.append("\(name): gate count differs (\(level.gates.count), witness \(stored.gates.count))")
        } else {
            for index in 0..<level.gates.count where level.gates[index] != stored.gates[index] {
                result.append("\(name): gate \(index + 1) differs")
            }
        }
        if level.target.crossings != stored.target.crossings { result.append("\(name): target crossings differ") }
        if level.target.writhe != stored.target.writhe { result.append("\(name): target writhe differs") }
        if level.tensionBound != stored.tensionBound { result.append("\(name): tension bound differs") }
        if level.allowance != stored.allowance { result.append("\(name): allowance differs") }
        if level.tutorial != stored.tutorial { result.append("\(name): tutorial differs") }
        if level.fingerprint != stored.fingerprint {
            result.append("\(name): level fingerprint differs (level \(level.fingerprint), witness "
                          + "\(stored.fingerprint))")
        }

        // The witness's own level: its content must rebuild to its stored fingerprint.
        do {
            let rebuilt: WaveKnotKeeperLevel = try WaveKnotKeeperLevel(
                id: stored.id, seed: stored.seed, band: stored.band, points: stored.points, gates: stored.gates,
                target: stored.target, tensionBound: stored.tensionBound, allowance: stored.allowance,
                tutorial: stored.tutorial)
            if rebuilt.fingerprint != stored.fingerprint {
                result.append("\(name): level fingerprint differs from the witness level's content")
            }
        } catch {
            result.append("\(name): witness level refused (\(error.reasonCode))")
        }

        // The witness replayed on the level: exactly its moves, its recorded fingerprints, then a win.
        var play: WaveKnotKeeperPlay
        do {
            play = try WaveKnotKeeperExperienceCore.freshPlay(of: level)
        } catch {
            result.append("\(name): fresh play refused (\(error.reasonCode))")
            return result
        }
        var replayed: [String] = [play.fingerprint]
        var refused: Bool = false
        for index in 0..<witness.moves.count {
            if play.stage != .playing {
                result.append("\(name): replay stage \(play.stage.rawValue) before move \(index + 1)")
                refused = true
                break
            }
            do {
                try play.apply(witness.moves[index], expecting: play.fingerprint)
            } catch {
                result.append("\(name): replay move \(index + 1) refused (\(error.reasonCode))")
                refused = true
                break
            }
            replayed.append(play.fingerprint)
        }
        if witness.fingerprints.count != witness.moves.count + 1 {
            result.append("\(name): recorded fingerprint count \(witness.fingerprints.count) differs")
        }
        let compared: Int = min(replayed.count, witness.fingerprints.count)
        for index in 0..<compared where replayed[index] != witness.fingerprints[index] {
            result.append("\(name): recorded fingerprint \(index) differs")
        }
        if !refused && play.stage != .won {
            result.append("\(name): replay does not win in \(witness.moves.count) moves (stage \(play.stage.rawValue))")
        }
        if witness.difficulty.shortest != witness.moves.count {
            result.append("\(name): recorded shortest \(witness.difficulty.shortest) differs from "
                          + "\(witness.moves.count) moves")
        }

        // The winning rope's terminal summary and near miss.
        if play.stage == .won {
            let winning: [WaveKnotKeeperPoint] = play.points
            let terminal: WaveKnotKeeperTerminal = WaveKnotKeeperTerminal(winning)
            if terminal.crossings != witness.terminal.crossings { result.append("\(name): terminal crossings differ") }
            if terminal.writhe != witness.terminal.writhe { result.append("\(name): terminal writhe differs") }
            if terminal.tension != witness.terminal.tension { result.append("\(name): terminal tension differs") }
            let nearMiss: WaveKnotKeeperNearMiss? = WaveKnotKeeperWitness.nearMiss(of: winning, level: level,
                                                                                  moves: witness.moves)
            if nearMiss != witness.nearMiss { result.append("\(name): near miss differs") }
        }

        // The crossing counterexample: a rope of the level whose move the rules refuse as a crossing.
        if !WaveKnotKeeperWitness.isRefused(witness.crossing, level: level) {
            result.append("\(name): crossing counterexample differs (not refused as a crossing)")
        }

        // The solver from the start: the certified shortest, the same winning moves, work within the bound and the
        // certified work, and the same crossing counterexample.
        guard let solution = solved(level) else {
            result.append("\(name): solver finds no solution")
            return result
        }
        if solution.shortest != witness.moves.count {
            result.append("\(name): solver shortest \(solution.shortest) differs from \(witness.moves.count) moves")
        }
        if let why = replayProblem(level: level, moves: solution.moves) {
            result.append("\(name): solver moves do not win (\(why))")
        }
        if solution.moves.count != witness.moves.count {
            result.append("\(name): solution move count \(solution.moves.count) differs")
        }
        for index in 0..<min(solution.moves.count, witness.moves.count) {
            if solution.moves[index].point != witness.moves[index].point {
                result.append("\(name): solution move \(index + 1) point differs")
            }
            if solution.moves[index].direction != witness.moves[index].direction {
                result.append("\(name): solution move \(index + 1) direction differs")
            }
        }
        if solution.work > workBound { result.append("\(name): solver work \(solution.work) above \(workBound)") }
        if solution.work != witness.difficulty.work {
            result.append("\(name): solver work \(solution.work) differs from certified \(witness.difficulty.work)")
        }
        if solution.crossing != witness.crossing {
            result.append("\(name): crossing counterexample differs from the solver's")
        }
        if WaveKnotKeeperDifficulty(level: level, solution: solution) != witness.difficulty {
            result.append("\(name): recorded difficulty differs")
        }

        // The strict decoder agrees: it re-verifies every stored value by replay.
        let data: Data
        do {
            data = try witness.encoded()
        } catch {
            result.append("\(name): witness unencodable (\(error))")
            return result
        }
        do {
            _ = try WaveKnotKeeperWitness.decode(data)
        } catch {
            result.append("\(name): witness refused (\(error.reasonCode))")
        }
        return result
    }

    /// Checks every level of `band` (20 levels) and records each problem; returns the largest work seen.
    @discardableResult
    static func checkBand(_ band: Int) throws -> Int {
        var checked: Int = 0
        var largestWork: Int = 0
        for number in ((band - 1) * 20 + 1)...(band * 20) {
            let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: number)
            #expect(generated.level.band == band, "level \(number): band \(generated.level.band)")
            let data: Data = try witnessData(number)
            let witness: WaveKnotKeeperRegressionWitnessMirror =
                try JSONDecoder().decode(WaveKnotKeeperRegressionWitnessMirror.self, from: data)
            #expect(witness.number == number, "level \(number): witness number \(witness.number)")
            #expect(try witness.encoded() == data, "level \(number): witness file is not in its stored form")
            for problem in check(level: generated.level, witness: witness) {
                Issue.record(Comment(rawValue: problem))
            }
            #expect(generated.solution.shortest == witness.moves.count,
                    "level \(number): generator shortest \(generated.solution.shortest)")
            #expect(generated.difficulty == witness.difficulty, "level \(number): generator difficulty differs")
            if let solution = solved(generated.level) {
                #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
                largestWork = max(largestWork, solution.work)
            }
            checked += 1
        }
        #expect(checked == 20)
        #expect(largestWork <= workBound, "band \(band): work \(largestWork)")
        print("WaveKnotKeeperRegressionSolverTests band \(band): largest work \(largestWork)")
        return largestWork
    }

    // MARK: The regression, one test per band (FR-R02G0308-001; SC-R02G0308-001; clarification Q1)

    @Test func band1Levels1To20() throws { try Self.checkBand(1) }
    @Test func band2Levels21To40() throws { try Self.checkBand(2) }
    @Test func band3Levels41To60() throws { try Self.checkBand(3) }
    @Test func band4Levels61To80() throws { try Self.checkBand(4) }
    @Test func band5Levels81To100() throws { try Self.checkBand(5) }

    // MARK: Alterations (FR-R02G0308-002; SC-R02G0308-002; clarification Q2)

    /// The certified levels altered: one of band 3 (8 points, one gate, two moves) and one of band 5 (10 points, two
    /// gates, three moves); both have crossing targets, so the writhe can change.
    static let alteredNumbers: [Int] = [44, 87]

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: WaveKnotKeeperLevel, points: [WaveKnotKeeperPoint]? = nil,
                        gates: [WaveKnotKeeperGate]? = nil, target: WaveKnotKeeperTarget? = nil,
                        tensionBound: Int? = nil, allowance: Int? = nil) throws -> WaveKnotKeeperLevel {
        try WaveKnotKeeperLevel(id: level.id, seed: level.seed, band: level.band, points: points ?? level.points,
                                gates: gates ?? level.gates, target: target ?? level.target,
                                tensionBound: tensionBound ?? level.tensionBound,
                                allowance: allowance ?? level.allowance, tutorial: level.tutorial)
    }

    /// The first level `make(variant)` builds for variant 1 … 48: a variant the initialiser refuses (a rope through
    /// itself, a start that already wins, a target out of range) is skipped and the next one tried.
    static func firstAccepted(_ make: (Int) throws -> WaveKnotKeeperLevel) throws -> WaveKnotKeeperLevel {
        var lastError: (any Error)? = nil
        for variant in 1...48 {
            do {
                return try make(variant)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? WaveKnotKeeperError.level("variant")
    }

    /// Records an issue unless `found` holds a message that starts with the level's name and names `part`.
    static func expectNamed(_ found: [String], number: Int, kind: String, part: String) {
        var named: Bool = false
        for message in found where message.hasPrefix("level \(number): ") && message.contains(part) { named = true }
        #expect(named, "level \(number) alteration \(kind): no message naming \"\(part)\" in \(found)")
        for message in found {
            #expect(message.hasPrefix("level \(number): "), "level \(number) alteration \(kind): message \(message)")
        }
    }

    /// The unaltered pairs are clean, so every problem found below is the alteration's.
    @Test func theUnalteredLevelsAndWitnessesAreClean() throws {
        for number in Self.alteredNumbers {
            let level: WaveKnotKeeperLevel = try WaveKnotKeeperExperienceCore.level(number: number)
            let found: [String] = Self.check(level: level, witness: try Self.witness(number))
            #expect(found.isEmpty, "level \(number): \(found)")
        }
    }

    /// Level alterations: a control point, a gate, the target crossings, the target writhe, the tension bound and the
    /// allowance. Each is rebuilt through the level initialiser, changes the fingerprint and is reported naming its part.
    @Test func levelAlterationsAreNamed() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        for number in Self.alteredNumbers {
            let level: WaveKnotKeeperLevel = try WaveKnotKeeperExperienceCore.level(number: number)
            let witness: WaveKnotKeeperRegressionWitnessMirror = try Self.witness(number)
            #expect(!level.gates.isEmpty && level.target.crossings > 0, "level \(number): no gate or no crossing")
            let count: Int = level.points.count
            let base: Int = Int(random.next() % UInt64(count * directions.count))
            var altered: [(String, String, WaveKnotKeeperLevel)] = []
            var pointPart: String = ""
            let pointLevel: WaveKnotKeeperLevel = try Self.firstAccepted { (k: Int) in
                let combination: Int = (base + k - 1) % (count * directions.count)
                let index: Int = combination / directions.count
                var points: [WaveKnotKeeperPoint] = level.points
                points[index] = points[index].moved(directions[combination % directions.count])
                let made: WaveKnotKeeperLevel = try Self.rebuilt(level, points: points)
                pointPart = "control point \(index + 1) differs"
                return made
            }
            altered.append(("control point", pointPart, pointLevel))
            altered.append(("gate", "gate 1 differs", try Self.firstAccepted { (k: Int) in
                let gate: WaveKnotKeeperGate = level.gates[0]
                let grown: Bool = gate.max.x + k <= 16
                let max: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: grown ? gate.max.x + k : gate.max.x,
                                                                   y: gate.max.y, z: gate.max.z)
                let min: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: grown ? gate.min.x : gate.min.x - k,
                                                                   y: gate.min.y, z: gate.min.z)
                var gates: [WaveKnotKeeperGate] = level.gates
                gates[0] = try WaveKnotKeeperGate(min: min, max: max)
                return try Self.rebuilt(level, gates: gates)
            }))
            altered.append(("target crossings", "target crossings differ", try Self.firstAccepted { (k: Int) in
                let target: WaveKnotKeeperTarget = try WaveKnotKeeperTarget(crossings: level.target.crossings + 2 * k,
                                                                           writhe: level.target.writhe)
                return try Self.rebuilt(level, target: target)
            }))
            altered.append(("target writhe", "target writhe differs", try Self.firstAccepted { (k: Int) in
                let step: Int = k % 2 == 1 ? 2 * ((k + 1) / 2) : -2 * (k / 2)
                let target: WaveKnotKeeperTarget = try WaveKnotKeeperTarget(crossings: level.target.crossings,
                                                                           writhe: level.target.writhe + step)
                return try Self.rebuilt(level, target: target)
            }))
            altered.append(("tension bound", "tension bound differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, tensionBound: level.tensionBound + k)
            }))
            altered.append(("allowance", "allowance differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, allowance: level.allowance == 64 ? 64 - k : level.allowance + k)
            }))
            for (kind, part, copy) in altered {
                #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(kind): same fingerprint")
                let found: [String] = Self.check(level: copy, witness: witness)
                Self.expectNamed(found, number: number, kind: kind, part: part)
                Self.expectNamed(found, number: number, kind: kind, part: "level fingerprint differs")
            }
        }
    }

    /// Solution alterations: the first move's point or direction in the witness.
    @Test func solutionAlterationsAreNamed() throws {
        for number in Self.alteredNumbers {
            let level: WaveKnotKeeperLevel = try WaveKnotKeeperExperienceCore.level(number: number)
            let witness: WaveKnotKeeperRegressionWitnessMirror = try Self.witness(number)
            #expect(!witness.moves.isEmpty, "level \(number): no moves")
            if witness.moves.isEmpty { continue }
            let first: WaveKnotKeeperMove = witness.moves[0]

            var pointCopy: WaveKnotKeeperRegressionWitnessMirror = witness
            pointCopy.moves[0] = WaveKnotKeeperMove(point: (first.point + 1) % level.points.count,
                                                    direction: first.direction)
            var directionCopy: WaveKnotKeeperRegressionWitnessMirror = witness
            let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
            let next: WaveKnotKeeperDirection =
                directions[((directions.firstIndex(of: first.direction) ?? 0) + 1) % directions.count]
            directionCopy.moves[0] = WaveKnotKeeperMove(point: first.point, direction: next)

            #expect(pointCopy != witness && directionCopy != witness, "level \(number): move unchanged")
            Self.expectNamed(Self.check(level: level, witness: pointCopy), number: number, kind: "move point",
                             part: "solution move 1 point differs")
            Self.expectNamed(Self.check(level: level, witness: directionCopy), number: number, kind: "move direction",
                             part: "solution move 1 direction differs")
        }
    }

    /// Witness alterations: the terminal, the near miss, the crossing counterexample, a recorded fingerprint and the
    /// level fingerprint the witness stores.
    @Test func witnessAlterationsAreNamed() throws {
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        for number in Self.alteredNumbers {
            let level: WaveKnotKeeperLevel = try WaveKnotKeeperExperienceCore.level(number: number)
            let witness: WaveKnotKeeperRegressionWitnessMirror = try Self.witness(number)
            var altered: [(String, String, WaveKnotKeeperRegressionWitnessMirror)] = []

            var terminal: WaveKnotKeeperRegressionWitnessMirror = witness
            terminal.terminal = WaveKnotKeeperTerminal(crossings: witness.terminal.crossings,
                                                       writhe: witness.terminal.writhe,
                                                       tension: witness.terminal.tension + 1)
            altered.append(("terminal", "terminal tension differs", terminal))

            var nearMiss: WaveKnotKeeperRegressionWitnessMirror = witness
            let missMove: WaveKnotKeeperMove = witness.nearMiss.move
            let missNext: WaveKnotKeeperDirection =
                directions[((directions.firstIndex(of: missMove.direction) ?? 0) + 1) % directions.count]
            nearMiss.nearMiss = WaveKnotKeeperNearMiss(
                move: WaveKnotKeeperMove(point: missMove.point, direction: missNext),
                crossings: witness.nearMiss.crossings, writhe: witness.nearMiss.writhe,
                degenerate: witness.nearMiss.degenerate)
            altered.append(("near miss", "near miss differs", nearMiss))

            var crossing: WaveKnotKeeperRegressionWitnessMirror = witness
            let crossingMove: WaveKnotKeeperMove = witness.crossing.move
            crossing.crossing = WaveKnotKeeperCrossingExample(
                points: witness.crossing.points,
                move: WaveKnotKeeperMove(point: crossingMove.point, direction: crossingMove.direction.opposite))
            altered.append(("crossing counterexample", "crossing counterexample differs", crossing))

            var recorded: WaveKnotKeeperRegressionWitnessMirror = witness
            let last: Int = recorded.fingerprints.count - 1
            let lastFirst: Character = recorded.fingerprints[last].first ?? "0"
            recorded.fingerprints[last] = (lastFirst == "0" ? "1" : "0") + recorded.fingerprints[last].dropFirst()
            altered.append(("recorded fingerprint", "recorded fingerprint \(last) differs", recorded))

            var fingerprint: WaveKnotKeeperRegressionWitnessMirror = witness
            let levelFirst: Character = fingerprint.level.fingerprint.first ?? "0"
            fingerprint.level.fingerprint = (levelFirst == "0" ? "1" : "0") + fingerprint.level.fingerprint.dropFirst()
            altered.append(("level fingerprint", "level fingerprint differs", fingerprint))

            for (kind, part, copy) in altered {
                #expect(copy != witness, "level \(number) alteration \(kind): unchanged")
                Self.expectNamed(Self.check(level: level, witness: copy), number: number, kind: kind, part: part)
            }
        }
    }
}
