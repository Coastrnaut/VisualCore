// HueCompassRegressionSolverTests — feature 338 (R02-G04-08) T-R02G0408-002 (FR-R02G0408-001, 002; SC-R02G0408-001,
// 002). The solver regression of all 100 certified levels, one test per band of 20 (clarification Q1): the generated
// level equals the level of its witness file in docs/games/hue-compass/levels (part by part and by fingerprint); the
// witness's actions replay on a fresh play to a win with exactly its recorded clues, counts and fingerprints, near miss
// and ambiguity; `HueCompassSolver.solve` returns a probe set of exactly the certified smallest size, equal to the
// witness's probe bearings, which settles the level (every class of `classes(_:probes:)` is accepted by the one selection
// `selection(for:in:)` gives), with work at most 4,657 (1 + 96 + 4,560) and equal to the certified solution's work. Then
// the fourteen alterations of clarification Q2, each applied to a copy of a certified level, solution or witness, must be
// reported by the same `problems(level:witness:solution:)` with a message naming the level and the part
// ("level 44: allowance differs"). Seed 2_338 picks the altered fog bearing. Explicit types, plain loops, short runs;
// work is counted, never timed.
@testable import HueCompassCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/hue-compass/levels", isDirectory: true)

/// The stored level form, field by field, with its fingerprint as plain text so a test can change any one value.
fileprivate struct HueCompassRegressionLevelMirror: Codable, Equatable {
    var schema: Int
    var id: String
    var seed: UInt64
    var band: Int
    var offset: Int
    var fog: [Int]
    var target: Int
    var start: Int
    var bearingTolerance: Int
    var bandTolerance: Int
    var allowance: Int
    var tutorial: Bool
    var fingerprint: String
}

/// The stored witness form, mirrored field by field so a test can change one value and encode it again exactly.
fileprivate struct HueCompassRegressionWitnessMirror: Codable, Equatable {
    var schema: Int
    var number: Int
    var level: HueCompassRegressionLevelMirror
    var actions: [HueCompassAction]
    var clues: [HueCompassClue]
    var counts: [Int]
    var fingerprints: [String]
    var nearMiss: HueCompassSelection
    var ambiguity: HueCompassAmbiguity
    var difficulty: HueCompassDifficulty
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
private let regressionSolveCache: Mutex<[String: HueCompassSolution]> = Mutex<[String: HueCompassSolution]>([:])

@Suite struct HueCompassRegressionSolverTests {
    /// The work bound of one solve: 1 + 96 + 4,560 probe sets tried at depth 2 (clarification Q1).
    static let workBound: Int = 4_657

    /// The seed of this feature's choices (the altered fog bearing).
    static let seed: UInt64 = 2_338

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(HueCompassGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, as its mirror.
    fileprivate static func witness(_ number: Int) throws -> HueCompassRegressionWitnessMirror {
        try JSONDecoder().decode(HueCompassRegressionWitnessMirror.self, from: try witnessData(number))
    }

    /// The solver's result for `level`, computed once per level fingerprint.
    static func solved(_ level: HueCompassLevel) -> HueCompassSolution? {
        if let cached = regressionSolveCache.withLock({ $0[level.fingerprint] }) { return cached }
        guard let fresh = HueCompassSolver.solve(level) else { return nil }
        regressionSolveCache.withLock { $0[level.fingerprint] = fresh }
        return fresh
    }

    /// The probe bearings of `actions` from `start`, in order (a turn moves the bearing, a probe samples it).
    static func probeBearings(_ actions: [HueCompassAction], start: Int) -> [Int] {
        var bearing: Int = start
        var probes: [Int] = []
        for action in actions {
            switch action {
            case .turn(let steps): bearing = HueCompassWheel.mod(bearing + steps, HueCompassWheel.bearings)
            case .probe: probes.append(bearing)
            case .select: break
            }
        }
        return probes
    }

    /// Nil when every class of the candidates after `probes` is accepted by the one selection `selection(for:in:)`
    /// gives it (checked member by member); otherwise why not.
    static func settleProblem(level: HueCompassLevel, probes: [Int]) -> String? {
        let groups: [[Int]] = HueCompassSolver.classes(level, probes: probes)
        for index in 0..<groups.count {
            guard let chosen = HueCompassSolver.selection(for: groups[index], in: level) else {
                return "class \(index + 1) of \(groups.count) has no selection"
            }
            for member in groups[index] {
                let bearingOK: Bool = HueCompassWheel.bearingDistance(chosen.bearing, member) <= level.bearingTolerance
                let bandOK: Bool =
                    HueCompassWheel.bandDistance(chosen.band, level.band(of: member)) <= level.bandTolerance
                if !bearingOK || !bandOK { return "class \(index + 1) member \(member) not accepted" }
            }
        }
        return nil
    }

    /// Every disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, each naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions are the canonical
    /// actions of the solution and replay to a win with exactly the recorded clues, counts and fingerprints, the near
    /// miss and ambiguity are reproduced, and the solution has the certified smallest size, settles the level and stays
    /// within (and equal to) the certified work.
    fileprivate static func problems(level: HueCompassLevel, witness: HueCompassRegressionWitnessMirror,
                                     solution: HueCompassSolution?) -> [String] {
        var result: [String] = []
        let name: String = "level \(witness.number)"
        let stored: HueCompassRegressionLevelMirror = witness.level

        // The level against the witness's level, part by part, then by fingerprint.
        if level.id != stored.id { result.append("\(name): id differs") }
        if level.seed != stored.seed { result.append("\(name): seed differs") }
        if level.band != stored.band { result.append("\(name): band differs") }
        if level.offset != stored.offset { result.append("\(name): hue offset differs") }
        if level.fog.count != stored.fog.count {
            result.append("\(name): fog count differs (\(level.fog.count), witness \(stored.fog.count))")
        } else {
            for index in 0..<level.fog.count where level.fog[index] != stored.fog[index] {
                result.append("\(name): fog density at bearing \(index) differs")
            }
        }
        if level.target != stored.target { result.append("\(name): target bearing differs") }
        if level.start != stored.start { result.append("\(name): start bearing differs") }
        if level.bearingTolerance != stored.bearingTolerance { result.append("\(name): bearing tolerance differs") }
        if level.bandTolerance != stored.bandTolerance { result.append("\(name): band tolerance differs") }
        if level.allowance != stored.allowance { result.append("\(name): allowance differs") }
        if level.tutorial != stored.tutorial { result.append("\(name): tutorial differs") }
        if level.fingerprint != stored.fingerprint {
            result.append("\(name): level fingerprint differs (level \(level.fingerprint), witness "
                          + "\(stored.fingerprint))")
        }

        // The witness's own level: its content must rebuild to its stored fingerprint.
        do {
            let rebuilt: HueCompassLevel = try HueCompassLevel(
                id: stored.id, seed: stored.seed, band: stored.band, offset: stored.offset, fog: stored.fog,
                target: stored.target, start: stored.start, bearingTolerance: stored.bearingTolerance,
                bandTolerance: stored.bandTolerance, allowance: stored.allowance, tutorial: stored.tutorial)
            if rebuilt.fingerprint != stored.fingerprint {
                result.append("\(name): level fingerprint differs from the witness level's content")
            }
        } catch {
            result.append("\(name): witness level refused (\(error.reasonCode))")
        }

        // The witness replayed on the level: its actions, its recorded clues and fingerprints, then a win.
        var play: HueCompassPlay
        do {
            play = try HueCompassExperienceCore.freshPlay(of: level)
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
        if !refused && play.stage != .won {
            result.append("\(name): replay does not win in \(witness.actions.count) actions "
                          + "(stage \(play.stage.rawValue))")
        }
        if witness.fingerprints.count != witness.actions.count + 1 {
            result.append("\(name): recorded fingerprint count \(witness.fingerprints.count) differs")
        }
        for index in 0..<min(replayed.count, witness.fingerprints.count)
        where replayed[index] != witness.fingerprints[index] {
            result.append("\(name): recorded fingerprint \(index) differs")
        }
        let clues: [HueCompassClue] = play.clues
        if clues.count != witness.clues.count {
            result.append("\(name): recorded clue count \(witness.clues.count) differs (replay \(clues.count))")
        }
        for index in 0..<min(clues.count, witness.clues.count) where clues[index] != witness.clues[index] {
            result.append("\(name): recorded clue \(index + 1) differs")
        }

        // The counts: after each probe, the size of the target's class among the candidates.
        let witnessProbes: [Int] = probeBearings(witness.actions, start: level.start)
        if witness.counts.count != witnessProbes.count {
            result.append("\(name): recorded count number \(witness.counts.count) differs")
        }
        for index in 0..<min(witness.counts.count, witnessProbes.count) {
            let prefix: [Int] = Array(witnessProbes[0...index])
            var size: Int = 0
            for group in HueCompassSolver.classes(level, probes: prefix) where group.contains(level.target) {
                size = group.count
            }
            if size != witness.counts[index] { result.append("\(name): recorded count \(index + 1) differs") }
        }

        // The near miss: bearing target + bearing tolerance + 1 with the target's band, which fails.
        let miss: HueCompassSelection = HueCompassWitness.nearMiss(of: level)
        if miss != witness.nearMiss { result.append("\(name): near miss differs") }
        if level.accepts(bearing: witness.nearMiss.bearing, band: witness.nearMiss.band) {
            result.append("\(name): near miss is accepted")
        }

        // The ambiguity: two targets sharing every clue of the smaller set that no one selection accepts together.
        let ambiguity: HueCompassAmbiguity = witness.ambiguity
        if ambiguity.targets.count == 2 {
            var together: Bool = false
            for group in HueCompassSolver.classes(level, probes: ambiguity.probes)
            where group.contains(ambiguity.targets[0]) && group.contains(ambiguity.targets[1]) {
                together = true
            }
            if !together { result.append("\(name): ambiguity differs (targets do not share every clue)") }
            if HueCompassSolver.selection(for: ambiguity.targets, in: level) != nil {
                result.append("\(name): ambiguity differs (one selection accepts both targets)")
            }
        } else {
            result.append("\(name): ambiguity differs (\(ambiguity.targets.count) targets)")
        }

        // The solver: the certified smallest, the witness's probe bearings, the canonical actions, a settling set, work
        // within the bound and equal to the certified work, the same ambiguity and difficulty.
        guard let solution else {
            result.append("\(name): solver finds no solution")
            return result
        }
        if solution.smallest != witness.difficulty.smallest {
            result.append("\(name): solver smallest \(solution.smallest) differs from certified "
                          + "\(witness.difficulty.smallest)")
        }
        if solution.probes.count != witnessProbes.count {
            result.append("\(name): solution probe count \(solution.probes.count) differs from the witness's "
                          + "\(witnessProbes.count)")
        }
        for index in 0..<min(solution.probes.count, witnessProbes.count)
        where solution.probes[index] != witnessProbes[index] {
            result.append("\(name): solution probe \(index + 1) bearing differs")
        }
        if let why = settleProblem(level: level, probes: solution.probes) {
            result.append("\(name): solution probes do not settle the level (\(why))")
        }
        let canonical: [HueCompassAction] = HueCompassWitness.actions(for: solution, level: level)
        if canonical.count != witness.actions.count {
            result.append("\(name): action count \(witness.actions.count) differs from the solution's \(canonical.count)")
        }
        for index in 0..<min(canonical.count, witness.actions.count) where canonical[index] != witness.actions[index] {
            result.append("\(name): action \(index + 1) differs")
        }
        if solution.work > workBound { result.append("\(name): solver work \(solution.work) above \(workBound)") }
        if solution.work != witness.difficulty.work {
            result.append("\(name): solver work \(solution.work) differs from certified \(witness.difficulty.work)")
        }
        if solution.ambiguity != ambiguity { result.append("\(name): ambiguity differs from the solver's") }
        let recomputed: HueCompassDifficulty = HueCompassDifficulty(
            smallest: solution.smallest, largestAfterBestSingle: solution.largestAfterBestSingle,
            bearingTolerance: level.bearingTolerance, bandTolerance: level.bandTolerance,
            clearShare: HueCompassBandProfile.of(band: level.band).clearShare, work: solution.work)
        if recomputed != witness.difficulty { result.append("\(name): recorded difficulty differs") }

        // The strict decoder agrees: it re-verifies every stored value by rebuilding the witness.
        let data: Data
        do {
            data = try witness.encoded()
        } catch {
            result.append("\(name): witness unencodable (\(error))")
            return result
        }
        do {
            _ = try HueCompassWitness.decode(data)
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
            let generated: HueCompassGenerated = try HueCompassExperienceCore.generated(number: number)
            #expect(generated.level.band == band, "level \(number): band \(generated.level.band)")
            let data: Data = try witnessData(number)
            let witness: HueCompassRegressionWitnessMirror =
                try JSONDecoder().decode(HueCompassRegressionWitnessMirror.self, from: data)
            #expect(witness.number == number, "level \(number): witness number \(witness.number)")
            #expect(try witness.encoded() == data, "level \(number): witness file is not in its stored form")
            #expect(generated.level.fingerprint == witness.level.fingerprint,
                    "level \(number): generated fingerprint differs from the witness's")
            let solution: HueCompassSolution? = solved(generated.level)
            for problem in problems(level: generated.level, witness: witness, solution: solution) {
                Issue.record(Comment(rawValue: problem))
            }
            #expect(generated.solution.smallest == witness.difficulty.smallest,
                    "level \(number): generator smallest \(generated.solution.smallest)")
            #expect(generated.difficulty == witness.difficulty, "level \(number): generator difficulty differs")
            #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
            if let solution {
                #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
                largestWork = max(largestWork, solution.work)
            }
            checked += 1
        }
        #expect(checked == 20)
        #expect(largestWork <= workBound, "band \(band): work \(largestWork)")
        print("HueCompassRegressionSolverTests band \(band): largest work \(largestWork)")
        return largestWork
    }

    // MARK: The regression, one test per band (FR-R02G0408-001; SC-R02G0408-001; clarification Q1)

    @Test func band1Levels1To20() throws { try Self.checkBand(1) }
    @Test func band2Levels21To40() throws { try Self.checkBand(2) }
    @Test func band3Levels41To60() throws { try Self.checkBand(3) }
    @Test func band4Levels61To80() throws { try Self.checkBand(4) }
    @Test func band5Levels81To100() throws { try Self.checkBand(5) }

    // MARK: Alterations (FR-R02G0408-002; SC-R02G0408-002; clarification Q2)

    /// The certified levels altered: one of band 3 (one probe) and one of band 5 (two probes).
    static let alteredNumbers: [Int] = [44, 87]

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: HueCompassLevel, offset: Int? = nil, fog: [Int]? = nil, target: Int? = nil,
                        start: Int? = nil, bearingTolerance: Int? = nil, bandTolerance: Int? = nil,
                        allowance: Int? = nil) throws -> HueCompassLevel {
        try HueCompassLevel(id: level.id, seed: level.seed, band: level.band, offset: offset ?? level.offset,
                            fog: fog ?? level.fog, target: target ?? level.target, start: start ?? level.start,
                            bearingTolerance: bearingTolerance ?? level.bearingTolerance,
                            bandTolerance: bandTolerance ?? level.bandTolerance,
                            allowance: allowance ?? level.allowance, tutorial: level.tutorial)
    }

    /// The first level `make(variant)` builds for variant 1 … 48: a variant the initialiser refuses (a start already
    /// within the tolerance of the target, a value out of range) is skipped and the next one tried.
    static func firstAccepted(_ make: (Int) throws -> HueCompassLevel) throws -> HueCompassLevel {
        var lastError: (any Error)? = nil
        for variant in 1...48 {
            do {
                return try make(variant)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? HueCompassError.level("variant")
    }

    /// Records an issue unless `found` holds a message that starts with the level's name and names `part`, and every
    /// message starts with the level's name.
    static func expectNamed(_ found: [String], number: Int, kind: String, part: String) {
        var named: Bool = false
        for message in found where message.hasPrefix("level \(number): ") && message.contains(part) { named = true }
        #expect(named, "level \(number) alteration \(kind): no message naming \"\(part)\" in \(found)")
        for message in found {
            #expect(message.hasPrefix("level \(number): "), "level \(number) alteration \(kind): message \(message)")
        }
    }

    /// The unaltered triples are clean, so every problem found below is the alteration's.
    @Test func theUnalteredLevelsWitnessesAndSolutionsAreClean() throws {
        for number in Self.alteredNumbers {
            let level: HueCompassLevel = try HueCompassExperienceCore.level(number: number)
            let found: [String] = Self.problems(level: level, witness: try Self.witness(number),
                                                solution: Self.solved(level))
            #expect(found.isEmpty, "level \(number): \(found)")
        }
    }

    /// Level alterations: the hue offset, a fog density, the target bearing, the start bearing, the bearing tolerance,
    /// the band tolerance and the allowance. Each is rebuilt through the level initialiser, changes the fingerprint and is
    /// reported naming its part (and the level fingerprint).
    @Test func levelAlterationsAreNamed() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for number in Self.alteredNumbers {
            let level: HueCompassLevel = try HueCompassExperienceCore.level(number: number)
            let witness: HueCompassRegressionWitnessMirror = try Self.witness(number)
            let n: Int = HueCompassWheel.bearings
            var altered: [(String, String, HueCompassLevel)] = []
            altered.append(("hue offset", "hue offset differs",
                            try Self.rebuilt(level, offset: (level.offset + 1) % HueCompassWheel.bands)))
            let fogBearing: Int = Int(random.next() % UInt64(n))
            var fog: [Int] = level.fog
            fog[fogBearing] = (fog[fogBearing] + 1) % 10
            altered.append(("fog density", "fog density at bearing \(fogBearing) differs",
                            try Self.rebuilt(level, fog: fog)))
            altered.append(("target bearing", "target bearing differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, target: HueCompassWheel.mod(level.target + k, n))
            }))
            altered.append(("start bearing", "start bearing differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, start: HueCompassWheel.mod(level.start + k, n))
            }))
            altered.append(("bearing tolerance", "bearing tolerance differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, bearingTolerance: (level.bearingTolerance + k) % 5)
            }))
            altered.append(("band tolerance", "band tolerance differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, bandTolerance: (level.bandTolerance + k) % 3)
            }))
            altered.append(("allowance", "allowance differs", try Self.firstAccepted { (k: Int) in
                try Self.rebuilt(level, allowance: level.allowance == 24 ? 24 - k : level.allowance + k)
            }))
            #expect(altered.count == 7)
            for (kind, part, copy) in altered {
                #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(kind): same fingerprint")
                let found: [String] = Self.problems(level: copy, witness: witness, solution: Self.solved(copy))
                Self.expectNamed(found, number: number, kind: kind, part: part)
                Self.expectNamed(found, number: number, kind: kind, part: "level fingerprint differs")
            }
        }
    }

    /// The solution alteration: the first probe bearing of the solver's solution, one bearing on.
    @Test func solutionAlterationIsNamed() throws {
        for number in Self.alteredNumbers {
            let level: HueCompassLevel = try HueCompassExperienceCore.level(number: number)
            let witness: HueCompassRegressionWitnessMirror = try Self.witness(number)
            let solution: HueCompassSolution? = Self.solved(level)
            #expect(solution != nil && !(solution?.probes.isEmpty ?? true), "level \(number): no probes")
            guard let solution, !solution.probes.isEmpty else { continue }
            var probes: [Int] = solution.probes
            probes[0] = HueCompassWheel.mod(probes[0] + 1, HueCompassWheel.bearings)
            if probes.count == 2 && probes[0] == probes[1] {
                probes[0] = HueCompassWheel.mod(probes[0] + 1, HueCompassWheel.bearings)
            }
            let copy: HueCompassSolution = HueCompassSolution(
                probes: probes, work: solution.work, bestSingle: solution.bestSingle,
                largestAfterBestSingle: solution.largestAfterBestSingle, ambiguity: solution.ambiguity)
            #expect(copy != solution, "level \(number): solution unchanged")
            Self.expectNamed(Self.problems(level: level, witness: witness, solution: copy), number: number,
                             kind: "solution probe bearing", part: "solution probe 1 bearing differs")
        }
    }

    /// Witness alterations: an action, a clue, the near miss, the ambiguity, a recorded fingerprint and the level
    /// fingerprint the witness stores.
    @Test func witnessAlterationsAreNamed() throws {
        for number in Self.alteredNumbers {
            let level: HueCompassLevel = try HueCompassExperienceCore.level(number: number)
            let witness: HueCompassRegressionWitnessMirror = try Self.witness(number)
            let solution: HueCompassSolution? = Self.solved(level)
            var altered: [(String, String, HueCompassRegressionWitnessMirror)] = []

            // The selection (the last action) with the next band: no longer the canonical action.
            var action: HueCompassRegressionWitnessMirror = witness
            let last: Int = action.actions.count - 1
            if case .select(let bearing, let band) = action.actions[last] {
                action.actions[last] = .select(bearing: bearing, band: (band + 1) % HueCompassWheel.bands)
            } else {
                Issue.record("level \(number): last action is not a selection")
            }
            altered.append(("action", "action \(last + 1) differs", action))

            var clue: HueCompassRegressionWitnessMirror = witness
            let firstClue: HueCompassClue = witness.clues[0]
            clue.clues[0] = HueCompassClue(bearing: firstClue.bearing, hueGap: firstClue.hueGap,
                                           depth: firstClue.depth + 1)
            altered.append(("clue", "recorded clue 1 differs", clue))

            var nearMiss: HueCompassRegressionWitnessMirror = witness
            nearMiss.nearMiss = HueCompassSelection(
                bearing: HueCompassWheel.mod(witness.nearMiss.bearing + 1, HueCompassWheel.bearings),
                band: witness.nearMiss.band)
            altered.append(("near miss", "near miss differs", nearMiss))

            var ambiguity: HueCompassRegressionWitnessMirror = witness
            let targets: [Int] = witness.ambiguity.targets
            ambiguity.ambiguity = HueCompassAmbiguity(probes: witness.ambiguity.probes, targets: [targets[1], targets[0]])
            altered.append(("ambiguity", "ambiguity differs", ambiguity))

            var recorded: HueCompassRegressionWitnessMirror = witness
            let lastPrint: Int = recorded.fingerprints.count - 1
            let lastFirst: Character = recorded.fingerprints[lastPrint].first ?? "0"
            recorded.fingerprints[lastPrint] =
                (lastFirst == "0" ? "1" : "0") + recorded.fingerprints[lastPrint].dropFirst()
            altered.append(("recorded fingerprint", "recorded fingerprint \(lastPrint) differs", recorded))

            var fingerprint: HueCompassRegressionWitnessMirror = witness
            let levelFirst: Character = fingerprint.level.fingerprint.first ?? "0"
            fingerprint.level.fingerprint = (levelFirst == "0" ? "1" : "0") + fingerprint.level.fingerprint.dropFirst()
            altered.append(("level fingerprint", "level fingerprint differs", fingerprint))

            #expect(altered.count == 6)
            for (kind, part, copy) in altered {
                #expect(copy != witness, "level \(number) alteration \(kind): unchanged")
                Self.expectNamed(Self.problems(level: level, witness: copy, solution: solution), number: number,
                                 kind: kind, part: part)
            }
        }
    }
}
