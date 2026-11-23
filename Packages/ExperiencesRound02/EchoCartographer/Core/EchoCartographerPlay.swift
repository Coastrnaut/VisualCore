// EchoCartographerPlay — feature 401 (R02-G11-01) T-R02G1101-004 (FR-R02G1101-002 … 008, 013, 014; SC-R02G1101-001,
// 002, 004; clarifications Q2, Q3, Q4, Q5). One play of an Echo Cartographer level: the life stage, what the player
// knows of the chamber, the markers, the located beacons with their claim cells, the energy left, the last echo, the
// failure, the append-only records and the undo and redo stacks. An action is validated in this order — stage, previous
// fingerprint, action (a cell outside the chamber, a pulse from a cell not known open, a claim on a known wall, a ninth
// marker), no-op (a claim within the tolerance only of located beacons) — and refused without any change, or applied
// and recorded. A pulse spends 1 energy and reveals its rays' cells; a claim that locates a beacon is free and makes the
// beacon's cell known open; a miss spends the miss cost (never more than the energy left) and reveals nothing; a marker
// toggles for free and never decides anything. After an accepted action the win is judged first (every beacon located:
// won, even with no energy left), then the energy (none left with a beacon hidden: failed with `energy(index)`, the
// 0-based index of the action). Every accepted action can be undone and redone exactly (snapshots); a new action clears
// the redo stack. Undo works in playing, paused and failed (a failed play returns to playing, an honest retry that is
// recorded); a won play is final. A record trace replays to the same records, fingerprints and outcome. The truth metric
// (each located beacon's localization error and their total) is reported after every action and never decides the
// outcome. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// Why a play failed.
public enum EchoCartographerFailure: Sendable, Hashable, Codable {
    /// The action with this 0-based index left no energy with a beacon still hidden.
    case energy(Int)

    /// The stable failure code: `energy`.
    public var code: String {
        switch self {
        case .energy: "energy"
        }
    }
}

/// An action on the chamber; the values are the column and the row of the cell.
public enum EchoCartographerAction: Sendable, Hashable, Codable {
    /// Emits a pulse from the cell (which must be known open); costs 1 energy.
    case pulse(Int, Int)
    /// Claims a beacon at the cell (not a known wall); free on a hit, the miss cost on a miss.
    case claim(Int, Int)
    /// Toggles a marker on the cell (at most 8 markers); free; never decides anything.
    case mark(Int, Int)

    /// The cell the action names.
    public var cell: EchoCartographerCell {
        switch self {
        case let .pulse(x, y), let .claim(x, y), let .mark(x, y): EchoCartographerCell(x: x, y: y)
        }
    }

    /// The record kind of the action.
    public var kind: EchoCartographerRecordKind {
        switch self {
        case .pulse: .pulse
        case .claim: .claim
        case .mark: .mark
        }
    }
}

/// The life stage of a play.
public enum EchoCartographerStage: String, Sendable, Codable, CaseIterable {
    /// The level is loading; `begin` starts it.
    case loading
    /// The tutorial is shown; `dismissTutorial` starts play.
    case tutorial
    /// Actions, undo and redo are accepted.
    case playing
    /// Play is paused; `resume` continues it; undo and redo are still accepted.
    case paused
    /// Every beacon is located; `showResult` shows the result. Final: undo is refused.
    case won
    /// The energy ran out with a beacon hidden; undo returns to playing, `showResult` shows the result.
    case failed
    /// The result is shown; the play is over.
    case result
}

/// An event that moves a play between life stages.
public enum EchoCartographerEvent: Sendable, Equatable {
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
public enum EchoCartographerRecordKind: String, Sendable, Codable {
    /// A pulse emitted.
    case pulse
    /// A claim made (hit or miss).
    case claim
    /// A marker toggled.
    case mark
    /// An undo of the latest action.
    case undo
    /// A redo of the latest undone action.
    case redo
}

/// The append-only record of one accepted action.
public struct EchoCartographerRecord: Sendable, Equatable, Codable {
    /// The record schema (``EchoCartographerPlay/schema``).
    public let schema: Int
    /// The level's seed.
    public let seed: UInt64
    /// The actions accepted before this one (the 0-based action index).
    public let index: Int
    /// The kind of action.
    public let kind: EchoCartographerRecordKind
    /// The action applied; nil for an undo or a redo.
    public let action: EchoCartographerAction?
    /// The play fingerprint before the action.
    public let previous: String
    /// The play fingerprint after the action (and its stage change).
    public let next: String

    /// A record of the given values.
    public init(schema: Int, seed: UInt64, index: Int, kind: EchoCartographerRecordKind,
                action: EchoCartographerAction?, previous: String, next: String) {
        self.schema = schema
        self.seed = seed
        self.index = index
        self.kind = kind
        self.action = action
        self.previous = previous
        self.next = next
    }
}

/// One play of an Echo Cartographer level.
public struct EchoCartographerPlay: Sendable, Equatable {
    /// The play and record schema.
    public static var schema: Int { 1 }

    /// A restorable moment of the play, held by the undo and redo stacks.
    struct Snapshot: Sendable, Equatable {
        /// The life stage.
        let stage: EchoCartographerStage
        /// The knowledge.
        let knowledge: EchoCartographerKnowledge
        /// The markers.
        let markers: [EchoCartographerCell]
        /// The located beacons.
        let located: [Int: EchoCartographerCell]
        /// The energy left.
        let energy: Int
        /// The last echo.
        let lastEcho: EchoCartographerEcho?
        /// The failure, or nil.
        let failure: EchoCartographerFailure?
        /// The actions accepted.
        let moves: Int
    }

    /// The level played.
    public let level: EchoCartographerLevel
    /// The life stage.
    public private(set) var stage: EchoCartographerStage
    /// What the player knows of each cell.
    public private(set) var knowledge: EchoCartographerKnowledge
    /// The marked cells, in cell-index order (at most ``EchoCartographerLevel/maximumMarkers``).
    public private(set) var markers: [EchoCartographerCell]
    /// The located beacons: beacon index (in ``EchoCartographerLevel/beacons``) → the cell of the claim that located it.
    public private(set) var located: [Int: EchoCartographerCell]
    /// The energy left.
    public private(set) var energy: Int
    /// The report of the latest pulse, or nil before the first.
    public private(set) var lastEcho: EchoCartographerEcho?
    /// Why the play failed, or nil.
    public private(set) var failure: EchoCartographerFailure?
    /// The append-only records of every accepted action.
    public private(set) var records: [EchoCartographerRecord]
    /// The pulses, claims and marks accepted (restored by undo and redo); the next action's 0-based index.
    private(set) var moves: Int
    /// Moments that undo can restore, latest last.
    private(set) var undoStack: [Snapshot]
    /// Moments that redo can restore, latest last.
    private(set) var redoStack: [Snapshot]

    /// A play of `level` in stage `loading`: only the entry known open, no marker, no beacon located, the full energy.
    public init(level: EchoCartographerLevel) {
        self.level = level
        stage = .loading
        knowledge = level.openingKnowledge
        markers = []
        located = [:]
        energy = level.energy
        lastEcho = nil
        failure = nil
        records = []
        moves = 0
        undoStack = []
        redoStack = []
    }

    /// The truth metric: for each located beacon in beacon-index order, the distance (the larger of the column and
    /// row differences) between its claim and the beacon. It never decides the outcome.
    public var localizationErrors: [Int] {
        var errors: [Int] = []
        for index in located.keys.sorted() {
            if let claim = located[index] { errors.append(claim.distance(to: level.beacons[index])) }
        }
        return errors
    }

    /// The sum of ``localizationErrors``.
    public var totalLocalizationError: Int {
        var total: Int = 0
        for error in localizationErrors { total += error }
        return total
    }

    /// The progress in words: "1 of 3 beacons located, 7 energy left".
    public var progressDescription: String {
        level.progressDescription(located: located.count, energy: energy)
    }

    /// Whether ``undo()`` would be accepted.
    public var canUndo: Bool { [.playing, .paused, .failed].contains(stage) && !undoStack.isEmpty }

    /// Whether ``redo()`` would be accepted.
    public var canRedo: Bool { [.playing, .paused].contains(stage) && !redoStack.isEmpty }

    /// The SHA-256 hex (``StableHash``) of the canonical JSON with sorted keys and no whitespace:
    /// `{"energy":<n>,"failure":"<f>","knowledge":"<k>","level":"<level fingerprint>","located":[[<beacon>,<claim
    /// cell index>],…],"markers":[<cell index>,…],"schema":1,"stage":"<stage>"}`, where the failure is `"none"` or
    /// `"energy <index>"`, the knowledge one letter per cell in cell-index order (`u` unknown, `o` open, `w` wall), the
    /// located beacons sorted by beacon index and the markers in cell-index order.
    public var fingerprint: String {
        let failureText: String
        switch failure {
        case .energy(let index): failureText = "energy " + String(index)
        case nil: failureText = "none"
        }
        var knowledgeText: String = ""
        for known in knowledge.cells {
            switch known {
            case .unknown: knowledgeText += "u"
            case .open: knowledgeText += "o"
            case .wall: knowledgeText += "w"
            }
        }
        var locatedText: String = ""
        for (position, index) in located.keys.sorted().enumerated() {
            guard let claim = located[index] else { continue }
            if position > 0 { locatedText += "," }
            locatedText += "[" + String(index) + "," + String(level.chamber.index(claim)) + "]"
        }
        var markersText: String = ""
        for (position, marker) in markers.enumerated() {
            if position > 0 { markersText += "," }
            markersText += String(level.chamber.index(marker))
        }
        let text: String = "{\"energy\":" + String(energy) + ",\"failure\":\"" + failureText + "\",\"knowledge\":\""
            + knowledgeText + "\",\"level\":\"" + level.fingerprint + "\",\"located\":[" + locatedText
            + "],\"markers\":[" + markersText + "],\"schema\":" + String(Self.schema) + ",\"stage\":\""
            + stage.rawValue + "\"}"
        return StableHash.sha256Hex(Array(text.utf8))
    }

    /// Moves between life stages: `loading` --begin--> `tutorial` (when the level asks for one) or `playing`;
    /// `tutorial` --dismissTutorial--> `playing`; `playing` --pause--> `paused` --resume--> `playing`; `won` or
    /// `failed` --showResult--> `result`.
    ///
    /// - Throws: `.stage` for any other event in a stage; the play is then unchanged.
    public mutating func handle(_ event: EchoCartographerEvent) throws(EchoCartographerError) {
        switch (stage, event) {
        case (.loading, .begin): stage = level.tutorial ? .tutorial : .playing
        case (.tutorial, .dismissTutorial): stage = .playing
        case (.playing, .pause): stage = .paused
        case (.paused, .resume): stage = .playing
        case (.won, .showResult), (.failed, .showResult): stage = .result
        default: throw .stage
        }
    }

    /// Checks `action` against the chamber, the knowledge and the markers.
    ///
    /// - Throws: `.action("cell")` for a cell outside the chamber; `.action("pulse")` for a pulse from a cell not
    ///   known open; `.action("claim")` for a claim on a known wall; `.action("marker")` for a mark that would make a
    ///   ninth marker.
    func check(_ action: EchoCartographerAction) throws(EchoCartographerError) {
        let cell: EchoCartographerCell = action.cell
        guard level.chamber.isInside(cell) else { throw .action("cell") }
        switch action {
        case .pulse:
            guard knowledge[cell] == .open else { throw .action("pulse") }
        case .claim:
            guard knowledge[cell] != .wall else { throw .action("claim") }
        case .mark:
            guard markers.contains(cell) || markers.count < EchoCartographerLevel.maximumMarkers else {
                throw .action("marker")
            }
        }
    }

    /// Applies an action that names the current fingerprint as its previous one: a pulse (1 energy; reveals its
    /// rays), a claim (a hit locates the beacon and makes its cell known open; a miss spends min(miss cost, energy))
    /// or a mark (toggles the marker); then judges the win, then the energy, and records it.
    ///
    /// - Throws: `.stage` outside `playing`; `.stale` when `previous` is not ``fingerprint``; `.action(name)` per
    ///   ``check(_:)``; `.noop` for a claim within the tolerance only of located beacons. A refused action spends
    ///   nothing, records nothing and leaves the play unchanged.
    public mutating func apply(_ action: EchoCartographerAction,
                               expecting previous: String) throws(EchoCartographerError) {
        guard stage == .playing else { throw .stage }
        let before: String = fingerprint
        guard previous == before else { throw .stale }
        try check(action)
        let cell: EchoCartographerCell = action.cell
        var claimResult: EchoCartographerClaimResult? = nil
        if case .claim = action {
            let result: EchoCartographerClaimResult = level.claim(cell, located: Set(located.keys))
            guard result != .alreadyLocated else { throw .noop }
            claimResult = result
        }
        let snapshot: Snapshot = moment
        let moveIndex: Int = moves
        switch action {
        case .pulse:
            let echo: EchoCartographerEcho = level.echo(from: cell)
            energy -= 1
            knowledge.reveal(echo)
            lastEcho = echo
        case .claim:
            if case .hit(let beacon) = claimResult {
                located[beacon] = cell
                knowledge.markOpen(level.beacons[beacon])
            } else {
                energy -= min(level.missCost, energy)
            }
        case .mark:
            if let position = markers.firstIndex(of: cell) {
                markers.remove(at: position)
            } else {
                markers.append(cell)
                markers.sort()
            }
        }
        moves += 1
        if located.count == level.beacons.count {
            stage = .won
        } else if energy == 0 {
            stage = .failed
            failure = .energy(moveIndex)
        }
        undoStack.append(snapshot)
        redoStack.removeAll()
        append(kind: action.kind, action: action, index: moveIndex, previous: before)
    }

    /// Restores the moment before the latest action (knowledge, markers, located beacons, energy, last echo, failure)
    /// and records the undo.
    ///
    /// - Throws: `.stage` outside `playing`, `paused` and `failed` (a won play is final); `.action("undo")` when
    ///   nothing can be undone. A refused undo leaves the play unchanged.
    public mutating func undo() throws(EchoCartographerError) {
        guard [.playing, .paused, .failed].contains(stage) else { throw .stage }
        guard let earlier = undoStack.last else { throw .action("undo") }
        let before: String = fingerprint
        let movesBefore: Int = moves
        let wasPaused: Bool = stage == .paused
        redoStack.append(moment)
        undoStack.removeLast()
        restore(earlier, paused: wasPaused)
        append(kind: .undo, action: nil, index: movesBefore, previous: before)
    }

    /// Restores the moment of the latest undone action and records the redo.
    ///
    /// - Throws: `.stage` outside `playing` and `paused`; `.action("redo")` when nothing was undone. A refused redo
    ///   leaves the play unchanged.
    public mutating func redo() throws(EchoCartographerError) {
        guard [.playing, .paused].contains(stage) else { throw .stage }
        guard let later = redoStack.last else { throw .action("redo") }
        let before: String = fingerprint
        let movesBefore: Int = moves
        let wasPaused: Bool = stage == .paused
        undoStack.append(moment)
        redoStack.removeLast()
        restore(later, paused: wasPaused)
        append(kind: .redo, action: nil, index: movesBefore, previous: before)
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
    public static func replay(level: EchoCartographerLevel,
                              records: [EchoCartographerRecord]) throws(EchoCartographerError) -> EchoCartographerPlay {
        var play = EchoCartographerPlay(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        for index in records.indices {
            let record: EchoCartographerRecord = records[index]
            guard record.schema == schema else { throw .malformed("schema \(index)") }
            guard record.seed == level.seed else { throw .malformed("seed \(index)") }
            if play.fingerprint != record.previous {
                var other: EchoCartographerPlay = play
                if other.stage == .playing {
                    try? other.handle(.pause)
                } else if other.stage == .paused {
                    try? other.handle(.resume)
                }
                guard other.fingerprint == record.previous else { throw .malformed("replay") }
                play = other
            }
            switch record.kind {
            case .pulse, .claim, .mark:
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
        Snapshot(stage: stage, knowledge: knowledge, markers: markers, located: located, energy: energy,
                 lastEcho: lastEcho, failure: failure, moves: moves)
    }

    /// Restores `snapshot`; a moment taken while playing comes back as `paused` when the play is paused, else as
    /// `playing`, except a failed moment, which stays failed.
    private mutating func restore(_ snapshot: Snapshot, paused: Bool) {
        knowledge = snapshot.knowledge
        markers = snapshot.markers
        located = snapshot.located
        energy = snapshot.energy
        lastEcho = snapshot.lastEcho
        failure = snapshot.failure
        moves = snapshot.moves
        if snapshot.stage == .failed {
            stage = .failed
        } else {
            stage = paused ? .paused : .playing
        }
    }

    /// Appends the record of an accepted action; its next fingerprint is taken after the stage change.
    private mutating func append(kind: EchoCartographerRecordKind, action: EchoCartographerAction?, index: Int,
                                 previous: String) {
        let record = EchoCartographerRecord(schema: Self.schema, seed: level.seed, index: index, kind: kind,
                                            action: action, previous: previous, next: fingerprint)
        records.append(record)
    }
}
