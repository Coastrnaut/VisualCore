// EchoCartographerHints — feature 405 (R02-G11-05) T-R02G1105-002 (FR-R02G1105-002, 003; SC-R02G1105-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the level's truth, and the
// plain-English explanation of a failure. The play's current pulses are its accepted pulse records still applied (the
// records' actions, undos and redos replayed on a stack exactly as the play's own undo and redo stacks move); the
// echoes they heard are the observations. When exactly one beacon placement fits them the plan claims every beacon not
// yet located on its own cell, lowest index first (a claim at distance 0 always locates that beacon and is free);
// otherwise the plan is the solver's continuation (`EchoCartographerSolver.continuation`, the certification's greedy
// rule from the current knowledge and pulses), whose pulses must leave at least 1 energy, followed by those claims.
// The plan is replayed on a copy of the play before it is offered, so following exact hints from any state with a plan
// wins. Hints never change a play, are unlimited and do not affect stars; the hint level is presentation (held by the
// presenter, reset to 1 after any change of the play).
//
// Cells are named exactly as the game already names them in words (`EchoCartographerLevel.cellName`,
// `echoDescription`): "column x, row y" with the chamber's own column and row numbers (0-based, row 0 the north edge),
// the same numbers the panel and `cell.pulse [x, y]` take. The failure explanation counts actions from 1 ("Action m"
// is the action with 0-based index m − 1) and keeps the clarification's wording literally ("k of n beacons", "p pulses",
// "q missed claims" also for 1); its sentence and the advice are joined by one space. Integers and strings only; no
// clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the further pulses until one beacon placement fits,
/// then one claim on each beacon not yet located (its own cell, beacon order). The first action is the hint.
public struct EchoCartographerHintPlan: Sendable, Equatable {
    /// The actions, in play order; the last claim wins.
    public let actions: [EchoCartographerAction]

    /// A plan of the given actions (not checked).
    public init(actions: [EchoCartographerAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum EchoCartographerHintKind: String, Sendable, Codable {
    /// Send a pulse to narrow down the beacons.
    case pulse
    /// The echoes leave one placement: claim a beacon.
    case claim
    /// No way to locate every beacon fits in the energy left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct EchoCartographerHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind, 2 adds the row, 3 names the cell.
    public let level: Int
    /// What the hint suggests.
    public let kind: EchoCartographerHintKind
    /// The suggested action (a pulse or a claim); nil for `stuck`.
    public let action: EchoCartographerAction?
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (`level` clamped to 1 … 3; not otherwise checked).
    init(level: Int, kind: EchoCartographerHintKind, action: EchoCartographerAction? = nil, failed: Bool = false) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to locate every beacon was found in the energy left, at every level.
    public static let stuckText: String =
        "No way to locate every beacon was found in the energy left: undo the last action or retry the level."
    /// The level-1 text of a pulse hint.
    public static let pulseText: String = "Send a pulse to narrow down where the beacons can be"
    /// The level-1 text of a claim hint.
    public static let claimText: String = "The echoes leave one place for the beacons: claim a beacon"

    /// The hint in plain English (clarification Q1), for the cell at column x, row y:
    /// - pulse: level 1 ``pulseText``; level 2 ``pulseText`` + " from a known open cell in row y"; level 3 "Send a
    ///   pulse from column x, row y"
    /// - claim: level 1 ``claimText``; level 2 ``claimText`` + " in row y"; level 3 "Claim column x, row y"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        guard let action, kind != .stuck else { return failed ? Self.failedText : Self.stuckText }
        let cell: EchoCartographerCell = action.cell
        let x: String = String(cell.x)
        let y: String = String(cell.y)
        if kind == .pulse {
            if level >= 3 { return "Send a pulse from column " + x + ", row " + y }
            return level == 2 ? Self.pulseText + " from a known open cell in row " + y : Self.pulseText
        }
        if level >= 3 { return "Claim column " + x + ", row " + y }
        return level == 2 ? Self.claimText + " in row " + y : Self.claimText
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it).
    public func at(level: Int) -> EchoCartographerHint {
        EchoCartographerHint(level: level, kind: kind, action: action, failed: failed)
    }
}

/// The hint engine of Echo Cartographer (clarification Q1).
public enum EchoCartographerHints {
    /// The plan of `play` while `playing` or `paused` with energy left: the solver's continuation
    /// (``EchoCartographerSolver/continuation(_:knowledge:pulsed:energyLeft:workBound:)`` with the default work bound)
    /// from the play's knowledge and current pulses within its energy, then one claim on each beacon not yet located
    /// (its own cell, beacon order); offered only when it replays on a copy of the play (resumed when paused) with
    /// every action accepted and a win on the last. Nil in every other stage and when no continuation is found.
    public static func plan(_ play: EchoCartographerPlay) -> EchoCartographerHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.energy >= 1 else { return nil }
        let level: EchoCartographerLevel = play.level
        var pulses: [EchoCartographerCell] = []
        for action in appliedActions(play.records) {
            if case .pulse = action { pulses.append(action.cell) }
        }
        guard let further = EchoCartographerSolver.continuation(level, knowledge: play.knowledge, pulsed: pulses,
                                                                energyLeft: play.energy) else { return nil }
        var actions: [EchoCartographerAction] = []
        for cell in further { actions.append(EchoCartographerAction.pulse(cell.x, cell.y)) }
        for (index, beacon) in level.beacons.enumerated() where play.located[index] == nil {
            actions.append(EchoCartographerAction.claim(beacon.x, beacon.y))
        }
        guard !actions.isEmpty else { return nil }
        var copy: EchoCartographerPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return EchoCartographerHintPlan(actions: actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first action (`pulse`
    /// or `claim`), `stuck` with ``EchoCartographerHint/stuckText`` when there is no plan; when `failed` (or `result`
    /// after a failure), `stuck` with ``EchoCartographerHint/failedText``; nil in every other stage (loading, tutorial,
    /// won, result after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: EchoCartographerPlay) -> EchoCartographerHint? {
        switch play.stage {
        case .playing, .paused: break
        case .failed: return EchoCartographerHint(level: level, kind: .stuck, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return EchoCartographerHint(level: level, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return EchoCartographerHint(level: level, kind: .stuck)
        }
        if case .pulse = first { return EchoCartographerHint(level: level, kind: .pulse, action: first) }
        return EchoCartographerHint(level: level, kind: .claim, action: first)
    }

    /// The actions still applied after `records`, in play order: pulses, claims and marks push, an undo moves the top
    /// to a redo stack, a redo moves it back and a new action clears the redo stack, as the play's own stacks do. The
    /// i-th element is the action with 0-based index i of the current play.
    static func appliedActions(_ records: [EchoCartographerRecord]) -> [EchoCartographerAction] {
        var applied: [EchoCartographerAction] = []
        var undone: [EchoCartographerAction] = []
        for record in records {
            switch record.kind {
            case .pulse, .claim, .mark:
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

/// The plain-English explanation of a failed play (FR-R02G1105-003; clarification Q5), from the action that spent the
/// last energy.
public struct EchoCartographerFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: EchoCartographerFailure
    /// The 0-based index of the action that spent the last energy (the index of ``failure``); the text counts from 1.
    public let action: Int
    /// The failing action's cell.
    public let cell: EchoCartographerCell
    /// Whether the failing action was a pulse (else a missed claim).
    public let isPulse: Bool
    /// The beacons located at the failure.
    public let located: Int
    /// The level's beacons.
    public let beacons: Int
    /// The pulses still applied in the current play (undone ones excluded), the failing one included.
    public let pulses: Int
    /// The missed claims still applied in the current play (undone ones excluded), the failing one included.
    public let missedClaims: Int
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation (clarification Q5): "Action m (a pulse from column x, row y) spent the last energy: k of n
    /// beacons located after p pulses and q missed claims." — or "(a missed claim at column x, row y)" — followed by a
    /// space and ``advice``; m is the failing action's index + 1.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). The
    /// current play's actions are the records' actions still applied (undone ones excluded); replaying them in order
    /// on the level's claim rule tells each claim's hit or miss and names the failing action (a failure restored by a
    /// redo names the same action).
    public init?(play: EchoCartographerPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: EchoCartographerLevel = play.level
        let applied: [EchoCartographerAction] = EchoCartographerHints.appliedActions(play.records)
        let index: Int
        switch failure {
        case .energy(let value): index = value
        }
        guard index >= 0, index < applied.count else { return nil }
        var located: Set<Int> = []
        var pulses: Int = 0
        var missed: Int = 0
        var failingWasPulse: Bool = false
        for position in 0...index {
            let step: EchoCartographerAction = applied[position]
            switch step {
            case .pulse:
                pulses += 1
                if position == index { failingWasPulse = true }
            case .claim:
                let result: EchoCartographerClaimResult = level.claim(step.cell, located: located)
                if case .hit(let beacon) = result {
                    located.insert(beacon)
                } else {
                    missed += 1
                }
            case .mark:
                break
            }
        }
        let failing: EchoCartographerAction = applied[index]
        if case .mark = failing { return nil }
        self.failure = failure
        action = index
        cell = failing.cell
        isPulse = failingWasPulse
        self.located = play.located.count
        beacons = level.beacons.count
        self.pulses = pulses
        missedClaims = missed
        let place: String = "column " + String(failing.cell.x) + ", row " + String(failing.cell.y)
        let what: String = failingWasPulse ? "a pulse from " + place : "a missed claim at " + place
        detail = "Action " + String(index + 1) + " (" + what + ") spent the last energy: " + String(play.located.count)
            + " of " + String(level.beacons.count) + " beacons located after " + String(pulses) + " pulses and "
            + String(missed) + " missed claims."
    }
}
