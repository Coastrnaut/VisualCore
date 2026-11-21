// AuroraLoomRegressionSolverTests — feature 308 (R02-G01-08) T-R02G0108-003 (FR-R02G0108-001, 002; SC-R02G0108-001,
// 002; clarifications Q1, Q2). The solver regression of all 100 catalog levels, one test per band of 20: the generated
// level equals the level of its witness file in docs/games/aurora-loom/levels (fingerprint); the witness replays on a fresh
// play to a win in exactly its recorded moves; `AuroraLoomSolver.solve` returns exactly the certified shortest, its moves
// win in order, and its work stays within 3 × (maxSweeps × 32 + 256) = 3,840 evaluations. Then the twelve alterations of
// clarification Q2, each applied to a copy of a certified level, solution or witness, must be detected by the same checks
// with a message naming the level and the part.
// Explicit types, plain loops, short runs, work counted, never timed.
@testable import AuroraLoomCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/aurora-loom/levels", isDirectory: true)

/// The stored witness form, mirrored field by field so a test can change one value and encode it again exactly
/// (JSONSerialization would carry a seed above Int64.max as a Double and change it).
fileprivate struct WitnessMirror: Codable {
    var schema: Int
    var number: Int
    var level: LevelMirror
    var actions: [AuroraLoomMove]
    var fingerprints: [String]
    var terminal: AuroraLoomMismatch
    var counterexample: AuroraLoomCounterexample
    var difficulty: DifficultyMirror
    var method: AuroraLoomSolveMethod
    var skipped: Int
}

/// The stored level form, with its fingerprint as plain text.
fileprivate struct LevelMirror: Codable {
    var schema: Int
    var id: String
    var seed: UInt64
    var band: Int
    var ribbons: [AuroraLoomRibbon]
    var gates: [AuroraLoomGate]
    var omega: Int
    var tolerance: Int
    var allowance: Int
    var tutorial: Bool
    var fingerprint: String
}

/// The stored difficulty form.
fileprivate struct DifficultyMirror: Codable {
    var omega: Int
    var shortest: Int
    var tolerance: Int
    var winningSettings: Int
    var work: Int
}

@Suite struct AuroraLoomRegressionSolverTests {
    /// The work bound of one solve: three ribbons, each at most `maxSweeps` sweeps of 32 settings and the 256-setting grid.
    static let workBound: Int = 3 * (AuroraLoomSolver.maxSweeps * 32 + 256)

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(AuroraLoomGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The generated (certified) level of manifest number `number`.
    static func generated(_ number: Int) throws -> AuroraLoomGenerated {
        let entry: AuroraLoomManifestEntry = AuroraLoomManifest.entries[number - 1]
        return try AuroraLoomGenerator.generate(entry)
    }

    /// Nil when `moves` applied in order on a fresh play of `level` win at the last move and not before; otherwise why not.
    static func replayProblem(level: AuroraLoomLevel, moves: [AuroraLoomMove]) -> String? {
        var play: AuroraLoomPlay
        do {
            play = try AuroraLoomExperienceCore.freshPlay(of: level)
        } catch {
            return "fresh play refused (\(error))"
        }
        for index in 0..<moves.count {
            if play.stage != .playing {
                return "stage \(play.stage.rawValue) before move \(index + 1) of \(moves.count)"
            }
            do {
                try play.apply(moves[index], expecting: play.fingerprint)
            } catch {
                return "move \(index + 1) of \(moves.count) refused (\(error))"
            }
        }
        if play.stage != .won {
            return "no win after \(moves.count) moves (stage \(play.stage.rawValue))"
        }
        return nil
    }

    /// Every disagreement between a level, its certified solution and its stored witness, each naming the level and the
    /// part; empty when the three agree and the solver reproduces the certified shortest within its work bound.
    static func problems(number: Int, level: AuroraLoomLevel, solution: AuroraLoomSolution,
                         witnessData: Data) -> [String] {
        var result: [String] = []
        let name: String = "level \(number)"

        // The level against the witness file's level, by fingerprint (read as stored text, before any decoding check).
        do {
            let mirror: WitnessMirror = try JSONDecoder().decode(WitnessMirror.self, from: witnessData)
            if mirror.level.fingerprint != level.fingerprint {
                result.append("\(name) fingerprint: generated \(level.fingerprint), witness \(mirror.level.fingerprint)")
            }
            if mirror.number != number {
                result.append("\(name) witness number: \(mirror.number)")
            }
        } catch {
            result.append("\(name) witness: unreadable (\(error))")
        }

        // The witness: it must decode (every stored value reproduced by replay) and replay on the level to a win in
        // exactly its recorded number of moves, which is the certified shortest.
        var recordedShortest: Int? = nil
        do {
            let witness: AuroraLoomWitness = try AuroraLoomWitness.decode(witnessData)
            recordedShortest = witness.difficulty.shortest
            if witness.level.fingerprint != level.fingerprint {
                result.append("\(name) fingerprint: decoded witness level \(witness.level.fingerprint)")
            }
            if witness.actions.count != witness.difficulty.shortest {
                result.append("\(name) witness shortest: \(witness.actions.count) actions, recorded "
                              + "\(witness.difficulty.shortest)")
            }
            if witness.difficulty.shortest != solution.shortest {
                result.append("\(name) witness shortest: recorded \(witness.difficulty.shortest), certified "
                              + "\(solution.shortest)")
            }
            if let why = replayProblem(level: level, moves: witness.actions) {
                result.append("\(name) witness replay: \(why)")
            }
        } catch {
            result.append("\(name) witness: refused (\(error))")
        }

        // The certified solution: its moves win in order in exactly its length.
        if solution.moves.count != solution.shortest {
            result.append("\(name) solution: \(solution.moves.count) moves, shortest \(solution.shortest)")
        }
        if let why = replayProblem(level: level, moves: solution.moves) {
            result.append("\(name) solution replay: \(why)")
        }

        // The solver from the start: the certified shortest, winning moves, work within the bound.
        if let solved = AuroraLoomSolver.solve(level) {
            if solved.shortest != solution.shortest {
                result.append("\(name) solver shortest: \(solved.shortest), certified \(solution.shortest)")
            }
            if let recorded = recordedShortest, solved.shortest != recorded {
                result.append("\(name) solver shortest: \(solved.shortest), witness recorded \(recorded)")
            }
            if solved.moves.count != solved.shortest {
                result.append("\(name) solver moves: \(solved.moves.count) moves, shortest \(solved.shortest)")
            }
            if let why = replayProblem(level: level, moves: solved.moves) {
                result.append("\(name) solver replay: \(why)")
            }
            if solved.moves != solution.moves {
                result.append("\(name) solution moves: differ from the solver's \(solved.moves)")
            }
            if solved.work > workBound {
                result.append("\(name) solver work: \(solved.work) above \(workBound)")
            }
        } else {
            result.append("\(name) solver: no solution")
        }
        return result
    }

    /// Checks every level of `band` (20 levels) and records each problem.
    static func checkBand(_ band: Int) throws {
        var checked: Int = 0
        var largestWork: Int = 0
        for number in ((band - 1) * 20 + 1)...(band * 20) {
            let generated: AuroraLoomGenerated = try generated(number)
            #expect(generated.level.band == band, "level \(number) band: \(generated.level.band)")
            let data: Data = try witnessData(number)
            let found: [String] = problems(number: number, level: generated.level, solution: generated.solution,
                                           witnessData: data)
            for problem in found {
                Issue.record(Comment(rawValue: problem))
            }
            largestWork = max(largestWork, generated.solution.work)
            checked += 1
        }
        #expect(checked == 20)
        #expect(largestWork <= workBound, "band \(band) work: \(largestWork)")
    }

    // MARK: The regression, one test per band (FR-R02G0108-001; SC-R02G0108-001)

    @Test func band1Levels1To20() throws { try Self.checkBand(1) }
    @Test func band2Levels21To40() throws { try Self.checkBand(2) }
    @Test func band3Levels41To60() throws { try Self.checkBand(3) }
    @Test func band4Levels61To80() throws { try Self.checkBand(4) }
    @Test func band5Levels81To100() throws { try Self.checkBand(5) }

    // MARK: Alterations (FR-R02G0108-002; SC-R02G0108-002; clarification Q2)

    /// The certified levels altered: the first of each band.
    static let alteredNumbers: [Int] = [1, 21, 41, 61, 81]

    /// `level` re-created with one field changed by `change`; nil when the initialiser refuses the change.
    static func rebuilt(_ level: AuroraLoomLevel, ribbons: [AuroraLoomRibbon]? = nil, gates: [AuroraLoomGate]? = nil,
                        omega: Int? = nil, tolerance: Int? = nil, allowance: Int? = nil) -> AuroraLoomLevel? {
        try? AuroraLoomLevel(id: level.id, seed: level.seed, band: level.band, ribbons: ribbons ?? level.ribbons,
                             gates: gates ?? level.gates, omega: omega ?? level.omega,
                             tolerance: tolerance ?? level.tolerance, allowance: allowance ?? level.allowance,
                             tutorial: level.tutorial)
    }

    /// `solution` with its first move changed by `edit`.
    static func editedSolution(_ solution: AuroraLoomSolution,
                               _ edit: (inout AuroraLoomMove) -> Void) -> AuroraLoomSolution {
        var moves: [AuroraLoomMove] = solution.moves
        edit(&moves[0])
        return AuroraLoomSolution(shortest: solution.shortest, moves: moves, setting: solution.setting,
                                  work: solution.work, winningSettings: solution.winningSettings,
                                  method: solution.method)
    }

    /// The witness file edited through its mirror and encoded again with sorted keys.
    fileprivate static func editedWitness(_ data: Data, _ edit: (inout WitnessMirror) -> Void) throws -> Data {
        var mirror: WitnessMirror = try JSONDecoder().decode(WitnessMirror.self, from: data)
        edit(&mirror)
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        var encoded: Data = try encoder.encode(mirror)
        encoded.append(0x0A)
        return encoded
    }

    /// Records an issue unless the alteration `kind` of level `number` was detected with messages naming the level.
    /// A nil `found` means the altered value was refused at construction, which counts as detection.
    static func expectDetected(_ found: [String]?, number: Int, kind: String) {
        guard let found else { return }   // refused at construction: detected
        #expect(!found.isEmpty, "level \(number) alteration \(kind): not detected")
        for message in found {
            #expect(message.hasPrefix("level \(number) "), "level \(number) alteration \(kind): message \(message)")
        }
    }

    /// The unaltered mirror re-encoding is clean, so every detection below is the alteration's.
    @Test func theMirrorReencodingOfACertifiedWitnessIsClean() throws {
        for number in Self.alteredNumbers {
            let generated: AuroraLoomGenerated = try Self.generated(number)
            let data: Data = try Self.editedWitness(try Self.witnessData(number)) { (_: inout WitnessMirror) in }
            let found: [String] = Self.problems(number: number, level: generated.level, solution: generated.solution,
                                                witnessData: data)
            #expect(found.isEmpty, "level \(number) mirror: \(found)")
        }
    }

    /// Level alterations: tolerance, allowance, a gate, a ribbon start step, ω. Each changes the fingerprint; a change the
    /// level initialiser refuses (for example a start that would already win) counts as detected.
    @Test func levelAlterationsAreDetected() throws {
        for number in Self.alteredNumbers {
            let generated: AuroraLoomGenerated = try Self.generated(number)
            let level: AuroraLoomLevel = generated.level
            let solution: AuroraLoomSolution = generated.solution
            let data: Data = try Self.witnessData(number)

            var altered: [(String, AuroraLoomLevel?)] = []
            altered.append(("tolerance", Self.rebuilt(level, tolerance: level.tolerance - 1)))
            altered.append(("allowance", Self.rebuilt(level, allowance: level.allowance + 1)))
            var gates: [AuroraLoomGate] = level.gates
            gates[0] = try AuroraLoomGate(position: gates[0].position, target: (gates[0].target + 1) % 4_096)
            altered.append(("gate", Self.rebuilt(level, gates: gates)))
            var ribbons: [AuroraLoomRibbon] = level.ribbons
            ribbons[0] = try AuroraLoomRibbon(wave: (ribbons[0].wave + 1) % 16, phase: ribbons[0].phase,
                                              omega: ribbons[0].omega)
            altered.append(("ribbon start step", Self.rebuilt(level, ribbons: ribbons)))
            let omega: Int = level.omega == 256 ? 128 : level.omega * 2
            altered.append(("omega", Self.rebuilt(level, omega: omega)))

            for (kind, copy) in altered {
                var found: [String]? = nil
                if let copy {
                    #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(kind): same fingerprint")
                    found = Self.problems(number: number, level: copy, solution: solution, witnessData: data)
                }
                Self.expectDetected(found, number: number, kind: kind)
            }
        }
    }

    /// Solution alterations: a move's ribbon, control or step.
    @Test func solutionAlterationsAreDetected() throws {
        for number in Self.alteredNumbers {
            let generated: AuroraLoomGenerated = try Self.generated(number)
            let solution: AuroraLoomSolution = generated.solution
            let data: Data = try Self.witnessData(number)
            #expect(!solution.moves.isEmpty, "level \(number) solution: no moves")
            if solution.moves.isEmpty { continue }

            var altered: [(String, AuroraLoomSolution)] = []
            altered.append(("move ribbon", Self.editedSolution(solution) { (move: inout AuroraLoomMove) in
                move.ribbon = (move.ribbon + 1) % 3
            }))
            altered.append(("move control", Self.editedSolution(solution) { (move: inout AuroraLoomMove) in
                move.control = move.control == .wave ? .phase : .wave
            }))
            altered.append(("move step", Self.editedSolution(solution) { (move: inout AuroraLoomMove) in
                move.step = (move.step + 1) % 16
            }))
            for (kind, copy) in altered {
                let found: [String] = Self.problems(number: number, level: generated.level, solution: copy,
                                                    witnessData: data)
                Self.expectDetected(found, number: number, kind: kind)
            }
        }
    }

    /// Witness alterations: its terminal (the winning setting's worst mismatch), its counterexample, its recorded
    /// shortest, and the level fingerprint it stores.
    @Test func witnessAlterationsAreDetected() throws {
        for number in Self.alteredNumbers {
            let generated: AuroraLoomGenerated = try Self.generated(number)
            let data: Data = try Self.witnessData(number)

            var altered: [(String, Data)] = []
            altered.append(("terminal", try Self.editedWitness(data) { (mirror: inout WitnessMirror) in
                let t: AuroraLoomMismatch = mirror.terminal
                mirror.terminal = AuroraLoomMismatch(ribbon: t.ribbon, gate: t.gate, tick: t.tick,
                                                     residual: t.residual + 1)
            }))
            altered.append(("counterexample", try Self.editedWitness(data) { (mirror: inout WitnessMirror) in
                let c: AuroraLoomCounterexample = mirror.counterexample
                let m: AuroraLoomMismatch = c.mismatch
                mirror.counterexample = AuroraLoomCounterexample(
                    setting: c.setting,
                    mismatch: AuroraLoomMismatch(ribbon: m.ribbon, gate: m.gate, tick: m.tick, residual: m.residual + 1))
            }))
            altered.append(("recorded shortest", try Self.editedWitness(data) { (mirror: inout WitnessMirror) in
                mirror.difficulty.shortest += 1
            }))
            altered.append(("level fingerprint", try Self.editedWitness(data) { (mirror: inout WitnessMirror) in
                let first: Character = mirror.level.fingerprint.first ?? "0"
                let replacement: String = first == "0" ? "1" : "0"
                mirror.level.fingerprint = replacement + String(mirror.level.fingerprint.dropFirst())
            }))
            for (kind, copy) in altered {
                #expect(copy != data, "level \(number) alteration \(kind): unchanged")
                let found: [String] = Self.problems(number: number, level: generated.level,
                                                    solution: generated.solution, witnessData: copy)
                Self.expectDetected(found, number: number, kind: kind)
            }
        }
    }
}
