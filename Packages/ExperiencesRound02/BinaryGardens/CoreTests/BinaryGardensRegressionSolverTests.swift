// BinaryGardensRegressionSolverTests — feature 508 (R02-G21-08) T-R02G2108-002 (FR-R02G2108-001, 002;
// SC-R02G2108-001, 002; clarifications Q1, Q2, Q5; research R1, R2, R8, R9). The solver regression of all 100 certified
// levels in ten parameterized tests of 10 levels each (research R8: the heaviest group, levels 81 … 90, judges 9,238
// arrangements, so each test stays well under 10 s): the generated level (the manifest entry's certified candidate,
// built as `BinaryGardensExperienceCore.generated(number:)` builds it) equals the level of its witness file in
// docs/games/binary-gardens/levels (part by part and by fingerprint); the witness's actions (the rings, phases,
// luminosities and tilt, then `run`) replay on a fresh play (begun, the tutorial dismissed on a tutorial level) to a
// win on exactly the final run and not before (no proper prefix of the arrangement actions followed by `run` wins),
// within the budget, with exactly its per-action fingerprints (after `begin`, after `dismissTutorial` on a tutorial
// level, then one per action), state digests (`BinaryGardensWitness.digest(arrangement:spent:)` after each action)
// and terminal report; `BinaryGardensSolver.plan` at the band's plan length returns exactly the witness's arrangement
// actions with `arrangementsByDepth[size − 1]` equal to the counterexample's `arrangements`, `nearestMiss` and
// `nearestMissArrangement` equal to its `nearestMiss` and `arrangement`, and its work at most
// `BinaryGardensSolver.workBound` (5,000; counted, never timed) and equal to the witness difficulty's. The regression
// builds each level as the experience core does and runs the solver on it once, so a group of 10 stays under 10 s in a
// debug build; the alterations take their plans from the experience core's per-process cache. Witness files are read
// with the plain decoder (the level re-checked by its own rules; the solver is not re-run by the decode, which the
// regression does itself).
//
// The alterations (clarification Q2): the thirteen kinds, each applied to a copy of level 1 (band 1, tutorial), 41
// (band 3) or 81 (band 5) and each detected by the pure checker `BinaryGardensRegressionSolverCheck.failures`, which
// returns every failure as a string naming the level and the part ("level 41: comfortable band differs (world 1: …)"):
// a world's comfortable band, a world's lethal bound, a world's bloom band, a world's required window, a world's orbit
// (radius, speed or phase), a ring radius, a luminosity level, a star's starting ring, phase or luminosity, the lethal
// tolerance, the budget (each rebuilt through the level initialiser, the first copy the level rules accept and whose
// fingerprint changes; a refused construction is itself a failure naming the part); a plan action; a witness action
// (one the run does not win with), a per-action fingerprint or a per-action digest (each altered and named); the
// counterexample's arrangements count. The unaltered input gives no failure. The altered world, ring, luminosity level
// and star are chosen from seed 2_508 (no random source). Explicit types, plain loops, short runs. Modelled on
// MushroomWeatherRegressionSolverTests (feature 498).
import Foundation
@testable import BinaryGardensCore
import Testing

/// The helpers of the solver regression: witness files, the pure checker and the alteration builders.
private enum BinaryGardensRegressionSolverCheck {
    /// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the
    /// package, Packages).
    static let witnessDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

    /// The seed that fixes which world, ring, luminosity level and star an alteration touches first.
    static let alterationSeed: UInt64 = 2_508

    /// The stored witness of manifest number `number`, read with the plain decoder.
    static func witness(_ number: Int) throws -> BinaryGardensWitness {
        let name: String = String(BinaryGardensGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: witnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(BinaryGardensWitness.self, from: data)
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

    /// A list in words: "5, 6, 12".
    static func listText(_ values: [Int]) -> String { values.map { String($0) }.joined(separator: ", ") }

    /// Every disagreement of `stars` with the stored stars: the count, then per star its start (ring, phase,
    /// luminosity) and its freedoms.
    static func starFailures(_ stars: [BinaryGardensStar], stored: [BinaryGardensStar], name: String) -> [String] {
        var found: [String] = []
        if stars.count != stored.count {
            found.append(failure(name, "star count", "\(stars.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<stars.count {
            let lhs: BinaryGardensStar = stars[index]
            let rhs: BinaryGardensStar = stored[index]
            if lhs.ring != rhs.ring || lhs.phase != rhs.phase || lhs.luminosity != rhs.luminosity {
                found.append(failure(name, "star start", "star \(index + 1): ring \(lhs.ring), phase \(lhs.phase), "
                                        + "luminosity \(lhs.luminosity), witness ring \(rhs.ring), phase "
                                        + "\(rhs.phase), luminosity \(rhs.luminosity)"))
            }
            if lhs.ringAdjustable != rhs.ringAdjustable || lhs.phaseAdjustable != rhs.phaseAdjustable
                || lhs.luminosityAdjustable != rhs.luminosityAdjustable {
                found.append(failure(name, "star freedom", "star \(index + 1)"))
            }
        }
        return found
    }

    /// Every disagreement of `worlds` with the stored worlds: the count, then per world its orbit (radius, speed,
    /// phase), comfortable band, lethal bounds, required window and bloom band.
    static func worldFailures(_ worlds: [BinaryGardensWorld], stored: [BinaryGardensWorld], name: String) -> [String] {
        var found: [String] = []
        if worlds.count != stored.count {
            found.append(failure(name, "world count", "\(worlds.count), witness \(stored.count)"))
            return found
        }
        for index in 0..<worlds.count {
            let lhs: BinaryGardensWorld = worlds[index]
            let rhs: BinaryGardensWorld = stored[index]
            if lhs.radius != rhs.radius || lhs.speed != rhs.speed || lhs.phase != rhs.phase {
                found.append(failure(name, "world orbit", "world \(index + 1): radius \(lhs.radius), speed "
                                        + "\(lhs.speed), phase \(lhs.phase), witness radius \(rhs.radius), speed "
                                        + "\(rhs.speed), phase \(rhs.phase)"))
            }
            if lhs.comfortLow != rhs.comfortLow || lhs.comfortHigh != rhs.comfortHigh {
                found.append(failure(name, "comfortable band", "world \(index + 1): \(lhs.comfortLow) … "
                                        + "\(lhs.comfortHigh), witness \(rhs.comfortLow) … \(rhs.comfortHigh)"))
            }
            if lhs.lethalLow != rhs.lethalLow || lhs.lethalHigh != rhs.lethalHigh {
                found.append(failure(name, "lethal bound", "world \(index + 1): \(lhs.lethalLow) … "
                                        + "\(lhs.lethalHigh), witness \(rhs.lethalLow) … \(rhs.lethalHigh)"))
            }
            if lhs.window != rhs.window {
                found.append(failure(name, "required window", "world \(index + 1): \(lhs.window), witness "
                                        + "\(rhs.window)"))
            }
            if lhs.bloomLow != rhs.bloomLow || lhs.bloomHigh != rhs.bloomHigh {
                found.append(failure(name, "bloom band", "world \(index + 1): \(lhs.bloomLow) … \(lhs.bloomHigh), "
                                        + "witness \(rhs.bloomLow) … \(rhs.bloomHigh)"))
            }
        }
        return found
    }

    /// Every disagreement of `level` with the stored level, each naming the level and the part (research R2: the id,
    /// seed and difficulty, the ring radii, the star speed, the luminosity levels, the stars with their freedoms, the
    /// maximum and starting tilt, the minimum separation, the clamp radius, the worlds, the lethal tolerance, the
    /// budget, the tutorial, the phase step and the fingerprint).
    static func levelFailures(_ level: BinaryGardensLevel, stored: BinaryGardensLevel, name: String) -> [String] {
        var found: [String] = []
        if level.id != stored.id { found.append(failure(name, "id")) }
        if level.seed != stored.seed { found.append(failure(name, "seed")) }
        if level.difficulty != stored.difficulty { found.append(failure(name, "difficulty")) }
        if level.ringRadii.count != stored.ringRadii.count {
            found.append(failure(name, "ring count", "\(level.ringRadii.count), witness \(stored.ringRadii.count)"))
        } else if level.ringRadii != stored.ringRadii {
            let index: Int = firstDifference(level.ringRadii, stored.ringRadii)
            found.append(failure(name, "ring radius", "ring \(index + 1): \(level.ringRadii[index]), witness "
                                    + "\(stored.ringRadii[index])"))
        }
        if level.starSpeed != stored.starSpeed {
            found.append(failure(name, "star speed", "\(level.starSpeed), witness \(stored.starSpeed)"))
        }
        if level.luminosityLevels.count != stored.luminosityLevels.count {
            found.append(failure(name, "luminosity count", "\(listText(level.luminosityLevels)), witness "
                                    + listText(stored.luminosityLevels)))
        } else if level.luminosityLevels != stored.luminosityLevels {
            let index: Int = firstDifference(level.luminosityLevels, stored.luminosityLevels)
            found.append(failure(name, "luminosity level", "level \(index + 1): \(level.luminosityLevels[index]), "
                                    + "witness \(stored.luminosityLevels[index])"))
        }
        found += starFailures(level.stars, stored: stored.stars, name: name)
        if level.maxTilt != stored.maxTilt {
            found.append(failure(name, "maximum tilt", "\(level.maxTilt), witness \(stored.maxTilt)"))
        }
        if level.startTilt != stored.startTilt {
            found.append(failure(name, "start tilt", "\(level.startTilt), witness \(stored.startTilt)"))
        }
        if level.minimumSeparation != stored.minimumSeparation {
            found.append(failure(name, "minimum separation",
                                 "\(level.minimumSeparation), witness \(stored.minimumSeparation)"))
        }
        if level.clampRadius != stored.clampRadius {
            found.append(failure(name, "clamp radius", "\(level.clampRadius), witness \(stored.clampRadius)"))
        }
        found += worldFailures(level.worlds, stored: stored.worlds, name: name)
        if level.lethalTolerance != stored.lethalTolerance {
            found.append(failure(name, "lethal tolerance",
                                 "\(level.lethalTolerance), witness \(stored.lethalTolerance)"))
        }
        if level.budget != stored.budget {
            found.append(failure(name, "budget", "\(level.budget), witness \(stored.budget)"))
        }
        if level.tutorial != stored.tutorial { found.append(failure(name, "tutorial")) }
        if level.phaseStep != stored.phaseStep {
            found.append(failure(name, "phase step", "\(level.phaseStep), witness \(stored.phaseStep)"))
        }
        if level.fingerprint != stored.fingerprint { found.append(failure(name, "level fingerprint")) }
        return found
    }

    /// The arrangement actions of `actions` (every action but a final `run`).
    static func changes(_ actions: [BinaryGardensAction]) -> [BinaryGardensAction] {
        actions.last == .run ? Array(actions.dropLast()) : actions
    }

    /// An action in words for messages (stars 1-based).
    static func actionText(_ action: BinaryGardensAction) -> String {
        switch action {
        case .ring(let star, let index): return "star \(star + 1) to ring \(index + 1)"
        case .phase(let star, let step): return "star \(star + 1) to phase \(step)"
        case .luminosity(let star, let index): return "star \(star + 1) to luminosity \(index + 1)"
        case .tilt(let step): return "tilt \(step)"
        case .run: return "run"
        }
    }

    /// Every failure of `level`, its stored `witness` and the solver's `plan` for `level`, each a string naming the
    /// level and the part; empty when the level equals the witness's level, the witness's actions replay on a fresh
    /// play to a win on exactly the final run and not before within the budget with exactly its per-action
    /// fingerprints, digests and report, and the plan's actions are the witness's with `arrangementsByDepth[size − 1]`
    /// the counterexample's arrangements, `nearestMiss` and `nearestMissArrangement` the counterexample's nearest miss
    /// and arrangement, and work at most `BinaryGardensSolver.workBound` and equal to the witness difficulty's. The
    /// level parts come first, then the witness's actions, digests and fingerprints, then the counterexample and the
    /// plan, so an altered part is the first failure. A replay the play refuses is a failure, never a crash. Pure.
    static func failures(level: BinaryGardensLevel, witness: BinaryGardensWitness,
                         plan: BinaryGardensPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        var found: [String] = levelFailures(level, stored: witness.level, name: name)
        let witnessChanges: [BinaryGardensAction] = changes(witness.actions)

        // The witness's actions: at least one arrangement action of the witness shape, then exactly one run last.
        if witness.actions.count < 2 { found.append(failure(name, "witness action", "\(witness.actions.count)")) }
        if witness.actions.last != .run {
            found.append(failure(name, "witness action", "the last is not the run"))
        }
        for index in 0..<witnessChanges.count where !BinaryGardensWitness.isShaped(witnessChanges[index],
                                                                                     level: level) {
            found.append(failure(name, "witness action", "action \(index + 1): \(actionText(witnessChanges[index]))"))
        }

        // Not before: no proper prefix of the arrangement actions followed by the run wins.
        if !witnessChanges.isEmpty {
            for count in 0..<witnessChanges.count {
                let prefix: [BinaryGardensAction] = Array(witnessChanges.prefix(count))
                if BinaryGardensSolver.replayWins(level, actions: prefix) {
                    found.append(failure(name, "witness action", "the run wins after \(count) actions"))
                }
            }
        }

        // The replay on a fresh play: a win on exactly the final run, within the budget.
        switch BinaryGardensWitness.replay(level, actions: witness.actions) {
        case .refused(let error):
            found.append(failure(name, "witness action", "replay refused (\(error.reasonCode))"))
        case .played(let play, let fingerprints, let digests):
            if play.stage != .won {
                found.append(failure(name, "witness action", "replay does not win (stage \(play.stage.rawValue))"))
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
                let report: BinaryGardensWitnessReport = BinaryGardensWitnessReport(level: level, report: play.report)
                if report != witness.report {
                    found.append(failure(name, "report", "outcome \(report.outcome), witness "
                                            + witness.report.outcome))
                }
            }
        }

        // The counterexample: one action below the witness's plan, its nearest miss failing as stored.
        if witness.counterexample.depth != witnessChanges.count - 1 {
            found.append(failure(name, "counterexample depth",
                                 "\(witness.counterexample.depth), witness actions \(witnessChanges.count)"))
        }
        let miss: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: witness.counterexample.arrangement)
        if miss.failure != witness.counterexample.failure {
            found.append(failure(name, "counterexample failure", "the nearest miss fails otherwise"))
        }

        // The solver: exactly the witness's actions, the counterexample's arrangements, nearest miss and its
        // arrangement, work within the bound and equal to the witness difficulty's.
        guard let plan: BinaryGardensPlan = plan else {
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
        if plan.nearestMissArrangement != witness.counterexample.arrangement {
            found.append(failure(name, "counterexample arrangement", "the plan's nearest miss is another arrangement"))
        }
        var searched: Int = 0
        for count in plan.arrangementsByDepth { searched += count }
        if searched != witness.difficulty.arrangementsSearched {
            found.append(failure(name, "arrangements searched",
                                 "plan \(searched), witness \(witness.difficulty.arrangementsSearched)"))
        }
        if plan.work > BinaryGardensSolver.workBound {
            found.append(failure(name, "solver work", "\(plan.work) exceeds \(BinaryGardensSolver.workBound)"))
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
        let source: BinaryGardensLevel
        /// The ring radii.
        var ringRadii: [Int]
        /// The luminosity levels.
        var luminosityLevels: [Int]
        /// The stars (starts and freedoms).
        var stars: [BinaryGardensStar]
        /// The worlds.
        var worlds: [BinaryGardensWorld]
        /// The lethal tolerance.
        var lethalTolerance: Int
        /// The budget.
        var budget: Int

        /// The parts of `level`, unchanged.
        init(_ level: BinaryGardensLevel) {
            source = level
            ringRadii = level.ringRadii
            luminosityLevels = level.luminosityLevels
            stars = level.stars
            worlds = level.worlds
            lethalTolerance = level.lethalTolerance
            budget = level.budget
        }

        /// The level of these parts, checked by the level rules (the "already won" rule included).
        func build() throws -> BinaryGardensLevel {
            try BinaryGardensLevel(id: source.id, seed: source.seed, difficulty: source.difficulty,
                                   ringRadii: ringRadii, starSpeed: source.starSpeed,
                                   luminosityLevels: luminosityLevels, stars: stars, maxTilt: source.maxTilt,
                                   startTilt: source.startTilt, minimumSeparation: source.minimumSeparation,
                                   clampRadius: source.clampRadius, worlds: worlds, lethalTolerance: lethalTolerance,
                                   budget: budget, tutorial: source.tutorial, phaseStep: source.phaseStep)
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
    static func firstAccepted(_ level: BinaryGardensLevel, _ candidates: [LevelParts]) throws -> BinaryGardensLevel {
        for parts in candidates {
            if let copy: BinaryGardensLevel = try? parts.build(), copy.fingerprint != level.fingerprint {
                return copy
            }
        }
        guard let first: LevelParts = candidates.first else { return level }
        return try first.build()
    }

    /// A world of `old` with the given values in place of its own (nil keeps a value).
    static func world(_ old: BinaryGardensWorld, radius: Int? = nil, phase: Int? = nil, speed: Int? = nil,
                      lethalLow: Int? = nil, comfortLow: Int? = nil, comfortHigh: Int? = nil, lethalHigh: Int? = nil,
                      window: Int? = nil, bloomLow: Int? = nil, bloomHigh: Int? = nil) -> BinaryGardensWorld {
        BinaryGardensWorld(radius: radius ?? old.radius, phase: phase ?? old.phase, speed: speed ?? old.speed,
                           lethalLow: lethalLow ?? old.lethalLow, comfortLow: comfortLow ?? old.comfortLow,
                           comfortHigh: comfortHigh ?? old.comfortHigh, lethalHigh: lethalHigh ?? old.lethalHigh,
                           window: window ?? old.window, bloomLow: bloomLow ?? old.bloomLow,
                           bloomHigh: bloomHigh ?? old.bloomHigh)
    }

    /// The candidates that replace one world (worlds from seed order) by each of `variants(old)`.
    static func worldCandidates(_ level: BinaryGardensLevel,
                                _ variants: (BinaryGardensWorld) -> [BinaryGardensWorld]) -> [LevelParts] {
        var candidates: [LevelParts] = []
        for index in order(level.worlds.count) {
            for variant in variants(level.worlds[index]) {
                var parts: LevelParts = LevelParts(level)
                parts.worlds[index] = variant
                candidates.append(parts)
            }
        }
        return candidates
    }

    /// A world's comfortable band altered: its high or its low one more or one less.
    static func comfortAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        try firstAccepted(level, worldCandidates(level) { old in
            [world(old, comfortHigh: old.comfortHigh + 1), world(old, comfortHigh: old.comfortHigh - 1),
             world(old, comfortLow: old.comfortLow - 1), world(old, comfortLow: old.comfortLow + 1)]
        })
    }

    /// A world's lethal bound altered: its low or its high one less or one more.
    static func lethalAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        try firstAccepted(level, worldCandidates(level) { old in
            [world(old, lethalLow: old.lethalLow - 1), world(old, lethalLow: old.lethalLow + 1),
             world(old, lethalHigh: old.lethalHigh + 1), world(old, lethalHigh: old.lethalHigh - 1)]
        })
    }

    /// A world's bloom band altered: its low or its high one less or one more.
    static func bloomAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        try firstAccepted(level, worldCandidates(level) { old in
            [world(old, bloomLow: old.bloomLow - 1), world(old, bloomLow: old.bloomLow + 1),
             world(old, bloomHigh: old.bloomHigh + 1), world(old, bloomHigh: old.bloomHigh - 1)]
        })
    }

    /// A world's required window altered: one more, else one less.
    static func windowAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        try firstAccepted(level, worldCandidates(level) { old in
            [world(old, window: old.window + 1), world(old, window: old.window - 1)]
        })
    }

    /// A world's orbit altered: its radius one more or one less, its speed one more or one less, or its phase one step
    /// on or back (around the cycle).
    static func orbitAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        let cycle: Int = BinaryGardensSky.cycle
        return try firstAccepted(level, worldCandidates(level) { old in
            [world(old, radius: old.radius + 1), world(old, radius: old.radius - 1),
             world(old, speed: old.speed + 1), world(old, speed: old.speed - 1),
             world(old, phase: (old.phase + 1) % cycle), world(old, phase: (old.phase + cycle - 1) % cycle)]
        })
    }

    /// A ring radius altered: one more, else one less (rings from seed order; the order must stay strictly
    /// increasing).
    static func ringAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        var candidates: [LevelParts] = []
        for index in order(level.ringRadii.count) {
            for delta in [1, -1] {
                var parts: LevelParts = LevelParts(level)
                parts.ringRadii[index] = level.ringRadii[index] + delta
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A luminosity level altered: one more, else one less (levels from seed order; the order must stay strictly
    /// increasing).
    static func luminosityAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        var candidates: [LevelParts] = []
        for index in order(level.luminosityLevels.count) {
            for delta in [1, -1] {
                var parts: LevelParts = LevelParts(level)
                parts.luminosityLevels[index] = level.luminosityLevels[index] + delta
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// A star's start altered (stars from seed order): another starting ring (ascending), the phase one grid step on
    /// or back (around the cycle), or another starting luminosity (ascending); freedoms kept.
    static func starAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        let cycle: Int = BinaryGardensSky.cycle
        var candidates: [LevelParts] = []
        for index in order(level.stars.count) {
            let old: BinaryGardensStar = level.stars[index]
            var starts: [(Int, Int, Int)] = []
            for ring in level.ringRadii.indices where ring != old.ring {
                starts.append((ring, old.phase, old.luminosity))
            }
            starts.append((old.ring, (old.phase + level.phaseStep) % cycle, old.luminosity))
            starts.append((old.ring, (old.phase + cycle - level.phaseStep) % cycle, old.luminosity))
            for luminosity in level.luminosityLevels.indices where luminosity != old.luminosity {
                starts.append((old.ring, old.phase, luminosity))
            }
            for (ring, phase, luminosity) in starts {
                var parts: LevelParts = LevelParts(level)
                parts.stars[index] = BinaryGardensStar(ring: ring, phase: phase, luminosity: luminosity,
                                                       ringAdjustable: old.ringAdjustable,
                                                       phaseAdjustable: old.phaseAdjustable,
                                                       luminosityAdjustable: old.luminosityAdjustable)
                candidates.append(parts)
            }
        }
        return try firstAccepted(level, candidates)
    }

    /// The lethal tolerance altered: one more, else one less.
    static func toleranceAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        var candidates: [LevelParts] = []
        for value in [level.lethalTolerance + 1, level.lethalTolerance - 1] {
            var parts: LevelParts = LevelParts(level)
            parts.lethalTolerance = value
            candidates.append(parts)
        }
        return try firstAccepted(level, candidates)
    }

    /// The budget altered: one less, or one more at the lower end.
    static func budgetAltered(_ level: BinaryGardensLevel) throws -> BinaryGardensLevel {
        var parts: LevelParts = LevelParts(level)
        let lower: Int = BinaryGardensLevel.budgets.lowerBound
        parts.budget = level.budget > lower ? level.budget - 1 : level.budget + 1
        return try firstAccepted(level, [parts])
    }

    /// The level altered at `part` (one of ``levelParts``).
    static func altered(_ level: BinaryGardensLevel, part: String) throws -> BinaryGardensLevel {
        switch part {
        case "comfortable band": return try comfortAltered(level)
        case "lethal bound": return try lethalAltered(level)
        case "bloom band": return try bloomAltered(level)
        case "required window": return try windowAltered(level)
        case "world orbit": return try orbitAltered(level)
        case "ring radius": return try ringAltered(level)
        case "luminosity level": return try luminosityAltered(level)
        case "star start": return try starAltered(level)
        case "lethal tolerance": return try toleranceAltered(level)
        default: return try budgetAltered(level)
        }
    }

    /// The ten level parts of clarification Q2, as the checker names them.
    static let levelParts: [String] = ["comfortable band", "lethal bound", "bloom band", "required window",
                                       "world orbit", "ring radius", "luminosity level", "star start",
                                       "lethal tolerance", "budget"]

    /// The failures of the level alteration of `part`: those of the altered copy, or one failure naming `part` when
    /// the level rules refuse the copy, or one "unchanged" failure when the copy's fingerprint is the stored one.
    static func levelAlterationFailures(part: String, witness: BinaryGardensWitness,
                                        plan: BinaryGardensPlan?) -> [String] {
        let name: String = "level \(witness.number)"
        let copy: BinaryGardensLevel
        do {
            copy = try altered(witness.level, part: part)
        } catch {
            return [failure(name, part, "the level rules refuse the copy: \(error)")]
        }
        if copy.fingerprint == witness.level.fingerprint { return ["\(name): \(part) unchanged"] }
        return failures(level: copy, witness: witness, plan: plan)
    }

    /// `witness` with the given parts replaced (the internal initialiser; nothing is checked).
    static func rebuilt(_ witness: BinaryGardensWitness, actions: [BinaryGardensAction]? = nil,
                        digests: [String]? = nil, fingerprints: [String]? = nil,
                        counterexample: BinaryGardensCounterexample? = nil) -> BinaryGardensWitness {
        BinaryGardensWitness(number: witness.number, level: witness.level, actions: actions ?? witness.actions,
                             digests: digests ?? witness.digests, fingerprints: fingerprints ?? witness.fingerprints,
                             report: witness.report, counterexample: counterexample ?? witness.counterexample,
                             difficulty: witness.difficulty, skipped: witness.skipped)
    }

    /// `text` with its first hex character changed.
    static func flipped(_ text: String) -> String {
        let first: Character = text.first ?? "0"
        return (first == "0" ? "1" : "0") + text.dropFirst()
    }

    /// The arrangement before the last of `changes` on `level`: the start with every earlier change applied.
    static func arrangementBeforeLast(_ level: BinaryGardensLevel,
                                      _ changes: [BinaryGardensAction]) -> BinaryGardensArrangement {
        var arrangement: BinaryGardensArrangement = level.start
        for index in 0..<max(0, changes.count - 1) {
            arrangement = BinaryGardensSolver.after(changes[index], from: arrangement)
        }
        return arrangement
    }

    /// The witness actions with the last arrangement action altered so the run no longer wins with them: the first of
    /// the puzzle contract's legal moves at that point (from seed order, the original action excluded) that the run
    /// does not win with, the run kept last. Nil when every such move still wins.
    static func actionAltered(_ level: BinaryGardensLevel,
                              _ actions: [BinaryGardensAction]) -> [BinaryGardensAction]? {
        let witnessChanges: [BinaryGardensAction] = changes(actions)
        guard let last: BinaryGardensAction = witnessChanges.last else { return nil }
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        let position = BinaryGardensPuzzle.Position(arrangement: arrangementBeforeLast(level, witnessChanges),
                                                    actionsSpent: witnessChanges.count - 1)
        let moves: [BinaryGardensAction] = rules.moves(in: position)
        for index in order(moves.count) where moves[index] != last {
            var altered: [BinaryGardensAction] = witnessChanges
            altered[altered.count - 1] = moves[index]
            guard case .played = BinaryGardensWitness.replay(level, actions: altered) else { continue }
            if !BinaryGardensSolver.replayWins(level, actions: altered) { return altered + [.run] }
        }
        return nil
    }

    /// The plan with its first action replaced by another legal move from the start (from seed order).
    static func planAltered(_ plan: BinaryGardensPlan, level: BinaryGardensLevel) -> BinaryGardensPlan? {
        guard let first: BinaryGardensAction = plan.actions.first else { return nil }
        let rules: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        let moves: [BinaryGardensAction] = rules.moves(in: rules.initialState)
        var replacement: BinaryGardensAction?
        for index in order(moves.count) where replacement == nil && moves[index] != first {
            replacement = moves[index]
        }
        guard let replacement: BinaryGardensAction = replacement else { return nil }
        var actions: [BinaryGardensAction] = plan.actions
        actions[0] = replacement
        return BinaryGardensPlan(actions: actions, arrangement: plan.arrangement,
                                 arrangementsByDepth: plan.arrangementsByDepth, nearestMiss: plan.nearestMiss,
                                 nearestMissArrangement: plan.nearestMissArrangement, work: plan.work)
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
    /// `BinaryGardensExperienceCore.generated(number:)` builds it) equals the witness's, the solver, run once on it at
    /// the band's plan length, matches the witness, and the checker finds no failure. The solver runs once per level
    /// (the experience core's certification would run it a second time), so a group of 10 stays under 10 s.
    static func check(number: Int) throws {
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[number - 1]
        let index: Int = BinaryGardensExperienceCore.certifiedCandidates[number - 1]
        let witness: BinaryGardensWitness = try witness(number)
        #expect(entry.number == number, "level \(number): manifest entry \(entry.number)")
        #expect(witness.number == number, "level \(number): witness number \(witness.number)")
        #expect(index == witness.skipped, "level \(number): certified candidate \(index), witness \(witness.skipped)")
        let candidate: BinaryGardensLevel? = BinaryGardensGenerator.candidate(entry, index: index)
        #expect(candidate != nil, "level \(number): no candidate \(index)")
        guard let level: BinaryGardensLevel = candidate else { return }
        let parts: [String] = levelFailures(level, stored: witness.level, name: "level \(number)")
        #expect(parts.isEmpty, Comment(rawValue: parts.joined(separator: "; ")))
        #expect(level == witness.level, "level \(number): generated level differs from the witness's")
        #expect(level.fingerprint == witness.level.fingerprint,
                "level \(number): generated fingerprint differs from the witness's")
        let tutorialCount: Int = level.tutorial ? 1 : 0
        #expect(witness.fingerprints.count == 1 + tutorialCount + witness.actions.count,
                "level \(number): \(witness.fingerprints.count) fingerprints for \(witness.actions.count) actions")
        #expect(witness.digests.count == witness.actions.count,
                "level \(number): \(witness.digests.count) digests for \(witness.actions.count) actions")
        let length: Int = BinaryGardensBandProfile.of(band: entry.band).plan
        let plan: BinaryGardensPlan? = BinaryGardensSolver.plan(level, maxDepth: length)
        let found: [String] = failures(level: level, witness: witness, plan: plan)
        #expect(found.isEmpty, Comment(rawValue: found.joined(separator: "; ")))
        #expect((plan?.work ?? Int.max) <= BinaryGardensSolver.workBound, "level \(number): solver work above bound")
        guard let plan: BinaryGardensPlan = plan else { return }
        #expect(plan.size == length, "level \(number): plan size \(plan.size), band length \(length)")
        #expect(BinaryGardensDifficulty(level: level, plan: plan) == witness.difficulty,
                "level \(number): difficulty differs")
    }
}

@Suite struct BinaryGardensRegressionSolverTests {
    /// The levels altered: level 1 (band 1, a tutorial level), level 41 (band 3) and level 81 (band 5).
    static let alteredNumbers: [Int] = [1, 41, 81]

    /// Checks level `index + 1` of group `group` (levels 10·(group − 1) + 1 … 10·group).
    static func check(group: Int, index: Int) throws {
        #expect(index >= 0 && index < 10, "group \(group): index \(index)")
        try BinaryGardensRegressionSolverCheck.check(number: (group - 1) * 10 + index + 1)
    }

    // MARK: The regression, ten parameterized tests of 10 levels (FR-R02G2108-001; SC-R02G2108-001; Q1)

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

    // MARK: Alterations (FR-R02G2108-002; SC-R02G2108-002; clarification Q2)

    /// The unaltered level, witness and plan give no failure, so every failure found below is the alteration's.
    @Test(arguments: alteredNumbers) func theUnalteredInputPasses(number: Int) throws {
        let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
        let witness: BinaryGardensWitness = try BinaryGardensRegressionSolverCheck.witness(number)
        let found: [String] = BinaryGardensRegressionSolverCheck.failures(level: generated.level, witness: witness,
                                                                          plan: generated.plan)
        #expect(found.isEmpty, "level \(number): \(found.joined(separator: "; "))")
    }

    /// Level alterations: a world's comfortable band, lethal bound, bloom band, required window and orbit, a ring
    /// radius, a luminosity level, a star's start, the lethal tolerance and the budget, each rebuilt through the level
    /// initialiser and named first. The level is compared first, so the unaltered plan is passed and no altered level
    /// is planned.
    @Test(arguments: alteredNumbers) func levelAlterationsAreNamed(number: Int) throws {
        let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
        let witness: BinaryGardensWitness = try BinaryGardensRegressionSolverCheck.witness(number)
        var checked: Int = 0
        for part in BinaryGardensRegressionSolverCheck.levelParts {
            let found: [String] = BinaryGardensRegressionSolverCheck.levelAlterationFailures(
                part: part, witness: witness, plan: generated.plan)
            BinaryGardensRegressionSolverCheck.expectNamed(found, number: number, part: part)
            #expect(!(found.first ?? "").contains("refuse"),
                    "level \(number) alteration \(part): no accepted copy (\(found.first ?? "(none)"))")
            checked += 1
        }
        #expect(checked == 10, "level \(number): \(checked) level alterations, expected 10")
    }

    /// The star start alteration changes exactly one star's ring, phase or luminosity and keeps its freedoms.
    @Test(arguments: alteredNumbers) func theStarAlterationTouchesOneStarStart(number: Int) throws {
        let witness: BinaryGardensWitness = try BinaryGardensRegressionSolverCheck.witness(number)
        let copy: BinaryGardensLevel = try BinaryGardensRegressionSolverCheck.starAltered(witness.level)
        var changed: Int = 0
        for index in copy.stars.indices where copy.stars[index] != witness.level.stars[index] {
            changed += 1
            let lhs: BinaryGardensStar = copy.stars[index]
            let rhs: BinaryGardensStar = witness.level.stars[index]
            #expect(lhs.ringAdjustable == rhs.ringAdjustable && lhs.phaseAdjustable == rhs.phaseAdjustable
                    && lhs.luminosityAdjustable == rhs.luminosityAdjustable,
                    "level \(number): star \(index + 1) freedoms changed")
        }
        #expect(changed == 1, "level \(number): \(changed) stars changed")
    }

    /// The plan alteration: the solver's plan with its first action replaced by another legal move.
    @Test(arguments: alteredNumbers) func planActionAlterationIsNamed(number: Int) throws {
        let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
        let witness: BinaryGardensWitness = try BinaryGardensRegressionSolverCheck.witness(number)
        let copy: BinaryGardensPlan? = BinaryGardensRegressionSolverCheck.planAltered(generated.plan,
                                                                                    level: generated.level)
        #expect(copy != nil, "level \(number): the plan has no action to alter")
        guard let copy: BinaryGardensPlan = copy else { return }
        #expect(copy != generated.plan, "level \(number): plan unchanged")
        let found: [String] = BinaryGardensRegressionSolverCheck.failures(level: generated.level, witness: witness,
                                                                          plan: copy)
        BinaryGardensRegressionSolverCheck.expectNamed(found, number: number, part: "plan action")
    }

    /// Witness alterations: an action the run does not win with, a per-action fingerprint, a per-action digest and the
    /// counterexample's arrangements count.
    @Test(arguments: alteredNumbers) func witnessAlterationsAreNamed(number: Int) throws {
        let generated: BinaryGardensGenerated = try BinaryGardensExperienceCore.generated(number: number)
        let level: BinaryGardensLevel = generated.level
        let witness: BinaryGardensWitness = try BinaryGardensRegressionSolverCheck.witness(number)
        var parts: [String] = []
        var copies: [BinaryGardensWitness] = []

        let actions: [BinaryGardensAction]? = BinaryGardensRegressionSolverCheck.actionAltered(level, witness.actions)
        #expect(actions != nil, "level \(number): every altered last action still wins")
        if let actions: [BinaryGardensAction] = actions {
            parts.append("witness action")
            copies.append(BinaryGardensRegressionSolverCheck.rebuilt(witness, actions: actions))
        }

        var fingerprints: [String] = witness.fingerprints
        let fingerprintIndex: Int = fingerprints.count / 2
        fingerprints[fingerprintIndex] = BinaryGardensRegressionSolverCheck.flipped(fingerprints[fingerprintIndex])
        parts.append("per-action fingerprint")
        copies.append(BinaryGardensRegressionSolverCheck.rebuilt(witness, fingerprints: fingerprints))

        var digests: [String] = witness.digests
        let digestIndex: Int = digests.count / 2
        digests[digestIndex] = BinaryGardensRegressionSolverCheck.flipped(digests[digestIndex])
        parts.append("per-action digest")
        copies.append(BinaryGardensRegressionSolverCheck.rebuilt(witness, digests: digests))

        let stored: BinaryGardensCounterexample = witness.counterexample
        let counterexample: BinaryGardensCounterexample = BinaryGardensCounterexample(
            depth: stored.depth, arrangements: stored.arrangements + 1, nearestMiss: stored.nearestMiss,
            arrangement: stored.arrangement, failure: stored.failure)
        parts.append("counterexample arrangements count")
        copies.append(BinaryGardensRegressionSolverCheck.rebuilt(witness, counterexample: counterexample))

        #expect(copies.count == 4)
        for position in 0..<copies.count {
            let part: String = parts[position]
            let copy: BinaryGardensWitness = copies[position]
            #expect(copy != witness, "level \(number) alteration \(part): unchanged")
            let found: [String] = BinaryGardensRegressionSolverCheck.failures(level: level, witness: copy,
                                                                              plan: generated.plan)
            BinaryGardensRegressionSolverCheck.expectNamed(found, number: number, part: part)
        }
    }
}
