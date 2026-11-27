// MushroomWeatherPlay — feature 491 (R02-G20-01) T-R02G2001-004 (FR-R02G2001-005 … 008, 011, 014; SC-R02G2001-001,
// 002, 004; clarification Q5). One play of a Mushroom Weather level: the life stage, the arrangement (the pod in every
// slot, every vent's state and the moonlight), the actions spent, the report (the truth metric, recomputed after every
// accepted arrangement action), the failure, the append-only records and the undo and redo stacks. An arrangement
// action — `place(slot:cell:)` (put a pod into a slot or move it), `remove(slot:)`, `vent(index:open:)` and
// `moonlight(level:)` — is validated in this order: stage, previous fingerprint, action (a slot, vent or moonlight out of
// range, a cell off the floor, on a colony or under another slot's pod, a change to the current value, the removal of
// an empty slot), budget (no action left); it is refused without any change, or applied and recorded, and spends 1
// action. A placed or moved pod starts ungrown with a zero integral: the arrangement holds no growth, which happens only
// during the run the report computes. The run is validated by stage and previous fingerprint only, spends nothing and
// ends the level: won when the report wins, else failed with the judge's failure. Every accepted arrangement action
// and run can be undone and redone exactly (snapshots); a new action clears the redo stack. Undo works in playing,
// paused and failed (a failed run returns to playing with the arrangement before the run, an honest retry that is
// recorded); a won run is final. The events begin, dismissTutorial, pause and resume are recorded with their own kinds
// (showResult only ends the play and is not recorded). Each record carries the schema, the level seed, its 0-based
// position in the trace, the kind, the action and the fingerprints before and after; a trace replays to the same
// records, fingerprints and outcome. Integers only; no clock, no random source. Modelled on `MicroscopicAuroraPlay`
// (feature 481).
// Feature 492 (R02-G20-02) T-R02G2002-002: on a level that lists pod sites, a placement on any other cell is refused
// `.action("not a site")`, checked after the colony cell and before the occupied cell.
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum MushroomWeatherStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Arrangement actions, the run, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The run won; `showResult` shows the result. Final: undo is refused.
    case won
    /// The run failed; undo returns to playing before the run, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum MushroomWeatherEvent: Sendable, Equatable {
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
public enum MushroomWeatherRecordKind: String, Sendable, Codable, CaseIterable {
    /// A placement or move of a pod.
    case place
    /// The removal of a pod.
    case remove
    /// A vent opened or closed.
    case vent
    /// The moonlight set.
    case moonlight
    /// The run that ended the level.
    case run
    /// An undo of the latest arrangement action or run.
    case undo
    /// A redo of the latest undone arrangement action or run.
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
public struct MushroomWeatherRecord: Sendable, Equatable, Codable {
    /// The record schema (``MushroomWeatherPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: MushroomWeatherRecordKind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: MushroomWeatherAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: MushroomWeatherRecordKind, action: MushroomWeatherAction?,
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

/// One play of a Mushroom Weather level.
public struct MushroomWeatherPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: MushroomWeatherStage
        /// The arrangement.
        let arrangement: MushroomWeatherArrangement
        /// The actions spent.
        let actionsSpent: Int
        /// The report.
        let report: MushroomWeatherReport
        /// The failure, or nil.
        let failure: MushroomWeatherFailure?
    }

    /// The level played.
    public let level: MushroomWeatherLevel
    /// The life stage.
    public private(set) var stage: MushroomWeatherStage
    /// The arrangement: the pod of every slot, every vent's state and the moonlight; the level's start at first.
    public private(set) var arrangement: MushroomWeatherArrangement
    /// The arrangement actions accepted (restored by undo and redo); the run spends nothing.
    public private(set) var actionsSpent: Int
    /// The report of ``arrangement`` in the level (the truth metric), recomputed after every arrangement action.
    public private(set) var report: MushroomWeatherReport
    /// Why the run failed, or nil (nil before the run and after a winning one).
    public private(set) var failure: MushroomWeatherFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [MushroomWeatherRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting arrangement, no action spent, no failure.
    public init(level: MushroomWeatherLevel) {
        self.level = level
        stage = .loading
        arrangement = level.start
        actionsSpent = 0
        report = MushroomWeatherForest.report(level, arrangement: level.start)
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
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","moonlight":<L>,"pods":["<p0>",…],
    /// "schema":1,"stage":"<stage>","vents":["<v0>",…]}`, where a pod is `"<row> <column>"` or `"none"`, a vent is
    /// `"open"` or `"closed"` and the failure is `"none"`, `"dried <colony> <cycle>"`,
    /// `"mold <row> <column> <cycle>"` or `"unstable <colony> <run>"`.
    public var fingerprint: String {
        var pods: String = ""
        for (position, pod) in arrangement.pods.enumerated() {
            if position > 0 { pods += "," }
            pods += "\"" + Self.text(pod) + "\""
        }
        var vents: String = ""
        for (position, open) in arrangement.ventsOpen.enumerated() {
            if position > 0 { vents += "," }
            vents += open ? "\"open\"" : "\"closed\""
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + Self.text(failure)
            + "\",\"level\":\"" + level.fingerprint + "\",\"moonlight\":" + String(arrangement.moonlight)
            + ",\"pods\":[" + pods + "],\"schema\":" + String(Self.schema) + ",\"stage\":\"" + stage.rawValue
            + "\",\"vents\":[" + vents + "]}"
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

    /// The canonical text of a slot's pod (see ``fingerprint``).
    static func text(_ pod: MushroomWeatherCell?) -> String {
        guard let pod else { return "none" }
        return words([pod.row, pod.column])
    }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: MushroomWeatherFailure?) -> String {
        switch failure {
        case .dried(let colony, let cycle):
            "dried " + words([colony, cycle])
        case .mold(let cell, let cycle):
            "mold " + words([cell.row, cell.column, cycle])
        case .unstable(let colony, let run):
            "unstable " + words([colony, run])
        case nil:
            "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event but `showResult` is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: MushroomWeatherEvent) throws(MushroomWeatherError) {
        let before: String = fingerprint
        let kind: MushroomWeatherRecordKind?
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
    static func kind(of action: MushroomWeatherAction) -> MushroomWeatherRecordKind {
        switch action {
        case .place: .place
        case .remove: .remove
        case .vent: .vent
        case .moonlight: .moonlight
        case .run: .run
        }
    }

    /// The arrangement an arrangement action asks for, checked against the ranges, the floor, the colonies, the other
    /// slots and the current arrangement (the run returns the current arrangement).
    ///
    /// - Throws: for `place`, `.action("slot out of range")` (outside 0 … P − 1), `.action("off floor")` (outside the
    ///   grid or on a blocked cell), `.action("colony cell")` (a colony stands on the cell), `.action("not a site")`
    ///   (the level lists sites and the cell is not one), `.action("occupied cell")` (another slot's pod is on the cell)
    ///   or `.action("unchanged")` (the slot's pod is already there); for `remove`, `.action("slot out of range")` or
    ///   `.action("empty slot")`; for `vent`, `.action("vent out of range")` (outside 0 … vents − 1) or
    ///   `.action("unchanged")`; for `moonlight`, `.action("moonlight out of range")` (outside 0 … 3) or
    ///   `.action("unchanged")`; each checked in this order.
    func changed(_ action: MushroomWeatherAction) throws(MushroomWeatherError) -> MushroomWeatherArrangement {
        var pods: [MushroomWeatherCell?] = arrangement.pods
        var vents: [Bool] = arrangement.ventsOpen
        var moonlight: Int = arrangement.moonlight
        switch action {
        case .place(let slot, let cell):
            guard pods.indices.contains(slot) else { throw .action("slot out of range") }
            guard level.isFloor(cell) else { throw .action("off floor") }
            guard !level.colonyCells.contains(cell) else { throw .action("colony cell") }
            // Feature 492 (R02-G20-02): a level that lists sites allows pods on its sites only.
            guard level.allowsPod(cell) else { throw .action("not a site") }
            for other in pods.indices where other != slot && pods[other] == cell { throw .action("occupied cell") }
            guard pods[slot] != cell else { throw .action("unchanged") }
            pods[slot] = cell
        case .remove(let slot):
            guard pods.indices.contains(slot) else { throw .action("slot out of range") }
            guard pods[slot] != nil else { throw .action("empty slot") }
            pods[slot] = nil
        case .vent(let index, let open):
            guard vents.indices.contains(index) else { throw .action("vent out of range") }
            guard vents[index] != open else { throw .action("unchanged") }
            vents[index] = open
        case .moonlight(let value):
            guard MushroomWeatherLevel.moonlightLevels.contains(value) else { throw .action("moonlight out of range") }
            guard moonlight != value else { throw .action("unchanged") }
            moonlight = value
        case .run:
            break
        }
        return MushroomWeatherArrangement(pods: pods, ventsOpen: vents, moonlight: moonlight)
    }

    /// Applies an action that names the current fingerprint as its previous one. An arrangement action changes one
    /// slot, vent or the moonlight, spends 1 action and recomputes the report (a placed or moved pod starts ungrown);
    /// the run spends nothing and ends the level: `won` when the report wins, else `failed` with the judge's failure.
    /// The action is recorded and the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``changed(_:)`` for an arrangement action; `.budget` for an arrangement action with no action left (the run
    ///   is still allowed). A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: MushroomWeatherAction,
                               expecting previous: String) throws(MushroomWeatherError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .place, .remove, .vent, .moonlight:
            let next: MushroomWeatherArrangement = try changed(action)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            arrangement = next
            actionsSpent += 1
            report = MushroomWeatherForest.report(level, arrangement: next)
        case .run:
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

    /// Restores the moment before the latest arrangement action or run (arrangement, actions spent, report, failure)
    /// and records the undo; from `failed` the play returns to `playing` with the arrangement before the run.
    ///
    /// - Throws: `.stage` in `won` (a won run is final) and outside `playing`, `paused` and `failed`;
    ///   `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(MushroomWeatherError) {
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

    /// Restores the moment of the latest undone arrangement action or run and records the redo (a redone run ends the
    /// level again).
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(MushroomWeatherError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, an
    /// arrangement action or run with the record's previous fingerprint, an undo or a redo). Every produced record must
    /// equal the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's; `.malformed("record <i>")` when record `i` lacks its action, names an action of
    ///   another kind, carries an action it should not or is not reproduced; any refusal of the replayed action.
    public static func replay(level: MushroomWeatherLevel,
                              records: [MushroomWeatherRecord]) throws(MushroomWeatherError) -> MushroomWeatherPlay {
        var play = MushroomWeatherPlay(level: level)
        for index in records.indices {
            let record: MushroomWeatherRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .place, .remove, .vent, .moonlight, .run:
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
        Snapshot(stage: stage, arrangement: arrangement, actionsSpent: actionsSpent, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`; a won or failed moment (a redone run) keeps its stage.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        arrangement = snapshot.arrangement
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
    private mutating func append(kind: MushroomWeatherRecordKind, action: MushroomWeatherAction?, previous: String) {
        let record = MushroomWeatherRecord(schema: Self.schema, seed: level.seed, index: records.count, kind: kind,
                                           action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
