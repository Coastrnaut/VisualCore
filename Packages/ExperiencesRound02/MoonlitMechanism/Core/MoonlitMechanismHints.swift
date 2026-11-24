// MoonlitMechanismHints — feature 435 (R02-G14-05) T-R02G1405-002 (FR-R02G1405-002, 003, 007; SC-R02G1405-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play, and the plain-English
// explanation of a failure. While a play is playing (or paused) with actions left, the plan is the solver's minimal
// plan from the play's current phases and lamp height (`MoonlitMechanismSolver.plan(_:phases:height:maxActions:
// workBound:)`) as its witness actions (`MoonlitMechanismSolver.actions(_:)`): the turns, then the re-seats in gear
// order, then the lamp steps, then the run. It is offered only when all of those actions fit the actions left, the
// search stays within the work bound and they replay on a copy of the play with every action accepted and a win on the
// last. The first action is the hint: level 1 names the kind, level 2 the gear or the way, level 3 the exact action. A
// won play has no hint; a failed play's hint is the advice to undo or retry. Hints never change a play, are unlimited
// and do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the
// play).
//
// The failure explanation counts actions from 1 ("Action m" is the action with 0-based index m − 1) and gears, key
// frames and cells from 0. The failing action is read from the actions still applied after the records (undone ones
// excluded): the latest one (the run) for a run failure, the one at the recorded index for the budget. The jammed
// gear's parent and the stray allowance are read from the level. Its sentence and the advice are joined by one space.
// Integers and strings only; no clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the minimal plan's turns, its re-seats in gear order,
/// its lamp steps, then the run. The first action is the hint.
public struct MoonlitMechanismHintPlan: Sendable, Equatable {
    /// The actions, in play order; the last one (the run) wins.
    public let actions: [MoonlitMechanismAction]

    /// A plan of the given actions (not checked).
    public init(actions: [MoonlitMechanismAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum MoonlitMechanismHintKind: String, Sendable, Codable {
    /// Turn the handle by ±1 tooth.
    case turn
    /// Re-seat a gear by ±1 tooth.
    case reseat
    /// Step the lamp by ±1 height.
    case lamp
    /// Every needed change is in place: run the machine.
    case run
    /// No way to win fits in the actions left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct MoonlitMechanismHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind, 2 the gear or the way, 3 the exact action.
    public let level: Int
    /// What the hint suggests.
    public let kind: MoonlitMechanismHintKind
    /// The suggested action (a turn, a re-seat, a lamp step or the run); nil for `stuck`.
    public let action: MoonlitMechanismAction?
    /// The hint in plain English (see ``text(level:kind:action:failed:)``).
    public var text: String

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."
    /// The level-1 text of a turn hint.
    public static let turnText: String = "Turn the handle"
    /// The level-1 text of a re-seat hint.
    public static let reseatText: String = "Re-seat a gear"
    /// The level-1 text of a lamp hint.
    public static let lampText: String = "Move the lamp"
    /// The level-1 text of a run hint.
    public static let runText: String = "The shadows are ready: run the machine"
    /// The level-2 and level-3 text of a run hint.
    public static let runDetailText: String = "Run: tap the lamp"

    /// A hint of the given values (`level` clamped to 1 … 3), its text per ``text(level:kind:action:failed:)``.
    init(level: Int, kind: MoonlitMechanismHintKind, action: MoonlitMechanismAction? = nil, failed: Bool = false) {
        let clamped: Int = min(3, max(1, level))
        self.level = clamped
        self.kind = kind
        self.action = action
        text = Self.text(level: clamped, kind: kind, action: action, failed: failed)
    }

    /// The signed step of a re-seat in words: "+1" or "−1" (U+2212 MINUS SIGN).
    public static func stepText(_ step: Int) -> String { step < 0 ? "\u{2212}1" : "+1" }

    /// The hint text (clarification Q1), for gear g (0-based):
    /// - turn: level 1 ``turnText``; level 2 "Turn the handle forward" (or "back"); level 3 "Turn the handle forward
    ///   one tooth" (or "back one tooth")
    /// - reseat: level 1 ``reseatText``; level 2 "Work on gear g"; level 3 "Re-seat gear g by +1" (or "by −1")
    /// - lamp: level 1 ``lampText``; level 2 "Raise the lamp" (or "Lower the lamp"); level 3 "Raise the lamp one step"
    ///   (or "Lower the lamp one step")
    /// - run: level 1 ``runText``; levels 2 and 3 ``runDetailText``
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public static func text(level: Int, kind: MoonlitMechanismHintKind, action: MoonlitMechanismAction?,
                            failed: Bool) -> String {
        switch kind {
        case .stuck:
            return failed ? failedText : stuckText
        case .run:
            return level <= 1 ? runText : runDetailText
        case .turn:
            guard case .turn(let step) = action else { return stuckText }
            if level <= 1 { return turnText }
            let way: String = step < 0 ? "back" : "forward"
            if level == 2 { return "Turn the handle " + way }
            return "Turn the handle " + way + " one tooth"
        case .reseat:
            guard case .reseat(let gear, let step) = action else { return stuckText }
            if level <= 1 { return reseatText }
            if level == 2 { return "Work on gear " + String(gear) }
            return "Re-seat gear " + String(gear) + " by " + stepText(step)
        case .lamp:
            guard case .lamp(let step) = action else { return stuckText }
            if level <= 1 { return lampText }
            let way: String = step < 0 ? "Lower" : "Raise"
            if level == 2 { return way + " the lamp" }
            return way + " the lamp one step"
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it). A stuck hint keeps its text.
    public func at(level: Int) -> MoonlitMechanismHint {
        var result = MoonlitMechanismHint(level: level, kind: kind, action: action)
        if kind == .stuck { result.text = text }
        return result
    }
}

/// The hint engine of Moonlit Mechanism (clarification Q1).
public enum MoonlitMechanismHints {
    /// The plan of `play` while `playing` or `paused` with actions left: the minimal plan from the play's current
    /// phases and lamp height (``MoonlitMechanismSolver/plan(_:phases:height:maxActions:workBound:)`` with the default
    /// work bound and at most `min(6, actions left − 1)` actions before the run) as its witness actions
    /// (``MoonlitMechanismSolver/actions(_:)``) — the turns, the re-seats in gear order, the lamp steps, then the run.
    /// Offered only when those actions fit ``MoonlitMechanismPlay/actionsLeft`` and replay on a copy of the play
    /// (resumed when paused) with every action accepted and a win on the last. Nil in every other stage, when the
    /// search finds no plan or exceeds the work bound, and when the plan does not fit the actions left. The play is
    /// not changed.
    public static func plan(_ play: MoonlitMechanismPlay) -> MoonlitMechanismHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.actionsLeft >= 1 else { return nil }
        let cap: Int = min(MoonlitMechanismSolver.maxActions, play.actionsLeft - 1)
        guard let minimal = MoonlitMechanismSolver.plan(play.level, phases: play.phases, height: play.height,
                                                        maxActions: cap) else { return nil }
        let actions: [MoonlitMechanismAction] = MoonlitMechanismSolver.actions(minimal)
        guard actions.count <= play.actionsLeft else { return nil }
        var copy: MoonlitMechanismPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return MoonlitMechanismHintPlan(actions: actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first action (`turn`,
    /// `reseat`, `lamp` or `run`), `stuck` with ``MoonlitMechanismHint/stuckText`` when there is no plan; when `failed`
    /// (or `result` after a failure), `stuck` with ``MoonlitMechanismHint/failedText``; nil in every other stage
    /// (loading, tutorial, won, result after a win). The same action is returned at every level; the play is not
    /// changed.
    public static func hint(level: Int, play: MoonlitMechanismPlay) -> MoonlitMechanismHint? {
        switch play.stage {
        case .playing, .paused: break
        case .failed: return MoonlitMechanismHint(level: level, kind: .stuck, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return MoonlitMechanismHint(level: level, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return MoonlitMechanismHint(level: level, kind: .stuck)
        }
        let kind: MoonlitMechanismHintKind
        switch first {
        case .turn: kind = .turn
        case .reseat: kind = .reseat
        case .lamp: kind = .lamp
        case .run: kind = .run
        }
        return MoonlitMechanismHint(level: level, kind: kind, action: first)
    }

    /// The actions still applied after `records`, in play order: turns, re-seats, lamp steps and runs push, an undo
    /// moves the top to a redo stack, a redo moves it back and a new action clears the redo stack, as the play's own
    /// stacks do. The i-th element is the action with 0-based index i of the current play.
    static func appliedActions(_ records: [MoonlitMechanismRecord]) -> [MoonlitMechanismAction] {
        var applied: [MoonlitMechanismAction] = []
        var undone: [MoonlitMechanismAction] = []
        for record in records {
            switch record.kind {
            case .turn, .reseat, .lamp, .run:
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

/// The plain-English explanation of a failed play (FR-R02G1405-003, 007; clarification Q5), from the failing action.
public struct MoonlitMechanismFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: MoonlitMechanismFailure
    /// The 0-based index of the failing action; the text counts from 1.
    public let action: Int
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The words for an action in a budget explanation: "a turn of the handle by +1" (or "by −1"), "a re-seat of gear g
    /// by +1" (or "by −1"), "a lamp step by +1" (or "by −1") or "the run" (U+2212 MINUS SIGN for −1).
    public static func describe(_ action: MoonlitMechanismAction) -> String {
        switch action {
        case .turn(let step):
            return "a turn of the handle by " + MoonlitMechanismHint.stepText(step)
        case .reseat(let gear, let step):
            return "a re-seat of gear " + String(gear) + " by " + MoonlitMechanismHint.stepText(step)
        case .lamp(let step):
            return "a lamp step by " + MoonlitMechanismHint.stepText(step)
        case .run:
            return "the run"
        }
    }

    /// "n <noun>s", or "1 <noun>" when n is 1.
    static func count(_ value: Int, _ noun: String) -> String {
        String(value) + " " + noun + (value == 1 ? "" : "s")
    }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With m
    /// the failing action's index + 1, p the jammed gear's parent and a the level's stray allowance:
    /// - jammed: "Action m (the run): gear c jammed against its parent, gear p."
    /// - forbidden: "Action m (the run): key frame k cast a shadow on forbidden cell x."
    /// - missing: "Action m (the run): key frame k missed n target cells." ("1 target cell" when n is 1)
    /// - stray: "Action m (the run): key frame k cast n stray cells, more than the a allowed." ("1 stray cell" when n
    ///   is 1)
    /// - budget: "Action m (<``describe(_:)``>) spent the last action without a win."
    /// each followed by a space and ``advice``. The failing action is read from the records' actions still applied
    /// (undone ones excluded): the latest of them (the run) for a run failure, the one at the recorded index for the
    /// budget.
    public init?(play: MoonlitMechanismPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let applied: [MoonlitMechanismAction] = MoonlitMechanismHints.appliedActions(play.records)
        let index: Int
        switch failure {
        case .jammed, .forbidden, .missing, .stray: index = play.actionsSpent - 1
        case .budget(let value): index = value
        }
        guard index >= 0, index < applied.count else { return nil }
        let failing: MoonlitMechanismAction = applied[index]
        let head: String = "Action " + String(index + 1)
        let sentence: String
        switch failure {
        case .jammed(let child):
            guard failing == .run, child >= 0, child < play.level.gears.count,
                  let parent = play.level.gears[child].parent else { return nil }
            sentence = head + " (the run): gear " + String(child) + " jammed against its parent, gear "
                + String(parent) + "."
        case .forbidden(let frame, let cell):
            guard failing == .run else { return nil }
            sentence = head + " (the run): key frame " + String(frame) + " cast a shadow on forbidden cell "
                + String(cell) + "."
        case .missing(let frame, let missed):
            guard failing == .run else { return nil }
            sentence = head + " (the run): key frame " + String(frame) + " missed " + Self.count(missed, "target cell")
                + "."
        case .stray(let frame, let stray):
            guard failing == .run else { return nil }
            sentence = head + " (the run): key frame " + String(frame) + " cast " + Self.count(stray, "stray cell")
                + ", more than the " + String(play.level.allowance) + " allowed."
        case .budget:
            sentence = head + " (" + Self.describe(failing) + ") spent the last action without a win."
        }
        self.failure = failure
        action = index
        text = sentence + " " + Self.advice
    }
}
