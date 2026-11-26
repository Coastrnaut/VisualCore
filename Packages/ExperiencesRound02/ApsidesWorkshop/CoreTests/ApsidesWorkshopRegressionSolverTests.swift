// ApsidesWorkshopRegressionSolverTests — feature 478 (R02-G18-08) T-R02G1808-002 (FR-R02G1808-001, 002, 007;
// SC-R02G1808-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1: certifying one level takes milliseconds in a debug build, so each test
// stays well under 10 s): the generated level equals the level of its witness file in
// docs/games/apsides-workshop/levels (part by part and by fingerprint); the witness's actions (the tunings, then
// `play`) replay on a fresh play (begun, the tutorial dismissed) to a win on exactly the final play and not before (no
// proper prefix of the tunings followed by `play` wins), within the budget, with exactly its per-action fingerprints
// (after `begin`, after `dismissTutorial` on a tutorial level, then one per action), state digests
// (`ApsidesWorkshopWitness.digest(orbit:spent:)` after each action) and terminal report; `ApsidesWorkshopSolver.plan`
// returns exactly the witness's tunings with `orbitsByDepth[size − 1]` equal to the counterexample's `orbits` at depth
// size − 1, and its work is at most `ApsidesWorkshopSolver.workBound` (counted, never timed) and equal to the witness
// difficulty's. Levels come from the experience core's per-process cache; witness files are read with the plain decoder
// (the level re-checked by its own rules; the solver is not re-run by the decode, which the regression does itself).
//
// The alterations (clarification Q2): the twelve kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `ApsidesWorkshopRegressionSolverCheck.failures`, which
// returns every failure as a string naming the level and the part ("level 41: planet radius differs (planet 0: …)"):
// a planet's centre, a planet's radius, a target's kind, a target's sector, a target's band, the starting orbit, the
// period, the budget (each rebuilt through the level initialiser, the first copy the level rules accept and whose
// fingerprint changes; a refused construction is itself a failure naming the part); a plan tuning; a witness action
// (one the play does not win with), a per-action fingerprint or digest (both are altered and named); the
// counterexample's orbits count. Level 1 has no planet, so the two planet alterations run on levels 41 and 81 (each
// has planets, which the test checks). The honest input gives no failure. The altered planet, target and lever are
// chosen from seed 2_478 (no random source). Explicit types, plain loops, short runs. Modelled on
// CelestialEclipseLabRegressionSolverTests (feature 468).
import Foundation
@testable import ApsidesWorkshopCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum ApsidesWorkshopRegressionSolverCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, ApsidesWorkshop, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/apsides-workshop/levels", isDirectory: true)

    /// The seed that fixes which planet, target and lever an alteration touches first.
    static let alterationSeed: UInt64 = 2_478

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> ApsidesWorkshopWitness {
        let name: String = String(ApsidesWorkshopGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(ApsidesWorkshopWitness.self, from: data)
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

    /// Every disagreement of `planets` with the stored planets: the count, then per planet its centre and radius.
    static func planetFailures(_ planets: [ApsidesWorkshopPlanet], stored: [ApsidesWorkshopPlanet],
                               name: String) -> [String] {
        var found: [String] = []
        if planets.count != stored.count {
            found.append(failure(name, "planet count", "\(planets.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<planets.count {
            let lhs: ApsidesWorkshopPlanet = planets[index]
            let rhs: ApsidesWorkshopPlanet = stored[index]
            if lhs.x != rhs.x || lhs.y != rhs.y {
                found.append(failure(name, "planet centre", "planet \(index): (\(lhs.x), \(lhs.y)), "
                                        + "witness (\(rhs.x), \(rhs.y))"))
            }
            if lhs.radius != rhs.radius {
                found.append(failure(name, "planet radius", "planet \(index): \(lhs.radius), witness \(rhs.radius)"))
            }
        }
        return found
    }

    /// Every disagreement of `targets` with the stored targets: the count, then per target its kind, sector and band.
    static func targetFailures(_ targets: [ApsidesWorkshopTarget], stored: [ApsidesWorkshopTarget],
                               name: String) -> [String] {
        var found: [String] = []
        if targets.count != stored.count {
            found.append(failure(name, "target count", "\(targets.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<targets.count {
            let lhs: ApsidesWorkshopTarget = targets[index]
            let rhs: ApsidesWorkshopTarget = stored[index]
            if lhs.kind != rhs.kind {
                found.append(failure(name, "target kind", "target \(index): \(lhs.kind.rawValue), "
                                        + "witness \(rhs.kind.rawValue)"))
            }
            if lhs.sector != rhs.sector {
                found.append(failure(name, "target sector", "target \(index): \(lhs.sector), witness \(rhs.sector)"))
            }
            if lhs.low != rhs.low || lhs.high != rhs.high {
                found.append(failure(name, "target band", "target \(index): \(lhs.low)…\(lhs.high), "
                                        + "witness \(rhs.low)…\(rhs.high)"))
            }
        }
        return found
    }

    /// The orbit in words for a failure detail: "size 18, eccentricity 10, direction 6".
    static func orbitText(_ orbit: ApsidesWorkshopOrbit) -> String {
        "size \(orbit.size), eccentricity \(orbit.eccentricity), direction \(orbit.direction)"
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (the id, seed and
    /// difficulty, then the period, the planets, the targets, the starting orbit, the budget, the tutorial and the
    /// fingerprint).
    static func levelFailures(_ level: ApsidesWorkshopLevel, stored: ApsidesWorkshopLevel, name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        if level.period != stored.period {
            found.append(failure(name, "period", "\(level.period), witness \(stored.period)"))
        }
        found += planetFailures(level.planets, stored: stored.planets, name: name)
        found += targetFailures(level.targets, stored: stored.targets, name: name)
        if level.orbit != stored.orbit {
            found.append(failure(name, "starting orbit", "\(orbitText(level.orbit)), witness "
                                    + orbitText(stored.orbit)))
        }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The tunings of `actions` (every action but a final `play`).
    static func tunings(_ actions: [ApsidesWorkshopAction]) -> [ApsidesWorkshopAction] {
        actions.last == .play ? Array(actions.dropLast()) : actions
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on exactly the final play and not before within the budget with exactly its per-action
    /// fingerprints, digests and report, and the plan's tunings are the witness's with `orbitsByDepth[size − 1]` the
    /// counterexample's orbits at depth size − 1 and work at most `ApsidesWorkshopSolver.workBound` and equal to the
    /// witness difficulty's. The level parts come first, then the witness's actions, digests and fingerprints, then the
    /// counterexample and the plan, so an altered part is the first failure. A replay the play refuses is a failure,
    /// never a crash. Pure.
    static func failures(level: ApsidesWorkshopLevel, witness: ApsidesWorkshopWitness,
                         plan: ApsidesWorkshopPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)
        let witnessTunings: [ApsidesWorkshopAction] = tunings(witness.actions)

        // The witness's actions: at least one tuning, each with its steps in range, then exactly one play last.
        if witness.actions.count < 2 { found.append(failure(name, "witness action", "\(witness.actions.count)")) }
        if witness.actions.last != .play {
            found.append(failure(name, "witness action", "the last is not the play"))
        }
        for index in 0..<witnessTunings.count {
            switch witnessTunings[index] {
            case .periapsis(let eccentricity, let direction):
                if !ApsidesWorkshopOrbit.eccentricities.contains(eccentricity)
                    || !ApsidesWorkshopOrbit.directions.contains(direction) {
                    found.append(failure(name, "witness action", "action \(index): periapsis \(eccentricity), "
                                            + "\(direction)"))
                }
            case .size(let size):
                if !ApsidesWorkshopOrbit.sizes.contains(size) {
                    found.append(failure(name, "witness action", "action \(index): size \(size)"))
                }
            case .play:
                found.append(failure(name, "witness action", "action \(index): a play before the final action"))
            }
        }

        // Not before: no proper prefix of the tunings followed by the play wins.
        if !witnessTunings.isEmpty {
            for count in 0..<witnessTunings.count {
                let prefix: [ApsidesWorkshopAction] = Array(witnessTunings.prefix(count)) + [.play]
                if let early = ApsidesWorkshopWitness.replay(level, actions: prefix), early.play.stage == .won {
                    found.append(failure(name, "witness action", "the play wins after \(count) tunings"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the final play, within the budget.
        if let run = ApsidesWorkshopWitness.replay(level, actions: witness.actions) {
            if run.play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            let spent: Int = run.play.actionsSpent
            if spent != witnessTunings.count || spent > level.budget {
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
                let report: ApsidesWorkshopWitnessReport = ApsidesWorkshopWitnessReport(run.play.report,
                                                                                        orbit: run.play.orbit)
                if report != witness.report {
                    found.append(failure(name, "report", "met \(report.met), witness \(witness.report.met)"))
                }
            }
        } else {
            found.append(failure(name, "witness action", "replay refused"))
        }

        // The counterexample: one tuning below the witness's plan.
        if witness.counterexample.depth != witnessTunings.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness tunings \(witnessTunings.count)"))
        }

        // The solver: exactly the witness's tunings, the counterexample's orbits, work within the bound.
        guard let plan: ApsidesWorkshopPlan = plan else {
            found.append(failure(name, "plan tuning", "the solver finds no plan"))
            return found
        }
        if plan.actions != witnessTunings {
            let tuning: Int = firstDifference(plan.actions, witnessTunings) + 1
            found.append(failure(name, "plan tuning", "tuning \(tuning) of \(plan.size), "
                                    + "witness \(witnessTunings.count)"))
        }
        if plan.size < 1 || plan.orbitsByDepth.count != plan.size {
            found.append(failure(name, "plan orbits by depth", "\(plan.orbitsByDepth.count) depths, size \(plan.size)"))
        } else if plan.orbitsByDepth[plan.size - 1] != witness.counterexample.orbits {
            found.append(failure(name, "counterexample orbits count",
                                 "\(witness.counterexample.orbits), plan \(plan.orbitsByDepth[plan.size - 1])"))
        }
        if plan.size - 1 != witness.counterexample.depth {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), plan \(plan.size - 1)"))
        }
        if plan.orbitsSearched != witness.difficulty.orbitsSearched {
            found.append(failure(name, "orbits searched",
                                 "plan \(plan.orbitsSearched), witness \(witness.difficulty.orbitsSearched)"))
        }
        if plan.work > ApsidesWorkshopSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(ApsidesWorkshopSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    // MARK: Alteration builders

    /// The editable parts of a level, rebuilt through the level initialiser by ``build()``.
    struct LevelParts {
        /// The level the parts came from (id, seed, difficulty and tutorial are kept).
        let source: ApsidesWorkshopLevel
        /// The period.
        var period: Int
        /// The planets.
        var planets: [ApsidesWorkshopPlanet]
        /// The targets.
        var targets: [ApsidesWorkshopTarget]
        /// The starting orbit.
        var orbit: ApsidesWorkshopOrbit
        /// The budget.
        var budget: Int

        /// The parts of `level`, unchanged.
        init(_ level: ApsidesWorkshopLevel) {
            source = level
            period = level.period
            planets = level.planets
            targets = level.targets
            orbit = level.orbit
            budget = level.budget
        }

        /// The level of these parts, checked by the level rules (the "already won" rule included).
        func build() throws -> ApsidesWorkshopLevel {
            try ApsidesWorkshopLevel(id: source.id, seed: source.seed, difficulty: source.difficulty, period: period,
                                     planets: planets, targets: targets, orbit: orbit, budget: budget,
                                     tutorial: source.tutorial)
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
    static func firstAccepted(_ level: ApsidesWorkshopLevel, _ candidates: [LevelParts]) throws
        -> ApsidesWorkshopLevel {
        for parts in candidates {
            if let copy: ApsidesWorkshopLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A planet's centre altered: moved one lattice unit along x or y.
    static func centreAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        let steps: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        for index in order(level.planets.count) {
            let old: ApsidesWorkshopPlanet = level.planets[index]
            for (dx, dy) in steps {
                var parts: LevelParts = LevelParts(level)
                parts.planets[index] = ApsidesWorkshopPlanet(x: old.x + dx, y: old.y + dy, radius: old.radius)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A planet's radius altered: one larger or one smaller.
    static func planetRadiusAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        for index in order(level.planets.count) {
            let old: ApsidesWorkshopPlanet = level.planets[index]
            for radius in [old.radius + 1, old.radius - 1] {
                var parts: LevelParts = LevelParts(level)
                parts.planets[index] = ApsidesWorkshopPlanet(x: old.x, y: old.y, radius: radius)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A target's kind altered: each other kind, the sector and band kept (a band outside the new kind's bounds is
    /// refused by the rules, so the next is tried).
    static func kindAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        for index in order(level.targets.count) {
            let old: ApsidesWorkshopTarget = level.targets[index]
            for kind in ApsidesWorkshopTargetKind.allCases where kind != old.kind {
                var parts: LevelParts = LevelParts(level)
                parts.targets[index] = ApsidesWorkshopTarget(kind: kind, sector: old.sector, low: old.low,
                                                             high: old.high)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A target's sector altered: moved forward by 1 … 7 sectors.
    static func sectorAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        let count: Int = ApsidesWorkshopSky.sectorCount
        for index in order(level.targets.count) {
            let old: ApsidesWorkshopTarget = level.targets[index]
            for delta in 1..<count {
                var parts: LevelParts = LevelParts(level)
                parts.targets[index] = ApsidesWorkshopTarget(kind: old.kind, sector: (old.sector + delta) % count,
                                                             low: old.low, high: old.high)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A target's band altered: its high one more or one less, or its low one more or one less.
    static func bandAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        for index in order(level.targets.count) {
            let old: ApsidesWorkshopTarget = level.targets[index]
            let bands: [(Int, Int)] = [(old.low, old.high + 1), (old.low, old.high - 1),
                                       (old.low + 1, old.high), (old.low - 1, old.high)]
            for (low, high) in bands {
                var parts: LevelParts = LevelParts(level)
                parts.targets[index] = ApsidesWorkshopTarget(kind: old.kind, sector: old.sector, low: low, high: high)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The starting orbit altered: one lever moved one step (size, eccentricity or direction, each up or down; an
    /// invalid or already winning orbit is refused by the rules, so the next is tried).
    static func orbitAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        let old: ApsidesWorkshopOrbit = level.orbit
        var orbits: [ApsidesWorkshopOrbit] = []
        orbits.append(ApsidesWorkshopOrbit(size: old.size + 1, eccentricity: old.eccentricity,
                                           direction: old.direction))
        orbits.append(ApsidesWorkshopOrbit(size: old.size - 1, eccentricity: old.eccentricity,
                                           direction: old.direction))
        orbits.append(ApsidesWorkshopOrbit(size: old.size, eccentricity: old.eccentricity + 1,
                                           direction: old.direction))
        orbits.append(ApsidesWorkshopOrbit(size: old.size, eccentricity: old.eccentricity - 1,
                                           direction: old.direction))
        orbits.append(ApsidesWorkshopOrbit(size: old.size, eccentricity: old.eccentricity,
                                           direction: (old.direction + 1) % 24))
        orbits.append(ApsidesWorkshopOrbit(size: old.size, eccentricity: old.eccentricity,
                                           direction: (old.direction + 23) % 24))
        var candidates: [LevelParts] = []
        for index in order(orbits.count) {
            var parts: LevelParts = LevelParts(level)
            parts.orbit = orbits[index]
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The period altered: two ticks shorter, else two ticks longer (periods are even).
    static func periodAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var candidates: [LevelParts] = []
        for period in [level.period - 2, level.period + 2] {
            var parts: LevelParts = LevelParts(level)
            parts.period = period
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = ApsidesWorkshopLevel.budgets.lowerBound
        parts.budget = level.budget > lower ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: ApsidesWorkshopLevel, part: String) throws -> ApsidesWorkshopLevel {
        switch part {
        case "planet centre": return try centreAltered(level)
        case "planet radius": return try planetRadiusAltered(level)
        case "target kind": return try kindAltered(level)
        case "target sector": return try sectorAltered(level)
        case "target band": return try bandAltered(level)
        case "starting orbit": return try orbitAltered(level)
        case "period": return try periodAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The two planet parts of clarification Q2, as the checker names them.
    static let planetParts: [String] = ["planet centre", "planet radius"]

    /// The eight level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["planet centre", "planet radius", "target kind", "target sector",
                                       "target band", "starting orbit", "period", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: ApsidesWorkshopWitness,
                                        plan: ApsidesWorkshopPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: ApsidesWorkshopLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: ApsidesWorkshopWitness, actions: [ApsidesWorkshopAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: ApsidesWorkshopCounterexample? = nil) -> ApsidesWorkshopWitness {
        ApsidesWorkshopWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                               digests: digests ?? witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                               report: witness.report, counterexample: counterexample ?? witness.counterexample,
                               difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The witness actions with the last tuning altered so the play no longer wins with them: another setting of the
    /// same lever (from seed order), the play kept last. Nil when every such change still wins.
    static func actionAltered(_ level: ApsidesWorkshopLevel,
                              _ actions: [ApsidesWorkshopAction]) -> [ApsidesWorkshopAction]? {
        let witnessTunings: [ApsidesWorkshopAction] = tunings(actions)
        guard let last: ApsidesWorkshopAction = witnessTunings.last else { return nil }
        var candidates: [ApsidesWorkshopAction] = []
        switch last {
        case .periapsis(let eccentricity, let direction):
            let directions: [Int] = order(ApsidesWorkshopOrbit.directions.count)
            for k in ApsidesWorkshopOrbit.eccentricities {
                for d in directions where k != eccentricity || d != direction {
                    candidates.append(.periapsis(k, d))
                }
            }
        case .size(let size):
            for a in ApsidesWorkshopOrbit.sizes where a != size { candidates.append(.size(a)) }
        case .play:
            return nil
        }
        for candidate in candidates {
            var altered: [ApsidesWorkshopAction] = witnessTunings
            altered[altered.count - 1] = candidate
            if !ApsidesWorkshopSolver.replayWins(level, actions: altered) { return altered + [.play] }
        }
        return nil
    }

    /// The plan with its first tuning moved: a periapsis tuning to the next direction, a size tuning one larger (one
    /// smaller at the top of the range).
    static func planAltered(_ plan: ApsidesWorkshopPlan) -> ApsidesWorkshopPlan? {
        guard !plan.actions.isEmpty else { return nil }
        var actions: [ApsidesWorkshopAction] = plan.actions
        switch actions[0] {
        case .periapsis(let eccentricity, let direction):
            actions[0] = .periapsis(eccentricity, (direction + 1) % ApsidesWorkshopOrbit.directions.count)
        case .size(let size):
            actions[0] = .size(size < ApsidesWorkshopOrbit.sizes.upperBound ? size + 1 : size - 1)
        case .play:
            return nil
        }
        return ApsidesWorkshopPlan(actions: actions, orbit: plan.orbit, orbitsByDepth: plan.orbitsByDepth,
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

    /// Checks level `number`: the generated level equals the witness's, the solver's plan matches the witness and the
    /// checker finds no failure.
    static func check(number: Int) throws {
        let generated: ApsidesWorkshopGenerated = try ApsidesWorkshopExperienceCore.generated(number: number)
        let witness: ApsidesWorkshopWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: ApsidesWorkshopPlan? = ApsidesWorkshopSolver.plan(generated.level)
        let found: [String] = failures(level: generated.level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= ApsidesWorkshopSolver.workBound,
                "level \(number): solver work above bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }
}

@Suite struct ApsidesWorkshopRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try ApsidesWorkshopRegressionSolverCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1808-001; SC-R02G1808-001; Q1)

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

    // MARK: Alterations (FR-R02G1808-002; SC-R02G1808-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: ApsidesWorkshopLevel = try ApsidesWorkshopExperienceCore.generated(number: number).level
        let witness: ApsidesWorkshopWitness = try ApsidesWorkshopRegressionSolverCheck.witness(number)
        let found: [String] = ApsidesWorkshopRegressionSolverCheck.failures(level: level, witness: witness,
                                                                            plan: ApsidesWorkshopSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a planet's centre, a planet's radius, a target's kind, a target's sector, a target's band,
    /// the starting orbit, the period and the budget, each rebuilt through the level initialiser and named first. The
    /// level is compared first, so the unaltered plan is passed and no altered level is planned. A level without a
    /// planet (level 1) skips the two planet parts; levels 41 and 81 have planets, so every part runs at least twice.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: ApsidesWorkshopGenerated = try ApsidesWorkshopExperienceCore.generated(number: number)
        let witness: ApsidesWorkshopWitness = try ApsidesWorkshopRegressionSolverCheck.witness(number)
        if number != 1 {
            #expect(!witness.level.planets.isEmpty, "level \(number): no planet to alter")
        }
        var checked: Int = 0
        for part in ApsidesWorkshopRegressionSolverCheck.levelParts {
            let planetPart: Bool = ApsidesWorkshopRegressionSolverCheck.planetParts.contains(part)
            if planetPart && witness.level.planets.isEmpty { continue }
            let found: [String] = ApsidesWorkshopRegressionSolverCheck.levelAlterationFailures(
                part: part, witness: witness, plan: generated.plan)
            ApsidesWorkshopRegressionSolverCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
            checked += 1
        }
        let expected: Int = witness.level.planets.isEmpty ? 6 : 8
        #expect(checked == expected, "level \(number): \(checked) level alterations, expected \(expected)")
    }

    /// The plan alteration: the solver's plan with its first tuning moved (a periapsis tuning to the next direction,
    /// a size tuning one step).
    @Test(arguments: alteredNumbers) func planTuningAlterationIsNamed(number: Int) throws {
        let level: ApsidesWorkshopLevel = try ApsidesWorkshopExperienceCore.generated(number: number).level
        let witness: ApsidesWorkshopWitness = try ApsidesWorkshopRegressionSolverCheck.witness(number)
        let plan: ApsidesWorkshopPlan? = ApsidesWorkshopSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: ApsidesWorkshopPlan = plan else { return }
        let copy: ApsidesWorkshopPlan? = ApsidesWorkshopRegressionSolverCheck.planAltered(plan)
        #expect(copy != nil, "level \(number): the plan has no tuning to alter")
        guard let copy: ApsidesWorkshopPlan = copy else { return }
        #expect(copy != plan, "level \(number): plan unchanged")
        let found: [String] = ApsidesWorkshopRegressionSolverCheck.failures(level: level, witness: witness, plan: copy)
        ApsidesWorkshopRegressionSolverCheck.expectNamed(found, number: number, part: "plan tuning")
    }

    /// Witness alterations: an action the play does not win with, a per-action fingerprint, a per-action digest and
    /// the counterexample's orbits count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: ApsidesWorkshopLevel = try ApsidesWorkshopExperienceCore.generated(number: number).level
        let witness: ApsidesWorkshopWitness = try ApsidesWorkshopRegressionSolverCheck.witness(number)
        let plan: ApsidesWorkshopPlan? = ApsidesWorkshopSolver.plan(level)
        var parts: [String] = []
        var copies: [ApsidesWorkshopWitness] = []

        let actions: [ApsidesWorkshopAction]? = ApsidesWorkshopRegressionSolverCheck.actionAltered(level,
                                                                                                   witness.actions)
        #expect(actions != nil, "level \(number): every altered last tuning still wins")
        if let actions: [ApsidesWorkshopAction] = actions {
            parts.append("witness action")
            copies.append(ApsidesWorkshopRegressionSolverCheck.rebuilt(witness, actions: actions))
        }

        var fingerprints: [String] = witness.fingerprints
        let fingerprintIndex: Int = fingerprints.count / 2
        fingerprints[fingerprintIndex] = ApsidesWorkshopRegressionSolverCheck.flipped(fingerprints[fingerprintIndex])
        parts.append("per-action fingerprint")
        copies.append(ApsidesWorkshopRegressionSolverCheck.rebuilt(witness, fingerprints: fingerprints))

        var digests: [String] = witness.digests
        let digestIndex: Int = digests.count / 2
        digests[digestIndex] = ApsidesWorkshopRegressionSolverCheck.flipped(digests[digestIndex])
        parts.append("per-action digest")
        copies.append(ApsidesWorkshopRegressionSolverCheck.rebuilt(witness, digests: digests))

        let counterexample: ApsidesWorkshopCounterexample =
            ApsidesWorkshopCounterexample(depth: witness.counterexample.depth,
                                          orbits: witness.counterexample.orbits + 1)
        parts.append("counterexample orbits count")
        copies.append(ApsidesWorkshopRegressionSolverCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: ApsidesWorkshopWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            let found: [String] = ApsidesWorkshopRegressionSolverCheck.failures(level: level, witness: copy,
                                                                                plan: plan)
            ApsidesWorkshopRegressionSolverCheck.expectNamed(found, number: number, part: part)
        }
    }
}
