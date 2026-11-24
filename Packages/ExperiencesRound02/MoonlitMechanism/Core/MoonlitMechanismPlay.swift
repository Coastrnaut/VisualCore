// MoonlitMechanismPlay — feature 431 (R02-G14-01) T-R02G1401-004 (FR-R02G1401-004 … 008, 011, 014;
// SC-R02G1401-002, 003, 004; clarifications Q2, Q4, Q5). One play of a Moonlit Mechanism level: the life stage, the
// phase of every gear, the lamp height, the actions spent, the report (the level's run of the current set-up, the truth
// metric, recomputed after every change), the failure, the append-only records and the undo and redo stacks. An action
// is validated in this order — stage, previous fingerprint, action (an unknown gear, re-seating the driver, a step other
// than ±1, a lamp step out of range) — and refused without any change, or applied and recorded. A turn (every gear in
// its direction), a re-seat (one gear, never the driver) and a lamp step each change the set-up and spend 1 action; a
// run spends 1 action and decides the level: won when the run wins (even on the last action of the budget), else failed
// with `jammed(child)`, `forbidden(frame, cell)`, `missing(frame, count)` or `stray(frame, count)`. After any other
// accepted action, a budget fully spent without a win fails the level with `budget(index)`, the 0-based index of that
// action. Every accepted action can be undone and redone exactly (snapshots); a new action clears the redo stack. Undo
// works in playing, paused and failed (a failed play returns to playing, an honest retry that is recorded); a won play
// is final. A record trace replays to the same records, fingerprints and outcome. Integers only; no clock, no random
// source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum MoonlitMechanismFailure: Sendable, Hashable, Codable {
    /// A run found the mesh of this child gear with its parent out of alignment (the first such child).
    case jammed(Int)
    /// A run's key frame `frame` shadowed forbidden cell `cell` (the lowest-numbered one).
    case forbidden(frame: Int, cell: Int)
    /// A run's required key frame `frame` left `count` target cells uncovered.
    case missing(frame: Int, count: Int)
    /// A run's required key frame `frame` cast `count` cells outside its target, more than the allowance.
    case stray(frame: Int, count: Int)
    /// The action with this 0-based index spent the last of the budget without a win.
    case budget(Int)

    /// The stable failure code: `jammed`, `forbidden`, `missing`, `stray` or `budget`.
    public var code: String {
        switch self {
        case .jammed: "jammed"
        case .forbidden: "forbidden"
        case .missing: "missing"
        case .stray: "stray"
        case .budget: "budget"
        }
    }
}

/// The life stage of a play.
public enum MoonlitMechanismStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// A run won; `showResult` shows the result. Final: undo is refused.
    case won
    /// A run failed or the budget ran out; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum MoonlitMechanismEvent: Sendable, Equatable {
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
public enum MoonlitMechanismRecordKind: String, Sendable, Codable {
    /// A handle turn.
    case turn
    /// A re-seat of one gear.
    case reseat
    /// A lamp step.
    case lamp
    /// A run.
    case run
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct MoonlitMechanismRecord: Sendable, Equatable, Codable {
    /// The record schema (``MoonlitMechanismPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions spent before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: MoonlitMechanismRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: MoonlitMechanismAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: MoonlitMechanismRecordKind,
                action: MoonlitMechanismAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Moonlit Mechanism level.
public struct MoonlitMechanismPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: MoonlitMechanismStage
        /// The phases.
        let phases: [Int]
        /// The lamp height.
        let height: Int
        /// The actions spent.
        let actionsSpent: Int
        /// The run report of the set-up.
        let report: MoonlitMechanismRunReport
        /// The failure, or nil.
        let failure: MoonlitMechanismFailure?
    }

    /// The level played.
    public let level: MoonlitMechanismLevel
    /// The life stage.
    public private(set) var stage: MoonlitMechanismStage
    /// The phase of every gear, in gear order.
    public private(set) var phases: [Int]
    /// The lamp height, 0 … L − 1.
    public private(set) var height: Int
    /// The actions accepted (restored by undo and redo); the next action's 0-based index.
    public private(set) var actionsSpent: Int
    /// The level's run of ``phases`` at ``height`` (the truth metric), recomputed after every change.
    public private(set) var report: MoonlitMechanismRunReport
    /// Why the play failed, or nil.
    public private(set) var failure: MoonlitMechanismFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [MoonlitMechanismRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting phases and starting height, no action spent, no
    /// failure.
    public init(level: MoonlitMechanismLevel) {
        self.level = level
        stage = .loading
        phases = level.startingPhases
        height = level.startingHeight
        actionsSpent = 0
        report = level.run(phases: level.startingPhases, height: level.startingHeight)
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
    /// `{"actions":<spent>,"failure":"<f>","height":<h>,"level":"<level fingerprint>","phases":[<q>,…],"schema":1,
    /// "stage":"<stage>"}`, where the failure is `"none"`, `"jammed <child>"`, `"forbidden <frame> <cell>"`,
    /// `"missing <frame> <count>"`, `"stray <frame> <count>"` or `"budget <index>"` and the phases are in gear order.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .jammed(let child): failureText = "jammed " + String(child)
        case .forbidden(let frame, let cell): failureText = "forbidden " + String(frame) + " " + String(cell)
        case .missing(let frame, let count): failureText = "missing " + String(frame) + " " + String(count)
        case .stray(let frame, let count): failureText = "stray " + String(frame) + " " + String(count)
        case .budget(let index): failureText = "budget " + String(index)
        case nil: failureText = "none"
        }
        var phasesText: String = ""
        for (position, phase) in phases.enumerated() {
            if position > 0 { phasesText += "," }
            phasesText += String(phase)
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + failureText
            + "\",\"height\":" + String(height) + ",\"level\":\"" + level.fingerprint + "\",\"phases\":["
            + phasesText + "],\"schema\":" + String(Self.schema) + ",\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: MoonlitMechanismEvent) throws(MoonlitMechanismError) {
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
    static func kind(of action: MoonlitMechanismAction) -> MoonlitMechanismRecordKind {
        switch action {
        case .turn: .turn
        case .reseat: .reseat
        case .lamp: .lamp
        case .run: .run
        }
    }

    /// Checks `action` against the machine.
    ///
    /// - Throws: `.action("gear")` for a re-seat of an unknown gear; `.action("driver")` for a re-seat of gear 0;
    ///   `.action("step")` for a turn, re-seat or lamp step other than ±1; `.action("lamp")` for a lamp step that would
    ///   leave 0 … L − 1.
    func check(_ action: MoonlitMechanismAction) throws(MoonlitMechanismError) {
        switch action {
        case .turn(let step):
            guard step == 1 || step == -1 else { throw .action("step") }
        case .reseat(let gear, let step):
            guard gear >= 0, gear < level.gears.count else { throw .action("gear") }
            guard gear != 0 else { throw .action("driver") }
            guard step == 1 || step == -1 else { throw .action("step") }
        case .lamp(let step):
            guard step == 1 || step == -1 else { throw .action("step") }
            guard height + step >= 0, height + step < level.lampHeights else { throw .action("lamp") }
        case .run:
            return
        }
    }

    /// Applies an action that names the current fingerprint as its previous one: a turn, a re-seat or a lamp step
    /// (changes the set-up) or a run (decides the level: won when the run wins, else failed `jammed`, `forbidden`,
    /// `missing` or `stray`); each spends 1 action. After a turn, re-seat or lamp step that spends the last of the
    /// budget without a win, the play fails `budget(index)`. The report is recomputed and the action recorded.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``check(_:)``. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: MoonlitMechanismAction,
                               expecting previous: String) throws(MoonlitMechanismError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try check(action)
        let snapshot: Snapshot = moment
        let actionIndex: Int = actionsSpent
        actionsSpent += 1
        switch action {
        case .turn(let step):
            phases = MoonlitMechanismTrain.turned(level.gears, phases: phases, by: step)
        case .reseat(let gear, let step):
            phases[gear] = MoonlitMechanismTrain.mod(phases[gear] + step, level.gears[gear].teeth)
        case .lamp(let step):
            height += step
        case .run:
            break
        }
        report = level.run(phases: phases, height: height)
        if action == .run {
            switch report.outcome {
            case .won: stage = .won
            case .jammed(let child):
                stage = .failed
                failure = .jammed(child)
            case .forbidden(let frame, let cell):
                stage = .failed
                failure = .forbidden(frame: frame, cell: cell)
            case .missing(let frame, let count):
                stage = .failed
                failure = .missing(frame: frame, count: count)
            case .stray(let frame, let count):
                stage = .failed
                failure = .stray(frame: frame, count: count)
            }
        } else if actionsSpent >= level.budget {
            stage = .failed
            failure = .budget(actionIndex)
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, index: actionIndex, previous: before)
    }

    /// Restores the moment before the latest action (phases, lamp height, actions spent, report, failure) and records
    /// the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(MoonlitMechanismError) {
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
    public mutating func redo() throws(MoonlitMechanismError) {
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
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused or resumed, the replay pauses or resumes first. Every produced record must equal the given
    /// one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")` or `.malformed("seed <i>")` when record `i` has another schema or level
    ///   seed; `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action, names an action of another kind or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: MoonlitMechanismLevel, records: [MoonlitMechanismRecord])
        throws(MoonlitMechanismError) -> MoonlitMechanismPlay {
        var play = MoonlitMechanismPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: MoonlitMechanismRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: MoonlitMechanismPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .turn, .reseat, .lamp, .run:
                guard let action = record.action, kind(of: action) == record.kind else {
                    throw .malformed("record \(index)")
                }
                try play.apply(action, expecting: record.previous)
            case .undo: try play.undo()
            case .redo: try play.redo()
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// The current moment.
    private var moment: Snapshot {
        Snapshot(stage: stage, phases: phases, height: height, actionsSpent: actionsSpent, report: report,
                 failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        phases = snapshot.phases
        height = snapshot.height
        actionsSpent = snapshot.actionsSpent
        report = snapshot.report
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: MoonlitMechanismRecordKind, action: MoonlitMechanismAction?, index: Int,
                                 previous: String) {
        let record = MoonlitMechanismRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                            action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
