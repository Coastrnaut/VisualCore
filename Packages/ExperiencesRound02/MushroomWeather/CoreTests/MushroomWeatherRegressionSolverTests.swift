// MushroomWeatherRegressionSolverTests — feature 498 (R02-G20-08) T-R02G2008-002 (FR-R02G2008-001, 002;
// SC-R02G2008-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1: certifying one level judges at most 1,500 arrangements, so each test stays
// well under 10 s): the generated level equals the level of its witness file in docs/games/mushroom-weather/levels
// (part by part and by fingerprint); the witness's actions (the pods, vents and moonlight, then `run`) replay on a fresh
// play (begun, the tutorial dismissed) to a win on exactly the final run and not before (no proper prefix of the
// arrangement actions followed by `run` wins), within the budget, with exactly its per-action fingerprints (after
// `begin`, after `dismissTutorial` on a tutorial level, then one per action), state digests
// (`MushroomWeatherWitness.digest(arrangement:spent:)` after each action) and terminal report;
// `MushroomWeatherSolver.plan` returns exactly the witness's arrangement actions with `arrangementsByDepth[size − 1]`
// equal to the counterexample's `arrangements` and `nearestMiss` equal to its `nearestMiss`, and its work is at most
// `MushroomWeatherSolver.workBound` (counted, never timed) and equal to the witness difficulty's. The regression builds
// each level as the experience core does (the manifest entry's certified candidate) and runs the solver on it once, so
// a group of 10 stays under 10 s in a debug build; the alterations take their plans from the experience core's
// per-process cache. Witness files are read with the plain decoder (the level re-checked by its own rules; the solver
// is not re-run by the decode, which the regression does itself).
//
// The alterations (clarification Q2): the twelve kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `MushroomWeatherRegressionSolverCheck.failures`, which
// returns every failure as a string naming the level and the part ("level 41: colony band differs (colony 2: …)"): a
// colony's band, a colony's survival floor, a cell's starting humidity, the diffusion, a vent's rate, the pod release,
// the growth threshold, the mold bound, the budget (each rebuilt through the level initialiser, the first copy the level
// rules accept and whose fingerprint changes; a refused construction is itself a failure naming the part); a plan
// action; a witness action (one the run does not win with); a per-action fingerprint or digest (both are altered and
// named); the counterexample's arrangements count. The honest input gives no failure. The altered colony, cell and vent
// are chosen from seed 2_498 (no random source). Explicit types, plain loops, short runs. Modelled on
// MicroscopicAuroraRegressionSolverTests (feature 488).
import Foundation
@testable import MushroomWeatherCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum MushroomWeatherRegressionSolverCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, MushroomWeather, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)

    /// The seed that fixes which colony, cell and vent an alteration touches first.
    static let alterationSeed: UInt64 = 2_498

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> MushroomWeatherWitness {
        let name: String = String(MushroomWeatherGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(MushroomWeatherWitness.self, from: data)
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

    /// A cell in words: "row 3, column 7".
    static func cellText(_ cell: MushroomWeatherCell) -> String { MushroomWeatherLevel.cellWords(cell) }

    /// A survival floor in words: the value or "none".
    static func floorText(_ floor: Int?) -> String { floor.map { String($0) } ?? "none" }

    /// Every disagreement of `colonies` with the stored colonies: the count, then per colony its cell, band and
    /// survival floor.
    static func colonyFailures(_ colonies: [MushroomWeatherColony], stored: [MushroomWeatherColony],
                               name: String) -> [String] {
        var found: [String] = []
        if colonies.count != stored.count {
            found.append(failure(name, "colony count", "\(colonies.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<colonies.count {
            let lhs: MushroomWeatherColony = colonies[index]
            let rhs: MushroomWeatherColony = stored[index]
            if lhs.cell != rhs.cell {
                found.append(failure(name, "colony cell", "colony \(index + 1): \(cellText(lhs.cell)), witness "
                                        + cellText(rhs.cell)))
            }
            if lhs.low != rhs.low || lhs.high != rhs.high {
                found.append(failure(name, "colony band", "colony \(index + 1): \(lhs.low) … \(lhs.high), witness "
                                        + "\(rhs.low) … \(rhs.high)"))
            }
            if lhs.survivalFloor != rhs.survivalFloor {
                found.append(failure(name, "survival floor", "colony \(index + 1): \(floorText(lhs.survivalFloor)), "
                                        + "witness \(floorText(rhs.survivalFloor))"))
            }
        }
        return found
    }

    /// Every disagreement of `vents` with the stored vents: the count, then per vent its cell and rates.
    static func ventFailures(_ vents: [MushroomWeatherVent], stored: [MushroomWeatherVent], name: String) -> [String] {
        var found: [String] = []
        if vents.count != stored.count {
            found.append(failure(name, "vent count", "\(vents.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<vents.count {
            let lhs: MushroomWeatherVent = vents[index]
            let rhs: MushroomWeatherVent = stored[index]
            if lhs.cell != rhs.cell {
                found.append(failure(name, "vent cell", "vent \(index + 1): \(cellText(lhs.cell)), witness "
                                        + cellText(rhs.cell)))
            }
            if lhs.openRate != rhs.openRate || lhs.closedRate != rhs.closedRate {
                found.append(failure(name, "vent rate", "vent \(index + 1): open \(lhs.openRate), closed "
                                        + "\(lhs.closedRate), witness open \(rhs.openRate), closed \(rhs.closedRate)"))
            }
        }
        return found
    }

    /// Every disagreement of `rules` with the stored pod rules: slots, release, grown release, growth threshold.
    static func podFailures(_ rules: MushroomWeatherPodRules, stored: MushroomWeatherPodRules,
                            name: String) -> [String] {
        var found: [String] = []
        if rules.slots != stored.slots {
            found.append(failure(name, "pod slots", "\(rules.slots), witness \(stored.slots)"))
        }
        if rules.release != stored.release {
            found.append(failure(name, "pod release", "\(rules.release), witness \(stored.release)"))
        }
        if rules.grownRelease != stored.grownRelease {
            found.append(failure(name, "grown release", "\(rules.grownRelease), witness \(stored.grownRelease)"))
        }
        if rules.growthThreshold != stored.growthThreshold {
            found.append(failure(name, "growth threshold",
                                 "\(rules.growthThreshold), witness \(stored.growthThreshold)"))
        }
        return found
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (the id, seed,
    /// difficulty, rows, columns and blocked cells, then the starting humidity, the diffusion, the evaporation rates,
    /// the vents, the pod rules, the colonies, the mold bound, the length, the required cycles, the start, the budget,
    /// the sites, the tutorial and the fingerprint).
    static func levelFailures(_ level: MushroomWeatherLevel, stored: MushroomWeatherLevel, name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        if level.rows != stored.rows || level.columns != stored.columns {
            found.append(failure(name, "floor size", "\(level.rows) × \(level.columns), witness "
                                    + "\(stored.rows) × \(stored.columns)"))
        }
        if level.blocked != stored.blocked { found.append(failure(name, "blocked cells")) }
        if level.humidity != stored.humidity {
            let index: Int = firstDifference(level.humidity, stored.humidity)
            let detail: String = index < min(level.humidity.count, stored.humidity.count)
                ? "\(cellText(level.cell(at: index))): \(level.humidity[index]), witness \(stored.humidity[index])"
                : "\(level.humidity.count) cells, witness \(stored.humidity.count)"
            found.append(failure(name, "starting humidity", detail))
        }
        if level.diffusion != stored.diffusion {
            found.append(failure(name, "diffusion", "\(level.diffusion), witness \(stored.diffusion)"))
        }
        if level.rates != stored.rates { found.append(failure(name, "evaporation rate")) }
        found += ventFailures(level.vents, stored: stored.vents, name: name)
        found += podFailures(level.podRules, stored: stored.podRules, name: name)
        found += colonyFailures(level.colonies, stored: stored.colonies, name: name)
        if level.moldBound != stored.moldBound {
            found.append(failure(name, "mold bound", "\(level.moldBound), witness \(stored.moldBound)"))
        }
        if level.length != stored.length {
            found.append(failure(name, "length", "\(level.length), witness \(stored.length)"))
        }
        if level.required != stored.required {
            found.append(failure(name, "required cycles", "\(level.required), witness \(stored.required)"))
        }
        if level.start != stored.start { found.append(failure(name, "start")) }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.sites != stored.sites { found.append(failure(name, "sites")) }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The arrangement actions of `actions` (every action but a final `run`).
    static func changes(_ actions: [MushroomWeatherAction]) -> [MushroomWeatherAction] {
        actions.last == .run ? Array(actions.dropLast()) : actions
    }

    /// An action in words for messages.
    static func actionText(_ action: MushroomWeatherAction) -> String {
        switch action {
        case .place(let slot, let cell): return "place pod \(slot + 1) at \(cellText(cell))"
        case .remove(let slot): return "remove pod \(slot + 1)"
        case .vent(let index, let open): return "vent \(index + 1) " + (open ? "open" : "closed")
        case .moonlight(let level): return "moonlight \(level)"
        case .run: return "run"
        }
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on exactly the final run and not before within the budget with exactly its per-action
    /// fingerprints, digests and report, and the plan's actions are the witness's with `arrangementsByDepth[size − 1]`
    /// the counterexample's arrangements, `nearestMiss` the counterexample's nearest miss and work at most
    /// `MushroomWeatherSolver.workBound` and equal to the witness difficulty's. The level parts come first, then the
    /// witness's actions, digests and fingerprints, then the counterexample and the plan, so an altered part is the
    /// first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: MushroomWeatherLevel, witness: MushroomWeatherWitness,
                         plan: MushroomWeatherPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)
        let witnessChanges: [MushroomWeatherAction] = changes(witness.actions)

        // The witness's actions: at least one arrangement action of the witness shape, then exactly one run last.
        if witness.actions.count < 2 { found.append(failure(name, "witness action", "\(witness.actions.count)")) }
        if witness.actions.last != .run {
            found.append(failure(name, "witness action", "the last is not the run"))
        }
        for index in 0..<witnessChanges.count where !MushroomWeatherWitness.isShaped(witnessChanges[index],
                                                                                       level: level) {
            found.append(failure(name, "witness action", "action \(index + 1): \(actionText(witnessChanges[index]))"))
        }

        // Not before: no proper prefix of the arrangement actions followed by the run wins.
        if !witnessChanges.isEmpty {
            for count in 0..<witnessChanges.count {
                let prefix: [MushroomWeatherAction] = Array(witnessChanges.prefix(count))
                if MushroomWeatherSolver.replayWins(level, actions: prefix) {
                    found.append(failure(name, "witness action", "the run wins after \(count) actions"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the final run, within the budget.
        switch MushroomWeatherWitness.replay(level, actions: witness.actions) {
        case .refused(let error):
            found.append(failure(name, "witness action", "replay refused (\(error.reasonCode))"))
        case .played(let play, let fingerprints, let digests):
            if play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(play.stage))"))
            }
            let spent: Int = play.actionsSpent
            if spent != witnessChanges.count || spent > level.budget {
                found.append(failure(name, "budget", "spent \(spent) of \(level.budget)"))
            }
            if digests != witness.digests {
                found.append(failure(name, "per-action digest",
                                     "digest \(firstDifference(digests, witness.digests) + 1)"))
            }
            if fingerprints != witness.fingerprints {
                found.append(failure(name, "per-action fingerprint",
                                     "fingerprint \(firstDifference(fingerprints, witness.fingerprints) + 1)"))
            }
            if play.stage == .won {
                let report: MushroomWeatherWitnessReport = MushroomWeatherWitnessReport(play.report)
                if report != witness.report {
                    found.append(failure(name, "report", "end \(report.end), witness \(witness.report.end)"))
                }
            }
        }

        // The counterexample: one action below the witness's plan.
        if witness.counterexample.depth != witnessChanges.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness actions \(witnessChanges.count)"))
        }

        // The solver: exactly the witness's actions, the counterexample's arrangements and nearest miss, work within
        // the bound.
        guard let plan: MushroomWeatherPlan = plan else {
            found.append(failure(name, "plan action", "the solver finds no plan"))
            return found
        }
        if plan.actions != witnessChanges {
            let action: Int = firstDifference(plan.actions, witnessChanges) + 1
            found.append(failure(name, "plan action", "action \(action) of \(plan.size), witness "
                                    + "\(witnessChanges.count)"))
        }
        if plan.size < 1 || plan.arrangementsByDepth.count != plan.size {
            found.append(failure(name, "plan arrangements by depth",
                                 "\(plan.arrangementsByDepth.count) depths, size \(plan.size)"))
        } else if plan.arrangementsByDepth[plan.size - 1] != witness.counterexample.arrangements {
            found.append(failure(name, "counterexample arrangements count",
                                 "\(witness.counterexample.arrangements), plan "
                                    + "\(plan.arrangementsByDepth[plan.size - 1])"))
        }
        if plan.size - 1 != witness.counterexample.depth {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), plan \(plan.size - 1)"))
        }
        if plan.nearestMiss != witness.counterexample.nearestMiss {
            found.append(failure(name, "counterexample nearest miss",
                                 "\(witness.counterexample.nearestMiss), plan \(plan.nearestMiss)"))
        }
        var searched: Int = 0
        for count in plan.arrangementsByDepth { searched += count }
        if searched != witness.difficulty.arrangementsSearched {
            found.append(failure(name, "arrangements searched",
                                 "plan \(searched), witness \(witness.difficulty.arrangementsSearched)"))
        }
        if plan.work > MushroomWeatherSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(MushroomWeatherSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    // MARK: Alteration builders

    /// The editable parts of a level, rebuilt through the level initialiser by ``build()``.
    struct LevelParts {
        /// The level the parts came from (every part not listed here is kept).
        let source: MushroomWeatherLevel
        /// The starting humidity of every cell.
        var humidity: [Int]
        /// The diffusion.
        var diffusion: Int
        /// The vents.
        var vents: [MushroomWeatherVent]
        /// The pod rules.
        var podRules: MushroomWeatherPodRules
        /// The colonies.
        var colonies: [MushroomWeatherColony]
        /// The mold bound.
        var moldBound: Int
        /// The budget.
        var budget: Int

        /// The parts of `level`, unchanged.
        init(_ level: MushroomWeatherLevel) {
            source = level
            humidity = level.humidity
            diffusion = level.diffusion
            vents = level.vents
            podRules = level.podRules
            colonies = level.colonies
            moldBound = level.moldBound
            budget = level.budget
        }

        /// The level of these parts, checked by the level rules (the "already won" rule included).
        func build() throws -> MushroomWeatherLevel {
            try MushroomWeatherLevel(id: source.id, seed: source.seed, difficulty: source.difficulty,
                                     rows: source.rows, columns: source.columns, blocked: source.blocked,
                                     humidity: humidity, diffusion: diffusion, rates: source.rates, vents: vents,
                                     podRules: podRules, colonies: colonies, moldBound: moldBound,
                                     length: source.length, required: source.required, start: source.start,
                                     budget: budget, tutorial: source.tutorial, sites: source.sites)
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

    /// The first of `candidates` the level rules accept with a changed fingerprint; when none is, the first candidate
    /// rebuilt (so the refusal is reported); with no candidate, `level` itself (reported as unchanged).
    static func firstAccepted(_ level: MushroomWeatherLevel, _ candidates: [LevelParts]) throws
        -> MushroomWeatherLevel {
        for parts in candidates {
            if let copy: MushroomWeatherLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A colony's band altered: its low or its high one more or one less.
    static func bandAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var candidates: [LevelParts] = []
        for index in order(level.colonies.count) {
            let old: MushroomWeatherColony = level.colonies[index]
            let bands: [(Int, Int)] = [(old.low, old.high + 1), (old.low, old.high - 1), (old.low - 1, old.high),
                                       (old.low + 1, old.high)]
            for (low, high) in bands {
                var parts: LevelParts = LevelParts(level)
                parts.colonies[index] = MushroomWeatherColony(cell: old.cell, low: low, high: high,
                                                              survivalFloor: old.survivalFloor)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A colony's survival floor altered: a sensitive colony's floor one less or one more (sensitive colonies first);
    /// a colony without a floor given floor 0 when no sensitive colony's floor can change.
    static func floorAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var candidates: [LevelParts] = []
        var fallbacks: [LevelParts] = []
        for index in order(level.colonies.count) {
            let old: MushroomWeatherColony = level.colonies[index]
            if let floor = old.survivalFloor {
                for value in [floor - 1, floor + 1] {
                    var parts: LevelParts = LevelParts(level)
                    parts.colonies[index] = MushroomWeatherColony(cell: old.cell, low: old.low, high: old.high,
                                                                  survivalFloor: value)
                    candidates.append(parts)
                }
            } else {
                var parts: LevelParts = LevelParts(level)
                parts.colonies[index] = MushroomWeatherColony(cell: old.cell, low: old.low, high: old.high,
                                                              survivalFloor: 0)
                fallbacks.append(parts)
            }
        }
        return try firstAccepted(level, candidates + fallbacks)
    }

    /// A cell's starting humidity altered: a floor cell's humidity one more or one less (floor cells from seed order).
    static func humidityAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var floor: [Int] = []
        for index in 0..<level.humidity.count where level.floorMask[index] { floor.append(index) }
        var candidates: [LevelParts] = []
        for position in order(floor.count) {
            let index: Int = floor[position]
            for delta in [1, -1] {
                var parts: LevelParts = LevelParts(level)
                parts.humidity[index] = level.humidity[index] + delta
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The diffusion altered: one more, else one less.
    static func diffusionAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var candidates: [LevelParts] = []
        for value in [level.diffusion + 1, level.diffusion - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.diffusion = value
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// A vent's rate altered: its open or closed rate one more or one less (vents from seed order).
    static func ventRateAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var candidates: [LevelParts] = []
        for index in order(level.vents.count) {
            let old: MushroomWeatherVent = level.vents[index]
            let rates: [(Int, Int)] = [(old.openRate - 1, old.closedRate), (old.openRate + 1, old.closedRate),
                                       (old.openRate, old.closedRate + 1), (old.openRate, old.closedRate - 1)]
            for (open, closed) in rates {
                var parts: LevelParts = LevelParts(level)
                parts.vents[index] = MushroomWeatherVent(cell: old.cell, openRate: open, closedRate: closed)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The pod rules with `release` and `threshold` in place of the old ones.
    static func rules(_ old: MushroomWeatherPodRules, release: Int, threshold: Int) -> MushroomWeatherPodRules {
        MushroomWeatherPodRules(slots: old.slots, release: release, grownRelease: old.grownRelease,
                                growthThreshold: threshold)
    }

    /// The pod release altered: one less, else one more (the grown release is kept, so it must stay at least r).
    static func releaseAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        let old: MushroomWeatherPodRules = level.podRules
        var candidates: [LevelParts] = []
        for value in [old.release - 1, old.release + 1] {
            var parts: LevelParts = LevelParts(level)
            parts.podRules = rules(old, release: value, threshold: old.growthThreshold)
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The growth threshold altered: one more, else one less.
    static func thresholdAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        let old: MushroomWeatherPodRules = level.podRules
        var candidates: [LevelParts] = []
        for value in [old.growthThreshold + 1, old.growthThreshold - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.podRules = rules(old, release: old.release, threshold: value)
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The mold bound altered: one more, else one less.
    static func moldBoundAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var candidates: [LevelParts] = []
        for value in [level.moldBound + 1, level.moldBound - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.moldBound = value
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: MushroomWeatherLevel) throws -> MushroomWeatherLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = MushroomWeatherLevel.budgets.lowerBound
        parts.budget = level.budget > lower ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: MushroomWeatherLevel, part: String) throws -> MushroomWeatherLevel {
        switch part {
        case "colony band": return try bandAltered(level)
        case "survival floor": return try floorAltered(level)
        case "starting humidity": return try humidityAltered(level)
        case "diffusion": return try diffusionAltered(level)
        case "vent rate": return try ventRateAltered(level)
        case "pod release": return try releaseAltered(level)
        case "growth threshold": return try thresholdAltered(level)
        case "mold bound": return try moldBoundAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The nine level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["colony band", "survival floor", "starting humidity", "diffusion", "vent rate",
                                       "pod release", "growth threshold", "mold bound", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: MushroomWeatherWitness,
                                        plan: MushroomWeatherPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: MushroomWeatherLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: MushroomWeatherWitness, actions: [MushroomWeatherAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: MushroomWeatherCounterexample? = nil) -> MushroomWeatherWitness {
        MushroomWeatherWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
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

    /// The arrangement actions of the witness shape that may replace the last of `changes` on `level`: a placement of
    /// the same slot on a site no earlier placement uses (sites from seed order), a setting of another vent to the
    /// state it does not start in, then another moonlight level than the start's; the original action excluded.
    static func replacements(_ level: MushroomWeatherLevel,
                             _ changes: [MushroomWeatherAction]) -> [MushroomWeatherAction] {
        guard let last: MushroomWeatherAction = changes.last else { return [] }
        var used: [MushroomWeatherCell] = []
        var toggled: [Int] = []
        var lastSlot: Int = 0
        for index in 0..<changes.count {
            switch changes[index] {
            case .place(let slot, let cell):
                if index < changes.count - 1 { used.append(cell) } else { lastSlot = slot }
            case .vent(let vent, _):
                if index < changes.count - 1 { toggled.append(vent) }
            default:
                break
            }
        }
        let sites: [MushroomWeatherCell] = level.sites ?? []
        var candidates: [MushroomWeatherAction] = []
        for index in order(sites.count) where !used.contains(sites[index]) {
            candidates.append(.place(slot: lastSlot, cell: sites[index]))
        }
        for index in order(level.vents.count) where !toggled.contains(index) {
            candidates.append(.vent(index: index, open: !level.start.ventsOpen[index]))
        }
        for value in MushroomWeatherLevel.moonlightLevels where value != level.start.moonlight {
            candidates.append(.moonlight(level: value))
        }
        var result: [MushroomWeatherAction] = []
        for candidate in candidates where candidate != last { result.append(candidate) }
        return result
    }

    /// The witness actions with the last arrangement action altered so the run no longer wins with them (the first of
    /// ``replacements(_:_:)`` the play accepts and the run does not win with), the run kept last. Nil when every such
    /// change still wins or is refused.
    static func actionAltered(_ level: MushroomWeatherLevel,
                              _ actions: [MushroomWeatherAction]) -> [MushroomWeatherAction]? {
        let witnessChanges: [MushroomWeatherAction] = changes(actions)
        guard !witnessChanges.isEmpty else { return nil }
        for candidate in replacements(level, witnessChanges) {
            var altered: [MushroomWeatherAction] = witnessChanges
            altered[altered.count - 1] = candidate
            guard case .played = MushroomWeatherWitness.replay(level, actions: altered) else { continue }
            if !MushroomWeatherSolver.replayWins(level, actions: altered) { return altered + [.run] }
        }
        return nil
    }

    /// The plan with its first action changed: a placement moved to another site the plan does not use (sites from
    /// seed order), a vent setting reversed or another moonlight level.
    static func planAltered(_ plan: MushroomWeatherPlan, level: MushroomWeatherLevel) -> MushroomWeatherPlan? {
        guard let first: MushroomWeatherAction = plan.actions.first else { return nil }
        var used: [MushroomWeatherCell] = []
        for action in plan.actions {
            if case .place(_, let cell) = action { used.append(cell) }
        }
        let replacement: MushroomWeatherAction
        switch first {
        case .place(let slot, _):
            let sites: [MushroomWeatherCell] = level.sites ?? []
            var free: MushroomWeatherCell?
            for index in order(sites.count) where free == nil && !used.contains(sites[index]) { free = sites[index] }
            guard let cell = free else { return nil }
            replacement = .place(slot: slot, cell: cell)
        case .vent(let index, let open):
            replacement = .vent(index: index, open: !open)
        case .moonlight(let value):
            replacement = .moonlight(level: (value + 1) % (MushroomWeatherLevel.moonlightLevels.upperBound + 1))
        case .remove, .run:
            return nil
        }
        var actions: [MushroomWeatherAction] = plan.actions
        actions[0] = replacement
        return MushroomWeatherPlan(actions: actions, arrangement: plan.arrangement,
                                   arrangementsByDepth: plan.arrangementsByDepth, nearestMiss: plan.nearestMiss,
                                   work: plan.work)
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
    /// `MushroomWeatherExperienceCore.generated(number:)` builds it) equals the witness's, the solver, run once on it,
    /// matches the witness with the band's plan length and the checker finds no failure. The solver runs once per
    /// level (the experience core's certification would run it a second time), so a group of 10 stays under 10 s.
    static func check(number: Int) throws {
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
        let index: Int = MushroomWeatherExperienceCore.certifiedCandidates[number - 1]
        let witness: MushroomWeatherWitness = try witness(number)
        #expect(entry.number == number, "level \(number): manifest entry \(entry.number)")
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(index == witness.skipped, "level \(number): certified candidate \(index), witness \(witness.skipped)")
        let candidate: MushroomWeatherLevel? = MushroomWeatherGenerator.candidate(entry, index: index)
        #expect(candidate != nil, "level \(number): no candidate \(index)")
        guard let level: MushroomWeatherLevel = candidate else { return }
        #expect(level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: MushroomWeatherPlan? = MushroomWeatherSolver.plan(level)
        let found: [String] = failures(level: level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect((plan?.work ?? Int.max) <= MushroomWeatherSolver.workBound, "level \(number): solver work above bound")
        guard let plan: MushroomWeatherPlan = plan else { return }
        let length: Int = MushroomWeatherBandProfile.of(band: entry.band).plan
        #expect(plan.size == length, "level \(number): plan size \(plan.size), band length \(length)")
        #expect(MushroomWeatherDifficulty(level: level, plan: plan) == witness.difficulty,
                "level \(number): difficulty differs")
    }
}

@Suite struct MushroomWeatherRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try MushroomWeatherRegressionSolverCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G2008-001; SC-R02G2008-001; Q1)

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

    // MARK: Alterations (FR-R02G2008-002; SC-R02G2008-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: MushroomWeatherLevel = try MushroomWeatherExperienceCore.generated(number: number).level
        let witness: MushroomWeatherWitness = try MushroomWeatherRegressionSolverCheck.witness(number)
        let found: [String] = MushroomWeatherRegressionSolverCheck.failures(
            level: level, witness: witness, plan: MushroomWeatherSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a colony's band, a colony's survival floor, a cell's starting humidity, the diffusion, a
    /// vent's rate, the pod release, the growth threshold, the mold bound and the budget, each rebuilt through the
    /// level initialiser and named first. The level is compared first, so the unaltered plan is passed and no altered
    /// level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: MushroomWeatherGenerated = try MushroomWeatherExperienceCore.generated(number: number)
        let witness: MushroomWeatherWitness = try MushroomWeatherRegressionSolverCheck.witness(number)
        #expect(!witness.level.vents.isEmpty, "level \(number): no vent to alter")
        var checked: Int = 0
        for part in MushroomWeatherRegressionSolverCheck.levelParts {
            let found: [String] = MushroomWeatherRegressionSolverCheck.levelAlterationFailures(
                part: part, witness: witness, plan: generated.plan)
            MushroomWeatherRegressionSolverCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
            checked += 1
        }
        #expect(checked == 9, "level \(number): \(checked) level alterations, expected 9")
    }

    /// The survival floor alteration changes a sensitive colony's floor when the level has one (levels 1, 41 and 81
    /// each have one), so the named part is the floor of a colony that can dry out.
    @Test(arguments: alteredNumbers) func theSurvivalFloorAlterationTouchesASensitiveColony(number: Int) throws {
        let witness: MushroomWeatherWitness = try MushroomWeatherRegressionSolverCheck.witness(number)
        var sensitive: Int = 0
        for colony in witness.level.colonies where colony.survivalFloor != nil { sensitive += 1 }
        #expect(sensitive > 0, "level \(number): no sensitive colony")
        let copy: MushroomWeatherLevel = try MushroomWeatherRegressionSolverCheck.floorAltered(witness.level)
        var changed: Int = 0
        for index in copy.colonies.indices where copy.colonies[index] != witness.level.colonies[index] {
            changed += 1
            #expect(witness.level.colonies[index].survivalFloor != nil,
                    "level \(number): colony \(index + 1) was not sensitive")
            #expect(copy.colonies[index].low == witness.level.colonies[index].low
                    && copy.colonies[index].high == witness.level.colonies[index].high,
                    "level \(number): colony \(index + 1) band changed")
        }
        #expect(changed == 1, "level \(number): \(changed) colonies changed")
    }

    /// The plan alteration: the solver's plan with its first action moved to another site (or reversed).
    @Test(arguments: alteredNumbers) func planActionAlterationIsNamed(number: Int) throws {
        let level: MushroomWeatherLevel = try MushroomWeatherExperienceCore.generated(number: number).level
        let witness: MushroomWeatherWitness = try MushroomWeatherRegressionSolverCheck.witness(number)
        let plan: MushroomWeatherPlan? = MushroomWeatherSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: MushroomWeatherPlan = plan else { return }
        let copy: MushroomWeatherPlan? = MushroomWeatherRegressionSolverCheck.planAltered(plan, level: level)
        #expect(copy != nil, "level \(number): the plan has no action to alter")
        guard let copy: MushroomWeatherPlan = copy else { return }
        #expect(copy != plan, "level \(number): plan unchanged")
        let found: [String] = MushroomWeatherRegressionSolverCheck.failures(level: level, witness: witness, plan: copy)
        MushroomWeatherRegressionSolverCheck.expectNamed(found, number: number, part: "plan action")
    }

    /// Witness alterations: an action the run does not win with, a per-action fingerprint, a per-action digest and the
    /// counterexample's arrangements count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: MushroomWeatherLevel = try MushroomWeatherExperienceCore.generated(number: number).level
        let witness: MushroomWeatherWitness = try MushroomWeatherRegressionSolverCheck.witness(number)
        let plan: MushroomWeatherPlan? = MushroomWeatherSolver.plan(level)
        var parts: [String] = []
        var copies: [MushroomWeatherWitness] = []

        let actions: [MushroomWeatherAction]? = MushroomWeatherRegressionSolverCheck.actionAltered(level,
                                                                                                    witness.actions)
        #expect(actions != nil, "level \(number): every altered last action still wins")
        if let actions: [MushroomWeatherAction] = actions {
            parts.append("witness action")
            copies.append(MushroomWeatherRegressionSolverCheck.rebuilt(witness, actions: actions))
        }

        var fingerprints: [String] = witness.fingerprints
        let fingerprintIndex: Int = fingerprints.count / 2
        fingerprints[fingerprintIndex] = MushroomWeatherRegressionSolverCheck.flipped(fingerprints[fingerprintIndex])
        parts.append("per-action fingerprint")
        copies.append(MushroomWeatherRegressionSolverCheck.rebuilt(witness, fingerprints: fingerprints))

        var digests: [String] = witness.digests
        let digestIndex: Int = digests.count / 2
        digests[digestIndex] = MushroomWeatherRegressionSolverCheck.flipped(digests[digestIndex])
        parts.append("per-action digest")
        copies.append(MushroomWeatherRegressionSolverCheck.rebuilt(witness, digests: digests))

        let counterexample: MushroomWeatherCounterexample = MushroomWeatherCounterexample(
            depth: witness.counterexample.depth, arrangements: witness.counterexample.arrangements + 1,
            nearestMiss: witness.counterexample.nearestMiss)
        parts.append("counterexample arrangements count")
        copies.append(MushroomWeatherRegressionSolverCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: MushroomWeatherWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            let found: [String] = MushroomWeatherRegressionSolverCheck.failures(level: level, witness: copy,
                                                                                plan: plan)
            MushroomWeatherRegressionSolverCheck.expectNamed(found, number: number, part: part)
        }
    }
}
