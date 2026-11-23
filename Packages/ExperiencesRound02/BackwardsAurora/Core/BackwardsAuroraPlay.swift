// BackwardsAuroraPlay — feature 391 (R02-G10-01) T-R02G1001-004 (FR-R02G1001-004 … 008, 014; SC-R02G1001-002, 004;
// clarifications Q3, Q4, Q5). One play of a Backwards Aurora level: the life stage, the wave, the reversals spent, the
// failure, the append-only records and the undo and redo stacks. A reversal is validated in this order — stage,
// previous fingerprint, range and section length, no-op — and refused without any change, or applied and recorded.
// Every accepted reversal spends one; a refused one spends nothing; undo and redo spend nothing and restore the
// reversals spent of the moment they restore. After a reversal the tear is judged first (the lowest seam position of
// the section whose bend magnitude exceeds the breaking limit B fails the play with `tear(move, seam)`, the 0-based
// index of the reversal and that position), then the win (every checkpoint matched and the wave smooth), then the
// budget (reversals spent equal to the budget: failed). There is no budget refusal: the reversal that reaches the
// budget is applied and then judged, so a win on the last reversal of the budget wins. Every accepted reversal can be
// undone and redone exactly (snapshots); a new reversal clears the redo stack. Undo works in playing, paused and
// failed (a failed play returns to playing, an honest retry that is recorded); a won play is final. A record trace
// replays to the same records, fingerprints and outcome. The truth metric (distance and worst bend) is reported after
// every action and never decides the outcome. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum BackwardsAuroraFailure: Sendable, Hashable, Codable {
    /// The reversal with this 0-based index left a bend beyond the breaking limit at this seam position (the lowest
    /// such position among the section's seams).
    case tear(Int, Int)
    /// The reversals spent reached the budget without a win.
    case budget

    /// The stable failure code: `tear` or `budget`.
    public var code: String {
        switch self {
        case .tear: "tear"
        case .budget: "budget"
        }
    }
}

/// An action on the wave.
public enum BackwardsAuroraAction: Sendable, Hashable, Codable {
    /// Reverses the section [start, end] (inclusive) in time.
    case reverse(Int, Int)
}

/// The life stage of a play.
public enum BackwardsAuroraStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Reversals, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// Every checkpoint is matched and the wave is smooth; `showResult` shows the result. Final: undo is refused.
    case won
    /// The play failed (tear or budget); undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum BackwardsAuroraEvent: Sendable, Equatable {
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
public enum BackwardsAuroraRecordKind: String, Sendable, Codable {
    /// A section reversed.
    case reverse
    /// An undo of the latest reversal.
    case undo
    /// A redo of the latest undone reversal.
    case redo
}

/// The append-only record of one accepted action.
public struct BackwardsAuroraRecord: Sendable, Equatable, Codable {
    /// The record schema (``BackwardsAuroraPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The reversals spent before the action (the 0-based reversal index).
    public let move: Int
    /// The kind of action.
    public let kind: BackwardsAuroraRecordKind
    /// The reversal applied; nil for an undo or a redo.
    public let action: BackwardsAuroraAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, move: Int, kind: BackwardsAuroraRecordKind, action: BackwardsAuroraAction?,
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

/// One play of a Backwards Aurora level.
public struct BackwardsAuroraPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: BackwardsAuroraStage
        /// The wave.
        let wave: BackwardsAuroraWave
        /// The reversals spent.
        let spent: Int
        /// The failure, or nil.
        let failure: BackwardsAuroraFailure?
    }

    /// The level played.
    public let level: BackwardsAuroraLevel
    /// The life stage.
    public private(set) var stage: BackwardsAuroraStage
    /// The current wave.
    public private(set) var wave: BackwardsAuroraWave
    /// The reversals spent.
    public private(set) var spent: Int
    /// Why the play failed, or nil.
    public private(set) var failure: BackwardsAuroraFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [BackwardsAuroraRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the opening wave and no reversal spent.
    public init(level: BackwardsAuroraLevel) {
        self.level = level
        stage = .loading
        wave = level.opening
        spent = 0
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// Per checkpoint (in position order): whether the wave has the target's height there.
    public var matched: [Bool] { level.matched(wave) }

    /// The truth metric's distance to the target as an exact fraction, Σ|s − t| / Σ|t| (0 / 1 at an all-zero target
    /// the wave equals). It never decides the outcome.
    public var distance: (numerator: Int, denominator: Int) { wave.distance(to: level.target) }

    /// The truth metric's continuity: the worst bend magnitude of the wave. It never decides the outcome.
    public var worstBend: Int { wave.worstBend }

    /// The reversals left: the budget less the reversals spent.
    public var remaining: Int { level.budget - spent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"failure":<f>,"level":"<level fingerprint>","samples":[<s0>,…],"schema":1,"spent":<n>,"stage":"<stage>"}`,
    /// where the failure is `"none"`, `"budget"` or `"tear <move> <seam>"`.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .tear(let move, let seam): failureText = "tear " + String(move) + " " + String(seam)
        case .budget: failureText = "budget"
        case nil: failureText = "none"
        }
        var samplesText: String = ""
        for (index, sample) in wave.samples.enumerated() {
            if index > 0 { samplesText += "," }
            samplesText += String(sample)
        }
        let text: String = "{\"failure\":\"" + failureText + "\",\"level\":\"" + level.fingerprint
            + "\",\"samples\":[" + samplesText + "],\"schema\":" + String(Self.schema) + ",\"spent\":" + String(spent)
            + ",\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: BackwardsAuroraEvent) throws(BackwardsAuroraError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Checks `action`'s section against the wave and the level.
    ///
    /// - Throws: `.action("end")` for an end outside 0 … N − 1; `.action("start")` for a start below 0 or not before
    ///   the end; `.action("length")` for a section length end − start + 1 outside the level's shortest … longest.
    func checkRange(_ action: BackwardsAuroraAction) throws(BackwardsAuroraError) {
        switch action {
        case let .reverse(start, end):
            guard end >= 0 && end < wave.count else { throw .action("end") }
            guard start >= 0 && start < end else { throw .action("start") }
            guard level.sectionLengths.contains(end - start + 1) else { throw .action("length") }
        }
    }

    /// Applies a reversal that names the current fingerprint as its previous one: reverses the section, spends one
    /// reversal, judges the outcome (tear, then win, then budget) and records it.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` for a
    ///   section out of range (``checkRange(_:)``); `.noop` for a section that reads the same both ways. A refused
    ///   action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: BackwardsAuroraAction,
                               expecting previous: String) throws(BackwardsAuroraError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try checkRange(action)
        let start: Int
        let end: Int
        switch action {
        case let .reverse(first, last):
            start = first
            end = last
        }
        guard !wave.isPalindrome(start: start, end: end) else { throw .noop }
        let snapshot: Snapshot = moment
        let moveIndex: Int = spent
        wave = wave.reversed(start: start, end: end)
        spent += 1
        var torn: Int?
        for seam in BackwardsAuroraWave.seams(start: start, end: end, count: wave.count)
        where abs(wave.bend(at: seam)) > level.breakingLimit {
            torn = seam
            break
        }
        if let seam = torn {
            stage = .failed
            failure = .tear(moveIndex, seam)
        } else if level.wins(wave) {
            stage = .won
        } else if spent >= level.budget {
            stage = .failed
            failure = .budget
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: .reverse, action: action, move: moveIndex, previous: before)
    }

    /// Restores the moment before the latest reversal (with its reversals spent) and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(BackwardsAuroraError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        let spentBefore: Int = spent
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, move: spentBefore, previous: before)
    }

    /// Restores the moment of the latest undone reversal (with its reversals spent) and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(BackwardsAuroraError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let spentBefore: Int = spent
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, move: spentBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (a reversal with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused (an undo or redo made while paused) or resumed (a reversal after a paused undo), the replay
    /// pauses or resumes first. Every produced record must equal the given one, so the trace reproduces every
    /// fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")` or `.malformed("seed <i>")` when record `i` has another schema or level
    ///   seed; `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action or is not reproduced; any refusal of the replayed
    ///   action.
    public static func replay(level: BackwardsAuroraLevel,
                              records: [BackwardsAuroraRecord]) throws(BackwardsAuroraError) -> BackwardsAuroraPlay {
        var play = BackwardsAuroraPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: BackwardsAuroraRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: BackwardsAuroraPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .reverse:
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
        Snapshot(stage: stage, wave: wave, spent: spent, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        wave = snapshot.wave
        spent = snapshot.spent
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: BackwardsAuroraRecordKind, action: BackwardsAuroraAction?, move: Int,
                                 previous: String) {
        let record = BackwardsAuroraRecord(schema: Self.schema, seed: level.seed, move: move, kind: kind,
                                           action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
