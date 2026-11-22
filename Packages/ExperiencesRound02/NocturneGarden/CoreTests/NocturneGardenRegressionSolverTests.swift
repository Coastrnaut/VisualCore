// NocturneGardenRegressionSolverTests — feature 388 (R02-G09-08) T-R02G0908-002 (FR-R02G0908-001, 002;
// SC-R02G0908-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/nocturne-garden/levels (part by part and by fingerprint); the witness's moves replay on a fresh play
// (begun, the tutorial dismissed) to a win on the last move in exactly its smallest move count (equal to the lower
// bound's), within the budget, with exactly its per-move digests (`NocturneGardenWitness.digest` of the shadow mask
// after each move) and play fingerprints (after the start and after each move); `NocturneGardenSolver.solve` returns
// exactly the witness's moves with `smallest` equal to the witness's and to `lowerBound(level)?.smallest`, and its work
// is at most `NocturneGardenSolver.workBound` (counted, never timed). The 100 levels are generated concurrently once
// per process (the pattern of NocturneGardenHintsTests) so each test stays short. Then the ten alterations of
// clarification Q2, each applied to a copy of level 1 (band 1, a tutorial level) and of level 41 (band 3, a sun move
// first): the pure `firstFailure(level:witness:solution:)` must name exactly the altered part ("target cell",
// "forbidden cell", "budget", "leak allowance", "required match", "solution move", "witness move", "per-move digest",
// "per-move fingerprint", "smallest move count") in a message naming the level ("level 41: budget differs …"), and the
// unaltered input must give nil. Every alteration is fixed (no random source), the level ones are built through the
// level initialiser, and the stored witnesses are read with the plain decoder. Explicit types, plain loops, short runs.
@testable import NocturneGardenCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/nocturne-garden/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache, as NocturneGardenHintsTests prewarms them).
private let regressionSolverCatalogResult: Result<[NocturneGardenGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? NocturneGardenExperienceCore.generated(number: index + 1)
    }
    var catalog: [NocturneGardenGenerated] = []
    for number in 1...100 { catalog.append(try NocturneGardenExperienceCore.generated(number: number)) }
    return catalog
}

/// A failure of the regression: the part that differs first and the message naming the level and that part.
struct NocturneGardenRegressionFailure: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level or witness.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

@Suite struct NocturneGardenRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level) and level 41 (band 3, a sun move first).
    static let alteredNumbers: [Int] = [1, 41]

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> NocturneGardenWitness {
        let name: String = String(NocturneGardenGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(NocturneGardenWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> NocturneGardenGenerated {
        let catalog: [NocturneGardenGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A failure of `part` for `name` with the detail `detail`.
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> NocturneGardenRegressionFailure {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return NocturneGardenRegressionFailure(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The smallest cell in exactly one of `lhs` and `rhs`, or nil when they are equal.
    static func firstDifference(_ lhs: Set<Int>, _ rhs: Set<Int>) -> Int? {
        let different: Set<Int> = lhs.symmetricDifference(rhs)
        return different.min()
    }

    /// The independent replay of `actions` on a fresh play of `level` (begun, the tutorial dismissed), as the witness
    /// computes it: the play fingerprint after the start and after each move, the `NocturneGardenWitness.digest` of
    /// the shadow mask after each move, and whether any move but the first was applied to a play no longer playing;
    /// nil when a stage event or a move is refused.
    static func replayed(_ level: NocturneGardenLevel, _ actions: [NocturneGardenAction])
        -> (play: NocturneGardenPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play: NocturneGardenPlay = NocturneGardenPlay(level: level)
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
                digests.append(NocturneGardenWitness.digest(play.mask))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The first disagreement of `level` with its stored witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: NocturneGardenLevel, stored: NocturneGardenLevel,
                             name: String) -> NocturneGardenRegressionFailure? {
        if level.id != stored.id { return failure(name, "id") }
        if level.seed != stored.seed { return failure(name, "seed") }
        if level.difficulty != stored.difficulty { return failure(name, "difficulty") }
        if level.width != stored.width || level.height != stored.height { return failure(name, "bed size") }
        if let cell = firstDifference(level.target, stored.target) {
            return failure(name, "target cell", "cell \(cell)")
        }
        if let cell = firstDifference(level.forbidden, stored.forbidden) {
            return failure(name, "forbidden cell", "cell \(cell)")
        }
        if level.supply != stored.supply { return failure(name, "supply") }
        if level.sizes != stored.sizes { return failure(name, "sizes") }
        if level.elevations != stored.elevations { return failure(name, "elevations") }
        if level.sun != stored.sun { return failure(name, "sun") }
        if level.budget != stored.budget {
            return failure(name, "budget", "\(level.budget), witness \(stored.budget)")
        }
        if level.leakAllowance != stored.leakAllowance {
            return failure(name, "leak allowance", "\(level.leakAllowance), witness \(stored.leakAllowance)")
        }
        if level.required != stored.required {
            return failure(name, "required match", "\(level.required.text), witness \(stored.required.text)")
        }
        if level.tutorial != stored.tutorial { return failure(name, "tutorial") }
        if level.fingerprint != stored.fingerprint { return failure(name, "level fingerprint") }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's moves replay on a fresh play
    /// to a win on the last move in exactly its smallest move count (the lower bound's) within the budget with exactly
    /// its per-move digests and play fingerprints, and the solution's moves and smallest equal the witness's with work
    /// at most `NocturneGardenSolver.workBound`. A replay the play refuses is a named failure, never a crash. Pure.
    static func firstFailure(level: NocturneGardenLevel, witness: NocturneGardenWitness,
                             solution: NocturneGardenSolution?) -> NocturneGardenRegressionFailure? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let found = levelFailure(level, stored: witness.level, name: name) { return found }

        // The witness's moves replayed on a fresh play: a win on the last move and not before.
        guard let run = replayed(level, witness.actions) else {
            return failure(name, "witness move", "replay refused")
        }
        if run.endedEarly { return failure(name, "witness move", "the play ends before the last move") }
        if run.play.stage != .won {
            return failure(name, "witness move", "replay does not win (stage \(run.play.stage.rawValue))")
        }

        // The smallest move count: the moves, the replay, the lower bound and the budget.
        guard let bound = NocturneGardenSolver.lowerBound(level) else {
            return failure(name, "lower bound", "the level has no lower bound")
        }
        if witness.smallest != witness.actions.count {
            return failure(name, "smallest move count", "\(witness.smallest), \(witness.actions.count) moves")
        }
        if witness.smallest != run.play.moves {
            return failure(name, "smallest move count", "\(witness.smallest), replay \(run.play.moves) moves")
        }
        if witness.smallest != bound.smallest {
            return failure(name, "smallest move count", "\(witness.smallest), lower bound \(bound.smallest)")
        }
        if witness.smallest > level.budget {
            return failure(name, "smallest move count", "\(witness.smallest) exceeds the budget \(level.budget)")
        }
        if witness.bound != bound { return failure(name, "lower bound", "\(witness.bound.smallest)") }

        // The per-move digests and play fingerprints.
        if run.digests.count != witness.digests.count {
            return failure(name, "per-move digest", "count \(witness.digests.count), replay \(run.digests.count)")
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.digests[index] {
            return failure(name, "per-move digest", "move \(index + 1)")
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return failure(name, "per-move fingerprint",
                           "count \(witness.fingerprints.count), replay \(run.fingerprints.count)")
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return failure(name, "per-move fingerprint", "after move \(index)")
        }

        // The solver: exactly the witness's moves and smallest; work within the bound.
        guard let solution else { return failure(name, "solution move", "the solver finds no solution") }
        if solution.actions.count != witness.actions.count {
            return failure(name, "solution move",
                           "count \(solution.actions.count), witness \(witness.actions.count)")
        }
        for index in 0..<solution.actions.count where solution.actions[index] != witness.actions[index] {
            return failure(name, "solution move", "move \(index + 1)")
        }
        if solution.smallest != witness.smallest || solution.smallest != bound.smallest {
            return failure(name, "smallest move count", "solver \(solution.smallest), witness \(witness.smallest)")
        }
        if solution.work > NocturneGardenSolver.workBound {
            return failure(name, "solver work", "\(solution.work) exceeds \(NocturneGardenSolver.workBound)")
        }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: NocturneGardenGenerated = try generated(number)
        let witness: NocturneGardenWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let solution: NocturneGardenSolution? = NocturneGardenSolver.solve(generated.level)
        let found: NocturneGardenRegressionFailure? = firstFailure(level: generated.level, witness: witness,
                                                                   solution: solution)
        #expect(found == nil, Comment(rawValue: found?.message ?? ""))
        #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
        #expect(generated.bound == witness.bound, "level \(number): bound differs")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G0908-001; SC-R02G0908-001; Q1)

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

    // MARK: Alterations (FR-R02G0908-002; SC-R02G0908-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: NocturneGardenLevel, target: Set<Int>? = nil, forbidden: Set<Int>? = nil,
                        budget: Int? = nil, required: NocturneGardenRatio? = nil,
                        leakAllowance: Int? = nil) throws -> NocturneGardenLevel {
        try NocturneGardenLevel(id: level.id, seed: level.seed, difficulty: level.difficulty, width: level.width,
                                height: level.height, target: target ?? level.target,
                                forbidden: forbidden ?? level.forbidden, supply: level.supply, sizes: level.sizes,
                                elevations: level.elevations, sun: level.sun, budget: budget ?? level.budget,
                                required: required ?? level.required,
                                leakAllowance: leakAllowance ?? level.leakAllowance, tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: NocturneGardenWitness, actions: [NocturneGardenAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        smallest: Int? = nil) -> NocturneGardenWitness {
        NocturneGardenWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
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

    /// The fixed variations of `action`, in order: a plant one column right, left, one row down, up, then one size
    /// larger (wrapping 3 → 1); a sun move to the next elevation (wrapping 4 → 1); any other move unchanged. Some
    /// variations may be out of range; the play then refuses them.
    static func variations(_ action: NocturneGardenAction) -> [NocturneGardenAction] {
        switch action {
        case let .plant(kind, column, row, size):
            let larger: Int = size % 3 + 1
            return [.plant(kind, column + 1, row, size), .plant(kind, column - 1, row, size),
                    .plant(kind, column, row + 1, size), .plant(kind, column, row - 1, size),
                    .plant(kind, column, row, larger)]
        case let .sun(elevation):
            return [.sun(elevation % 4 + 1)]
        default:
            return []
        }
    }

    /// The witness's moves with the last one replaced by its first variation that no longer wins on a fresh play
    /// (refused or not won); nil when every variation still wins.
    static func losingWitnessMoves(_ level: NocturneGardenLevel,
                                   _ actions: [NocturneGardenAction]) -> [NocturneGardenAction]? {
        let last: Int = actions.count - 1
        for variation in variations(actions[last]) {
            var altered: [NocturneGardenAction] = actions
            altered[last] = variation
            if !NocturneGardenSolver.wins(level, actions: altered) { return altered }
        }
        return nil
    }

    /// The required match moved to a different ratio: p/q → (10p + 1)/(10q) when p < q, 1/1 → 9/10.
    static func requiredAltered(_ required: NocturneGardenRatio) throws -> NocturneGardenRatio {
        let p: Int = required.numerator
        let q: Int = required.denominator
        if p < q { return try NocturneGardenRatio(10 * p + 1, 10 * q) }
        return try NocturneGardenRatio(9, 10)
    }

    /// The forbidden cells altered: the smallest one removed, or, when there is none, the smallest bed cell outside
    /// the target added.
    static func forbiddenAltered(_ level: NocturneGardenLevel) -> Set<Int> {
        var forbidden: Set<Int> = level.forbidden
        if let smallest = forbidden.min() {
            forbidden.remove(smallest)
            return forbidden
        }
        for cell in 0..<level.cellCount where !level.target.contains(cell) {
            forbidden.insert(cell)
            return forbidden
        }
        return forbidden
    }

    /// Records an issue unless `found` names exactly `part` in a message naming level `number` and the part.
    static func expectNamed(_ found: NocturneGardenRegressionFailure?, number: Int, part: String) {
        let message: String = found?.message ?? "(none)"
        #expect(found?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
    }

    /// The unaltered level, witness and solution are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: NocturneGardenLevel = try Self.generated(number).level
        let found: NocturneGardenRegressionFailure? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                                                        solution: NocturneGardenSolver.solve(level))
        #expect(found == nil, "level \(number): \(found?.message ?? "")")
    }

    /// Level alterations: a target cell, a forbidden cell, the budget, the leak allowance and the required match, each
    /// rebuilt through the level initialiser (which accepts every one) and named exactly. The level is compared first,
    /// so the unaltered solution is passed and no altered level is solved.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: NocturneGardenGenerated = try Self.generated(number)
        let level: NocturneGardenLevel = generated.level
        let witness: NocturneGardenWitness = try Self.witness(number)
        var altered: [(String, NocturneGardenLevel)] = []

        // A target cell: the smallest target cell removed (the target keeps its other cells).
        var target: Set<Int> = level.target
        let firstTarget: Int = target.min() ?? 0
        target.remove(firstTarget)
        #expect(!target.isEmpty, "level \(number): a one-cell target")
        altered.append(("target cell", try Self.rebuilt(level, target: target)))

        // A forbidden cell: the smallest one removed (or one added when there is none).
        altered.append(("forbidden cell", try Self.rebuilt(level, forbidden: Self.forbiddenAltered(level))))

        // The budget: one more (one less at the largest budget).
        let budget: Int = level.budget == NocturneGardenLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        altered.append(("budget", try Self.rebuilt(level, budget: budget)))

        // The leak allowance: one more.
        altered.append(("leak allowance", try Self.rebuilt(level, leakAllowance: level.leakAllowance + 1)))

        // The required match: a slightly different ratio.
        let required: NocturneGardenRatio = try Self.requiredAltered(level.required)
        #expect(required != level.required, "level \(number): required match unchanged")
        altered.append(("required match", try Self.rebuilt(level, required: required)))

        #expect(altered.count == 5)
        for (part, copy) in altered {
            #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: copy, witness: witness, solution: generated.solution),
                             number: number, part: part)
        }
    }

    /// The solution alteration: the solver's first move replaced by its first variation.
    @Test(arguments: alteredNumbers) func solutionAlterationIsNamed(number: Int) throws {
        let level: NocturneGardenLevel = try Self.generated(number).level
        let witness: NocturneGardenWitness = try Self.witness(number)
        let solution: NocturneGardenSolution? = NocturneGardenSolver.solve(level)
        #expect(solution != nil, "level \(number): no solution")
        guard let solution else { return }
        let variations: [NocturneGardenAction] = Self.variations(solution.actions[0])
        #expect(!variations.isEmpty, "level \(number): the first move has no variation")
        guard let variation = variations.first else { return }
        var actions: [NocturneGardenAction] = solution.actions
        actions[0] = variation
        let copy: NocturneGardenSolution = NocturneGardenSolution(smallest: solution.smallest, actions: actions,
                                                                  work: solution.work)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, solution: copy), number: number,
                         part: "solution move")
    }

    /// Witness alterations: a move, a per-move digest, a per-move fingerprint and the smallest move count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: NocturneGardenLevel = try Self.generated(number).level
        let witness: NocturneGardenWitness = try Self.witness(number)
        let solution: NocturneGardenSolution? = NocturneGardenSolver.solve(level)
        var altered: [(String, NocturneGardenWitness)] = []

        // A witness move: the last move replaced by its first variation that no longer wins.
        let moves: [NocturneGardenAction]? = Self.losingWitnessMoves(level, witness.actions)
        #expect(moves != nil, "level \(number): every variation of the last move still wins")
        if let moves { altered.append(("witness move", Self.rebuilt(witness, actions: moves))) }

        // A per-move digest: the middle move's digest with its first character changed.
        var digests: [String] = witness.digests
        let move: Int = digests.count / 2
        digests[move] = Self.flipped(digests[move])
        altered.append(("per-move digest", Self.rebuilt(witness, digests: digests)))

        // A per-move fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        altered.append(("per-move fingerprint", Self.rebuilt(witness, fingerprints: fingerprints)))

        // The smallest move count: one more.
        altered.append(("smallest move count", Self.rebuilt(witness, smallest: witness.smallest + 1)))

        #expect(altered.count == 4)
        for (part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, solution: solution), number: number,
                             part: part)
        }
    }
}
