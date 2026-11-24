// MoonlitMechanismRegressionSolverTests — feature 438 (R02-G14-08) T-R02G1408-002 (FR-R02G1408-001, 002;
// SC-R02G1408-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/moonlit-mechanism/levels (part by part and by fingerprint); the witness's actions replay on a fresh play
// (begun, the tutorial dismissed) to a win on the last action and not before, in exactly its action count (the plan's
// turns, then its re-seats in gear order, then its lamp steps, then one run), within the budget, with exactly its
// per-action state digests (`MoonlitMechanismWitness.digest(phases:height:)` after each action) and per-action
// fingerprints (after `begin`, after `dismissTutorial` when the level has a tutorial, and after each action); the
// counterexample's norm is one below the plan's size and its vectors are the count of plan vectors of that norm
// (`MoonlitMechanismWitness.vectors(dimensions:norm:)`, dimension gears + 1), and the vectors of every norm up to it
// sum to the difficulty's `smallerVectors`; `MoonlitMechanismSolver.plan` returns exactly the witness's turns, lamp
// steps and re-seats (derived from its actions) with exactly its `smallerVectors` and size, and its work is at most
// `MoonlitMechanismSolver.workBound` (counted, never timed) and equal to the witness's.
// The 100 levels are generated concurrently once per process (through the experience core's cache) so each test stays
// short. Witness files are read with the plain decoder (the level re-checked by its own decoder; the solver is not
// re-run by the decode, which the regression below does itself).
//
// The alterations (clarification Q2): thirteen kinds, each applied to a copy of level 1, 41 or 81 and each detected by
// the checker `differences`, which returns every named difference, each with a message naming the level and the part
// ("level 41: budget differs …"): a gear's tooth count, a gear's centre, a gear's depth, a gear's starting phase, a
// slot table offset, the lamp's starting height, a key frame's target cell, a forbidden cell, the budget (each rebuilt
// through the level initialiser; a refused construction is itself named as the part); a plan component; a witness
// action, a per-action fingerprint; the smaller-vectors count. The honest input gives an empty list. The altered gear
// is fixed by seed 2_438 (no random source). Explicit types, plain loops, short runs.
@testable import MoonlitMechanismCore
import Foundation
import Testing

/// The repository's witness directory, found from this file (five levels up: CoreTests, MoonlitMechanism, the package,
/// Packages).
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/moonlit-mechanism/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache).
private let regressionSolverCatalogResult: Result<[MoonlitMechanismGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? MoonlitMechanismExperienceCore.generated(number: index + 1)
    }
    var catalog: [MoonlitMechanismGenerated] = []
    for number in 1...100 { catalog.append(try MoonlitMechanismExperienceCore.generated(number: number)) }
    return catalog
}

/// One named difference of the regression: the part that differs and the message naming the level and that part.
struct MoonlitMechanismRegressionDifference: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level, witness or plan.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

/// The independent replay of a witness's actions: the play at the end, the fingerprints, the per-action state digests
/// and whether any action but the first found the play no longer playing.
struct MoonlitMechanismRegressionReplay {
    /// The play after the last action.
    let play: MoonlitMechanismPlay
    /// The fingerprints after `begin`, after `dismissTutorial` (with a tutorial) and after each action.
    let fingerprints: [String]
    /// The state digest of the play's phases and lamp height after every action, in order.
    let digests: [String]
    /// Whether an action was applied to a play no longer playing.
    let endedEarly: Bool
}

/// The plan vector of a witness's actions: net turns, net lamp steps and each gear's net re-seat.
struct MoonlitMechanismRegressionVector: Equatable {
    /// The net handle turns.
    let turns: Int
    /// The net lamp steps.
    let lamp: Int
    /// The net re-seat of every gear (the driver's is 0).
    let reseats: [Int]

    /// The actions before the run: |t| + |h| + Σ|rᵢ|.
    var size: Int {
        var total: Int = abs(turns) + abs(lamp)
        for reseat in reseats { total += abs(reseat) }
        return total
    }
}

@Suite struct MoonlitMechanismRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]
    /// The seed that fixes which gear an alteration touches (no random source).
    static let alterationSeed: UInt64 = 2_438

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> MoonlitMechanismWitness {
        let name: String = String(MoonlitMechanismGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(MoonlitMechanismWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> MoonlitMechanismGenerated {
        let catalog: [MoonlitMechanismGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A difference of `part` for `name` with the detail `detail`.
    static func difference(_ name: String, _ part: String,
                           _ detail: String = "") -> MoonlitMechanismRegressionDifference {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return MoonlitMechanismRegressionDifference(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The plan vector of `actions` for a level of `gears` gears: every turn, lamp step and re-seat summed (a run
    /// adds nothing; a re-seat of an unknown gear is ignored, so the shape check below catches it).
    static func vector(_ actions: [MoonlitMechanismAction], gears: Int) -> MoonlitMechanismRegressionVector {
        var turns: Int = 0
        var lamp: Int = 0
        var reseats: [Int] = Array(repeating: 0, count: max(gears, 1))
        for action in actions {
            switch action {
            case .turn(let step): turns += step
            case .lamp(let step): lamp += step
            case .reseat(let gear, let step):
                if gear >= 0, gear < reseats.count { reseats[gear] += step }
            case .run: break
            }
        }
        return MoonlitMechanismRegressionVector(turns: turns, lamp: lamp, reseats: reseats)
    }

    /// The independent replay of `actions` on a fresh play of `level`, as the witness computes it: the fingerprint
    /// after `begin`, after `dismissTutorial` when the play shows a tutorial, and after each action (each applied with
    /// the current fingerprint), the state digest after each action; nil when a stage event or an action is refused.
    static func replayed(_ level: MoonlitMechanismLevel,
                         _ actions: [MoonlitMechanismAction]) -> MoonlitMechanismRegressionReplay? {
        var play: MoonlitMechanismPlay = MoonlitMechanismPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            fingerprints.append(play.fingerprint)
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(MoonlitMechanismWitness.digest(phases: play.phases, height: play.height))
            }
        } catch {
            return nil
        }
        return MoonlitMechanismRegressionReplay(play: play, fingerprints: fingerprints, digests: digests,
                                                endedEarly: endedEarly)
    }

    /// Every disagreement of gear `index` of `level` with the same gear of the stored level, each naming the level and
    /// the part (the tooth count first, so a changed tooth count is named before the blades and slots it resizes).
    static func gearDifferences(_ lhs: MoonlitMechanismGear, _ rhs: MoonlitMechanismGear, index: Int,
                                name: String) -> [MoonlitMechanismRegressionDifference] {
        var found: [MoonlitMechanismRegressionDifference] = []
        if lhs.teeth != rhs.teeth {
            found.append(difference(name, "gear tooth count", "gear \(index): \(lhs.teeth), witness \(rhs.teeth)"))
        }
        if lhs.centre != rhs.centre {
            found.append(difference(name, "gear centre",
                                    "gear \(index): (\(lhs.centre.column), \(lhs.centre.row)), witness "
                                        + "(\(rhs.centre.column), \(rhs.centre.row))"))
        }
        if lhs.depth != rhs.depth {
            found.append(difference(name, "gear depth", "gear \(index): \(lhs.depth), witness \(rhs.depth)"))
        }
        if lhs.phase != rhs.phase {
            found.append(difference(name, "gear starting phase", "gear \(index): \(lhs.phase), witness \(rhs.phase)"))
        }
        if lhs.slots != rhs.slots {
            found.append(difference(name, "slot table offset", "gear \(index)"))
        }
        if lhs.blades != rhs.blades { found.append(difference(name, "gear blades", "gear \(index)")) }
        if lhs.parent != rhs.parent { found.append(difference(name, "gear parent", "gear \(index)")) }
        if lhs.alignment != rhs.alignment { found.append(difference(name, "gear alignment", "gear \(index)")) }
        return found
    }

    /// Every disagreement of `level` with its stored witness level, each naming the level and the part.
    static func levelDifferences(_ level: MoonlitMechanismLevel, stored: MoonlitMechanismLevel,
                                 name: String) -> [MoonlitMechanismRegressionDifference] {
        var found: [MoonlitMechanismRegressionDifference] = []
        if level.id != stored.id { found.append(difference(name, "id")) }
        if level.seed != stored.seed { found.append(difference(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(difference(name, "difficulty")) }
        if level.gears.count != stored.gears.count {
            found.append(difference(name, "gear count", "\(level.gears.count), witness \(stored.gears.count)"))
        } else {
            for index in 0..<level.gears.count {
                found += gearDifferences(level.gears[index], stored.gears[index], index: index, name: name)
            }
        }
        if level.width != stored.width || level.rows != stored.rows { found.append(difference(name, "wall")) }
        if level.lampHeights != stored.lampHeights { found.append(difference(name, "lamp heights")) }
        if level.startingHeight != stored.startingHeight {
            found.append(difference(name, "lamp starting height",
                                    "\(level.startingHeight), witness \(stored.startingHeight)"))
        }
        if level.keyFrames.count != stored.keyFrames.count {
            found.append(difference(name, "key frame count",
                                    "\(level.keyFrames.count), witness \(stored.keyFrames.count)"))
        } else {
            for index in 0..<level.keyFrames.count {
                let lhs: MoonlitMechanismKeyFrame = level.keyFrames[index]
                let rhs: MoonlitMechanismKeyFrame = stored.keyFrames[index]
                if lhs.target != rhs.target {
                    found.append(difference(name, "key frame target cell",
                                            "key frame \(index): \(lhs.target.count) cells, witness "
                                                + "\(rhs.target.count)"))
                }
                if lhs.turns != rhs.turns { found.append(difference(name, "key frame turns", "key frame \(index)")) }
                if lhs.required != rhs.required {
                    found.append(difference(name, "key frame required", "key frame \(index)"))
                }
            }
        }
        if level.forbidden != stored.forbidden {
            found.append(difference(name, "forbidden cell",
                                    "count \(level.forbidden.count), witness \(stored.forbidden.count)"))
        }
        if level.allowance != stored.allowance { found.append(difference(name, "allowance")) }
        if level.budget != stored.budget {
            found.append(difference(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(difference(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(difference(name, "level fingerprint")) }
        return found
    }

    /// Every disagreement between `level`, its stored `witness` and the solver's `plan` for `level`, each naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on the last action in exactly its action count within the budget with exactly its per-action
    /// digests and fingerprints, the counterexample's norm and vectors and the difficulty's smaller vectors are the
    /// recounted ones, and the plan's turns, lamp steps, re-seats, smaller vectors and size equal the witness's with
    /// work at most `MoonlitMechanismSolver.workBound`. The level parts come first, so an altered level's first
    /// difference is its own part. A replay the play refuses is a named difference, never a crash. Pure.
    static func differences(level: MoonlitMechanismLevel, witness: MoonlitMechanismWitness,
                            plan: MoonlitMechanismPlan?) -> [MoonlitMechanismRegressionDifference] {
        let name: String = "level \(witness.number)"
        var found: [MoonlitMechanismRegressionDifference] = levelDifferences(level, stored: witness.level, name: name)

        // The witness's actions replayed on a fresh play: a win on the last action and not before, within the budget.
        let parts: MoonlitMechanismRegressionVector = vector(witness.actions, gears: level.gears.count)
        if let run: MoonlitMechanismRegressionReplay = replayed(level, witness.actions) {
            if run.endedEarly {
                found.append(difference(name, "witness action", "the play ends before the last action"))
            }
            if run.play.stage != .won {
                found.append(difference(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            if witness.actions.count != parts.size + 1 || witness.actions.last != .run || parts.size == 0 {
                found.append(difference(name, "witness action",
                                        "count \(witness.actions.count): plan size \(parts.size) + 1 run"))
            }
            if run.play.actionsSpent != witness.actions.count || run.play.actionsSpent > level.budget {
                found.append(difference(name, "budget", "spent \(run.play.actionsSpent) of \(level.budget)"))
            }
            if run.digests != witness.digests {
                found.append(difference(name, "per-action digest",
                                        "count \(witness.digests.count), replay \(run.digests.count)"))
            }
            if run.fingerprints != witness.fingerprints {
                var first: Int = 0
                while first < min(run.fingerprints.count, witness.fingerprints.count),
                      run.fingerprints[first] == witness.fingerprints[first] {
                    first += 1
                }
                found.append(difference(name, "per-action fingerprint", "fingerprint \(first + 1)"))
            }
        } else {
            found.append(difference(name, "witness action", "replay refused"))
        }

        // The counterexample: its norm one below the plan, its vectors the count at that norm (none winning), and the
        // vectors of every norm up to it the difficulty's smaller vectors.
        let dimensions: Int = level.gears.count + 1
        let norm: Int = parts.size - 1
        if witness.counterexample.norm != norm {
            found.append(difference(name, "counterexample norm", "\(witness.counterexample.norm), witness plan \(norm)"))
        }
        let vectors: Int = MoonlitMechanismWitness.vectors(dimensions: dimensions, norm: norm)
        if witness.counterexample.vectors != vectors {
            found.append(difference(name, "smaller-vectors count",
                                    "\(witness.counterexample.vectors), recount \(vectors)"))
        }
        var total: Int = 0
        if norm >= 0 {
            for smaller in 0...norm { total += MoonlitMechanismWitness.vectors(dimensions: dimensions, norm: smaller) }
        }
        if witness.difficulty.smallerVectors != total {
            found.append(difference(name, "smaller-vectors total",
                                    "\(witness.difficulty.smallerVectors), recount \(total)"))
        }

        // The solver: exactly the witness's turns, lamp steps, re-seats, smaller vectors and size; work within the
        // bound.
        guard let plan: MoonlitMechanismPlan = plan else {
            found.append(difference(name, "plan component", "the solver finds no plan"))
            return found
        }
        if plan.turns != parts.turns || plan.lamp != parts.lamp || plan.reseats != parts.reseats {
            found.append(difference(name, "plan component",
                                    "plan turns \(plan.turns) lamp \(plan.lamp) re-seats \(plan.reseats), witness "
                                        + "turns \(parts.turns) lamp \(parts.lamp) re-seats \(parts.reseats)"))
        }
        if MoonlitMechanismSolver.actions(plan) != witness.actions {
            found.append(difference(name, "witness action", "not the plan's actions"))
        }
        if plan.smallerVectors != witness.difficulty.smallerVectors {
            found.append(difference(name, "smaller-vectors total",
                                    "plan \(plan.smallerVectors), witness \(witness.difficulty.smallerVectors)"))
        }
        if plan.size - 1 != witness.counterexample.norm {
            found.append(difference(name, "counterexample norm", "plan \(plan.size - 1)"))
        }
        if plan.work > MoonlitMechanismSolver.workBound {
            found.append(difference(name, "solver work", "\(plan.work) exceeds \(MoonlitMechanismSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(difference(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: MoonlitMechanismGenerated = try generated(number)
        let witness: MoonlitMechanismWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(generated.level)
        let found: [MoonlitMechanismRegressionDifference] = differences(level: generated.level, witness: witness,
                                                                        plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.map(\.message).joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= MoonlitMechanismSolver.workBound,
                "level \(number): solver work above the bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1408-001; SC-R02G1408-001; Q1)

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

    // MARK: Alterations (FR-R02G1408-002; SC-R02G1408-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: MoonlitMechanismLevel, gears: [MoonlitMechanismGear]? = nil,
                        startingHeight: Int? = nil, keyFrames: [MoonlitMechanismKeyFrame]? = nil,
                        forbidden: [Int]? = nil, budget: Int? = nil) throws -> MoonlitMechanismLevel {
        try MoonlitMechanismLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                  gears: gears ?? level.gears, width: level.width, rows: level.rows,
                                  lampHeights: level.lampHeights, startingHeight: startingHeight ?? level.startingHeight,
                                  keyFrames: keyFrames ?? level.keyFrames, forbidden: forbidden ?? level.forbidden,
                                  allowance: level.allowance, budget: budget ?? level.budget, tutorial: level.tutorial)
    }

    /// `gear` with the given parts replaced (the gear initialiser checks nothing; the level initialiser does).
    static func gear(_ gear: MoonlitMechanismGear, teeth: Int? = nil, phase: Int? = nil, blades: [Bool]? = nil,
                     depth: Int? = nil, centre: MoonlitMechanismCell? = nil, alignment: Int? = nil,
                     slots: [[MoonlitMechanismCell]]? = nil) -> MoonlitMechanismGear {
        MoonlitMechanismGear(teeth: teeth ?? gear.teeth, phase: phase ?? gear.phase, blades: blades ?? gear.blades,
                             depth: depth ?? gear.depth, centre: centre ?? gear.centre, parent: gear.parent,
                             alignment: alignment ?? gear.alignment, slots: slots ?? gear.slots)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: MoonlitMechanismWitness, actions: [MoonlitMechanismAction]? = nil,
                        fingerprints: [String]? = nil,
                        counterexample: MoonlitMechanismCounterexample? = nil) -> MoonlitMechanismWitness {
        MoonlitMechanismWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                digests: witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                                counterexample: counterexample ?? witness.counterexample,
                                difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// One less within `range`, or one more at its lower end.
    static func nudged(_ value: Int, within range: ClosedRange<Int>) -> Int {
        value > range.lowerBound ? value - 1 : value + 1
    }

    /// The gear an alteration of `level` touches: seed 2_438 modulo the gear count.
    static func alteredGear(_ level: MoonlitMechanismLevel) -> Int {
        Int(alterationSeed % UInt64(level.gears.count))
    }

    /// The gears with gear `alteredGear(level)` passed through `change`.
    static func gearsAltered(_ level: MoonlitMechanismLevel,
                             _ change: (MoonlitMechanismGear) -> MoonlitMechanismGear) -> [MoonlitMechanismGear] {
        var gears: [MoonlitMechanismGear] = level.gears
        let index: Int = alteredGear(level)
        gears[index] = change(gears[index])
        return gears
    }

    /// The tooth count altered: starting with gear `alteredGear(level)`, the first gear and the nearest other tooth
    /// count (6 … 20) for which the level rules accept the copy, the blades and slots repeated around the new count
    /// (one blade flipped if they all agree), the phase kept in range and the mesh alignment taken modulo the new
    /// common divisor; when no copy is accepted, the first attempted copy, which the level rules refuse.
    static func teethAltered(_ level: MoonlitMechanismLevel) throws -> MoonlitMechanismLevel {
        let count: Int = level.gears.count
        let start: Int = alteredGear(level)
        var firstAttempt: [MoonlitMechanismGear]? = nil
        for offset in 0..<count {
            let index: Int = (start + offset) % count
            let old: MoonlitMechanismGear = level.gears[index]
            var candidates: [Int] = []
            for distance in 1...MoonlitMechanismLevel.toothCounts.count {
                for teeth in [old.teeth - distance, old.teeth + distance]
                where MoonlitMechanismLevel.toothCounts.contains(teeth) {
                    candidates.append(teeth)
                }
            }
            for teeth in candidates {
                var blades: [Bool] = []
                var slots: [[MoonlitMechanismCell]] = []
                for tooth in 0..<teeth {
                    blades.append(old.blades[tooth % old.teeth])
                    slots.append(old.slots[tooth % old.teeth])
                }
                if !blades.contains(true) || !blades.contains(false) { blades[0] = !blades[0] }
                var alignment: Int = 0
                if let parent: Int = old.parent {
                    let common: Int = MoonlitMechanismTrain.gcd(level.gears[parent].teeth, teeth)
                    alignment = common >= 1 ? old.alignment % common : 0
                }
                var gears: [MoonlitMechanismGear] = level.gears
                gears[index] = gear(old, teeth: teeth, phase: min(old.phase, teeth - 1), blades: blades,
                                    alignment: alignment, slots: slots)
                if firstAttempt == nil { firstAttempt = gears }
                if let copy: MoonlitMechanismLevel = try? rebuilt(level, gears: gears) { return copy }
            }
        }
        return try rebuilt(level, gears: firstAttempt ?? level.gears)
    }

    /// The centre altered: the altered gear's centre one column over, within the wall.
    static func centreAltered(_ level: MoonlitMechanismLevel) -> [MoonlitMechanismGear] {
        gearsAltered(level) { (old: MoonlitMechanismGear) in
            let column: Int = Self.nudged(old.centre.column, within: 0...(level.width - 1))
            return Self.gear(old, centre: MoonlitMechanismCell(column: column, row: old.centre.row))
        }
    }

    /// The slot table altered: the altered gear's first slot's first offset one column over, within ±8.
    static func slotsAltered(_ level: MoonlitMechanismLevel) -> [MoonlitMechanismGear] {
        gearsAltered(level) { (old: MoonlitMechanismGear) in
            var slots: [[MoonlitMechanismCell]] = old.slots
            let cell: MoonlitMechanismCell = slots[0][0]
            let limit: Int = MoonlitMechanismLevel.maxOffset
            slots[0][0] = MoonlitMechanismCell(column: Self.nudged(cell.column, within: -limit...limit), row: cell.row)
            return Self.gear(old, slots: slots)
        }
    }

    /// The first wall cell of `level` outside `taken`, or nil.
    static func freeCell(_ level: MoonlitMechanismLevel, excluding taken: Set<Int>) -> Int? {
        for cell in 0..<(level.width * level.rows) where !taken.contains(cell) { return cell }
        return nil
    }

    /// Every target cell of every key frame of `level`.
    static func targetCells(_ level: MoonlitMechanismLevel) -> Set<Int> {
        var cells: Set<Int> = []
        for frame in level.keyFrames { cells.formUnion(frame.target) }
        return cells
    }

    /// The key frames altered: key frame 0's first target cell replaced by the first wall cell neither in that
    /// target nor forbidden (the target kept sorted).
    static func keyFramesAltered(_ level: MoonlitMechanismLevel) -> [MoonlitMechanismKeyFrame] {
        var frames: [MoonlitMechanismKeyFrame] = level.keyFrames
        let frame: MoonlitMechanismKeyFrame = frames[0]
        guard let cell: Int = freeCell(level, excluding: Set(frame.target).union(level.forbidden)) else {
            return frames
        }
        var target: [Int] = frame.target
        target[0] = cell
        target.sort()
        frames[0] = MoonlitMechanismKeyFrame(turns: frame.turns, target: target, required: frame.required)
        return frames
    }

    /// The forbidden cells altered: the first forbidden cell replaced by (or, with none, the list given) the first
    /// wall cell neither forbidden nor in any target (kept sorted).
    static func forbiddenAltered(_ level: MoonlitMechanismLevel) -> [Int] {
        var cells: [Int] = level.forbidden
        guard let cell: Int = freeCell(level, excluding: targetCells(level).union(cells)) else { return cells }
        if cells.isEmpty { cells.append(cell) } else { cells[0] = cell }
        cells.sort()
        return cells
    }

    /// The level alteration of `part` checked against `witness`: the copy built by `build`, or a construction the level
    /// rules refuse, which is itself a difference naming `part`.
    static func levelAlterationDifferences(part: String, number: Int, witness: MoonlitMechanismWitness,
                                           plan: MoonlitMechanismPlan?,
                                           build: () throws -> MoonlitMechanismLevel)
        -> [MoonlitMechanismRegressionDifference] {
        let copy: MoonlitMechanismLevel
        do {
            copy = try build()
        } catch {
            return [difference("level \(number)", part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint {
            return [MoonlitMechanismRegressionDifference(part: "unchanged", message: "level \(number): \(part) unchanged")]
        }
        return differences(level: copy, witness: witness, plan: plan)
    }

    /// Records an issue unless `found` is not empty, names `part` first in a message naming level `number` and the
    /// part, and every message names level `number`.
    static func expectNamed(_ found: [MoonlitMechanismRegressionDifference], number: Int, part: String) {
        let message: String = found.first?.message ?? "(none)"
        #expect(found.first?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
        for entry in found {
            #expect(entry.message.hasPrefix("level \(number): "),
                    "level \(number) alteration \(part): \"\(entry.message)\" does not name the level")
        }
    }

    /// The unaltered level, witness and plan are clean, so every difference found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: MoonlitMechanismLevel = try Self.generated(number).level
        let witness: MoonlitMechanismWitness = try Self.witness(number)
        let found: [MoonlitMechanismRegressionDifference] =
            Self.differences(level: level, witness: witness, plan: MoonlitMechanismSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.map(\.message).joined(separator: "; "))")
    }

    /// Level alterations: a gear's tooth count, a gear's centre, a gear's depth, a gear's starting phase, a slot table
    /// offset, the lamp's starting height, a key frame's target cell, a forbidden cell and the budget, each rebuilt
    /// through the level initialiser and named first. The level is compared first, so the unaltered plan is passed and
    /// no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: MoonlitMechanismGenerated = try Self.generated(number)
        let level: MoonlitMechanismLevel = generated.level
        let witness: MoonlitMechanismWitness = try Self.witness(number)
        let plan: MoonlitMechanismPlan = generated.plan
        var parts: [String] = []
        var builders: [() throws -> MoonlitMechanismLevel] = []
        parts.append("gear tooth count")
        builders.append { try Self.teethAltered(level) }
        parts.append("gear centre")
        builders.append { try Self.rebuilt(level, gears: Self.centreAltered(level)) }
        parts.append("gear depth")
        builders.append {
            try Self.rebuilt(level, gears: Self.gearsAltered(level) { (old: MoonlitMechanismGear) in
                Self.gear(old, depth: Self.nudged(old.depth, within: MoonlitMechanismLevel.depths))
            })
        }
        parts.append("gear starting phase")
        builders.append {
            try Self.rebuilt(level, gears: Self.gearsAltered(level) { (old: MoonlitMechanismGear) in
                Self.gear(old, phase: (old.phase + 1) % old.teeth)
            })
        }
        parts.append("slot table offset")
        builders.append { try Self.rebuilt(level, gears: Self.slotsAltered(level)) }
        parts.append("lamp starting height")
        builders.append {
            try Self.rebuilt(level, startingHeight: Self.nudged(level.startingHeight,
                                                                within: 0...(level.lampHeights - 1)))
        }
        parts.append("key frame target cell")
        builders.append { try Self.rebuilt(level, keyFrames: Self.keyFramesAltered(level)) }
        parts.append("forbidden cell")
        builders.append { try Self.rebuilt(level, forbidden: Self.forbiddenAltered(level)) }
        parts.append("budget")
        builders.append { try Self.rebuilt(level, budget: Self.nudged(level.budget, within: MoonlitMechanismLevel.budgets)) }
        #expect(parts.count == 9 && builders.count == 9)
        for position in 0..<builders.count {
            let found: [MoonlitMechanismRegressionDifference] =
                Self.levelAlterationDifferences(part: parts[position], number: number, witness: witness, plan: plan,
                                                build: builders[position])
            Self.expectNamed(found, number: number, part: parts[position])
        }
    }

    /// A refused level construction is named too: a depth one above the deepest allowed is refused by the level rules
    /// and reported as the gear's depth.
    @Test func aRefusedLevelConstructionIsNamed() throws {
        let number: Int = 41
        let generated: MoonlitMechanismGenerated = try Self.generated(number)
        let level: MoonlitMechanismLevel = generated.level
        let witness: MoonlitMechanismWitness = try Self.witness(number)
        let tooDeep: Int = MoonlitMechanismLevel.depths.upperBound + 1
        let found: [MoonlitMechanismRegressionDifference] =
            Self.levelAlterationDifferences(part: "gear depth", number: number, witness: witness,
                                            plan: generated.plan) {
                try Self.rebuilt(level, gears: Self.gearsAltered(level) { (old: MoonlitMechanismGear) in
                    Self.gear(old, depth: tooDeep)
                })
            }
        Self.expectNamed(found, number: number, part: "gear depth")
        #expect(found.first?.message.contains("refuse") == true, "level \(number): \(found.first?.message ?? "(none)")")
    }

    /// The plan alteration: the solver's plan with one more handle turn (turns, lamp and re-seats are each a plan
    /// component; the turns are the one changed).
    @Test(arguments: alteredNumbers) func planComponentAlterationIsNamed(number: Int) throws {
        let level: MoonlitMechanismLevel = try Self.generated(number).level
        let witness: MoonlitMechanismWitness = try Self.witness(number)
        let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: MoonlitMechanismPlan = plan else { return }
        let copy: MoonlitMechanismPlan = MoonlitMechanismPlan(turns: plan.turns + 1, lamp: plan.lamp,
                                                              reseats: plan.reseats,
                                                              smallerVectors: plan.smallerVectors, work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        Self.expectNamed(Self.differences(level: level, witness: witness, plan: copy), number: number,
                         part: "plan component")
    }

    /// Witness alterations: an action, a per-action fingerprint and the smaller-vectors count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: MoonlitMechanismLevel = try Self.generated(number).level
        let witness: MoonlitMechanismWitness = try Self.witness(number)
        let plan: MoonlitMechanismPlan? = MoonlitMechanismSolver.plan(level)
        var parts: [String] = []
        var copies: [MoonlitMechanismWitness] = []

        // A witness action: the final run replaced by the first action again, so the altered actions never win.
        var actions: [MoonlitMechanismAction] = witness.actions
        actions[actions.count - 1] = actions[0]
        #expect(!MoonlitMechanismSolver.wins(level, actions: actions), "level \(number): the altered actions win")
        parts.append("witness action")
        copies.append(Self.rebuilt(witness, actions: actions))

        // A per-action fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        parts.append("per-action fingerprint")
        copies.append(Self.rebuilt(witness, fingerprints: fingerprints))

        // The smaller-vectors count: the counterexample's vectors one more.
        let counterexample: MoonlitMechanismCounterexample =
            MoonlitMechanismCounterexample(norm: witness.counterexample.norm,
                                           vectors: witness.counterexample.vectors + 1)
        parts.append("smaller-vectors count")
        copies.append(Self.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 3)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: MoonlitMechanismWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.differences(level: level, witness: copy, plan: plan), number: number, part: part)
        }
    }
}
