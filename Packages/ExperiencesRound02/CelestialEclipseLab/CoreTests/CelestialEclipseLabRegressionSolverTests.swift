// CelestialEclipseLabRegressionSolverTests — feature 468 (R02-G17-08) T-R02G1708-002 (FR-R02G1708-001, 002;
// SC-R02G1708-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1: certifying one level takes milliseconds in a debug build, so each test
// stays well under 10 s): the generated level equals the level of its witness file in
// docs/games/celestial-eclipse-lab/levels (part by part and by fingerprint); the witness's actions (the phase changes,
// then `run`) replay on a fresh play (begun, the tutorial dismissed) to a win on exactly the final run and not before,
// within the budget, with exactly its per-action fingerprints (after `begin`, after `dismissTutorial` on a tutorial
// level, then one per action), state digests (`CelestialEclipseLabWitness.digest(phases:spent:)` after each action)
// and terminal timeline; `CelestialEclipseLabSolver.plan` returns exactly the witness's phase changes with
// `settingsByDepth[size − 1]` equal to the counterexample's `settings` at depth size − 1, and its work is at most
// `CelestialEclipseLabSolver.workBound` (counted, never timed) and equal to the witness difficulty's. Levels come from
// the experience core's per-process cache; witness files are read with the plain decoder (the level re-checked by its
// own rules; the solver is not re-run by the decode, which the regression does itself).
//
// The alterations (clarification Q2): the twelve kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `RegressionCheck.failures`, which returns every failure
// as a string naming the level and the part ("level 41: body radius differs (body 2: …)"): a body's orbit point, a
// body's radius, a body's fixed flag, a starting phase, a target's bodies, a target's window, the horizon, the budget
// (each rebuilt through the level initialiser, the first copy the level rules accept and whose fingerprint changes; a
// refused construction is itself a failure naming the part); a plan phase change; a witness action (one the play does
// not win with), a per-action fingerprint or digest (both are altered and named); the counterexample's settings count.
// The honest input gives no failure. The altered body, target and phase are chosen from seed 2_468 (no random
// source). Explicit types, plain loops, short runs. Modelled on StarlitCartoucheRegressionSolverTests (feature 458).
import Foundation
@testable import CelestialEclipseLabCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum RegressionCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

    /// The seed that fixes which body, target and phase an alteration touches first.
    static let alterationSeed: UInt64 = 2_468

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> CelestialEclipseLabWitness {
        let name: String = String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(CelestialEclipseLabWitness.self, from: data)
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

    /// Every disagreement of `bodies` with the stored bodies: the count, then per body its orbit points, radius and
    /// fixed flag.
    static func bodyFailures(_ bodies: [CelestialEclipseLabBody], stored: [CelestialEclipseLabBody],
                             name: String) -> [String] {
        var found: [String] = []
        if bodies.count != stored.count {
            found.append(failure(name, "body count", "\(bodies.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<bodies.count {
            let lhs: CelestialEclipseLabBody = bodies[index]
            let rhs: CelestialEclipseLabBody = stored[index]
            if lhs.orbit != rhs.orbit {
                let point: Int = firstDifference(lhs.orbit, rhs.orbit)
                found.append(failure(name, "body orbit point", "body \(index) point \(point) of \(lhs.orbit.count), "
                                        + "witness \(rhs.orbit.count) points"))
            }
            if lhs.radius != rhs.radius {
                found.append(failure(name, "body radius", "body \(index): \(lhs.radius), witness \(rhs.radius)"))
            }
            if lhs.fixed != rhs.fixed {
                found.append(failure(name, "body fixed flag", "body \(index): \(lhs.fixed), witness \(rhs.fixed)"))
            }
        }
        return found
    }

    /// Every disagreement of `target` with the stored target: the count, then per eclipse its bodies and window.
    static func targetFailures(_ target: [CelestialEclipseLabTarget], stored: [CelestialEclipseLabTarget],
                               name: String) -> [String] {
        var found: [String] = []
        if target.count != stored.count {
            found.append(failure(name, "target count", "\(target.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<target.count {
            let lhs: CelestialEclipseLabTarget = target[index]
            let rhs: CelestialEclipseLabTarget = stored[index]
            if lhs.front != rhs.front || lhs.back != rhs.back {
                found.append(failure(name, "target bodies", "eclipse \(index): \(lhs.front) before \(lhs.back), "
                                        + "witness \(rhs.front) before \(rhs.back)"))
            }
            if lhs.open != rhs.open || lhs.close != rhs.close {
                found.append(failure(name, "target window", "eclipse \(index): \(lhs.open)…\(lhs.close), "
                                        + "witness \(rhs.open)…\(rhs.close)"))
            }
        }
        return found
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (the bodies first,
    /// then the horizon, the target, the starting phases, the budget, the tutorial and the fingerprint).
    static func levelFailures(_ level: CelestialEclipseLabLevel, stored: CelestialEclipseLabLevel,
                              name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        found += bodyFailures(level.bodies, stored: stored.bodies, name: name)
        if level.horizon != stored.horizon {
            found.append(failure(name, "horizon", "\(level.horizon), witness \(stored.horizon)"))
        }
        found += targetFailures(level.target, stored: stored.target, name: name)
        if level.phases != stored.phases {
            found.append(failure(name, "starting phase", "body \(firstDifference(level.phases, stored.phases)): "
                                    + "\(level.phases), witness \(stored.phases)"))
        }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The phase changes of `actions` (every action but a final `run`).
    static func changes(_ actions: [CelestialEclipseLabAction]) -> [CelestialEclipseLabAction] {
        actions.last == .run ? Array(actions.dropLast()) : actions
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on exactly the final run and not before within the budget with exactly its per-action
    /// fingerprints, digests and timeline, and the plan's phase changes are the witness's with
    /// `settingsByDepth[size − 1]` the counterexample's settings at depth size − 1 and work at most
    /// `CelestialEclipseLabSolver.workBound` and equal to the witness difficulty's. The level parts come first, then
    /// the witness's actions, digests and fingerprints, then the counterexample and the plan, so an altered part is the
    /// first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: CelestialEclipseLabLevel, witness: CelestialEclipseLabWitness,
                         plan: CelestialEclipseLabPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)

        // The witness's actions: at least one phase change, each of a known movable body to an offset in its
        // period, then exactly one run as the final action.
        if witness.actions.count < 2 { found.append(failure(name, "witness action", "\(witness.actions.count)")) }
        if witness.actions.last != .run { found.append(failure(name, "witness action", "the last is not the run")) }
        for (index, action) in changes(witness.actions).enumerated() {
            switch action {
            case .phase(let body, let offset):
                if body < 0 || body >= level.bodies.count || level.bodies[body].fixed || offset < 0
                    || offset >= level.bodies[body].period {
                    found.append(failure(name, "witness action", "action \(index): body \(body) offset \(offset)"))
                }
            case .run:
                found.append(failure(name, "witness action", "action \(index): a run before the final action"))
            }
        }

        // The replay on a fresh play: a win on exactly the final run and not before, within the budget.
        if let before = CelestialEclipseLabWitness.replay(level, actions: changes(witness.actions)),
           before.play.stage == .won {
            found.append(failure(name, "witness action", "the play is won before the final run"))
        }
        if let run = CelestialEclipseLabWitness.replay(level, actions: witness.actions) {
            if run.play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(run.play.stage))"))
            }
            let spent: Int = run.play.actionsSpent
            if spent != changes(witness.actions).count || spent > level.budget {
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
            if CelestialEclipseLabWitnessTimeline(run.play.timeline) != witness.timeline {
                found.append(failure(name, "timeline", "matched \(run.play.timeline.matched), "
                                        + "witness \(witness.timeline.matched)"))
            }
        } else {
            found.append(failure(name, "witness action", "replay refused"))
        }

        // The counterexample: one phase change below the witness's plan.
        let witnessChanges: [CelestialEclipseLabAction] = changes(witness.actions)
        if witness.counterexample.depth != witnessChanges.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness changes \(witnessChanges.count)"))
        }

        // The solver: exactly the witness's phase changes, the counterexample's settings, work within the bound.
        guard let plan: CelestialEclipseLabPlan = plan else {
            found.append(failure(name, "plan phase change", "the solver finds no plan"))
            return found
        }
        if plan.actions != witnessChanges {
            let change: Int = firstDifference(plan.actions, witnessChanges) + 1
            found.append(failure(name, "plan phase change",
                                 "change \(change) of \(plan.size), witness \(witnessChanges.count)"))
        }
        if plan.size < 1 || plan.settingsByDepth.count != plan.size {
            found.append(failure(name, "plan settings by depth",
                                 "\(plan.settingsByDepth.count) depths, size \(plan.size)"))
        } else if plan.settingsByDepth[plan.size - 1] != witness.counterexample.settings {
            found.append(failure(name, "counterexample settings count",
                                 "\(witness.counterexample.settings), plan \(plan.settingsByDepth[plan.size - 1])"))
        }
        if plan.size - 1 != witness.counterexample.depth {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), plan \(plan.size - 1)"))
        }
        if plan.settingsSearched != witness.difficulty.settingsSearched {
            found.append(failure(name, "settings searched",
                                 "plan \(plan.settingsSearched), witness \(witness.difficulty.settingsSearched)"))
        }
        if plan.work > CelestialEclipseLabSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(CelestialEclipseLabSolver.workBound)"))
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
        let source: CelestialEclipseLabLevel
        /// The bodies.
        var bodies: [CelestialEclipseLabBody]
        /// The horizon.
        var horizon: Int
        /// The target eclipses.
        var target: [CelestialEclipseLabTarget]
        /// The starting phases.
        var phases: [Int]
        /// The budget.
        var budget: Int

        /// The parts of `level`, unchanged.
        init(_ level: CelestialEclipseLabLevel) {
            source = level
            bodies = level.bodies
            horizon = level.horizon
            target = level.target
            phases = level.phases
            budget = level.budget
        }

        /// The level of these parts, checked by the level rules.
        func build() throws -> CelestialEclipseLabLevel {
            try CelestialEclipseLabLevel(id: source.id, seed: source.seed, difficulty: source.difficulty,
                                         bodies: bodies, horizon: horizon, target: target, phases: phases,
                                         budget: budget, tutorial: source.tutorial)
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
    static func firstAccepted(_ level: CelestialEclipseLabLevel, _ candidates: [LevelParts]) throws
        -> CelestialEclipseLabLevel {
        for parts in candidates {
            if let copy: CelestialEclipseLabLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A body's orbit point altered: its first point moved one unit along x, y or z.
    static func orbitAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        let units: [(Int, Int, Int)] = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
        var steps: [CelestialEclipseLabVector] = []
        for (x, y, z) in units { steps.append(CelestialEclipseLabVector(x, y, z)) }
        for index in order(level.bodies.count) {
            let old: CelestialEclipseLabBody = level.bodies[index]
            for step in steps {
                let first: CelestialEclipseLabVector = old.orbit[0]
                var orbit: [CelestialEclipseLabVector] = old.orbit
                orbit[0] = CelestialEclipseLabVector(first.x + step.x, first.y + step.y, first.z + step.z)
                var parts: LevelParts = LevelParts(level)
                parts.bodies[index] = CelestialEclipseLabBody(orbit: orbit, radius: old.radius, fixed: old.fixed)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A body's radius altered: one larger or one smaller.
    static func radiusAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for index in order(level.bodies.count) {
            let old: CelestialEclipseLabBody = level.bodies[index]
            for radius in [old.radius + 1, old.radius - 1] {
                var parts: LevelParts = LevelParts(level)
                parts.bodies[index] = CelestialEclipseLabBody(orbit: old.orbit, radius: radius, fixed: old.fixed)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A body's fixed flag altered: toggled (a level left without a movable body is refused by the rules).
    static func fixedAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for index in order(level.bodies.count) {
            let old: CelestialEclipseLabBody = level.bodies[index]
            var parts: LevelParts = LevelParts(level)
            parts.bodies[index] = CelestialEclipseLabBody(orbit: old.orbit, radius: old.radius, fixed: !old.fixed)
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// A starting phase altered: a body's phase moved forward by 1 … period − 1 (a phase that already wins is refused
    /// by the rules, so the next is tried).
    static func phaseAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for index in order(level.bodies.count) {
            let period: Int = level.bodies[index].period
            for delta in 1..<period {
                var parts: LevelParts = LevelParts(level)
                parts.phases[index] = (level.phases[index] + delta) % period
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A target's bodies altered: an eclipse given another ordered pair of different bodies.
    static func targetBodiesAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for index in order(level.target.count) {
            let old: CelestialEclipseLabTarget = level.target[index]
            for front in order(level.bodies.count) {
                for back in 0..<level.bodies.count where back != front && (front != old.front || back != old.back) {
                    var parts: LevelParts = LevelParts(level)
                    parts.target[index] = CelestialEclipseLabTarget(front: front, back: back, open: old.open,
                                                                    close: old.close)
                    candidates.append(parts)
                }
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A target's window altered: its close one later or earlier, or its open one later or earlier.
    static func windowAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for index in order(level.target.count) {
            let old: CelestialEclipseLabTarget = level.target[index]
            let windows: [(Int, Int)] = [(old.open, old.close + 1), (old.open, old.close - 1),
                                         (old.open + 1, old.close), (old.open - 1, old.close)]
            for (open, close) in windows {
                var parts: LevelParts = LevelParts(level)
                parts.target[index] = CelestialEclipseLabTarget(front: old.front, back: old.back, open: open,
                                                                close: close)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The horizon altered: one tick shorter, else one tick longer.
    static func horizonAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var candidates: [LevelParts] = []
        for horizon in [level.horizon - 1, level.horizon + 1] {
            var parts: LevelParts = LevelParts(level)
            parts.horizon = horizon
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = CelestialEclipseLabLevel.budgets.lowerBound
        parts.budget = level.budget > lower ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: CelestialEclipseLabLevel, part: String) throws -> CelestialEclipseLabLevel {
        switch part {
        case "body orbit point": return try orbitAltered(level)
        case "body radius": return try radiusAltered(level)
        case "body fixed flag": return try fixedAltered(level)
        case "starting phase": return try phaseAltered(level)
        case "target bodies": return try targetBodiesAltered(level)
        case "target window": return try windowAltered(level)
        case "horizon": return try horizonAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The eight level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["body orbit point", "body radius", "body fixed flag", "starting phase",
                                       "target bodies", "target window", "horizon", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: CelestialEclipseLabWitness,
                                        plan: CelestialEclipseLabPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: CelestialEclipseLabLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: CelestialEclipseLabWitness, actions: [CelestialEclipseLabAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: CelestialEclipseLabCounterexample? = nil) -> CelestialEclipseLabWitness {
        CelestialEclipseLabWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                   digests: digests ?? witness.digests,
                                   fingerprints: fingerprints ?? witness.fingerprints, timeline: witness.timeline,
                                   counterexample: counterexample ?? witness.counterexample,
                                   difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The witness actions with the last phase change altered so the play no longer wins with them: another offset
    /// of the same body, else another movable body with each offset; the run kept last. Nil when every such change
    /// still wins.
    static func actionAltered(_ level: CelestialEclipseLabLevel,
                              _ actions: [CelestialEclipseLabAction]) -> [CelestialEclipseLabAction]? {
        let phaseChanges: [CelestialEclipseLabAction] = changes(actions)
        guard let last: CelestialEclipseLabAction = phaseChanges.last else { return nil }
        var candidates: [CelestialEclipseLabAction] = []
        switch last {
        case .phase(let body, let offset):
            for other in 0..<level.bodies[body].period where other != offset {
                candidates.append(.phase(body, other))
            }
            for target in 0..<level.bodies.count where target != body && !level.bodies[target].fixed {
                for other in 0..<level.bodies[target].period { candidates.append(.phase(target, other)) }
            }
        case .run:
            return nil
        }
        for candidate in candidates {
            var altered: [CelestialEclipseLabAction] = phaseChanges
            altered[altered.count - 1] = candidate
            if !CelestialEclipseLabSolver.wins(level, actions: altered) { return altered + [.run] }
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
        let generated: CelestialEclipseLabGenerated = try CelestialEclipseLabExperienceCore.generated(number: number)
        let witness: CelestialEclipseLabWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(generated.level)
        let found: [String] = failures(level: generated.level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= CelestialEclipseLabSolver.workBound,
                "level \(number): solver work above bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }
}

@Suite struct CelestialEclipseLabRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try RegressionCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1708-001; SC-R02G1708-001; Q1)

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

    // MARK: Alterations (FR-R02G1708-002; SC-R02G1708-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.generated(number: number).level
        let witness: CelestialEclipseLabWitness = try RegressionCheck.witness(number)
        let found: [String] = RegressionCheck.failures(level: level, witness: witness,
                                                       plan: CelestialEclipseLabSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a body's orbit point, a body's radius, a body's fixed flag, a starting phase, a target's
    /// bodies, a target's window, the horizon and the budget, each rebuilt through the level initialiser and named
    /// first. The level is compared first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: CelestialEclipseLabGenerated = try CelestialEclipseLabExperienceCore.generated(number: number)
        let witness: CelestialEclipseLabWitness = try RegressionCheck.witness(number)
        for part in RegressionCheck.levelParts {
            let found: [String] = RegressionCheck.levelAlterationFailures(part: part, witness: witness,
                                                                          plan: generated.plan)
            RegressionCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
        }
    }

    /// The plan alteration: the solver's plan with its first phase change moved to the next offset of its body.
    @Test(arguments: alteredNumbers) func planPhaseChangeAlterationIsNamed(number: Int) throws {
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.generated(number: number).level
        let witness: CelestialEclipseLabWitness = try RegressionCheck.witness(number)
        let plan: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: CelestialEclipseLabPlan = plan, !plan.actions.isEmpty else { return }
        var actions: [CelestialEclipseLabAction] = plan.actions
        switch actions[0] {
        case .phase(let body, let offset):
            actions[0] = .phase(body, (offset + 1) % level.bodies[body].period)
        case .run:
            Issue.record("level \(number): the plan holds a run")
        }
        let copy: CelestialEclipseLabPlan = CelestialEclipseLabPlan(actions: actions,
                                                                    settingsByDepth: plan.settingsByDepth,
                                                                    work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: witness, plan: copy),
                                    number: number, part: "plan phase change")
    }

    /// Witness alterations: an action the play does not win with, a per-action fingerprint, a per-action digest and
    /// the counterexample's settings count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: CelestialEclipseLabLevel = try CelestialEclipseLabExperienceCore.generated(number: number).level
        let witness: CelestialEclipseLabWitness = try RegressionCheck.witness(number)
        let plan: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level)
        var parts: [String] = []
        var copies: [CelestialEclipseLabWitness] = []

        let actions: [CelestialEclipseLabAction]? = RegressionCheck.actionAltered(level, witness.actions)
        #expect(actions != nil, "level \(number): every altered last phase change still wins")
        if let actions: [CelestialEclipseLabAction] = actions {
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

        let counterexample: CelestialEclipseLabCounterexample =
            CelestialEclipseLabCounterexample(depth: witness.counterexample.depth,
                                              settings: witness.counterexample.settings + 1)
        parts.append("counterexample settings count")
        copies.append(RegressionCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: CelestialEclipseLabWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: copy, plan: plan),
                                        number: number, part: part)
        }
    }
}
