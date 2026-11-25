// StarlitCartoucheRegressionSolverTests — feature 458 (R02-G16-08) T-R02G1608-002 (FR-R02G1608-001, 002;
// SC-R02G1608-001, 002; clarifications Q1, Q2). The solver regression of all 100 certified levels in ten parameterized
// tests of 10 levels each (clarification Q1: certifying one level takes a few milliseconds in a debug build, so each
// test stays well under 10 s): the generated level equals the level of its witness file in
// docs/games/starlit-cartouche/levels (part by part and by fingerprint); the witness's legs replay on a fresh play
// (begun, the tutorial dismissed) to a win on exactly the last leg and not before, within the budget, with exactly its
// per-action fingerprints (after `begin`, after `dismissTutorial` on a tutorial level, then one per leg) and state
// digests (`StarlitCartoucheWitness.digest(star:beat:drawn:)` after each leg); `StarlitCartoucheSolver.plan` returns
// exactly the witness's legs with `statesByDepth[size − 1]` equal to the counterexample's `states` at depth size − 1,
// and its work is at most `StarlitCartoucheSolver.workBound` (counted, never timed) and equal to the witness
// difficulty's. Levels come from the experience core's per-process cache; witness files are read with the plain decoder
// (the level re-checked by its own rules; the solver is not re-run by the decode, which the regression does itself).
//
// The alterations (clarification Q2): the thirteen kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `RegressionCheck.failures`, which returns every failure
// as a string naming the level and the part ("level 41: star orbit differs (star 3: …)"): a star's orbit, a star's
// window, a corridor's ends, a hazard, the range, the beacon, the deadline, a symbol stroke, the budget (each rebuilt
// through the level initialiser, the first copy the level rules accept and whose fingerprint changes; a refused
// construction is itself a failure naming the part); a plan leg; a witness action (one the play does not win with), a
// per-action fingerprint or digest (both are altered and named); the counterexample's state count. The honest input
// gives no failure. The altered star, corridor, hazard and stroke are chosen from seed 2_458 (no random source).
// Explicit types, plain loops, short runs. Modelled on VoxelOrigamiRegressionSolverTests (feature 448).
import Foundation
@testable import StarlitCartoucheCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum RegressionCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, StarlitCartouche, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/starlit-cartouche/levels", isDirectory: true)

    /// The seed that fixes which star, corridor, hazard and stroke an alteration touches first.
    static let alterationSeed: UInt64 = 2_458

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> StarlitCartoucheWitness {
        let name: String = String(StarlitCartoucheGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(StarlitCartoucheWitness.self, from: data)
    }

    /// The failure string of `part` for `name`: "level N: <part> differs (detail)".
    static func failure(_ name: String, _ part: String, _ detail: String = "") -> String {
        let suffix: String = detail.isEmpty ? "" : " (\(detail))"
        return "\(name): \(part) differs\(suffix)"
    }

    /// Every disagreement of `stars` with the stored stars: the count, then per star its orbit, glyph and window.
    static func starFailures(_ stars: [StarlitCartoucheStar], stored: [StarlitCartoucheStar],
                             name: String) -> [String] {
        var found: [String] = []
        if stars.count != stored.count {
            found.append(failure(name, "star count", "\(stars.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<stars.count {
            let lhs: StarlitCartoucheStar = stars[index]
            let rhs: StarlitCartoucheStar = stored[index]
            if lhs.orbit != rhs.orbit {
                found.append(failure(name, "star orbit", "star \(index): \(String(describing: lhs.orbit)), "
                                        + "witness \(String(describing: rhs.orbit))"))
            }
            if lhs.glyph != rhs.glyph { found.append(failure(name, "star glyph", "star \(index)")) }
            if lhs.open != rhs.open || lhs.close != rhs.close {
                found.append(failure(name, "star window", "star \(index): \(lhs.open)…\(lhs.close), "
                                        + "witness \(rhs.open)…\(rhs.close)"))
            }
        }
        return found
    }

    /// Every disagreement of `corridors` with the stored corridors: the count, then per corridor its ends and travel.
    static func corridorFailures(_ corridors: [StarlitCartoucheCorridor], stored: [StarlitCartoucheCorridor],
                                 name: String) -> [String] {
        var found: [String] = []
        if corridors.count != stored.count {
            found.append(failure(name, "corridor count", "\(corridors.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<corridors.count {
            let lhs: StarlitCartoucheCorridor = corridors[index]
            let rhs: StarlitCartoucheCorridor = stored[index]
            if lhs.a != rhs.a || lhs.b != rhs.b {
                found.append(failure(name, "corridor ends",
                                     "corridor \(index): \(lhs.a)–\(lhs.b), witness \(rhs.a)–\(rhs.b)"))
            }
            if lhs.travel != rhs.travel {
                found.append(failure(name, "corridor travel",
                                     "corridor \(index): \(lhs.travel), witness \(rhs.travel)"))
            }
        }
        return found
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (stars first, then the
    /// range, the corridors, the hazards, the start, the beacon, the deadline, the symbol, the budget and the
    /// fingerprint).
    static func levelFailures(_ level: StarlitCartoucheLevel, stored: StarlitCartoucheLevel,
                              name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        found += starFailures(level.stars, stored: stored.stars, name: name)
        if level.range != stored.range {
            found.append(failure(name, "range", "\(level.range), witness \(stored.range)"))
        }
        found += corridorFailures(level.corridors, stored: stored.corridors, name: name)
        if level.hazards.count != stored.hazards.count {
            found.append(failure(name, "hazard", "count \(level.hazards.count), witness \(stored.hazards.count)"))
        } else {
            for index in 0..<level.hazards.count where level.hazards[index] != stored.hazards[index] {
                let lhs: StarlitCartoucheHazard = level.hazards[index]
                let rhs: StarlitCartoucheHazard = stored.hazards[index]
                found.append(failure(name, "hazard", "hazard \(index): corridor \(lhs.corridor) \(lhs.from)…\(lhs.to), "
                                        + "witness corridor \(rhs.corridor) \(rhs.from)…\(rhs.to)"))
            }
        }
        if level.start != stored.start {
            found.append(failure(name, "start", "\(level.start), witness \(stored.start)"))
        }
        if level.beacon != stored.beacon {
            found.append(failure(name, "beacon", "\(level.beacon), witness \(stored.beacon)"))
        }
        if level.deadline != stored.deadline {
            found.append(failure(name, "deadline", "\(level.deadline), witness \(stored.deadline)"))
        }
        if level.symbol != stored.symbol {
            found.append(failure(name, "symbol stroke", "\(level.symbol), witness \(stored.symbol)"))
        }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The index of the first entry where `lhs` and `rhs` differ (the shorter count when one is a prefix).
    static func firstDifference<T: Equatable>(_ lhs: [T], _ rhs: [T]) -> Int {
        var index: Int = 0
        while index < min(lhs.count, rhs.count), lhs[index] == rhs[index] { index += 1 }
        return index
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's legs replay on a fresh play
    /// to a win on exactly the last leg and not before within the budget with exactly its per-action fingerprints and
    /// digests, and the plan's legs are the witness's with `statesByDepth[size − 1]` the counterexample's states at
    /// depth size − 1 and work at most `StarlitCartoucheSolver.workBound` and equal to the witness difficulty's. The
    /// level parts come first, then the witness's actions, digests and fingerprints, then the counterexample and the
    /// plan, so an altered part is the first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: StarlitCartoucheLevel, witness: StarlitCartoucheWitness,
                         plan: StarlitCartouchePlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)

        // The witness's legs: at least one, each to a known star with a wait of 0 … 8.
        if witness.actions.isEmpty { found.append(failure(name, "witness action", "no action")) }
        for (index, action) in witness.actions.enumerated() {
            switch action {
            case .leg(let star, let wait):
                if star < 0 || star >= level.stars.count || !StarlitCartoucheChart.waits.contains(wait) {
                    found.append(failure(name, "witness action", "action \(index): star \(star) wait \(wait)"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the last leg and not before, within the budget.
        if let run = StarlitCartoucheWitness.replay(level, actions: witness.actions) {
            if run.endedEarly {
                found.append(failure(name, "witness action", "the play ends before the last leg"))
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

        // The counterexample: one leg below the witness's plan.
        if witness.counterexample.depth != witness.actions.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness legs \(witness.actions.count)"))
        }

        // The solver: exactly the witness's legs, the counterexample's states, work within the bound.
        guard let plan: StarlitCartouchePlan = plan else {
            found.append(failure(name, "plan leg", "the solver finds no plan"))
            return found
        }
        if plan.legs != witness.actions {
            found.append(failure(name, "plan leg", "leg \(firstDifference(plan.legs, witness.actions) + 1) of "
                                    + "\(plan.size), witness \(witness.actions.count)"))
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
        if plan.work > StarlitCartoucheSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(StarlitCartoucheSolver.workBound)"))
        }
        if plan.work != witness.difficulty.work {
            found.append(failure(name, "solver work", "\(plan.work), witness \(witness.difficulty.work)"))
        }
        return found
    }

    // MARK: Alteration builders

    /// The editable parts of a level, rebuilt through the level initialiser by ``build()``.
    struct LevelParts {
        /// The level the parts came from (id, seed, difficulty, start and tutorial are kept).
        let source: StarlitCartoucheLevel
        /// The stars.
        var stars: [StarlitCartoucheStar]
        /// The range.
        var range: Int
        /// The corridors.
        var corridors: [StarlitCartoucheCorridor]
        /// The hazards.
        var hazards: [StarlitCartoucheHazard]
        /// The beacon.
        var beacon: Int
        /// The deadline.
        var deadline: Int
        /// The symbol.
        var symbol: [Int]
        /// The budget.
        var budget: Int

        /// The parts of `level`, unchanged.
        init(_ level: StarlitCartoucheLevel) {
            source = level
            stars = level.stars
            range = level.range
            corridors = level.corridors
            hazards = level.hazards
            beacon = level.beacon
            deadline = level.deadline
            symbol = level.symbol
            budget = level.budget
        }

        /// The level of these parts, checked by the level rules.
        func build() throws -> StarlitCartoucheLevel {
            try StarlitCartoucheLevel(id: source.id, seed: source.seed, difficulty: source.difficulty, stars: stars,
                                      range: range, corridors: corridors, hazards: hazards, start: source.start,
                                      beacon: beacon, deadline: deadline, symbol: symbol, budget: budget,
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
    static func firstAccepted(_ level: StarlitCartoucheLevel, _ candidates: [LevelParts]) throws
        -> StarlitCartoucheLevel {
        for parts in candidates {
            if let copy: StarlitCartoucheLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A star's orbit altered: its first position moved one unit along x, y or z.
    static func orbitAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        let steps: [StarlitCartoucheVector] = [StarlitCartoucheVector(1, 0, 0), StarlitCartoucheVector(-1, 0, 0),
                                               StarlitCartoucheVector(0, 1, 0), StarlitCartoucheVector(0, -1, 0),
                                               StarlitCartoucheVector(0, 0, 1), StarlitCartoucheVector(0, 0, -1)]
        for index in order(level.stars.count) {
            let old: StarlitCartoucheStar = level.stars[index]
            for step in steps {
                let first: StarlitCartoucheVector = old.orbit[0]
                var orbit: [StarlitCartoucheVector] = old.orbit
                orbit[0] = StarlitCartoucheVector(first.x + step.x, first.y + step.y, first.z + step.z)
                var parts: LevelParts = LevelParts(level)
                parts.stars[index] = StarlitCartoucheStar(orbit: orbit, glyph: old.glyph, open: old.open,
                                                          close: old.close)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A star's window altered: its close one later or earlier, or its open one later or earlier.
    static func windowAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        for index in order(level.stars.count) {
            let old: StarlitCartoucheStar = level.stars[index]
            let windows: [(Int, Int)] = [(old.open, old.close + 1), (old.open, old.close - 1),
                                         (old.open + 1, old.close), (old.open - 1, old.close)]
            for (open, close) in windows {
                var parts: LevelParts = LevelParts(level)
                parts.stars[index] = StarlitCartoucheStar(orbit: old.orbit, glyph: old.glyph, open: open, close: close)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A corridor's ends altered: one end moved to another star, the pair not already joined.
    static func corridorEndsAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        for index in order(level.corridors.count) {
            let old: StarlitCartoucheCorridor = level.corridors[index]
            for star in 0..<level.stars.count where star != old.a && star != old.b {
                let moved: [StarlitCartoucheCorridor] = [StarlitCartoucheCorridor(old.a, star, travel: old.travel),
                                                         StarlitCartoucheCorridor(star, old.b, travel: old.travel)]
                for corridor in moved {
                    var parts: LevelParts = LevelParts(level)
                    parts.corridors[index] = corridor
                    candidates.append(parts)
                }
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A hazard altered: its interval one beat longer or its corridor another; a level without hazards gains one.
    static func hazardAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        for index in order(level.hazards.count) {
            let old: StarlitCartoucheHazard = level.hazards[index]
            var longer: LevelParts = LevelParts(level)
            longer.hazards[index] = StarlitCartoucheHazard(corridor: old.corridor, from: old.from, to: old.to + 1)
            candidates.append(longer)
            var moved: LevelParts = LevelParts(level)
            moved.hazards[index] = StarlitCartoucheHazard(corridor: (old.corridor + 1) % level.corridors.count,
                                                          from: old.from, to: old.to)
            candidates.append(moved)
        }
        if level.hazards.count < StarlitCartoucheLevel.maxHazards {
            var added: LevelParts = LevelParts(level)
            added.hazards.append(StarlitCartoucheHazard(corridor: 0, from: 0, to: 0))
            candidates.append(added)
        }
        return try firstAccepted(level, candidates)
    }

    /// The range altered: one less, or one more at the lower end.
    static func rangeAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var parts: LevelParts = LevelParts(level)
        parts.range = level.range > StarlitCartoucheLevel.ranges.lowerBound ? level.range - 1 : level.range + 1
        return try firstAccepted(level, [parts])
    }

    /// The beacon altered: another star, from the next index around.
    static func beaconAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        for offset in 1..<level.stars.count {
            var parts: LevelParts = LevelParts(level)
            parts.beacon = (level.beacon + offset) % level.stars.count
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The deadline altered: one beat earlier, or one later at the lower end.
    static func deadlineAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = StarlitCartoucheLevel.deadlines.lowerBound
        parts.deadline = level.deadline > lower ? level.deadline - 1 : level.deadline + 1
        return try firstAccepted(level, [parts])
    }

    /// A symbol stroke altered: a stroke replaced by a corridor outside the symbol (kept sorted); when every corridor
    /// is a stroke, a stroke removed.
    static func symbolAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var candidates: [LevelParts] = []
        for index in order(level.symbol.count) {
            for corridor in 0..<level.corridors.count where !level.symbol.contains(corridor) {
                var parts: LevelParts = LevelParts(level)
                parts.symbol[index] = corridor
                parts.symbol.sort()
                candidates.append(parts)
            }
        }
        if level.symbol.count > 1 {
            for index in order(level.symbol.count) {
                var parts: LevelParts = LevelParts(level)
                parts.symbol.remove(at: index)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: StarlitCartoucheLevel) throws -> StarlitCartoucheLevel {
        var parts: LevelParts = LevelParts(level)
        parts.budget = level.budget > StarlitCartoucheLevel.budgets.lowerBound ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: StarlitCartoucheLevel, part: String) throws -> StarlitCartoucheLevel {
        switch part {
        case "star orbit": return try orbitAltered(level)
        case "star window": return try windowAltered(level)
        case "corridor ends": return try corridorEndsAltered(level)
        case "hazard": return try hazardAltered(level)
        case "range": return try rangeAltered(level)
        case "beacon": return try beaconAltered(level)
        case "deadline": return try deadlineAltered(level)
        case "symbol stroke": return try symbolAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The nine level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["star orbit", "star window", "corridor ends", "hazard", "range", "beacon",
                                       "deadline", "symbol stroke", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: StarlitCartoucheWitness,
                                        plan: StarlitCartouchePlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: StarlitCartoucheLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: StarlitCartoucheWitness, actions: [StarlitCartoucheAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: StarlitCartoucheCounterexample? = nil) -> StarlitCartoucheWitness {
        StarlitCartoucheWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                                digests: digests ?? witness.digests,
                                fingerprints: fingerprints ?? witness.fingerprints,
                                counterexample: counterexample ?? witness.counterexample,
                                difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The witness actions with the last leg changed so the play no longer wins with them: another wait, else another
    /// star with each wait; nil when every such change still wins.
    static func actionAltered(_ level: StarlitCartoucheLevel,
                              _ actions: [StarlitCartoucheAction]) -> [StarlitCartoucheAction]? {
        guard let last: StarlitCartoucheAction = actions.last else { return nil }
        var candidates: [StarlitCartoucheAction] = []
        switch last {
        case .leg(let star, let wait):
            for other in StarlitCartoucheChart.waits where other != wait { candidates.append(.leg(star, other)) }
            for target in 0..<level.stars.count where target != star {
                for other in StarlitCartoucheChart.waits { candidates.append(.leg(target, other)) }
            }
        }
        for candidate in candidates {
            var altered: [StarlitCartoucheAction] = actions
            altered[altered.count - 1] = candidate
            if !StarlitCartoucheSolver.wins(level, actions: altered) { return altered }
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
        let generated: StarlitCartoucheGenerated = try StarlitCartoucheExperienceCore.generated(number: number)
        let witness: StarlitCartoucheWitness = try witness(number)
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(generated.level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(generated.level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let plan: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(generated.level,
                                                                      workBound: StarlitCartoucheSolver.workBound)
        let found: [String] = failures(level: generated.level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect(plan == generated.plan, "level \(number): solver plan differs from the generator's")
        #expect((plan?.work ?? Int.max) <= StarlitCartoucheSolver.workBound,
                "level \(number): solver work above bound")
        #expect(generated.skipped == witness.skipped, "level \(number): skipped differs")
        #expect(generated.difficulty == witness.difficulty, "level \(number): difficulty differs")
    }
}

@Suite struct StarlitCartoucheRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try RegressionCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G1608-001; SC-R02G1608-001; Q1)

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

    // MARK: Alterations (FR-R02G1608-002; SC-R02G1608-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let level: StarlitCartoucheLevel = try StarlitCartoucheExperienceCore.generated(number: number).level
        let witness: StarlitCartoucheWitness = try RegressionCheck.witness(number)
        let found: [String] = RegressionCheck.failures(level: level, witness: witness,
                                                       plan: StarlitCartoucheSolver.plan(level))
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a star's orbit, a star's window, a corridor's ends, a hazard, the range, the beacon, the
    /// deadline, a symbol stroke and the budget, each rebuilt through the level initialiser and named first. The level
    /// is compared first, so the unaltered plan is passed and no altered level is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: StarlitCartoucheGenerated = try StarlitCartoucheExperienceCore.generated(number: number)
        let witness: StarlitCartoucheWitness = try RegressionCheck.witness(number)
        for part in RegressionCheck.levelParts {
            let found: [String] = RegressionCheck.levelAlterationFailures(part: part, witness: witness,
                                                                          plan: generated.plan)
            RegressionCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
        }
    }

    /// The plan alteration: the solver's plan with its first leg's wait changed by one beat.
    @Test(arguments: alteredNumbers) func planLegAlterationIsNamed(number: Int) throws {
        let level: StarlitCartoucheLevel = try StarlitCartoucheExperienceCore.generated(number: number).level
        let witness: StarlitCartoucheWitness = try RegressionCheck.witness(number)
        let plan: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(level)
        #expect(plan != nil, "level \(number): no plan")
        guard let plan: StarlitCartouchePlan = plan else { return }
        var legs: [StarlitCartoucheAction] = plan.legs
        switch legs[0] {
        case .leg(let star, let wait):
            legs[0] = .leg(star, wait < StarlitCartoucheChart.waits.upperBound ? wait + 1 : wait - 1)
        }
        let copy: StarlitCartouchePlan = StarlitCartouchePlan(legs: legs, statesByDepth: plan.statesByDepth,
                                                              work: plan.work)
        #expect(copy != plan, "level \(number): plan unchanged")
        RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: witness, plan: copy),
                                    number: number, part: "plan leg")
    }

    /// Witness alterations: an action the play does not win with, a per-action fingerprint, a per-action digest and
    /// the counterexample's state count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let level: StarlitCartoucheLevel = try StarlitCartoucheExperienceCore.generated(number: number).level
        let witness: StarlitCartoucheWitness = try RegressionCheck.witness(number)
        let plan: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(level)
        var parts: [String] = []
        var copies: [StarlitCartoucheWitness] = []

        let actions: [StarlitCartoucheAction]? = RegressionCheck.actionAltered(level, witness.actions)
        #expect(actions != nil, "level \(number): every altered last leg still wins")
        if let actions: [StarlitCartoucheAction] = actions {
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

        let counterexample: StarlitCartoucheCounterexample =
            StarlitCartoucheCounterexample(depth: witness.counterexample.depth,
                                           states: witness.counterexample.states + 1)
        parts.append("counterexample state count")
        copies.append(RegressionCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: StarlitCartoucheWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            RegressionCheck.expectNamed(RegressionCheck.failures(level: level, witness: copy, plan: plan),
                                        number: number, part: part)
        }
    }
}
