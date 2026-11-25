// ApsidesWorkshopPlay — feature 471 (R02-G18-01) T-R02G1801-004 (FR-R02G1801-006 … 009, 011; SC-R02G1801-001, 002;
// clarification Q4). One play of an Apsides Workshop level: the life stage, the orbit, the actions spent, the orbit
// report (the truth metric, recomputed after every tuning), the failure, the append-only records and the undo and redo
// stacks. A tuning (`periapsis(k, d)` or `size(a)`) is validated in this order — stage, previous fingerprint, action
// (a step out of range, a tuning equal to the current orbit, or one making the orbit invalid), budget (no action left)
// — and refused without any change, or applied and recorded; it spends 1 action. The play is validated by stage and
// previous fingerprint only, spends nothing and ends the level: won when the report wins, else failed with the
// report's failure. Every accepted tuning and play can be undone and redone exactly (snapshots); a new action clears
// the redo stack. Undo works in playing, paused and failed (a failed play returns to playing with the orbit before the
// play, an honest retry that is recorded); a won play is final. The events begin, dismissTutorial, pause and resume
// are recorded with their own kinds (showResult only ends the play and is not recorded). Each record carries the
// schema, the level seed, its 0-based position in the trace, the kind, the action and the fingerprints before and
// after; a trace replays to the same records, fingerprints and outcome. Integers only; no clock, no random source.
// Modelled on `CelestialEclipseLabPlay` (feature 461).
import Foundation
import VisualCoreMath

/// A player action of Apsides Workshop (clarification Q4): a tuning of the periapsis knob or the size (one action
/// each) or the play that ends the level (no action). Encoded as `{"periapsis": {"_0": k, "_1": d}}`,
/// `{"size": {"_0": a}}` or `{"play": {}}`.
public enum ApsidesWorkshopAction: Sendable, Hashable, Codable {
    /// Set the eccentricity step to `0` (0 … 15) and the periapsis direction step to `1` (0 … 23), at least one of
    /// them different from the current orbit's.
    case periapsis(Int, Int)
    /// Set the size to `0` (8 … 48 lattice units, different from the current one).
    case size(Int)
    /// Fly the orbit and end the level.
    case play
}

/// The life stage of a play.
public enum ApsidesWorkshopStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Tunings, the play, undo and redo are accepted.
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
public enum ApsidesWorkshopEvent: Sendable, Equatable {
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
public enum ApsidesWorkshopRecordKind: String, Sendable, Codable, CaseIterable {
    /// A tuning of the periapsis knob.
    case periapsis
    /// A tuning of the size.
    case size
    /// The play that ended the level.
    case play
    /// An undo of the latest tuning or play.
    case undo
    /// A redo of the latest undone tuning or play.
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
public struct ApsidesWorkshopRecord: Sendable, Equatable, Codable {
    /// The record schema (``ApsidesWorkshopPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: ApsidesWorkshopRecordKind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: ApsidesWorkshopAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: ApsidesWorkshopRecordKind,
                action: ApsidesWorkshopAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of an Apsides Workshop level.
public struct ApsidesWorkshopPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: ApsidesWorkshopStage
        /// The orbit.
        let orbit: ApsidesWorkshopOrbit
        /// The actions spent.
        let actionsSpent: Int
        /// The orbit report.
        let report: ApsidesWorkshopReport
        /// The failure, or nil.
        let failure: ApsidesWorkshopFailure?
    }

    /// The level played.
    public let level: ApsidesWorkshopLevel
    /// The life stage.
    public private(set) var stage: ApsidesWorkshopStage
    /// The orbit (the level's starting orbit at first).
    public private(set) var orbit: ApsidesWorkshopOrbit
    /// The tunings accepted (restored by undo and redo); the play spends nothing.
    public private(set) var actionsSpent: Int
    /// The report of ``orbit`` in the level (the truth metric), recomputed after every change.
    public private(set) var report: ApsidesWorkshopReport
    /// Why the play failed, or nil (nil before the play and after a winning one).
    public private(set) var failure: ApsidesWorkshopFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [ApsidesWorkshopRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting orbit, no action spent, no failure.
    public init(level: ApsidesWorkshopLevel) {
        self.level = level
        stage = .loading
        orbit = level.orbit
        actionsSpent = 0
        report = ApsidesWorkshopSky.report(level, orbit: level.orbit)
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
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","orbit":[<a>,<k>,<d>],"schema":1,
    /// "stage":"<stage>"}`, where the failure is `"none"`, `"contact <planet> <tick>"`, `"order <target> <tick>"`,
    /// `"share <target> <tick> <share>"`, `"apsis-sector <target> <sector>"` or
    /// `"apsis-distance <target> <distance>"`.
    public var fingerprint: String {
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + Self.text(failure)
            + "\",\"level\":\"" + level.fingerprint + "\",\"orbit\":["
            + Self.list([orbit.size, orbit.eccentricity, orbit.direction]) + "],\"schema\":" + String(Self.schema)
            + ",\"stage\":\"" + stage.rawValue + "\"}"
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
    static func text(_ failure: ApsidesWorkshopFailure?) -> String {
        switch failure {
        case .contact(let planet, let tick):
            "contact " + words([planet, tick])
        case .order(let target, let tick):
            "order " + words([target, tick])
        case .share(let target, let tick, let share):
            "share " + words([target, tick, share])
        case .apsisSector(let target, let sector):
            "apsis-sector " + words([target, sector])
        case .apsisDistance(let target, let distance):
            "apsis-distance " + words([target, distance])
        case nil:
            "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event but `showResult` is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: ApsidesWorkshopEvent) throws(ApsidesWorkshopError) {
        let before: String = fingerprint
        let kind: ApsidesWorkshopRecordKind?
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
    static func kind(of action: ApsidesWorkshopAction) -> ApsidesWorkshopRecordKind {
        switch action {
        case .periapsis: .periapsis
        case .size: .size
        case .play: .play
        }
    }

    /// The orbit a tuning asks for, checked against the ranges and the current orbit.
    ///
    /// - Throws: `.action("eccentricity out of range")`, `.action("direction out of range")`,
    ///   `.action("size out of range")`, `.action("unchanged")` or `.action("invalid orbit")` (the periapsis would
    ///   come closer than 3 lattice units to the star or the apoapsis leave the sky).
    func tuned(_ action: ApsidesWorkshopAction) throws(ApsidesWorkshopError) -> ApsidesWorkshopOrbit {
        let next: ApsidesWorkshopOrbit
        switch action {
        case .periapsis(let eccentricity, let direction):
            guard ApsidesWorkshopOrbit.eccentricities.contains(eccentricity) else {
                throw .action("eccentricity out of range")
            }
            guard ApsidesWorkshopOrbit.directions.contains(direction) else { throw .action("direction out of range") }
            next = ApsidesWorkshopOrbit(size: orbit.size, eccentricity: eccentricity, direction: direction)
        case .size(let size):
            guard ApsidesWorkshopOrbit.sizes.contains(size) else { throw .action("size out of range") }
            next = ApsidesWorkshopOrbit(size: size, eccentricity: orbit.eccentricity, direction: orbit.direction)
        case .play:
            return orbit
        }
        guard next != orbit else { throw .action("unchanged") }
        guard next.isValid else { throw .action("invalid orbit") }
        return next
    }

    /// Applies an action that names the current fingerprint as its previous one. A tuning sets the periapsis knob or
    /// the size, spends 1 action and recomputes the report; the play spends nothing and ends the level: `won` when
    /// the report wins, else `failed` with the report's failure. The action is recorded and the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``tuned(_:)`` for a tuning; `.budget` for a tuning with no action left (the play is still allowed). A
    ///   refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: ApsidesWorkshopAction,
                               expecting previous: String) throws(ApsidesWorkshopError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .periapsis, .size:
            let next: ApsidesWorkshopOrbit = try tuned(action)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            orbit = next
            actionsSpent += 1
            report = ApsidesWorkshopSky.report(level, orbit: orbit)
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

    /// Restores the moment before the latest tuning or play (orbit, actions spent, report, failure) and records the
    /// undo; from `failed` the play returns to `playing` with the orbit before the play.
    ///
    /// - Throws: `.stage` in `won` (a won play is final, as in Celestial Eclipse Lab) and outside `playing`, `paused`
    ///   and `failed`; `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(ApsidesWorkshopError) {
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

    /// Restores the moment of the latest undone tuning or play and records the redo (a redone play ends the level
    /// again).
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(ApsidesWorkshopError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, a tuning or
    /// play with the record's previous fingerprint, an undo or a redo). Every produced record must equal the given
    /// one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's; `.malformed("record <i>")` when record `i` lacks its action, names an action of
    ///   another kind, carries an action it should not or is not reproduced; any refusal of the replayed action.
    public static func replay(level: ApsidesWorkshopLevel,
                              records: [ApsidesWorkshopRecord]) throws(ApsidesWorkshopError) -> ApsidesWorkshopPlay {
        var play = ApsidesWorkshopPlay(level: level)
        for index in records.indices {
            let record: ApsidesWorkshopRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .periapsis, .size, .play:
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
        Snapshot(stage: stage, orbit: orbit, actionsSpent: actionsSpent, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`; a won or failed moment (a redone play) keeps its stage.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        orbit = snapshot.orbit
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
    private mutating func append(kind: ApsidesWorkshopRecordKind, action: ApsidesWorkshopAction?, previous: String) {
        let record = ApsidesWorkshopRecord(schema: Self.schema, seed: level.seed, index: records.count, kind: kind,
                                           action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
