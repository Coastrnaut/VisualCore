// FacetedForgePlay — feature 371 (R02-G08-01) T-R02G0801-004 (FR-R02G0801-004 … 008, 010, 011; clarifications Q2, Q4,
// Q5). One play of a Faceted Forge level: the life stage, the pieces in canonical order with their shares of the
// crystal, the cuts spent, the failure, the append-only records and the undo and redo stacks. An action is validated in
// this order — stage, previous fingerprint, range, miss — and refused without any change, or applied and recorded.
// Every accepted cut spends one cut; a refused action spends nothing. After a cut the sliver is judged first (a new
// half whose share of the crystal is strictly below the level's sliver limit fails the play, naming that piece by its
// index in the new canonical order and the cut index), then the win (the multiset of (share, face count) equals the
// target), then the budget (cuts spent equal to the budget: failed). There is no budget refusal: the cut that reaches
// the budget is applied and then judged, so a win on the last cut of the budget wins. An overflow of the exact
// arithmetic refuses the cut (`.action("overflow")`) and leaves the play unchanged. Every accepted action can be undone
// and redone exactly (snapshots); undo gives the cut back, redo spends it again, and a new cut clears the redo stack.
// Undo works in playing, paused and failed (a failed play returns to playing, an honest retry that is recorded); a won
// play is final. A record trace replays to the same records, fingerprints and outcome. Exact fractions only; no clock,
// no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum FacetedForgeFailure: Sendable, Hashable, Codable {
    /// A cut left a piece below the sliver limit: the piece's index in the new canonical order (first) and the cut
    /// index (second, the cuts spent before that cut).
    case sliver(Int, Int)
    /// The cuts spent reached the budget without a win.
    case budget

    /// The stable failure code: `sliver` or `budget`.
    public var code: String {
        switch self {
        case .sliver: "sliver"
        case .budget: "budget"
        }
    }
}

/// The life stage of a play.
public enum FacetedForgeStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Cuts, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// The pieces match the target; `showResult` shows the result. Final: undo is refused.
    case won
    /// The play failed; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum FacetedForgeEvent: Sendable, Equatable {
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
public enum FacetedForgeRecordKind: String, Sendable, Codable {
    /// A piece cut in two.
    case cut
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct FacetedForgeRecord: Sendable, Equatable, Codable {
    /// The record schema (``FacetedForgePlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The cuts spent before the action (the cut index).
    public let cut: Int
    /// The kind of action.
    public let kind: FacetedForgeRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: FacetedForgeAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, cut: Int, kind: FacetedForgeRecordKind, action: FacetedForgeAction?,
                previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.cut = cut
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Faceted Forge level.
public struct FacetedForgePlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: FacetedForgeStage
        /// The pieces, in canonical order.
        let pieces: [FacetedForgePiece]
        /// The pieces' shares of the crystal.
        let shares: [FacetedForgeFraction]
        /// The cuts spent.
        let cuts: Int
        /// The failure, or nil.
        let failure: FacetedForgeFailure?
    }

    /// The level played.
    public let level: FacetedForgeLevel
    /// The life stage.
    public private(set) var stage: FacetedForgeStage
    /// The pieces, in canonical order (``FacetedForgePiece/canonical(_:)``).
    public private(set) var pieces: [FacetedForgePiece]
    /// Each piece's share of the crystal's volume, in the order of ``pieces``.
    public private(set) var shares: [FacetedForgeFraction]
    /// The cuts (accepted cut actions) spent.
    public private(set) var cuts: Int
    /// Why the play failed, or nil.
    public private(set) var failure: FacetedForgeFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [FacetedForgeRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the whole crystal as its one piece and no cut spent.
    public init(level: FacetedForgeLevel) {
        self.level = level
        stage = .loading
        pieces = [level.crystal]
        shares = [.one]
        cuts = 0
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the UTF-8 text, lines joined by a line feed: `schema <n>`; `level <level
    /// fingerprint>`; one line per piece in canonical order, `piece <direction>,<sign>,<depth>;… | <x>,<y>,<z>;…` (its
    /// half-spaces and its exact corners, fractions as text); `cuts <n>`; `stage <raw value>`; `failure <code>` (with
    /// ` <piece> <cut>` for a sliver) or `failure none`.
    public var fingerprint: String {
        var text: String = "schema " + String(Self.schema) + "\nlevel " + level.fingerprint
        text.reserveCapacity(128 + 256 * pieces.count)
        for piece in pieces {
            text += "\npiece "
            for (i, plane) in piece.halfSpaces.enumerated() {
                if i > 0 { text += ";" }
                text += String(plane.direction) + "," + String(plane.sign) + "," + String(plane.depth)
            }
            text += " | "
            for (i, corner) in piece.corners.enumerated() {
                if i > 0 { text += ";" }
                Self.append(corner.x, to: &text)
                text += ","
                Self.append(corner.y, to: &text)
                text += ","
                Self.append(corner.z, to: &text)
            }
        }
        text += "\ncuts " + String(cuts) + "\nstage " + stage.rawValue + "\nfailure "
        switch failure {
        case .sliver(let piece, let cut): text += "sliver " + String(piece) + " " + String(cut)
        case .budget: text += "budget"
        case nil: text += "none"
        }
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Appends `value` as ``FacetedForgeFraction/text`` ("3/16", "1") to `text`.
    private static func append(_ value: FacetedForgeFraction, to text: inout String) {
        text += String(value.numerator)
        if value.denominator != 1 { text += "/" + String(value.denominator) }
    }

    /// The cuts left: the budget less the cuts spent.
    public var remaining: Int { level.budget - cuts }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: FacetedForgeEvent) throws(FacetedForgeError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `action`'s operands are in range for a play of `count` pieces: a piece index 0 … count − 1, a direction
    /// 0 … 12 and a depth −24 … 24.
    public static func inRange(_ action: FacetedForgeAction, pieces count: Int) -> Bool {
        switch action {
        case .cut(let piece, let direction, let depth):
            return (0..<count).contains(piece) && FacetedForgeDirection.all.indices.contains(direction)
                && FacetedForgeHalfSpace.depths.contains(depth)
        }
    }

    /// Applies a cut that names the current fingerprint as its previous one: replaces the piece by its two halves (the
    /// pieces kept in canonical order), spends one cut, judges the outcome (sliver, then win, then budget) and records
    /// it.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action("range")` for a
    ///   piece index, direction or depth out of range; `.miss` when the plane does not pass through the piece's
    ///   interior; `.action("overflow")` when an exact value overflows. A refused action spends nothing, records
    ///   nothing and leaves the play unchanged.
    public mutating func apply(_ action: FacetedForgeAction, expecting previous: String) throws(FacetedForgeError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        guard Self.inRange(action, pieces: pieces.count) else { throw .action("range") }
        guard case .cut(let index, let direction, let depth) = action else { throw .action("range") }
        let halves: (below: FacetedForgePiece, above: FacetedForgePiece) =
            try pieces[index].cut(direction: direction, depth: depth)
        var rest: [FacetedForgePiece] = pieces
        rest.remove(at: index)
        let next: [FacetedForgePiece] = FacetedForgePiece.canonical(rest + [halves.below, halves.above])
        var nextShares: [FacetedForgeFraction] = []
        for piece in next { nextShares.append(try piece.volume.dividing(by: level.crystal.volume)) }
        let snapshot: Snapshot = moment
        let cutIndex: Int = cuts
        pieces = next
        shares = nextShares
        cuts += 1
        if let sliver = Self.sliverIndex(next, shares: nextShares, halves: halves, limit: level.sliver) {
            stage = .failed
            failure = .sliver(sliver, cutIndex)
        } else if Self.matches(next, shares: nextShares, target: level.target) {
            stage = .won
        } else if cuts >= level.budget {
            stage = .failed
            failure = .budget
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: .cut, action: action, cut: cutIndex, previous: before)
    }

    /// Restores the moment before the latest action (giving its cut back) and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final);
    ///   `.action("nothing-to-undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(FacetedForgeError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("nothing-to-undo") }
        let before: String = fingerprint
        let cutsBefore: Int = cuts
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, cut: cutsBefore, previous: before)
    }

    /// Restores the moment of the latest undone action (spending its cut again) and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("nothing-to-redo")` when nothing was undone. A
    ///   refused redo leaves the play unchanged.
    public mutating func redo() throws(FacetedForgeError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("nothing-to-redo") }
        let before: String = fingerprint
        let cutsBefore: Int = cuts
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, cut: cutsBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (a cut with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused (an undo or redo made while paused) or resumed (a cut after a paused undo), the replay
    /// pauses or resumes first. Every produced record must equal the given one, so the trace reproduces every
    /// fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action or is not reproduced; any refusal of the replayed
    ///   action.
    public static func replay(level: FacetedForgeLevel,
                              records: [FacetedForgeRecord]) throws(FacetedForgeError) -> FacetedForgePlay {
        var play = FacetedForgePlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: FacetedForgeRecord = records[index]
            if play.fingerprint != record.previous {
                var other: FacetedForgePlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .cut:
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

    /// The index in `pieces` of the first new half whose share is strictly below `limit`, or nil.
    static func sliverIndex(_ pieces: [FacetedForgePiece], shares: [FacetedForgeFraction],
                            halves: (below: FacetedForgePiece, above: FacetedForgePiece),
                            limit: FacetedForgeFraction) -> Int? {
        for index in pieces.indices where shares[index] < limit {
            if pieces[index] == halves.below || pieces[index] == halves.above { return index }
        }
        return nil
    }

    /// Whether the multiset of (share, face count) of `pieces` equals `target` (both compared sorted).
    static func matches(_ pieces: [FacetedForgePiece], shares: [FacetedForgeFraction],
                        target: [FacetedForgeTargetPiece]) -> Bool {
        guard pieces.count == target.count else { return false }
        var made: [FacetedForgeTargetPiece] = []
        for index in pieces.indices {
            made.append(FacetedForgeTargetPiece(share: shares[index], faces: pieces[index].faceCount))
        }
        return made.sorted() == target.sorted()
    }

    /// The current moment.
    private var moment: Snapshot {
        Snapshot(stage: stage, pieces: pieces, shares: shares, cuts: cuts, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        pieces = snapshot.pieces
        shares = snapshot.shares
        cuts = snapshot.cuts
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: FacetedForgeRecordKind, action: FacetedForgeAction?, cut: Int,
                                 previous: String) {
        let record = FacetedForgeRecord(schema: Self.schema, seed: level.seed, cut: cut, kind: kind, action: action,
                                        previous: previous, next: fingerprint)
        records.append(record)
    }
}
