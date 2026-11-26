// MicroscopicAuroraRegressionSolverTests — feature 488 (R02-G19-08) T-R02G1908-002 (FR-R02G1908-001, 002;
// SC-R02G1908-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1: certifying one level judges at most 1,200 well sets, so each test stays
// well under 10 s): the generated level equals the level of its witness file in docs/games/microscopic-aurora/levels
// (part by part and by fingerprint); the witness's actions (the placements, then `play`) replay on a fresh play (begun,
// the tutorial dismissed) to a win on exactly the final play and not before (no proper prefix of the placements
// followed by `play` wins), within the budget, with exactly its per-action fingerprints (after `begin`, after
// `dismissTutorial` on a tutorial level, then one per action), state digests
// (`MicroscopicAuroraWitness.digest(wells:spent:)` after each action) and terminal report;
// `MicroscopicAuroraSolver.plan` returns exactly the witness's placements with `setsByDepth[size − 1]` equal to the
// counterexample's `sets` and `nearestMiss` equal to its `nearestMiss`, and its work is at most
// `MicroscopicAuroraSolver.workBound` (counted, never timed) and equal to the witness difficulty's. The regression
// builds each level as the experience core does (the manifest entry's certified candidate) and runs the solver on it
// once, so a group of 10 stays under 10 s in a debug build; the alterations take their levels from the experience
// core's per-process cache. Witness files are read with the plain decoder (the level re-checked by its own rules; the
// solver is not re-run by the decode, which the regression does itself).
//
// The alterations (clarification Q2): the twelve kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `MicroscopicAuroraRegressionSolverCheck.failures`,
// which returns every failure as a string naming the level and the part ("level 41: site differs (site 2: …)"): a
// swimmer's position, a swimmer's velocity, a stencil cell, a site, the threshold, the coverage requirement, the
// coherence requirement, the budget (each rebuilt through the level initialiser, the first copy the level rules accept
// and whose fingerprint changes; a refused construction is itself a failure naming the part); a plan placement; a
// witness action (one the play does not win with); a per-action fingerprint or digest (both are altered and named);
// the counterexample's sets count. The honest input gives no failure. The altered swimmer, cell and site are chosen
// from seed 2_488 (no random source). Explicit types, plain loops, short runs. Modelled on
// ApsidesWorkshopRegressionSolverTests (feature 478).
import Foundation
@testable import MicroscopicAuroraCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum MicroscopicAuroraRegressionSolverCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

    /// The seed that fixes which swimmer, stencil cell and site an alteration touches first.
    static let alterationSeed: UInt64 = 2_488

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> MicroscopicAuroraWitness {
        let name: String = String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data)
    }

    /// The failure string of `part` for `name`: "level N: <part> differs (detail)".
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> String {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return "\(name): \(part) differs\(suffix)"
    }

    /// The index of the first entry where `lhs` and `rhs` differ (the shorter count when one is a prefix).
    static func firstDifference<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        var index: Int = 0
        while index < min(lhs.count, rhs.count), lhs[index] == rhs[index] { index += 1 }
        return index
    }

    /// A point in words: "(2944, 3200)".
    static func pointText(_ point: MicroscopicAuroraPoint) -> String { "(\(point.x), \(point.y))" }

    /// A cell in words: "row 7, column 12".
    static func cellText(_ cell: MicroscopicAuroraCell) -> String { MicroscopicAuroraLevel.cellWords(cell) }

    /// Every disagreement of `swimmers` with the stored swimmers: the count, then per swimmer its position and
    /// velocity.
    static func swimmerFailures(_ swimmers: [MicroscopicAuroraSwimmer], stored: [MicroscopicAuroraSwimmer],
                                name: String) -> [String] {
        var found: [String] = []
        if swimmers.count != stored.count {
            found.append(failure(name, "swimmer count", "\(swimmers.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<swimmers.count {
            let lhs: MicroscopicAuroraSwimmer = swimmers[index]
            let rhs: MicroscopicAuroraSwimmer = stored[index]
            if lhs.position != rhs.position {
                found.append(failure(name, "swimmer position", "swimmer \(index): \(pointText(lhs.position)), "
                                        + "witness \(pointText(rhs.position))"))
            }
            if lhs.velocity != rhs.velocity {
                found.append(failure(name, "swimmer velocity", "swimmer \(index): \(pointText(lhs.velocity)), "
                                        + "witness \(pointText(rhs.velocity))"))
            }
        }
        return found
    }

    /// Every disagreement of the cell list `cells` with `stored`, named `part` per cell and `countPart` for the count.
    static func cellFailures(_ cells: [MicroscopicAuroraCell], stored: [MicroscopicAuroraCell], part: String,
                             countPart: String, item: String, name: String) -> [String] {
        var found: [String] = []
        if cells.count != stored.count {
            found.append(failure(name, countPart, "\(cells.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<cells.count where cells[index] != stored[index] {
            found.append(failure(name, part, "\(item) \(index): \(cellText(cells[index])), witness "
                                    + cellText(stored[index])))
        }
        return found
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (the id, seed,
    /// difficulty, radius, length and rules, then the swimmers, the stencil, the threshold, the coverage and coherence
    /// requirements, the starting wells, the budget, the sites, the tutorial and the fingerprint).
    static func levelFailures(_ level: MicroscopicAuroraLevel, stored: MicroscopicAuroraLevel,
                              name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        if level.radius != stored.radius {
            found.append(failure(name, "radius", "\(level.radius), witness \(stored.radius)"))
        }
        if level.length != stored.length {
            found.append(failure(name, "length", "\(level.length), witness \(stored.length)"))
        }
        if level.rules != stored.rules { found.append(failure(name, "swarm rules")) }
        found += swimmerFailures(level.swimmers, stored: stored.swimmers, name: name)
        found += cellFailures(level.stencil, stored: stored.stencil, part: "stencil cell", countPart: "stencil count",
                              item: "cell", name: name)
        if level.threshold != stored.threshold {
            found.append(failure(name, "threshold", "\(level.threshold), witness \(stored.threshold)"))
        }
        if level.coverage != stored.coverage {
            found.append(failure(name, "coverage requirement", "\(level.coverage), witness \(stored.coverage)"))
        }
        if level.coherence != stored.coherence {
            found.append(failure(name, "coherence requirement", "\(level.coherence), witness \(stored.coherence)"))
        }
        if level.wells != stored.wells { found.append(failure(name, "starting wells")) }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        let storedSites: [MicroscopicAuroraCell] = stored.sites ?? []
        if (level.sites == nil) != (stored.sites == nil) { found.append(failure(name, "site count", "sites missing")) }
        found += cellFailures(sites, stored: storedSites, part: "site", countPart: "site count", item: "site",
                              name: name)
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The placements of `actions` (every action but a final `play`).
    static func placements(_ actions: [MicroscopicAuroraAction]) -> [MicroscopicAuroraAction] {
        actions.last == .play ? Array(actions.dropLast()) : actions
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on exactly the final play and not before within the budget with exactly its per-action
    /// fingerprints, digests and report, and the plan's placements are the witness's with `setsByDepth[size − 1]` the
    /// counterexample's sets, `nearestMiss` the counterexample's nearest miss and work at most
    /// `MicroscopicAuroraSolver.workBound` and equal to the witness difficulty's. The level parts come first, then the
    /// witness's actions, digests and fingerprints, then the counterexample and the plan, so an altered part is the
    /// first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: MicroscopicAuroraLevel, witness: MicroscopicAuroraWitness,
                         plan: MicroscopicAuroraPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)
        let witnessPlacements: [MicroscopicAuroraAction] = placements(witness.actions)

        // The witness's actions: at least one placement into a slot on a site with a strength in range, then exactly
        // one play last.
        if witness.actions.count < 2 { found.append(failure(name, "witness action", "\(witness.actions.count)")) }
        if witness.actions.last != .play {
            found.append(failure(name, "witness action", "the last is not the play"))
        }
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        for index in 0..<witnessPlacements.count {
            switch witnessPlacements[index] {
            case .place(let slot, let well):
                if !(0..<MicroscopicAuroraLevel.slots).contains(slot)
                    || !MicroscopicAuroraWell.strengths.contains(well.strength) || !sites.contains(well.cell) {
                    found.append(failure(name, "witness action", "action \(index): slot \(slot), "
                                            + "\(cellText(well.cell)), strength \(well.strength)"))
                }
            case .remove(let slot):
                found.append(failure(name, "witness action", "action \(index): remove slot \(slot)"))
            case .play:
                found.append(failure(name, "witness action", "action \(index): a play before the final action"))
            }
        }

        // Not before: no proper prefix of the placements followed by the play wins.
        if !witnessPlacements.isEmpty {
            for count in 0..<witnessPlacements.count {
                let prefix: [MicroscopicAuroraAction] = Array(witnessPlacements.prefix(count)) + [.play]
                if let early = MicroscopicAuroraWitness.replay(level, actions: prefix), early.play.stage == .won {
                    found.append(failure(name, "witness action", "the play wins after \(count) placements"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the final play, within the budget.
        if let run = MicroscopicAuroraWitness.replay(level, actions: witness.actions) {
            if run.play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            let spent: Int = run.play.actionsSpent
            if spent != witnessPlacements.count || spent > level.budget {
                found.append(failure(name, "budget", "spent \(spent) of \(level.budget)"))
            }
            if run.digests != witness.digests {
                found.append(failure(name, "per-action digest",
                                     "digest \(firstDifference(run.digests, witness.digests) + 1)"))
            }
            if run.fingerprints != witness.fingerprints {
                found.append(failure(name, "per-action fingerprint",
                                     "fingerprint \(firstDifference(run.fingerprints, witness.fingerprints) + 1)"))
            }
            if run.play.stage == .won {
                let report: MicroscopicAuroraWitnessReport = MicroscopicAuroraWitnessReport(run.play.report)
                if report != witness.report {
                    found.append(failure(name, "report", "coverage \(report.coverage), witness "
                                            + "\(witness.report.coverage)"))
                }
            }
        } else {
            found.append(failure(name, "witness action", "replay refused"))
        }

        // The counterexample: one placement below the witness's plan.
        if witness.counterexample.depth != witnessPlacements.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness placements \(witnessPlacements.count)"))
        }

        // The solver: exactly the witness's placements, the counterexample's sets and nearest miss, work within the
        // bound.
        guard let plan: MicroscopicAuroraPlan = plan else {
            found.append(failure(name, "plan placement", "the solver finds no plan"))
            return found
        }
        if plan.actions != witnessPlacements {
            let placement: Int = firstDifference(plan.actions, witnessPlacements) + 1
            found.append(failure(name, "plan placement", "placement \(placement) of \(plan.size), "
                                    + "witness \(witnessPlacements.count)"))
        }
        if plan.size < 1 || plan.setsByDepth.count != plan.size {
            found.append(failure(name, "plan sets by depth", "\(plan.setsByDepth.count) depths, size \(plan.size)"))
        } else if plan.setsByDepth[plan.size - 1] != witness.counterexample.sets {
            found.append(failure(name, "counterexample sets count",
                                 "\(witness.counterexample.sets), plan \(plan.setsByDepth[plan.size - 1])"))
        }
        if plan.size - 1 != witness.counterexample.depth {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), plan \(plan.size - 1)"))
        }
        if plan.nearestMiss != witness.counterexample.nearestMiss {
            found.append(failure(name, "counterexample nearest miss",
                                 "\(witness.counterexample.nearestMiss), plan \(plan.nearestMiss)"))
        }
        var setsSearched: Int = 0
        for count in plan.setsByDepth { setsSearched += count }
        if setsSearched != witness.difficulty.setsSearched {
            found.append(failure(name, "sets searched",
                                 "plan \(setsSearched), witness \(witness.difficulty.setsSearched)"))
        }
        if plan.work > MicroscopicAuroraSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(MicroscopicAuroraSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    // MARK: Alteration builders

    /// The editable parts of a level, rebuilt through the level initialiser by ``build()``.
    struct LevelParts {
        /// The level the parts came from (id, seed, difficulty, radius, length, rules, wells and tutorial are kept).
        let source: MicroscopicAuroraLevel
        /// The swimmers.
        var swimmers: [MicroscopicAuroraSwimmer]
        /// The stencil.
        var stencil: [MicroscopicAuroraCell]
        /// The threshold.
        var threshold: Int
        /// The required coverage.
        var coverage: Int
        /// The required coherence.
        var coherence: Int
        /// The budget.
        var budget: Int
        /// The sites.
        var sites: [MicroscopicAuroraCell]?

        /// The parts of `level`, unchanged.
        init(_ level: MicroscopicAuroraLevel) {
            source = level
            swimmers = level.swimmers
            stencil = level.stencil
            threshold = level.threshold
            coverage = level.coverage
            coherence = level.coherence
            budget = level.budget
            sites = level.sites
        }

        /// The level of these parts, checked by the level rules (the "already won" rule included).
        func build() throws -> MicroscopicAuroraLevel {
            try MicroscopicAuroraLevel(id: source.id, seed: source.seed, difficulty: source.difficulty,
                                       radius: source.radius, length: source.length, rules: source.rules,
                                       swimmers: swimmers, stencil: stencil, threshold: threshold,
                                       coverage: coverage, coherence: coherence, wells: source.wells, budget: budget,
                                       tutorial: source.tutorial, sites: sites)
        }
    }

    /// The indices 0 ..< `count` in the order alterations try them: from seed mod count, around.
    static func order(_ count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let start: Int = Int(alterationSeed % UInt64(count))
        var indices: [Int] = []
        for offset in 0..<count { indices.append((start + offset) % count) }
        return indices
    }

    /// The four unit steps, in order: +x, −x, +y, −y.
    static let steps: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    /// The first of `candidates` the level rules accept with a changed fingerprint; when none is, the first candidate
    /// rebuilt (so the refusal is reported); with no candidate, `level` itself (reported as unchanged).
    static func firstAccepted(_ level: MicroscopicAuroraLevel, _ candidates: [LevelParts]) throws
        -> MicroscopicAuroraLevel {
        for parts in candidates {
            if let copy: MicroscopicAuroraLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A swimmer's position altered: moved one dish unit along x or y.
    static func positionAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for index in order(level.swimmers.count) {
            let old: MicroscopicAuroraSwimmer = level.swimmers[index]
            for (dx, dy) in steps {
                var parts: LevelParts = LevelParts(level)
                let position: MicroscopicAuroraPoint = MicroscopicAuroraPoint(x: old.position.x + dx,
                                                                              y: old.position.y + dy)
                parts.swimmers[index] = MicroscopicAuroraSwimmer(position: position, velocity: old.velocity)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A swimmer's velocity altered: one dish unit per tick more or less along x or y (a speed above the bound is
    /// refused by the rules, so the next is tried).
    static func velocityAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for index in order(level.swimmers.count) {
            let old: MicroscopicAuroraSwimmer = level.swimmers[index]
            for (dx, dy) in steps {
                var parts: LevelParts = LevelParts(level)
                let velocity: MicroscopicAuroraPoint = MicroscopicAuroraPoint(x: old.velocity.x + dx,
                                                                              y: old.velocity.y + dy)
                parts.swimmers[index] = MicroscopicAuroraSwimmer(position: old.position, velocity: velocity)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The four-neighbour cells of `cell` that are not in `taken`, in step order (unusable cells are refused by the
    /// rules, so the next is tried).
    static func neighbours(_ cell: MicroscopicAuroraCell, excluding taken: [MicroscopicAuroraCell])
        -> [MicroscopicAuroraCell] {
        var result: [MicroscopicAuroraCell] = []
        for (dc, dr) in steps {
            let next: MicroscopicAuroraCell = MicroscopicAuroraCell(row: cell.row + dr, column: cell.column + dc)
            if !taken.contains(next) { result.append(next) }
        }
        return result
    }

    /// A stencil cell altered: moved to a four-neighbour cell outside the stencil.
    static func stencilAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for index in order(level.stencil.count) {
            for cell in neighbours(level.stencil[index], excluding: level.stencil) {
                var parts: LevelParts = LevelParts(level)
                parts.stencil[index] = cell
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A site altered: moved to a four-neighbour cell that is not a site.
    static func siteAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        var candidates: [LevelParts] = []
        for index in order(sites.count) {
            for cell in neighbours(sites[index], excluding: sites) {
                var parts: LevelParts = LevelParts(level)
                var moved: [MicroscopicAuroraCell] = sites
                moved[index] = cell
                parts.sites = moved
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The threshold altered: one more, else one less.
    static func thresholdAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for threshold in [level.threshold + 1, level.threshold - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.threshold = threshold
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The coverage requirement altered: one tenth of a percent more, else less.
    static func coverageAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for coverage in [level.coverage + 1, level.coverage - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.coverage = coverage
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The coherence requirement altered: one less, else one more (a requirement above the start's coherence is
    /// refused by the rules).
    static func coherenceAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var candidates: [LevelParts] = []
        for coherence in [level.coherence - 1, level.coherence + 1] {
            var parts: LevelParts = LevelParts(level)
            parts.coherence = coherence
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = MicroscopicAuroraLevel.budgets.lowerBound
        parts.budget = level.budget > lower ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: MicroscopicAuroraLevel, part: String) throws -> MicroscopicAuroraLevel {
        switch part {
        case "swimmer position": return try positionAltered(level)
        case "swimmer velocity": return try velocityAltered(level)
        case "stencil cell": return try stencilAltered(level)
        case "site": return try siteAltered(level)
        case "threshold": return try thresholdAltered(level)
        case "coverage requirement": return try coverageAltered(level)
        case "coherence requirement": return try coherenceAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The eight level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["swimmer position", "swimmer velocity", "stencil cell", "site", "threshold",
                                       "coverage requirement", "coherence requirement", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: MicroscopicAuroraWitness,
                                        plan: MicroscopicAuroraPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: MicroscopicAuroraLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: MicroscopicAuroraWitness, actions: [MicroscopicAuroraAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: MicroscopicAuroraCounterexample? = nil) -> MicroscopicAuroraWitness {
        MicroscopicAuroraWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                 digests: digests ?? witness.digests,
                                 fingerprints: fingerprints ?? witness.fingerprints, report: witness.report,
                                 counterexample: counterexample ?? witness.counterexample,
                                 difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The witness actions with the last placement altered so the play no longer wins with them: the same slot with
    /// another well on a site no earlier placement uses (sites from seed order, then strength, then sense), the play
    /// kept last. Nil when every such change still wins.
    static func actionAltered(_ level: MicroscopicAuroraLevel,
                              _ actions: [MicroscopicAuroraAction]) -> [MicroscopicAuroraAction]? {
        let witnessPlacements: [MicroscopicAuroraAction] = placements(actions)
        guard let last: MicroscopicAuroraAction = witnessPlacements.last,
              case .place(let slot, let well) = last else { return nil }
        var used: [MicroscopicAuroraCell] = []
        for index in 0..<(witnessPlacements.count - 1) {
            if case .place(_, let earlier) = witnessPlacements[index] { used.append(earlier.cell) }
        }
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        var candidates: [MicroscopicAuroraAction] = []
        for index in order(sites.count) where !used.contains(sites[index]) {
            for strength in MicroscopicAuroraWell.strengths {
                for sense in MicroscopicAuroraSense.allCases {
                    let next: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: sites[index], strength: strength,
                                                                            sense: sense)
                    if next != well { candidates.append(.place(slot: slot, well: next)) }
                }
            }
        }
        for candidate in candidates {
            var altered: [MicroscopicAuroraAction] = witnessPlacements
            altered[altered.count - 1] = candidate
            if !MicroscopicAuroraSolver.replayWins(level, actions: altered) { return altered + [.play] }
        }
        return nil
    }

    /// The plan with its first placement's well changed: the strength one step around 1 … 4, the slot, cell and sense
    /// kept.
    static func planAltered(_ plan: MicroscopicAuroraPlan) -> MicroscopicAuroraPlan? {
        guard !plan.actions.isEmpty, case .place(let slot, let well) = plan.actions[0] else { return nil }
        var actions: [MicroscopicAuroraAction] = plan.actions
        let strength: Int = well.strength % MicroscopicAuroraWell.strengths.upperBound + 1
        actions[0] = .place(slot: slot, well: MicroscopicAuroraWell(cell: well.cell, strength: strength,
                                                                    sense: well.sense))
        return MicroscopicAuroraPlan(actions: actions, wells: plan.wells, setsByDepth: plan.setsByDepth,
                                     nearestMiss: plan.nearestMiss, work: plan.work)
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

    /// Checks level `number`: the generated level (the manifest entry's certified candidate, built as
    /// `MicroscopicAuroraExperienceCore.generated(number:)` builds it) equals the witness's, the solver, run once on
    /// it, matches the witness with the band's plan length and the checker finds no failure. The solver runs once per
    /// level (the experience core's certification would run it a second time), so a group of 10 stays under 10 s.
    static func check(number: Int) throws {
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
        let index: Int = MicroscopicAuroraExperienceCore.certifiedCandidates[number - 1]
        let witness: MicroscopicAuroraWitness = try witness(number)
        #expect(entry.number == number, "level \(number): manifest entry \(entry.number)")
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(index == witness.skipped,
                "level \(number): certified candidate \(index), witness \(witness.skipped)")
        let candidate: MicroscopicAuroraLevel? = MicroscopicAuroraGenerator.candidate(entry, index: index)
        #expect(candidate != nil, "level \(number): no candidate \(index)")
        guard let level: MicroscopicAuroraLevel = candidate else { return }
        #expect(level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: MicroscopicAuroraPlan? = MicroscopicAuroraSolver.plan(level)
        let found: [String] = failures(level: level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect((plan?.work ?? Int.max) <= MicroscopicAuroraSolver.workBound,
                "level \(number): solver work above bound")
        guard let plan: MicroscopicAuroraPlan = plan else { return }
        let length: Int = MicroscopicAuroraBandProfile.of(band: entry.band).plan
        #expect(plan.size == length, "level \(number): plan size \(plan.size), band length \(length)")
        #expect(MicroscopicAuroraDifficulty(level: level, plan: plan) == witness.difficulty,
                "level \(number): difficulty differs")
    }
}

@Suite struct MicroscopicAuroraRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try MicroscopicAuroraRegressionSolverCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1908-001; SC-R02G1908-001; Q1)

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

    // MARK: Alterations (FR-R02G1908-002; SC-R02G1908-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraExperienceCore.generated(number: number).level
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraRegressionSolverCheck.witness(number)
        let found: [String] = MicroscopicAuroraRegressionSolverCheck.failures(
            level: level, witness: witness, plan: MicroscopicAuroraSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a swimmer's position, a swimmer's velocity, a stencil cell, a site, the threshold, the
    /// coverage requirement, the coherence requirement and the budget, each rebuilt through the level initialiser and
    /// named first. The level is compared first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: MicroscopicAuroraGenerated = try MicroscopicAuroraExperienceCore.generated(number: number)
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraRegressionSolverCheck.witness(number)
        #expect(!(witness.level.sites ?? []).isEmpty, "level \(number): no site to alter")
        var checked: Int = 0
        for part in MicroscopicAuroraRegressionSolverCheck.levelParts {
            let found: [String] = MicroscopicAuroraRegressionSolverCheck.levelAlterationFailures(
                part: part, witness: witness, plan: generated.plan)
            MicroscopicAuroraRegressionSolverCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
            checked += 1
        }
        #expect(checked == 8, "level \(number): \(checked) level alterations, expected 8")
    }

    /// The plan alteration: the solver's plan with its first placement's strength moved one step.
    @Test(arguments: alteredNumbers) func planPlacementAlterationIsNamed(number: Int) throws {
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraExperienceCore.generated(number: number).level
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraRegressionSolverCheck.witness(number)
        let plan: MicroscopicAuroraPlan? = MicroscopicAuroraSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: MicroscopicAuroraPlan = plan else { return }
        let copy: MicroscopicAuroraPlan? = MicroscopicAuroraRegressionSolverCheck.planAltered(plan)
        #expect(copy != nil, "level \(number): the plan has no placement to alter")
        guard let copy: MicroscopicAuroraPlan = copy else { return }
        #expect(copy != plan, "level \(number): plan unchanged")
        let found: [String] = MicroscopicAuroraRegressionSolverCheck.failures(level: level, witness: witness,
                                                                              plan: copy)
        MicroscopicAuroraRegressionSolverCheck.expectNamed(found, number: number, part: "plan placement")
    }

    /// Witness alterations: an action the play does not win with, a per-action fingerprint, a per-action digest and
    /// the counterexample's sets count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: MicroscopicAuroraLevel = try MicroscopicAuroraExperienceCore.generated(number: number).level
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraRegressionSolverCheck.witness(number)
        let plan: MicroscopicAuroraPlan? = MicroscopicAuroraSolver.plan(level)
        var parts: [String] = []
        var copies: [MicroscopicAuroraWitness] = []

        let actions: [MicroscopicAuroraAction]? = MicroscopicAuroraRegressionSolverCheck.actionAltered(
            level, witness.actions)
        #expect(actions != nil, "level \(number): every altered last placement still wins")
        if let actions: [MicroscopicAuroraAction] = actions {
            parts.append("witness action")
            copies.append(MicroscopicAuroraRegressionSolverCheck.rebuilt(witness, actions: actions))
        }

        var fingerprints: [String] = witness.fingerprints
        let fingerprintIndex: Int = fingerprints.count / 2
        fingerprints[fingerprintIndex] = MicroscopicAuroraRegressionSolverCheck.flipped(fingerprints[fingerprintIndex])
        parts.append("per-action fingerprint")
        copies.append(MicroscopicAuroraRegressionSolverCheck.rebuilt(witness, fingerprints: fingerprints))

        var digests: [String] = witness.digests
        let digestIndex: Int = digests.count / 2
        digests[digestIndex] = MicroscopicAuroraRegressionSolverCheck.flipped(digests[digestIndex])
        parts.append("per-action digest")
        copies.append(MicroscopicAuroraRegressionSolverCheck.rebuilt(witness, digests: digests))

        let counterexample: MicroscopicAuroraCounterexample = MicroscopicAuroraCounterexample(
            depth: witness.counterexample.depth, sets: witness.counterexample.sets + 1,
            nearestMiss: witness.counterexample.nearestMiss)
        parts.append("counterexample sets count")
        copies.append(MicroscopicAuroraRegressionSolverCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: MicroscopicAuroraWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            let found: [String] = MicroscopicAuroraRegressionSolverCheck.failures(level: level, witness: copy,
                                                                                  plan: plan)
            MicroscopicAuroraRegressionSolverCheck.expectNamed(found, number: number, part: part)
        }
    }
}
