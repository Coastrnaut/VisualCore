// EchoCartographerRegressionSolverTests — feature 408 (R02-G11-08) T-R02G1108-002 (FR-R02G1108-001, 002;
// SC-R02G1108-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/echo-cartographer/levels (part by part and by fingerprint); the witness's actions replay on a fresh play
// (begun, the tutorial dismissed) to a win on the last action and not before, in exactly its action count (the plan's
// pulses then one claim per beacon), within the energy, with exactly its per-pulse echo digests
// (`EchoCartographerWitness.digest` of each pulse's echo) and per-action fingerprints (after `begin`, after
// `dismissTutorial` when the level has a tutorial, and after each action); the placements recounted after each pulse
// with `EchoCartographerSolver.fitting` and one pulse short equal the witness's; `EchoCartographerSolver.plan` returns
// exactly the witness's pulses with exactly its placements and placements before the last pulse, and its work is at most
// `EchoCartographerSolver.workBound` (counted, never timed). The 100 levels are generated concurrently once per process
// (through the experience core's cache) so each test stays short.
//
// The alterations (clarification Q2): ten kinds, each applied to a copy of level 1, 41 or 81 and each detected by the
// checker `firstFailure`, which returns the first differing part with a message naming the level and the part ("level
// 41: energy differs …"): a beacon cell, a chamber wall, the energy, the tolerance, the miss cost (each rebuilt through
// the level initialiser; a refused construction is itself named as the part); a plan pulse; a witness action, a
// per-pulse echo digest, a per-action fingerprint; the placements count. The unaltered input gives nil. Every alteration
// is fixed (no random source). Explicit types, plain loops, short runs.
@testable import EchoCartographerCore
import Foundation
import Testing

/// The repository's witness directory, found from this file.
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/echo-cartographer/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache).
private let regressionSolverCatalogResult: Result<[EchoCartographerGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? EchoCartographerExperienceCore.generated(number: index + 1)
    }
    var catalog: [EchoCartographerGenerated] = []
    for number in 1...100 { catalog.append(try EchoCartographerExperienceCore.generated(number: number)) }
    return catalog
}

/// A failure of the regression: the part that differs first and the message naming the level and that part.
struct EchoCartographerRegressionFailure: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level, witness or plan.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

/// The independent replay of a witness's actions: the play at the end, the fingerprints, the per-pulse echo digests
/// and observations, and whether any action but the first found the play no longer playing.
struct EchoCartographerRegressionReplay {
    /// The play after the last action.
    let play: EchoCartographerPlay
    /// The fingerprints after `begin`, after `dismissTutorial` (with a tutorial) and after each action.
    let fingerprints: [String]
    /// The echo digest of every pulse, in order.
    let digests: [String]
    /// The observation of every pulse, in order.
    let observations: [EchoCartographerObservation]
    /// The pulse emitters, in order.
    let pulses: [EchoCartographerCell]
    /// Whether an action was applied to a play no longer playing.
    let endedEarly: Bool
}

@Suite struct EchoCartographerRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> EchoCartographerWitness {
        let name: String = String(EchoCartographerGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(EchoCartographerWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> EchoCartographerGenerated {
        let catalog: [EchoCartographerGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A failure of `part` for `name` with the detail `detail`.
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> EchoCartographerRegressionFailure {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return EchoCartographerRegressionFailure(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The first position where `lhs` and `rhs` differ (the shorter length when one is a prefix), or nil when equal.
    static func firstDifference(_ lhs: [Int], _ rhs: [Int]) -> Int? {
        let shared: Int = min(lhs.count, rhs.count)
        for index in 0..<shared where lhs[index] != rhs[index] { return index }
        return lhs.count == rhs.count ? nil : shared
    }

    /// The independent replay of `actions` on a fresh play of `level`, as the witness computes it: the fingerprint
    /// after `begin`, after `dismissTutorial` when the play shows a tutorial, and after each action (each applied with
    /// the current fingerprint), the `EchoCartographerWitness.digest` and observation of each pulse's echo; nil when a
    /// stage event or an action is refused or a pulse leaves no echo.
    static func replayed(_ level: EchoCartographerLevel,
                         _ actions: [EchoCartographerAction]) -> EchoCartographerRegressionReplay? {
        var play: EchoCartographerPlay = EchoCartographerPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var observations: [EchoCartographerObservation] = []
        var pulses: [EchoCartographerCell] = []
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
                if case .pulse = action {
                    guard let echo: EchoCartographerEcho = play.lastEcho else { return nil }
                    digests.append(EchoCartographerWitness.digest(echo))
                    observations.append(EchoCartographerObservation(emitter: echo.emitter,
                                                                    echoes: echo.beaconDistances))
                    pulses.append(echo.emitter)
                }
            }
        } catch {
            return nil
        }
        return EchoCartographerRegressionReplay(play: play, fingerprints: fingerprints, digests: digests,
                                                observations: observations, pulses: pulses, endedEarly: endedEarly)
    }

    /// The first disagreement of `level` with its stored witness level, naming the level and the part, or nil.
    static func levelFailure(_ level: EchoCartographerLevel, stored: EchoCartographerLevel,
                             name: String) -> EchoCartographerRegressionFailure? {
        if level.id != stored.id { return failure(name, "id") }
        if level.seed != stored.seed { return failure(name, "seed") }
        if level.difficulty != stored.difficulty { return failure(name, "difficulty") }
        if level.chamber.width != stored.chamber.width || level.chamber.height != stored.chamber.height {
            return failure(name, "chamber size")
        }
        if level.chamber.walls != stored.chamber.walls {
            let lhs: [Int] = level.chamber.walls.sorted()
            let rhs: [Int] = stored.chamber.walls.sorted()
            let position: Int = firstDifference(lhs, rhs) ?? 0
            return failure(name, "chamber wall", "wall \(position + 1)")
        }
        if level.entry != stored.entry { return failure(name, "entry") }
        if level.beacons.count != stored.beacons.count {
            return failure(name, "beacon cell", "count \(level.beacons.count), witness \(stored.beacons.count)")
        }
        for index in 0..<level.beacons.count where level.beacons[index] != stored.beacons[index] {
            return failure(name, "beacon cell", "beacon \(index + 1)")
        }
        if level.tolerance != stored.tolerance {
            return failure(name, "tolerance", "\(level.tolerance), witness \(stored.tolerance)")
        }
        if level.energy != stored.energy {
            return failure(name, "energy", "\(level.energy), witness \(stored.energy)")
        }
        if level.missCost != stored.missCost {
            return failure(name, "miss cost", "\(level.missCost), witness \(stored.missCost)")
        }
        if level.tutorial != stored.tutorial { return failure(name, "tutorial") }
        if level.fingerprint != stored.fingerprint { return failure(name, "level fingerprint") }
        return nil
    }

    /// The first disagreement between `level`, its stored `witness` and the solver's `plan` for `level`, naming the
    /// level and the part; nil when the level equals the witness's level, the witness's actions replay on a fresh play
    /// to a win on the last action in exactly its action count within the energy with exactly its per-pulse echo
    /// digests and per-action fingerprints, the recounted placements equal the witness's, and the plan's pulses,
    /// placements and placements before the last pulse equal the witness's with work at most
    /// `EchoCartographerSolver.workBound`. A replay the play refuses is a named failure, never a crash. Pure.
    static func firstFailure(level: EchoCartographerLevel, witness: EchoCartographerWitness,
                             plan: EchoCartographerPlan?) -> EchoCartographerRegressionFailure? {
        let name: String = "level \(witness.number)"

        // The level against the witness's level, part by part, then by fingerprint.
        if let found: EchoCartographerRegressionFailure = levelFailure(level, stored: witness.level, name: name) {
            return found
        }

        // The witness's actions replayed on a fresh play: a win on the last action and not before.
        guard let run: EchoCartographerRegressionReplay = replayed(level, witness.actions) else {
            return failure(name, "witness action", "replay refused")
        }
        if run.endedEarly { return failure(name, "witness action", "the play ends before the last action") }
        if run.play.stage != .won {
            return failure(name, "witness action", "replay does not win (stage \(run.play.stage))")
        }
        if run.pulses.isEmpty { return failure(name, "witness action", "no pulse") }
        let expectedCount: Int = run.pulses.count + level.beacons.count
        if witness.actions.count != expectedCount {
            return failure(name, "witness action",
                           "count \(witness.actions.count), \(run.pulses.count) pulses + \(level.beacons.count) claims")
        }
        let spent: Int = level.energy - run.play.energy
        if spent > level.energy || spent != run.pulses.count {
            return failure(name, "energy", "spent \(spent) of \(level.energy), \(run.pulses.count) pulses")
        }

        // The per-pulse echo digests and per-action fingerprints.
        if run.digests.count != witness.echoDigests.count {
            return failure(name, "per-pulse echo digest",
                           "count \(witness.echoDigests.count), replay \(run.digests.count)")
        }
        for index in 0..<run.digests.count where run.digests[index] != witness.echoDigests[index] {
            return failure(name, "per-pulse echo digest", "pulse \(index + 1)")
        }
        if run.fingerprints.count != witness.fingerprints.count {
            return failure(name, "per-action fingerprint",
                           "count \(witness.fingerprints.count), replay \(run.fingerprints.count)")
        }
        for index in 0..<run.fingerprints.count where run.fingerprints[index] != witness.fingerprints[index] {
            return failure(name, "per-action fingerprint", "fingerprint \(index + 1)")
        }

        // The placements recounted after each pulse and one pulse short.
        var recounted: [Int] = []
        var spentWork: Int = 0
        var heard: [EchoCartographerObservation] = []
        for observation in run.observations {
            heard.append(observation)
            let count: Int = EchoCartographerSolver.fitting(level, observations: heard,
                                                            cap: EchoCartographerSolver.placementCap,
                                                            work: &spentWork).count
            recounted.append(count)
        }
        if let index: Int = firstDifference(recounted, witness.placements) {
            return failure(name, "placements count", "after pulse \(index + 1)")
        }
        if recounted.last != 1 { return failure(name, "placements count", "the last count is not 1") }
        let short: [EchoCartographerObservation] = Array(run.observations.dropLast())
        let before: (count: Int, first: [[EchoCartographerCell]]) =
            EchoCartographerSolver.fitting(level, observations: short, cap: EchoCartographerSolver.placementCap,
                                           work: &spentWork, collect: 2)
        if before.count != witness.placementsBeforeLast || before.count < 2 {
            return failure(name, "placements before last",
                           "\(witness.placementsBeforeLast), recount \(before.count)")
        }
        if before.first != witness.counterexample { return failure(name, "counterexample") }

        // The solver: exactly the witness's pulses, placements and placements before the last; work within the bound.
        guard let plan: EchoCartographerPlan = plan else { return failure(name, "plan pulse", "the solver finds no plan") }
        if plan.pulses.count != run.pulses.count {
            return failure(name, "plan pulse", "count \(plan.pulses.count), witness \(run.pulses.count)")
        }
        for index in 0..<plan.pulses.count where plan.pulses[index] != run.pulses[index] {
            return failure(name, "plan pulse", "pulse \(index + 1)")
        }
        let planActions: [EchoCartographerAction] = EchoCartographerSolver.actions(level, plan: plan)
        if planActions != witness.actions { return failure(name, "witness action", "not the plan's actions") }
        if let index: Int = firstDifference(plan.placements, witness.placements) {
            return failure(name, "placements count", "plan, after pulse \(index + 1)")
        }
        if plan.placementsBeforeLast != witness.placementsBeforeLast {
            return failure(name, "placements before last",
                           "plan \(plan.placementsBeforeLast), witness \(witness.placementsBeforeLast)")
        }
        if plan.counterexample != witness.counterexample { return failure(name, "counterexample", "plan") }
        if plan.work > EchoCartographerSolver.workBound {
            return failure(name, "solver work", "\(plan.work) exceeds \(EchoCartographerSolver.workBound)")
        }
        if plan.work != witness.difficulty.work {
            return failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)")
        }
        return nil
    }

    /// Checks level `number` of group `group` (levels 10·(group − 1) + 1 … 10·group): one level per argument.
    static func check(group: Int, index: Int) throws {
        let number: Int = (group - 1) * 10 + index + 1
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        let generated: EchoCartographerGenerated = try generated(number)
        let witness: EchoCartographerWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: EchoCartographerPlan? = EchoCartographerSolver.plan(generated.level)
        let found: EchoCartographerRegressionFailure? = firstFailure(level: generated.level, witness: witness,
                                                                     plan: plan)
        #expect(found == nil, Comment(rawValue: found?.message ?? ""))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= EchoCartographerSolver.workBound,
                "level \(number): solver work above the bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1108-001; SC-R02G1108-001; Q1)

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

    // MARK: Alterations (FR-R02G1108-002; SC-R02G1108-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: EchoCartographerLevel, chamber: EchoCartographerChamber? = nil,
                        beacons: [EchoCartographerCell]? = nil, tolerance: Int? = nil, energy: Int? = nil,
                        missCost: Int? = nil) throws -> EchoCartographerLevel {
        try EchoCartographerLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                  chamber: chamber ?? level.chamber, entry: level.entry,
                                  beacons: beacons ?? level.beacons, tolerance: tolerance ?? level.tolerance,
                                  energy: energy ?? level.energy, missCost: missCost ?? level.missCost,
                                  tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: EchoCartographerWitness, actions: [EchoCartographerAction]? = nil,
                        echoDigests: [String]? = nil, fingerprints: [String]? = nil,
                        placements: [Int]? = nil) -> EchoCartographerWitness {
        EchoCartographerWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                echoDigests: echoDigests ?? witness.echoDigests,
                                placements: placements ?? witness.placements,
                                fingerprints: fingerprints ?? witness.fingerprints,
                                counterexample: witness.counterexample,
                                placementsBeforeLast: witness.placementsBeforeLast, difficulty: witness.difficulty,
                                skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// One more within `range`, or one less at its upper end.
    static func nudged(_ value: Int, within range: ClosedRange<Int>) -> Int {
        value < range.upperBound ? value + 1 : value - 1
    }

    /// The beacons with the first one moved to the first region cell that is not a beacon.
    static func beaconsAltered(_ level: EchoCartographerLevel) -> [EchoCartographerCell] {
        var beacons: [EchoCartographerCell] = level.beacons
        for cell in EchoCartographerSolver.region(level) where !beacons.contains(cell) {
            beacons[0] = cell
            return beacons
        }
        return beacons
    }

    /// The chamber with its first wall removed (a removed wall never cuts a beacon off), or with a wall added at the
    /// first open cell that is neither the entry nor a beacon when the chamber has no wall.
    static func chamberAltered(_ level: EchoCartographerLevel) throws -> EchoCartographerChamber {
        let chamber: EchoCartographerChamber = level.chamber
        var walls: Set<Int> = chamber.walls
        if let first: Int = walls.min() {
            walls.remove(first)
        } else {
            for index in 0..<chamber.cellCount {
                let cell: EchoCartographerCell = chamber.cell(index)
                if cell != level.entry && !level.beacons.contains(cell) {
                    walls.insert(index)
                    break
                }
            }
        }
        return try EchoCartographerChamber(width: chamber.width, height: chamber.height, walls: walls)
    }

    /// The level alteration of `part` checked against `witness`: the copy built by `build`, or a construction the level
    /// rules refuse, which is itself a failure naming `part`.
    static func levelAlterationFailure(part: String, number: Int, witness: EchoCartographerWitness,
                                       plan: EchoCartographerPlan?,
                                       build: () throws -> EchoCartographerLevel) -> EchoCartographerRegressionFailure? {
        let copy: EchoCartographerLevel
        do {
            copy = try build()
        } catch {
            return failure("level \(number)", part, "the level rules refuse the copy: \(error)")
        }
        if copy.fingerprint == witness.level.fingerprint {
            return EchoCartographerRegressionFailure(part: "unchanged", message: "level \(number): \(part) unchanged")
        }
        return firstFailure(level: copy, witness: witness, plan: plan)
    }

    /// Records an issue unless `found` names exactly `part` in a message naming level `number` and the part.
    static func expectNamed(_ found: EchoCartographerRegressionFailure?, number: Int, part: String) {
        let message: String = found?.message ?? "(none)"
        #expect(found?.part == part, "level \(number) alteration \(part): found \"\(message)\"")
        #expect(message.hasPrefix("level \(number): \(part) differs"),
                "level \(number) alteration \(part): \"\(message)\" does not name the level and the part")
    }

    /// The unaltered level, witness and plan are clean, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: EchoCartographerLevel = try Self.generated(number).level
        let found: EchoCartographerRegressionFailure? = Self.firstFailure(level: level, witness: try Self.witness(number),
                                                                          plan: EchoCartographerSolver.plan(level))
        #expect(found == nil, "level \(number): \(found?.message ?? "")")
    }

    /// Level alterations: a beacon cell, a chamber wall, the energy, the tolerance and the miss cost, each rebuilt
    /// through the level initialiser and named exactly. The level is compared first, so the unaltered plan is passed and
    /// no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: EchoCartographerGenerated = try Self.generated(number)
        let level: EchoCartographerLevel = generated.level
        let witness: EchoCartographerWitness = try Self.witness(number)
        let plan: EchoCartographerPlan = generated.plan

        let beacon: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "beacon cell", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, beacons: Self.beaconsAltered(level))
            }
        Self.expectNamed(beacon, number: number, part: "beacon cell")

        let wall: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "chamber wall", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, chamber: try Self.chamberAltered(level))
            }
        Self.expectNamed(wall, number: number, part: "chamber wall")

        let energy: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "energy", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, energy: Self.nudged(level.energy, within: EchoCartographerLevel.energies))
            }
        Self.expectNamed(energy, number: number, part: "energy")

        let tolerance: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "tolerance", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level,
                                 tolerance: Self.nudged(level.tolerance, within: EchoCartographerLevel.tolerances))
            }
        Self.expectNamed(tolerance, number: number, part: "tolerance")

        let missCost: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "miss cost", number: number, witness: witness, plan: plan) {
                try Self.rebuilt(level, missCost: Self.nudged(level.missCost, within: EchoCartographerLevel.missCosts))
            }
        Self.expectNamed(missCost, number: number, part: "miss cost")
    }

    /// A refused level construction is named too: a beacon moved onto a wall (or outside the chamber when it has no
    /// wall) is refused by the level rules and reported as the beacon cell.
    @Test func aRefusedLevelConstructionIsNamed() throws {
        let number: Int = 41
        let generated: EchoCartographerGenerated = try Self.generated(number)
        let level: EchoCartographerLevel = generated.level
        let witness: EchoCartographerWitness = try Self.witness(number)
        var target: EchoCartographerCell = EchoCartographerCell(x: level.chamber.width, y: 0)
        if let wall: Int = level.chamber.walls.min() { target = level.chamber.cell(wall) }
        var beacons: [EchoCartographerCell] = level.beacons
        beacons[0] = target
        let found: EchoCartographerRegressionFailure? =
            Self.levelAlterationFailure(part: "beacon cell", number: number, witness: witness, plan: generated.plan) {
                try Self.rebuilt(level, beacons: beacons)
            }
        Self.expectNamed(found, number: number, part: "beacon cell")
        #expect(found?.message.contains("refuse") == true, "level \(number): \(found?.message ?? "(none)")")
    }

    /// The plan alteration: the solver's first pulse replaced by another cell (the entry, or the first region cell
    /// when the first pulse is the entry).
    @Test(arguments: alteredNumbers) func planPulseAlterationIsNamed(number: Int) throws {
        let level: EchoCartographerLevel = try Self.generated(number).level
        let witness: EchoCartographerWitness = try Self.witness(number)
        let plan: EchoCartographerPlan? = EchoCartographerSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: EchoCartographerPlan = plan else { return }
        var pulses: [EchoCartographerCell] = plan.pulses
        var other: EchoCartographerCell = level.entry
        if other == pulses[0] { other = EchoCartographerSolver.region(level)[0] }
        pulses[0] = other
        let copy: EchoCartographerPlan = EchoCartographerPlan(pulses: pulses, placements: plan.placements,
                                                              placementsBeforeLast: plan.placementsBeforeLast,
                                                              counterexample: plan.counterexample, work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        Self.expectNamed(Self.firstFailure(level: level, witness: witness, plan: copy), number: number,
                         part: "plan pulse")
    }

    /// Witness alterations: an action, a per-pulse echo digest, a per-action fingerprint and the placements count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: EchoCartographerLevel = try Self.generated(number).level
        let witness: EchoCartographerWitness = try Self.witness(number)
        let plan: EchoCartographerPlan? = EchoCartographerSolver.plan(level)
        var parts: [String] = []
        var copies: [EchoCartographerWitness] = []

        // A witness action: the last claim replaced by a pulse from the entry, which never wins.
        var actions: [EchoCartographerAction] = witness.actions
        actions[actions.count - 1] = EchoCartographerAction.pulse(level.entry.x, level.entry.y)
        #expect(!EchoCartographerSolver.wins(level, actions: actions), "level \(number): the altered actions win")
        parts.append("witness action")
        copies.append(Self.rebuilt(witness, actions: actions))

        // A per-pulse echo digest: the middle pulse's digest with its first character changed.
        var digests: [String] = witness.echoDigests
        let pulse: Int = digests.count / 2
        digests[pulse] = Self.flipped(digests[pulse])
        parts.append("per-pulse echo digest")
        copies.append(Self.rebuilt(witness, echoDigests: digests))

        // A per-action fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        parts.append("per-action fingerprint")
        copies.append(Self.rebuilt(witness, fingerprints: fingerprints))

        // The placements count: the first pulse's count one more.
        var placements: [Int] = witness.placements
        placements[0] += 1
        parts.append("placements count")
        copies.append(Self.rebuilt(witness, placements: placements))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: EchoCartographerWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.firstFailure(level: level, witness: copy, plan: plan), number: number, part: part)
        }
    }
}
