// VoxelOrigamiPlay — feature 441 (R02-G15-01) T-R02G1501-004 (FR-R02G1501-004 … 008, 012; SC-R02G1501-001, 002, 004;
// clarifications Q2, Q3, Q5). One play of a Voxel Origami level: the life stage, the quarter turn of every hinge, the
// actions spent, the pose, the shape report (the truth metric, recomputed after every action), the failure, the
// append-only records and the undo and redo stacks. A turn is validated in this order — stage, previous fingerprint,
// action (an unknown hinge, a step other than ±1, a hinge with nothing that would move) — and refused without any change,
// or applied and recorded. Every accepted turn spends 1 action. A turn that the lattice check refuses fails the level on
// that turn with `collision` or `sweep` (the turns and the pose stay as they were); a clear turn changes the turns and
// wins when the shape matches the target (even on the last action of the budget), else a budget fully spent fails the
// level with `budget(index)`, the 0-based index of that action. Every accepted action can be undone and redone exactly
// (snapshots); a new turn clears the redo stack. Undo works in playing, paused and failed (a failed play returns to
// playing before the failing turn, its action refunded, an honest retry that is recorded); a won play is final. A record
// trace replays to the same records, fingerprints and outcome. Integers only; no clock, no random source. Modelled on
// `MoonlitMechanismPlay` (feature 431).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum VoxelOrigamiStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Turns, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The shape matches the target; `showResult` shows the result. Final: undo is refused.
    case won
    /// A turn collided or swept through a cube, or the budget ran out; undo returns to playing, `showResult` shows the
    /// result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum VoxelOrigamiEvent: Sendable, Equatable {
    /// `loading` → `tutorial` (when the level asks for one) or `playing`.
    case begin
    /// `tutorial` → `playing`.
    case dismissTutorial
    /// `playing` → `paused`.
    case pause
    /// `paused` → `playing`.
    case resume
    /// `won` or `failed` → `result`.
    case showResult
}

/// The kind of an accepted action.
public enum VoxelOrigamiRecordKind: String, Sendable, Codable {
    /// A hinge turn.
    case turn
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct VoxelOrigamiRecord: Sendable, Equatable, Codable {
    /// The record schema (``VoxelOrigamiPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions spent before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: VoxelOrigamiRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: VoxelOrigamiAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: VoxelOrigamiRecordKind, action: VoxelOrigamiAction?,
                previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Voxel Origami level.
public struct VoxelOrigamiPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: VoxelOrigamiStage
        /// The quarter turns.
        let turns: [Int]
        /// The actions spent.
        let actionsSpent: Int
        /// The pose of the turns.
        let pose: VoxelOrigamiPose
        /// The shape report of the pose.
        let report: VoxelOrigamiShapeReport
        /// The failure, or nil.
        let failure: VoxelOrigamiFailure?
    }

    /// The level played.
    public let level: VoxelOrigamiLevel
    /// The life stage.
    public private(set) var stage: VoxelOrigamiStage
    /// The quarter turn of every hinge, one per cube (0 for the root).
    public private(set) var turns: [Int]
    /// The actions accepted (restored by undo and redo); the next action's 0-based index.
    public private(set) var actionsSpent: Int
    /// The pose of ``turns``.
    public private(set) var pose: VoxelOrigamiPose
    /// The level's shape report of ``turns`` (the truth metric), recomputed after every action.
    public private(set) var report: VoxelOrigamiShapeReport
    /// Why the play failed, or nil.
    public private(set) var failure: VoxelOrigamiFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [VoxelOrigamiRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting turns, no action spent, no failure.
    public init(level: VoxelOrigamiLevel) {
        self.level = level
        stage = .loading
        turns = level.startTurns
        actionsSpent = 0
        pose = level.pose(turns: level.startTurns)
        report = level.report(turns: level.startTurns)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","schema":1,"stage":"<stage>",
    /// "turns":[<q>,…]}`, where the failure is `"none"`, `"collision <hinge> <moving> <still> <x> <y> <z>"`,
    /// `"sweep <hinge> <moving> <still> <x> <y> <z>"` or `"budget <index>"` and the turns are in cube order.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .collision(let hinge, let moving, let still, let cell):
            failureText = "collision " + Self.text(hinge, moving, still, cell)
        case .sweep(let hinge, let moving, let still, let cell):
            failureText = "sweep " + Self.text(hinge, moving, still, cell)
        case .budget(let index):
            failureText = "budget " + String(index)
        case nil:
            failureText = "none"
        }
        var turnsText: String = ""
        for (position, turn) in turns.enumerated() {
            if position > 0 { turnsText += "," }
            turnsText += String(turn)
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + failureText
            + "\",\"level\":\"" + level.fingerprint + "\",\"schema\":" + String(Self.schema) + ",\"stage\":\""
            + stage.rawValue + "\",\"turns\":[" + turnsText + "]}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// "<hinge> <moving> <still> <x> <y> <z>".
    static func text(_ hinge: Int, _ moving: Int, _ still: Int, _ cell: VoxelOrigamiVector) -> String {
        String(hinge) + " " + String(moving) + " " + String(still) + " " + String(cell.x) + " " + String(cell.y) + " "
            + String(cell.z)
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: VoxelOrigamiEvent) throws(VoxelOrigamiError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// The record kind of `action`.
    static func kind(of action: VoxelOrigamiAction) -> VoxelOrigamiRecordKind {
        switch action {
        case .turn: .turn
        }
    }

    /// Checks `action` against the current turns.
    ///
    /// - Throws: `.action("hinge")` for a hinge outside 1 … n − 1; `.action("step")` for a step other than ±1;
    ///   `.action("idle")` for a hinge whose turn would swing no cube (a leaf, or every descendant on its axis).
    func check(_ action: VoxelOrigamiAction) throws(VoxelOrigamiError) {
        switch action {
        case .turn(let hinge, let step):
            guard hinge >= 1, hinge < level.cubes.count else { throw .action("hinge") }
            guard step == 1 || step == -1 else { throw .action("step") }
            guard level.canTurn(hinge, turns: turns) else { throw .action("idle") }
        }
    }

    /// Applies a turn that names the current fingerprint as its previous one; it spends 1 action. When the lattice
    /// check refuses the turn, the play fails `collision` or `sweep` on that turn and the turns and pose stay as they
    /// were. Otherwise the turns change; the play is won when the shape matches the target (even on the last action of
    /// the budget), else a turn that spends the last of the budget fails `budget(index)`. The report is recomputed and
    /// the action recorded.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``check(_:)``. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: VoxelOrigamiAction, expecting previous: String) throws(VoxelOrigamiError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try check(action)
        let snapshot: Snapshot = moment
        let actionIndex: Int = actionsSpent
        actionsSpent += 1
        switch action {
        case .turn(let hinge, let step):
            if let refused = VoxelOrigamiLattice.check(level.cubes, turns: turns, hinge: hinge, step: step) {
                stage = .failed
                failure = refused
            } else {
                turns = VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
                pose = level.pose(turns: turns)
            }
        }
        report = level.report(turns: turns)
        if stage == .playing {
            if report.matched {
                stage = .won
            } else if actionsSpent >= level.budget {
                stage = .failed
                failure = .budget(actionIndex)
            }
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, index: actionIndex, previous: before)
    }

    /// Restores the moment before the latest action (turns, actions spent, pose, report, failure) and records the
    /// undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(VoxelOrigamiError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        let spentBefore: Int = actionsSpent
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, index: spentBefore, previous: before)
    }

    /// Restores the moment of the latest undone action and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(VoxelOrigamiError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let spentBefore: Int = actionsSpent
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, index: spentBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (a turn with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused or resumed, the replay pauses or resumes first. Every produced record must equal the given
    /// one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")` or `.malformed("seed <i>")` when record `i` has another schema or level
    ///   seed; `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action, names an action of another kind or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: VoxelOrigamiLevel,
                              records: [VoxelOrigamiRecord]) throws(VoxelOrigamiError) -> VoxelOrigamiPlay {
        var play = VoxelOrigamiPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: VoxelOrigamiRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: VoxelOrigamiPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .turn:
                guard let action = record.action, kind(of: action) == record.kind else {
                    throw .malformed("record \(index)")
                }
                try play.apply(action, expecting: record.previous)
            case .undo:
                guard record.action == nil else { throw .malformed("record \(index)") }
                try play.undo()
            case .redo:
                guard record.action == nil else { throw .malformed("record \(index)") }
                try play.redo()
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// The current moment.
    private var moment: Snapshot {
        Snapshot(stage: stage, turns: turns, actionsSpent: actionsSpent, pose: pose, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        turns = snapshot.turns
        actionsSpent = snapshot.actionsSpent
        pose = snapshot.pose
        report = snapshot.report
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: VoxelOrigamiRecordKind, action: VoxelOrigamiAction?, index: Int,
                                 previous: String) {
        let record = VoxelOrigamiRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                        action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
