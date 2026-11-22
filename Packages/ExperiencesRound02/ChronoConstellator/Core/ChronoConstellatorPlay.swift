// ChronoConstellatorPlay — feature 351 (R02-G06-01) T-R02G0601-004 (FR-R02G0601-004 … 008; clarifications Q3, Q4, Q5).
// One play of a Chrono Constellator level: the life stage, the replay tick, the timeline, the failure, the append-only
// records and the undo and redo stacks. An action is validated in this order — stage, previous fingerprint, range, edits
// only at tick 0, the edit's own rule (same phase, overlapping hold, missing hold), budget — and refused without any
// change, or applied and recorded. Phase, hold and release edit the timeline at tick 0; a step replays 1 … 1,200 ticks,
// spends nothing and stops at the first tick whose verdict decides the play; a rewind returns to tick 0 with the timeline
// kept (from playing, or from failed as an honest retry). Every accepted action can be undone and redone exactly
// (snapshots); a new action clears the redo stack. Undo works in playing, paused and failed (a failed play returns to
// playing); a won play is final. A record trace replays to the same records, fingerprints and outcome.
import Foundation
import VisualCoreMath

/// A player action.
public enum ChronoConstellatorAction: Sendable, Hashable, Codable {
    /// Set star (first) to start at phase (second).
    case phase(Int, Int)
    /// Hold star (first) from tick (second) for (third) ticks.
    case hold(Int, Int, Int)
    /// Remove the hold of star (first) that starts at tick (second).
    case release(Int, Int)
    /// Replay the given number of ticks, 1 … 1,200.
    case step(Int)
    /// Return to tick 0 with the timeline kept.
    case rewind
}

/// The life stage of a play.
public enum ChronoConstellatorStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Edits (at tick 0), steps, rewinds, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// Every star stood on its own target; `showResult` shows the result.
    case won
    /// The play failed; undo or rewind returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum ChronoConstellatorEvent: Sendable, Equatable {
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
public enum ChronoConstellatorRecordKind: String, Sendable, Codable {
    /// A start phase set.
    case phase
    /// A hold added.
    case hold
    /// A hold removed.
    case release
    /// A replay of ticks.
    case step
    /// A return to tick 0.
    case rewind
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct ChronoConstellatorRecord: Sendable, Equatable, Codable {
    /// The record schema (``ChronoConstellatorPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The replay tick before the action.
    public let tick: Int
    /// The kind of action.
    public let kind: ChronoConstellatorRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: ChronoConstellatorAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: ChronoConstellatorRecordKind,
                action: ChronoConstellatorAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Chrono Constellator level.
public struct ChronoConstellatorPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }
    /// The ticks a single step may replay.
    public static let steps: ClosedRange<Int> = 1...1_200

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        let stage: ChronoConstellatorStage
        let tick: Int
        let timeline: ChronoConstellatorTimeline
        let failure: ChronoConstellatorFailure?
    }

    /// The level played.
    public let level: ChronoConstellatorLevel
    /// The life stage.
    public private(set) var stage: ChronoConstellatorStage
    /// The replay tick, 0 at the start of the timeline.
    public private(set) var tick: Int
    /// The start phases and holds.
    public private(set) var timeline: ChronoConstellatorTimeline
    /// Why the play failed, or nil.
    public private(set) var failure: ChronoConstellatorFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [ChronoConstellatorRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading` at tick 0 with the level's default timeline.
    public init(level: ChronoConstellatorLevel) {
        self.level = level
        stage = .loading
        tick = 0
        timeline = ChronoConstellatorTimeline(level: level)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (one byte); the level fingerprint (UTF-8); the
    /// tick (four bytes, big-endian); the timeline fingerprint (UTF-8); the edits in use (one byte); the stage's raw value
    /// (UTF-8); a zero byte and the failure (code, then the two stars and the cell, one byte each, for a collision) when
    /// there is one. Positions follow from these, so they are not hashed separately.
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        for shift in [24, 16, 8, 0] { bytes.append(UInt8(truncatingIfNeeded: tick >> shift)) }
        bytes.append(contentsOf: Array(timeline.fingerprint.utf8))
        bytes.append(UInt8(truncatingIfNeeded: timeline.editsInUse(level: level)))
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        if let failure {
            bytes.append(0)
            bytes.append(contentsOf: Array(failure.code.utf8))
            if case .collision(let a, let b, let cell) = failure {
                bytes.append(contentsOf: [UInt8(truncatingIfNeeded: a), UInt8(truncatingIfNeeded: b),
                                          UInt8(truncatingIfNeeded: cell)])
            }
        }
        return StableHash.sha256Hex(bytes)
    }

    /// The edits in use.
    public var spent: Int { timeline.editsInUse(level: level) }

    /// The edits left.
    public var remaining: Int { level.budget - spent }

    /// The cells of every star at the current tick.
    public var positions: [Int] { timeline.positions(at: tick, level: level) }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: ChronoConstellatorEvent) throws(ChronoConstellatorError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `action`'s operands are in range for `level`: a star index; a phase 0 … L − 1; a hold start ≥ 1 and length
    /// 1 … 60 ending by the tick limit; a step of 1 … 1,200 ticks.
    public static func inRange(_ action: ChronoConstellatorAction, level: ChronoConstellatorLevel) -> Bool {
        switch action {
        case .phase(let star, let offset):
            return level.stars.indices.contains(star) && (0..<level.stars[star].length).contains(offset)
        case .hold(let star, let start, let length):
            return level.stars.indices.contains(star) && start >= 1
                && ChronoConstellatorTimeline.holdLengths.contains(length) && start + length - 1 <= level.tickLimit
        case .release(let star, _):
            return level.stars.indices.contains(star)
        case .step(let ticks):
            return steps.contains(ticks)
        case .rewind:
            return true
        }
    }

    /// Applies an action that names the current fingerprint as its previous one and records it, with its verdict.
    ///
    /// - Throws: `.stage` outside `playing` (a rewind is also accepted in `failed`); `.stale` when `previous` is not
    ///   ``fingerprint``; `.action("range")` for an operand out of range; `.action("not-at-start")` for an edit after tick
    ///   0; `.action("same-phase")`, `.action("overlap")` or `.action("no-hold")` for an edit its own rule refuses;
    ///   `.budget` when an edit would bring the edits in use above the budget. A refused action leaves the play unchanged.
    public mutating func apply(_ action: ChronoConstellatorAction,
                               expecting previous: String) throws(ChronoConstellatorError) {
        if case .rewind = action {
            guard stage == .playing || stage == .failed else { throw .stage }
        } else {
            guard stage == .playing else { throw .stage }
        }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        guard Self.inRange(action, level: level) else { throw .action("range") }
        let snapshot: Snapshot = moment
        let tickBefore: Int = tick
        switch action {
        case .phase(let star, let offset):
            guard tick == 0 else { throw .action("not-at-start") }
            timeline = try timeline.settingPhase(star: star, to: offset, level: level)
        case .hold(let star, let start, let length):
            guard tick == 0 else { throw .action("not-at-start") }
            timeline = try timeline.adding(ChronoConstellatorHold(star: star, start: start, length: length), level: level)
        case .release(let star, let start):
            guard tick == 0 else { throw .action("not-at-start") }
            timeline = try timeline.releasing(star: star, start: start, level: level)
        case .step(let ticks):
            for _ in 0..<ticks {
                tick += 1
                let verdict = ChronoConstellatorEvaluation.verdict(positions: positions, tick: tick, level: level)
                switch verdict {
                case .running: continue
                case .won: stage = .won
                case .failed(let reason):
                    stage = .failed
                    failure = reason
                }
                break
            }
        case .rewind:
            tick = 0
            failure = nil
            stage = .playing
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, tick: tickBefore, previous: before)
    }

    /// Restores the moment before the latest action and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed`; `.action("nothing-to-undo")` when nothing can be
    ///   undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(ChronoConstellatorError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("nothing-to-undo") }
        let before: String = fingerprint
        let tickBefore: Int = tick
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, tick: tickBefore, previous: before)
    }

    /// Restores the moment of the latest undone action and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("nothing-to-redo")` when nothing was undone. A refused
    ///   redo leaves the play unchanged.
    public mutating func redo() throws(ChronoConstellatorError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("nothing-to-redo") }
        let before: String = fingerprint
        let tickBefore: Int = tick
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, tick: tickBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Every produced
    /// record must equal the given one, so the trace reproduces every fingerprint and the outcome. Pauses are not
    /// recorded, so a replay runs in `playing`.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: ChronoConstellatorLevel,
                              records: [ChronoConstellatorRecord]) throws(ChronoConstellatorError) -> ChronoConstellatorPlay {
        var play = ChronoConstellatorPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: ChronoConstellatorRecord = records[index]
            switch record.kind {
            case .phase, .hold, .release, .step, .rewind:
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
    private var moment: Snapshot { Snapshot(stage: stage, tick: tick, timeline: timeline, failure: failure) }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        tick = snapshot.tick
        timeline = snapshot.timeline
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// The record kind of an action.
    private static func kind(of action: ChronoConstellatorAction) -> ChronoConstellatorRecordKind {
        switch action {
        case .phase: .phase
        case .hold: .hold
        case .release: .release
        case .step: .step
        case .rewind: .rewind
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: ChronoConstellatorRecordKind, action: ChronoConstellatorAction?, tick: Int,
                                 previous: String) {
        let record = ChronoConstellatorRecord(schema: Self.schema, seed: level.seed, tick: tick, kind: kind,
                                              action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
