// WaveKnotKeeperPlay — feature 321 (R02-G03-01) T-R02G0301-004 (FR-R02G0301-002 … 006; clarifications Q2, Q4, Q5). One
// play of a Wave Knot Keeper level: the life stage, the rope's control points, the moves spent, the append-only records
// and the undo and redo stacks. A move steps one control point one lattice unit; it is validated in this order — stage,
// previous fingerprint, point index (`range`), bounds, coincidence with another point, the sweep through the rope outside
// a gate (`crossing`), the tension bound (`tension`), the allowance — and refused without any change, or applied,
// recorded and followed by the verdict: a rope whose projection matches the target wins, and spending the last move
// without a win fails with the final summary as the explanation. Undo steps the point back and refunds the move (the rope
// returns to a state it already held, so no check can fail); redo re-applies it; a new move clears the redo stack. A
// record trace replays to the same records, fingerprints and outcome.
import VisualCoreMath

/// The life stage of a play.
public enum WaveKnotKeeperStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Moves, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it.
    case paused
    /// The rope matches the target; `showResult` shows the result.
    case won
    /// The allowance is spent without a win; `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum WaveKnotKeeperEvent: Sendable, Equatable {
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
public enum WaveKnotKeeperRecordKind: String, Sendable, Codable {
    /// A move of a control point.
    case move
    /// An undo of the latest move.
    case undo
    /// A redo of the latest undone move.
    case redo
}

/// The append-only record of one accepted move, undo or redo.
public struct WaveKnotKeeperRecord: Sendable, Equatable, Codable {
    /// The record schema (``WaveKnotKeeperPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The record's index in the play's records.
    public let tick: Int
    /// The kind of action.
    public let kind: WaveKnotKeeperRecordKind
    /// The control point that moved.
    public let point: Int
    /// The direction it stepped (for an undo, the direction of the step back).
    public let direction: WaveKnotKeeperDirection
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: WaveKnotKeeperRecordKind, point: Int,
                direction: WaveKnotKeeperDirection, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.point = point
        self.direction = direction
        self.previous = previous
        self.next = next
    }
}

/// One play of a Wave Knot Keeper level.
public struct WaveKnotKeeperPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// The level played.
    public let level: WaveKnotKeeperLevel
    /// The life stage.
    public private(set) var stage: WaveKnotKeeperStage
    /// The rope's control points.
    public private(set) var points: [WaveKnotKeeperPoint]
    /// The moves spent (undo refunds one, redo spends one).
    public private(set) var spent: Int
    /// The append-only records of every accepted move, undo and redo.
    public private(set) var records: [WaveKnotKeeperRecord]
    /// The projection summary of the final rope when the play failed, otherwise nil.
    public private(set) var failure: WaveKnotKeeperSummary?
    /// Moves that undo can revert, latest last.
    private(set) var undoStack: [WaveKnotKeeperMove]
    /// Moves that redo can re-apply, latest last.
    private(set) var redoStack: [WaveKnotKeeperMove]

    /// A play of `level` in stage `loading` at the level's start rope with nothing spent.
    public init(level: WaveKnotKeeperLevel) {
        self.level = level
        stage = .loading
        points = level.points
        spent = 0
        records = []
        failure = nil
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (one byte); the level fingerprint (UTF-8);
    /// each control point's x, y and z (one byte each, two's complement); the moves spent (one byte); the stage's raw
    /// value (UTF-8).
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        for p in points {
            bytes.append(UInt8(truncatingIfNeeded: p.x))
            bytes.append(UInt8(truncatingIfNeeded: p.y))
            bytes.append(UInt8(truncatingIfNeeded: p.z))
        }
        bytes.append(UInt8(truncatingIfNeeded: spent))
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        return StableHash.sha256Hex(bytes)
    }

    /// The xy-projection summary of the current rope.
    public var summary: WaveKnotKeeperSummary { WaveKnotKeeperGeometry.summary(points) }

    /// The tension of the current rope.
    public var tension: Int { WaveKnotKeeperGeometry.tension(points) }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { stage == .playing && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { stage == .playing && !redoStack.isEmpty && spent < level.allowance }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: WaveKnotKeeperEvent) throws(WaveKnotKeeperError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Why `move` is illegal for the rope `points` of `level`, or nil when it is legal (range, bounds, coincidence,
    /// sweep outside a gate, tension), in that order. Reads only; the stage, fingerprint and allowance are the play's.
    public static func refusal(of move: WaveKnotKeeperMove, points: [WaveKnotKeeperPoint],
                               level: WaveKnotKeeperLevel) -> WaveKnotKeeperError? {
        guard points.indices.contains(move.point) else { return .move("range") }
        let from = points[move.point]
        let to = from.moved(move.direction)
        guard to.isInBounds else { return .move("bounds") }
        guard !points.contains(to) else { return .move("coincident") }
        if !level.gateContains(from, to)
            && !WaveKnotKeeperGeometry.sweepIsClear(points, moving: move.point, to: to) {
            return .move("crossing")
        }
        var moved = points
        moved[move.point] = to
        guard WaveKnotKeeperGeometry.tension(moved) <= level.tensionBound else { return .move("tension") }
        return nil
    }

    /// Applies a move that names the current fingerprint as its previous one, records it, then checks the verdict: a
    /// matching projection wins; otherwise, when the allowance is spent, the play fails with the summary as
    /// ``failure``.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; the refusal of
    ///   ``refusal(of:points:level:)`` (`.move("range" | "bounds" | "coincident" | "crossing" | "tension")`);
    ///   `.allowance` when the allowance is spent. A refused move leaves the play unchanged.
    public mutating func apply(_ move: WaveKnotKeeperMove, expecting previous: String) throws(WaveKnotKeeperError) {
        guard stage == .playing else { throw .stage }
        let before = fingerprint
        guard previous == before else { throw .stale }
        if let refusal = Self.refusal(of: move, points: points, level: level) { throw refusal }
        guard spent < level.allowance else { throw .allowance }
        points[move.point] = points[move.point].moved(move.direction)
        spent += 1
        undoStack.append(move)
        redoStack.removeAll()
        settle(failing: true)
        append(kind: .move, point: move.point, direction: move.direction, previous: before)
    }

    /// Steps the latest moved point back, refunds the move and records the undo; then checks the win (an undo never
    /// fails the play).
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-undo")` when there is no move to undo. A refused undo
    ///   leaves the play unchanged.
    public mutating func undo() throws(WaveKnotKeeperError) {
        guard stage == .playing else { throw .stage }
        guard let move = undoStack.last else { throw .move("nothing-to-undo") }
        let before = fingerprint
        undoStack.removeLast()
        points[move.point] = points[move.point].moved(move.direction.opposite)
        spent -= 1
        redoStack.append(move)
        settle(failing: false)
        append(kind: .undo, point: move.point, direction: move.direction.opposite, previous: before)
    }

    /// Re-applies the latest undone move, spends it and records the redo; then checks the verdict as a move.
    ///
    /// - Throws: `.stage` outside `playing`; `.move("nothing-to-redo")` when there is no undone move; `.allowance` when
    ///   the allowance is spent. A refused redo leaves the play unchanged.
    public mutating func redo() throws(WaveKnotKeeperError) {
        guard stage == .playing else { throw .stage }
        guard let move = redoStack.last else { throw .move("nothing-to-redo") }
        guard spent < level.allowance else { throw .allowance }
        let before = fingerprint
        redoStack.removeLast()
        points[move.point] = points[move.point].moved(move.direction)
        spent += 1
        undoStack.append(move)
        settle(failing: true)
        append(kind: .redo, point: move.point, direction: move.direction, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (a move with the record's previous fingerprint, an undo or a redo). Every produced
    /// record must equal the given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: WaveKnotKeeperLevel,
                              records: [WaveKnotKeeperRecord]) throws(WaveKnotKeeperError) -> WaveKnotKeeperPlay {
        var play = WaveKnotKeeperPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record = records[index]
            switch record.kind {
            case .move:
                try play.apply(WaveKnotKeeperMove(point: record.point, direction: record.direction),
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

    /// After an accepted action: `won` when the rope matches the target; otherwise, when `failing` and the allowance is
    /// spent, `failed` with the summary.
    private mutating func settle(failing: Bool) {
        if level.wins(points) {
            stage = .won
        } else if failing && spent == level.allowance {
            stage = .failed
            failure = WaveKnotKeeperGeometry.summary(points)
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: WaveKnotKeeperRecordKind, point: Int, direction: WaveKnotKeeperDirection,
                                 previous: String) {
        let record = WaveKnotKeeperRecord(schema: Self.schema, seed: level.seed, tick: records.count, kind: kind,
                                          point: point, direction: direction, previous: previous, next: fingerprint)
        records.append(record)
    }
}
