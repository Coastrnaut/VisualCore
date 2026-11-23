// AcousticConstellatorPlay — feature 421 (R02-G13-01) T-R02G1301-004 (FR-R02G1301-003 … 008, 011, 014;
// SC-R02G1301-002, 003, 004; clarifications Q3, Q4, Q5). One play of an Acoustic Constellator level: the life stage, the
// links (the level's fixed links plus the links the player made, kept sorted by (a, b)), the starting phase of every
// star, the actions spent, the report (the exact listen of the current links and phases), the graph-isomorphism label
// of the link graph and whether it matches the target symbol's, the failure, the append-only records and the undo and
// redo stacks. An action is validated in this order — stage, previous fingerprint, action (an unknown star, a self link,
// a link that exists, a link that would take a star above the degree limit D, a link above the link limit E, removing a
// missing or fixed link, a nudge step other than ±1) — and refused without any change, or applied and recorded. A link,
// an unlink and a nudge each change the state and spend 1 action; a listen spends 1 action and decides the level: won
// when the listen holds (even on the last action of the budget), else failed with `missing(pair)`,
// `disconnected(tick, link)` or `incoherent(longest run)`. After any other accepted action, a budget fully spent without
// a win fails the level with `budget(index)`, the 0-based index of that action. The report is recomputed after every
// action and the label is derived from the links when read (its search visits up to 8! orderings); neither decides the
// outcome by itself. Every accepted action can be undone and redone exactly (snapshots); a new action clears the redo
// stack. Undo works in playing, paused and failed (a failed play returns to
// playing, an honest retry that is recorded); a won play is final. A record trace replays to the same records,
// fingerprints and outcome. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum AcousticConstellatorFailure: Sendable, Hashable, Codable {
    /// A listen found this symbol pair unlinked (the lowest missing pair).
    case missing(AcousticConstellatorLink)
    /// A listen's remaining links stopped joining the symbol's stars on `tick`; `link` is the lowest-index link snapped
    /// on that tick.
    case disconnected(tick: Int, link: AcousticConstellatorLink)
    /// A listen's window ended without a hold; the payload is the longest coherent run.
    case incoherent(Int)
    /// The action with this 0-based index spent the last of the budget without a win.
    case budget(Int)

    /// The stable failure code: `missing`, `disconnected`, `incoherent` or `budget`.
    public var code: String {
        switch self {
        case .missing: "missing"
        case .disconnected: "disconnected"
        case .incoherent: "incoherent"
        case .budget: "budget"
        }
    }
}

/// An action on the constellation.
public enum AcousticConstellatorAction: Sendable, Hashable, Codable {
    /// Links two distinct stars (in either order); spends 1 action.
    case link(Int, Int)
    /// Removes a link the player made between two stars (in either order); spends 1 action.
    case unlink(Int, Int)
    /// Shifts star `star`'s starting phase by `step` (+1 or −1, modulo 12); spends 1 action.
    case nudge(Int, Int)
    /// Runs a listen of the current links and phases and decides the level; spends 1 action.
    case listen

    /// The record kind of the action.
    public var kind: AcousticConstellatorRecordKind {
        switch self {
        case .link: .link
        case .unlink: .unlink
        case .nudge: .nudge
        case .listen: .listen
        }
    }
}

/// The life stage of a play.
public enum AcousticConstellatorStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// A listen held; `showResult` shows the result. Final: undo is refused.
    case won
    /// A listen failed or the budget ran out; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum AcousticConstellatorEvent: Sendable, Equatable {
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
public enum AcousticConstellatorRecordKind: String, Sendable, Codable {
    /// A link.
    case link
    /// An unlink.
    case unlink
    /// A phase nudge.
    case nudge
    /// A listen.
    case listen
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct AcousticConstellatorRecord: Sendable, Equatable, Codable {
    /// The record schema (``AcousticConstellatorPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions spent before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: AcousticConstellatorRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: AcousticConstellatorAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: AcousticConstellatorRecordKind,
                action: AcousticConstellatorAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of an Acoustic Constellator level.
public struct AcousticConstellatorPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: AcousticConstellatorStage
        /// The links, sorted.
        let links: [AcousticConstellatorLink]
        /// The starting phases.
        let phases: [Int]
        /// The actions spent.
        let actionsSpent: Int
        /// The listen of the links and phases.
        let report: AcousticConstellatorListen
        /// The failure, or nil.
        let failure: AcousticConstellatorFailure?
    }

    /// The level played.
    public let level: AcousticConstellatorLevel
    /// The life stage.
    public private(set) var stage: AcousticConstellatorStage
    /// The links: the level's fixed links and the links the player made, sorted by (a, b).
    public private(set) var links: [AcousticConstellatorLink]
    /// The starting phase of every star, in star order.
    public private(set) var phases: [Int]
    /// The actions accepted (restored by undo and redo); the next action's 0-based index.
    public private(set) var actionsSpent: Int
    /// The listen of ``links`` from ``phases``, recomputed after every action.
    public private(set) var report: AcousticConstellatorListen
    /// Why the play failed, or nil.
    public private(set) var failure: AcousticConstellatorFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [AcousticConstellatorRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's fixed links and starting phases, no action spent, no failure.
    public init(level: AcousticConstellatorLevel) {
        self.level = level
        stage = .loading
        links = level.fixedLinks.sorted()
        phases = level.startingPhases
        actionsSpent = 0
        report = level.listen(links: links, phases: phases)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The graph-isomorphism label of ``links`` on all stars (``AcousticConstellatorLabel``), as it stands after the
    /// latest action. Derived from the links when read: the label search visits up to 8! orderings, so it is not
    /// recomputed for actions nobody reads it after. It only reports and never decides the outcome.
    public var label: String { AcousticConstellatorLabel.label(stars: level.stars.count, links: links) }

    /// Whether ``label`` equals the label of the target symbol's graph (``AcousticConstellatorLevel/symbolLabel``).
    public var matchesSymbol: Bool { label == level.symbolLabel }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// The progress in words for the current report (see ``AcousticConstellatorLevel/progressDescription``).
    public var progressDescription: String {
        level.progressDescription(listen: report, actionsLeft: actionsLeft)
    }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"failure":"<f>","level":"<level fingerprint>","links":[[a,b],…],"phases":[<φ>,…],
    /// "schema":1,"stage":"<stage>"}`, where the failure is `"none"`, `"missing <a> <b>"`,
    /// `"disconnected <tick> <a> <b>"`, `"incoherent <run>"` or `"budget <index>"`, the links are sorted and the phases
    /// are in star order.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .missing(let pair): failureText = "missing " + String(pair.a) + " " + String(pair.b)
        case .disconnected(let tick, let link):
            failureText = "disconnected " + String(tick) + " " + String(link.a) + " " + String(link.b)
        case .incoherent(let run): failureText = "incoherent " + String(run)
        case .budget(let index): failureText = "budget " + String(index)
        case nil: failureText = "none"
        }
        var linksText: String = ""
        for (position, link) in links.enumerated() {
            if position > 0 { linksText += "," }
            linksText += "[" + String(link.a) + "," + String(link.b) + "]"
        }
        var phasesText: String = ""
        for (position, phase) in phases.enumerated() {
            if position > 0 { phasesText += "," }
            phasesText += String(phase)
        }
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"failure\":\"" + failureText
            + "\",\"level\":\"" + level.fingerprint + "\",\"links\":[" + linksText + "],\"phases\":[" + phasesText
            + "],\"schema\":" + String(Self.schema) + ",\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: AcousticConstellatorEvent) throws(AcousticConstellatorError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `star` is a star of the level.
    private func isStar(_ star: Int) -> Bool { star >= 0 && star < level.stars.count }

    /// The links touching `star`, fixed links included.
    private func degree(_ star: Int) -> Int {
        var count: Int = 0
        for link in links where link.touches(star) { count += 1 }
        return count
    }

    /// Checks `action` against the constellation.
    ///
    /// - Throws: `.action("star")` for an unknown star; `.action("self")` for a link or unlink of a star to itself;
    ///   `.action("exists")` for a link that exists; `.action("degree")` for a link that would take a star above the
    ///   degree limit; `.action("limit")` for a link above the link limit; `.action("missing")` for removing a link that
    ///   does not exist; `.action("fixed")` for removing a fixed link; `.action("step")` for a nudge step other than ±1.
    func check(_ action: AcousticConstellatorAction) throws(AcousticConstellatorError) {
        switch action {
        case .link(let u, let v):
            guard isStar(u), isStar(v) else { throw .action("star") }
            guard u != v else { throw .action("self") }
            let link = AcousticConstellatorLink.between(u, v)
            guard !links.contains(link) else { throw .action("exists") }
            guard degree(u) < level.degreeLimit, degree(v) < level.degreeLimit else { throw .action("degree") }
            guard links.count < level.linkLimit else { throw .action("limit") }
        case .unlink(let u, let v):
            guard isStar(u), isStar(v) else { throw .action("star") }
            guard u != v else { throw .action("self") }
            let link = AcousticConstellatorLink.between(u, v)
            guard links.contains(link) else { throw .action("missing") }
            guard !level.fixedLinks.contains(link) else { throw .action("fixed") }
        case .nudge(let star, let step):
            guard isStar(star) else { throw .action("star") }
            guard step == 1 || step == -1 else { throw .action("step") }
        case .listen:
            return
        }
    }

    /// Applies an action that names the current fingerprint as its previous one: a link, an unlink or a nudge (changes
    /// the links or a starting phase) or a listen (decides the level: won when the listen holds, else failed `missing`,
    /// `disconnected` or `incoherent`); each spends 1 action. After a link, unlink or nudge that spends the last of the
    /// budget, the play fails `budget(index)`. The report is recomputed and the action recorded.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``check(_:)``. A refused action spends nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: AcousticConstellatorAction,
                               expecting previous: String) throws(AcousticConstellatorError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try check(action)
        let snapshot: Snapshot = moment
        let actionIndex: Int = actionsSpent
        actionsSpent += 1
        switch action {
        case .link(let u, let v):
            links.append(AcousticConstellatorLink.between(u, v))
            links.sort()
        case .unlink(let u, let v):
            let link = AcousticConstellatorLink.between(u, v)
            links.removeAll { $0 == link }
        case .nudge(let star, let step):
            phases[star] = AcousticConstellatorClock.reduce(phases[star] + step)
        case .listen:
            break
        }
        report = level.listen(links: links, phases: phases)
        if action == .listen {
            switch report.outcome {
            case .won: stage = .won
            case .missing(let pair):
                stage = .failed
                failure = .missing(pair)
            case .disconnected(let tick, let link):
                stage = .failed
                failure = .disconnected(tick: tick, link: link)
            case .incoherent(let run):
                stage = .failed
                failure = .incoherent(run)
            }
        } else if actionsSpent >= level.budget {
            stage = .failed
            failure = .budget(actionIndex)
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: action.kind, action: action, index: actionIndex, previous: before)
    }

    /// Restores the moment before the latest action (links, phases, actions spent, report, failure) and records the
    /// undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(AcousticConstellatorError) {
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
    public mutating func redo() throws(AcousticConstellatorError) {
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
    public static func replay(level: AcousticConstellatorLevel, records: [AcousticConstellatorRecord])
        throws(AcousticConstellatorError) -> AcousticConstellatorPlay {
        var play = AcousticConstellatorPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: AcousticConstellatorRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: AcousticConstellatorPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .link, .unlink, .nudge, .listen:
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
        Snapshot(stage: stage, links: links, phases: phases, actionsSpent: actionsSpent, report: report,
                 failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        links = snapshot.links
        phases = snapshot.phases
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
    private mutating func append(kind: AcousticConstellatorRecordKind, action: AcousticConstellatorAction?, index: Int,
                                 previous: String) {
        let record = AcousticConstellatorRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                                action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
