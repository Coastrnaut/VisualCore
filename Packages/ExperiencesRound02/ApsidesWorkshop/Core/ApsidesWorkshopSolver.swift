// ApsidesWorkshopSolver — feature 472 (R02-G18-02) T-R02G1802-003 (FR-R02G1802-002; SC-R02G1802-001, 002, 005;
// clarification Q2; research R1 … R3, R5). The bounded search over eccentricity, direction and size samples that
// certifies an Apsides Workshop level. A later tuning of the same lever overrides an earlier one, so the orbits
// reachable with at most d tunings are exactly the valid orbits that differ from the start in at most d levers (the
// periapsis knob — eccentricity and direction together — and the size). Depth 1 lists every valid knob setting
// (eccentricity 0 … 15, then direction 0 … 23, the start's pair excluded) at the start's size, then every valid size 8
// … 48 (the start's excluded) at the start's knob; depth 2 lists every valid orbit with both a different size and a
// different knob, size outermost, then eccentricity, then direction. Each orbit is judged by the kernel's report
// through Kepler anomaly inversion, the apsis targets checked first from the orbit's steps alone (an orbit failing one
// cannot win, so its positions are not computed). The first winning orbit ends the search and is minimal; the orbits
// judged at every smaller depth, none winning, are the proof. Two tunings are ordered size first when the winning
// eccentricity is not lower than the start's, the knob first otherwise, so the orbit in between keeps the lower
// eccentricity and is valid. Work = orbits judged (the start included), bounded at 16 000 as a guard above the largest
// search space (1 + 423 + 13 880). Modelled on `CelestialEclipseLabSolver` (feature 462).
//
// Feature 475 (R02-G18-05) T-R02G1805-001 (FR-R02G1805-002; clarification Q1): `plan(_:from:maxTunings:workBound:)`
// searches the same way from any valid orbit, judging that orbit first (a plan of no tunings when it already wins) and
// limiting the depth to `maxTunings`; the certifying `plan(_:workBound:)` is that entry at the level's starting orbit,
// so every certified plan, witness and work count is unchanged (the start, which never wins, counts as work 1).

/// A certified plan: the tunings to the first winning orbit at the smallest depth, with its proof and work.
public struct ApsidesWorkshopPlan: Sendable, Equatable, Codable {
    /// The tunings of the plan in a valid order; the `play` is not part of it.
    public let actions: [ApsidesWorkshopAction]
    /// The winning orbit the tunings reach.
    public let orbit: ApsidesWorkshopOrbit
    /// The orbits judged at depths 0 … size − 1 (depth 0 is the start alone: 1); none won.
    public let orbitsByDepth: [Int]
    /// The orbits judged before the plan was found, the start and the winning orbit included.
    public let work: Int

    /// A plan of the given values.
    public init(actions: [ApsidesWorkshopAction], orbit: ApsidesWorkshopOrbit, orbitsByDepth: [Int], work: Int) {
        self.actions = actions
        self.orbit = orbit
        self.orbitsByDepth = orbitsByDepth
        self.work = work
    }

    /// The number of tunings.
    public var size: Int { actions.count }

    /// The orbits judged at every smaller depth together.
    public var orbitsSearched: Int { orbitsByDepth.reduce(0, +) }
}

/// The depth search that certifies a level's minimal plan.
public enum ApsidesWorkshopSolver {
    /// The most orbits judged per level (a guard above the largest search space, 14 304).
    public static let workBound: Int = 16_000

    /// The valid orbits that differ from `start` in exactly `depth` levers (1 or 2), in search order; any other depth
    /// gives no orbits.
    public static func orbits(from start: ApsidesWorkshopOrbit, depth: Int) -> [ApsidesWorkshopOrbit] {
        var result: [ApsidesWorkshopOrbit] = []
        switch depth {
        case 1:
            for k in ApsidesWorkshopOrbit.eccentricities {
                for d in ApsidesWorkshopOrbit.directions where k != start.eccentricity || d != start.direction {
                    let orbit = ApsidesWorkshopOrbit(size: start.size, eccentricity: k, direction: d)
                    if orbit.isValid { result.append(orbit) }
                }
            }
            for a in ApsidesWorkshopOrbit.sizes where a != start.size {
                let orbit = ApsidesWorkshopOrbit(size: a, eccentricity: start.eccentricity,
                                                 direction: start.direction)
                if orbit.isValid { result.append(orbit) }
            }
        case 2:
            for a in ApsidesWorkshopOrbit.sizes where a != start.size {
                for k in ApsidesWorkshopOrbit.eccentricities {
                    for d in ApsidesWorkshopOrbit.directions where k != start.eccentricity || d != start.direction {
                        let orbit = ApsidesWorkshopOrbit(size: a, eccentricity: k, direction: d)
                        if orbit.isValid { result.append(orbit) }
                    }
                }
            }
        default:
            break
        }
        return result
    }

    /// The tunings from `start` to `target` in a valid order: the size first when the target's eccentricity is not
    /// lower than the start's, the knob first otherwise; a lever that does not change gives no tuning.
    public static func tunings(from start: ApsidesWorkshopOrbit,
                               to target: ApsidesWorkshopOrbit) -> [ApsidesWorkshopAction] {
        let knobChanges: Bool = start.eccentricity != target.eccentricity || start.direction != target.direction
        let sizeChanges: Bool = start.size != target.size
        let knob: ApsidesWorkshopAction = .periapsis(target.eccentricity, target.direction)
        let size: ApsidesWorkshopAction = .size(target.size)
        if knobChanges && sizeChanges {
            return target.eccentricity >= start.eccentricity ? [size, knob] : [knob, size]
        }
        if knobChanges { return [knob] }
        if sizeChanges { return [size] }
        return []
    }

    /// Whether `orbit` wins `level`: the apsis targets are checked first from the orbit's steps (sector and distance),
    /// then the kernel's full report decides.
    public static func wins(_ level: ApsidesWorkshopLevel, orbit: ApsidesWorkshopOrbit) -> Bool {
        guard orbit.isValid else { return false }
        for target in level.targets where target.kind != .sweep {
            let periapsis: Bool = target.kind == .periapsis
            let sector: Int = periapsis ? orbit.periapsisSector : orbit.apoapsisSector
            let distance: Int = periapsis ? orbit.periapsisDistance : orbit.apoapsisDistance
            if sector != target.sector || distance < target.low || distance > target.high { return false }
        }
        return ApsidesWorkshopSky.report(level, orbit: orbit).wins
    }

    /// The minimal plan of `level`, or nil when no orbit within two tunings wins or the work bound is reached: exactly
    /// ``plan(_:from:maxTunings:workBound:)`` at the level's starting orbit (which the level rules guarantee does not
    /// win, so its results, witnesses and work are those of the search from the start).
    public static func plan(_ level: ApsidesWorkshopLevel, workBound: Int = workBound) -> ApsidesWorkshopPlan? {
        plan(level, from: level.orbit, maxTunings: 2, workBound: workBound)
    }

    /// The minimal plan of `level` from `orbit` (feature 475, clarification Q1): depth 0 judges `orbit` itself (work
    /// 1) and gives a plan of no tunings when it wins; then depth 1 and, when `maxTunings` ≥ 2, depth 2 in the order of
    /// ``orbits(from:depth:)``, the tunings ordered as ``tunings(from:to:)``. Nil when `orbit` is invalid, no orbit
    /// within min(`maxTunings`, 2) tunings wins, or more than `workBound` orbits would be judged.
    public static func plan(_ level: ApsidesWorkshopLevel, from orbit: ApsidesWorkshopOrbit, maxTunings: Int = 2,
                            workBound: Int = workBound) -> ApsidesWorkshopPlan? {
        guard orbit.isValid, workBound >= 1 else { return nil }
        let start: ApsidesWorkshopOrbit = orbit
        var work: Int = 1   // the start, judged at depth 0
        if wins(level, orbit: start) {
            return ApsidesWorkshopPlan(actions: [], orbit: start, orbitsByDepth: [], work: work)
        }
        var byDepth: [Int] = [1]
        let deepest: Int = min(maxTunings, 2)
        guard deepest >= 1 else { return nil }
        for depth in 1...deepest {
            let candidates: [ApsidesWorkshopOrbit] = orbits(from: start, depth: depth)
            for candidate in candidates {
                work += 1
                if work > workBound { return nil }
                if wins(level, orbit: candidate) {
                    return ApsidesWorkshopPlan(actions: tunings(from: start, to: candidate), orbit: candidate,
                                               orbitsByDepth: byDepth, work: work)
                }
            }
            byDepth.append(candidates.count)
        }
        return nil
    }

    /// Whether replaying `actions` and then `play` through the kernel's play wins `level` within its budget.
    public static func replayWins(_ level: ApsidesWorkshopLevel, actions: [ApsidesWorkshopAction]) -> Bool {
        var play = ApsidesWorkshopPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions + [.play] {
                try play.apply(action, expecting: play.fingerprint)
            }
        } catch {
            return false
        }
        return play.stage == .won
    }
}
