// LissajousLabyrinthPlay — feature 311 (R02-G02-01) T-R02G0201-004 (FR-R02G0201-003, 004, 005, 006; clarifications Q3,
// Q4). One play of a Lissajous Labyrinth level: the life stage, the four dials, the actions spent, the append-only records
// and the undo and redo stacks. An action sets one dial; it is validated (stage, previous fingerprint, range, change,
// coprime frequencies, allowance) and refused without any change, or applied, recorded and followed by the lap verdict:
// a won lap wins, and spending the last action without a win fails with the verdict as its explanation. Undo restores the
// previous dial value and refunds the action; redo re-applies it; a new action clears the redo stack. A record trace
// replays to the same records, fingerprints and outcome.
import VisualCoreMath

/// One action: set `dial` to `value`. Not checked here; ``LissajousLabyrinthPlay`` checks it.
public struct LissajousLabyrinthAction: Sendable, Equatable, Hashable, Codable {
    /// The dial that is set.
    public var dial: LissajousLabyrinthDial
    /// The new value, inside ``LissajousLabyrinthDial/range`` when valid.
    public var value: Int

    /// An action of the given values (not checked).
    public init(dial: LissajousLabyrinthDial, value: Int) {
        self.dial = dial
        self.value = value
    }
}

/// The life stage of a play.
public enum LissajousLabyrinthStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it.
    case paused
    /// The lap wins; `showResult` shows the result.
    case won
    /// The allowance is spent without a win; `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum LissajousLabyrinthEvent: Sendable, Equatable {
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
public enum LissajousLabyrinthRecordKind: String, Sendable, Codable {
    /// An action that set a dial.
    case action
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action, undo or redo.
public struct LissajousLabyrinthRecord: Sendable, Equatable, Codable {
    /// The record schema (``LissajousLabyrinthPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's index in the play's records.
    public let tick: Int
    /// The kind of action.
    public let kind: LissajousLabyrinthRecordKind
    /// The dial that changed.
    public let dial: LissajousLabyrinthDial
    /// The dial's value after the action.
    public let value: Int
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: LissajousLabyrinthRecordKind, dial: LissajousLabyrinthDial,
                value: Int, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.dial = dial
        self.value = value
        self.previous = previous
        self.next = next
    }
}

/// One play of a Lissajous Labyrinth level.
public struct LissajousLabyrinthPlay: Sendable, Equatable {
    /// One entry of the undo or redo stack: a dial changed from `from` to `to`.
    struct Change: Sendable, Equatable {
        let dial: LissajousLabyrinthDial
        let from: Int
        let to: Int
    }

    /// The play and record schema.
    public static var schema: Int { 1 }

    /// The level played.
    public let level: LissajousLabyrinthLevel
    /// The life stage.
    public private(set) var stage: LissajousLabyrinthStage
    /// The four dial values.
    public private(set) var dials: LissajousLabyrinthDials
    /// The actions spent (undo refunds one, redo spends one).
    public private(set) var spent: Int
    /// The append-only records of every accepted action, undo and redo.
    public private(set) var records: [LissajousLabyrinthRecord]
    /// The lap verdict (the first contact or the first missed checkpoint) when the play failed, otherwise nil.
    public private(set) var failure: LissajousLabyrinthVerdict?
    /// Changes that undo can revert, latest last.
    private(set) var undoStack: [Change]
    /// Changes that redo can re-apply, latest last.
    private(set) var redoStack: [Change]

    /// A play of `level` in stage `loading` at the level's start dials with nothing spent.
    public init(level: LissajousLabyrinthLevel) {
        self.level = level
        stage = .loading
        dials = level.start
        spent = 0
        records = []
        failure = nil
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (``schema``, one byte); the level fingerprint
    /// (UTF-8); the dials `frequencyA`, `frequencyB`, `phaseA`, `phaseC` (one byte each); the actions spent (one byte);
    /// the stage's raw value (UTF-8).
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        for dial in LissajousLabyrinthDial.allCases { bytes.append(UInt8(truncatingIfNeeded: dials[dial])) }
        bytes.append(UInt8(truncatingIfNeeded: spent))
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        return StableHash.sha256Hex(bytes)
    }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { stage == .playing && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { stage == .playing && !redoStack.isEmpty && spent < level.allowance }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: LissajousLabyrinthEvent) throws(LissajousLabyrinthError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Applies an action that names the current fingerprint as its previous one, records it, then evaluates the lap: a
    /// win ends the play `won`; otherwise, when the allowance is spent, the play fails with the verdict as ``failure``.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.move("range")` for a value
    ///   outside the dial's range; `.move("no-change")` for the current value; `.move("not-coprime")` when the new
    ///   frequencies are not coprime; `.allowance` when the allowance is spent. A refused action leaves the play
    ///   unchanged.
    public mutating func apply(_ action: LissajousLabyrinthAction,
                               expecting previous: String) throws(LissajousLabyrinthError) {
        guard stage == .playing else { throw .stage }
        let before = fingerprint
        guard previous == before else { throw .stale }
        guard action.dial.range.contains(action.value) else { throw .move("range") }
        let current = dials[action.dial]
        guard action.value != current else { throw .move("no-change") }
        var changed = dials
        changed[action.dial] = action.value
        guard changed.isValid else { throw .move("not-coprime") }
        guard spent < level.allowance else { throw .allowance }
        dials = changed
        spent += 1
        undoStack.append(Change(dial: action.dial, from: current, to: action.value))
        redoStack.removeAll()
        settle(failing: true)
        append(kind: .action, dial: action.dial, value: action.value, previous: before)
    }

    /// Reverts the latest action, refunds it and records the undo; then evaluates the lap (an undo may win but never fails
    /// the play).
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-undo")` when there is no action to undo. A refused undo
    ///   leaves the play unchanged.
    public mutating func undo() throws(LissajousLabyrinthError) {
        guard stage == .playing else { throw .stage }
        guard let change = undoStack.last else { throw .move("nothing-to-undo") }
        let before = fingerprint
        undoStack.removeLast()
        dials[change.dial] = change.from
        spent -= 1
        redoStack.append(change)
        settle(failing: false)
        append(kind: .undo, dial: change.dial, value: change.from, previous: before)
    }

    /// Re-applies the latest undone action, spends it and records the redo; then evaluates the lap as an action.
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-redo")` when there is no undone action; `.allowance` when
    ///   the allowance is spent. A refused redo leaves the play unchanged.
    public mutating func redo() throws(LissajousLabyrinthError) {
        guard stage == .playing else { throw .stage }
        guard let change = redoStack.last else { throw .move("nothing-to-redo") }
        guard spent < level.allowance else { throw .allowance }
        let before = fingerprint
        redoStack.removeLast()
        dials[change.dial] = change.to
        spent += 1
        undoStack.append(change)
        settle(failing: true)
        append(kind: .redo, dial: change.dial, value: change.to, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Every produced
    /// record must equal the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: LissajousLabyrinthLevel,
                              records: [LissajousLabyrinthRecord]) throws(LissajousLabyrinthError)
        -> LissajousLabyrinthPlay {
        var play = LissajousLabyrinthPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record = records[index]
            switch record.kind {
            case .action:
                try play.apply(LissajousLabyrinthAction(dial: record.dial, value: record.value),
                               expecting: record.previous)
            case .undo: try play.undo()
            case .redo: try play.redo()
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// After an accepted action: `won` when the lap wins; otherwise, when `failing` and the allowance is spent, `failed`
    /// with the verdict.
    private mutating func settle(failing: Bool) {
        let verdict = LissajousLabyrinthLap.verdict(dials, level: level)
        if verdict == .won {
            stage = .won
        } else if failing && spent == level.allowance {
            stage = .failed
            failure = verdict
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: LissajousLabyrinthRecordKind, dial: LissajousLabyrinthDial, value: Int,
                                 previous: String) {
        let record = LissajousLabyrinthRecord(schema: Self.schema, seed: level.seed, tick: records.count, kind: kind,
                                              dial: dial, value: value, previous: previous, next: fingerprint)
        records.append(record)
    }
}
