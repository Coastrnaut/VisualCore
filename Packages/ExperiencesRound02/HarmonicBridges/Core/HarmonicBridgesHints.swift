// HarmonicBridgesHints — feature 415 (R02-G12-05) T-R02G1205-002 (FR-R02G1205-002, 003, 007; SC-R02G1205-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the level's truth, and the
// plain-English explanation of a failure. While a play is playing (or paused): when the current pegs already join the
// start to the goal in every step the plan is the test; otherwise it is the solver's minimal plan for the level with
// every string at its current peg (`HarmonicBridgesSolver.plan(_:pegs:workBound:)`, locks kept) — its tunings in string
// order, then the test — offered only when those actions fit the actions left, the search stays within the work bound
// and they replay on a copy of the play with every action accepted and a win on the last. The first action is the hint:
// level 1 names the kind, level 2 the string, level 3 the peg. Hints never change a play, are unlimited and do not
// affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the play).
//
// The failure explanation counts actions from 1 ("Action m" is the action with 0-based index m − 1) and steps and
// strings from 0, as the game names them in words; the steps in which the start reached the goal are counted at the
// pegs after the failing action (the play's report at the failure). Its sentence and the advice are joined by one space.
// Integers and strings only; no clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the minimal plan's tunings from the current pegs in
/// string order, then the test (or only the test when every step is already bridged). The first action is the hint.
public struct HarmonicBridgesHintPlan: Sendable, Equatable {
    /// The actions, in play order; the last one (the test) wins.
    public let actions: [HarmonicBridgesAction]

    /// A plan of the given actions (not checked).
    public init(actions: [HarmonicBridgesAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum HarmonicBridgesHintKind: String, Sendable, Codable {
    /// Tune a string so that more steps are bridged.
    case tune
    /// Every step is bridged: test the crossing.
    case test
    /// No way to win fits in the moves left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct HarmonicBridgesHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind, 2 the string, 3 the peg.
    public let level: Int
    /// What the hint suggests.
    public let kind: HarmonicBridgesHintKind
    /// The suggested action (a tuning or the test); nil for `stuck`.
    public let action: HarmonicBridgesAction?
    /// The hint in plain English (see ``text(level:kind:action:failed:)``).
    public var text: String

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the moves left, at every level.
    public static let stuckText: String =
        "No way to win was found in the moves left: undo the last action or retry the level."
    /// The level-1 text of a tuning hint.
    public static let tuneText: String = "Tune a string so that more steps are bridged"
    /// The level-1 text of a test hint.
    public static let testText: String = "Every step is bridged: test the crossing"
    /// The level-2 and level-3 text of a test hint.
    public static let testDetailText: String = "Test the crossing: tap the goal or a step pip"

    /// A hint of the given values (`level` clamped to 1 … 3), its text per ``text(level:kind:action:failed:)``.
    init(level: Int, kind: HarmonicBridgesHintKind, action: HarmonicBridgesAction? = nil, failed: Bool = false) {
        let clamped: Int = min(3, max(1, level))
        self.level = clamped
        self.kind = kind
        self.action = action
        text = Self.text(level: clamped, kind: kind, action: action, failed: failed)
    }

    /// The hint text (clarification Q1), for string i and peg p:
    /// - tune: level 1 ``tuneText``; level 2 "Tune string i"; level 3 "Tune string i to peg p"
    /// - test: level 1 ``testText``; levels 2 and 3 ``testDetailText``
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public static func text(level: Int, kind: HarmonicBridgesHintKind, action: HarmonicBridgesAction?,
                            failed: Bool) -> String {
        switch kind {
        case .stuck:
            return failed ? failedText : stuckText
        case .test:
            return level <= 1 ? testText : testDetailText
        case .tune:
            guard case .tune(let string, let peg) = action else { return stuckText }
            if level <= 1 { return tuneText }
            if level == 2 { return "Tune string " + String(string) }
            return "Tune string " + String(string) + " to peg " + String(peg)
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it). A stuck hint keeps its text.
    public func at(level: Int) -> HarmonicBridgesHint {
        var result = HarmonicBridgesHint(level: level, kind: kind, action: action)
        if kind == .stuck { result.text = text }
        return result
    }
}

/// The hint engine of Harmonic Bridges (clarification Q1).
public enum HarmonicBridgesHints {
    /// The plan of `play` while `playing` or `paused` with actions left: the test when the current pegs already join
    /// the start to the goal in every step; otherwise the minimal plan from the current pegs
    /// (``HarmonicBridgesSolver/plan(_:pegs:workBound:)`` with the default work bound), its tunings in string order then
    /// the test. Offered only when those actions fit ``HarmonicBridgesPlay/actionsLeft`` and replay on a copy of the play
    /// (resumed when paused) with every action accepted and a win on the last. Nil in every other stage, when the search
    /// finds no plan or exceeds the work bound, and when the plan does not fit the actions left.
    public static func plan(_ play: HarmonicBridgesPlay) -> HarmonicBridgesHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.actionsLeft >= 1 else { return nil }
        var actions: [HarmonicBridgesAction] = []
        if !play.report.goalReachedInEveryStep {
            guard let minimal = HarmonicBridgesSolver.plan(play.level, pegs: play.pegs),
                  !minimal.tunings.isEmpty else { return nil }
            for tuning in minimal.tunings { actions.append(.tune(tuning.string, tuning.peg)) }
        }
        actions.append(.test)
        guard actions.count <= play.actionsLeft else { return nil }
        var copy: HarmonicBridgesPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return HarmonicBridgesHintPlan(actions: actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first action (`tune`
    /// or `test`), `stuck` with ``HarmonicBridgesHint/stuckText`` when there is no plan; when `failed` (or `result`
    /// after a failure), `stuck` with ``HarmonicBridgesHint/failedText``; nil in every other stage (loading, tutorial,
    /// won, result after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: HarmonicBridgesPlay) -> HarmonicBridgesHint? {
        switch play.stage {
        case .playing, .paused: break
        case .failed: return HarmonicBridgesHint(level: level, kind: .stuck, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return HarmonicBridgesHint(level: level, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return HarmonicBridgesHint(level: level, kind: .stuck)
        }
        if case .tune = first { return HarmonicBridgesHint(level: level, kind: .tune, action: first) }
        return HarmonicBridgesHint(level: level, kind: .test, action: first)
    }

    /// The actions still applied after `records`, in play order: tunings and tests push, an undo moves the top to a redo
    /// stack, a redo moves it back and a new action clears the redo stack, as the play's own stacks do. The i-th
    /// element is the action with 0-based index i of the current play.
    static func appliedActions(_ records: [HarmonicBridgesRecord]) -> [HarmonicBridgesAction] {
        var applied: [HarmonicBridgesAction] = []
        var undone: [HarmonicBridgesAction] = []
        for record in records {
            switch record.kind {
            case .tune, .test:
                if let action = record.action { applied.append(action) }
                undone.removeAll()
            case .undo:
                if let action = applied.popLast() { undone.append(action) }
            case .redo:
                if let action = undone.popLast() { applied.append(action) }
            }
        }
        return applied
    }
}

/// The plain-English explanation of a failed play (FR-R02G1205-003, 007; clarification Q5), from the failing action.
public struct HarmonicBridgesFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: HarmonicBridgesFailure
    /// The 0-based index of the failing action; the text counts from 1.
    public let action: Int
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With m the
    /// failing action's index + 1, k the steps whose goal the start reached at the failure (the play's report) and n the
    /// level's steps:
    /// - a broken test: "Action m (the test) broke the crossing in step s at string i: the start reached the goal in k
    ///   of n steps." — or "… in step s: no string reaches across: …" when no string crosses the cut;
    /// - the budget: "Action m (a tuning of string i to peg p) spent the last move without a win: the start reached the
    ///   goal in k of n steps." — or "(a test)";
    /// each followed by a space and ``advice``. The failing action is read from the records' actions still applied
    /// (undone ones excluded); a broken test is the latest of them.
    public init?(play: HarmonicBridgesPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let applied: [HarmonicBridgesAction] = HarmonicBridgesHints.appliedActions(play.records)
        let index: Int
        switch failure {
        case .broken: index = play.actionsSpent - 1
        case .budget(let value): index = value
        }
        guard index >= 0, index < applied.count else { return nil }
        let failing: HarmonicBridgesAction = applied[index]
        var reached: Int = 0
        for stepReached in play.report.reached where stepReached[play.level.goal] { reached += 1 }
        let tail: String = ": the start reached the goal in " + String(reached) + " of "
            + String(play.level.steps.count) + " steps."
        let sentence: String
        switch failure {
        case .broken(let step, let string):
            guard case .test = failing else { return nil }
            var place: String = "in step " + String(step)
            if let string {
                place += " at string " + String(string)
            } else {
                place += ": no string reaches across"
            }
            sentence = "Action " + String(index + 1) + " (the test) broke the crossing " + place + tail
        case .budget:
            let what: String
            switch failing {
            case .tune(let string, let peg): what = "a tuning of string " + String(string) + " to peg " + String(peg)
            case .test: what = "a test"
            }
            sentence = "Action " + String(index + 1) + " (" + what + ") spent the last move without a win" + tail
        }
        self.failure = failure
        action = index
        text = sentence + " " + Self.advice
    }
}
