// LissajousLabyrinthRegressionSolverTests — feature 318 (R02-G02-08) T-R02G0208-002 (FR-R02G0208-001, 002;
// SC-R02G0208-001, 002).
// The solver regression of all 100 certified levels, one test per band of 20 (clarification Q1): the generated
// level equals the level of its witness file in docs/games/lissajous-labyrinth/levels (field by field and by
// fingerprint); the witness replays on a fresh play to a win in exactly its recorded actions with its recorded
// fingerprints, terminal, near miss and non-coprime refusal; `LissajousLabyrinthSolver.solve` returns exactly the
// certified shortest, its actions win, its work stays within the 14,080 legal settings and its winning-setting count
// equals the witness's. Then the twelve alterations of clarification Q2, each applied to a copy of a certified level or
// witness, must be reported by the same
// `check(level:witness:)` with a message naming the level and the part ("level 7: allowance differs").
// Explicit types, plain loops, short runs; work is counted, never timed.
@testable import LissajousLabyrinthCore
import Foundation
import Synchronization
import Testing

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)

/// The stored level form, field by field, with its fingerprint as plain text so a test can change any one value.
fileprivate struct LevelMirror: Codable, Equatable {
    var schema: Int
    var id: String
    var seed: UInt64
    var band: Int
    var amplitudes: [Int]
    var frequencyC: Int
    var start: LissajousLabyrinthDials
    var checkpoints: [LissajousLabyrinthBall]
    var obstacles: [LissajousLabyrinthBall]
    var allowance: Int
    var tutorial: Bool
    var fingerprint: String
}

/// The stored witness form, mirrored field by field so a test can change one value and encode it again exactly.
fileprivate struct WitnessMirror: Codable, Equatable {
    var schema: Int
    var number: Int
    var level: LevelMirror
    var actions: [LissajousLabyrinthAction]
    var fingerprints: [String]
    var terminal: LissajousLabyrinthTerminal
    var nearMiss: LissajousLabyrinthNearMiss
    var nonCoprime: LissajousLabyrinthNonCoprime
    var difficulty: LissajousLabyrinthDifficulty
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
private let solveCache: Mutex<[String: LissajousLabyrinthSolution]> = Mutex<[String: LissajousLabyrinthSolution]>([:])

@Suite struct LissajousLabyrinthRegressionSolverTests {
    /// The work bound of one solve: every one of the 14,080 legal settings decided at most once (clarification Q1).
    static let workBound: Int = 14_080

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(LissajousLabyrinthGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, as its mirror.
    fileprivate static func witness(_ number: Int) throws -> WitnessMirror {
        try JSONDecoder().decode(WitnessMirror.self, from: try witnessData(number))
    }

    /// The solver's result for `level`, computed once per level fingerprint.
    static func solved(_ level: LissajousLabyrinthLevel) -> LissajousLabyrinthSolution? {
        if let cached = solveCache.withLock({ $0[level.fingerprint] }) { return cached }
        guard let fresh = LissajousLabyrinthSolver.solve(level) else { return nil }
        solveCache.withLock { $0[level.fingerprint] = fresh }
        return fresh
    }

    /// Nil when `actions` applied in order on a fresh play of `level` win at the last action and not before.
    static func replayProblem(level: LissajousLabyrinthLevel, actions: [LissajousLabyrinthAction]) -> String? {
        var play: LissajousLabyrinthPlay
        do {
            play = try LissajousLabyrinthExperienceCore.freshPlay(of: level)
        } catch {
            return "fresh play refused (\(error.reasonCode))"
        }
        for index in 0..<actions.count {
            if play.stage != .playing {
                return "stage \(play.stage.rawValue) before action \(index + 1) of \(actions.count)"
            }
            do {
                try play.apply(actions[index], expecting: play.fingerprint)
            } catch {
                return "action \(index + 1) of \(actions.count) refused (\(error.reasonCode))"
            }
        }
        if play.stage != .won {
            return "no win after \(actions.count) actions (stage \(play.stage.rawValue))"
        }
        return nil
    }

    /// Appends "<name>: <part> differs" for every ball of `actual` that differs from `stored`.
    static func compareBalls(_ actual: [LissajousLabyrinthBall], _ stored: [LissajousLabyrinthBall], part: String,
                             name: String, into result: inout [String]) {
        if actual.count != stored.count {
            result.append("\(name): \(part) count differs (\(actual.count), witness \(stored.count))")
            return
        }
        for index in 0..<actual.count where actual[index] != stored[index] {
            result.append("\(name): \(part) \(index + 1) differs")
        }
    }

    /// Every disagreement between `level` and its stored `witness`, each naming the level and the part; empty when the
    /// witness replays on the level to a win in exactly its recorded actions with its recorded fingerprints, terminal,
    /// near miss and non-coprime refusal, and the solver reproduces its shortest, actions, work and winning settings.
    fileprivate static func check(level: LissajousLabyrinthLevel, witness: WitnessMirror) -> [String] {
        var result: [String] = []
        let name: String = "level \(witness.number)"
        let stored: LevelMirror = witness.level

        // The level against the witness's level, part by part, then by fingerprint.
        if level.id != stored.id { result.append("\(name): id differs") }
        if level.seed != stored.seed { result.append("\(name): seed differs") }
        if level.band != stored.band { result.append("\(name): band differs") }
        if level.amplitudes != stored.amplitudes { result.append("\(name): amplitude differs") }
        if level.frequencyC != stored.frequencyC { result.append("\(name): frequency C differs") }
        for dial in LissajousLabyrinthDial.allCases where level.start[dial] != stored.start[dial] {
            result.append("\(name): start dial \(dial.rawValue) differs")
        }
        compareBalls(level.checkpoints, stored.checkpoints, part: "checkpoint", name: name, into: &result)
        compareBalls(level.obstacles, stored.obstacles, part: "obstacle", name: name, into: &result)
        if level.allowance != stored.allowance { result.append("\(name): allowance differs") }
        if level.tutorial != stored.tutorial { result.append("\(name): tutorial differs") }
        if level.fingerprint != stored.fingerprint {
            result.append("\(name): level fingerprint differs (level \(level.fingerprint), witness "
                          + "\(stored.fingerprint))")
        }

        // The witness's own level: its content must rebuild to its stored fingerprint.
        do {
            let rebuilt: LissajousLabyrinthLevel = try LissajousLabyrinthLevel(
                id: stored.id, seed: stored.seed, band: stored.band, amplitudes: stored.amplitudes,
                frequencyC: stored.frequencyC, start: stored.start, checkpoints: stored.checkpoints,
                obstacles: stored.obstacles, allowance: stored.allowance, tutorial: stored.tutorial)
            if rebuilt.fingerprint != stored.fingerprint {
                result.append("\(name): level fingerprint differs from the witness level's content")
            }
        } catch {
            result.append("\(name): witness level refused (\(error.reasonCode))")
        }

        // The witness replayed on the level: exactly its actions, its recorded fingerprints, then a win.
        var play: LissajousLabyrinthPlay
        do {
            play = try LissajousLabyrinthExperienceCore.freshPlay(of: level)
        } catch {
            result.append("\(name): fresh play refused (\(error.reasonCode))")
            return result
        }
        var replayed: [String] = [play.fingerprint]
        var refused: Bool = false
        for index in 0..<witness.actions.count {
            if play.stage != .playing {
                result.append("\(name): replay stage \(play.stage.rawValue) before action \(index + 1)")
                refused = true
                break
            }
            do {
                try play.apply(witness.actions[index], expecting: play.fingerprint)
            } catch {
                result.append("\(name): replay action \(index + 1) refused (\(error.reasonCode))")
                refused = true
                break
            }
            replayed.append(play.fingerprint)
        }
        if witness.fingerprints.count != witness.actions.count + 1 {
            result.append("\(name): recorded fingerprint count \(witness.fingerprints.count) differs")
        }
        let compared: Int = min(replayed.count, witness.fingerprints.count)
        for index in 0..<compared where replayed[index] != witness.fingerprints[index] {
            result.append("\(name): recorded fingerprint \(index) differs")
        }
        if !refused && play.stage != .won {
            result.append("\(name): replay does not win in \(witness.actions.count) actions "
                          + "(stage \(play.stage.rawValue))")
        }
        if witness.difficulty.shortest != witness.actions.count {
            result.append("\(name): recorded shortest \(witness.difficulty.shortest) differs from "
                          + "\(witness.actions.count) actions")
        }

        // The winning setting's terminal measure, near miss and non-coprime refusal.
        if play.stage == .won {
            let winning: LissajousLabyrinthDials = play.dials
            let terminal: LissajousLabyrinthTerminal = LissajousLabyrinthTerminal(winning, level: level)
            if terminal.visits != witness.terminal.visits { result.append("\(name): terminal visits differ") }
            if terminal.clearance != witness.terminal.clearance { result.append("\(name): terminal clearance differs") }
            if terminal.clearance != witness.difficulty.clearance {
                result.append("\(name): recorded clearance differs")
            }
            let nearMiss: LissajousLabyrinthNearMiss? = LissajousLabyrinthWitness.nearMiss(of: winning, level: level)
            let storedVerdict: LissajousLabyrinthVerdict? = witness.nearMiss.verdict.verdict
            if nearMiss != witness.nearMiss || storedVerdict == nil
                || LissajousLabyrinthLap.verdict(witness.nearMiss.dials, level: level) != storedVerdict {
                result.append("\(name): near miss differs")
            }
            if LissajousLabyrinthWitness.nonCoprime(of: winning) != witness.nonCoprime
                || !LissajousLabyrinthWitness.isRefused(witness.nonCoprime, from: winning, level: level) {
                result.append("\(name): non-coprime refusal differs")
            }
        }

        // The solver from the start: the certified shortest, the same winning actions, work within the bound and the
        // recorded winning-setting count.
        guard let solution = solved(level) else {
            result.append("\(name): solver finds no solution")
            return result
        }
        if solution.shortest != witness.actions.count {
            result.append("\(name): solver shortest \(solution.shortest) differs from \(witness.actions.count) actions")
        }
        if let why = replayProblem(level: level, actions: solution.actions) {
            result.append("\(name): solver actions do not win (\(why))")
        }
        for index in 0..<min(solution.actions.count, witness.actions.count) {
            if solution.actions[index].dial != witness.actions[index].dial {
                result.append("\(name): solution action \(index + 1) dial differs")
            }
            if solution.actions[index].value != witness.actions[index].value {
                result.append("\(name): solution action \(index + 1) value differs")
            }
        }
        if solution.work > workBound { result.append("\(name): solver work \(solution.work) above \(workBound)") }
        if solution.work != witness.difficulty.work {
            result.append("\(name): solver work \(solution.work) differs from recorded \(witness.difficulty.work)")
        }
        if solution.winningSettings != witness.difficulty.winningSettings {
            result.append("\(name): winning settings \(solution.winningSettings) differ from recorded "
                          + "\(witness.difficulty.winningSettings)")
        }

        // The strict decoder agrees: it re-verifies every stored value by replay.
        do {
            _ = try LissajousLabyrinthWitness.decode(try witness.encoded())
        } catch let error as LissajousLabyrinthError {
            result.append("\(name): witness refused (\(error.reasonCode))")
        } catch {
            result.append("\(name): witness unencodable (\(error))")
        }
        return result
    }

    /// Checks every level of `band` (20 levels) and records each problem.
    static func checkBand(_ band: Int) throws {
        var checked: Int = 0
        var largestWork: Int = 0
        for number in ((band - 1) * 20 + 1)...(band * 20) {
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: number)
            #expect(generated.level.band == band, "level \(number): band \(generated.level.band)")
            let data: Data = try witnessData(number)
            let witness: WitnessMirror = try JSONDecoder().decode(WitnessMirror.self, from: data)
            #expect(witness.number == number, "level \(number): witness number \(witness.number)")
            #expect(try witness.encoded() == data, "level \(number): witness file is not in its stored form")
            for problem in check(level: generated.level, witness: witness) {
                Issue.record(Comment(rawValue: problem))
            }
            #expect(generated.solution.winningSettings == witness.difficulty.winningSettings,
                    "level \(number): generator winning settings \(generated.solution.winningSettings)")
            #expect(generated.solution.shortest == witness.actions.count,
                    "level \(number): generator shortest \(generated.solution.shortest)")
            if let solution = solved(generated.level) {
                #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
                largestWork = max(largestWork, solution.work)
            }
            checked += 1
        }
        #expect(checked == 20)
        #expect(largestWork <= workBound, "band \(band): work \(largestWork)")
    }

    // MARK: The regression, one test per band (FR-R02G0208-001; SC-R02G0208-001; clarification Q1)

    @Test func band1Levels1To20() throws { try Self.checkBand(1) }
    @Test func band2Levels21To40() throws { try Self.checkBand(2) }
    @Test func band3Levels41To60() throws { try Self.checkBand(3) }
    @Test func band4Levels61To80() throws { try Self.checkBand(4) }
    @Test func band5Levels81To100() throws { try Self.checkBand(5) }

    // MARK: Alterations (FR-R02G0208-002; SC-R02G0208-002; clarification Q2)

    /// The certified levels altered: one of band 1 and one of band 5 (six checkpoints, eight obstacles).
    static let alteredNumbers: [Int] = [7, 86]

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: LissajousLabyrinthLevel, amplitudes: [Int]? = nil, frequencyC: Int? = nil,
                        start: LissajousLabyrinthDials? = nil, checkpoints: [LissajousLabyrinthBall]? = nil,
                        obstacles: [LissajousLabyrinthBall]? = nil,
                        allowance: Int? = nil) throws -> LissajousLabyrinthLevel {
        try LissajousLabyrinthLevel(id: level.id, seed: level.seed, band: level.band,
                                    amplitudes: amplitudes ?? level.amplitudes,
                                    frequencyC: frequencyC ?? level.frequencyC, start: start ?? level.start,
                                    checkpoints: checkpoints ?? level.checkpoints,
                                    obstacles: obstacles ?? level.obstacles, allowance: allowance ?? level.allowance,
                                    tutorial: level.tutorial)
    }

    /// `ball` moved by 8 · `step` along x, inward.
    static func moved(_ ball: LissajousLabyrinthBall, step: Int) throws -> LissajousLabyrinthBall {
        let dx: Int = 8 * step
        return try LissajousLabyrinthBall(x: ball.x > 0 ? ball.x - dx : ball.x + dx, y: ball.y, z: ball.z,
                                          radius: ball.radius)
    }

    /// The first level `make(variant)` builds for variant 1 … 8: a variant whose start would already win is refused
    /// by the initialiser (`won-at-start`), so the next one is tried.
    static func firstAccepted(_ make: (Int) throws -> LissajousLabyrinthLevel) throws -> LissajousLabyrinthLevel {
        var lastError: (any Error)? = nil
        for variant in 1...8 {
            do {
                return try make(variant)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? LissajousLabyrinthError.level("variant")
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

    /// The unaltered pair is clean, so every problem found below is the alteration's.
    @Test func theUnalteredLevelsAndWitnessesAreClean() throws {
        for number in Self.alteredNumbers {
            let level: LissajousLabyrinthLevel = try LissajousLabyrinthExperienceCore.level(number: number)
            let found: [String] = Self.check(level: level, witness: try Self.witness(number))
            #expect(found.isEmpty, "level \(number): \(found)")
        }
    }

    /// Level alterations: an amplitude, frequency C, a start dial, a checkpoint ball, an obstacle ball, the allowance.
    /// Each is rebuilt through the level initialiser, changes the fingerprint and is reported naming its part.
    @Test func levelAlterationsAreNamed() throws {
        for number in Self.alteredNumbers {
            let level: LissajousLabyrinthLevel = try LissajousLabyrinthExperienceCore.level(number: number)
            let witness: WitnessMirror = try Self.witness(number)
            var altered: [(String, String, LissajousLabyrinthLevel)] = []
            altered.append(("amplitude", "amplitude differs", try Self.firstAccepted { (k: Int) in
                var amplitudes: [Int] = level.amplitudes
                amplitudes[0] = (amplitudes[0] - 1 + k % 4) % 4 + 1
                return try Self.rebuilt(level, amplitudes: amplitudes)
            }))
            altered.append(("frequency C", "frequency C differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, frequencyC: (level.frequencyC - 1 + k) % 9 + 1)
            }))
            altered.append(("start dial", "start dial phaseC differs", try Self.firstAccepted { (k: Int) in
                var start: LissajousLabyrinthDials = level.start
                start.phaseC = (start.phaseC + k) % 16
                return try Self.rebuilt(level, start: start)
            }))
            altered.append(("checkpoint", "checkpoint 1 differs", try Self.firstAccepted { (k: Int) in
                var checkpoints: [LissajousLabyrinthBall] = level.checkpoints
                checkpoints[0] = try Self.moved(checkpoints[0], step: k)
                return try Self.rebuilt(level, checkpoints: checkpoints)
            }))
            altered.append(("obstacle", "obstacle 1 differs", try Self.firstAccepted { (k: Int) in
                var obstacles: [LissajousLabyrinthBall] = level.obstacles
                obstacles[0] = try Self.moved(obstacles[0], step: k)
                return try Self.rebuilt(level, obstacles: obstacles)
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

    /// Solution alterations: the first action's dial or value in the witness.
    @Test func solutionAlterationsAreNamed() throws {
        for number in Self.alteredNumbers {
            let level: LissajousLabyrinthLevel = try LissajousLabyrinthExperienceCore.level(number: number)
            let witness: WitnessMirror = try Self.witness(number)
            #expect(!witness.actions.isEmpty, "level \(number): no actions")
            if witness.actions.isEmpty { continue }
            let first: LissajousLabyrinthAction = witness.actions[0]

            var dialCopy: WitnessMirror = witness
            let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
            let next: LissajousLabyrinthDial = dials[((dials.firstIndex(of: first.dial) ?? 0) + 1) % dials.count]
            dialCopy.actions[0] = LissajousLabyrinthAction(dial: next, value: first.value)
            var valueCopy: WitnessMirror = witness
            let range: ClosedRange<Int> = first.dial.range
            let value: Int = first.value == range.upperBound ? range.lowerBound : first.value + 1
            valueCopy.actions[0] = LissajousLabyrinthAction(dial: first.dial, value: value)

            Self.expectNamed(Self.check(level: level, witness: dialCopy), number: number, kind: "action dial",
                             part: "solution action 1 dial differs")
            Self.expectNamed(Self.check(level: level, witness: valueCopy), number: number, kind: "action value",
                             part: "solution action 1 value differs")
        }
    }

    /// Witness alterations: the terminal visits, the near miss, the non-coprime refusal, a recorded fingerprint and the
    /// level fingerprint the witness stores.
    @Test func witnessAlterationsAreNamed() throws {
        for number in Self.alteredNumbers {
            let level: LissajousLabyrinthLevel = try LissajousLabyrinthExperienceCore.level(number: number)
            let witness: WitnessMirror = try Self.witness(number)
            var altered: [(String, String, WitnessMirror)] = []

            var terminal: WitnessMirror = witness
            var visits: [Int] = witness.terminal.visits
            visits[0] += 1
            terminal.terminal = LissajousLabyrinthTerminal(visits: visits, clearance: witness.terminal.clearance)
            altered.append(("terminal visits", "terminal visits differ", terminal))

            var nearMiss: WitnessMirror = witness
            let missAction: LissajousLabyrinthAction = witness.nearMiss.action
            let missRange: ClosedRange<Int> = missAction.dial.range
            let missValue: Int = missAction.value == missRange.upperBound ? missRange.lowerBound : missAction.value + 1
            nearMiss.nearMiss = LissajousLabyrinthNearMiss(
                action: LissajousLabyrinthAction(dial: missAction.dial, value: missValue),
                dials: witness.nearMiss.dials, verdict: witness.nearMiss.verdict)
            altered.append(("near miss", "near miss differs", nearMiss))

            var nonCoprime: WitnessMirror = witness
            nonCoprime.nonCoprime = LissajousLabyrinthNonCoprime(actions: witness.nonCoprime.actions,
                                                                 dials: witness.nonCoprime.dials,
                                                                 reason: "r02-g02.stage")
            altered.append(("non-coprime refusal", "non-coprime refusal differs", nonCoprime))

            var recorded: WitnessMirror = witness
            let last: Int = recorded.fingerprints.count - 1
            let lastFirst: Character = recorded.fingerprints[last].first ?? "0"
            recorded.fingerprints[last] = (lastFirst == "0" ? "1" : "0") + recorded.fingerprints[last].dropFirst()
            altered.append(("recorded fingerprint", "recorded fingerprint \(last) differs", recorded))

            var fingerprint: WitnessMirror = witness
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
