// MicroscopicAuroraPlay — feature 481 (R02-G19-01) T-R02G1901-004 (FR-R02G1901-006 … 009, 011; SC-R02G1901-001, 002;
// clarification Q5). One play of a Microscopic Aurora level: the life stage, the three well slots, the actions spent,
// the report (the truth metric, recomputed after every placement and removal), the failure, the append-only records and
// the undo and redo stacks. A placement (`place(slot:well:)`) or removal (`remove(slot:)`) is validated in this order —
// stage, previous fingerprint, action (a slot or strength out of range, a cell off the dish or outside the enclosure, a
// cell another slot's well occupies, a placement equal to the slot's well, the removal of an empty slot), budget (no
// action left) — and refused without any change, or applied and recorded; it spends 1 action. The play is validated
// by stage and previous fingerprint only, spends nothing and ends the level: won when the report wins, else failed
// with the report's failure. Every accepted placement, removal and play can be undone and redone exactly (snapshots);
// a new action clears the redo stack. Undo works in playing, paused and failed (a failed play returns to playing with
// the wells before the play, an honest retry that is recorded); a won play is final. The events begin,
// dismissTutorial, pause and resume are recorded with their own kinds (showResult only ends the play and is not
// recorded). Each record carries the schema, the level seed, its 0-based position in the trace, the kind, the action
// and the fingerprints before and after; a trace replays to the same records, fingerprints and outcome. Integers only;
// no clock, no random source. Modelled on `ApsidesWorkshopPlay` (feature 471).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum MicroscopicAuroraStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Placements, removals, the play, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The play met every target; `showResult` shows the result. Final: undo is refused.
    case won
    /// The play failed; undo returns to playing before the play, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum MicroscopicAuroraEvent: Sendable, Equatable {
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
public enum MicroscopicAuroraRecordKind: String, Sendable, Codable, CaseIterable {
    /// A placement or change of a well.
    case place
    /// The removal of a well.
    case remove
    /// The play that ended the level.
    case play
    /// An undo of the latest placement, removal or play.
    case undo
    /// A redo of the latest undone placement, removal or play.
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
public struct MicroscopicAuroraRecord: Sendable, Equatable, Codable {
    /// The record schema (``MicroscopicAuroraPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: MicroscopicAuroraRecordKind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: MicroscopicAuroraAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: MicroscopicAuroraRecordKind,
                action: MicroscopicAuroraAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Microscopic Aurora level.
public struct MicroscopicAuroraPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: MicroscopicAuroraStage
        /// The wells, one entry per slot.
        let wells: [MicroscopicAuroraWell?]
        /// The actions spent.
        let actionsSpent: Int
        /// The report.
        let report: MicroscopicAuroraReport
        /// The failure, or nil.
        let failure: MicroscopicAuroraFailure?
    }

    /// The level played.
    public let level: MicroscopicAuroraLevel
    /// The life stage.
    public private(set) var stage: MicroscopicAuroraStage
    /// The wells, one entry per slot 0 … 2 (nil for an empty slot); the level's starting wells at first.
    public private(set) var wells: [MicroscopicAuroraWell?]
    /// The placements and removals accepted (restored by undo and redo); the play spends nothing.
    public private(set) var actionsSpent: Int
    /// The report of ``wells`` in the level (the truth metric), recomputed after every change.
    public private(set) var report: MicroscopicAuroraReport
    /// Why the play failed, or nil (nil before the play and after a winning one).
    public private(set) var failure: MicroscopicAuroraFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [MicroscopicAuroraRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting wells, no action spent, no failure.
    public init(level: MicroscopicAuroraLevel) {
        self.level = level
        stage = .loading
        wells = level.wells
        actionsSpent = 0
        report = MicroscopicAuroraDish.report(level, wells: level.placedWells)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// The placed wells in slot order (empty slots skipped), as passed to the report.
    public var placedWells: [MicroscopicAuroraWell] { wells.compactMap { $0 } }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","schema":1,"stage":"<stage>",
    /// "wells":["<w0>","<w1>","<w2>"]}`, where a well is `"<row> <column> <strength> <sense>"` or `"none"` and the
    /// failure is `"none"`, `"exit <swimmer> <tick>"`, `"coherence <tick> <group>"`, `"coverage <lit> <needed>"` or
    /// `"connectedness <row> <column>"`.
    public var fingerprint: String {
        var slots: String = ""
        for (position, well) in wells.enumerated() {
            if position > 0 { slots += "," }
            slots += "\"" + Self.text(well) + "\""
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + Self.text(failure)
            + "\",\"level\":\"" + level.fingerprint + "\",\"schema\":" + String(Self.schema)
            + ",\"stage\":\"" + stage.rawValue + "\",\"wells\":[" + slots + "]}"
        return StableHash.sha256Hex(Array(text.utf8))
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

    /// The canonical text of a slot's well (see ``fingerprint``).
    static func text(_ well: MicroscopicAuroraWell?) -> String {
        guard let well else { return "none" }
        return words([well.cell.row, well.cell.column, well.strength]) + " " + well.sense.rawValue
    }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: MicroscopicAuroraFailure?) -> String {
        switch failure {
        case .exit(let swimmer, let tick):
            "exit " + words([swimmer, tick])
        case .coherence(let tick, let group):
            "coherence " + words([tick, group])
        case .coverage(let lit, let needed):
            "coverage " + words([lit, needed])
        case .connectedness(let cell):
            "connectedness " + words([cell.row, cell.column])
        case nil:
            "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event but `showResult` is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: MicroscopicAuroraEvent) throws(MicroscopicAuroraError) {
        let before: String = fingerprint
        let kind: MicroscopicAuroraRecordKind?
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
    static func kind(of action: MicroscopicAuroraAction) -> MicroscopicAuroraRecordKind {
        switch action {
        case .place: .place
        case .remove: .remove
        case .play: .play
        }
    }

    /// The wells a placement or removal asks for, checked against the ranges, the enclosure, the other slots and the
    /// current wells (the play returns the current wells).
    ///
    /// - Throws: `.action("slot out of range")` (a slot outside 0 … 2), `.action("strength out of range")` (outside
    ///   1 … 4), `.action("outside cell")` (off the dish or its centre outside the enclosure), `.action("occupied
    ///   cell")` (another slot's well is on the cell), `.action("unchanged")` (equal to the slot's well) or
    ///   `.action("empty slot")` (a removal of an empty slot), checked in this order.
    func changed(_ action: MicroscopicAuroraAction) throws(MicroscopicAuroraError) -> [MicroscopicAuroraWell?] {
        var next: [MicroscopicAuroraWell?] = wells
        switch action {
        case .place(let slot, let well):
            guard wells.indices.contains(slot) else { throw .action("slot out of range") }
            guard MicroscopicAuroraWell.strengths.contains(well.strength) else {
                throw .action("strength out of range")
            }
            guard MicroscopicAuroraLevel.isUsable(well.cell, radius: level.radius) else {
                throw .action("outside cell")
            }
            for other in wells.indices where other != slot {
                if let placed = wells[other], placed.cell == well.cell { throw .action("occupied cell") }
            }
            guard wells[slot] != well else { throw .action("unchanged") }
            next[slot] = well
        case .remove(let slot):
            guard wells.indices.contains(slot) else { throw .action("slot out of range") }
            guard wells[slot] != nil else { throw .action("empty slot") }
            next[slot] = nil
        case .play:
            break
        }
        return next
    }

    /// Applies an action that names the current fingerprint as its previous one. A placement or removal changes one
    /// slot, spends 1 action and recomputes the report (the placed wells in slot order); the play spends nothing and
    /// ends the level: `won` when the report wins, else `failed` with the report's failure. The action is recorded and
    /// the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``changed(_:)`` for a placement or removal; `.budget` for a placement or removal with no action left (the
    ///   play is still allowed). A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: MicroscopicAuroraAction,
                               expecting previous: String) throws(MicroscopicAuroraError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .place, .remove:
            let next: [MicroscopicAuroraWell?] = try changed(action)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            wells = next
            actionsSpent += 1
            report = MicroscopicAuroraDish.report(level, wells: placedWells)
        case .play:
            undoStack.append(moment)
            if let refused = report.failure {
                stage = .failed
                failure = refused
            } else {
                stage = .won
            }
        }
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, previous: before)
    }

    /// Restores the moment before the latest placement, removal or play (wells, actions spent, report, failure) and
    /// records the undo; from `failed` the play returns to `playing` with the wells before the play.
    ///
    /// - Throws: `.stage` in `won` (a won play is final, as in Apsides Workshop) and outside `playing`, `paused` and
    ///   `failed`; `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(MicroscopicAuroraError) {
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

    /// Restores the moment of the latest undone placement, removal or play and records the redo (a redone play ends
    /// the level again).
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(MicroscopicAuroraError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, a placement,
    /// removal or play with the record's previous fingerprint, an undo or a redo). Every produced record must equal
    /// the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's; `.malformed("record <i>")` when record `i` lacks its action, names an action of
    ///   another kind, carries an action it should not or is not reproduced; any refusal of the replayed action.
    public static func replay(level: MicroscopicAuroraLevel,
                              records: [MicroscopicAuroraRecord]) throws(MicroscopicAuroraError)
        -> MicroscopicAuroraPlay {
        var play = MicroscopicAuroraPlay(level: level)
        for index in records.indices {
            let record: MicroscopicAuroraRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .place, .remove, .play:
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
        Snapshot(stage: stage, wells: wells, actionsSpent: actionsSpent, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`; a won or failed moment (a redone play) keeps its stage.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        wells = snapshot.wells
        actionsSpent = snapshot.actionsSpent
        report = snapshot.report
        failure = snapshot.failure
        if snapshot.stage == .won || snapshot.stage == .failed {
            stage = snapshot.stage
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action or event; its next fingerprint is taken after the stage change.
    private mutating func append(kind: MicroscopicAuroraRecordKind, action: MicroscopicAuroraAction?,
                                 previous: String) {
        let record = MicroscopicAuroraRecord(schema: Self.schema, seed: level.seed, index: records.count, kind: kind,
                                             action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
