// CelestialEclipseLabHints — feature 465 (R02-G17-05) T-R02G1705-002 (FR-R02G1705-002, 003, 007; SC-R02G1705-002,
// 003; clarifications Q1, Q5). Progressive hints computed from the current state of a play, and the plain-English
// explanation of a failed run. While a play is `playing`, the plan is the solver's minimal plan from the play's current
// phases (`CelestialEclipseLabSolver.plan(_:from:maxChanges:workBound:)` with the default work bound and at most
// min(actions left, 5) phase changes); it is empty when the current phases already win (the timeline wins) and nil when
// no plan is found (none within those changes, or the work bound exceeded). A breadth-first-by-depth plan is a minimal
// one, so after its first change the plan from there has at most one change fewer and following the hints wins within
// the budget. The first change (b, p) is the hint: level 1 names the planet ("Move planet b next"), level 2 the way and
// distance ("Move planet b k steps forward" or "back", "1 step" singular, k the shorter way around the orbit from the
// current phase to p, forward on a tie), level 3 the exact change ("Set planet b to phase p"). With an empty plan the
// hint is the run ("The eclipses are in order: run the clock"); with no plan it is `stuck`. A failed play (or one in
// `result` after a failure) gets the advice to undo or retry; loading, tutorial, paused, won and `result` after a win
// have no hint. Hints never change a play, are unlimited and do not affect stars; the hint level is presentation (held
// by the presenter, reset to 1 after any change of the play).
//
// The failure explanation numbers targets from 1 (target k is the target with 0-based index k − 1, the timeline's
// matched count + 1 for the target the run was waiting for) and planets by body index (from 0, as the level names
// them). The sentence and the advice are joined by one space. Integers and strings only; no clock, no random source.
// Modelled on `StarlitCartoucheHints` (feature 455).
import Foundation

/// The plan of a play from its current phases (clarification Q1): the minimal plan's phase changes. The first change
/// is the hint; an empty plan means the current phases already win.
public struct CelestialEclipseLabHintPlan: Sendable, Equatable {
    /// The phase changes (each `.phase(body, offset)`), in body order; the run is not part of it.
    public let changes: [CelestialEclipseLabAction]

    /// A plan of the given changes (not checked).
    public init(changes: [CelestialEclipseLabAction]) {
        self.changes = changes
    }
}

/// What a hint suggests (clarification Q1).
public enum CelestialEclipseLabHintKind: String, Sendable, Codable {
    /// Change a planet's phase.
    case change
    /// The eclipses are already in order: run the clock.
    case run
    /// No way to win fits in the actions left (or the run failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct CelestialEclipseLabHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the planet, 2 the way and distance, 3 the exact phase change.
    public let level: Int
    /// What the hint suggests.
    public let kind: CelestialEclipseLabHintKind
    /// The suggested action: a phase change for `change`, `.run` for `run`, nil for `stuck`.
    public let action: CelestialEclipseLabAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current phases already win, at every level.
    public static let runText: String = "The eclipses are in order: run the clock"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: CelestialEclipseLabHintKind, action: CelestialEclipseLabAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// "k steps", or "1 step" when `steps` is 1.
    public static func stepsText(_ steps: Int) -> String {
        steps == 1 ? "1 step" : String(steps) + " steps"
    }

    /// The shorter way around an orbit of `period` positions from phase `from` to phase `to`: the steps and whether
    /// they go forward (increasing phase). Forward on a tie; 0 steps forward when the phases are equal.
    public static func way(from: Int, to: Int, period: Int) -> (steps: Int, forward: Bool) {
        guard period > 0 else { return (0, true) }
        let ahead: Int = ((to - from) % period + period) % period
        let behind: Int = (period - ahead) % period
        return ahead <= behind ? (ahead, true) : (behind, false)
    }

    /// The text of a phase-change hint (clarification Q1) that sets planet `body` from phase `from` to phase `to` on
    /// an orbit of `period` positions, at `level` (clamped to 1 … 3): level 1 "Move planet b next", level 2 "Move
    /// planet b k steps forward" or "… back" (``way(from:to:period:)``, "1 step" singular), level 3 "Set planet b to
    /// phase p".
    public static func changeText(level: Int, body: Int, from: Int, to: Int, period: Int) -> String {
        let clamped: Int = min(3, max(1, level))
        if clamped == 1 { return "Move planet " + String(body) + " next" }
        if clamped == 2 {
            let route: (steps: Int, forward: Bool) = way(from: from, to: to, period: period)
            return "Move planet " + String(body) + " " + stepsText(route.steps) + (route.forward ? " forward" : " back")
        }
        return "Set planet " + String(body) + " to phase " + String(to)
    }
}

/// The hint engine of Celestial Eclipse Lab (clarification Q1).
public enum CelestialEclipseLabHints {
    /// The plan of `play` while `playing`: empty when the current phases already win (the play's timeline wins);
    /// else the minimal plan from the play's current phases
    /// (``CelestialEclipseLabSolver/plan(_:from:maxChanges:workBound:)`` with the default work bound and at most
    /// `min(actions left, 5)` changes). Nil in every other stage, and when the search finds no plan or exceeds the work
    /// bound. The play is not changed.
    public static func plan(_ play: CelestialEclipseLabPlay) -> CelestialEclipseLabHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.timeline.wins { return CelestialEclipseLabHintPlan(changes: []) }
        let cap: Int = min(CelestialEclipseLabSolver.maxChanges, play.actionsLeft)
        guard cap >= 1,
              let minimal = CelestialEclipseLabSolver.plan(play.level, from: play.phases, maxChanges: cap),
              minimal.size <= play.actionsLeft else { return nil }
        return CelestialEclipseLabHintPlan(changes: minimal.actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing`, `run` with
    /// ``CelestialEclipseLabHint/runText`` when the plan is empty, the plan's first change (`change`, text per
    /// ``CelestialEclipseLabHint/changeText(level:body:from:to:period:)``), or `stuck` with
    /// ``CelestialEclipseLabHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure),
    /// `stuck` with ``CelestialEclipseLabHint/failedText``; nil in every other stage (loading, tutorial, paused, won,
    /// result after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: CelestialEclipseLabPlay) -> CelestialEclipseLabHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return CelestialEclipseLabHint(level: level, kind: .stuck, action: nil,
                                           text: CelestialEclipseLabHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return CelestialEclipseLabHint(level: level, kind: .stuck, action: nil,
                                           text: CelestialEclipseLabHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let plan = plan(play) else {
            return CelestialEclipseLabHint(level: level, kind: .stuck, action: nil,
                                           text: CelestialEclipseLabHint.stuckText)
        }
        guard let first = plan.changes.first else {
            return CelestialEclipseLabHint(level: level, kind: .run, action: .run,
                                           text: CelestialEclipseLabHint.runText)
        }
        guard case .phase(let body, let offset) = first, play.level.bodies.indices.contains(body) else {
            return CelestialEclipseLabHint(level: level, kind: .stuck, action: nil,
                                           text: CelestialEclipseLabHint.stuckText)
        }
        let text: String = CelestialEclipseLabHint.changeText(level: level, body: body, from: play.phases[body],
                                                              to: offset, period: play.level.bodies[body].period)
        return CelestialEclipseLabHint(level: level, kind: .change, action: first, text: text)
    }
}

/// The plain-English explanation of a failed run (FR-R02G1705-003, 007; clarification Q5), from the run's failure.
public struct CelestialEclipseLabFailureExplanation: Sendable, Equatable {
    /// Why the run failed.
    public let failure: CelestialEclipseLabFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With k
    /// the number of the target the run was waiting for (the timeline's matched count + 1) and target k's planets
    /// f′, b′ and window o … c:
    /// - unwanted: "The run met an unwanted eclipse first: planet f in front of planet b at tick t, before target k
    ///   (planet f′ in front of planet b′)."
    /// - window: "Target k (planet f in front of planet b) began at tick t, outside its window from tick o to tick c."
    /// - horizon: "The clock reached tick h before target k (planet f in front of planet b, window o … c) happened."
    ///   (h the last tick, horizon − 1)
    /// each followed by a space and ``advice``, with the planets, ticks and window the kernel recorded. Nil when the
    /// timeline's matched count names no target.
    public init?(play: CelestialEclipseLabPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let matched: Int = play.timeline.matched
        guard matched >= 0, matched < play.level.target.count else { return nil }
        let number: String = String(matched + 1)
        let sentence: String
        switch failure {
        case .unwanted(let front, let back, let tick):
            let next: CelestialEclipseLabTarget = play.level.target[matched]
            sentence = "The run met an unwanted eclipse first: planet " + String(front) + " in front of planet "
                + String(back) + " at tick " + String(tick) + ", before target " + number + " (planet "
                + String(next.front) + " in front of planet " + String(next.back) + ")."
        case .window(let front, let back, let tick, let open, let close):
            sentence = "Target " + number + " (planet " + String(front) + " in front of planet " + String(back)
                + ") began at tick " + String(tick) + ", outside its window from tick " + String(open) + " to tick "
                + String(close) + "."
        case .horizon(let front, let back, let open, let close):
            sentence = "The clock reached tick " + String(play.level.horizon - 1) + " before target " + number
                + " (planet " + String(front) + " in front of planet " + String(back) + ", window " + String(open)
                + " … " + String(close) + ") happened."
        }
        self.failure = failure
        text = sentence + " " + Self.advice
    }
}
