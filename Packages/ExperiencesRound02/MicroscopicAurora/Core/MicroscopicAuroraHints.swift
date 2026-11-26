// MicroscopicAuroraHints — feature 485 (R02-G19-05) T-R02G1905-002 (FR-R02G1905-002, 003; SC-R02G1905-002, 003;
// clarifications Q1, Q5; research R1 … R3). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failed swim.
//
// While a play is `playing`, the plan is empty when the current wells already win (the play's report wins); otherwise
// it is a shortest completion from the play's current wells within min(actions left, 2) actions, found by a bounded
// search over the sets of wells. An action places a well on a level site no other well holds (into the first free
// slot, or replacing a slot's well, never equal to the slot's well) or takes a slot's well away. One action is tried
// before two. At each step the candidate actions are ordered: the certified plan's next placement first while the
// current wells are a subset of the certified wells (the first certified well not yet placed, into the first free
// slot), then removals by slot, then placements by slot (the first free slot, or replacing an occupied slot), site
// index, strength 1 … 4 and sense (clockwise first). Each reached set is judged with
// `MicroscopicAuroraDish.report(level, wells:)` on the compacted wells (a report depends only on the set of wells), a
// set already judged (or the current set) is not judged again, and the work is the number of sets judged, bounded at
// 1,200. The plan is nil when no winning set is found within those actions or the bound would be exceeded. Exact
// hints from a level's start therefore replay the certified plan: the certified wells win, and every smaller set was
// judged and lost when the level was certified.
//
// The first action of the plan is the hint: level 1 names the site or the well ("Use the site at row r, column c next"
// or "Take well n away"), level 2 adds the sense ("Place a clockwise well at the site at row r, column c" or
// "counterclockwise"), level 3 the exact well ("Place well n at row r, column c with strength s, turning clockwise" or
// "counterclockwise"; "Take well n away"), wells numbered by slot from 1. With an empty plan the hint is the play ("The
// trails already cover the stencil as one pattern: play the swim"); with no plan it is `stuck`. A failed play (or one
// in `result` after a failure) gets the advice to undo or retry; loading, tutorial, paused, won and `result` after a
// win have no hint. Hints never change a play, are unlimited and do not affect stars; the hint level is presentation.
//
// The failure explanation numbers swimmers from 1 (swimmer s is the swimmer with 0-based index s − 1), names cells in
// the level's words ("the cell at row r, column c") and the level's required coherence ("the n needed"); the sentence
// and the advice are joined by one space. Integers and strings only; no clock, no random source. Modelled on
// `ApsidesWorkshopHints` (feature 475).
import Foundation

/// The plan of a play from its current wells (clarification Q1): a shortest completion's placements and removals. The
/// first action is the hint; an empty plan means the current wells already win.
public struct MicroscopicAuroraHintPlan: Sendable, Equatable {
    /// The placements and removals in order; the play is not part of it.
    public let actions: [MicroscopicAuroraAction]

    /// A plan of the given actions (not checked).
    public init(actions: [MicroscopicAuroraAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum MicroscopicAuroraHintKind: String, Sendable, Codable {
    /// Place a well (into the first free slot, or replacing a slot's well).
    case place
    /// Take a slot's well away.
    case remove
    /// The trails already cover the stencil as one pattern: play the swim.
    case play
    /// No way to win fits in the actions left (or the swim failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct MicroscopicAuroraHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the site or the well, 2 adds the sense, 3 the exact well.
    public let level: Int
    /// What the hint suggests.
    public let kind: MicroscopicAuroraHintKind
    /// The suggested action: a placement for `place`, a removal for `remove`, `.play` for `play`, nil for `stuck`.
    public let action: MicroscopicAuroraAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current wells already win, at every level.
    public static let playText: String = "The trails already cover the stencil as one pattern: play the swim"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: MicroscopicAuroraHintKind, action: MicroscopicAuroraAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// The text of a placement or removal hint at `level` (clamped to 1 … 3); nil for the play.
    /// - `.place(slot, well)`: level 1 "Use the site at row r, column c next"; level 2 "Place a clockwise well at the
    ///   site at row r, column c" (or "counterclockwise"); level 3 "Place well n at row r, column c with strength s,
    ///   turning clockwise" (or "counterclockwise"), n = slot + 1.
    /// - `.remove(slot)`: "Take well n away" at every level, n = slot + 1.
    public static func actionText(level: Int, action: MicroscopicAuroraAction) -> String? {
        let clamped: Int = min(3, max(1, level))
        switch action {
        case .place(let slot, let well):
            let cell: String = MicroscopicAuroraLevel.cellWords(well.cell)
            if clamped == 1 { return "Use the site at " + cell + " next" }
            if clamped == 2 { return "Place a " + well.sense.rawValue + " well at the site at " + cell }
            return "Place well " + String(slot + 1) + " at " + cell + " with strength " + String(well.strength)
                + ", turning " + well.sense.rawValue
        case .remove(let slot):
            return "Take well " + String(slot + 1) + " away"
        case .play:
            return nil
        }
    }
}

/// The hint engine of Microscopic Aurora (clarification Q1).
public enum MicroscopicAuroraHints {
    /// The bound on sets judged per plan.
    public static let workBound: Int = 1_200

    /// The most actions a hint plan holds.
    static let maxActions: Int = 2

    /// The senses in search order (clockwise first).
    static let senses: [MicroscopicAuroraSense] = [.clockwise, .counterclockwise]

    /// The wells after `action` from `wells` (a placement sets its slot, a removal empties it, the play changes
    /// nothing).
    static func applied(_ action: MicroscopicAuroraAction,
                        to wells: [MicroscopicAuroraWell?]) -> [MicroscopicAuroraWell?] {
        var next: [MicroscopicAuroraWell?] = wells
        switch action {
        case .place(let slot, let well):
            next[slot] = well
        case .remove(let slot):
            next[slot] = nil
        case .play:
            break
        }
        return next
    }

    /// Whether placing `well` into `slot` is a hint action from `wells` on `level`: a slot in range, a strength in
    /// range, a cell the level allows (one of its sites), no other slot's well on the cell, and a well different from
    /// the slot's well.
    static func isPlacement(_ well: MicroscopicAuroraWell, slot: Int, wells: [MicroscopicAuroraWell?],
                            level: MicroscopicAuroraLevel) -> Bool {
        guard wells.indices.contains(slot), MicroscopicAuroraWell.strengths.contains(well.strength),
              level.allows(well.cell) else { return false }
        for other in wells.indices where other != slot {
            if let placed = wells[other], placed.cell == well.cell { return false }
        }
        return wells[slot] != well
    }

    /// The candidate actions from `wells` on `level`, in search order: the certified plan's next placement first
    /// while the placed wells are a subset of `certified` (the first certified well not yet placed, into the first
    /// free slot), then removals by slot, then placements by slot (the first free slot, or replacing an occupied
    /// slot), site index, strength 1 … 4 and sense (clockwise first). Without sites only the certified placement and
    /// the removals are candidates.
    static func candidates(_ wells: [MicroscopicAuroraWell?], level: MicroscopicAuroraLevel,
                           certified: [MicroscopicAuroraWell]?) -> [MicroscopicAuroraAction] {
        var result: [MicroscopicAuroraAction] = []
        var placed: [MicroscopicAuroraWell] = []
        for slot in wells.indices {
            if let well = wells[slot] { placed.append(well) }
        }
        var firstFree: Int? = nil
        for slot in wells.indices where wells[slot] == nil {
            firstFree = slot
            break
        }
        if let certified, let free = firstFree {
            var subset: Bool = true
            for well in placed where !certified.contains(well) {
                subset = false
                break
            }
            if subset {
                for well in certified where !placed.contains(well) {
                    if isPlacement(well, slot: free, wells: wells, level: level) {
                        result.append(.place(slot: free, well: well))
                    }
                    break
                }
            }
        }
        for slot in wells.indices where wells[slot] != nil {
            result.append(.remove(slot: slot))
        }
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        for slot in wells.indices {
            if wells[slot] == nil && slot != firstFree { continue }
            for site in sites {
                for strength in MicroscopicAuroraWell.strengths {
                    for sense in senses {
                        let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: site, strength: strength,
                                                                                sense: sense)
                        if isPlacement(well, slot: slot, wells: wells, level: level) {
                            result.append(.place(slot: slot, well: well))
                        }
                    }
                }
            }
        }
        return result
    }

    /// The plan of `play` while `playing`: empty when the current wells already win (the play's report wins); else
    /// the first shortest completion within `min(actions left, 2)` actions in the search order of
    /// ``candidates(_:level:certified:)``, each new set of wells judged once with
    /// ``MicroscopicAuroraDish/report(_:wells:)``. Nil in every other stage, when no winning set is reachable within
    /// those actions, and when more than `workBound` sets would be judged. The play is not changed.
    public static func plan(_ play: MicroscopicAuroraPlay, certified: [MicroscopicAuroraWell]?,
                            workBound: Int = workBound) -> MicroscopicAuroraHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.report.wins { return MicroscopicAuroraHintPlan(actions: []) }
        let cap: Int = min(maxActions, play.actionsLeft)
        guard cap >= 1 else { return nil }
        let level: MicroscopicAuroraLevel = play.level
        var seen: Set<Set<MicroscopicAuroraWell>> = [Set(play.placedWells)]
        var work: Int = 0
        let firsts: [MicroscopicAuroraAction] = candidates(play.wells, level: level, certified: certified)
        for first in firsts {
            let next: [MicroscopicAuroraWell?] = applied(first, to: play.wells)
            let wells: [MicroscopicAuroraWell] = next.compactMap { $0 }
            let key: Set<MicroscopicAuroraWell> = Set(wells)
            if seen.contains(key) { continue }
            guard work < workBound else { return nil }
            work += 1
            seen.insert(key)
            if MicroscopicAuroraDish.report(level, wells: wells).wins {
                return MicroscopicAuroraHintPlan(actions: [first])
            }
        }
        guard cap >= 2 else { return nil }
        for first in firsts {
            let middle: [MicroscopicAuroraWell?] = applied(first, to: play.wells)
            for second in candidates(middle, level: level, certified: certified) {
                let next: [MicroscopicAuroraWell?] = applied(second, to: middle)
                let wells: [MicroscopicAuroraWell] = next.compactMap { $0 }
                let key: Set<MicroscopicAuroraWell> = Set(wells)
                if seen.contains(key) { continue }
                guard work < workBound else { return nil }
                work += 1
                seen.insert(key)
                if MicroscopicAuroraDish.report(level, wells: wells).wins {
                    return MicroscopicAuroraHintPlan(actions: [first, second])
                }
            }
        }
        return nil
    }

    /// The hint of `level` (clamped to 1 … 3) for `play` with the certified wells `certified`: while `playing`,
    /// `play` with ``MicroscopicAuroraHint/playText`` when the plan is empty, the plan's first action (`place` or
    /// `remove`, text per ``MicroscopicAuroraHint/actionText(level:action:)``), or `stuck` with
    /// ``MicroscopicAuroraHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure), `stuck`
    /// with ``MicroscopicAuroraHint/failedText``; nil in every other stage (loading, tutorial, paused, won, result
    /// after a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: MicroscopicAuroraPlay,
                            certified: [MicroscopicAuroraWell]?) -> MicroscopicAuroraHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return MicroscopicAuroraHint(level: level, kind: .stuck, action: nil,
                                         text: MicroscopicAuroraHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return MicroscopicAuroraHint(level: level, kind: .stuck, action: nil,
                                         text: MicroscopicAuroraHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let found = plan(play, certified: certified) else {
            return MicroscopicAuroraHint(level: level, kind: .stuck, action: nil,
                                         text: MicroscopicAuroraHint.stuckText)
        }
        guard let first = found.actions.first else {
            return MicroscopicAuroraHint(level: level, kind: .play, action: .play,
                                         text: MicroscopicAuroraHint.playText)
        }
        guard let text = MicroscopicAuroraHint.actionText(level: level, action: first) else {
            return MicroscopicAuroraHint(level: level, kind: .stuck, action: nil,
                                         text: MicroscopicAuroraHint.stuckText)
        }
        let kind: MicroscopicAuroraHintKind
        switch first {
        case .remove: kind = .remove
        default: kind = .place
        }
        return MicroscopicAuroraHint(level: level, kind: kind, action: first, text: text)
    }
}

/// The plain-English explanation of a failed swim (FR-R02G1905-003; clarification Q5), from the play's failure.
public struct MicroscopicAuroraFailureExplanation: Sendable, Equatable {
    /// Why the swim failed.
    public let failure: MicroscopicAuroraFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With s
    /// the swimmer's number (its index + 1), n the level's required coherence and cells in the level's words:
    /// - exit: "Swimmer s left the dish at tick t."
    /// - coherence: "The swarm split at tick t: its largest group had g swimmers, fewer than the n needed."
    /// - coverage: "Only l stencil cells were lit; n were needed."
    /// - connectedness: "The cell at row r, column c is lit but not joined to the pattern."
    /// each followed by a space and ``advice``. Nil when the failure names a swimmer the level lacks.
    public init?(play: MicroscopicAuroraPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: MicroscopicAuroraLevel = play.level
        let sentence: String
        switch failure {
        case .exit(let swimmer, let tick):
            guard level.swimmers.indices.contains(swimmer) else { return nil }
            sentence = "Swimmer " + String(swimmer + 1) + " left the dish at tick " + String(tick) + "."
        case .coherence(let tick, let group):
            sentence = "The swarm split at tick " + String(tick) + ": its largest group had " + String(group)
                + " swimmers, fewer than the " + String(level.coherence) + " needed."
        case .coverage(let lit, let needed):
            sentence = "Only " + String(lit) + " stencil cells were lit; " + String(needed) + " were needed."
        case .connectedness(let cell):
            sentence = "The cell at " + MicroscopicAuroraLevel.cellWords(cell)
                + " is lit but not joined to the pattern."
        }
        self.failure = failure
        text = sentence + " " + Self.advice
    }
}
