// VoxelOrigamiRegressionSolverTests — feature 448 (R02-G15-08) T-R02G1508-002 (FR-R02G1508-001, 002;
// SC-R02G1508-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in twenty
// parameterized tests of 5 levels each (clarification Q1: a six-turn band-5 search costs over a second in a debug
// build, so ten such levels would pass the 10 s rule): the generated level equals the level of its witness file in
// docs/games/voxel-origami/levels (part by part and by fingerprint); the witness's turns replay on a fresh play (begun,
// the tutorial dismissed) to a win on exactly the last turn and not before, within the budget, with exactly its
// per-action fingerprints (after `begin`, after `dismissTutorial` on a tutorial level, then one per turn) and state
// digests (`VoxelOrigamiWitness.digest(turns:)` after each turn); `VoxelOrigamiSolver.plan` returns exactly the
// witness's turns with `statesByDepth[size − 1]` equal to the counterexample's `states` at depth size − 1, and its work
// is at most `VoxelOrigamiSolver.workBound` (counted, never timed) and equal to the witness difficulty's.
// Levels come from the experience core's per-process cache; witness files are read with the plain decoder (the level
// re-checked by its own rules; the solver is not re-run by the decode, which the regression below does itself).
//
// The alterations (clarification Q2): eleven kinds, each applied to a copy of level 1 (band 1, tutorial), 41 (band 3)
// or 81 (band 5) and each detected by the pure checker `RegressionCheck.failures`, which returns every failure as a
// string naming the level and the part ("level 41: cube direction differs (cube 5: …)"): a cube's parent, a cube's
// direction, a cube's start turn, a target cell, the allowed orientations, the budget (each rebuilt through the level
// initialiser, the first copy the level rules accept and whose fingerprint changes; a refused construction is itself a
// failure naming the part); a plan turn; a witness action (one the play does not win with), a per-action fingerprint, a
// per-action digest; the counterexample's state count. The honest input gives no failure. The altered cube and target
// cell are chosen by seed 2_448 (no random source). Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import VoxelOrigamiCore

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum RegressionCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, VoxelOrigami, the package,
    /// Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/voxel-origami/levels", isDirectory: true)

    /// The seed that fixes which cube and target cell an alteration touches first.
    static let alterationSeed: UInt64 = 2_448

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> VoxelOrigamiWitness {
        let name: String = String(VoxelOrigamiGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(VoxelOrigamiWitness.self, from: data)
    }

    /// The failure string of `part` for `name`: "level N: <part> differs (detail)".
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> String {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return "\(name): \(part) differs\(suffix)"
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (cubes first, then the
    /// target, the orientations, the budget and the fingerprint).
    static func levelFailures(_ level: VoxelOrigamiLevel, stored: VoxelOrigamiLevel, name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        if level.cubes.count != stored.cubes.count {
            found.append(failure(name, "cube count", "\(level.cubes.count), witness \(stored.cubes.count)"))
        } else {
            for index in 0..<level.cubes.count {
                let lhs: VoxelOrigamiCube = level.cubes[index]
                let rhs: VoxelOrigamiCube = stored.cubes[index]
                if lhs.parent != rhs.parent {
                    found.append(failure(name, "cube parent", "cube \(index): \(String(describing: lhs.parent)), "
                                            + "witness \(String(describing: rhs.parent))"))
                }
                if lhs.direction != rhs.direction {
                    found.append(failure(name, "cube direction",
                                         "cube \(index): \(lhs.direction), witness \(rhs.direction)"))
                }
                if lhs.startTurn != rhs.startTurn {
                    found.append(failure(name, "cube start turn",
                                         "cube \(index): \(lhs.startTurn), witness \(rhs.startTurn)"))
                }
            }
        }
        if level.target.count != stored.target.count {
            found.append(failure(name, "target cell", "count \(level.target.count), witness \(stored.target.count)"))
        } else {
            for index in 0..<level.target.count where level.target[index] != stored.target[index] {
                found.append(failure(name, "target cell",
                                     "cell \(index): \(level.target[index]), witness \(stored.target[index])"))
            }
        }
        if level.orientations != stored.orientations {
            found.append(failure(name, "allowed orientations",
                                 "\(level.orientations.rawValue), witness \(stored.orientations.rawValue)"))
        }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The index of the first entry where `lhs` and `rhs` differ (the shorter count when one is a prefix).
    static func firstDifference(_ lhs: [String], _ rhs: [String]) -> Int {
        var index: Int = 0
        while index < min(lhs.count, rhs.count), lhs[index] == rhs[index] { index += 1 }
        return index
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's turns replay on a fresh play
    /// to a win on exactly the last turn and not before within the budget with exactly its per-action fingerprints and
    /// digests, and the plan's turns are the witness's with `statesByDepth[size − 1]` the counterexample's states at
    /// depth size − 1 and work at most `VoxelOrigamiSolver.workBound` and equal to the witness difficulty's. The level
    /// parts come first, then the witness's actions, digests and fingerprints, then the counterexample and the plan,
    /// so an altered part is the first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: VoxelOrigamiLevel, witness: VoxelOrigamiWitness, plan: VoxelOrigamiPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)

        // The witness's turns: at least one, each of a known hinge by ±1, within the budget.
        if witness.actions.isEmpty { found.append(failure(name, "witness action", "no action")) }
        for (index, action) in witness.actions.enumerated() {
            switch action {
            case .turn(let hinge, let step):
                if hinge < 1 || hinge >= level.cubes.count || (step != 1 && step != -1) {
                    found.append(failure(name, "witness action", "action \(index): hinge \(hinge) step \(step)"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the last turn and not before, within the budget.
        if let run = VoxelOrigamiWitness.replay(level, actions: witness.actions) {
            if run.endedEarly {
                found.append(failure(name, "witness action", "the play ends before the last turn"))
            }
            if run.play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            if run.play.actionsSpent != witness.actions.count || run.play.actionsSpent > level.budget {
                found.append(failure(name, "budget", "spent \(run.play.actionsSpent) of \(level.budget)"))
            }
            if run.digests != witness.digests {
                found.append(failure(name, "per-action digest",
                                     "digest \(firstDifference(run.digests, witness.digests) + 1)"))
            }
            if run.fingerprints != witness.fingerprints {
                found.append(failure(name, "per-action fingerprint",
                                     "fingerprint \(firstDifference(run.fingerprints, witness.fingerprints) + 1)"))
            }
        } else {
            found.append(failure(name, "witness action", "replay refused"))
        }

        // The counterexample: one turn below the witness's plan.
        if witness.counterexample.depth != witness.actions.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness turns \(witness.actions.count)"))
        }

        // The solver: exactly the witness's turns, the counterexample's states, work within the bound.
        guard let plan: VoxelOrigamiPlan = plan else {
            found.append(failure(name, "plan turn", "the solver finds no plan"))
            return found
        }
        if plan.turns != witness.actions {
            var first: Int = 0
            while first < min(plan.turns.count, witness.actions.count), plan.turns[first] == witness.actions[first] {
                first += 1
            }
            found.append(failure(name, "plan turn",
                                 "turn \(first + 1) of \(plan.size), witness \(witness.actions.count)"))
        }
        if plan.size < 1 || plan.statesByDepth.count != plan.size {
            found.append(failure(name, "plan states by depth", "\(plan.statesByDepth.count) depths, size \(plan.size)"))
        } else if plan.statesByDepth[plan.size - 1] != witness.counterexample.states {
            found.append(failure(name, "counterexample state count",
                                 "\(witness.counterexample.states), plan \(plan.statesByDepth[plan.size - 1])"))
        }
        if plan.size - 1 != witness.counterexample.depth {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), plan \(plan.size - 1)"))
        }
        if plan.statesSearched != witness.difficulty.statesSearched {
            found.append(failure(name, "states searched",
                                 "plan \(plan.statesSearched), witness \(witness.difficulty.statesSearched)"))
        }
        if plan.work > VoxelOrigamiSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(VoxelOrigamiSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    // MARK: Alteration builders

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: VoxelOrigamiLevel, cubes: [VoxelOrigamiCube]? = nil,
                        target: [VoxelOrigamiVector]? = nil, orientations: VoxelOrigamiOrientations? = nil,
                        budget: Int? = nil) throws -> VoxelOrigamiLevel {
        try VoxelOrigamiLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                              cubes: cubes ?? level.cubes, target: target ?? level.target,
                              orientations: orientations ?? level.orientations, budget: budget ?? level.budget,
                              tutorial: level.tutorial)
    }

    /// The non-root cube indices of `level` in the order alterations try them: from cube 1 + seed mod hinges, around.
    static func cubeOrder(_ level: VoxelOrigamiLevel) -> [Int] {
        let hinges: Int = level.hingeCount
        let start: Int = Int(alterationSeed % UInt64(hinges))
        var order: [Int] = []
        for offset in 0..<hinges { order.append(1 + (start + offset) % hinges) }
        return order
    }

    /// The first of `candidates` (whole cube lists) the level rules accept with a changed fingerprint; when none is,
    /// the first candidate rebuilt (so the refusal is reported).
    static func firstAccepted(_ level: VoxelOrigamiLevel, cubes candidates: [[VoxelOrigamiCube]]) throws
        -> VoxelOrigamiLevel {
        for cubes in candidates {
            if let copy: VoxelOrigamiLevel = try? rebuilt(level, cubes: cubes), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        return try rebuilt(level, cubes: candidates.first ?? level.cubes)
    }

    /// `level`'s cubes with cube `index` replaced by `cube`.
    static func replacing(_ level: VoxelOrigamiLevel, cube index: Int, with cube: VoxelOrigamiCube)
        -> [VoxelOrigamiCube] {
        var cubes: [VoxelOrigamiCube] = level.cubes
        cubes[index] = cube
        return cubes
    }

    /// A cube's parent altered: another lower-index parent, first cube in ``cubeOrder(_:)`` order.
    static func parentAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        var candidates: [[VoxelOrigamiCube]] = []
        for index in cubeOrder(level) {
            let old: VoxelOrigamiCube = level.cubes[index]
            for parent in 0..<index where parent != old.parent {
                let cube: VoxelOrigamiCube = VoxelOrigamiCube(parent: parent, direction: old.direction,
                                                              startTurn: old.startTurn)
                candidates.append(replacing(level, cube: index, with: cube))
            }
        }
        return try firstAccepted(level, cubes: candidates)
    }

    /// A cube's direction altered: another of the six unit directions.
    static func directionAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        var candidates: [[VoxelOrigamiCube]] = []
        for index in cubeOrder(level) {
            let old: VoxelOrigamiCube = level.cubes[index]
            for direction in VoxelOrigamiVector.units where direction != old.direction {
                let cube: VoxelOrigamiCube = VoxelOrigamiCube(parent: old.parent, direction: direction,
                                                              startTurn: old.startTurn)
                candidates.append(replacing(level, cube: index, with: cube))
            }
        }
        return try firstAccepted(level, cubes: candidates)
    }

    /// A cube's start turn altered: one, two or three quarter turns further.
    static func startTurnAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        var candidates: [[VoxelOrigamiCube]] = []
        for index in cubeOrder(level) {
            let old: VoxelOrigamiCube = level.cubes[index]
            for delta in 1...3 {
                let cube: VoxelOrigamiCube = VoxelOrigamiCube(parent: old.parent, direction: old.direction,
                                                              startTurn: (old.startTurn + delta) % 4)
                candidates.append(replacing(level, cube: index, with: cube))
            }
        }
        return try firstAccepted(level, cubes: candidates)
    }

    /// A target cell altered: from cell seed mod count, the first cell moved one unit to a free cell (kept sorted)
    /// that the level rules accept; when none is, the first such copy rebuilt (so the refusal is reported).
    static func targetAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        let count: Int = level.target.count
        let start: Int = Int(alterationSeed % UInt64(count))
        var first: [VoxelOrigamiVector]? = nil
        for offset in 0..<count {
            let index: Int = (start + offset) % count
            for unit in VoxelOrigamiVector.units {
                let moved: VoxelOrigamiVector = level.target[index] + unit
                if level.target.contains(moved) { continue }
                var target: [VoxelOrigamiVector] = level.target
                target[index] = moved
                target.sort()
                if first == nil { first = target }
                if let copy: VoxelOrigamiLevel = try? rebuilt(level, target: target) { return copy }
            }
        }
        return try rebuilt(level, target: first ?? level.target)
    }

    /// The allowed orientations altered: the first other group the level rules accept.
    static func orientationsAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        var first: VoxelOrigamiOrientations? = nil
        for orientations in VoxelOrigamiOrientations.allCases where orientations != level.orientations {
            if first == nil { first = orientations }
            if let copy: VoxelOrigamiLevel = try? rebuilt(level, orientations: orientations) { return copy }
        }
        return try rebuilt(level, orientations: first ?? level.orientations)
    }

    /// The budget altered: one less, or one more at the lower end of the range.
    static func budgetAltered(_ level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel {
        let budget: Int = level.budget > VoxelOrigamiLevel.budgets.lowerBound ? level.budget - 1 : level.budget + 1
        return try rebuilt(level, budget: budget)
    }

    /// The failures of the level alteration of `part`: those of the copy built by `build`, or one failure naming
    /// `part` when the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the
    /// stored one.
    static func levelAlterationFailures(part: String, witness: VoxelOrigamiWitness, plan: VoxelOrigamiPlan?,
                                        build: (VoxelOrigamiLevel) throws -> VoxelOrigamiLevel) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: VoxelOrigamiLevel
        do {
            copy = try build(witness.level)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: VoxelOrigamiWitness, actions: [VoxelOrigamiAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: VoxelOrigamiCounterexample? = nil) -> VoxelOrigamiWitness {
        VoxelOrigamiWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                            digests: digests ?? witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                            counterexample: counterexample ?? witness.counterexample,
                            difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The witness actions with the last turn changed so the play no longer wins with them: its step reversed, else
    /// another hinge either way; nil when every such change still wins.
    static func actionAltered(_ level: VoxelOrigamiLevel, _ actions: [VoxelOrigamiAction]) -> [VoxelOrigamiAction]? {
        guard let last: VoxelOrigamiAction = actions.last else { return nil }
        var candidates: [VoxelOrigamiAction] = []
        switch last {
        case .turn(let hinge, let step):
            candidates.append(.turn(hinge, -step))
            for other in 1..<level.cubes.count where other != hinge {
                candidates.append(.turn(other, step))
                candidates.append(.turn(other, -step))
            }
        }
        for candidate in candidates {
            var altered: [VoxelOrigamiAction] = actions
            altered[altered.count - 1] = candidate
            if !VoxelOrigamiSolver.matches(level, actions: altered) { return altered }
        }
        return nil
    }

    /// Records an issue unless `found`'s first failure names level `number` and `part`, and every failure names level
    /// `number`.
    static func expectNamed(_ found: [String], number: Int, part: String) {
        let message: String = found.first ?? "(none)"
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): found \"\(message)\"")
        for entry in found {
            #expect(entry.hasPrefix("level \(number): "),
                    "level \(number) alteration \(part): \"\(entry)\" does not name the level")
        }
    }

    /// Checks level `number`: the generated level equals the witness's, the solver's plan matches the witness and the
    /// checker finds no failure.
    static func check(number: Int) throws {
        let generated: VoxelOrigamiGenerated = try VoxelOrigamiExperienceCore.generated(number: number)
        let witness: VoxelOrigamiWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(generated.level)
        let found: [String] = failures(level: generated.level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= VoxelOrigamiSolver.workBound, "level \(number): solver work above bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }
}

@Suite struct VoxelOrigamiRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 5·(group − 1) + 1 … 5·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 5, "group \(group): index \(index)")
        try RegressionCheck.check(number: (group - 1) * 5 + index + 1)
    }

    // MARK: The regression, twenty parameterized tests of 5 levels (FR-R02G1508-001; SC-R02G1508-001; Q1)

    @Test(arguments: Array(0..<5)) func group01(index: Int) throws { try Self.check(group: 1, index: index) }
    @Test(arguments: Array(0..<5)) func group02(index: Int) throws { try Self.check(group: 2, index: index) }
    @Test(arguments: Array(0..<5)) func group03(index: Int) throws { try Self.check(group: 3, index: index) }
    @Test(arguments: Array(0..<5)) func group04(index: Int) throws { try Self.check(group: 4, index: index) }
    @Test(arguments: Array(0..<5)) func group05(index: Int) throws { try Self.check(group: 5, index: index) }
    @Test(arguments: Array(0..<5)) func group06(index: Int) throws { try Self.check(group: 6, index: index) }
    @Test(arguments: Array(0..<5)) func group07(index: Int) throws { try Self.check(group: 7, index: index) }
    @Test(arguments: Array(0..<5)) func group08(index: Int) throws { try Self.check(group: 8, index: index) }
    @Test(arguments: Array(0..<5)) func group09(index: Int) throws { try Self.check(group: 9, index: index) }
    @Test(arguments: Array(0..<5)) func group10(index: Int) throws { try Self.check(group: 10, index: index) }
    @Test(arguments: Array(0..<5)) func group11(index: Int) throws { try Self.check(group: 11, index: index) }
    @Test(arguments: Array(0..<5)) func group12(index: Int) throws { try Self.check(group: 12, index: index) }
    @Test(arguments: Array(0..<5)) func group13(index: Int) throws { try Self.check(group: 13, index: index) }
    @Test(arguments: Array(0..<5)) func group14(index: Int) throws { try Self.check(group: 14, index: index) }
    @Test(arguments: Array(0..<5)) func group15(index: Int) throws { try Self.check(group: 15, index: index) }
    @Test(arguments: Array(0..<5)) func group16(index: Int) throws { try Self.check(group: 16, index: index) }
    @Test(arguments: Array(0..<5)) func group17(index: Int) throws { try Self.check(group: 17, index: index) }
    @Test(arguments: Array(0..<5)) func group18(index: Int) throws { try Self.check(group: 18, index: index) }
    @Test(arguments: Array(0..<5)) func group19(index: Int) throws { try Self.check(group: 19, index: index) }
    @Test(arguments: Array(0..<5)) func group20(index: Int) throws { try Self.check(group: 20, index: index) }

    // MARK: Alterations (FR-R02G1508-002; SC-R02G1508-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: VoxelOrigamiLevel = try VoxelOrigamiExperienceCore.generated(number: number).level
        let witness: VoxelOrigamiWitness = try RegressionCheck.witness(number)
        let found: [String] = RegressionCheck.failures(level: level, witness: witness,
                                                       plan: VoxelOrigamiSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a cube's parent, a cube's direction, a cube's start turn, a target cell, the allowed
    /// orientations and the budget, each rebuilt through the level initialiser and named first. The level is compared
    /// first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: VoxelOrigamiGenerated = try VoxelOrigamiExperienceCore.generated(number: number)
        let witness: VoxelOrigamiWitness = try RegressionCheck.witness(number)
        let parts: [String] = ["cube parent", "cube direction", "cube start turn", "target cell",
                               "allowed orientations", "budget"]
        for part in parts {
            let found: [String] = RegressionCheck.levelAlterationFailures(part: part, witness: witness,
                                                                          plan: generated.plan) {
                (level: VoxelOrigamiLevel) throws -> VoxelOrigamiLevel in
                switch part {
                case "cube parent": return try RegressionCheck.parentAltered(level)
                case "cube direction": return try RegressionCheck.directionAltered(level)
                case "cube start turn": return try RegressionCheck.startTurnAltered(level)
                case "target cell": return try RegressionCheck.targetAltered(level)
                case "allowed orientations": return try RegressionCheck.orientationsAltered(level)
                default: return try RegressionCheck.budgetAltered(level)
                }
            }
            RegressionCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
        }
    }

    /// The plan alteration: the solver's plan with its first turn reversed.
    @Test(arguments: alteredNumbers) func planTurnAlterationIsNamed(number: Int) throws {
        let level: VoxelOrigamiLevel = try VoxelOrigamiExperienceCore.generated(number: number).level
        let witness: VoxelOrigamiWitness = try RegressionCheck.witness(number)
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: VoxelOrigamiPlan = plan else { return }
        var turns: [VoxelOrigamiAction] = plan.turns
        switch turns[0] {
        case .turn(let hinge, let step): turns[0] = .turn(hinge, -step)
        }
        let copy: VoxelOrigamiPlan = VoxelOrigamiPlan(turns: turns, statesByDepth: plan.statesByDepth, work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: witness, plan: copy),
                                    number: number, part: "plan turn")
    }

    /// Witness alterations: an action the play does not win with, a per-action fingerprint, a per-action digest and
    /// the counterexample's state count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: VoxelOrigamiLevel = try VoxelOrigamiExperienceCore.generated(number: number).level
        let witness: VoxelOrigamiWitness = try RegressionCheck.witness(number)
        let plan: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level)
        var parts: [String] = []
        var copies: [VoxelOrigamiWitness] = []

        let actions: [VoxelOrigamiAction]? = RegressionCheck.actionAltered(level, witness.actions)
        #expect(actions != nil, "level \(number): every altered last turn still wins")
        if let actions: [VoxelOrigamiAction] = actions {
            parts.append("witness action")
            copies.append(RegressionCheck.rebuilt(witness, actions: actions))
        }

        var fingerprints: [String] = witness.fingerprints
        let fingerprintIndex: Int = fingerprints.count / 2
        fingerprints[fingerprintIndex] = RegressionCheck.flipped(fingerprints[fingerprintIndex])
        parts.append("per-action fingerprint")
        copies.append(RegressionCheck.rebuilt(witness, fingerprints: fingerprints))

        var digests: [String] = witness.digests
        let digestIndex: Int = digests.count / 2
        digests[digestIndex] = RegressionCheck.flipped(digests[digestIndex])
        parts.append("per-action digest")
        copies.append(RegressionCheck.rebuilt(witness, digests: digests))

        let counterexample: VoxelOrigamiCounterexample =
            VoxelOrigamiCounterexample(depth: witness.counterexample.depth, states: witness.counterexample.states + 1)
        parts.append("counterexample state count")
        copies.append(RegressionCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: VoxelOrigamiWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: copy, plan: plan),
                                        number: number, part: part)
        }
    }
}
