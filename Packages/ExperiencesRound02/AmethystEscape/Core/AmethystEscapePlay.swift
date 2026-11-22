// AmethystEscapePlay — feature 361 (R02-G07-01) T-R02G0701-004 (FR-R02G0701-004 … 008; clarifications Q3 … Q5). One
// play of an Amethyst Escape level: the life stage, the crystal (shell offsets and the pearl's pocket), the moves spent,
// the failure, the append-only records and the undo and redo stacks. An action is validated in this order — stage,
// previous fingerprint, range, stuck — and refused without any change, or applied and recorded. Every accepted rotate and
// advance spends one move; a refused action spends nothing. After an advance the exit is judged first (won), then a
// blocked wedge (failed, naming the shell and the sector, with the pearl placed there); then, after any accepted move that
// did not end the level, the budget (moves spent equal to the budget: failed). There is no budget refusal: the move that
// reaches the budget is applied and then judged, so an exit on the last move wins. Every accepted action can be undone and
// redone exactly (snapshots); undo gives the move back, redo spends it again, and a new action clears the redo stack. Undo
// works in playing, paused and failed (a failed play returns to playing, an honest retry that is recorded); a won play is
// final. A record trace replays to the same records, fingerprints and outcome. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum AmethystEscapeFailure: Sendable, Hashable, Codable {
    /// The pearl fell into a blocked wedge: the shell (first) and the absolute sector (second) of that pocket.
    case wedge(Int, Int)
    /// The moves spent reached the budget without a win.
    case budget

    /// The stable failure code: `wedge` or `budget`.
    public var code: String {
        switch self {
        case .wedge: "wedge"
        case .budget: "budget"
        }
    }
}

/// The life stage of a play.
public enum AmethystEscapeStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Rotations, advances, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The pearl left through the exit gap; `showResult` shows the result. Final: undo is refused.
    case won
    /// The play failed; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum AmethystEscapeEvent: Sendable, Equatable {
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
public enum AmethystEscapeRecordKind: String, Sendable, Codable {
    /// A shell turned by one sector.
    case rotate
    /// The pearl advanced by one transition.
    case advance
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct AmethystEscapeRecord: Sendable, Equatable, Codable {
    /// The record schema (``AmethystEscapePlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The moves spent before the action (the move index).
    public let move: Int
    /// The kind of action.
    public let kind: AmethystEscapeRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: AmethystEscapeAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, move: Int, kind: AmethystEscapeRecordKind, action: AmethystEscapeAction?,
                previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.move = move
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of an Amethyst Escape level.
public struct AmethystEscapePlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        let stage: AmethystEscapeStage
        let crystal: AmethystEscapeCrystal
        let moves: Int
        let failure: AmethystEscapeFailure?
    }

    /// The level played.
    public let level: AmethystEscapeLevel
    /// The life stage.
    public private(set) var stage: AmethystEscapeStage
    /// The shell offsets and the pearl's pocket.
    public private(set) var crystal: AmethystEscapeCrystal
    /// The moves (accepted rotations and advances) spent.
    public private(set) var moves: Int
    /// Why the play failed, or nil.
    public private(set) var failure: AmethystEscapeFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [AmethystEscapeRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading` with the level's opening crystal and no move spent.
    public init(level: AmethystEscapeLevel) {
        self.level = level
        stage = .loading
        crystal = AmethystEscapeCrystal(level: level)
        moves = 0
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (one byte); the level fingerprint (UTF-8); the
    /// shell count (one byte) and every shell's offset (one byte each, innermost first); the pearl's shell and absolute
    /// sector (one byte each); the moves spent (two bytes, big-endian); the stage's raw value (UTF-8); a zero byte and the
    /// failure (its code, then the shell and the sector, one byte each, for a wedge) when there is one.
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        bytes.append(UInt8(truncatingIfNeeded: crystal.offsets.count))
        for offset in crystal.offsets { bytes.append(UInt8(truncatingIfNeeded: offset)) }
        bytes.append(UInt8(truncatingIfNeeded: crystal.pearl.shell))
        bytes.append(UInt8(truncatingIfNeeded: crystal.pearl.sector))
        bytes.append(UInt8(truncatingIfNeeded: moves >> 8))
        bytes.append(UInt8(truncatingIfNeeded: moves))
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        if let failure {
            bytes.append(0)
            bytes.append(contentsOf: Array(failure.code.utf8))
            if case .wedge(let shell, let sector) = failure {
                bytes.append(contentsOf: [UInt8(truncatingIfNeeded: shell), UInt8(truncatingIfNeeded: sector)])
            }
        }
        return StableHash.sha256Hex(bytes)
    }

    /// The moves left: the budget less the moves spent.
    public var remaining: Int { level.budget - moves }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: AmethystEscapeEvent) throws(AmethystEscapeError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `action`'s operands are in range for `level`: a rotation names a shell 0 … K − 1 and a step of +1 or −1;
    /// an advance has no operands.
    public static func inRange(_ action: AmethystEscapeAction, level: AmethystEscapeLevel) -> Bool {
        switch action {
        case .rotate(let shell, let step):
            return level.shells.indices.contains(shell) && (step == 1 || step == -1)
        case .advance:
            return true
        }
    }

    /// Applies an action that names the current fingerprint as its previous one, spends one move, judges the outcome
    /// (exit, then wedge after an advance; then the budget) and records it.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action("range")` for a
    ///   shell out of range or a step other than ±1; `.stuck` for an advance with no aperture lined up and a radial wall
    ///   ahead. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: AmethystEscapeAction, expecting previous: String) throws(AmethystEscapeError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        guard Self.inRange(action, level: level) else { throw .action("range") }
        let snapshot: Snapshot = moment
        let movesBefore: Int = moves
        switch action {
        case .rotate(let shell, let step):
            crystal = crystal.rotating(shell: shell, step: step, level: level)
        case .advance:
            switch crystal.transition(level: level) {
            case .stuck:
                throw .stuck
            case .moved(let pocket):
                crystal = crystal.placing(pearl: pocket)
            case .exited:
                stage = .won
            case .wedge(let pocket):
                crystal = crystal.placing(pearl: pocket)
                stage = .failed
                failure = .wedge(pocket.shell, pocket.sector)
            }
        }
        moves += 1
        if stage == .playing && moves >= level.budget {
            stage = .failed
            failure = .budget
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, move: movesBefore, previous: before)
    }

    /// Restores the moment before the latest action (giving its move back) and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final);
    ///   `.action("nothing-to-undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(AmethystEscapeError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("nothing-to-undo") }
        let before: String = fingerprint
        let movesBefore: Int = moves
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, move: movesBefore, previous: before)
    }

    /// Restores the moment of the latest undone action (spending its move again) and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("nothing-to-redo")` when nothing was undone. A refused
    ///   redo leaves the play unchanged.
    public mutating func redo() throws(AmethystEscapeError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("nothing-to-redo") }
        let before: String = fingerprint
        let movesBefore: Int = moves
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, move: movesBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one with
    /// the play paused (an undo or redo made while paused) or resumed (an action after a paused undo), the replay pauses
    /// or resumes first. Every produced record must equal the given one, so the trace reproduces every fingerprint and the
    /// outcome.
    ///
    /// - Throws: `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action or is not reproduced; any refusal of the replayed
    ///   action.
    public static func replay(level: AmethystEscapeLevel,
                              records: [AmethystEscapeRecord]) throws(AmethystEscapeError) -> AmethystEscapePlay {
        var play = AmethystEscapePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: AmethystEscapeRecord = records[index]
            if play.fingerprint != record.previous {
                var other: AmethystEscapePlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .rotate, .advance:
                guard let action = record.action else { throw .malformed("record \(index)") }
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
    private var moment: Snapshot { Snapshot(stage: stage, crystal: crystal, moves: moves, failure: failure) }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        crystal = snapshot.crystal
        moves = snapshot.moves
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// The record kind of an action.
    private static func kind(of action: AmethystEscapeAction) -> AmethystEscapeRecordKind {
        switch action {
        case .rotate: .rotate
        case .advance: .advance
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: AmethystEscapeRecordKind, action: AmethystEscapeAction?, move: Int,
                                 previous: String) {
        let record = AmethystEscapeRecord(schema: Self.schema, seed: level.seed, move: move, kind: kind, action: action,
                                          previous: previous, next: fingerprint)
        records.append(record)
    }
}
