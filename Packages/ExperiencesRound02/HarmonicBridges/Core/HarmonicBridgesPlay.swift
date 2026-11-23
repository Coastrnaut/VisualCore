// HarmonicBridgesPlay — feature 411 (R02-G12-01) T-R02G1201-004 (FR-R02G1201-004 … 008, 013, 014; SC-R02G1201-001,
// 002, 004; clarifications Q3, Q4, Q5). One play of a Harmonic Bridges level: the life stage, the peg of every string,
// the actions spent, the report (the exact truth metric at the current pegs), the failure, the append-only records and
// the undo and redo stacks. An action is validated in this order — stage, previous fingerprint, action (an unknown
// string, a peg outside 1 … 12, a locked string), no-op (a tuning to the string's current peg) — and refused without
// any change, or applied and recorded. A tuning sets one peg and spends 1 action; a test spends 1 action and decides the
// crossing: won when the goal is reached in every step of the crossing window (even on the last action of the budget),
// else failed with `broken(step, string)`, the first step whose path is missing and the lowest-index non-bridge string
// across the start's reach in that step (nil when no string crosses that cut). After any other accepted action, a budget
// fully spent without a win fails the level with `budget(index)`, the 0-based index of that action. The report is
// recomputed after every action and never decides the outcome by itself. A pluck is a query: it names the string and its
// resonance per step in words and changes nothing. Every accepted action can be undone and redone exactly (snapshots);
// a new action clears the redo stack. Undo works in playing, paused and failed (a failed play returns to playing, an
// honest retry that is recorded); a won play is final. A record trace replays to the same records, fingerprints and
// outcome. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum HarmonicBridgesFailure: Sendable, Hashable, Codable {
    /// A test found the path missing in step `step` (0-based); `string` is the lowest-index non-bridge string joining an
    /// island the start reached in that step to one it did not, or nil when no string crosses that cut.
    case broken(step: Int, string: Int?)
    /// The action with this 0-based index spent the last of the budget without a win.
    case budget(Int)

    /// The stable failure code: `broken` or `budget`.
    public var code: String {
        switch self {
        case .broken: "broken"
        case .budget: "budget"
        }
    }
}

/// An action on the strings.
public enum HarmonicBridgesAction: Sendable, Hashable, Codable {
    /// Sets the peg of string `string` (0-based) to `peg` (1 … 12); spends 1 action.
    case tune(Int, Int)
    /// Tests the crossing over every step of the crossing window; spends 1 action.
    case test

    /// The record kind of the action.
    public var kind: HarmonicBridgesRecordKind {
        switch self {
        case .tune: .tune
        case .test: .test
        }
    }
}

/// The life stage of a play.
public enum HarmonicBridgesStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// A test held in every step; `showResult` shows the result. Final: undo is refused.
    case won
    /// A test broke or the budget ran out; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum HarmonicBridgesEvent: Sendable, Equatable {
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
public enum HarmonicBridgesRecordKind: String, Sendable, Codable {
    /// A tuning.
    case tune
    /// A test of the crossing.
    case test
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct HarmonicBridgesRecord: Sendable, Equatable, Codable {
    /// The record schema (``HarmonicBridgesPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions spent before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: HarmonicBridgesRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: HarmonicBridgesAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: HarmonicBridgesRecordKind,
                action: HarmonicBridgesAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Harmonic Bridges level.
public struct HarmonicBridgesPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: HarmonicBridgesStage
        /// The pegs.
        let pegs: [Int]
        /// The actions spent.
        let actionsSpent: Int
        /// The report at the pegs.
        let report: HarmonicBridgesReport
        /// The failure, or nil.
        let failure: HarmonicBridgesFailure?
    }

    /// The level played.
    public let level: HarmonicBridgesLevel
    /// The life stage.
    public private(set) var stage: HarmonicBridgesStage
    /// The peg of every string, in string order.
    public private(set) var pegs: [Int]
    /// The tunings and tests accepted (restored by undo and redo); the next action's 0-based index.
    public private(set) var actionsSpent: Int
    /// The truth metric at ``pegs``, recomputed after every action.
    public private(set) var report: HarmonicBridgesReport
    /// Why the play failed, or nil.
    public private(set) var failure: HarmonicBridgesFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [HarmonicBridgesRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting pegs, no action spent, no failure.
    public init(level: HarmonicBridgesLevel) {
        self.level = level
        stage = .loading
        pegs = level.startingPegs
        actionsSpent = 0
        report = level.report(pegs: level.startingPegs)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// The progress in words: "step 0: 2 bridges, goal reached; step 1: 1 bridge, goal not reached; 4 actions left".
    public var progressDescription: String {
        level.progressDescription(report: report, actionsLeft: actionsLeft)
    }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","pegs":[<peg>,…],"schema":1,"stage":"<stage>"}`,
    /// where the failure is `"none"`, `"broken <step> <string>"` (`"broken <step> none"` without a string) or
    /// `"budget <index>"`, and the pegs are in string order.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .broken(let step, let string):
            var named: String = "none"
            if let string { named = String(string) }
            failureText = "broken " + String(step) + " " + named
        case .budget(let index): failureText = "budget " + String(index)
        case nil: failureText = "none"
        }
        var pegsText: String = ""
        for (position, peg) in pegs.enumerated() {
            if position > 0 { pegsText += "," }
            pegsText += String(peg)
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + failureText
            + "\",\"level\":\"" + level.fingerprint + "\",\"pegs\":[" + pegsText + "],\"schema\":"
            + String(Self.schema) + ",\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// String `string` in words with its resonance per step at the current pegs, for example "string 0, island 0 to
    /// island 1, peg 2: step 0: mode 1, swing 2 6 8 6 2, a bridge; step 1: no modes, swing 0 0 0 0 0, not a bridge".
    /// A query: accepted in every stage, spends nothing, records nothing and changes nothing.
    ///
    /// - Throws: `.action("string")` for an unknown string.
    public func pluck(_ string: Int) throws(HarmonicBridgesError) -> String {
        guard string >= 0, string < level.strings.count else { throw .action("string") }
        return level.stringName(string, peg: pegs[string]) + ": " + level.resonanceDescription(string, pegs: pegs)
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: HarmonicBridgesEvent) throws(HarmonicBridgesError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Checks `action` against the strings: the action rules first, then the no-op rule.
    ///
    /// - Throws: `.action("string")` for an unknown string; `.action("peg")` for a peg outside 1 … 12;
    ///   `.action("locked")` for a locked string; `.noop` for a tuning to the string's current peg.
    func check(_ action: HarmonicBridgesAction) throws(HarmonicBridgesError) {
        guard case .tune(let string, let peg) = action else { return }
        guard string >= 0, string < level.strings.count else { throw .action("string") }
        guard HarmonicBridgesLevel.pegs.contains(peg) else { throw .action("peg") }
        guard !level.strings[string].locked else { throw .action("locked") }
        guard pegs[string] != peg else { throw .noop }
    }

    /// Applies an action that names the current fingerprint as its previous one: a tuning (sets the peg) or a test
    /// (decides the crossing: won when the goal is reached in every step, else failed `broken`); each spends 1 action.
    /// After a tuning that spends the last of the budget, the play fails `budget(index)`. The report is recomputed and
    /// the action recorded.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` or
    ///   `.noop` per ``check(_:)``. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: HarmonicBridgesAction,
                               expecting previous: String) throws(HarmonicBridgesError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try check(action)
        let snapshot: Snapshot = moment
        let actionIndex: Int = actionsSpent
        actionsSpent += 1
        switch action {
        case .tune(let string, let peg):
            pegs[string] = peg
            report = level.report(pegs: pegs)
            if actionsSpent >= level.budget {
                stage = .failed
                failure = .budget(actionIndex)
            }
        case .test:
            report = level.report(pegs: pegs)
            if let broken = level.firstBreak(report) {
                stage = .failed
                failure = .broken(step: broken.step, string: broken.string)
            } else {
                stage = .won
            }
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: action.kind, action: action, index: actionIndex, previous: before)
    }

    /// Restores the moment before the latest action (pegs, actions spent, report, failure) and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(HarmonicBridgesError) {
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
    public mutating func redo() throws(HarmonicBridgesError) {
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
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one
    /// with the play paused or resumed, the replay pauses or resumes first. Every produced record must equal the given
    /// one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")` or `.malformed("seed <i>")` when record `i` has another schema or level
    ///   seed; `.malformed("replay")` when a record's previous fingerprint is not the replayed play's;
    ///   `.malformed("record <i>")` when record `i` lacks its action, names an action of another kind or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: HarmonicBridgesLevel,
                              records: [HarmonicBridgesRecord]) throws(HarmonicBridgesError) -> HarmonicBridgesPlay {
        var play = HarmonicBridgesPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: HarmonicBridgesRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: HarmonicBridgesPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .tune, .test:
                guard let action = record.action, action.kind == record.kind else {
                    throw .malformed("record \(index)")
                }
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
        Snapshot(stage: stage, pegs: pegs, actionsSpent: actionsSpent, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        pegs = snapshot.pegs
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
    private mutating func append(kind: HarmonicBridgesRecordKind, action: HarmonicBridgesAction?, index: Int,
                                 previous: String) {
        let record = HarmonicBridgesRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                           action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
