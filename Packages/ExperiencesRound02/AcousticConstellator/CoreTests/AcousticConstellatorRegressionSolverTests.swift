// AcousticConstellatorRegressionSolverTests — feature 428 (R02-G13-08) T-R02G1308-002 (FR-R02G1308-001, 002;
// SC-R02G1308-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1): the generated level equals the level of its witness file in
// docs/games/acoustic-constellator/levels (part by part and by fingerprint); the witness's actions replay on a fresh
// play (begun, the tutorial dismissed) to a win on the last action and not before, in exactly its action count (the
// plan's links, then its nudges, then one listen), within the budget, with exactly its per-action state digests
// (`AcousticConstellatorWitness.digest(links:phases:)` after each action) and per-action fingerprints (after `begin`,
// after `dismissTutorial` when the level has a tutorial, and after each action); the smaller sets recounted over the
// solver's options equal the witness's counterexample (its `sets`, `size` and `reason`) and the difficulty's
// `smallerSets`; `AcousticConstellatorSolver.plan` returns exactly the witness's links and nudges with exactly its
// `smallerSets` and size, and its work is at most `AcousticConstellatorSolver.workBound` (counted, never timed) and
// equal to the witness's.
// The 100 levels are generated concurrently once per process (through the experience core's cache) so each test stays
// short.
//
// The alterations (clarification Q2): thirteen kinds, each applied to a copy of level 1, 41 or 81 and each detected by
// the checker `differences`, which returns every named difference, each with a message naming the level and the part
// ("level 41: budget differs …"): a star's position, a star's rate, a star's starting phase, a fixed link, a symbol
// pair, the coupling, the threshold, the hold, the budget (each rebuilt through the level initialiser; a refused
// construction is itself named as the part); a plan link or nudge; a witness action, a per-action fingerprint; the
// smaller-sets count. The honest input gives an empty list. The altered star is fixed by seed 2_428 (no random
// source). Explicit types, plain loops, short runs.
@testable import AcousticConstellatorCore
import Foundation
import Testing

/// The repository's witness directory, found from this file (five levels up: CoreTests, AcousticConstellator, the
/// package, Packages).
private let regressionSolverWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/acoustic-constellator/levels", isDirectory: true)

/// The 100 certified levels in manifest order, generated concurrently once per test process (through the experience
/// core's cache).
private let regressionSolverCatalogResult: Result<[AcousticConstellatorGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? AcousticConstellatorExperienceCore.generated(number: index + 1)
    }
    var catalog: [AcousticConstellatorGenerated] = []
    for number in 1...100 { catalog.append(try AcousticConstellatorExperienceCore.generated(number: number)) }
    return catalog
}

/// One named difference of the regression: the part that differs and the message naming the level and that part.
struct AcousticConstellatorRegressionDifference: Equatable, CustomStringConvertible {
    /// The part's name, one of the names of clarification Q2 or another part of the level, witness or plan.
    let part: String
    /// The message: "level N: <part> differs (…)".
    let message: String

    /// The message.
    var description: String { message }
}

/// The independent replay of a witness's actions: the play at the end, the fingerprints, the per-action state digests
/// and whether any action but the first found the play no longer playing.
struct AcousticConstellatorRegressionReplay {
    /// The play after the last action.
    let play: AcousticConstellatorPlay
    /// The fingerprints after `begin`, after `dismissTutorial` (with a tutorial) and after each action.
    let fingerprints: [String]
    /// The state digest of the play's links and phases after every action, in order.
    let digests: [String]
    /// Whether an action was applied to a play no longer playing.
    let endedEarly: Bool
}

@Suite struct AcousticConstellatorRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]
    /// The seed that fixes which star an alteration touches (no random source).
    static let alterationSeed: UInt64 = 2_428

    // MARK: Helpers

    /// The stored witness of manifest number `number`, read with the plain decoder (the level re-checked; the proof is
    /// not re-run, which the regression below does itself).
    static func witness(_ number: Int) throws -> AcousticConstellatorWitness {
        let name: String = String(AcousticConstellatorGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: regressionSolverWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(AcousticConstellatorWitness.self, from: data)
    }

    /// The generated level of manifest number `number` (1 … 100) from the prewarmed catalog.
    static func generated(_ number: Int) throws -> AcousticConstellatorGenerated {
        let catalog: [AcousticConstellatorGenerated] = try regressionSolverCatalogResult.get()
        return catalog[number - 1]
    }

    /// A difference of `part` for `name` with the detail `detail`.
    static func difference(_ name: String, _ part: String,
                           _ detail: String = "") -> AcousticConstellatorRegressionDifference {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return AcousticConstellatorRegressionDifference(part: part, message: "\(name): \(part) differs\(suffix)")
    }

    /// The links and nudges of `actions`: every `.link` and every `.nudge` in order (the witness's plan part).
    static func planParts(_ actions: [AcousticConstellatorAction])
        -> (links: [AcousticConstellatorLink], nudges: [AcousticConstellatorNudge]) {
        var links: [AcousticConstellatorLink] = []
        var nudges: [AcousticConstellatorNudge] = []
        for action in actions {
            switch action {
            case .link(let a, let b): links.append(AcousticConstellatorLink(a: a, b: b))
            case .nudge(let star, let step): nudges.append(AcousticConstellatorNudge(star: star, step: step))
            case .unlink, .listen: break
            }
        }
        return (links, nudges)
    }

    /// The independent replay of `actions` on a fresh play of `level`, as the witness computes it: the fingerprint
    /// after `begin`, after `dismissTutorial` when the play shows a tutorial, and after each action (each applied with
    /// the current fingerprint), the state digest after each action; nil when a stage event or an action is refused.
    static func replayed(_ level: AcousticConstellatorLevel,
                         _ actions: [AcousticConstellatorAction]) -> AcousticConstellatorRegressionReplay? {
        var play: AcousticConstellatorPlay = AcousticConstellatorPlay(level: level)
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
                digests.append(AcousticConstellatorWitness.digest(links: play.links, phases: play.phases))
            }
        } catch {
            return nil
        }
        return AcousticConstellatorRegressionReplay(play: play, fingerprints: fingerprints, digests: digests,
                                                    endedEarly: endedEarly)
    }

    /// Every disagreement of `level` with its stored witness level, each naming the level and the part.
    static func levelDifferences(_ level: AcousticConstellatorLevel, stored: AcousticConstellatorLevel,
                                 name: String) -> [AcousticConstellatorRegressionDifference] {
        var found: [AcousticConstellatorRegressionDifference] = []
        if level.id != stored.id { found.append(difference(name, "id")) }
        if level.seed != stored.seed { found.append(difference(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(difference(name, "difficulty")) }
        if level.stars.count != stored.stars.count {
            found.append(difference(name, "star count", "\(level.stars.count), witness \(stored.stars.count)"))
        } else {
            for index in 0..<level.stars.count {
                let lhs: AcousticConstellatorStar = level.stars[index]
                let rhs: AcousticConstellatorStar = stored.stars[index]
                if lhs.x != rhs.x || lhs.y != rhs.y || lhs.z != rhs.z {
                    found.append(difference(name, "star position", "star \(index)"))
                }
                if lhs.rate != rhs.rate {
                    found.append(difference(name, "star rate", "star \(index): \(lhs.rate), witness \(rhs.rate)"))
                }
                if lhs.phase != rhs.phase {
                    found.append(difference(name, "star starting phase",
                                            "star \(index): \(lhs.phase), witness \(rhs.phase)"))
                }
            }
        }
        if level.fixedLinks != stored.fixedLinks {
            found.append(difference(name, "fixed link",
                                    "count \(level.fixedLinks.count), witness \(stored.fixedLinks.count)"))
        }
        if level.symbol != stored.symbol {
            found.append(difference(name, "symbol pair",
                                    "count \(level.symbol.count), witness \(stored.symbol.count)"))
        }
        if level.coupling != stored.coupling {
            found.append(difference(name, "coupling", "\(level.coupling), witness \(stored.coupling)"))
        }
        if level.degreeLimit != stored.degreeLimit { found.append(difference(name, "degree limit")) }
        if level.linkLimit != stored.linkLimit { found.append(difference(name, "link limit")) }
        if level.snapLimit != stored.snapLimit { found.append(difference(name, "snap limit")) }
        if level.threshold != stored.threshold {
            found.append(difference(name, "threshold", "\(level.threshold), witness \(stored.threshold)"))
        }
        if level.hold != stored.hold {
            found.append(difference(name, "hold", "\(level.hold), witness \(stored.hold)"))
        }
        if level.window != stored.window { found.append(difference(name, "window")) }
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
    /// digests and fingerprints, the recounted smaller sets equal the witness's counterexample and difficulty, and the
    /// plan's links, nudges, smaller sets and size equal the witness's with work at most
    /// `AcousticConstellatorSolver.workBound`. The level parts come first, so an altered level's first difference is
    /// its own part. A replay the play refuses is a named difference, never a crash. Pure.
    static func differences(level: AcousticConstellatorLevel, witness: AcousticConstellatorWitness,
                            plan: AcousticConstellatorPlan?) -> [AcousticConstellatorRegressionDifference] {
        let name: String = "level \(witness.number)"
        var found: [AcousticConstellatorRegressionDifference] = levelDifferences(level, stored: witness.level,
                                                                                 name: name)

        // The witness's actions replayed on a fresh play: a win on the last action and not before, within the budget.
        let parts: (links: [AcousticConstellatorLink], nudges: [AcousticConstellatorNudge]) =
            planParts(witness.actions)
        if let run: AcousticConstellatorRegressionReplay = replayed(level, witness.actions) {
            if run.endedEarly {
                found.append(difference(name, "witness action", "the play ends before the last action"))
            }
            if run.play.stage != .won {
                found.append(difference(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            if witness.actions.count != parts.links.count + parts.nudges.count + 1
                || witness.actions.last != .listen || parts.links.count + parts.nudges.count == 0 {
                found.append(difference(name, "witness action",
                                        "count \(witness.actions.count): \(parts.links.count) links + "
                                            + "\(parts.nudges.count) nudges + 1 listen"))
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

        // The counterexample: its size one below the plan, the smaller sets recounted (none winning).
        let required: Set<AcousticConstellatorLink> = Set(AcousticConstellatorSolver.missing(level))
        let extras: Int = parts.links.count - required.count + parts.nudges.count
        let size: Int = parts.links.count + parts.nudges.count - 1
        if witness.counterexample.size != size {
            found.append(difference(name, "smaller-sets size", "\(witness.counterexample.size), witness plan \(size)"))
        }
        if extras >= 0, required.isSubset(of: Set(parts.links)),
           let counts: [Int] = AcousticConstellatorWitness.smallerSets(level, extras: extras) {
            let sets: Int = extras == 0 ? 0 : counts[extras - 1]
            let reason: String = extras == 0 ? AcousticConstellatorCounterexample.missing
                : AcousticConstellatorCounterexample.tried
            if witness.counterexample.sets != sets {
                found.append(difference(name, "smaller-sets count", "\(witness.counterexample.sets), recount \(sets)"))
            }
            if witness.counterexample.reason != reason {
                found.append(difference(name, "counterexample reason", witness.counterexample.reason))
            }
            var total: Int = 0
            for count in counts { total += count }
            if witness.difficulty.smallerSets != total {
                found.append(difference(name, "smaller-sets total",
                                        "\(witness.difficulty.smallerSets), recount \(total)"))
            }
        } else {
            found.append(difference(name, "smaller-sets count",
                                    "a smaller set wins, a missing pair is unlinked or the recount passes the bound"))
        }

        // The solver: exactly the witness's links, nudges, smaller sets and size; work within the bound.
        guard let plan: AcousticConstellatorPlan = plan else {
            found.append(difference(name, "plan link or nudge", "the solver finds no plan"))
            return found
        }
        if plan.links != parts.links || plan.nudges != parts.nudges {
            found.append(difference(name, "plan link or nudge",
                                    "plan \(plan.links.count) links \(plan.nudges.count) nudges, witness "
                                        + "\(parts.links.count) links \(parts.nudges.count) nudges"))
        }
        if AcousticConstellatorSolver.actions(plan) != witness.actions {
            found.append(difference(name, "witness action", "not the plan's actions"))
        }
        if plan.smallerSets != witness.difficulty.smallerSets {
            found.append(difference(name, "smaller-sets total",
                                    "plan \(plan.smallerSets), witness \(witness.difficulty.smallerSets)"))
        }
        if plan.size - 1 != witness.counterexample.size {
            found.append(difference(name, "smaller-sets size", "plan \(plan.size - 1)"))
        }
        if plan.work > AcousticConstellatorSolver.workBound {
            found.append(difference(name, "solver work",
                                    "\(plan.work) exceeds \(AcousticConstellatorSolver.workBound)"))
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
        let generated: AcousticConstellatorGenerated = try generated(number)
        let witness: AcousticConstellatorWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(generated.level)
        let found: [AcousticConstellatorRegressionDifference] = differences(level: generated.level, witness: witness,
                                                                            plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.map(\.message).joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= AcousticConstellatorSolver.workBound,
                "level \(number): solver work above the bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1308-001; SC-R02G1308-001; Q1)

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

    // MARK: Alterations (FR-R02G1308-002; SC-R02G1308-002; clarification Q2)

    /// `level` rebuilt through the level initialiser with the given parts replaced.
    static func rebuilt(_ level: AcousticConstellatorLevel, stars: [AcousticConstellatorStar]? = nil,
                        fixedLinks: [AcousticConstellatorLink]? = nil, symbol: [AcousticConstellatorLink]? = nil,
                        coupling: Int? = nil, threshold: Int? = nil, hold: Int? = nil,
                        budget: Int? = nil) throws -> AcousticConstellatorLevel {
        try AcousticConstellatorLevel(id: level.id, seed: level.seed, difficulty: level.difficulty,
                                      stars: stars ?? level.stars, fixedLinks: fixedLinks ?? level.fixedLinks,
                                      symbol: symbol ?? level.symbol, coupling: coupling ?? level.coupling,
                                      degreeLimit: level.degreeLimit, linkLimit: level.linkLimit,
                                      snapLimit: level.snapLimit, threshold: threshold ?? level.threshold,
                                      hold: hold ?? level.hold, window: level.window, budget: budget ?? level.budget,
                                      tutorial: level.tutorial)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: AcousticConstellatorWitness, actions: [AcousticConstellatorAction]? = nil,
                        fingerprints: [String]? = nil,
                        counterexample: AcousticConstellatorCounterexample? = nil) -> AcousticConstellatorWitness {
        AcousticConstellatorWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                    digests: witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                                    counterexample: counterexample ?? witness.counterexample,
                                    difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// One less within `range`, or one more at its lower end (one less keeps the hold within the window).
    static func nudged(_ value: Int, within range: ClosedRange<Int>) -> Int {
        value > range.lowerBound ? value - 1 : value + 1
    }

    /// The star an alteration of `level` touches: seed 2_428 modulo the star count.
    static func alteredStar(_ level: AcousticConstellatorLevel) -> Int {
        Int(alterationSeed % UInt64(level.stars.count))
    }

    /// The stars with star `alteredStar(level)` passed through `change`.
    static func starsAltered(_ level: AcousticConstellatorLevel,
                             _ change: (AcousticConstellatorStar) -> AcousticConstellatorStar)
        -> [AcousticConstellatorStar] {
        var stars: [AcousticConstellatorStar] = level.stars
        let index: Int = alteredStar(level)
        stars[index] = change(stars[index])
        return stars
    }

    /// The first pair (in pair order) of `level`'s stars that is not in `taken`, or nil.
    static func freePair(_ level: AcousticConstellatorLevel,
                         excluding taken: [AcousticConstellatorLink]) -> AcousticConstellatorLink? {
        let n: Int = level.stars.count
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) {
                let link: AcousticConstellatorLink = AcousticConstellatorLink(a: a, b: b)
                if !taken.contains(link) { return link }
            }
        }
        return nil
    }

    /// The fixed links altered: the first fixed link moved to the first pair no fixed link or symbol pair holds, or,
    /// without fixed links, that pair added.
    static func fixedLinksAltered(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorLink] {
        var links: [AcousticConstellatorLink] = level.fixedLinks
        guard let pair: AcousticConstellatorLink = freePair(level, excluding: links + level.symbol) else {
            return links
        }
        if links.isEmpty { links.append(pair) } else { links[0] = pair }
        return links
    }

    /// The symbol altered: the first symbol pair replaced by the first pair outside the symbol for which the level
    /// rules accept the copy (the symbol stays joined), else by the first pair outside the symbol.
    static func symbolAltered(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorLink] {
        let n: Int = level.stars.count
        var fallback: [AcousticConstellatorLink]? = nil
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) {
                let link: AcousticConstellatorLink = AcousticConstellatorLink(a: a, b: b)
                if level.symbol.contains(link) { continue }
                var symbol: [AcousticConstellatorLink] = level.symbol
                symbol[0] = link
                if fallback == nil { fallback = symbol }
                if (try? rebuilt(level, symbol: symbol)) != nil { return symbol }
            }
        }
        return fallback ?? level.symbol
    }

    /// The level alteration of `part` checked against `witness`: the copy built by `build`, or a construction the level
    /// rules refuse, which is itself a difference naming `part`.
    static func levelAlterationDifferences(part: String, number: Int, witness: AcousticConstellatorWitness,
                                           plan: AcousticConstellatorPlan?,
                                           build: () throws -> AcousticConstellatorLevel)
        -> [AcousticConstellatorRegressionDifference] {
        let copy: AcousticConstellatorLevel
        do {
            copy = try build()
        } catch {
            return [difference("level \(number)", part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint {
            return [AcousticConstellatorRegressionDifference(part: "unchanged",
                                                             message: "level \(number): \(part) unchanged")]
        }
        return differences(level: copy, witness: witness, plan: plan)
    }

    /// Records an issue unless `found` is not empty, names `part` first in a message naming level `number` and the
    /// part, and every message names level `number`.
    static func expectNamed(_ found: [AcousticConstellatorRegressionDifference], number: Int, part: String) {
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
        let level: AcousticConstellatorLevel = try Self.generated(number).level
        let witness: AcousticConstellatorWitness = try Self.witness(number)
        let found: [AcousticConstellatorRegressionDifference] =
            Self.differences(level: level, witness: witness, plan: AcousticConstellatorSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.map(\.message).joined(separator: "; "))")
    }

    /// Level alterations: a star's position, a star's rate, a star's starting phase, a fixed link, a symbol pair, the
    /// coupling, the threshold, the hold and the budget, each rebuilt through the level initialiser and named first.
    /// The level is compared first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: AcousticConstellatorGenerated = try Self.generated(number)
        let level: AcousticConstellatorLevel = generated.level
        let witness: AcousticConstellatorWitness = try Self.witness(number)
        let plan: AcousticConstellatorPlan = generated.plan
        let coordinates: ClosedRange<Int> = AcousticConstellatorLevel.coordinates
        let builders: [(part: String, build: () throws -> AcousticConstellatorLevel)] = [
            ("star position", {
                try Self.rebuilt(level, stars: Self.starsAltered(level) { (star: AcousticConstellatorStar) in
                    AcousticConstellatorStar(x: Self.nudged(star.x, within: coordinates), y: star.y, z: star.z,
                                             rate: star.rate, phase: star.phase)
                })
            }),
            ("star rate", {
                try Self.rebuilt(level, stars: Self.starsAltered(level) { (star: AcousticConstellatorStar) in
                    AcousticConstellatorStar(x: star.x, y: star.y, z: star.z,
                                             rate: Self.nudged(star.rate, within: AcousticConstellatorLevel.rates),
                                             phase: star.phase)
                })
            }),
            ("star starting phase", {
                try Self.rebuilt(level, stars: Self.starsAltered(level) { (star: AcousticConstellatorStar) in
                    AcousticConstellatorStar(x: star.x, y: star.y, z: star.z, rate: star.rate,
                                             phase: Self.nudged(star.phase, within: AcousticConstellatorLevel.phases))
                })
            }),
            ("fixed link", { try Self.rebuilt(level, fixedLinks: Self.fixedLinksAltered(level)) }),
            ("symbol pair", { try Self.rebuilt(level, symbol: Self.symbolAltered(level)) }),
            ("coupling", {
                try Self.rebuilt(level, coupling: Self.nudged(level.coupling,
                                                              within: AcousticConstellatorLevel.couplings))
            }),
            ("threshold", {
                let n: Int = level.stars.count
                return try Self.rebuilt(level, threshold: Self.nudged(level.threshold, within: 1...(n * n)))
            }),
            ("hold", {
                try Self.rebuilt(level, hold: Self.nudged(level.hold, within: AcousticConstellatorLevel.holds))
            }),
            ("budget", {
                try Self.rebuilt(level, budget: Self.nudged(level.budget, within: AcousticConstellatorLevel.budgets))
            }),
        ]
        #expect(builders.count == 9)
        for builder in builders {
            let found: [AcousticConstellatorRegressionDifference] =
                Self.levelAlterationDifferences(part: builder.part, number: number, witness: witness, plan: plan,
                                                build: builder.build)
            Self.expectNamed(found, number: number, part: builder.part)
        }
    }

    /// A refused level construction is named too: a coupling one above the strongest allowed is refused by the level
    /// rules and reported as the coupling.
    @Test func aRefusedLevelConstructionIsNamed() throws {
        let number: Int = 41
        let generated: AcousticConstellatorGenerated = try Self.generated(number)
        let level: AcousticConstellatorLevel = generated.level
        let witness: AcousticConstellatorWitness = try Self.witness(number)
        let tooStrong: Int = AcousticConstellatorLevel.couplings.upperBound + 1
        let found: [AcousticConstellatorRegressionDifference] =
            Self.levelAlterationDifferences(part: "coupling", number: number, witness: witness,
                                            plan: generated.plan) {
                try Self.rebuilt(level, coupling: tooStrong)
            }
        Self.expectNamed(found, number: number, part: "coupling")
        #expect(found.first?.message.contains("refuse") == true, "level \(number): \(found.first?.message ?? "(none)")")
    }

    /// The plan alteration: the solver's first link moved to the first pair the plan, the fixed links and the symbol do
    /// not hold, or, for a plan without links, its first nudge reversed.
    @Test(arguments: alteredNumbers) func planLinkOrNudgeAlterationIsNamed(number: Int) throws {
        let level: AcousticConstellatorLevel = try Self.generated(number).level
        let witness: AcousticConstellatorWitness = try Self.witness(number)
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: AcousticConstellatorPlan = plan else { return }
        var links: [AcousticConstellatorLink] = plan.links
        var nudges: [AcousticConstellatorNudge] = plan.nudges
        if !links.isEmpty,
           let pair: AcousticConstellatorLink = Self.freePair(level,
                                                              excluding: links + level.fixedLinks + level.symbol) {
            links[0] = pair
            links.sort()
        } else if !nudges.isEmpty {
            nudges[0] = AcousticConstellatorNudge(star: nudges[0].star, step: -nudges[0].step)
        }
        let copy: AcousticConstellatorPlan = AcousticConstellatorPlan(links: links, nudges: nudges,
                                                                      smallerSets: plan.smallerSets, work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        Self.expectNamed(Self.differences(level: level, witness: witness, plan: copy), number: number,
                         part: "plan link or nudge")
    }

    /// Witness alterations: an action, a per-action fingerprint and the smaller-sets count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: AcousticConstellatorLevel = try Self.generated(number).level
        let witness: AcousticConstellatorWitness = try Self.witness(number)
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level)
        var parts: [String] = []
        var copies: [AcousticConstellatorWitness] = []

        // A witness action: the final listen replaced by the first action again, so the altered actions never win.
        var actions: [AcousticConstellatorAction] = witness.actions
        actions[actions.count - 1] = actions[0]
        #expect(!AcousticConstellatorSolver.wins(level, actions: actions), "level \(number): the altered actions win")
        parts.append("witness action")
        copies.append(Self.rebuilt(witness, actions: actions))

        // A per-action fingerprint: the middle fingerprint with its first character changed.
        var fingerprints: [String] = witness.fingerprints
        let index: Int = fingerprints.count / 2
        fingerprints[index] = Self.flipped(fingerprints[index])
        parts.append("per-action fingerprint")
        copies.append(Self.rebuilt(witness, fingerprints: fingerprints))

        // The smaller-sets count: the counterexample's sets one more.
        let counterexample: AcousticConstellatorCounterexample =
            AcousticConstellatorCounterexample(size: witness.counterexample.size,
                                               sets: witness.counterexample.sets + 1,
                                               reason: witness.counterexample.reason)
        parts.append("smaller-sets count")
        copies.append(Self.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 3)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: AcousticConstellatorWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            Self.expectNamed(Self.differences(level: level, witness: copy, plan: plan), number: number, part: part)
        }
    }
}
