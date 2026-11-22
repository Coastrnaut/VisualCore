// NocturneGardenPlay — feature 381 (R02-G09-01) T-R02G0901-004 (FR-R02G0901-002, 004 … 008, 011, 013, 014;
// SC-R02G0901-001, 002, 004; clarifications Q3, Q4, Q5). One play of a Nocturne Garden level: the life stage, the
// planted blooms in canonical order (row, column, kind, size), the sun elevation, the moves spent, the failure, the
// append-only records and the undo and redo stacks. An action is validated in this order — stage, previous
// fingerprint, range, supply, no-op — and refused without any change, or applied and recorded. Every accepted action
// spends one move; a refused one spends nothing; undo and redo restore the moves of the moment they restore. After an
// action the leak is judged first (the shadow mask's cells in the forbidden regions above the level's allowance fail
// the play with `leak(move)`, the 0-based index of that move), then the win (the match reaches the required fraction
// with the leak within the allowance and at least one bloom planted), then the budget (moves spent equal to the budget:
// failed). There is no budget refusal: the move that reaches the budget is applied and then judged, so a win on the
// last move of the budget wins. Every accepted action can be undone and redone exactly (snapshots); a new action clears
// the redo stack. Undo works in playing, paused and failed (a failed play returns to playing, an honest retry that is
// recorded); a won play is final. A record trace replays to the same records, fingerprints and outcome. The shadow
// mask is recomputed from scratch after every change (FR-R02G0901-014). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum NocturneGardenFailure: Sendable, Hashable, Codable {
    /// The shadow leaked into the forbidden regions beyond the allowance on the move with this 0-based index; the
    /// action and its bloom (or the sun) are read from the record of that move.
    case leak(Int)
    /// The moves spent reached the budget without a win.
    case budget

    /// The stable failure code: `leak` or `budget`.
    public var code: String {
        switch self {
        case .leak: "leak"
        case .budget: "budget"
        }
    }
}

/// The life stage of a play.
public enum NocturneGardenStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The shadow matches the target; `showResult` shows the result. Final: undo is refused.
    case won
    /// The play failed; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum NocturneGardenEvent: Sendable, Equatable {
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
public enum NocturneGardenRecordKind: String, Sendable, Codable {
    /// A bloom planted.
    case plant
    /// A bloom moved to another cell.
    case move
    /// A bloom resized.
    case resize
    /// A bloom removed (returned to the supply).
    case remove
    /// The sun elevation set.
    case sun
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo

    /// The kind of record that `action` makes.
    public init(_ action: NocturneGardenAction) {
        switch action {
        case .plant: self = .plant
        case .move: self = .move
        case .resize: self = .resize
        case .remove: self = .remove
        case .sun: self = .sun
        }
    }
}

/// The append-only record of one accepted action.
public struct NocturneGardenRecord: Sendable, Equatable, Codable {
    /// The record schema (``NocturneGardenPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The moves spent before the action (the 0-based move index).
    public let move: Int
    /// The kind of action.
    public let kind: NocturneGardenRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: NocturneGardenAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, move: Int, kind: NocturneGardenRecordKind, action: NocturneGardenAction?,
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

/// One play of a Nocturne Garden level.
public struct NocturneGardenPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: NocturneGardenStage
        /// The blooms, in canonical order.
        let blooms: [NocturneGardenBloom]
        /// The sun elevation.
        let elevation: Int
        /// The moves spent.
        let moves: Int
        /// The failure, or nil.
        let failure: NocturneGardenFailure?
        /// The failure in words, or nil.
        let failureReason: String?
        /// The shadow mask.
        let mask: NocturneGardenMask
    }

    /// The level played.
    public let level: NocturneGardenLevel
    /// The life stage.
    public private(set) var stage: NocturneGardenStage
    /// The planted blooms, in canonical order (``NocturneGardenBloom/<(_:_:)``); bloom operands index this array.
    public private(set) var blooms: [NocturneGardenBloom]
    /// The sun elevation (1 high … 4 low).
    public private(set) var elevation: Int
    /// The moves (accepted actions) spent.
    public private(set) var moves: Int
    /// Why the play failed, or nil.
    public private(set) var failure: NocturneGardenFailure?
    /// Why the play failed, in words (FR-R02G0901-013), or nil: "the shadow leaked into 3 cells of the forbidden
    /// regions at move 4 (planting bloom 2: rose at column 5, row 1, size 2), 2 allowed" or "all 6 moves were spent
    /// without a match of 3/4".
    public private(set) var failureReason: String?
    /// The append-only records of every accepted action.
    public private(set) var records: [NocturneGardenRecord]
    /// The shadow mask: the union of the blooms' shadows under the sun, clipped to the bed, recomputed from scratch
    /// after every change.
    public private(set) var mask: NocturneGardenMask
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: no bloom planted, the level's opening sun and no move spent.
    public init(level: NocturneGardenLevel) {
        self.level = level
        stage = .loading
        blooms = []
        elevation = level.sun
        moves = 0
        failure = nil
        failureReason = nil
        records = []
        mask = NocturneGardenMask(width: level.width, height: level.height, cells: [])
        undoStack = []
        redoStack = []
    }

    /// The match: the cells dark and in the target (`shared`) and the cells dark or in the target (`either`).
    public var match: (shared: Int, either: Int) {
        (mask.intersection(level.target), mask.union(level.target))
    }

    /// The leak: the dark cells in the forbidden regions.
    public var leak: Int { mask.leak(forbidden: level.forbidden) }

    /// The boundary deviation between the mask and the target (the truth metric; it never decides the outcome).
    public var deviation: Int {
        NocturneGardenMask.boundaryDeviation(mask.cells, level.target, width: level.width, height: level.height)
    }

    /// The moves left: the budget less the moves spent.
    public var remaining: Int { level.budget - moves }

    /// How many blooms of `kind` are planted.
    public func planted(_ kind: NocturneGardenKind) -> Int {
        var count: Int = 0
        for bloom in blooms where bloom.kind == kind { count += 1 }
        return count
    }

    /// How many blooms of `kind` are still in the supply: the level's count less those planted.
    public func available(_ kind: NocturneGardenKind) -> Int { level.supplyCount(kind) - planted(kind) }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the UTF-8 text, lines joined by a line feed: `schema <n>`; `level <level
    /// fingerprint>`; one line per bloom in canonical order, `bloom <kind>,<column>,<row>,<size>`; `sun <elevation>`;
    /// `moves <n>`; `stage <raw value>`; `failure leak <move>`, `failure budget` or `failure none`.
    public var fingerprint: String {
        var text: String = "schema " + String(Self.schema) + "\nlevel " + level.fingerprint
        for bloom in blooms {
            text += "\nbloom " + bloom.kind.rawValue + "," + String(bloom.column) + "," + String(bloom.row) + ","
                + String(bloom.size)
        }
        text += "\nsun " + String(elevation) + "\nmoves " + String(moves) + "\nstage " + stage.rawValue + "\nfailure "
        switch failure {
        case .leak(let move): text += "leak " + String(move)
        case .budget: text += "budget"
        case nil: text += "none"
        }
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: NocturneGardenEvent) throws(NocturneGardenError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Checks `action`'s operands against the level and the current blooms.
    ///
    /// - Throws: `.action("bloom")` for a bloom index outside 0 … count − 1; `.action("anchor")` for an anchor cell
    ///   outside the bed; `.action("size")` for a size the level does not allow; `.action("elevation")` for a sun
    ///   elevation the level does not allow. The bloom index is checked first, then the anchor, then the size.
    public func checkRange(_ action: NocturneGardenAction) throws(NocturneGardenError) {
        switch action {
        case let .plant(_, column, row, size):
            guard inBed(column, row) else { throw .action("anchor") }
            guard level.sizes.contains(size) else { throw .action("size") }
        case let .move(bloom, column, row):
            guard blooms.indices.contains(bloom) else { throw .action("bloom") }
            guard inBed(column, row) else { throw .action("anchor") }
        case let .resize(bloom, size):
            guard blooms.indices.contains(bloom) else { throw .action("bloom") }
            guard level.sizes.contains(size) else { throw .action("size") }
        case let .remove(bloom):
            guard blooms.indices.contains(bloom) else { throw .action("bloom") }
        case let .sun(elevation):
            guard level.elevations.contains(elevation) else { throw .action("elevation") }
        }
    }

    /// Whether (column, row) is a cell of the bed.
    private func inBed(_ column: Int, _ row: Int) -> Bool {
        column >= 0 && column < level.width && row >= 0 && row < level.height
    }

    /// Applies an action that names the current fingerprint as its previous one: changes only what it names (the
    /// blooms kept in canonical order), spends one move, recomputes the mask, judges the outcome (leak, then win, then
    /// budget) and records it.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` for an
    ///   operand out of range (``checkRange(_:)``); `.supply` for a plant of a kind whose supply is used up; `.noop` for
    ///   a move to the bloom's own cell, a resize to its own size or the sun's own elevation. A refused action spends
    ///   nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: NocturneGardenAction,
                               expecting previous: String) throws(NocturneGardenError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try checkRange(action)
        var next: [NocturneGardenBloom] = blooms
        var nextElevation: Int = elevation
        var named: NocturneGardenBloom?
        switch action {
        case let .plant(kind, column, row, size):
            guard available(kind) > 0 else { throw .supply }
            let bloom = NocturneGardenBloom(kind: kind, column: column, row: row, size: size)
            next.append(bloom)
            named = bloom
        case let .move(index, column, row):
            let old: NocturneGardenBloom = blooms[index]
            guard old.column != column || old.row != row else { throw .noop }
            let bloom = NocturneGardenBloom(kind: old.kind, column: column, row: row, size: old.size)
            next[index] = bloom
            named = bloom
        case let .resize(index, size):
            let old: NocturneGardenBloom = blooms[index]
            guard old.size != size else { throw .noop }
            let bloom = NocturneGardenBloom(kind: old.kind, column: old.column, row: old.row, size: size)
            next[index] = bloom
            named = bloom
        case let .remove(index):
            next.remove(at: index)
        case let .sun(value):
            guard value != elevation else { throw .noop }
            nextElevation = value
        }
        next.sort()
        let snapshot: Snapshot = moment
        let moveIndex: Int = moves
        let words: String = describe(action, named: named, after: next, elevation: nextElevation)
        blooms = next
        elevation = nextElevation
        moves += 1
        mask = NocturneGardenMask.union(blooms, elevation: elevation, width: level.width, height: level.height)
        let leaked: Int = leak
        if leaked > level.leakAllowance {
            stage = .failed
            failure = .leak(moveIndex)
            failureReason = "the shadow leaked into \(NocturneGardenLevel.cellsText(leaked)) of the forbidden regions "
                + "at move \(moveIndex + 1) (\(words)), \(level.leakAllowance) allowed"
        } else if !blooms.isEmpty && NocturneGardenMask.matches(mask: mask, target: level.target,
                                                                 required: level.required) {
            stage = .won
        } else if moves >= level.budget {
            stage = .failed
            failure = .budget
            let spent: String = level.budget == 1 ? "the only move was" : "all \(level.budget) moves were"
            failureReason = "\(spent) spent without a match of \(level.required.text)"
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: NocturneGardenRecordKind(action), action: action, move: moveIndex, previous: before)
    }

    /// `action` in words, naming its bloom by its index in the order after the action ("planting bloom 2: rose at
    /// column 5, row 1, size 2"; a removed bloom by its index before), or the sun ("setting sun 3 of 4, …").
    private func describe(_ action: NocturneGardenAction, named: NocturneGardenBloom?, after: [NocturneGardenBloom],
                          elevation: Int) -> String {
        let verb: String
        switch action {
        case .plant: verb = "planting"
        case .move: verb = "moving"
        case .resize: verb = "resizing"
        case let .remove(index): return "removing " + level.bloomName(index, bloom: blooms[index])
        case .sun: return "setting " + NocturneGardenLevel.sunName(elevation)
        }
        guard let bloom = named, let index = after.firstIndex(of: bloom) else { return verb }
        return verb + " " + level.bloomName(index, bloom: bloom)
    }

    /// Restores the moment before the latest action (with its moves) and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final);
    ///   `.action("nothing-to-undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(NocturneGardenError) {
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

    /// Restores the moment of the latest undone action (with its moves) and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("nothing-to-redo")` when nothing was undone. A
    ///   refused redo leaves the play unchanged.
    public mutating func redo() throws(NocturneGardenError) {
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
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused (an undo or redo made while paused) or resumed (an action after a paused undo), the replay
    /// pauses or resumes first. Every produced record must equal the given one, so the trace reproduces every
    /// fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action or is not reproduced; any refusal of the replayed
    ///   action.
    public static func replay(level: NocturneGardenLevel,
                              records: [NocturneGardenRecord]) throws(NocturneGardenError) -> NocturneGardenPlay {
        var play = NocturneGardenPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: NocturneGardenRecord = records[index]
            if play.fingerprint != record.previous {
                var other: NocturneGardenPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .plant, .move, .resize, .remove, .sun:
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
    private var moment: Snapshot {
        Snapshot(stage: stage, blooms: blooms, elevation: elevation, moves: moves, failure: failure,
                 failureReason: failureReason, mask: mask)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        blooms = snapshot.blooms
        elevation = snapshot.elevation
        moves = snapshot.moves
        failure = snapshot.failure
        failureReason = snapshot.failureReason
        mask = snapshot.mask
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: NocturneGardenRecordKind, action: NocturneGardenAction?, move: Int,
                                 previous: String) {
        let record = NocturneGardenRecord(schema: Self.schema, seed: level.seed, move: move, kind: kind,
                                          action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
