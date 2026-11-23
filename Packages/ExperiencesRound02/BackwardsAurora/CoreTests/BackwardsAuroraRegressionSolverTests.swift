// BackwardsAuroraRegressionSolverTests — feature 398 (R02-G10-08) T-R02G1008-002 (FR-R02G1008-001, 002;
// SC-R02G1008-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/backwards-aurora/levels (part by part and by fingerprint); the witness's reversals replay on a fresh play
// (begun, the tutorial dismissed) to a win on the last reversal in exactly its smallest reversal count (equal to the
// lower bound's ⌈β / 4⌉), within the budget, with exactly its per-reversal digests (`BackwardsAuroraWitness.digest` of
// the wave after each reversal) and play fingerprints (after the start and after each reversal);
// `BackwardsAuroraSolver.solve` returns exactly the witness's reversals with `smallest` equal to the witness's and to
// `lowerBound(level).smallest`, and its work is at most `BackwardsAuroraSolver.workBound` (counted, never timed). The
// 100 levels are generated concurrently once per process (through the experience core's cache) so each test stays
// short. Then the ten alterations of clarification Q2, each applied to a copy of level 1 (band 1, a tutorial level)
// and of level 41 (band 3): the pure `firstFailure(level:witness:solution:)` must name exactly the altered part
// ("target sample", "checkpoint", "budget", "bend limit", "breaking limit", "solution reversal", "witness reversal",
// "per-reversal digest", "per-reversal fingerprint", "smallest reversal count") in a message naming the level
// ("level 41: budget differs …"), and the unaltered input must give nil. Every alteration is fixed (no random source is
// needed), the level ones are built through the level initialiser, and the stored witnesses are read with the plain
// decoder. Explicit types, plain loops, short runs.
@testable import BackwardsAuroraCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/backwards-aurora/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache).
private let regressionSolverCatalogResult: Result<[BackwardsAuroraGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? BackwardsAuroraExperienceCore.generated(number: index + 1)
    }
    var catalog: [BackwardsAuroraGenerated] = []
    for number in 1...100 { catalog.append(try BackwardsAuroraExperienceCore.generated(number: number)) }
    return catalog
}

/// A failure of the regression: the part that differs first and the message naming the level and that part.
struct BackwardsAuroraRegressionFailure: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level or witness.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

@Suite struct BackwardsAuroraRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level) and level 41 (band 3).
    static let alteredNumbers: [Int] = [1, 41]

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> BackwardsAuroraWitness {
        let name: String = String(BackwardsAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(BackwardsAuroraWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> BackwardsAuroraGenerated {
        let catalog: [BackwardsAuroraGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A failure of `part` for `name` with the detail `detail`.
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> BackwardsAuroraRegressionFailure {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return BackwardsAuroraRegressionFailure(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The first position where `lhs` and `rhs` differ (the shorter length when one is a prefix), or nil when equal.
    static func firstDifference(_ lhs: [Int], _ rhs: [Int]) -> Int? {
        let shared: Int = min(lhs.count, rhs.count)
        for index in 0..<shared where lhs[index] != rhs[index] { return index }
        return lhs.count == rhs.count ? nil : shared
    }

    /// The independent replay of `actions` on a fresh play of `level` (begun, the tutorial dismissed), as the witness
    /// computes it: the play fingerprint after the start and after each reversal, the `BackwardsAuroraWitness.digest`
    /// of the wave after each reversal, and whether any reversal but the first was applied to a play no longer
    /// playing; nil when a stage event or a reversal is refused.
    static func replayed(_ level: BackwardsAuroraLevel, _ actions: [BackwardsAuroraAction])
        -> (play: BackwardsAuroraPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play: BackwardsAuroraPlay = BackwardsAuroraPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(BackwardsAuroraWitness.digest(play.wave))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The first disagreement of `level` with its stored witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: BackwardsAuroraLevel, stored: BackwardsAuroraLevel,
                             name: String) -> BackwardsAuroraRegressionFailure? {
        if level.id != stored.id { return failure(name, "id") }
        if level.seed != stored.seed { return failure(name, "seed") }
        if level.difficulty != stored.difficulty { return failure(name, "difficulty") }
        if let position = firstDifference(level.opening.samples, stored.opening.samples) {
            return failure(name, "opening sample", "position \(position)")
        }
        if let position = firstDifference(level.target.samples, stored.target.samples) {
            return failure(name, "target sample", "position \(position)")
        }
        if let index = firstDifference(level.checkpoints, stored.checkpoints) {
            return failure(name, "checkpoint", "checkpoint \(index + 1)")
        }
        if level.bendLimit != stored.bendLimit {
            return failure(name, "bend limit", "\(level.bendLimit), witness \(stored.bendLimit)")
        }
        if level.breakingLimit != stored.breakingLimit {
            return failure(name, "breaking limit", "\(level.breakingLimit), witness \(stored.breakingLimit)")
        }
        if level.shortest != stored.shortest || level.longest != stored.longest {
            return failure(name, "section lengths")
        }
        if level.budget != stored.budget {
            return failure(name, "budget", "\(level.budget), witness \(stored.budget)")
        }
        if level.tutorial != stored.tutorial { return failure(name, "tutorial") }
        if level.fingerprint != stored.fingerprint { return failure(name, "level fingerprint") }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's reversals replay on a fresh
    /// play to a win on the last reversal in exactly its smallest reversal count (the lower bound's) within the budget
    /// with exactly its per-reversal digests and play fingerprints, and the solution's reversals and smallest equal the
    /// witness's with work at most `BackwardsAuroraSolver.workBound`. A replay the play refuses is a named failure,
    /// never a crash. Pure.
    static func firstFailure(level: BackwardsAuroraLevel, witness: BackwardsAuroraWitness,
                             solution: BackwardsAuroraSolution?) -> BackwardsAuroraRegressionFailure? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let found = levelFailure(level, stored: witness.level, name: name) { return found }

        // The witness's reversals replayed on a fresh play: a win on the last reversal and not before.
        guard let run = replayed(level, witness.actions) else {
            return failure(name, "witness reversal", "replay refused")
        }
        if run.endedEarly { return failure(name, "witness reversal", "the play ends before the last reversal") }
        if run.play.stage != .won {
            return failure(name, "witness reversal", "replay does not win (stage \(run.play.stage.rawValue))")
        }

        // The smallest reversal count: the reversals, the replay, the lower bound and the budget.
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        if witness.smallest != witness.actions.count {
            return failure(name, "smallest reversal count", "\(witness.smallest), \(witness.actions.count) reversals")
        }
        if witness.smallest != run.play.spent {
            return failure(name, "smallest reversal count", "\(witness.smallest), replay \(run.play.spent) reversals")
        }
        if witness.smallest != bound.smallest {
            return failure(name, "smallest reversal count", "\(witness.smallest), lower bound \(bound.smallest)")
        }
        if witness.smallest > level.budget {
            return failure(name, "smallest reversal count", "\(witness.smallest) exceeds the budget \(level.budget)")
        }
        if witness.bound != bound { return failure(name, "lower bound", "\(witness.bound.badBends) bad bends") }

        // The per-reversal digests and play fingerprints.
        if run.digests.count != witness.digests.count {
            return failure(name, "per-reversal digest", "count \(witness.digests.count), replay \(run.digests.count)")
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.digests[index] {
            return failure(name, "per-reversal digest", "reversal \(index + 1)")
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return failure(name, "per-reversal fingerprint",
                           "count \(witness.fingerprints.count), replay \(run.fingerprints.count)")
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return failure(name, "per-reversal fingerprint", "after reversal \(index)")
        }

        // The solver: exactly the witness's reversals and smallest; work within the bound.
        guard let solution else { return failure(name, "solution reversal", "the solver finds no solution") }
        if solution.actions.count != witness.actions.count {
            return failure(name, "solution reversal",
                           "count \(solution.actions.count), witness \(witness.actions.count)")
        }
        for index in 0..<solution.actions.count where solution.actions[index] != witness.actions[index] {
            return failure(name, "solution reversal", "reversal \(index + 1)")
        }
        if solution.smallest != witness.smallest || solution.smallest != bound.smallest {
            return failure(name, "smallest reversal count",
                           "solver \(solution.smallest), witness \(witness.smallest)")
        }
        if solution.work > BackwardsAuroraSolver.workBound {
            return failure(name, "solver work", "\(solution.work) exceeds \(BackwardsAuroraSolver.workBound)")
        }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: BackwardsAuroraGenerated = try generated(number)
        let witness: BackwardsAuroraWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let solution: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(generated.level)
        let found: BackwardsAuroraRegressionFailure? = firstFailure(level: generated.level, witness: witness,
                                                                    solution: solution)
        #expect(found == nil, Comment(rawValue: found?.message ?? ""))
        #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
        #expect((solution?.work ?? Int.max) <= BackwardsAuroraSolver.workBound,
                "level \(number): solver work above the bound")
        #expect(solution?.work == witness.difficulty.work, "level \(number): solver work differs from the witness's")
        #expect(generated.bound == witness.bound, "level \(number): bound differs")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1008-001; SC-R02G1008-001; Q1)

    @Test(arguments: Array(0..<10)) func group01(index: Int) throws { try Self.check(group: 1, index: index) }
    @Test(arguments: Array(0..<10)) func group02(index: Int) throws { try Self.check(group: 2, index: index) }
    @Test(arguments: Array(0..<10)) func group03(index: Int) throws { try Self.check(group: 3, index: index) }
    @Test(arguments: Array(0..<10)) func group04(index: Int) throws { try Self.check(group: 4, index: index) }
    @Test(arguments: Array(0..<10)) func group05(index: Int) throws { try Self.check(group: 5, index: index) }
    @Test(arguments: Array(0..<10)) func group06(index: Int) throws { try Self.check(group: 6, index: index) }
    @Test(arguments: Array(0..<10)) func group07(index: Int) throws { try Self.check(group: 7, index: index) }
    @Test(arguments: Array(0..<10)) func group08(index: Int) throws { try Self.check(group: 8, index: index) }
    @Test(arguments: Array(0..<10)) func group09(index: Int) throws { try Self.check(group: 9, index: index) }
    @Test(arguments: Array(0..<10)) func group10(index: Int) throws { try Self.check(group: 10, index: index) }

    // MARK: Alterations (FR-R02G1008-002; SC-R02G1008-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: BackwardsAuroraLevel, target: BackwardsAuroraWave? = nil, checkpoints: [Int]? = nil,
                        bendLimit: Int? = nil, breakingLimit: Int? = nil,
                        budget: Int? = nil) throws -> BackwardsAuroraLevel {
        try BackwardsAuroraLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, opening: level.opening,
                                 target: target ?? level.target, checkpoints: checkpoints ?? level.checkpoints,
                                 bendLimit: bendLimit ?? level.bendLimit,
                                 breakingLimit: breakingLimit ?? level.breakingLimit, shortest: level.shortest,
                                 longest: level.longest, budget: budget ?? level.budget, tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: BackwardsAuroraWitness, actions: [BackwardsAuroraAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        smallest: Int? = nil) -> BackwardsAuroraWitness {
        BackwardsAuroraWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                               digests: digests ?? witness.digests,
                               fingerprints: fingerprints ?? witness.fingerprints,
                               smallest: smallest ?? witness.smallest, bound: witness.bound,
                               nearMiss: witness.nearMiss, difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The target with two samples of different heights exchanged (the first sample and the first later one of a
    /// different height), so the multiset of heights, which the level initialiser requires, is kept; nil when every
    /// sample has the same height.
    static func targetAltered(_ target: BackwardsAuroraWave) throws -> BackwardsAuroraWave? {
        var samples: [Int] = target.samples
        for index in 1..<samples.count where samples[index] != samples[0] {
            samples.swapAt(0, index)
            return try BackwardsAuroraWave(samples)
        }
        return nil
    }

    /// The checkpoints with the first one moved to the smallest position that is not a checkpoint.
    static func checkpointsAltered(_ level: BackwardsAuroraLevel) -> [Int] {
        var checkpoints: [Int] = level.checkpoints
        for position in 0..<level.count where !checkpoints.contains(position) {
            checkpoints[0] = position
            return checkpoints
        }
        return checkpoints
    }

    /// The fixed variations of `action`, in order: the section moved one sample right, one left, then lengthened at
    /// the end, then at the start. Some variations may be out of range; the play then refuses them.
    static func variations(_ action: BackwardsAuroraAction) -> [BackwardsAuroraAction] {
        switch action {
        case let .reverse(start, end):
            return [.reverse(start + 1, end + 1), .reverse(start - 1, end - 1), .reverse(start, end + 1),
                    .reverse(start - 1, end)]
        }
    }

    /// The witness's reversals with the last one replaced by its first variation that no longer wins on a fresh play
    /// (refused or not won); nil when every variation still wins.
    static func losingWitnessReversals(_ level: BackwardsAuroraLevel,
                                       _ actions: [BackwardsAuroraAction]) -> [BackwardsAuroraAction]? {
        let last: Int = actions.count - 1
        for variation in variations(actions[last]) {
            var altered: [BackwardsAuroraAction] = actions
            altered[last] = variation
            if !BackwardsAuroraSolver.wins(level, actions: altered) { return altered }
        }
        return nil
    }

    /// Records an issue unless `found` names exactly `part` in a message naming level `number` and the part.
    static func expectNamed(_ found: BackwardsAuroraRegressionFailure?, number: Int, part: String) {
        let message: String = found?.message ?? "(none)"
        #expect(found?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
    }

    /// The unaltered level, witness and solution are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: BackwardsAuroraLevel = try Self.generated(number).level
        let found: BackwardsAuroraRegressionFailure? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                                                         solution: BackwardsAuroraSolver.solve(level))
        #expect(found == nil, "level \(number): \(found?.message ?? "")")
    }

    /// Level alterations: a target sample, a checkpoint, the budget, the bend limit and the breaking limit, each
    /// rebuilt through the level initialiser (which accepts every one) and named exactly. The level is compared first,
    /// so the unaltered solution is passed and no altered level is solved.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: BackwardsAuroraGenerated = try Self.generated(number)
        let level: BackwardsAuroraLevel = generated.level
        let witness: BackwardsAuroraWitness = try Self.witness(number)
        var altered: [(String, BackwardsAuroraLevel)] = []

        // A target sample: two samples of different heights exchanged.
        let target: BackwardsAuroraWave? = try Self.targetAltered(level.target)
        #expect(target != nil, "level \(number): a flat target")
        if let target { altered.append(("target sample", try Self.rebuilt(level, target: target))) }

        // A checkpoint: the first one moved to the smallest free position.
        let checkpoints: [Int] = Self.checkpointsAltered(level)
        altered.append(("checkpoint", try Self.rebuilt(level, checkpoints: checkpoints)))

        // The budget: one more (one less at the largest budget).
        let budget: Int = level.budget == BackwardsAuroraLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        altered.append(("budget", try Self.rebuilt(level, budget: budget)))

        // The bend limit: one more while it stays within the breaking limit and the range, otherwise one less.
        let bendLimit: Int = level.bendLimit < min(level.breakingLimit, BackwardsAuroraLevel.bendLimits.upperBound)
            ? level.bendLimit + 1 : level.bendLimit - 1
        altered.append(("bend limit", try Self.rebuilt(level, bendLimit: bendLimit)))

        // The breaking limit: one more (one less at the largest).
        let breakingLimit: Int = level.breakingLimit == BackwardsAuroraLevel.maximumBreakingLimit
            ? level.breakingLimit - 1 : level.breakingLimit + 1
        altered.append(("breaking limit", try Self.rebuilt(level, breakingLimit: breakingLimit)))

        #expect(altered.count == 5)
        for (part, copy) in altered {
            #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: copy, witness: witness, solution: generated.solution),
                             number: number, part: part)
        }
    }

    /// The solution alteration: the solver's first reversal replaced by its first variation.
    @Test(arguments: alteredNumbers) func solutionAlterationIsNamed(number: Int) throws {
        let level: BackwardsAuroraLevel = try Self.generated(number).level
        let witness: BackwardsAuroraWitness = try Self.witness(number)
        let solution: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(level)
        #expect(solution != nil, "level \(number): no solution")
        guard let solution else { return }
        let variations: [BackwardsAuroraAction] = Self.variations(solution.actions[0])
        #expect(!variations.isEmpty, "level \(number): the first reversal has no variation")
        guard let variation = variations.first else { return }
        var actions: [BackwardsAuroraAction] = solution.actions
        actions[0] = variation
        let copy: BackwardsAuroraSolution = BackwardsAuroraSolution(smallest: solution.smallest, actions: actions,
                                                                    work: solution.work)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, solution: copy), number: number,
                         part: "solution reversal")
    }

    /// Witness alterations: a reversal, a per-reversal digest, a per-reversal fingerprint and the smallest reversal
    /// count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: BackwardsAuroraLevel = try Self.generated(number).level
        let witness: BackwardsAuroraWitness = try Self.witness(number)
        let solution: BackwardsAuroraSolution? = BackwardsAuroraSolver.solve(level)
        var altered: [(String, BackwardsAuroraWitness)] = []

        // A witness reversal: the last reversal replaced by its first variation that no longer wins.
        let reversals: [BackwardsAuroraAction]? = Self.losingWitnessReversals(level, witness.actions)
        #expect(reversals != nil, "level \(number): every variation of the last reversal still wins")
        if let reversals { altered.append(("witness reversal", Self.rebuilt(witness, actions: reversals))) }

        // A per-reversal digest: the middle reversal's digest with its first character changed.
        var digests: [String] = witness.digests
        let reversal: Int = digests.count / 2
        digests[reversal] = Self.flipped(digests[reversal])
        altered.append(("per-reversal digest", Self.rebuilt(witness, digests: digests)))

        // A per-reversal fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        altered.append(("per-reversal fingerprint", Self.rebuilt(witness, fingerprints: fingerprints)))

        // The smallest reversal count: one more.
        altered.append(("smallest reversal count", Self.rebuilt(witness, smallest: witness.smallest + 1)))

        #expect(altered.count == 4)
        for (part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, solution: solution), number: number,
                             part: part)
        }
    }
}
