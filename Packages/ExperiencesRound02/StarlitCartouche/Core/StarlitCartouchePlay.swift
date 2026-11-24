// StarlitCartouchePlay — feature 451 (R02-G16-01) T-R02G1601-004 (FR-R02G1601-002 … 008, 014; SC-R02G1601-002 … 004;
// clarifications Q2 … Q5). One play of a Starlit Cartouche level: the life stage, the ship's star and beat, the drawn
// strokes, the legs flown, the actions spent, the route report (the truth metric, recomputed after every action), the
// failure, the append-only records and the undo and redo stacks. A leg is validated in this order — stage, previous
// fingerprint, action (the chart's refusals: an unknown star, the ship's own star, no corridor, a wait outside 0 … 8,
// stars out of range at departure) — and refused without any change, or applied and recorded. Every accepted leg spends
// 1 action. A leg that the chart's check fails fails the level on that leg with `departure`, `hazard`, `arrival`,
// `deadline` or `stroke` (the ship, beat, strokes and legs stay as they were); a clear leg moves the ship, draws its
// corridor and wins when the drawn set equals the symbol with the ship at the beacon (even on the last action of the
// budget), else a budget fully spent fails the level with `budget(actionsSpent)`, the action count. Every accepted
// action can be undone and redone exactly (snapshots); a new leg clears the redo stack. Undo works in playing, paused
// and failed (a failed play returns to playing before the failing leg, its action refunded, an honest retry that is
// recorded); a won play is final. A record trace replays to the same records, fingerprints and outcome. Integers only;
// no clock, no random source. Modelled on `VoxelOrigamiPlay` (feature 441).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum StarlitCartoucheStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Legs, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The cartouche is drawn and the ship is at the beacon; `showResult` shows the result. Final: undo is refused.
    case won
    /// A leg broke a window, met a hazard, missed the deadline or drew a stray stroke, or the budget ran out; undo
    /// returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum StarlitCartoucheEvent: Sendable, Equatable {
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
public enum StarlitCartoucheRecordKind: String, Sendable, Codable {
    /// A leg flown.
    case leg
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct StarlitCartoucheRecord: Sendable, Equatable, Codable {
    /// The record schema (``StarlitCartouchePlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions spent before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: StarlitCartoucheRecordKind
    /// The action applied (its star and wait); nil for an undo or a redo.
    public let action: StarlitCartoucheAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: StarlitCartoucheRecordKind,
                action: StarlitCartoucheAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Starlit Cartouche level.
public struct StarlitCartouchePlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: StarlitCartoucheStage
        /// The ship's star.
        let star: Int
        /// The current beat.
        let beat: Int
        /// The drawn strokes.
        let drawn: Set<Int>
        /// The legs flown.
        let legs: [StarlitCartoucheLeg]
        /// The actions spent.
        let actionsSpent: Int
        /// The route report.
        let report: StarlitCartoucheRouteReport
        /// The failure, or nil.
        let failure: StarlitCartoucheFailure?
    }

    /// The level played.
    public let level: StarlitCartoucheLevel
    /// The life stage.
    public private(set) var stage: StarlitCartoucheStage
    /// The star the ship is at.
    public private(set) var star: Int
    /// The current beat (the arrival beat of the latest leg; 0 at the start).
    public private(set) var beat: Int
    /// The corridors drawn by accepted legs (a retraced stroke counts once).
    public private(set) var drawn: Set<Int>
    /// The legs flown, in order.
    public private(set) var legs: [StarlitCartoucheLeg]
    /// The actions accepted (restored by undo and redo); the next action's 0-based index.
    public private(set) var actionsSpent: Int
    /// The route report (the truth metric), recomputed after every action.
    public private(set) var report: StarlitCartoucheRouteReport
    /// Why the play failed, or nil.
    public private(set) var failure: StarlitCartoucheFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [StarlitCartoucheRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the ship at the start star at beat 0, nothing drawn, no action spent, no
    /// failure.
    public init(level: StarlitCartoucheLevel) {
        self.level = level
        stage = .loading
        star = level.start
        beat = 0
        drawn = []
        legs = []
        actionsSpent = 0
        report = level.startReport
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
    /// `{"actions":<spent>,"beat":<beat>,"drawn":[<c>,…],"failure":"<f>","legs":[[<from>,<to>,<corridor>,<wait>,
    /// <depart>,<arrive>],…],"level":"<level fingerprint>","schema":1,"stage":"<stage>","star":<star>}`, where the
    /// drawn strokes are sorted, the legs are in flight order and the failure is `"none"`,
    /// `"departure <star> <beat> <close>"`, `"hazard <corridor> <hazard> <from> <to>"`,
    /// `"arrival <star> <beat> <open> <close>"`, `"deadline <beat> <deadline>"`, `"stroke <corridor>"` or
    /// `"budget <spent>"`.
    public var fingerprint: String {
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"beat\":" + String(beat) + ",\"drawn\":["
            + Self.list(drawn.sorted()) + "],\"failure\":\"" + Self.text(failure) + "\",\"legs\":["
            + Self.text(legs) + "],\"level\":\"" + level.fingerprint + "\",\"schema\":" + String(Self.schema)
            + ",\"stage\":\"" + stage.rawValue + "\",\"star\":" + String(star) + "}"
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

    /// "[<from>,<to>,<corridor>,<wait>,<depart>,<arrive>],…".
    static func text(_ legs: [StarlitCartoucheLeg]) -> String {
        var text: String = ""
        for (position, leg) in legs.enumerated() {
            if position > 0 { text += "," }
            text += "[" + list([leg.from, leg.to, leg.corridor, leg.wait, leg.depart, leg.arrive]) + "]"
        }
        return text
    }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: StarlitCartoucheFailure?) -> String {
        switch failure {
        case .departure(let star, let beat, let close):
            "departure " + String(star) + " " + String(beat) + " " + String(close)
        case .hazard(let corridor, let hazard, let from, let to):
            "hazard " + String(corridor) + " " + String(hazard) + " " + String(from) + " " + String(to)
        case .arrival(let star, let beat, let open, let close):
            "arrival " + String(star) + " " + String(beat) + " " + String(open) + " " + String(close)
        case .deadline(let beat, let deadline):
            "deadline " + String(beat) + " " + String(deadline)
        case .stroke(let corridor):
            "stroke " + String(corridor)
        case .budget(let spent):
            "budget " + String(spent)
        case nil:
            "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: StarlitCartoucheEvent) throws(StarlitCartoucheError) {
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
    static func kind(of action: StarlitCartoucheAction) -> StarlitCartoucheRecordKind {
        switch action {
        case .leg: .leg
        }
    }

    /// The leg `action` would fly from the ship's star and beat.
    ///
    /// - Throws: `.action(name)` per ``StarlitCartoucheChart/leg(_:from:at:to:wait:)``: an unknown star, the same
    ///   star, no corridor, a wait outside 0 … 8, or stars out of range at the departure beat.
    func leg(for action: StarlitCartoucheAction) throws(StarlitCartoucheError) -> StarlitCartoucheLeg {
        switch action {
        case .leg(let destination, let wait):
            try StarlitCartoucheChart.leg(level, from: star, at: beat, to: destination, wait: wait)
        }
    }

    /// Applies a leg that names the current fingerprint as its previous one; it spends 1 action. When the chart's check
    /// fails the leg, the play fails on that leg and the ship, beat, strokes and legs stay as they were. Otherwise the
    /// ship moves to the leg's star at its arrival beat and the corridor is drawn; the play is won when the drawn set
    /// equals the symbol with the ship at the beacon (even on the last action of the budget), else a leg that spends
    /// the last of the budget fails `budget(actionsSpent)`. The report is recomputed and the action recorded.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``leg(for:)``. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: StarlitCartoucheAction,
                               expecting previous: String) throws(StarlitCartoucheError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        let flown: StarlitCartoucheLeg = try leg(for: action)
        let snapshot: Snapshot = moment
        let actionIndex: Int = actionsSpent
        actionsSpent += 1
        if let refused = StarlitCartoucheChart.check(level, leg: flown) {
            stage = .failed
            failure = refused
        } else {
            star = flown.to
            beat = flown.arrive
            drawn.insert(flown.corridor)
            legs.append(flown)
        }
        report = StarlitCartoucheChart.report(level, star: star, beat: beat, drawn: drawn, legs: legs)
        if stage == .playing {
            if report.matched {
                stage = .won
            } else if actionsSpent >= level.budget {
                stage = .failed
                failure = .budget(actionsSpent)
            }
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, index: actionIndex, previous: before)
    }

    /// Restores the moment before the latest action (star, beat, strokes, legs, actions spent, report, failure) and
    /// records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(StarlitCartoucheError) {
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
    public mutating func redo() throws(StarlitCartoucheError) {
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
    /// then each record by kind (a leg with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused or resumed, the replay pauses or resumes first. Every produced record must equal the given
    /// one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")` or `.malformed("seed <i>")` when record `i` has another schema or level
    ///   seed; `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action, names an action of another kind or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: StarlitCartoucheLevel,
                              records: [StarlitCartoucheRecord]) throws(StarlitCartoucheError) -> StarlitCartouchePlay {
        var play = StarlitCartouchePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: StarlitCartoucheRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: StarlitCartouchePlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .leg:
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
        Snapshot(stage: stage, star: star, beat: beat, drawn: drawn, legs: legs, actionsSpent: actionsSpent,
                 report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        star = snapshot.star
        beat = snapshot.beat
        drawn = snapshot.drawn
        legs = snapshot.legs
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
    private mutating func append(kind: StarlitCartoucheRecordKind, action: StarlitCartoucheAction?, index: Int,
                                 previous: String) {
        let record = StarlitCartoucheRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                            action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
