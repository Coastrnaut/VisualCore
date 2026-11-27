// MushroomWeatherHints — feature 495 (R02-G20-05) T-R02G2005-002 (FR-R02G2005-002, 003; SC-R02G2005-002, 003;
// clarifications Q1, Q5; research R1 … R3). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failed run of the weather. T-R02G2005-004: the unstable explanation counts in the
// singular when a count is 1 ("only the last 1 cycle", "1 was needed").
//
// While a play is `playing`, the plan is empty when the current arrangement already wins (the play's report wins).
// Otherwise, while the current arrangement lies on the way to the certified arrangement — its pod cells a subset of the
// certified pod cells, its toggled vents (against the level's start) a subset of the certified toggled vents, and its
// moonlight the start's or the certified one — and the actions left cover the certified actions still to do, the plan
// is those remaining certified actions in the certified order: a placement whose cell a pod already holds, a vent
// already in the certified state and a moonlight already at the certified level count as done; a remaining placement
// goes into the first free slot (the slot the certified plan used may hold another of its pods). Exact hints from a
// level's start therefore replay its certified witness, of up to 5 actions, with no search at all.
//
// Otherwise a bounded search from the current arrangement looks for a winning arrangement within
// min(actions left, 2) actions. An action takes a slot's pod away, moves a slot's pod to a free site, places a pod on a
// free site into the first free slot, toggles a vent or sets another moonlight level; at each step the candidates are
// ordered: removals by slot, then moves and placements by slot (occupied slots move, the first free slot places) and
// site, then vents by index, then moonlight levels ascending. One action is tried before two. Each reached arrangement
// is judged with `MushroomWeatherForest.report(level, arrangement:)` (a report's verdict depends only on the set of pod
// cells, the vents' states and the moonlight), an arrangement already judged (or the current one) is not judged again,
// and the work is the number of arrangements judged, bounded at 1,500. The plan is nil when no winning arrangement is
// found within those actions or the bound would be exceeded.
//
// The first action of the plan is the hint: level 1 names the kind of change ("Change a spore pod", "Change a vent" or
// "Change the moonlight"), level 2 adds where ("Use the site at row r, column c", "Take pod n away", "Use vent n",
// "Make the moonlight brighter" or "dimmer"), level 3 the exact action ("Put pod n on the site at row r, column c",
// "Move pod n to the site at row r, column c", "Take pod n away", "Open vent n" or "Close vent n", "Set the moonlight
// to level l"), pods and vents numbered from 1 (slot + 1, index + 1) and cells in the level's words. With an empty plan
// the hint is the run ("Every colony stays in its band: run the weather"); with no plan it is `stuck`. A failed play
// (or one in `result` after a failure) gets the advice to undo or retry; loading, tutorial, paused, won and `result`
// after a win have no hint. Hints never change a play, are unlimited and do not affect stars; the hint level is
// presentation.
//
// The failure explanation numbers colonies from 1 (colony n is the colony with 0-based index n − 1), names cells in the
// level's words ("the cell at row r, column c") and the level's required final run ("k were needed"); the sentence and
// the advice are joined by one space. Integers and strings only; no clock, no random source. Modelled on
// `MicroscopicAuroraHints` (feature 485).
import Foundation

/// The plan of a play from its current arrangement (clarification Q1): the certified actions still to do, or a
/// shortest completion's pod, vent and moonlight actions. The first action is the hint; an empty plan means the
/// current arrangement already wins.
public struct MushroomWeatherHintPlan: Sendable, Equatable {
    /// The arrangement actions in order; the run is not part of it.
    public let actions: [MushroomWeatherAction]

    /// A plan of the given actions (not checked).
    public init(actions: [MushroomWeatherAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum MushroomWeatherHintKind: String, Sendable, Codable {
    /// Place, move or take away a spore pod.
    case pod
    /// Open or close a vent.
    case vent
    /// Set another moonlight level.
    case moonlight
    /// Every colony stays in its band: run the weather.
    case run
    /// No way to win was found in the actions left (or the run failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct MushroomWeatherHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind of change, 2 adds where, 3 the exact action.
    public let level: Int
    /// What the hint suggests.
    public let kind: MushroomWeatherHintKind
    /// The suggested action: a pod, vent or moonlight action, `.run` for `run`, nil for `stuck`.
    public let action: MushroomWeatherAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current arrangement already wins, at every level.
    public static let runText: String = "Every colony stays in its band: run the weather"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: MushroomWeatherHintKind, action: MushroomWeatherAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// The kind of `action`: `pod` for a placement or removal, `vent`, `moonlight`, or `run`.
    public static func kind(of action: MushroomWeatherAction) -> MushroomWeatherHintKind {
        switch action {
        case .place, .remove: .pod
        case .vent: .vent
        case .moonlight: .moonlight
        case .run: .run
        }
    }

    /// The text of a pod, vent or moonlight hint at `level` (clamped to 1 … 3) from `arrangement` (the arrangement the
    /// action would change); nil for the run. With n = slot + 1 for a pod, n = index + 1 for a vent and cells in the
    /// level's words:
    /// - `.place(slot, cell)` into an empty slot: "Change a spore pod"; "Use the site at row r, column c"; "Put pod n
    ///   on the site at row r, column c".
    /// - `.place(slot, cell)` into an occupied slot (a move): "Change a spore pod"; "Use the site at row r, column c";
    ///   "Move pod n to the site at row r, column c".
    /// - `.remove(slot)`: "Change a spore pod"; "Take pod n away"; "Take pod n away".
    /// - `.vent(index, open)`: "Change a vent"; "Use vent n"; "Open vent n" (or "Close vent n").
    /// - `.moonlight(l)`: "Change the moonlight"; "Make the moonlight brighter" (l above the current level) or "Make
    ///   the moonlight dimmer"; "Set the moonlight to level l".
    public static func actionText(level: Int, action: MushroomWeatherAction,
                                  arrangement: MushroomWeatherArrangement) -> String? {
        let clamped: Int = min(3, max(1, level))
        switch action {
        case .place(let slot, let cell):
            if clamped == 1 { return "Change a spore pod" }
            let words: String = MushroomWeatherLevel.cellWords(cell)
            if clamped == 2 { return "Use the site at " + words }
            var occupied: Bool = false
            if arrangement.pods.indices.contains(slot), arrangement.pods[slot] != nil { occupied = true }
            if occupied { return "Move pod " + String(slot + 1) + " to the site at " + words }
            return "Put pod " + String(slot + 1) + " on the site at " + words
        case .remove(let slot):
            if clamped == 1 { return "Change a spore pod" }
            return "Take pod " + String(slot + 1) + " away"
        case .vent(let index, let open):
            if clamped == 1 { return "Change a vent" }
            if clamped == 2 { return "Use vent " + String(index + 1) }
            return (open ? "Open vent " : "Close vent ") + String(index + 1)
        case .moonlight(let value):
            if clamped == 1 { return "Change the moonlight" }
            if clamped == 2 {
                return value > arrangement.moonlight ? "Make the moonlight brighter" : "Make the moonlight dimmer"
            }
            return "Set the moonlight to level " + String(value)
        case .run:
            return nil
        }
    }
}

/// The hint engine of Mushroom Weather (clarification Q1).
public enum MushroomWeatherHints {
    /// The bound on arrangements judged per plan.
    public static let workBound: Int = 1_500

    /// The most actions a searched plan holds.
    static let maxActions: Int = 2

    /// An arrangement as the judge sees it: the set of pod cells, the vents' states and the moonlight.
    struct Key: Hashable {
        /// The pod cells.
        let pods: Set<MushroomWeatherCell>
        /// Whether each vent is open.
        let vents: [Bool]
        /// The moonlight level.
        let moonlight: Int

        /// The key of `arrangement`.
        init(_ arrangement: MushroomWeatherArrangement) {
            pods = Set(arrangement.placedPods)
            vents = arrangement.ventsOpen
            moonlight = arrangement.moonlight
        }
    }

    /// The arrangement after `action` from `arrangement` (a placement sets its slot, a removal empties it, a vent is
    /// set, the moonlight is set, the run changes nothing). Unchecked.
    static func applied(_ action: MushroomWeatherAction,
                        to arrangement: MushroomWeatherArrangement) -> MushroomWeatherArrangement {
        var pods: [MushroomWeatherCell?] = arrangement.pods
        var vents: [Bool] = arrangement.ventsOpen
        var moonlight: Int = arrangement.moonlight
        switch action {
        case .place(let slot, let cell):
            pods[slot] = cell
        case .remove(let slot):
            pods[slot] = nil
        case .vent(let index, let open):
            vents[index] = open
        case .moonlight(let value):
            moonlight = value
        case .run:
            break
        }
        return MushroomWeatherArrangement(pods: pods, ventsOpen: vents, moonlight: moonlight)
    }

    /// The first empty slot of `pods`, or nil.
    static func firstFreeSlot(_ pods: [MushroomWeatherCell?]) -> Int? {
        for slot in pods.indices where pods[slot] == nil { return slot }
        return nil
    }

    /// The candidate actions from `arrangement` on `level`, in search order: removals by slot; then by slot, an
    /// occupied slot's moves and the first free slot's placements, each by site in the level's order onto sites no pod
    /// holds; then each vent toggled, by index; then every other moonlight level, ascending.
    static func candidates(_ arrangement: MushroomWeatherArrangement,
                           level: MushroomWeatherLevel) -> [MushroomWeatherAction] {
        var result: [MushroomWeatherAction] = []
        let pods: [MushroomWeatherCell?] = arrangement.pods
        for slot in pods.indices where pods[slot] != nil {
            result.append(.remove(slot: slot))
        }
        let held: Set<MushroomWeatherCell> = Set(arrangement.placedPods)
        let firstFree: Int? = firstFreeSlot(pods)
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        var sites: [MushroomWeatherCell] = []
        for site in level.sites ?? [] where !held.contains(site) && !colonies.contains(site) && level.isFloor(site) {
            sites.append(site)
        }
        for slot in pods.indices {
            if pods[slot] == nil && slot != firstFree { continue }
            for site in sites {
                result.append(.place(slot: slot, cell: site))
            }
        }
        for index in arrangement.ventsOpen.indices {
            result.append(.vent(index: index, open: !arrangement.ventsOpen[index]))
        }
        for value in MushroomWeatherLevel.moonlightLevels where value != arrangement.moonlight {
            result.append(.moonlight(level: value))
        }
        return result
    }

    /// The certified actions still to do from `arrangement` when it lies on the way to `certified`'s arrangement (its
    /// pod cells a subset of the certified ones, its toggled vents a subset of the certified toggled vents, its
    /// moonlight the start's or the certified one), in the certified order, a remaining placement put into the first
    /// free slot; nil when it does not lie on the way or the plan does not fit the level.
    static func remainingCertified(_ arrangement: MushroomWeatherArrangement, level: MushroomWeatherLevel,
                                   certified: MushroomWeatherPlan) -> [MushroomWeatherAction]? {
        let target: MushroomWeatherArrangement = certified.arrangement
        let start: MushroomWeatherArrangement = level.start
        guard target.pods.count == arrangement.pods.count, target.ventsOpen.count == arrangement.ventsOpen.count,
              start.ventsOpen.count == arrangement.ventsOpen.count else { return nil }
        let targetPods: Set<MushroomWeatherCell> = Set(target.placedPods)
        for cell in arrangement.placedPods where !targetPods.contains(cell) { return nil }
        for index in arrangement.ventsOpen.indices where arrangement.ventsOpen[index] != start.ventsOpen[index] {
            if target.ventsOpen[index] == start.ventsOpen[index] { return nil }
        }
        guard arrangement.moonlight == start.moonlight || arrangement.moonlight == target.moonlight else { return nil }
        var current: MushroomWeatherArrangement = arrangement
        var result: [MushroomWeatherAction] = []
        for action in certified.actions {
            switch action {
            case .place(_, let cell):
                if current.placedPods.contains(cell) { continue }
                guard let free = firstFreeSlot(current.pods) else { return nil }
                let step: MushroomWeatherAction = .place(slot: free, cell: cell)
                result.append(step)
                current = applied(step, to: current)
            case .remove:
                return nil
            case .vent(let index, let open):
                guard current.ventsOpen.indices.contains(index) else { return nil }
                if current.ventsOpen[index] == open { continue }
                result.append(action)
                current = applied(action, to: current)
            case .moonlight(let value):
                if current.moonlight == value { continue }
                result.append(action)
                current = applied(action, to: current)
            case .run:
                continue
            }
        }
        return result
    }

    /// The plan of `play` while `playing`: empty when the current arrangement already wins (the play's report wins);
    /// else the certified actions still to do (``remainingCertified(_:level:certified:)``) while the arrangement lies
    /// on the way to `certified`'s and the actions left cover them; else the first shortest completion within
    /// `min(actions left, 2)` actions in the search order of ``candidates(_:level:)``, each new arrangement judged once
    /// with ``MushroomWeatherForest/report(_:arrangement:)``. Nil in every other stage, when no winning arrangement is
    /// reachable within those actions, and when more than `workBound` arrangements would be judged. The play is not
    /// changed.
    public static func plan(_ play: MushroomWeatherPlay, certified: MushroomWeatherPlan?,
                            workBound: Int = workBound) -> MushroomWeatherHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.report.wins { return MushroomWeatherHintPlan(actions: []) }
        let level: MushroomWeatherLevel = play.level
        let current: MushroomWeatherArrangement = play.arrangement
        if let certified, let remaining = remainingCertified(current, level: level, certified: certified),
           !remaining.isEmpty, remaining.count <= play.actionsLeft {
            return MushroomWeatherHintPlan(actions: remaining)
        }
        let cap: Int = min(maxActions, play.actionsLeft)
        guard cap >= 1 else { return nil }
        var seen: Set<Key> = [Key(current)]
        var work: Int = 0
        let firsts: [MushroomWeatherAction] = candidates(current, level: level)
        for first in firsts {
            let next: MushroomWeatherArrangement = applied(first, to: current)
            let key: Key = Key(next)
            if seen.contains(key) { continue }
            guard work < workBound else { return nil }
            work += 1
            seen.insert(key)
            if MushroomWeatherForest.report(level, arrangement: next).wins {
                return MushroomWeatherHintPlan(actions: [first])
            }
        }
        guard cap >= 2 else { return nil }
        for first in firsts {
            let middle: MushroomWeatherArrangement = applied(first, to: current)
            for second in candidates(middle, level: level) {
                let next: MushroomWeatherArrangement = applied(second, to: middle)
                let key: Key = Key(next)
                if seen.contains(key) { continue }
                guard work < workBound else { return nil }
                work += 1
                seen.insert(key)
                if MushroomWeatherForest.report(level, arrangement: next).wins {
                    return MushroomWeatherHintPlan(actions: [first, second])
                }
            }
        }
        return nil
    }

    /// The hint of `level` (clamped to 1 … 3) for `play` with the certified plan `certified`: while `playing`, `run`
    /// with ``MushroomWeatherHint/runText`` when the plan is empty, the plan's first action (`pod`, `vent` or
    /// `moonlight`, text per ``MushroomWeatherHint/actionText(level:action:arrangement:)``), or `stuck` with
    /// ``MushroomWeatherHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure), `stuck`
    /// with ``MushroomWeatherHint/failedText``; nil in every other stage (loading, tutorial, paused, won, result after
    /// a win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: MushroomWeatherPlay,
                            certified: MushroomWeatherPlan?) -> MushroomWeatherHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return MushroomWeatherHint(level: level, kind: .stuck, action: nil, text: MushroomWeatherHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return MushroomWeatherHint(level: level, kind: .stuck, action: nil, text: MushroomWeatherHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let found = plan(play, certified: certified) else {
            return MushroomWeatherHint(level: level, kind: .stuck, action: nil, text: MushroomWeatherHint.stuckText)
        }
        guard let first = found.actions.first else {
            return MushroomWeatherHint(level: level, kind: .run, action: .run, text: MushroomWeatherHint.runText)
        }
        guard let text = MushroomWeatherHint.actionText(level: level, action: first,
                                                        arrangement: play.arrangement) else {
            return MushroomWeatherHint(level: level, kind: .stuck, action: nil, text: MushroomWeatherHint.stuckText)
        }
        return MushroomWeatherHint(level: level, kind: MushroomWeatherHint.kind(of: first), action: first, text: text)
    }
}

/// The plain-English explanation of a failed run of the weather (FR-R02G2005-003; clarification Q5), from the play's
/// failure.
public struct MushroomWeatherFailureExplanation: Sendable, Equatable {
    /// Why the run failed.
    public let failure: MushroomWeatherFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With n
    /// the colony's number (its index + 1), k the level's required final run and cells in the level's words:
    /// - dried: "Colony n dried out at cycle t: it fell below its survival floor."
    /// - mold: "The cell at row r, column c grew mold at cycle t: it rose above the mold bound."
    /// - unstable: "Colony n stayed in its band for only the last r cycles; k were needed." ("cycle" when r is 1,
    ///   "was" when k is 1: ``unstableSentence(colony:run:required:)``)
    /// each followed by a space and ``advice``. Nil when the failure names a colony the level lacks.
    public init?(play: MushroomWeatherPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: MushroomWeatherLevel = play.level
        let sentence: String
        switch failure {
        case .dried(let colony, let cycle):
            guard level.colonies.indices.contains(colony) else { return nil }
            sentence = "Colony " + String(colony + 1) + " dried out at cycle " + String(cycle)
                + ": it fell below its survival floor."
        case .mold(let cell, let cycle):
            sentence = "The cell at " + MushroomWeatherLevel.cellWords(cell) + " grew mold at cycle " + String(cycle)
                + ": it rose above the mold bound."
        case .unstable(let colony, let run):
            guard level.colonies.indices.contains(colony) else { return nil }
            sentence = Self.unstableSentence(colony: colony, run: run, required: level.required)
        }
        self.failure = failure
        text = sentence + " " + Self.advice
    }

    /// The sentence of an unstable failure of colony index `colony` (numbered `colony + 1`) whose final run in its band
    /// lasted `run` cycles where `required` were needed (T-R02G2005-004): "Colony n stayed in its band for only the
    /// last r cycles; k were needed.", with "cycle" when `run` is 1 and "was" when `required` is 1.
    public static func unstableSentence(colony: Int, run: Int, required: Int) -> String {
        let cycles: String = run == 1 ? " cycle; " : " cycles; "
        let needed: String = required == 1 ? " was needed." : " were needed."
        return "Colony " + String(colony + 1) + " stayed in its band for only the last " + String(run) + cycles
            + String(required) + needed
    }
}
