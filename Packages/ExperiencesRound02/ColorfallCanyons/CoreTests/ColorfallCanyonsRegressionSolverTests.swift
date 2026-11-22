// ColorfallCanyonsRegressionSolverTests — feature 348 (R02-G05-08) T-R02G0508-002 (FR-R02G0508-001, 002;
// SC-R02G0508-001, 002). The solver regression of all 100 certified levels in ten groups of 10, each group run as two
// tests of 5 levels so every test stays under 10 s (clarification Q1): the generated level equals the level of its
// witness file in docs/games/colorfall-canyons/levels (part by part and by fingerprint); the witness's actions replay
// on a fresh play to a win at exactly its win tick with exactly its per-tick fluid digests and play fingerprints;
// `ColorfallCanyonsSolver.solve` (to the band's search depth, as the generator and the witness decoder run it) returns
// exactly the witness's edit set, with `smaller`, the win tick and the work equal to the witness's. Then the twelve
// alterations of clarification Q2, each applied to a copy of level 1 (its level, the solver's solution or its witness),
// must be reported by the same `problems(level:witness:solution:)` with a message naming the level and the part
// ("level 1: flow rate differs"). Seed 2_348 picks the altered cells. Explicit types, plain loops, short runs; work is
// counted, never timed.
@testable import ColorfallCanyonsCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let regressionWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/colorfall-canyons/levels", isDirectory: true)

/// The stored level form, field by field, with its fingerprint as plain text so a test can change any one value.
fileprivate struct ColorfallCanyonsRegressionLevelMirror: Codable, Equatable {
    var schema: Int
    var id: String
    var seed: UInt64
    var difficulty: Int
    var columns: Int
    var rows: Int
    var heights: [Int]
    var grounds: [ColorfallCanyonsGround]
    var springs: [ColorfallCanyonsSpring]
    var basins: [ColorfallCanyonsBasin]
    var flowRate: Int
    var budget: Int
    var tickLimit: Int
    var tutorial: Bool
    var fingerprint: String
}

/// The stored witness form, mirrored field by field so a test can change one value and encode it again exactly.
fileprivate struct ColorfallCanyonsRegressionWitnessMirror: Codable, Equatable {
    var schema: Int
    var number: Int
    var level: ColorfallCanyonsRegressionLevelMirror
    var actions: [ColorfallCanyonsAction]
    var winTick: Int
    var digests: [String]
    var totals: ColorfallCanyonsWitness.Totals
    var fingerprints: [String]
    var unedited: ColorfallCanyonsCounterexample
    var nearMiss: ColorfallCanyonsCounterexample
    var smaller: Int
    var difficulty: ColorfallCanyonsDifficulty
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
private let regressionSolveCache: Mutex<[String: ColorfallCanyonsSolution]> =
    Mutex<[String: ColorfallCanyonsSolution]>([:])

@Suite struct ColorfallCanyonsRegressionSolverTests {
    /// The seed of this feature's choices (the altered cells).
    static let seed: UInt64 = 2_348

    // MARK: Helpers

    /// The stored witness file of manifest number `number`.
    static func witnessData(_ number: Int) throws -> Data {
        let name: String = String(ColorfallCanyonsGenerator.levelID(number).suffix(3)) + ".witness.json"
        return try Data(contentsOf: regressionWitnessDirectory.appendingPathComponent(name))
    }

    /// The stored witness of manifest number `number`, as its mirror.
    fileprivate static func witness(_ number: Int) throws -> ColorfallCanyonsRegressionWitnessMirror {
        try JSONDecoder().decode(ColorfallCanyonsRegressionWitnessMirror.self, from: try witnessData(number))
    }

    /// The band's search depth, as the generator and the witness decoder solve (the level's difficulty is its band).
    static func depth(_ level: ColorfallCanyonsLevel) -> Int {
        ColorfallCanyonsBandProfile.of(band: level.difficulty).smallest.upperBound
    }

    /// The solver's result for `level` at its band's depth, computed once per level fingerprint.
    static func solved(_ level: ColorfallCanyonsLevel) -> ColorfallCanyonsSolution? {
        if let cached = regressionSolveCache.withLock({ (cache: inout [String: ColorfallCanyonsSolution]) in
            cache[level.fingerprint]
        }) { return cached }
        guard let fresh = ColorfallCanyonsSolver.solve(level, depth: depth(level)) else { return nil }
        regressionSolveCache.withLock { (cache: inout [String: ColorfallCanyonsSolution]) in
            cache[level.fingerprint] = fresh
        }
        return fresh
    }

    /// Every disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, each naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win at exactly its win tick with exactly its per-tick digests and fingerprints, and the solution is
    /// exactly the witness's edit set with the witness's `smaller`, win tick and work.
    fileprivate static func problems(level: ColorfallCanyonsLevel, witness: ColorfallCanyonsRegressionWitnessMirror,
                                     solution: ColorfallCanyonsSolution?) -> [String] {
        var result: [String] = []
        let name: String = "level \(witness.number)"
        let stored: ColorfallCanyonsRegressionLevelMirror = witness.level

        // The level against the witness's level, part by part, then by fingerprint.
        if level.id != stored.id { result.append("\(name): id differs") }
        if level.seed != stored.seed { result.append("\(name): seed differs") }
        if level.difficulty != stored.difficulty { result.append("\(name): difficulty differs") }
        if level.columns != stored.columns || level.rows != stored.rows {
            result.append("\(name): grid size differs (\(level.columns) × \(level.rows), witness "
                          + "\(stored.columns) × \(stored.rows))")
        }
        if level.heights.count != stored.heights.count {
            result.append("\(name): cell count differs")
        } else {
            for cell in 0..<level.heights.count where level.heights[cell] != stored.heights[cell] {
                result.append("\(name): cell \(cell) height differs (\(level.heights[cell]), witness "
                              + "\(stored.heights[cell]))")
            }
        }
        if level.grounds.count == stored.grounds.count {
            for cell in 0..<level.grounds.count where level.grounds[cell] != stored.grounds[cell] {
                result.append("\(name): cell \(cell) ground differs")
            }
        }
        if level.springs.count != stored.springs.count {
            result.append("\(name): spring count differs")
        } else {
            for index in 0..<level.springs.count {
                let mine: ColorfallCanyonsSpring = level.springs[index]
                let theirs: ColorfallCanyonsSpring = stored.springs[index]
                if mine.cell != theirs.cell { result.append("\(name): spring \(index) cell differs") }
                if mine.color != theirs.color { result.append("\(name): spring \(index) colour differs") }
                if mine.release != theirs.release { result.append("\(name): spring \(index) release differs") }
                if mine.supply != theirs.supply { result.append("\(name): spring \(index) supply differs") }
                if mine.open != theirs.open { result.append("\(name): spring \(index) valve differs") }
            }
        }
        if level.basins.count != stored.basins.count {
            result.append("\(name): basin count differs")
        } else {
            for index in 0..<level.basins.count {
                let mine: ColorfallCanyonsBasin = level.basins[index]
                let theirs: ColorfallCanyonsBasin = stored.basins[index]
                if mine.cell != theirs.cell { result.append("\(name): basin \(index) cell differs") }
                if mine.capacity != theirs.capacity { result.append("\(name): basin \(index) capacity differs") }
                if mine.fill != theirs.fill { result.append("\(name): basin \(index) fill differs") }
                if mine.shares.count == 3 && theirs.shares.count == 3 {
                    for color in ColorfallCanyonsColor.allCases
                    where mine.shares[color.rawValue] != theirs.shares[color.rawValue] {
                        result.append("\(name): basin \(index) target share of \(color.name) differs")
                    }
                } else {
                    result.append("\(name): basin \(index) target share count differs")
                }
                if mine.tolerance != theirs.tolerance { result.append("\(name): basin \(index) share tolerance differs") }
                if mine.isProtected != theirs.isProtected { result.append("\(name): basin \(index) protection differs") }
                if mine.toleratedWrong != theirs.toleratedWrong {
                    result.append("\(name): basin \(index) wrong-mass tolerance differs")
                }
            }
        }
        if level.flowRate != stored.flowRate { result.append("\(name): flow rate differs") }
        if level.budget != stored.budget { result.append("\(name): budget differs") }
        if level.tickLimit != stored.tickLimit { result.append("\(name): tick limit differs") }
        if level.tutorial != stored.tutorial { result.append("\(name): tutorial differs") }
        if level.fingerprint != stored.fingerprint {
            result.append("\(name): level fingerprint differs (level \(level.fingerprint), witness "
                          + "\(stored.fingerprint))")
        }

        // The witness's own level: its content must rebuild to its stored fingerprint.
        do {
            let rebuilt: ColorfallCanyonsLevel = try ColorfallCanyonsLevel(
                id: stored.id, seed: stored.seed, difficulty: stored.difficulty, columns: stored.columns,
                rows: stored.rows, heights: stored.heights, grounds: stored.grounds, springs: stored.springs,
                basins: stored.basins, flowRate: stored.flowRate, budget: stored.budget, tickLimit: stored.tickLimit,
                tutorial: stored.tutorial)
            if rebuilt.fingerprint != stored.fingerprint {
                result.append("\(name): level fingerprint differs from the witness level's content")
            }
        } catch {
            result.append("\(name): witness level refused (\(error.reasonCode))")
        }

        // The witness replayed on a fresh play, tick by tick inside each step action: its fingerprints after the start
        // and after each action, its per-tick fluid digests, then a win at exactly its win tick.
        var play: ColorfallCanyonsPlay
        do {
            play = try ColorfallCanyonsExperienceCore.freshPlay(of: level)
        } catch {
            result.append("\(name): fresh play refused (\(error.reasonCode))")
            return result
        }
        var fingerprints: [String] = [play.fingerprint]
        var digests: [String] = []
        var refused: Bool = false
        for index in 0..<witness.actions.count {
            if play.stage != .playing {
                result.append("\(name): replay stage \(play.stage.rawValue) before action \(index + 1)")
                refused = true
                break
            }
            let action: ColorfallCanyonsAction = witness.actions[index]
            guard ColorfallCanyonsPlay.inRange(action, level: level) else {
                result.append("\(name): replay action \(index + 1) refused (range)")
                refused = true
                break
            }
            do {
                if case .step(let ticks) = action {
                    for _ in 0..<ticks where play.stage == .playing {
                        try play.apply(.step(1), expecting: play.fingerprint)
                        digests.append(ColorfallCanyonsWitness.digest(play.fluid))
                    }
                } else {
                    try play.apply(action, expecting: play.fingerprint)
                }
            } catch {
                result.append("\(name): replay action \(index + 1) refused (\(error.reasonCode))")
                refused = true
                break
            }
            fingerprints.append(play.fingerprint)
        }
        if !refused && play.stage != .won {
            result.append("\(name): replay does not win in \(witness.actions.count) actions "
                          + "(stage \(play.stage.rawValue))")
        }
        if play.fluid.tick != witness.winTick {
            result.append("\(name): replay win tick \(play.fluid.tick) differs from the witness's \(witness.winTick)")
        }
        if witness.difficulty.winTick != witness.winTick { result.append("\(name): recorded difficulty win tick differs") }
        if witness.fingerprints.count != fingerprints.count {
            result.append("\(name): recorded fingerprint count \(witness.fingerprints.count) differs "
                          + "(replay \(fingerprints.count))")
        }
        for index in 0..<min(fingerprints.count, witness.fingerprints.count)
        where fingerprints[index] != witness.fingerprints[index] {
            result.append("\(name): recorded fingerprint \(index) differs")
        }
        if witness.digests.count != digests.count {
            result.append("\(name): per-tick digest count \(witness.digests.count) differs (replay \(digests.count))")
        }
        for index in 0..<min(digests.count, witness.digests.count) where digests[index] != witness.digests[index] {
            result.append("\(name): per-tick digest \(index + 1) differs")
        }

        // The solver: exactly the witness's edit set, its smaller count, its win tick and its work; and the witness's
        // actions are the canonical actions of the solution.
        guard let edits = ColorfallCanyonsWitness.edits(of: witness.actions) else {
            result.append("\(name): witness actions are not edits followed by steps")
            return result
        }
        guard let solution else {
            result.append("\(name): solver finds no solution")
            return result
        }
        if solution.edits.count != edits.count {
            result.append("\(name): solution edit count \(solution.edits.count) differs from the witness's "
                          + "\(edits.count)")
        }
        for index in 0..<min(solution.edits.count, edits.count) where solution.edits[index] != edits[index] {
            result.append("\(name): solution edit \(index + 1) differs")
        }
        if solution.smallest != witness.difficulty.smallest {
            result.append("\(name): solver smallest \(solution.smallest) differs from certified "
                          + "\(witness.difficulty.smallest)")
        }
        if solution.smaller != witness.smaller {
            result.append("\(name): solver smaller \(solution.smaller) differs from the witness's \(witness.smaller)")
        }
        if solution.winTick != witness.winTick {
            result.append("\(name): solver win tick \(solution.winTick) differs from the witness's \(witness.winTick)")
        }
        if solution.work != witness.difficulty.work {
            result.append("\(name): solver work \(solution.work) differs from certified \(witness.difficulty.work)")
        }
        let canonical: [ColorfallCanyonsAction] = ColorfallCanyonsWitness.actions(for: solution, level: level)
        if canonical.count != witness.actions.count {
            result.append("\(name): action count \(witness.actions.count) differs from the solution's \(canonical.count)")
        }
        for index in 0..<min(canonical.count, witness.actions.count) where canonical[index] != witness.actions[index] {
            result.append("\(name): action \(index + 1) differs")
        }
        return result
    }

    /// Checks levels `first` … `last` of group `group` (group g holds levels 10·(g − 1) + 1 … 10·g; each group runs
    /// as two tests of 5 levels so every test stays under 10 s) and records each problem.
    static func checkGroup(_ group: Int, levels first: Int, _ last: Int) throws {
        #expect(first >= (group - 1) * 10 + 1 && last <= group * 10, "group \(group): levels \(first) … \(last)")
        var checked: Int = 0
        var largestWork: Int = 0
        for number in first...last {
            let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: number)
            let data: Data = try witnessData(number)
            let witness: ColorfallCanyonsRegressionWitnessMirror =
                try JSONDecoder().decode(ColorfallCanyonsRegressionWitnessMirror.self, from: data)
            #expect(witness.number == number, "level \(number): witness number \(witness.number)")
            #expect(try witness.encoded() == data, "level \(number): witness file is not in its stored form")
            #expect(generated.level.fingerprint == witness.level.fingerprint,
                    "level \(number): generated fingerprint differs from the witness's")
            let solution: ColorfallCanyonsSolution? = solved(generated.level)
            for problem in problems(level: generated.level, witness: witness, solution: solution) {
                Issue.record(Comment(rawValue: problem))
            }
            #expect(generated.difficulty == witness.difficulty, "level \(number): generator difficulty differs")
            #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
            if let solution {
                #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
                largestWork = max(largestWork, solution.work)
            }
            checked += 1
        }
        #expect(checked == last - first + 1)
        print("ColorfallCanyonsRegressionSolverTests group \(group) levels \(first) … \(last): "
              + "largest work \(largestWork)")
    }

    // MARK: The regression, ten groups of 10 as two tests of 5 each (FR-R02G0508-001; SC-R02G0508-001; Q1)

    @Test func group01Levels1To5() throws { try Self.checkGroup(1, levels: 1, 5) }
    @Test func group01Levels6To10() throws { try Self.checkGroup(1, levels: 6, 10) }
    @Test func group02Levels11To15() throws { try Self.checkGroup(2, levels: 11, 15) }
    @Test func group02Levels16To20() throws { try Self.checkGroup(2, levels: 16, 20) }
    @Test func group03Levels21To25() throws { try Self.checkGroup(3, levels: 21, 25) }
    @Test func group03Levels26To30() throws { try Self.checkGroup(3, levels: 26, 30) }
    @Test func group04Levels31To35() throws { try Self.checkGroup(4, levels: 31, 35) }
    @Test func group04Levels36To40() throws { try Self.checkGroup(4, levels: 36, 40) }
    @Test func group05Levels41To45() throws { try Self.checkGroup(5, levels: 41, 45) }
    @Test func group05Levels46To50() throws { try Self.checkGroup(5, levels: 46, 50) }
    @Test func group06Levels51To55() throws { try Self.checkGroup(6, levels: 51, 55) }
    @Test func group06Levels56To60() throws { try Self.checkGroup(6, levels: 56, 60) }
    @Test func group07Levels61To65() throws { try Self.checkGroup(7, levels: 61, 65) }
    @Test func group07Levels66To70() throws { try Self.checkGroup(7, levels: 66, 70) }
    @Test func group08Levels71To75() throws { try Self.checkGroup(8, levels: 71, 75) }
    @Test func group08Levels76To80() throws { try Self.checkGroup(8, levels: 76, 80) }
    @Test func group09Levels81To85() throws { try Self.checkGroup(9, levels: 81, 85) }
    @Test func group09Levels86To90() throws { try Self.checkGroup(9, levels: 86, 90) }
    @Test func group10Levels91To95() throws { try Self.checkGroup(10, levels: 91, 95) }
    @Test func group10Levels96To100() throws { try Self.checkGroup(10, levels: 96, 100) }

    // MARK: Alterations (FR-R02G0508-002; SC-R02G0508-002; clarification Q2)

    /// The certified level altered: level 1 (band 1, one spring, one basin, a small grid).
    static let alteredNumber: Int = 1

    /// `level` rebuilt through the initialiser with the given parts replaced.
    static func rebuilt(_ level: ColorfallCanyonsLevel, heights: [Int]? = nil, grounds: [ColorfallCanyonsGround]? = nil,
                        springs: [ColorfallCanyonsSpring]? = nil, basins: [ColorfallCanyonsBasin]? = nil,
                        flowRate: Int? = nil, budget: Int? = nil,
                        tickLimit: Int? = nil) throws -> ColorfallCanyonsLevel {
        try ColorfallCanyonsLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, columns: level.columns,
                                  rows: level.rows, heights: heights ?? level.heights, grounds: grounds ?? level.grounds,
                                  springs: springs ?? level.springs, basins: basins ?? level.basins,
                                  flowRate: flowRate ?? level.flowRate, budget: budget ?? level.budget,
                                  tickLimit: tickLimit ?? level.tickLimit, tutorial: level.tutorial)
    }

    /// `basin` with the given parts replaced.
    static func basin(_ basin: ColorfallCanyonsBasin, shares: [Int]? = nil,
                      toleratedWrong: Int? = nil) -> ColorfallCanyonsBasin {
        ColorfallCanyonsBasin(cell: basin.cell, capacity: basin.capacity, fill: basin.fill,
                              shares: shares ?? basin.shares, tolerance: basin.tolerance,
                              isProtected: basin.isProtected, toleratedWrong: toleratedWrong ?? basin.toleratedWrong)
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

    /// The unaltered triple is clean, so every problem found below is the alteration's.
    @Test func theUnalteredLevelWitnessAndSolutionAreClean() throws {
        let number: Int = Self.alteredNumber
        let level: ColorfallCanyonsLevel = try ColorfallCanyonsExperienceCore.level(number: number)
        let found: [String] = Self.problems(level: level, witness: try Self.witness(number), solution: Self.solved(level))
        #expect(found.isEmpty, "level \(number): \(found)")
    }

    /// Level alterations: a cell height, a cell ground, a spring's colour, the flow rate, the budget, the tick limit, a
    /// basin's target share and a basin's wrong-mass tolerance. Each is rebuilt through the level initialiser, changes
    /// the fingerprint and is reported naming its part (and the level fingerprint).
    @Test func levelAlterationsAreNamed() throws {
        let number: Int = Self.alteredNumber
        let level: ColorfallCanyonsLevel = try ColorfallCanyonsExperienceCore.level(number: number)
        let witness: ColorfallCanyonsRegressionWitnessMirror = try Self.witness(number)
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var altered: [(String, String, ColorfallCanyonsLevel)] = []

        // A cell height: a seeded cell one step higher (one lower at 15).
        let heightCell: Int = Int(random.next() % UInt64(level.cellCount))
        var heights: [Int] = level.heights
        heights[heightCell] = heights[heightCell] == 15 ? 14 : heights[heightCell] + 1
        altered.append(("cell height", "cell \(heightCell) height differs", try Self.rebuilt(level, heights: heights)))

        // A cell ground: a seeded open cell without a spring or basin turned to rock.
        var free: [Int] = []
        for cell in 0..<level.cellCount where level.kind(of: cell) == .open { free.append(cell) }
        #expect(!free.isEmpty, "level \(number): no free open cell")
        let groundCell: Int = free[Int(random.next() % UInt64(max(free.count, 1)))]
        var grounds: [ColorfallCanyonsGround] = level.grounds
        grounds[groundCell] = .rock
        altered.append(("cell ground", "cell \(groundCell) ground differs", try Self.rebuilt(level, grounds: grounds)))

        // A spring's colour: spring 0 with the next colour.
        let spring: ColorfallCanyonsSpring = level.springs[0]
        let nextColor: ColorfallCanyonsColor = ColorfallCanyonsColor(rawValue: (spring.color.rawValue + 1) % 3) ?? .cyan
        var springs: [ColorfallCanyonsSpring] = level.springs
        springs[0] = ColorfallCanyonsSpring(cell: spring.cell, color: nextColor, release: spring.release,
                                            supply: spring.supply, open: spring.open)
        altered.append(("spring colour", "spring 0 colour differs", try Self.rebuilt(level, springs: springs)))

        // The flow rate, the budget and the tick limit, each one step within its range.
        let flowRate: Int = level.flowRate == ColorfallCanyonsLevel.flowRates.upperBound ? level.flowRate - 1
            : level.flowRate + 1
        altered.append(("flow rate", "flow rate differs", try Self.rebuilt(level, flowRate: flowRate)))
        let budget: Int = level.budget == ColorfallCanyonsLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        altered.append(("budget", "budget differs", try Self.rebuilt(level, budget: budget)))
        let tickLimit: Int = level.tickLimit == ColorfallCanyonsLevel.tickLimits.upperBound ? level.tickLimit - 1
            : level.tickLimit + 1
        altered.append(("tick limit", "tick limit differs", try Self.rebuilt(level, tickLimit: tickLimit)))

        // A basin's target share: 10 per mille moved from basin 0's largest share to the next colour.
        let first: ColorfallCanyonsBasin = level.basins[0]
        var largest: Int = 0
        for c in 1..<3 where first.shares[c] > first.shares[largest] { largest = c }
        var shares: [Int] = first.shares
        shares[largest] -= 10
        shares[(largest + 1) % 3] += 10
        let shareColor: ColorfallCanyonsColor = ColorfallCanyonsColor(rawValue: largest) ?? .cyan
        var shareBasins: [ColorfallCanyonsBasin] = level.basins
        shareBasins[0] = Self.basin(first, shares: shares)
        altered.append(("basin target share", "basin 0 target share of \(shareColor.name) differs",
                        try Self.rebuilt(level, basins: shareBasins)))

        // A basin's wrong-mass tolerance: one unit more (one less at 999).
        var wrongBasins: [ColorfallCanyonsBasin] = level.basins
        wrongBasins[0] = Self.basin(first, toleratedWrong: first.toleratedWrong == 999 ? 998 : first.toleratedWrong + 1)
        altered.append(("basin wrong-mass tolerance", "basin 0 wrong-mass tolerance differs",
                        try Self.rebuilt(level, basins: wrongBasins)))

        #expect(altered.count == 8)
        for (kind, part, copy) in altered {
            #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(kind): same fingerprint")
            let found: [String] = Self.problems(level: copy, witness: witness, solution: Self.solved(copy))
            Self.expectNamed(found, number: number, kind: kind, part: part)
            Self.expectNamed(found, number: number, kind: kind, part: "level fingerprint differs")
        }
    }

    /// The solution alteration: the first edit of the solver's solution replaced by the next move of the level.
    @Test func solutionAlterationIsNamed() throws {
        let number: Int = Self.alteredNumber
        let level: ColorfallCanyonsLevel = try ColorfallCanyonsExperienceCore.level(number: number)
        let witness: ColorfallCanyonsRegressionWitnessMirror = try Self.witness(number)
        let solution: ColorfallCanyonsSolution? = Self.solved(level)
        #expect(solution != nil && !(solution?.edits.isEmpty ?? true), "level \(number): no edits")
        guard let solution, !solution.edits.isEmpty else { return }
        let moves: [ColorfallCanyonsEdit] = ColorfallCanyonsSolver.moves(level)
        var edits: [ColorfallCanyonsEdit] = solution.edits
        var replacement: ColorfallCanyonsEdit = edits[0]
        for move in moves where move != edits[0] {
            replacement = move
            break
        }
        edits[0] = replacement
        let copy: ColorfallCanyonsSolution = ColorfallCanyonsSolution(
            edits: edits, work: solution.work, smaller: solution.smaller, winTick: solution.winTick)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.problems(level: level, witness: witness, solution: copy), number: number,
                         kind: "solution edit", part: "solution edit 1 differs")
    }

    /// Witness alterations: an action, a per-tick digest and the level fingerprint the witness stores.
    @Test func witnessAlterationsAreNamed() throws {
        let number: Int = Self.alteredNumber
        let level: ColorfallCanyonsLevel = try ColorfallCanyonsExperienceCore.level(number: number)
        let witness: ColorfallCanyonsRegressionWitnessMirror = try Self.witness(number)
        let solution: ColorfallCanyonsSolution? = Self.solved(level)
        var altered: [(String, String, ColorfallCanyonsRegressionWitnessMirror)] = []

        // The last action (a step) one tick shorter (longer at 1): it still covers the win but is no longer canonical.
        var action: ColorfallCanyonsRegressionWitnessMirror = witness
        let last: Int = action.actions.count - 1
        if case .step(let ticks) = action.actions[last] {
            action.actions[last] = .step(ticks > 1 ? ticks - 1 : ticks + 1)
        } else {
            Issue.record("level \(number): last action is not a step")
        }
        altered.append(("action", "action \(last + 1) differs", action))

        // A per-tick digest: a seeded tick's digest with its first character changed.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var digest: ColorfallCanyonsRegressionWitnessMirror = witness
        let tick: Int = Int(random.next() % UInt64(max(digest.digests.count, 1)))
        let digestFirst: Character = digest.digests[tick].first ?? "0"
        digest.digests[tick] = (digestFirst == "0" ? "1" : "0") + digest.digests[tick].dropFirst()
        altered.append(("per-tick digest", "per-tick digest \(tick + 1) differs", digest))

        // The level fingerprint the witness stores, its first character changed.
        var fingerprint: ColorfallCanyonsRegressionWitnessMirror = witness
        let levelFirst: Character = fingerprint.level.fingerprint.first ?? "0"
        fingerprint.level.fingerprint = (levelFirst == "0" ? "1" : "0") + fingerprint.level.fingerprint.dropFirst()
        altered.append(("level fingerprint", "level fingerprint differs", fingerprint))

        #expect(altered.count == 3)
        for (kind, part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(kind): unchanged")
            Self.expectNamed(Self.problems(level: level, witness: copy, solution: solution), number: number,
                             kind: kind, part: part)
        }
    }
}
