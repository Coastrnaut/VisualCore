// BinaryGardensPlay — feature 501 (R02-G21-01) T-R02G2101-004 (FR-R02G2101-005 … 008, 011, 014; SC-R02G2101-001,
// 002, 004; clarification Q5). One play of a Binary Gardens level: the life stage, the arrangement (both stars' rings,
// phases and luminosities and the orbit tilt), the actions spent, the light report (the truth metric, recomputed after
// every accepted arrangement action), the failure, the append-only records and the undo and redo stacks. An arrangement
// action — `ring(star:index:)`, `phase(star:step:)`, `luminosity(star:index:)` and `tilt(step:)` — is validated in this
// order: stage, previous fingerprint, action (a star, ring, phase, luminosity or tilt out of range, a locked control, an
// unchanged value, an arrangement that breaks the stars' minimum separation at a tick of 0 … 47), budget (no action
// left); it is refused without any change, or applied and recorded, and spends 1 action. The run ("commit light
// window") is validated by stage and previous fingerprint only, spends nothing and ends the level: won when the report
// wins, else failed with the judge's failure. Every accepted arrangement action and run can be undone and redone exactly
// (snapshots); a new action clears the redo stack. Undo and redo work in playing; undo also from failed (a failed run
// returns to playing with the arrangement before the run, actions spent unchanged, an honest retry that is recorded);
// a redo after it re-runs the run and ends failed again with the same failure; a won run is final; nothing but resume
// is accepted while paused. The events begin, dismissTutorial, pause, resume and showResult are recorded with their own
// kinds. Each record carries the schema, the level seed, its 0-based position in the trace, the kind, the action and
// the fingerprints before and after; a trace replays to the same records, fingerprints and outcome. Integers only; no
// clock, no random source. Modelled on `MushroomWeatherPlay` (feature 491).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum BinaryGardensStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Arrangement actions, the run, undo and redo are accepted.
    case playing
    /// Play is paused; only `resume` is accepted.
    case paused
    /// The run won; `showResult` shows the result. Final: undo is refused.
    case won
    /// The run failed; undo returns to playing before the run, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum BinaryGardensEvent: Sendable, Equatable {
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

/// The append-only record of one accepted action or event.
public struct BinaryGardensRecord: Sendable, Equatable, Codable {
    /// The kind of an accepted action or event.
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// A star moved to another ring.
        case ring
        /// A star's phase shifted.
        case phase
        /// A star's luminosity set.
        case luminosity
        /// The orbit plane tilted.
        case tilt
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
        /// The `showResult` event.
        case showResult
    }

    /// The record schema (``BinaryGardensPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let levelSeed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: Kind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: BinaryGardensAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, levelSeed: UInt64, index: Int, kind: Kind, action: BinaryGardensAction?,
                previous: String, next: String) {
        self.schema = schema
        self.levelSeed = levelSeed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Binary Gardens level.
public struct BinaryGardensPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: BinaryGardensStage
        /// The arrangement.
        let arrangement: BinaryGardensArrangement
        /// The actions spent.
        let actionsSpent: Int
        /// The report.
        let report: BinaryGardensReport
        /// The failure, or nil.
        let failure: BinaryGardensFailure?
    }

    /// The level played.
    public let level: BinaryGardensLevel
    /// The life stage.
    public private(set) var stage: BinaryGardensStage
    /// The arrangement: both stars' rings, phases and luminosities and the tilt; the level's start at first.
    public private(set) var arrangement: BinaryGardensArrangement
    /// The arrangement actions accepted (restored by undo and redo); the run spends nothing.
    public private(set) var actionsSpent: Int
    /// The light report of ``arrangement`` in the level (the truth metric), recomputed after every arrangement action.
    public private(set) var report: BinaryGardensReport
    /// Why the run failed, or nil (nil before the run and after a winning one).
    public private(set) var failure: BinaryGardensFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [BinaryGardensRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting arrangement, no action spent, no failure.
    public init(level: BinaryGardensLevel) {
        self.level = level
        stage = .loading
        arrangement = level.start
        actionsSpent = 0
        report = BinaryGardensSky.report(level, arrangement: level.start)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { (stage == .playing || stage == .failed) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { stage == .playing && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","luminosities":[<l1>,<l2>],
    /// "phases":[<p1>,<p2>],"rings":[<r1>,<r2>],"schema":1,"stage":"<stage>","tilt":<t>}`, where the failure is
    /// `"none"`, `"frozen <world> <tick>"`, `"scorched <world> <tick>"`, `"unstable <world> <window> <required>"`,
    /// `"wilted <world> <integral> <low> <high>"` or `"bleached <world> <integral> <low> <high>"`.
    public var fingerprint: String {
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + Self.text(failure)
            + "\",\"level\":\"" + level.fingerprint + "\",\"luminosities\":[" + Self.list(arrangement.luminosities)
            + "],\"phases\":[" + Self.list(arrangement.phases) + "],\"rings\":[" + Self.list(arrangement.rings)
            + "],\"schema\":" + String(Self.schema) + ",\"stage\":\"" + stage.rawValue + "\",\"tilt\":"
            + String(arrangement.tilt) + "}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// "<a>,<b>,…".
    static func list(_ values: [Int]) -> String { values.map { String($0) }.joined(separator: ",") }

    /// "<a> <b> …".
    static func words(_ values: [Int]) -> String { values.map { String($0) }.joined(separator: " ") }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: BinaryGardensFailure?) -> String {
        switch failure {
        case .frozen(let world, let tick): "frozen " + words([world, tick])
        case .scorched(let world, let tick): "scorched " + words([world, tick])
        case .unstable(let world, let window, let required): "unstable " + words([world, window, required])
        case .wilted(let world, let integral, let low, let high): "wilted " + words([world, integral, low, high])
        case .bleached(let world, let integral, let low, let high): "bleached " + words([world, integral, low, high])
        case nil: "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: BinaryGardensEvent) throws(BinaryGardensError) {
        let before: String = fingerprint
        let kind: BinaryGardensRecord.Kind
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
            kind = .showResult
        default:
            throw .stage
        }
        append(kind: kind, action: nil, previous: before)
    }

    /// The record kind of `action`.
    static func kind(of action: BinaryGardensAction) -> BinaryGardensRecord.Kind {
        switch action {
        case .ring: .ring
        case .phase: .phase
        case .luminosity: .luminosity
        case .tilt: .tilt
        case .run: .run
        }
    }

    /// Applies an action that names the current fingerprint as its previous one. An arrangement action changes one
    /// star's ring, phase or luminosity or the tilt, spends 1 action and recomputes the report; the run spends nothing
    /// and ends the level: `won` when the report wins, else `failed` with the judge's failure. The action is recorded
    /// and the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` for an
    ///   arrangement action out of range, on a locked control, unchanged or breaking the minimum separation (in this
    ///   order); `.budget` for an arrangement action with no action left (the run is still allowed). A refused action
    ///   spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: BinaryGardensAction,
                               expecting previous: String) throws(BinaryGardensError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .ring, .phase, .luminosity, .tilt:
            let next: BinaryGardensArrangement = try BinaryGardensSky.changed(level, arrangement, by: action)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            arrangement = next
            actionsSpent += 1
            report = BinaryGardensSky.report(level, arrangement: next)
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
    /// - Throws: `.stage` outside `playing` and `failed` (a won run is final; nothing is undone while paused);
    ///   `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(BinaryGardensError) {
        guard stage == .playing || stage == .failed else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier)
        append(kind: .undo, action: nil, previous: before)
    }

    /// Restores the moment of the latest undone arrangement action or run and records the redo (a redone run ends the
    /// level again with the same outcome).
    ///
    /// - Throws: `.stage` outside `playing`; `.action("redo")` when nothing was undone. A refused redo leaves the play
    ///   unchanged.
    public mutating func redo() throws(BinaryGardensError) {
        guard stage == .playing else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, an
    /// arrangement action or run with the record's previous fingerprint, an undo or a redo). The chain must start at
    /// the initial fingerprint and link every next to the following previous, and every produced record must equal the
    /// given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's (a trace of another level breaks the chain at record 0); `.malformed("record <i>")`
    ///   when record `i` lacks its action, names an action of another kind, carries an action it should not or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: BinaryGardensLevel,
                              records: [BinaryGardensRecord]) throws(BinaryGardensError) -> BinaryGardensPlay {
        var play = BinaryGardensPlay(level: level)
        for index in records.indices {
            let record: BinaryGardensRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.levelSeed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .ring, .phase, .luminosity, .tilt, .run:
                guard let action = record.action, kind(of: action) == record.kind else {
                    throw .malformed("record \(index)")
                }
                try play.apply(action, expecting: record.previous)
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume, .showResult:
                guard record.action == nil else { throw .malformed("record \(index)") }
                switch record.kind {
                case .undo: try play.undo()
                case .redo: try play.redo()
                case .begin: try play.handle(.begin)
                case .dismissTutorial: try play.handle(.dismissTutorial)
                case .pause: try play.handle(.pause)
                case .resume: try play.handle(.resume)
                default: try play.handle(.showResult)
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

    /// Restores `snapshot`; a moment taken while playing comes back as `playing`; a won or failed moment (a redone run)
    /// keeps its stage.
    private mutating func restore(_ snapshot: Snapshot) {
        arrangement = snapshot.arrangement
        actionsSpent = snapshot.actionsSpent
        report = snapshot.report
        failure = snapshot.failure
        stage = (snapshot.stage == .won || snapshot.stage == .failed) ? snapshot.stage : .playing
    }

    /// Appends the record of an accepted action or event; its next fingerprint is taken after the stage change.
    private mutating func append(kind: BinaryGardensRecord.Kind, action: BinaryGardensAction?, previous: String) {
        let record = BinaryGardensRecord(schema: Self.schema, levelSeed: level.seed, index: records.count, kind: kind,
                                         action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
