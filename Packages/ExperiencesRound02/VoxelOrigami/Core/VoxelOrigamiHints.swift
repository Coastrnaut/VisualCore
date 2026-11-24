// VoxelOrigamiHints — feature 445 (R02-G15-05) T-R02G1505-002 (FR-R02G1505-002, 003, 007; SC-R02G1505-002, 003;
// clarifications Q1, Q5; research R1, R2, R6). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failure. While a play is playing (or paused) with actions left, the plan is the
// solver's minimal plan from the play's current quarter turns (`VoxelOrigamiSolver.plan(_:turns:maxTurns:workBound:)`
// with the default work bound and at most min(6, actions left) turns); it is offered only when its turns fit the
// actions left. A breadth-first plan is a shortest one, so after its first turn the plan from there has exactly one
// turn fewer and following the hints wins within the budget. The first turn (h, s) is the hint: level 1 names what
// moves (hinge h's tracked cube, `VoxelOrigamiPicker.trackedCube`, among the cubes the hinge swings at the current
// pose), level 2 the hinge, level 3 the exact turn. A won play has no hint; a failed play's hint is the advice to undo
// or retry. As feature 435's Moonlit Mechanism: a paused play is hinted as if playing; a play in `result` after a
// failure gets the failed advice; loading, tutorial, won and `result` after a win have no hint. Hints never change a
// play, are unlimited and do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after
// any change of the play).
//
// The failure explanation counts actions from 1 ("Action m" is the action with 0-based index m − 1) and cubes, hinges
// and cells from 0. The failing action is read from the actions still applied after the records (undone ones excluded,
// as the play's own undo and redo stacks do): the latest one for a collision or a sweep (a refused turn is recorded and
// spends its action, so it is the action with index actions spent − 1), the one at the recorded index for the budget.
// The sentence and the advice are joined by one space; "−1" uses U+2212 MINUS SIGN. Integers and strings only; no
// clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the minimal plan's turns. The first turn is the hint.
public struct VoxelOrigamiHintPlan: Sendable, Equatable {
    /// The turns, in play order; the last one wins.
    public let turns: [VoxelOrigamiAction]

    /// A plan of the given turns (not checked).
    public init(turns: [VoxelOrigamiAction]) {
        self.turns = turns
    }
}

/// What a hint suggests (clarification Q1).
public enum VoxelOrigamiHintKind: String, Sendable, Codable {
    /// Turn a hinge by a quarter turn.
    case turn
    /// No way to win fits in the actions left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested turn is the same at every level; only the text reveals more.
public struct VoxelOrigamiHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the cube that moves, 2 the hinge, 3 the exact turn.
    public let level: Int
    /// What the hint suggests.
    public let kind: VoxelOrigamiHintKind
    /// The suggested turn; nil for `stuck`.
    public let action: VoxelOrigamiAction?
    /// The hint in plain English.
    public var text: String

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: VoxelOrigamiHintKind, action: VoxelOrigamiAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// The signed step in words: "+1" or "−1" (U+2212 MINUS SIGN).
    public static func stepText(_ step: Int) -> String { step < 0 ? "\u{2212}1" : "+1" }

    /// The text of a turn hint (clarification Q1) of hinge `hinge` by `step` at `level` (clamped to 1 … 3), `cube`
    /// being the hinge's tracked cube: level 1 "The next turn swings cube k", level 2 "Turn hinge h", level 3 "Turn
    /// hinge h forward (+1)" or "Turn hinge h back (−1)".
    public static func turnText(level: Int, hinge: Int, step: Int, cube: Int) -> String {
        let clamped: Int = min(3, max(1, level))
        if clamped == 1 { return "The next turn swings cube " + String(cube) }
        if clamped == 2 { return "Turn hinge " + String(hinge) }
        let way: String = step < 0 ? "back" : "forward"
        return "Turn hinge " + String(hinge) + " " + way + " (" + stepText(step) + ")"
    }
}

/// The hint engine of Voxel Origami (clarification Q1).
public enum VoxelOrigamiHints {
    /// The plan of `play` while `playing` or `paused` with actions left: the minimal plan from the play's current
    /// turns (``VoxelOrigamiSolver/plan(_:turns:maxTurns:workBound:)`` with the default work bound and at most
    /// `min(6, actions left)` turns), offered only when its turns fit ``VoxelOrigamiPlay/actionsLeft``. Nil in every
    /// other stage, when the search finds no plan or exceeds the work bound, and when the plan does not fit the actions
    /// left. The play is not changed.
    public static func plan(_ play: VoxelOrigamiPlay) -> VoxelOrigamiHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.actionsLeft >= 1 else { return nil }
        let cap: Int = min(VoxelOrigamiSolver.maxTurns, play.actionsLeft)
        guard let minimal = VoxelOrigamiSolver.plan(play.level, turns: play.turns, maxTurns: cap) else { return nil }
        guard !minimal.turns.isEmpty, minimal.size <= play.actionsLeft else { return nil }
        return VoxelOrigamiHintPlan(turns: minimal.turns)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first turn (`turn`,
    /// text per ``VoxelOrigamiHint/turnText(level:hinge:step:cube:)``), or `stuck` with
    /// ``VoxelOrigamiHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure), `stuck` with
    /// ``VoxelOrigamiHint/failedText``; nil in every other stage (loading, tutorial, won, result after a win). The same
    /// turn is returned at every level; the play is not changed.
    public static func hint(level: Int, play: VoxelOrigamiPlay) -> VoxelOrigamiHint? {
        switch play.stage {
        case .playing, .paused:
            break
        case .failed:
            return VoxelOrigamiHint(level: level, kind: .stuck, action: nil, text: VoxelOrigamiHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return VoxelOrigamiHint(level: level, kind: .stuck, action: nil, text: VoxelOrigamiHint.failedText)
        case .loading, .tutorial, .won:
            return nil
        }
        guard let first = plan(play)?.turns.first else {
            return VoxelOrigamiHint(level: level, kind: .stuck, action: nil, text: VoxelOrigamiHint.stuckText)
        }
        switch first {
        case .turn(let hinge, let step):
            let cubes: [VoxelOrigamiCube] = play.level.cubes
            let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: play.pose, hinge: hinge)
            let cube: Int = VoxelOrigamiPicker.trackedCube(hinge, cubes: cubes, pose: play.pose, moving: moving)
            let text: String = VoxelOrigamiHint.turnText(level: level, hinge: hinge, step: step, cube: cube)
            return VoxelOrigamiHint(level: level, kind: .turn, action: first, text: text)
        }
    }

    /// The actions still applied after `records`, in play order: a turn pushes, an undo moves the top to a redo stack,
    /// a redo moves it back and a new turn clears the redo stack, as the play's own stacks do. The i-th element is the
    /// action with 0-based index i of the current play.
    static func appliedActions(_ records: [VoxelOrigamiRecord]) -> [VoxelOrigamiAction] {
        var applied: [VoxelOrigamiAction] = []
        var undone: [VoxelOrigamiAction] = []
        for record in records {
            switch record.kind {
            case .turn:
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

/// The plain-English explanation of a failed play (FR-R02G1505-003, 007; clarification Q5), from the failing action.
public struct VoxelOrigamiFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: VoxelOrigamiFailure
    /// The number of the failing action, counted from 1 (its 0-based index + 1), as the text names it.
    public let action: Int
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// "(x, y, z)".
    static func cellText(_ cell: VoxelOrigamiVector) -> String {
        "(" + String(cell.x) + ", " + String(cell.y) + ", " + String(cell.z) + ")"
    }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With m
    /// the failing action's number (from 1) and that action a turn of hinge h by s (written "+1" or "−1"):
    /// - collision: "Action m (a turn of hinge h by s) would put cube a on cube b at (x, y, z)."
    /// - sweep: "Action m (a turn of hinge h by s) would swing cube a through cube b at (x, y, z)."
    /// - budget: "Action m (a turn of hinge h by s) spent the last action without a match."
    /// each followed by a space and ``advice``; a is the moving cube, b the still cube and (x, y, z) the cell the
    /// kernel recorded. The failing action is read from the records' actions still applied (undone ones excluded): the
    /// latest of them for a collision or a sweep (its hinge must be the failure's), the one at the recorded index for
    /// the budget. Nil when the records do not hold that action.
    public init?(play: VoxelOrigamiPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let applied: [VoxelOrigamiAction] = VoxelOrigamiHints.appliedActions(play.records)
        let index: Int
        switch failure {
        case .collision, .sweep: index = play.actionsSpent - 1
        case .budget(let value): index = value
        }
        guard index >= 0, index < applied.count else { return nil }
        guard case .turn(let hinge, let step) = applied[index] else { return nil }
        let head: String = "Action " + String(index + 1) + " (a turn of hinge " + String(hinge) + " by "
            + VoxelOrigamiHint.stepText(step) + ")"
        let sentence: String
        switch failure {
        case .collision(let failed, let moving, let still, let cell):
            guard failed == hinge else { return nil }
            sentence = head + " would put cube " + String(moving) + " on cube " + String(still) + " at "
                + Self.cellText(cell) + "."
        case .sweep(let failed, let moving, let still, let cell):
            guard failed == hinge else { return nil }
            sentence = head + " would swing cube " + String(moving) + " through cube " + String(still) + " at "
                + Self.cellText(cell) + "."
        case .budget:
            sentence = head + " spent the last action without a match."
        }
        self.failure = failure
        action = index + 1
        text = sentence + " " + Self.advice
    }
}
