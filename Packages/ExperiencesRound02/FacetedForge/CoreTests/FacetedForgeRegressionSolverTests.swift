// FacetedForgeRegressionSolverTests — feature 378 (R02-G08-08) T-R02G0808-002 (FR-R02G0808-001, 002; SC-R02G0808-001,
// 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized tests of 10
// levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/faceted-forge/levels (part by part and by fingerprint); the witness's cuts replay on a fresh play (begun,
// the tutorial dismissed) to a win in exactly its smallest cut count (equal to the lower bound), within the budget,
// with exactly its per-cut digests (`FacetedForgeWitness.digest` of the pieces after each cut) and play fingerprints
// (after the start and after each cut); `FacetedForgeSolver.solve` returns exactly the witness's cuts with `smallest`
// equal to the witness's and to `lowerBound(level)`, and its work is at most `FacetedForgeSolver.workBound` (counted,
// never timed). Then the ten alterations of clarification Q2, each applied to a copy of level 1 (band 1, a tutorial
// level) and of level 41 (band 3): the pure `firstFailure(level:witness:solution:)` must name exactly the altered part
// ("crystal half-space", "budget", "sliver limit", "target share", "target face count", "solution cut", "witness cut",
// "per-cut digest", "per-cut fingerprint", "smallest cut count") in a message naming the level ("level 41: budget
// differs …"), and the unaltered input must give nil. Every alteration is fixed (no random source), the level ones are
// built through the level initialiser, and the stored witnesses are read with the plain decoder, so no test re-solves
// a level more than once. Explicit types, plain loops, short runs.
@testable import FacetedForgeCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/faceted-forge/levels", isDirectory: true)

/// A failure of the regression: the part that differs first and the message naming the level and that part.
struct FacetedForgeRegressionFailure: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level or witness.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

@Suite struct FacetedForgeRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level) and level 41 (band 3, a corner-cut cube).
    static let alteredNumbers: [Int] = [1, 41]

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> FacetedForgeWitness {
        let name: String = String(FacetedForgeGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(FacetedForgeWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (generated once per process by the experience core).
    static func generated(_ number: Int) throws -> FacetedForgeGenerated {
        try FacetedForgeExperienceCore.generated(number: number)
    }

    /// A failure of `part` for `name` with the detail `detail`.
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> FacetedForgeRegressionFailure {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return FacetedForgeRegressionFailure(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The independent replay of `actions` on a fresh play of `level` (begun, the tutorial dismissed), as the witness
    /// computes it: the play fingerprint after the start and after each cut, the `FacetedForgeWitness.digest` of the
    /// pieces after each cut, and whether any cut but the first was applied to a play no longer playing; nil when a
    /// stage event or a cut is refused.
    static func replayed(_ level: FacetedForgeLevel, _ actions: [FacetedForgeAction])
        -> (play: FacetedForgePlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play: FacetedForgePlay = FacetedForgePlay(level: level)
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
                digests.append(FacetedForgeWitness.digest(play.pieces))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The first disagreement of `level` with its stored witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: FacetedForgeLevel, stored: FacetedForgeLevel,
                             name: String) -> FacetedForgeRegressionFailure? {
        if level.id != stored.id { return failure(name, "id") }
        if level.seed != stored.seed { return failure(name, "seed") }
        if level.difficulty != stored.difficulty { return failure(name, "difficulty") }
        if level.planes.count != stored.planes.count { return failure(name, "crystal half-space", "count") }
        for index in 0..<level.planes.count where level.planes[index] != stored.planes[index] {
            return failure(name, "crystal half-space", "half-space \(index + 1)")
        }
        if level.budget != stored.budget {
            return failure(name, "budget", "\(level.budget), witness \(stored.budget)")
        }
        if level.sliver != stored.sliver {
            return failure(name, "sliver limit", "\(level.sliver.text), witness \(stored.sliver.text)")
        }
        if level.target.count != stored.target.count { return failure(name, "target piece count") }
        for index in 0..<level.target.count where level.target[index].share != stored.target[index].share {
            return failure(name, "target share", "piece \(index + 1)")
        }
        for index in 0..<level.target.count where level.target[index].faces != stored.target[index].faces {
            return failure(name, "target face count", "piece \(index + 1)")
        }
        if level.tutorial != stored.tutorial { return failure(name, "tutorial") }
        if level.fingerprint != stored.fingerprint { return failure(name, "level fingerprint") }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `solution` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's cuts replay on a fresh play
    /// to a win on the last cut in exactly its smallest cut count (the lower bound) within the budget with exactly its
    /// per-cut digests and play fingerprints, and the solution's cuts and smallest equal the witness's with work at
    /// most `FacetedForgeSolver.workBound`. A replay the play refuses is a named failure, never a crash. Pure.
    static func firstFailure(level: FacetedForgeLevel, witness: FacetedForgeWitness,
                             solution: FacetedForgeSolution?) -> FacetedForgeRegressionFailure? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let found = levelFailure(level, stored: witness.level, name: name) { return found }

        // The witness's cuts replayed on a fresh play: a win on the last cut and not before.
        guard let run = replayed(level, witness.actions) else {
            return failure(name, "witness cut", "replay refused")
        }
        if run.endedEarly { return failure(name, "witness cut", "the play ends before the last cut") }
        if run.play.stage != .won {
            return failure(name, "witness cut", "replay does not win (stage \(run.play.stage.rawValue))")
        }

        // The smallest cut count: the cuts, the replay, the lower bound and the budget.
        let lowerBound: Int = FacetedForgeSolver.lowerBound(level)
        if witness.smallest != witness.actions.count {
            return failure(name, "smallest cut count", "\(witness.smallest), \(witness.actions.count) cuts")
        }
        if witness.smallest != run.play.cuts {
            return failure(name, "smallest cut count", "\(witness.smallest), replay \(run.play.cuts) cuts")
        }
        if witness.smallest != lowerBound {
            return failure(name, "smallest cut count", "\(witness.smallest), lower bound \(lowerBound)")
        }
        if witness.smallest > level.budget {
            return failure(name, "smallest cut count", "\(witness.smallest) exceeds the budget \(level.budget)")
        }
        if witness.lowerBound != lowerBound { return failure(name, "lower bound", "\(witness.lowerBound)") }

        // The per-cut digests and play fingerprints.
        if run.digests.count != witness.digests.count {
            return failure(name, "per-cut digest", "count \(witness.digests.count), replay \(run.digests.count)")
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.digests[index] {
            return failure(name, "per-cut digest", "cut \(index + 1)")
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return failure(name, "per-cut fingerprint",
                           "count \(witness.fingerprints.count), replay \(run.fingerprints.count)")
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return failure(name, "per-cut fingerprint", "after cut \(index)")
        }

        // The solver: exactly the witness's cuts and smallest; work within the bound.
        guard let solution else { return failure(name, "solution cut", "the solver finds no solution") }
        if solution.actions.count != witness.actions.count {
            return failure(name, "solution cut", "count \(solution.actions.count), witness \(witness.actions.count)")
        }
        for index in 0..<solution.actions.count where solution.actions[index] != witness.actions[index] {
            return failure(name, "solution cut", "cut \(index + 1)")
        }
        if solution.smallest != witness.smallest || solution.smallest != lowerBound {
            return failure(name, "smallest cut count", "solver \(solution.smallest), witness \(witness.smallest)")
        }
        if solution.work > FacetedForgeSolver.workBound {
            return failure(name, "solver work", "\(solution.work) exceeds \(FacetedForgeSolver.workBound)")
        }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: FacetedForgeGenerated = try generated(number)
        let witness: FacetedForgeWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let solution: FacetedForgeSolution? = FacetedForgeSolver.solve(generated.level)
        let found: FacetedForgeRegressionFailure? = firstFailure(level: generated.level, witness: witness,
                                                                 solution: solution)
        #expect(found == nil, Comment(rawValue: found?.message ?? ""))
        #expect(solution == generated.solution, "level \(number): solver result differs from the generator's")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G0808-001; SC-R02G0808-001; Q1)

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

    // MARK: Alterations (FR-R02G0808-002; SC-R02G0808-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: FacetedForgeLevel, planes: [FacetedForgeHalfSpace]? = nil, budget: Int? = nil,
                        sliver: FacetedForgeFraction? = nil,
                        target: [FacetedForgeTargetPiece]? = nil) throws -> FacetedForgeLevel {
        try FacetedForgeLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                              planes: planes ?? level.planes, budget: budget ?? level.budget,
                              sliver: sliver ?? level.sliver, target: target ?? level.target,
                              tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: FacetedForgeWitness, actions: [FacetedForgeAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        smallest: Int? = nil) -> FacetedForgeWitness {
        FacetedForgeWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                            digests: digests ?? witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                            smallest: smallest ?? witness.smallest, lowerBound: witness.lowerBound,
                            nearMiss: witness.nearMiss, difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// `action` with its depth one deeper (the piece and the direction kept).
    static func deeper(_ action: FacetedForgeAction) -> FacetedForgeAction {
        switch action {
        case let .cut(piece, direction, depth): return .cut(piece, direction, depth + 1)
        }
    }

    /// The first crystal half-space alteration the level initialiser accepts: half-space after half-space in order,
    /// its depth moved one step inward (then one outward); nil when every such copy is refused.
    static func halfSpaceAltered(_ level: FacetedForgeLevel) -> FacetedForgeLevel? {
        for index in 0..<level.planes.count {
            let plane: FacetedForgeHalfSpace = level.planes[index]
            for step in [-1, 1] {
                var planes: [FacetedForgeHalfSpace] = level.planes
                planes[index] = FacetedForgeHalfSpace(direction: plane.direction, sign: plane.sign,
                                                      depth: plane.depth + step * plane.sign)
                if let copy = try? rebuilt(level, planes: planes) { return copy }
            }
        }
        return nil
    }

    /// The target with 1/128 of the crystal moved from the smallest entry to the largest (the order and the sum kept;
    /// every generated share is at least 1/32, so the smallest stays above the 1/64 sliver limit).
    static func shareAltered(_ target: [FacetedForgeTargetPiece]) throws -> [FacetedForgeTargetPiece] {
        let delta: FacetedForgeFraction = try FacetedForgeFraction(1, 128)
        var result: [FacetedForgeTargetPiece] = target
        let last: Int = result.count - 1
        result[0] = FacetedForgeTargetPiece(share: try target[0].share.adding(delta), faces: target[0].faces)
        result[last] = FacetedForgeTargetPiece(share: try target[last].share.subtracting(delta),
                                               faces: target[last].faces)
        return result
    }

    /// Records an issue unless `found` names exactly `part` in a message naming level `number` and the part.
    static func expectNamed(_ found: FacetedForgeRegressionFailure?, number: Int, part: String) {
        let message: String = found?.message ?? "(none)"
        #expect(found?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
    }

    /// The unaltered level, witness and solution are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: FacetedForgeLevel = try Self.generated(number).level
        let found: FacetedForgeRegressionFailure? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                                                      solution: FacetedForgeSolver.solve(level))
        #expect(found == nil, "level \(number): \(found?.message ?? "")")
    }

    /// Level alterations: a crystal half-space, the budget, the sliver limit, a target piece's share and a target
    /// piece's face count, each rebuilt through the level initialiser (which accepts every one) and named exactly. The
    /// level is compared first, so the unaltered solution is passed and no altered level is solved.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: FacetedForgeGenerated = try Self.generated(number)
        let level: FacetedForgeLevel = generated.level
        let witness: FacetedForgeWitness = try Self.witness(number)
        var altered: [(String, FacetedForgeLevel)] = []

        // A crystal half-space: one depth moved by one.
        let halfSpace: FacetedForgeLevel? = Self.halfSpaceAltered(level)
        #expect(halfSpace != nil, "level \(number): every half-space alteration refused")
        if let halfSpace { altered.append(("crystal half-space", halfSpace)) }

        // The budget: one more (one less at the largest budget).
        let budget: Int = level.budget == FacetedForgeLevel.budgets.upperBound ? level.budget - 1 : level.budget + 1
        altered.append(("budget", try Self.rebuilt(level, budget: budget)))

        // The sliver limit: halved (1/64 → 1/128).
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        altered.append(("sliver limit", try Self.rebuilt(level, sliver: try level.sliver.multiplying(half))))

        // A target piece's share: 1/128 moved from the smallest entry to the largest.
        altered.append(("target share", try Self.rebuilt(level, target: try Self.shareAltered(level.target))))

        // A target piece's face count: the first entry one face more (it stays first among equal shares).
        var faces: [FacetedForgeTargetPiece] = level.target
        faces[0] = FacetedForgeTargetPiece(share: faces[0].share, faces: faces[0].faces + 1)
        altered.append(("target face count", try Self.rebuilt(level, target: faces)))

        #expect(altered.count == 5)
        for (part, copy) in altered {
            #expect(copy.fingerprint != level.fingerprint, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: copy, witness: witness, solution: generated.solution),
                             number: number, part: part)
        }
    }

    /// The solution alteration: the solver's first cut one step deeper.
    @Test(arguments: alteredNumbers) func solutionAlterationIsNamed(number: Int) throws {
        let level: FacetedForgeLevel = try Self.generated(number).level
        let witness: FacetedForgeWitness = try Self.witness(number)
        let solution: FacetedForgeSolution? = FacetedForgeSolver.solve(level)
        #expect(solution != nil, "level \(number): no solution")
        guard let solution else { return }
        var actions: [FacetedForgeAction] = solution.actions
        actions[0] = Self.deeper(actions[0])
        let copy: FacetedForgeSolution = FacetedForgeSolution(smallest: solution.smallest, actions: actions,
                                                              work: solution.work)
        #expect(copy != solution, "level \(number): solution unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, solution: copy), number: number,
                         part: "solution cut")
    }

    /// Witness alterations: a cut, a per-cut digest, a per-cut fingerprint and the smallest cut count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: FacetedForgeLevel = try Self.generated(number).level
        let witness: FacetedForgeWitness = try Self.witness(number)
        let solution: FacetedForgeSolution? = FacetedForgeSolver.solve(level)
        var altered: [(String, FacetedForgeWitness)] = []

        // A witness cut: the last cut one step deeper, so the replay no longer completes the target.
        var actions: [FacetedForgeAction] = witness.actions
        actions[actions.count - 1] = Self.deeper(actions[actions.count - 1])
        altered.append(("witness cut", Self.rebuilt(witness, actions: actions)))

        // A per-cut digest: the middle cut's digest with its first character changed.
        var digests: [String] = witness.digests
        let cut: Int = digests.count / 2
        digests[cut] = Self.flipped(digests[cut])
        altered.append(("per-cut digest", Self.rebuilt(witness, digests: digests)))

        // A per-cut fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        altered.append(("per-cut fingerprint", Self.rebuilt(witness, fingerprints: fingerprints)))

        // The smallest cut count: one more.
        altered.append(("smallest cut count", Self.rebuilt(witness, smallest: witness.smallest + 1)))

        #expect(altered.count == 4)
        for (part, copy) in altered {
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, solution: solution), number: number,
                             part: part)
        }
    }
}
