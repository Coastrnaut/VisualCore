// CelestialEclipseLabPlay — feature 461 (R02-G17-01) T-R02G1701-004 (FR-R02G1701-003, 005, 006, 009; SC-R02G1701-002 …
// 004; clarifications Q2, Q4). One play of a Celestial Eclipse Lab level: the life stage, the phase of every body, the
// actions spent, the predicted timeline (the truth metric, recomputed after every change), the failure, the append-only
// records and the undo and redo stacks. A phase change is validated in this order — stage, previous fingerprint, action
// (an unknown or fixed body, an offset outside the period or equal to the current one), budget (no action left) — and
// refused without any change, or applied and recorded; it spends 1 action. The run is validated by stage and previous
// fingerprint only, spends nothing and ends the level: won when the timeline wins, else failed with the timeline's
// failure. Every accepted phase change and run can be undone and redone exactly (snapshots); a new action clears the
// redo stack. Undo works in playing, paused and failed (a failed play returns to playing with the phases before the
// run, an honest retry that is recorded); a won play is final. The events begin, dismissTutorial, pause and resume are
// recorded with their own kinds (showResult only ends the play and is not recorded). Each record carries the schema,
// the level seed, its 0-based position in the trace, the kind, the action and the fingerprints before and after; a
// trace replays to the same records, fingerprints and outcome. Integers only; no clock, no random source. Modelled on
// `StarlitCartouchePlay` (feature 451).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum CelestialEclipseLabStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Phase changes, the run, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The run matched the target; `showResult` shows the result. Final: undo is refused.
    case won
    /// The run failed; undo returns to playing before the run, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum CelestialEclipseLabEvent: Sendable, Equatable {
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

/// The kind of an accepted action or event.
public enum CelestialEclipseLabRecordKind: String, Sendable, Codable, CaseIterable {
    /// A phase change.
    case phase
    /// The run that ended the level.
    case run
    /// An undo of the latest phase change or run.
    case undo
    /// A redo of the latest undone phase change or run.
    case redo
    /// The `begin` event.
    case begin
    /// The `dismissTutorial` event.
    case dismissTutorial
    /// The `pause` event.
    case pause
    /// The `resume` event.
    case resume
}

/// The append-only record of one accepted action or event.
public struct CelestialEclipseLabRecord: Sendable, Equatable, Codable {
    /// The record schema (``CelestialEclipseLabPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: CelestialEclipseLabRecordKind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: CelestialEclipseLabAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: CelestialEclipseLabRecordKind,
                action: CelestialEclipseLabAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Celestial Eclipse Lab level.
public struct CelestialEclipseLabPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: CelestialEclipseLabStage
        /// The phases.
        let phases: [Int]
        /// The actions spent.
        let actionsSpent: Int
        /// The predicted timeline.
        let timeline: CelestialEclipseLabTimeline
        /// The failure, or nil.
        let failure: CelestialEclipseLabFailure?
    }

    /// The level played.
    public let level: CelestialEclipseLabLevel
    /// The life stage.
    public private(set) var stage: CelestialEclipseLabStage
    /// The phase of every body (the level's starting phases at first).
    public private(set) var phases: [Int]
    /// The phase changes accepted (restored by undo and redo); the run spends nothing.
    public private(set) var actionsSpent: Int
    /// The predicted timeline of ``phases`` (the truth metric), recomputed after every change.
    public private(set) var timeline: CelestialEclipseLabTimeline
    /// Why the run failed, or nil (nil before the run and after a winning one).
    public private(set) var failure: CelestialEclipseLabFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [CelestialEclipseLabRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting phases, no action spent, no failure.
    public init(level: CelestialEclipseLabLevel) {
        self.level = level
        stage = .loading
        phases = level.phases
        actionsSpent = 0
        timeline = CelestialEclipseLabSky.timeline(level, phases: level.phases)
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
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","phases":[<p0>,…],"schema":1,
    /// "stage":"<stage>"}`, where the failure is `"none"`, `"unwanted <front> <back> <tick>"`,
    /// `"window <front> <back> <tick> <open> <close>"` or `"horizon <front> <back> <open> <close>"`.
    public var fingerprint: String {
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + Self.text(failure)
            + "\",\"level\":\"" + level.fingerprint + "\",\"phases\":[" + Self.list(phases) + "],\"schema\":"
            + String(Self.schema) + ",\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// "<a>,<b>,…".
    static func list(_ values: [Int]) -> String {
        var text: String = ""
        for (position, value) in values.enumerated() {
            if position > 0 { text += "," }
            text += String(value)
        }
        return text
    }

    /// "<a> <b> …".
    static func words(_ values: [Int]) -> String {
        var text: String = ""
        for (position, value) in values.enumerated() {
            if position > 0 { text += " " }
            text += String(value)
        }
        return text
    }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: CelestialEclipseLabFailure?) -> String {
        switch failure {
        case .unwanted(let front, let back, let tick):
            "unwanted " + words([front, back, tick])
        case .window(let front, let back, let tick, let open, let close):
            "window " + words([front, back, tick, open, close])
        case .horizon(let front, let back, let open, let close):
            "horizon " + words([front, back, open, close])
        case nil:
            "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event but `showResult` is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: CelestialEclipseLabEvent) throws(CelestialEclipseLabError) {
        let before: String = fingerprint
        let kind: CelestialEclipseLabRecordKind?
        switch (stage, event) {
        case (.loading, .begin):
            stage = level.tutorial ? .tutorial : .playing
            kind = .begin
        case (.tutorial, .dismissTutorial):
            stage = .playing
            kind = .dismissTutorial
        case (.playing, .pause):
            stage = .paused
            kind = .pause
        case (.paused, .resume):
            stage = .playing
            kind = .resume
        case (.won, .showResult), (.failed, .showResult):
            stage = .result
            kind = nil
        default:
            throw .stage
        }
        if let kind {
            append(kind: kind, action: nil, previous: before)
        }
    }

    /// The record kind of `action`.
    static func kind(of action: CelestialEclipseLabAction) -> CelestialEclipseLabRecordKind {
        switch action {
        case .phase: .phase
        case .run: .run
        }
    }

    /// Checks a phase change of `body` to `offset` against the level and the current phases.
    ///
    /// - Throws: `.action("unknown body")`, `.action("fixed body")`, `.action("offset outside the period")` or
    ///   `.action("same offset")`.
    func check(body: Int, offset: Int) throws(CelestialEclipseLabError) {
        guard body >= 0, body < level.bodies.count else { throw .action("unknown body") }
        let chosen: CelestialEclipseLabBody = level.bodies[body]
        guard !chosen.fixed else { throw .action("fixed body") }
        guard offset >= 0, offset < chosen.period else { throw .action("offset outside the period") }
        guard offset != phases[body] else { throw .action("same offset") }
    }

    /// Applies an action that names the current fingerprint as its previous one. A phase change sets the body's
    /// phase, spends 1 action and recomputes the timeline; the run spends nothing and ends the level: `won` when the
    /// timeline wins, else `failed` with the timeline's failure. The action is recorded and the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``check(body:offset:)`` for a phase change; `.budget` for a phase change with no action left (the run is
    ///   still allowed). A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: CelestialEclipseLabAction,
                               expecting previous: String) throws(CelestialEclipseLabError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .phase(let body, let offset):
            try check(body: body, offset: offset)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            phases[body] = offset
            actionsSpent += 1
            timeline = CelestialEclipseLabSky.timeline(level, phases: phases)
        case .run:
            undoStack.append(moment)
            if let refused = timeline.failure {
                stage = .failed
                failure = refused
            } else {
                stage = .won
            }
        }
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, previous: before)
    }

    /// Restores the moment before the latest phase change or run (phases, actions spent, timeline, failure) and
    /// records the undo; from `failed` the play returns to `playing` with the phases before the run.
    ///
    /// - Throws: `.stage` in `won` (a won play is final, as in Starlit Cartouche) and outside `playing`, `paused` and
    ///   `failed`; `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(CelestialEclipseLabError) {
        if stage == .won { throw .stage }
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, previous: before)
    }

    /// Restores the moment of the latest undone phase change or run and records the redo (a redone run ends the level
    /// again).
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(CelestialEclipseLabError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, a phase
    /// change or run with the record's previous fingerprint, an undo or a redo). Every produced record must equal the
    /// given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's; `.malformed("record <i>")` when record `i` lacks its action, names an action of
    ///   another kind, carries an action it should not or is not reproduced; any refusal of the replayed action.
    public static func replay(level: CelestialEclipseLabLevel,
                              records: [CelestialEclipseLabRecord]) throws(CelestialEclipseLabError)
        -> CelestialEclipseLabPlay {
        var play = CelestialEclipseLabPlay(level: level)
        for index in records.indices {
            let record: CelestialEclipseLabRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .phase, .run:
                guard let action = record.action, kind(of: action) == record.kind else {
                    throw .malformed("record \(index)")
                }
                try play.apply(action, expecting: record.previous)
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume:
                guard record.action == nil else { throw .malformed("record \(index)") }
                switch record.kind {
                case .undo: try play.undo()
                case .redo: try play.redo()
                case .begin: try play.handle(.begin)
                case .dismissTutorial: try play.handle(.dismissTutorial)
                case .pause: try play.handle(.pause)
                default: try play.handle(.resume)
                }
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// The current moment.
    private var moment: Snapshot {
        Snapshot(stage: stage, phases: phases, actionsSpent: actionsSpent, timeline: timeline, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`; a won or failed moment (a redone run) keeps its stage.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        phases = snapshot.phases
        actionsSpent = snapshot.actionsSpent
        timeline = snapshot.timeline
        failure = snapshot.failure
        if snapshot.stage == .won || snapshot.stage == .failed {
            stage = snapshot.stage
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action or event; its next fingerprint is taken after the stage change.
    private mutating func append(kind: CelestialEclipseLabRecordKind, action: CelestialEclipseLabAction?,
                                 previous: String) {
        let record = CelestialEclipseLabRecord(schema: Self.schema, seed: level.seed, index: records.count,
                                               kind: kind, action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
