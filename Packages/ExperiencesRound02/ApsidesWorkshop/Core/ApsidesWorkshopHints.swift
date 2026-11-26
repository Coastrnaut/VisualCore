// ApsidesWorkshopHints — feature 475 (R02-G18-05) T-R02G1805-002 (FR-R02G1805-002, 003, 007; SC-R02G1805-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play, and the plain-English
// explanation of a failed revolution. While a play is `playing`, the plan is empty when the current orbit already wins
// (the play's report wins); otherwise it is the solver's minimal plan from the play's orbit
// (`ApsidesWorkshopSolver.plan(_:from:maxTunings:workBound:)` with the default work bound and at most
// min(actions left, 2) tunings), and nil when no plan is found (none within those tunings, or the work bound exceeded).
// A depth-by-depth plan is minimal, so after its first tuning the plan from there has at most one tuning fewer and
// following the hints wins within the budget. The first tuning is the hint: level 1 names the lever ("Turn the
// periapsis knob next" or "Change the size next"), level 2 the way and distance ("Raise the eccentricity by n steps
// and turn the periapsis m steps counterclockwise" or "clockwise", "Lower" for a lower eccentricity, the shorter way
// around the 24 direction steps, counterclockwise (increasing direction) on a tie, a part that does not change left
// out, "1 step" singular; "Grow the orbit by n units" or "Shrink the orbit by n units", "1 unit" singular), level 3 the
// exact setting ("Set the periapsis to eccentricity k, direction d°" with k the eccentricity step and d the direction
// in degrees, 15 per step; "Set the size to a"). With an empty plan the hint is the play ("Every target reads in its
// band: play the revolution"); with no plan it is `stuck`. A failed play (or one in `result` after a failure) gets the
// advice to undo or retry; loading, tutorial, paused, won and `result` after a win have no hint. Hints never change a
// play, are unlimited and do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after
// any change of the play).
//
// The failure explanation numbers targets from 1 (target k is the target with 0-based index k − 1) and names planets,
// sectors, shares and distances in the level's words (`planetName`, `sectorName`, `shareWords`, `distanceWords`). The
// sentence and the advice are joined by one space. Integers and strings only; no clock, no random source. Modelled on
// `CelestialEclipseLabHints` (feature 465).
import Foundation

/// The plan of a play from its current orbit (clarification Q1): the minimal plan's tunings. The first tuning is the
/// hint; an empty plan means the current orbit already wins.
public struct ApsidesWorkshopHintPlan: Sendable, Equatable {
    /// The tunings (`.periapsis(k, d)` or `.size(a)`) in a valid order; the play is not part of it.
    public let tunings: [ApsidesWorkshopAction]

    /// A plan of the given tunings (not checked).
    public init(tunings: [ApsidesWorkshopAction]) {
        self.tunings = tunings
    }
}

/// What a hint suggests (clarification Q1).
public enum ApsidesWorkshopHintKind: String, Sendable, Codable {
    /// Tune the periapsis knob or the size.
    case tune
    /// Every target already reads in its band: play the revolution.
    case play
    /// No way to win fits in the actions left (or the revolution failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct ApsidesWorkshopHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the lever, 2 the way and distance, 3 the exact setting.
    public let level: Int
    /// What the hint suggests.
    public let kind: ApsidesWorkshopHintKind
    /// The suggested action: a tuning for `tune`, `.play` for `play`, nil for `stuck`.
    public let action: ApsidesWorkshopAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current orbit already wins, at every level.
    public static let playText: String = "Every target reads in its band: play the revolution"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: ApsidesWorkshopHintKind, action: ApsidesWorkshopAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// "n steps", or "1 step" when `count` is 1.
    public static func stepsText(_ count: Int) -> String {
        count == 1 ? "1 step" : String(count) + " steps"
    }

    /// "n units", or "1 unit" when `count` is 1.
    public static func unitsText(_ count: Int) -> String {
        count == 1 ? "1 unit" : String(count) + " units"
    }

    /// The shorter way around the 24 direction steps from `from` to `to`: the steps and whether they turn
    /// counterclockwise (increasing direction). Counterclockwise on a tie; 0 steps counterclockwise when equal.
    public static func turn(from: Int, to: Int) -> (steps: Int, counterclockwise: Bool) {
        let count: Int = ApsidesWorkshopOrbit.directions.count
        let ahead: Int = ((to - from) % count + count) % count
        let behind: Int = (count - ahead) % count
        return ahead <= behind ? (ahead, true) : (behind, false)
    }

    /// The text of a tuning hint from `orbit` (clarification Q1) at `level` (clamped to 1 … 3); nil for the play.
    /// - `.periapsis(k, d)`: level 1 "Turn the periapsis knob next"; level 2 "Raise the eccentricity by n steps and
    ///   turn the periapsis m steps counterclockwise" (or "Lower …", "… clockwise", per ``turn(from:to:)``, an
    ///   unchanged part left out, ``stepsText(_:)``); level 3 "Set the periapsis to eccentricity k, direction d°"
    ///   (d × 15 degrees).
    /// - `.size(a)`: level 1 "Change the size next"; level 2 "Grow the orbit by n units" or "Shrink the orbit by n
    ///   units" (``unitsText(_:)``); level 3 "Set the size to a".
    public static func tuneText(level: Int, action: ApsidesWorkshopAction, orbit: ApsidesWorkshopOrbit) -> String? {
        let clamped: Int = min(3, max(1, level))
        switch action {
        case .periapsis(let k, let d):
            if clamped == 1 { return "Turn the periapsis knob next" }
            if clamped == 3 {
                return "Set the periapsis to eccentricity " + String(k) + ", direction " + String(d * 15) + "°"
            }
            var parts: [String] = []
            if k != orbit.eccentricity {
                let raise: Bool = k > orbit.eccentricity
                parts.append((raise ? "raise" : "lower") + " the eccentricity by "
                    + stepsText(abs(k - orbit.eccentricity)))
            }
            if d != orbit.direction {
                let way: (steps: Int, counterclockwise: Bool) = turn(from: orbit.direction, to: d)
                parts.append("turn the periapsis " + stepsText(way.steps)
                    + (way.counterclockwise ? " counterclockwise" : " clockwise"))
            }
            let joined: String = parts.joined(separator: " and ")
            return joined.prefix(1).uppercased() + joined.dropFirst()
        case .size(let a):
            if clamped == 1 { return "Change the size next" }
            if clamped == 3 { return "Set the size to " + String(a) }
            let grow: Bool = a > orbit.size
            return (grow ? "Grow" : "Shrink") + " the orbit by " + unitsText(abs(a - orbit.size))
        case .play:
            return nil
        }
    }
}

/// The hint engine of Apsides Workshop (clarification Q1).
public enum ApsidesWorkshopHints {
    /// The most tunings a hint plan holds (the certified plans have 1 or 2).
    public static let maxTunings: Int = 2

    /// The plan of `play` while `playing`: empty when the current orbit already wins (the play's report wins); else
    /// the minimal plan from the play's orbit (``ApsidesWorkshopSolver/plan(_:from:maxTunings:workBound:)`` with the
    /// default work bound and at most `min(actions left, 2)` tunings). Nil in every other stage, and when the search
    /// finds no plan or exceeds the work bound. The play is not changed.
    public static func plan(_ play: ApsidesWorkshopPlay) -> ApsidesWorkshopHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.report.wins { return ApsidesWorkshopHintPlan(tunings: []) }
        let cap: Int = min(maxTunings, play.actionsLeft)
        guard cap >= 1,
              let minimal = ApsidesWorkshopSolver.plan(play.level, from: play.orbit, maxTunings: cap),
              minimal.size <= play.actionsLeft else { return nil }
        return ApsidesWorkshopHintPlan(tunings: minimal.actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing`, `play` with
    /// ``ApsidesWorkshopHint/playText`` when the plan is empty, the plan's first tuning (`tune`, text per
    /// ``ApsidesWorkshopHint/tuneText(level:action:orbit:)``), or `stuck` with ``ApsidesWorkshopHint/stuckText`` when
    /// there is no plan; when `failed` (or `result` after a failure), `stuck` with ``ApsidesWorkshopHint/failedText``;
    /// nil in every other stage (loading, tutorial, paused, won, result after a win). The same action is returned at
    /// every level; the play is not changed.
    public static func hint(level: Int, play: ApsidesWorkshopPlay) -> ApsidesWorkshopHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return ApsidesWorkshopHint(level: level, kind: .stuck, action: nil, text: ApsidesWorkshopHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return ApsidesWorkshopHint(level: level, kind: .stuck, action: nil, text: ApsidesWorkshopHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let plan = plan(play) else {
            return ApsidesWorkshopHint(level: level, kind: .stuck, action: nil, text: ApsidesWorkshopHint.stuckText)
        }
        guard let first = plan.tunings.first else {
            return ApsidesWorkshopHint(level: level, kind: .play, action: .play, text: ApsidesWorkshopHint.playText)
        }
        guard let text = ApsidesWorkshopHint.tuneText(level: level, action: first, orbit: play.orbit) else {
            return ApsidesWorkshopHint(level: level, kind: .stuck, action: nil, text: ApsidesWorkshopHint.stuckText)
        }
        return ApsidesWorkshopHint(level: level, kind: .tune, action: first, text: text)
    }
}

/// The plain-English explanation of a failed revolution (FR-R02G1805-003, 007; clarification Q5), from the play's
/// failure.
public struct ApsidesWorkshopFailureExplanation: Sendable, Equatable {
    /// Why the revolution failed.
    public let failure: ApsidesWorkshopFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With k
    /// the target's number (its index + 1) and the level's words for planets, sectors, shares and distances:
    /// - contact: "The orbit struck planet p after tick t."
    /// - order: "Target k was reached at tick t, before the target before it."
    /// - share: "Target k (sector s, reached at tick t) swept x %, outside its band from l % to h %."
    /// - apsis sector: "Target k: the periapsis lies in sector s, not in sector s′." ("apoapsis" for an apoapsis
    ///   target; s′ the target's sector)
    /// - apsis distance: "Target k: the periapsis lies at r units, outside its range from l units to h units."
    /// each followed by a space and ``advice``. Nil when the failure names a planet or target the level lacks.
    public init?(play: ApsidesWorkshopPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: ApsidesWorkshopLevel = play.level
        let sentence: String
        switch failure {
        case .contact(let planet, let tick):
            guard level.planets.indices.contains(planet) else { return nil }
            sentence = "The orbit struck " + level.planetName(planet) + " after tick " + String(tick) + "."
        case .order(let target, let tick):
            guard level.targets.indices.contains(target) else { return nil }
            sentence = "Target " + String(target + 1) + " was reached at tick " + String(tick)
                + ", before the target before it."
        case .share(let target, let tick, let share):
            guard level.targets.indices.contains(target) else { return nil }
            let goal: ApsidesWorkshopTarget = level.targets[target]
            sentence = "Target " + String(target + 1) + " (" + level.sectorName(goal.sector) + ", reached at tick "
                + String(tick) + ") swept " + ApsidesWorkshopLevel.shareWords(share) + ", outside its band from "
                + ApsidesWorkshopLevel.shareWords(goal.low) + " to " + ApsidesWorkshopLevel.shareWords(goal.high) + "."
        case .apsisSector(let target, let sector):
            guard level.targets.indices.contains(target) else { return nil }
            let goal: ApsidesWorkshopTarget = level.targets[target]
            sentence = "Target " + String(target + 1) + ": the " + goal.kind.rawValue + " lies in "
                + level.sectorName(sector) + ", not in " + level.sectorName(goal.sector) + "."
        case .apsisDistance(let target, let distance):
            guard level.targets.indices.contains(target) else { return nil }
            let goal: ApsidesWorkshopTarget = level.targets[target]
            sentence = "Target " + String(target + 1) + ": the " + goal.kind.rawValue + " lies at "
                + ApsidesWorkshopLevel.distanceWords(distance) + ", outside its range from "
                + ApsidesWorkshopLevel.distanceWords(goal.low) + " to " + ApsidesWorkshopLevel.distanceWords(goal.high)
                + "."
        }
        self.failure = failure
        text = sentence + " " + Self.advice
    }
}
