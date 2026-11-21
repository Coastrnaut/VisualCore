// HueCompassPlay — feature 331 (R02-G04-01) T-R02G0401-004 (FR-R02G0401-003 … 007; clarifications Q2, Q3, Q4, Q5). One
// play of a Hue Compass level: the life stage, the compass bearing, the units spent, the clues seen, the append-only
// records and the turn-only undo and redo stacks. An action is validated in this order — stage, previous fingerprint,
// range, allowance — and refused without any change, or applied and recorded. A turn moves the bearing by −48 … 48
// non-zero steps (mod 96) and spends nothing. A probe spends one unit and adds the clue at the current bearing; when it
// spends the last unit the play fails (`probes`). A selection spends one unit and wins when the level accepts the
// bearing and band, otherwise fails (`selection`). Undo and redo hold turns only; a probe or selection clears both (a
// clue once seen cannot be unseen). A record trace replays to the same records, fingerprints and outcome.
import VisualCoreMath

/// The life stage of a play.
public enum HueCompassStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Turns, probes, selections, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it.
    case paused
    /// The selection was accepted; `showResult` shows the result.
    case won
    /// The selection missed or a probe spent the last unit; `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum HueCompassEvent: Sendable, Equatable {
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
public enum HueCompassRecordKind: String, Sendable, Codable {
    /// A turn of the compass.
    case turn
    /// A probe at the current bearing.
    case probe
    /// A selection of a bearing and band.
    case select
    /// An undo of the latest turn.
    case undo
    /// A redo of the latest undone turn.
    case redo
}

/// Why a play failed.
public enum HueCompassFailure: String, Sendable, Codable, CaseIterable {
    /// The selection was outside a tolerance.
    case selection
    /// A probe spent the last unit of the allowance.
    case probes
}

/// The bearing and band a play selected.
public struct HueCompassSelection: Sendable, Hashable, Codable {
    /// The selected bearing, 0 … 95.
    public let bearing: Int
    /// The selected hue band, 0 … 23.
    public let band: Int

    /// A selection of the given values (not checked).
    public init(bearing: Int, band: Int) {
        self.bearing = bearing
        self.band = band
    }
}

/// The append-only record of one accepted action.
public struct HueCompassRecord: Sendable, Equatable, Codable {
    /// The record schema (``HueCompassPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's index in the play's records.
    public let tick: Int
    /// The kind of action.
    public let kind: HueCompassRecordKind
    /// The action applied: the turn, probe or selection; for an undo the reverse turn, for a redo the turn re-applied.
    public let action: HueCompassAction
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: HueCompassRecordKind, action: HueCompassAction,
                previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Hue Compass level.
public struct HueCompassPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }
    /// The turns a single action may make.
    public static let turns: ClosedRange<Int> = -48...48

    /// The level played.
    public let level: HueCompassLevel
    /// The life stage.
    public private(set) var stage: HueCompassStage
    /// The bearing the compass points at, 0 … 95.
    public private(set) var bearing: Int
    /// The units spent by probes and the selection.
    public private(set) var spent: Int
    /// The clues seen, in order.
    public private(set) var clues: [HueCompassClue]
    /// The append-only records of every accepted action.
    public private(set) var records: [HueCompassRecord]
    /// Why the play failed, or nil.
    public private(set) var failure: HueCompassFailure?
    /// The bearing and band selected, or nil before the selection.
    public private(set) var selection: HueCompassSelection?
    /// Turns that undo can revert, latest last.
    private(set) var undoStack: [Int]
    /// Turns that redo can re-apply, latest last.
    private(set) var redoStack: [Int]

    /// A play of `level` in stage `loading` at the level's start bearing with nothing spent.
    public init(level: HueCompassLevel) {
        self.level = level
        stage = .loading
        bearing = level.start
        spent = 0
        clues = []
        records = []
        failure = nil
        selection = nil
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (one byte); the level fingerprint (UTF-8);
    /// the bearing and the units spent (one byte each); each clue's bearing and hue gap (one byte each) and depth (two
    /// bytes, big-endian); the stage's raw value (UTF-8); the failure's raw value (UTF-8, nothing when there is none);
    /// after a selection, a zero byte and the selected bearing and band (one byte each), so a record's next fingerprint
    /// pins the selection itself, not only its verdict.
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        bytes.append(UInt8(truncatingIfNeeded: bearing))
        bytes.append(UInt8(truncatingIfNeeded: spent))
        for clue in clues {
            bytes.append(UInt8(truncatingIfNeeded: clue.bearing))
            bytes.append(UInt8(truncatingIfNeeded: clue.hueGap))
            bytes.append(UInt8(truncatingIfNeeded: clue.depth >> 8))
            bytes.append(UInt8(truncatingIfNeeded: clue.depth))
        }
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        if let failure { bytes.append(contentsOf: Array(failure.rawValue.utf8)) }
        if let selection {
            bytes.append(0)
            bytes.append(UInt8(truncatingIfNeeded: selection.bearing))
            bytes.append(UInt8(truncatingIfNeeded: selection.band))
        }
        return StableHash.sha256Hex(bytes)
    }

    /// The units left.
    public var remaining: Int { level.allowance - spent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { stage == .playing && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { stage == .playing && !redoStack.isEmpty }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: HueCompassEvent) throws(HueCompassError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `action`'s operands are in range: a turn of −48 … 48 other than 0; a selection of bearing 0 … 95 and
    /// band 0 … 23; a probe always.
    public static func inRange(_ action: HueCompassAction) -> Bool {
        switch action {
        case .turn(let steps): steps != 0 && turns.contains(steps)
        case .probe: true
        case .select(let bearing, let band):
            (0..<HueCompassWheel.bearings).contains(bearing) && (0..<HueCompassWheel.bands).contains(band)
        }
    }

    /// Applies an action that names the current fingerprint as its previous one and records it, with its verdict.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action("range")` for an
    ///   operand out of range; `.allowance` for a probe or selection when nothing is left. A refused action leaves the
    ///   play unchanged.
    public mutating func apply(_ action: HueCompassAction, expecting previous: String) throws(HueCompassError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        guard Self.inRange(action) else { throw .action("range") }
        switch action {
        case .turn(let steps):
            bearing = HueCompassWheel.mod(bearing + steps, HueCompassWheel.bearings)
            undoStack.append(steps)
            redoStack.removeAll()
            append(kind: .turn, action: action, previous: before)
        case .probe:
            guard spent < level.allowance else { throw .allowance }
            spent += 1
            clues.append(level.clue(at: bearing))
            undoStack.removeAll()
            redoStack.removeAll()
            if spent == level.allowance {
                stage = .failed
                failure = .probes
            }
            append(kind: .probe, action: action, previous: before)
        case .select(let selected, let band):
            guard spent < level.allowance else { throw .allowance }
            spent += 1
            undoStack.removeAll()
            redoStack.removeAll()
            selection = HueCompassSelection(bearing: selected, band: band)
            if level.accepts(bearing: selected, band: band) {
                stage = .won
            } else {
                stage = .failed
                failure = .selection
            }
            append(kind: .select, action: action, previous: before)
        }
    }

    /// Reverts the latest turn and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`; `.action("nothing-to-undo")` when no turn can be undone. A refused undo
    ///   leaves the play unchanged.
    public mutating func undo() throws(HueCompassError) {
        guard stage == .playing else { throw .stage }
        guard let steps = undoStack.last else { throw .action("nothing-to-undo") }
        let before: String = fingerprint
        undoStack.removeLast()
        bearing = HueCompassWheel.mod(bearing - steps, HueCompassWheel.bearings)
        redoStack.append(steps)
        append(kind: .undo, action: .turn(-steps), previous: before)
    }

    /// Re-applies the latest undone turn and records the redo.
    ///
    /// - Throws: `.stage` outside `playing`; `.action("nothing-to-redo")` when no turn was undone. A refused redo leaves
    ///   the play unchanged.
    public mutating func redo() throws(HueCompassError) {
        guard stage == .playing else { throw .stage }
        guard let steps = redoStack.last else { throw .action("nothing-to-redo") }
        let before: String = fingerprint
        redoStack.removeLast()
        bearing = HueCompassWheel.mod(bearing + steps, HueCompassWheel.bearings)
        undoStack.append(steps)
        append(kind: .redo, action: .turn(steps), previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Every produced
    /// record must equal the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: HueCompassLevel,
                              records: [HueCompassRecord]) throws(HueCompassError) -> HueCompassPlay {
        var play = HueCompassPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: HueCompassRecord = records[index]
            switch record.kind {
            case .turn, .probe, .select: try play.apply(record.action, expecting: record.previous)
            case .undo: try play.undo()
            case .redo: try play.redo()
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: HueCompassRecordKind, action: HueCompassAction, previous: String) {
        let record = HueCompassRecord(schema: Self.schema, seed: level.seed, tick: records.count, kind: kind,
                                      action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
