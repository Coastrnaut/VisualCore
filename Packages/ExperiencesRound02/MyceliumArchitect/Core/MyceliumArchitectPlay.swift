// MyceliumArchitectPlay — feature 511 (R02-G22-01) T-R02G2201-004 (FR-R02G2201-006 … 009, 012, 013, 015;
// SC-R02G2201-001, 002, 004; clarifications Q4, Q5). One play of a Mycelium Architect level: the life stage, the
// arrangement (placed nutrients, placed blockers and seeds), the actions spent, the growth report (the truth metric,
// recomputed after every accepted arrangement action), the failure, the append-only records and the undo and redo
// stacks. An arrangement action — `nutrient(cell)`, `blocker(cell)`, `clear(cell)`, `seed(direction)` and
// `unseed(direction)` — is validated in this order: stage (not playing), previous fingerprint, action (a cell off the
// board or not empty — rock, toxin, root, terminal, fixed nutrient, placed item — for nutrient or blocker; a count
// already at its limit; clear of a cell without a placed item; a direction already seeded or the seed limit reached;
// unseed of a direction not seeded or a starting seed), budget (no action left); it is refused without any change, or
// applied and recorded, and spends 1 action. The run ("commit graph") is validated by stage and previous fingerprint
// only, never checks the budget, spends nothing and ends the level: won when the report wins, else failed with the
// judge's failure. Every accepted arrangement action and run can be undone and redone exactly (snapshots); a new action
// clears the redo stack. Undo and redo work in playing; undo also from failed (a failed run returns to playing with the
// arrangement before the run, actions spent unchanged, recorded); a redo after it re-runs and ends failed again the
// same way; a won run is final; nothing but resume is accepted while paused. The events begin, dismissTutorial, pause,
// resume and showResult are recorded with their own kinds. Each record carries the schema, the level seed, its 0-based
// position, the kind, the action and the fingerprints before and after; a trace replays to the same records,
// fingerprints and outcome. Integers only; no clock, no random source. Modelled on `BinaryGardensPlay` (feature 501).
import Foundation
import VisualCoreMath

/// The life stage of a play.
public enum MyceliumArchitectStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Arrangement actions, the run, undo and redo are accepted.
    case playing
    /// Play is paused; only `resume` is accepted.
    case paused
    /// The run won; `showResult` shows the result. Final: undo is refused.
    case won
    /// The run failed; undo returns to playing before the run, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum MyceliumArchitectEvent: Sendable, Equatable {
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

/// The append-only record of one accepted action or event.
public struct MyceliumArchitectRecord: Sendable, Equatable, Codable {
    /// The kind of an accepted action or event.
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// A nutrient placed.
        case nutrient
        /// A blocker placed.
        case blocker
        /// A placed item cleared.
        case clear
        /// A direction seeded at the root.
        case seed
        /// A player seed removed.
        case unseed
        /// The run that ended the level.
        case run
        /// An undo of the latest arrangement action or run.
        case undo
        /// A redo of the latest undone arrangement action or run.
        case redo
        /// The `begin` event.
        case begin
        /// The `dismissTutorial` event.
        case dismissTutorial
        /// The `pause` event.
        case pause
        /// The `resume` event.
        case resume
        /// The `showResult` event.
        case showResult
    }

    /// The record schema (``MyceliumArchitectPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let levelSeed: UInt64
    /// The record's 0-based position in the trace.
    public let index: Int
    /// The kind of action or event.
    public let kind: Kind
    /// The action applied; nil for an undo, a redo or an event.
    public let action: MyceliumArchitectAction?
    /// The play fingerprint before the action or event.
    public let previous: String
    /// The play fingerprint after the action or event (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, levelSeed: UInt64, index: Int, kind: Kind, action: MyceliumArchitectAction?,
                previous: String, next: String) {
        self.schema = schema
        self.levelSeed = levelSeed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Mycelium Architect level.
public struct MyceliumArchitectPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: MyceliumArchitectStage
        /// The arrangement.
        let arrangement: MyceliumArchitectArrangement
        /// The actions spent.
        let actionsSpent: Int
        /// The report.
        let report: MyceliumArchitectReport
        /// The failure, or nil.
        let failure: MyceliumArchitectFailure?
    }

    /// The level played.
    public let level: MyceliumArchitectLevel
    /// The life stage.
    public private(set) var stage: MyceliumArchitectStage
    /// The arrangement: placed nutrients, placed blockers and seeds; the level's start at first.
    public private(set) var arrangement: MyceliumArchitectArrangement
    /// The arrangement actions accepted (restored by undo and redo); the run spends nothing.
    public private(set) var actionsSpent: Int
    /// The growth report of ``arrangement`` in the level (the truth metric), recomputed after every arrangement action.
    public private(set) var report: MyceliumArchitectReport
    /// Why the run failed, or nil (nil before the run and after a winning one).
    public private(set) var failure: MyceliumArchitectFailure?
    /// The append-only records of every accepted action and event.
    public private(set) var records: [MyceliumArchitectRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: the level's starting arrangement, no action spent, no failure.
    public init(level: MyceliumArchitectLevel) {
        self.level = level
        stage = .loading
        arrangement = level.start
        actionsSpent = 0
        report = MyceliumArchitectGrowth.report(level, arrangement: level.start)
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The actions left in the budget.
    public var actionsLeft: Int { level.budget - actionsSpent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { (stage == .playing || stage == .failed) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { stage == .playing && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"actions":<spent>,"blockers":[[<column>,<row>],…],"failure":"<f>","level":"<level fingerprint>",
    /// "nutrients":[[<column>,<row>],…],"schema":1,"seeds":[<direction>,…],"stage":"<stage>"}`, cells and directions in
    /// the arrangement's sorted order, where the failure is `"none"`, `"toxic <pulse> <tip> <column> <row>"`,
    /// `"starved <pulse> <tip> <column> <row> <weight> <budget>"`, `"unreached <terminal>"` or
    /// `"overweight <weight> <limit>"`.
    public var fingerprint: String {
        let text: String = "{\"actions\":" + String(actionsSpent) + ",\"blockers\":[" + Self.cells(arrangement.blockers)
            + "],\"failure\":\"" + Self.text(failure) + "\",\"level\":\"" + level.fingerprint + "\",\"nutrients\":["
            + Self.cells(arrangement.nutrients) + "],\"schema\":" + String(Self.schema) + ",\"seeds\":["
            + Self.directions(arrangement.seeds) + "],\"stage\":\"" + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// "[<column>,<row>],…".
    static func cells(_ cells: [MyceliumArchitectCell]) -> String {
        var parts: [String] = []
        for cell in cells { parts.append("[" + String(cell.column) + "," + String(cell.row) + "]") }
        return parts.joined(separator: ",")
    }

    /// "<n>,…" of the direction numbers.
    static func directions(_ directions: [MyceliumArchitectDirection]) -> String {
        var parts: [String] = []
        for direction in directions { parts.append(String(direction.rawValue)) }
        return parts.joined(separator: ",")
    }

    /// "<a> <b> …".
    static func words(_ values: [Int]) -> String {
        var parts: [String] = []
        for value in values { parts.append(String(value)) }
        return parts.joined(separator: " ")
    }

    /// The canonical text of a failure (see ``fingerprint``).
    static func text(_ failure: MyceliumArchitectFailure?) -> String {
        switch failure {
        case .toxic(let pulse, let tip, let cell): "toxic " + words([pulse, tip, cell.column, cell.row])
        case .starved(let pulse, let tip, let cell, let weight, let budget):
            "starved " + words([pulse, tip, cell.column, cell.row, weight, budget])
        case .unreached(let terminal): "unreached " + String(terminal)
        case .overweight(let weight, let limit): "overweight " + words([weight, limit])
        case nil: "none"
        }
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`. Every accepted event is recorded with its own kind.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: MyceliumArchitectEvent) throws(MyceliumArchitectError) {
        let before: String = fingerprint
        let kind: MyceliumArchitectRecord.Kind
        switch (stage, event) {
        case (.loading, .begin):
            stage = level.tutorial ? .tutorial : .playing
            kind = .begin
        case (.tutorial, .dismissTutorial):
            stage = .playing
            kind = .dismissTutorial
        case (.playing, .pause):
            stage = .paused
            kind = .pause
        case (.paused, .resume):
            stage = .playing
            kind = .resume
        case (.won, .showResult), (.failed, .showResult):
            stage = .result
            kind = .showResult
        default:
            throw .stage
        }
        append(kind: kind, action: nil, previous: before)
    }

    /// The record kind of `action`.
    static func kind(of action: MyceliumArchitectAction) -> MyceliumArchitectRecord.Kind {
        switch action {
        case .nutrient: .nutrient
        case .blocker: .blocker
        case .clear: .clear
        case .seed: .seed
        case .unseed: .unseed
        case .run: .run
        }
    }

    /// The arrangement after the arrangement action `action` on `arrangement` in `level`, ignoring stage and budget.
    ///
    /// - Throws: `.action("cell")` for a nutrient or blocker off the board or on a cell that is not empty (rock,
    ///   toxin, root, terminal, fixed nutrient, placed item); `.action("nutrient limit")` or `.action("blocker limit")`
    ///   when that count is already at its limit; `.action("clear")` for a cell without a placed item;
    ///   `.action("seeded")` for a direction already seeded; `.action("seed limit")` when the seed limit is reached;
    ///   `.action("not seeded")` to unseed a direction not seeded; `.action("starting seed")` to unseed a starting
    ///   seed; `.action("run")` for the run, which is not an arrangement action.
    static func changed(_ level: MyceliumArchitectLevel, _ arrangement: MyceliumArchitectArrangement,
                        by action: MyceliumArchitectAction) throws(MyceliumArchitectError)
        -> MyceliumArchitectArrangement {
        var nutrients: [MyceliumArchitectCell] = arrangement.nutrients
        var blockers: [MyceliumArchitectCell] = arrangement.blockers
        var seeds: [MyceliumArchitectDirection] = arrangement.seeds
        switch action {
        case .nutrient(let cell):
            guard level.isEmpty(cell, in: arrangement) else { throw .action("cell") }
            guard nutrients.count < level.maxNutrients else { throw .action("nutrient limit") }
            nutrients.append(cell)
        case .blocker(let cell):
            guard level.isEmpty(cell, in: arrangement) else { throw .action("cell") }
            guard blockers.count < level.maxBlockers else { throw .action("blocker limit") }
            blockers.append(cell)
        case .clear(let cell):
            if let n = nutrients.firstIndex(of: cell) {
                nutrients.remove(at: n)
            } else if let b = blockers.firstIndex(of: cell) {
                blockers.remove(at: b)
            } else {
                throw .action("clear")
            }
        case .seed(let direction):
            guard !seeds.contains(direction) else { throw .action("seeded") }
            guard seeds.count < level.maxSeeds else { throw .action("seed limit") }
            seeds.append(direction)
        case .unseed(let direction):
            guard let s = seeds.firstIndex(of: direction) else { throw .action("not seeded") }
            guard !level.startSeeds.contains(direction) else { throw .action("starting seed") }
            seeds.remove(at: s)
        case .run:
            throw .action("run")
        }
        return MyceliumArchitectArrangement(nutrients: nutrients, blockers: blockers, seeds: seeds)
    }

    /// Applies an action that names the current fingerprint as its previous one. An arrangement action places a
    /// nutrient or blocker, clears a placed item, seeds or unseeds a direction, spends 1 action and recomputes the
    /// report; the run spends nothing and ends the level: `won` when the report wins, else `failed` with the judge's
    /// failure. The action is recorded and the redo stack cleared.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` for an
    ///   arrangement action the arrangement refuses (see the reasons in this file's header); `.budget` for an
    ///   arrangement action with no action left (the run is still allowed). A refused action spends nothing, records
    ///   nothing and leaves the play unchanged.
    public mutating func apply(_ action: MyceliumArchitectAction,
                               expecting previous: String) throws(MyceliumArchitectError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        switch action {
        case .nutrient, .blocker, .clear, .seed, .unseed:
            let next: MyceliumArchitectArrangement = try Self.changed(level, arrangement, by: action)
            guard actionsSpent < level.budget else { throw .budget }
            undoStack.append(moment)
            arrangement = next
            actionsSpent += 1
            report = MyceliumArchitectGrowth.report(level, arrangement: next)
        case .run:
            undoStack.append(moment)
            if let refused = report.failure {
                stage = .failed
                failure = refused
            } else {
                stage = .won
            }
        }
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, previous: before)
    }

    /// Restores the moment before the latest arrangement action or run (arrangement, actions spent, report, failure)
    /// and records the undo; from `failed` the play returns to `playing` with the arrangement before the run.
    ///
    /// - Throws: `.stage` outside `playing` and `failed` (a won run is final; nothing is undone while paused);
    ///   `.action("undo")` when nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(MyceliumArchitectError) {
        guard stage == .playing || stage == .failed else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier)
        append(kind: .undo, action: nil, previous: before)
    }

    /// Restores the moment of the latest undone arrangement action or run and records the redo (a redone run ends the
    /// level again with the same outcome).
    ///
    /// - Throws: `.stage` outside `playing`; `.action("redo")` when nothing was undone. A refused redo leaves the play
    ///   unchanged.
    public mutating func redo() throws(MyceliumArchitectError) {
        guard stage == .playing else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later)
        append(kind: .redo, action: nil, previous: before)
    }

    /// Replays a record trace on a new play of `level` (stage `loading`): each record by kind (an event, an
    /// arrangement action or run with the record's previous fingerprint, an undo or a redo). The chain must start at
    /// the initial fingerprint and link every next to the following previous, and every produced record must equal the
    /// given one, so the trace reproduces every fingerprint and the outcome.
    ///
    /// - Throws: `.malformed("schema <i>")`, `.malformed("seed <i>")` or `.malformed("index <i>")` when record `i` has
    ///   another schema, level seed or position; `.malformed("chain <i>")` when record `i`'s previous fingerprint is
    ///   not the replayed play's (a trace of another level breaks the chain at record 0); `.malformed("record <i>")`
    ///   when record `i` lacks its action, names an action of another kind, carries an action it should not or is not
    ///   reproduced; any refusal of the replayed action.
    public static func replay(level: MyceliumArchitectLevel,
                              records: [MyceliumArchitectRecord]) throws(MyceliumArchitectError)
        -> MyceliumArchitectPlay {
        var play = MyceliumArchitectPlay(level: level)
        for index in records.indices {
            let record: MyceliumArchitectRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.levelSeed == level.seed else { throw .malformed("seed \(index)") }
            guard record.index == index else { throw .malformed("index \(index)") }
            guard record.previous == play.fingerprint else { throw .malformed("chain \(index)") }
            switch record.kind {
            case .nutrient, .blocker, .clear, .seed, .unseed, .run:
                guard let action = record.action, kind(of: action) == record.kind else {
                    throw .malformed("record \(index)")
                }
                try play.apply(action, expecting: record.previous)
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume, .showResult:
                guard record.action == nil else { throw .malformed("record \(index)") }
                switch record.kind {
                case .undo: try play.undo()
                case .redo: try play.redo()
                case .begin: try play.handle(.begin)
                case .dismissTutorial: try play.handle(.dismissTutorial)
                case .pause: try play.handle(.pause)
                case .resume: try play.handle(.resume)
                default: try play.handle(.showResult)
                }
            }
            guard play.records.count == index + 1, play.records[index] == record else {
                throw .malformed("record \(index)")
            }
        }
        return play
    }

    /// The current moment.
    private var moment: Snapshot {
        Snapshot(stage: stage, arrangement: arrangement, actionsSpent: actionsSpent, report: report, failure: failure)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `playing`; a won or failed moment (a redone run)
    /// keeps its stage.
    private mutating func restore(_ snapshot: Snapshot) {
        arrangement = snapshot.arrangement
        actionsSpent = snapshot.actionsSpent
        report = snapshot.report
        failure = snapshot.failure
        stage = (snapshot.stage == .won || snapshot.stage == .failed) ? snapshot.stage : .playing
    }

    /// Appends the record of an accepted action or event; its next fingerprint is taken after the stage change.
    private mutating func append(kind: MyceliumArchitectRecord.Kind, action: MyceliumArchitectAction?,
                                 previous: String) {
        let record = MyceliumArchitectRecord(schema: Self.schema, levelSeed: level.seed, index: records.count,
                                             kind: kind, action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
