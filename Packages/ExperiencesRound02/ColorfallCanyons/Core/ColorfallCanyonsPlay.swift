// ColorfallCanyonsPlay — feature 341 (R02-G05-01) T-R02G0501-004 (FR-R02G0501-004 … 008; clarifications Q3, Q4, Q5).
// One play of a Colorfall Canyons level: the life stage, the fluid, the actions spent, the failure, the append-only
// records and the undo and redo stacks. An action is validated in this order — stage, previous fingerprint, range or
// carvability, budget — and refused without any change, or applied and recorded. A carve lowers one carvable cell and a
// valve toggles one spring, each spending one action; a step runs 1 … 600 ticks, spends nothing and stops at the first
// tick whose verdict decides the play. Every accepted action can be undone and redone exactly (snapshots); a new action
// clears the redo stack. Undo works in playing, paused and failed (a failed play returns to playing); a won play is
// final. A record trace replays to the same records, fingerprints and outcome.
import VisualCoreMath

/// A player action.
public enum ColorfallCanyonsAction: Sendable, Hashable, Codable {
    /// Lower the given cell by one height step.
    case carve(Int)
    /// Toggle the valve of the given spring.
    case valve(Int)
    /// Run the given number of ticks, 1 … 600.
    case step(Int)
}

/// The life stage of a play.
public enum ColorfallCanyonsStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Carves, valves, steps, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// Every target basin was met; `showResult` shows the result.
    case won
    /// The play failed; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum ColorfallCanyonsEvent: Sendable, Equatable {
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
public enum ColorfallCanyonsRecordKind: String, Sendable, Codable {
    /// A carve.
    case carve
    /// A valve toggle.
    case valve
    /// A run of ticks.
    case step
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct ColorfallCanyonsRecord: Sendable, Equatable, Codable {
    /// The record schema (``ColorfallCanyonsPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The fluid tick before the action.
    public let tick: Int
    /// The kind of action.
    public let kind: ColorfallCanyonsRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: ColorfallCanyonsAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, tick: Int, kind: ColorfallCanyonsRecordKind, action: ColorfallCanyonsAction?,
                previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.tick = tick
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of a Colorfall Canyons level.
public struct ColorfallCanyonsPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }
    /// The ticks a single step may run.
    public static let steps: ClosedRange<Int> = 1...600

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        let stage: ColorfallCanyonsStage
        let fluid: ColorfallCanyonsFluid
        let spent: Int
        let failure: ColorfallCanyonsFailure?
    }

    /// The level played.
    public let level: ColorfallCanyonsLevel
    /// The life stage.
    public private(set) var stage: ColorfallCanyonsStage
    /// The fluid state.
    public private(set) var fluid: ColorfallCanyonsFluid
    /// The carves and valve toggles spent.
    public private(set) var spent: Int
    /// Why the play failed, or nil.
    public private(set) var failure: ColorfallCanyonsFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [ColorfallCanyonsRecord]
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading` with the level's starting fluid and nothing spent.
    public init(level: ColorfallCanyonsLevel) {
        self.level = level
        stage = .loading
        fluid = ColorfallCanyonsFluid(level: level)
        spent = 0
        failure = nil
        records = []
        undoStack = []
        redoStack = []
    }

    /// The SHA-256 hex (``StableHash``) of the bytes, in order: the schema (one byte); the level fingerprint (UTF-8); the
    /// tick (four bytes, big-endian); every height (one byte); every valve (one byte, 1 open); every supply left (two
    /// bytes); every cell's three colour masses (two bytes each); the three spilled amounts (two bytes each); the actions
    /// spent (one byte); the stage's raw value (UTF-8); a zero byte and the failure's raw value when there is one.
    public var fingerprint: String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: Self.schema)]
        bytes.append(contentsOf: Array(level.fingerprint.utf8))
        for shift in [24, 16, 8, 0] { bytes.append(UInt8(truncatingIfNeeded: fluid.tick >> shift)) }
        for h in fluid.heights { bytes.append(UInt8(truncatingIfNeeded: h)) }
        for v in fluid.valves { bytes.append(v ? 1 : 0) }
        func two(_ value: Int) {
            bytes.append(UInt8(truncatingIfNeeded: value >> 8))
            bytes.append(UInt8(truncatingIfNeeded: value))
        }
        for s in fluid.supplies { two(s) }
        for cell in fluid.masses { for m in cell { two(m) } }
        for s in fluid.spilled { two(s) }
        bytes.append(UInt8(truncatingIfNeeded: spent))
        bytes.append(contentsOf: Array(stage.rawValue.utf8))
        if let failure {
            bytes.append(0)
            bytes.append(contentsOf: Array(failure.rawValue.utf8))
        }
        return StableHash.sha256Hex(bytes)
    }

    /// The carves and valve toggles left.
    public var remaining: Int { level.budget - spent }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or `failed`
    /// --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: ColorfallCanyonsEvent) throws(ColorfallCanyonsError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Whether `action`'s operands are in range for `level`: a carve of a cell index, a valve of a spring index, a step
    /// of 1 … 600 ticks.
    public static func inRange(_ action: ColorfallCanyonsAction, level: ColorfallCanyonsLevel) -> Bool {
        switch action {
        case .carve(let cell): (0..<level.cellCount).contains(cell)
        case .valve(let spring): level.springs.indices.contains(spring)
        case .step(let ticks): steps.contains(ticks)
        }
    }

    /// Applies an action that names the current fingerprint as its previous one and records it, with its verdict.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action("range")` for an
    ///   operand out of range; `.action("not-carvable")` for a carve of a cell that cannot be carved; `.budget` for a
    ///   carve or valve when nothing is left. A refused action leaves the play unchanged.
    public mutating func apply(_ action: ColorfallCanyonsAction,
                               expecting previous: String) throws(ColorfallCanyonsError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        guard Self.inRange(action, level: level) else { throw .action("range") }
        let snapshot: Snapshot = moment
        let tickBefore: Int = fluid.tick
        switch action {
        case .carve(let cell):
            guard level.isCarvable(cell, heights: fluid.heights) else { throw .action("not-carvable") }
            guard spent < level.budget else { throw .budget }
            spent += 1
            fluid.carve(cell)
        case .valve(let spring):
            guard spent < level.budget else { throw .budget }
            spent += 1
            fluid.toggle(spring)
        case .step(let ticks):
            for _ in 0..<ticks {
                fluid.tick(level: level)
                switch fluid.verdict(level: level) {
                case .running: continue
                case .won: stage = .won
                case .failed(let reason):
                    stage = .failed
                    failure = reason
                }
                break
            }
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: Self.kind(of: action), action: action, tick: tickBefore, previous: before)
    }

    /// Restores the moment before the latest action and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed`; `.action("nothing-to-undo")` when nothing can be
    ///   undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(ColorfallCanyonsError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("nothing-to-undo") }
        let before: String = fingerprint
        let tickBefore: Int = fluid.tick
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
    public mutating func redo() throws(ColorfallCanyonsError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("nothing-to-redo") }
        let before: String = fingerprint
        let tickBefore: Int = fluid.tick
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, tick: tickBefore, previous: before)
    }

    /// Replays a record trace on a new play of `level`: `begin` (and `dismissTutorial` when the level has a tutorial),
    /// then each record by kind (an action with the record's previous fingerprint, an undo or a redo). Every produced
    /// record must equal the given one, so the trace reproduces every fingerprint and the outcome. Pauses are not
    /// records, but the stage is part of every fingerprint: when a record's previous fingerprint is the current one with
    /// the play paused (an undo or redo made while paused) or resumed (an action after a paused undo), the replay pauses
    /// or resumes first.
    ///
    /// - Throws: any refusal of the replayed action; `.malformed("record <i>")` when record `i` is not reproduced.
    public static func replay(level: ColorfallCanyonsLevel,
                              records: [ColorfallCanyonsRecord]) throws(ColorfallCanyonsError) -> ColorfallCanyonsPlay {
        var play = ColorfallCanyonsPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: ColorfallCanyonsRecord = records[index]
            if play.fingerprint != record.previous {
                var other: ColorfallCanyonsPlay = play
                if other.stage == .playing { try? other.handle(.pause) } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                if other.fingerprint == record.previous { play = other }
            }
            switch record.kind {
            case .carve, .valve, .step:
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
    private var moment: Snapshot { Snapshot(stage: stage, fluid: fluid, spent: spent, failure: failure) }

    /// Restores `snapshot`; a moment taken while playing (or a failed one) comes back as `paused` when the play is
    /// paused, else as `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        fluid = snapshot.fluid
        spent = snapshot.spent
        failure = snapshot.failure
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// The record kind of an action.
    private static func kind(of action: ColorfallCanyonsAction) -> ColorfallCanyonsRecordKind {
        switch action {
        case .carve: .carve
        case .valve: .valve
        case .step: .step
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: ColorfallCanyonsRecordKind, action: ColorfallCanyonsAction?, tick: Int,
                                 previous: String) {
        let record = ColorfallCanyonsRecord(schema: Self.schema, seed: level.seed, tick: tick, kind: kind,
                                            action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
