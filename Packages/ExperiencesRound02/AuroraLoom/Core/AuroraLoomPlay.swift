// AuroraLoomPlay — feature 301 (R02-G01-01) T-R02G0101-004 (FR-R02G0101-004, 005, 006; clarifications Q2, Q3, Q4). One
// play of an Aurora Loom level: the life stage, the six control steps, the moves spent, the append-only records and the
// undo and redo stacks. A move sets one control of one ribbon; it is validated (stage, previous fingerprint, range, change,
// allowance) and refused without any change, or applied, recorded and followed by the win and failure check. Undo restores
// the previous step and refunds the move; redo re-applies it; a new move clears the redo stack. A record trace replays to
// the same records, fingerprints and outcome.
import VisualCoreMath

/// The control of a ribbon that a move sets.
public enum AuroraLoomControl: String, Sendable, Codable, CaseIterable {
    /// The wave step (how far the phase turns along the ribbon).
    case wave
    /// The phase step (the ribbon's phase offset).
    case phase
}

/// One move: set `control` of `ribbon` to `step`. Not checked here; ``AuroraLoomPlay`` and the rules check it.
public struct AuroraLoomMove: Sendable, Equatable, Hashable, Codable {
    /// The ribbon, 0 … 2 when valid.
    public var ribbon: Int
    /// The control that is set.
    public var control: AuroraLoomControl
    /// The new step, 0 … 15 when valid.
    public var step: Int

    /// A move of the given values (not checked).
    public init(ribbon: Int, control: AuroraLoomControl, step: Int) {
        self.ribbon = ribbon
        self.control = control
        self.step = step
    }
}

/// The life stage of a play.
public enum AuroraLoomStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Moves, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it.
    case paused
    /// The setting wins; `showResult` shows the result.
    case won
    /// The allowance is spent without a win; `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum AuroraLoomEvent: Sendable, Equatable {
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
public enum AuroraLoomRecordKind: String, Sendable, Codable {
    /// A move.
    case move
    /// An undo of the latest move.
    case undo
    /// A redo of the latest undone move.
    case redo
}

/// The append-only record of one accepted move, undo or redo.
public struct AuroraLoomRecord: Sendable, Equatable, Codable {
    /// The record schema (``AuroraLoomLevel/schema``).
    public let schema: Int
    /// The level's design seed.
    public let seed: UInt64
    /// The record's index in the play's records.
    public let tick: Int
    /// The kind of action.
    public let kind: AuroraLoomRecordKind
    /// The ribbon whose control changed.
    public let ribbon: Int
    /// The control that changed.
    public let control: AuroraLoomControl
    /// The control's step after the action.
    public let step: Int
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: AuroraLoomRecordKind, ribbon: Int,
                control: AuroraLoomControl, step: Int, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.ribbon = ribbon
        self.control = control
        self.step = step
        self.previous = previous
        self.next = next
    }
}

/// One play of an Aurora Loom level.
public struct AuroraLoomPlay: Sendable, Equatable {
    /// One entry of the undo or redo stack: a control changed from `from` to `to`.
    struct Change: Sendable, Equatable {
        let ribbon: Int
        let control: AuroraLoomControl
        let from: Int
        let to: Int
    }

    /// The level played.
    public let level: AuroraLoomLevel
    /// The life stage.
    public private(set) var stage: AuroraLoomStage
    /// The six control steps.
    public private(set) var steps: AuroraLoomSteps
    /// The moves spent (undo refunds one, redo spends one).
    public private(set) var spent: Int
    /// The append-only records of every accepted move, undo and redo.
    public private(set) var records: [AuroraLoomRecord]
    /// The largest mismatch when the play failed, otherwise nil.
    public private(set) var failure: AuroraLoomMismatch?
    /// Changes that undo can revert, latest last.
    private(set) var undoStack: [Change]
    /// Changes that redo can re-apply, latest last.
    private(set) var redoStack: [Change]

    /// A play of `level` in stage `loading` at the level's start steps with nothing spent.
    public init(level: AuroraLoomLevel) {
        self.level = level
        stage = .loading
        steps = level.startSteps
        spent = 0
        records = []
        failure = nil
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (``AuroraLoomLevel/schema``, one byte); the
    /// level fingerprint (UTF-8); the wave steps of ribbons 0, 1, 2 then the phase steps of ribbons 0, 1, 2 (one byte
    /// each); the moves spent (one byte); the stage's raw value (UTF-8).
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: AuroraLoomLevel.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        for value in steps.wave { bytes.append(UInt8(truncatingIfNeeded: value)) }
        for value in steps.phase { bytes.append(UInt8(truncatingIfNeeded: value)) }
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
    public mutating func handle(_ event: AuroraLoomEvent) throws(AuroraLoomError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Applies a move that names the current fingerprint as its previous one, records it, then checks the win and, when
    /// the allowance is spent, the failure (``failure`` names the worst mismatch).
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.move("range")` for a
    ///   ribbon outside 0 … 2 or a step outside 0 … 15; `.move("no-change")` for the current step; `.allowance` when the
    ///   allowance is spent. A refused move leaves the play unchanged.
    public mutating func apply(_ move: AuroraLoomMove, expecting previous: String) throws(AuroraLoomError) {
        guard stage == .playing else { throw .stage }
        let before = fingerprint
        guard previous == before else { throw .stale }
        guard (0...2).contains(move.ribbon), (0...15).contains(move.step) else { throw .move("range") }
        let current = Self.step(of: steps, ribbon: move.ribbon, control: move.control)
        guard move.step != current else { throw .move("no-change") }
        guard spent < level.allowance else { throw .allowance }
        Self.set(&steps, ribbon: move.ribbon, control: move.control, step: move.step)
        spent += 1
        undoStack.append(Change(ribbon: move.ribbon, control: move.control, from: current, to: move.step))
        redoStack.removeAll()
        settle(failing: true)
        append(kind: .move, ribbon: move.ribbon, control: move.control, step: move.step, previous: before)
    }

    /// Reverts the latest move, refunds it and records the undo; then checks the win (an undo never fails the play).
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-undo")` when there is no move to undo. A refused undo
    ///   leaves the play unchanged.
    public mutating func undo() throws(AuroraLoomError) {
        guard stage == .playing else { throw .stage }
        guard let change = undoStack.last else { throw .move("nothing-to-undo") }
        let before = fingerprint
        undoStack.removeLast()
        Self.set(&steps, ribbon: change.ribbon, control: change.control, step: change.from)
        spent -= 1
        redoStack.append(change)
        settle(failing: false)
        append(kind: .undo, ribbon: change.ribbon, control: change.control, step: change.from, previous: before)
    }

    /// Re-applies the latest undone move, spends it and records the redo; then checks the win and the failure as a move.
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-redo")` when there is no undone move; `.allowance` when the
    ///   allowance is spent. A refused redo leaves the play unchanged.
    public mutating func redo() throws(AuroraLoomError) {
        guard stage == .playing else { throw .stage }
        guard let change = redoStack.last else { throw .move("nothing-to-redo") }
        guard spent < level.allowance else { throw .allowance }
        let before = fingerprint
        redoStack.removeLast()
        Self.set(&steps, ribbon: change.ribbon, control: change.control, step: change.to)
        spent += 1
        undoStack.append(change)
        settle(failing: true)
        append(kind: .redo, ribbon: change.ribbon, control: change.control, step: change.to, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (a move with the record's previous fingerprint, an undo or a redo). Every produced record
    /// must equal the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: AuroraLoomLevel, records: [AuroraLoomRecord]) throws(AuroraLoomError)
        -> AuroraLoomPlay {
        var play = AuroraLoomPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record = records[index]
            switch record.kind {
            case .move:
                try play.apply(AuroraLoomMove(ribbon: record.ribbon, control: record.control, step: record.step),
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

    /// After an accepted action: `won` when the steps win; otherwise, when `failing` and the allowance is spent,
    /// `failed` with the worst mismatch.
    private mutating func settle(failing: Bool) {
        if AuroraLoomHarmony.wins(steps, level: level) {
            stage = .won
        } else if failing && spent == level.allowance {
            stage = .failed
            failure = AuroraLoomHarmony.worst(steps, level: level)
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: AuroraLoomRecordKind, ribbon: Int, control: AuroraLoomControl, step: Int,
                                 previous: String) {
        let record = AuroraLoomRecord(schema: AuroraLoomLevel.schema, seed: level.seed, tick: records.count,
                                      kind: kind, ribbon: ribbon, control: control, step: step, previous: previous,
                                      next: fingerprint)
        records.append(record)
    }

    /// The step of `control` of `ribbon`.
    static func step(of steps: AuroraLoomSteps, ribbon: Int, control: AuroraLoomControl) -> Int {
        switch control {
        case .wave: steps.wave[ribbon]
        case .phase: steps.phase[ribbon]
        }
    }

    /// Sets `control` of `ribbon` to `step`.
    static func set(_ steps: inout AuroraLoomSteps, ribbon: Int, control: AuroraLoomControl, step: Int) {
        switch control {
        case .wave: steps.wave[ribbon] = step
        case .phase: steps.phase[ribbon] = step
        }
    }
}
