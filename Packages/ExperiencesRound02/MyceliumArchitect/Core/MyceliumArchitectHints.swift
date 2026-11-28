// MyceliumArchitectHints — feature 515 (R02-G22-05) T-R02G2205-002 (FR-R02G2205-002, 003, 009; SC-R02G2205-002, 003;
// clarifications Q1, Q5; research R1 … R3). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failed run of the growth.
//
// While a play is `playing`, the plan is empty when the current arrangement already wins (the play's report wins).
// Otherwise, while the current arrangement lies on the way to the certified arrangement — for each of placed
// nutrients, placed blockers and seeds, start ∩ certified ⊆ current ⊆ start ∪ certified — the remaining actions are
// the certified witness's arrangement actions not yet done (a placement whose item is not yet placed on its cell, a
// clear whose cell still holds an item, a seed whose direction is not yet seeded, an unseed whose direction is still
// seeded), in the witness's order; when the actions left cover them and each, applied in that order from the current
// arrangement, is a move the rules accept (the kernel's check, `MyceliumArchitectPlay.changed`, the same one
// `MyceliumArchitectPuzzle.apply` uses), the plan is them. Exact hints from a level's start therefore replay its
// certified witness of 1 … 4 actions with no search at all.
//
// Otherwise a bounded breadth-first search from the current arrangement looks for a winning arrangement within
// min(actions left, 2) actions, an action being any legal move of `MyceliumArchitectPuzzle.moves(in:)` in its fixed
// order (nutrients on empty cells ascending (row, column), blockers likewise, clears ascending, seeds ascending,
// unseeds ascending). One action is tried before two. Each reached arrangement is judged with
// `MyceliumArchitectGrowth.report(level, arrangement:)` (a report depends only on the arrangement); an arrangement
// already judged (or the current one) is not judged again, and the work is the number of arrangements judged, bounded
// at 2,000 (above any catalog level's two-action space, at most 34 + 34 × 34 = 1,190). The plan is the first winning
// sequence found; nil when none is found within those actions or the bound would be exceeded.
//
// The first action of the plan is the hint: level 1 names the kind of change ("Place a nutrient", "Place a blocker",
// "Clear a placed nutrient or blocker", "Seed a filament from the root" or "Remove a seeded filament"); level 2 adds
// where — for a cell its part of the board ("in the upper left", "in the upper right", "in the lower left" or "in the
// lower right": a column below W / 2 is left, a row below H / 2 upper, rows counted from the top, compared exactly as
// 2 · column < W and 2 · row < H), for a direction its side ("towards the top" for north, north-east and north-west,
// "towards the bottom" for south, south-east and south-west, "to the east", "to the west"); level 3 the exact action
// ("Place a nutrient at (c, r)", "Place a blocker at (c, r)", "Clear (c, r)" with the cell's words, "Seed a filament to
// the north-east", "Remove the filament to the west" with the compass name). With an empty plan the hint is the run
// ("Every terminal is reached within the limits: run the growth"); with no plan it is `stuck`. A failed play (or one
// in `result` after a failure) gets `retry`, the advice to undo or retry; loading, tutorial, paused, won and `result`
// after a win have no hint. Hints never change a play, are unlimited and do not affect stars; the hint level is
// presentation.
//
// The failure explanation is the level's own `failureDescription` (tips and terminals numbered from 1, numbers grouped
// as the level groups them), its first letter capitalised, then ". " and "Undo the last action or retry the level.".
// Integers and strings only; no clock, no random source; work is counted, never measured. Modelled on
// `BinaryGardensHints` (feature 505).
import Foundation

/// The plan of a play from its current arrangement (clarification Q1): the certified witness's actions still to do, or
/// a shortest winning completion's nutrient, blocker, clear, seed and unseed actions. The first action is the hint; an
/// empty plan means the current arrangement already wins.
public struct MyceliumArchitectHintPlan: Sendable, Equatable {
    /// The arrangement actions in order; the run is not part of it.
    public let actions: [MyceliumArchitectAction]

    /// A plan of the given actions (not checked).
    public init(actions: [MyceliumArchitectAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum MyceliumArchitectHintKind: String, Sendable, Codable {
    /// Place a nutrient on an empty cell.
    case nutrient
    /// Place a blocker on an empty cell.
    case blocker
    /// Clear a placed nutrient or blocker.
    case clear
    /// Seed a filament from the root.
    case seed
    /// Remove a seeded filament.
    case unseed
    /// Every terminal is reached within the limits: run the growth.
    case run
    /// No way to win was found in the actions left: undo or retry.
    case stuck
    /// The run failed: undo or retry.
    case retry
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct MyceliumArchitectHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind of change, 2 adds where, 3 the exact action.
    public let level: Int
    /// What the hint suggests.
    public let kind: MyceliumArchitectHintKind
    /// The suggested action: a nutrient, blocker, clear, seed or unseed action, `.run` for `run`, nil for `stuck` and
    /// `retry`.
    public let action: MyceliumArchitectAction?
    /// The hint in plain English.
    public var text: String

    /// The text of the hint when the current arrangement already wins, at every level.
    public static let runText: String = "Every terminal is reached within the limits: run the growth"
    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: MyceliumArchitectHintKind, action: MyceliumArchitectAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// The kind of `action`: `nutrient`, `blocker`, `clear`, `seed`, `unseed` or `run`.
    public static func kind(of action: MyceliumArchitectAction) -> MyceliumArchitectHintKind {
        switch action {
        case .nutrient: .nutrient
        case .blocker: .blocker
        case .clear: .clear
        case .seed: .seed
        case .unseed: .unseed
        case .run: .run
        }
    }

    /// The part of `board` that holds `cell`: "in the upper left", "in the upper right", "in the lower left" or "in the
    /// lower right" — a column below W / 2 is left (2 · column < W), a row below H / 2 upper (2 · row < H), rows
    /// counted from the top.
    public static func quadrantWords(_ cell: MyceliumArchitectCell, on board: MyceliumArchitectLevel) -> String {
        let vertical: String = 2 * cell.row < board.height ? "upper" : "lower"
        let horizontal: String = 2 * cell.column < board.width ? "left" : "right"
        return "in the " + vertical + " " + horizontal
    }

    /// The side `direction` points to: "towards the top" for north, north-east and north-west, "towards the bottom"
    /// for south, south-east and south-west, "to the east" for east and "to the west" for west.
    public static func sideWords(_ direction: MyceliumArchitectDirection) -> String {
        switch direction {
        case .north, .northEast, .northWest: "towards the top"
        case .south, .southEast, .southWest: "towards the bottom"
        case .east: "to the east"
        case .west: "to the west"
        }
    }

    /// The text of a nutrient, blocker, clear, seed or unseed hint at `level` (clamped to 1 … 3) on `board`; nil for
    /// the run and for a cell off the board. With (c, r) the cell's words (`MyceliumArchitectCell.words`):
    /// - `.nutrient(cell)`: "Place a nutrient"; "Place a nutrient in the upper left" (``quadrantWords(_:on:)``);
    ///   "Place a nutrient at (c, r)".
    /// - `.blocker(cell)`: "Place a blocker"; "Place a blocker in the lower right"; "Place a blocker at (c, r)".
    /// - `.clear(cell)`: "Clear a placed nutrient or blocker"; "Clear a placed nutrient or blocker in the upper
    ///   right"; "Clear (c, r)".
    /// - `.seed(direction)`: "Seed a filament from the root"; "Seed a filament from the root towards the top"
    ///   (``sideWords(_:)``); "Seed a filament to the north-east" (the compass name).
    /// - `.unseed(direction)`: "Remove a seeded filament"; "Remove a seeded filament to the west"; "Remove the filament
    ///   to the west".
    public static func actionText(level: Int, action: MyceliumArchitectAction,
                                  on board: MyceliumArchitectLevel) -> String? {
        let clamped: Int = min(3, max(1, level))
        switch action {
        case .nutrient(let cell):
            guard board.contains(cell) else { return nil }
            if clamped == 1 { return "Place a nutrient" }
            if clamped == 2 { return "Place a nutrient " + quadrantWords(cell, on: board) }
            return "Place a nutrient at " + cell.words
        case .blocker(let cell):
            guard board.contains(cell) else { return nil }
            if clamped == 1 { return "Place a blocker" }
            if clamped == 2 { return "Place a blocker " + quadrantWords(cell, on: board) }
            return "Place a blocker at " + cell.words
        case .clear(let cell):
            guard board.contains(cell) else { return nil }
            if clamped == 1 { return "Clear a placed nutrient or blocker" }
            if clamped == 2 { return "Clear a placed nutrient or blocker " + quadrantWords(cell, on: board) }
            return "Clear " + cell.words
        case .seed(let direction):
            if clamped == 1 { return "Seed a filament from the root" }
            if clamped == 2 { return "Seed a filament from the root " + sideWords(direction) }
            return "Seed a filament to the " + direction.words
        case .unseed(let direction):
            if clamped == 1 { return "Remove a seeded filament" }
            if clamped == 2 { return "Remove a seeded filament " + sideWords(direction) }
            return "Remove the filament to the " + direction.words
        case .run:
            return nil
        }
    }
}

/// The hint engine of Mycelium Architect (clarification Q1).
public enum MyceliumArchitectHints {
    /// The bound on arrangements judged per plan.
    public static let workBound: Int = 2_000

    /// The most actions a searched plan holds.
    static let maxActions: Int = 2

    /// Whether `part` lies between `start` and `target`: start ∩ target ⊆ part ⊆ start ∪ target.
    static func between<Item: Hashable>(_ part: [Item], start: [Item], target: [Item]) -> Bool {
        let now: Set<Item> = Set(part)
        let from: Set<Item> = Set(start)
        let to: Set<Item> = Set(target)
        return from.intersection(to).isSubset(of: now) && now.isSubset(of: from.union(to))
    }

    /// Whether `arrangement` lies on the way from `start` to `target`: for placed nutrients, placed blockers and seeds
    /// alike, start ∩ target ⊆ arrangement ⊆ start ∪ target.
    static func liesOnTheWay(_ arrangement: MyceliumArchitectArrangement, start: MyceliumArchitectArrangement,
                             target: MyceliumArchitectArrangement) -> Bool {
        between(arrangement.nutrients, start: start.nutrients, target: target.nutrients)
            && between(arrangement.blockers, start: start.blockers, target: target.blockers)
            && between(arrangement.seeds, start: start.seeds, target: target.seeds)
    }

    /// Whether `action` is already done in `arrangement`: a placement whose item is placed on its cell, a clear whose
    /// cell holds no item, a seed whose direction is seeded, an unseed whose direction is not seeded. The run is never
    /// done.
    static func isDone(_ action: MyceliumArchitectAction, in arrangement: MyceliumArchitectArrangement) -> Bool {
        switch action {
        case .nutrient(let cell):
            return arrangement.nutrients.contains(cell)
        case .blocker(let cell):
            return arrangement.blockers.contains(cell)
        case .clear(let cell):
            return !arrangement.nutrients.contains(cell) && !arrangement.blockers.contains(cell)
        case .seed(let direction):
            return arrangement.seeds.contains(direction)
        case .unseed(let direction):
            return !arrangement.seeds.contains(direction)
        case .run:
            return false
        }
    }

    /// The arrangement `certified` (arrangement actions; a run among them is skipped) reaches from `level`'s start,
    /// or nil when the kernel refuses one of them.
    static func certifiedArrangement(_ level: MyceliumArchitectLevel,
                                     certified: [MyceliumArchitectAction]) -> MyceliumArchitectArrangement? {
        var current: MyceliumArchitectArrangement = level.start
        for action in certified {
            if case .run = action { continue }
            guard let next = try? MyceliumArchitectPlay.changed(level, current, by: action) else { return nil }
            current = next
        }
        return current
    }

    /// The certified witness's actions still to do from `arrangement` when it lies on the way to the arrangement
    /// `certified` reaches from the start: the witness's arrangement actions not yet done (``isDone(_:in:)``, judged on
    /// the arrangement as the remaining actions change it), in the witness's order, each a move the kernel accepts
    /// from the arrangement before it. Nil when the arrangement does not lie on the way or a remaining action is
    /// refused. The budget is not checked here.
    static func remainingCertified(_ arrangement: MyceliumArchitectArrangement, level: MyceliumArchitectLevel,
                                   certified: [MyceliumArchitectAction]) -> [MyceliumArchitectAction]? {
        guard let target = certifiedArrangement(level, certified: certified) else { return nil }
        guard liesOnTheWay(arrangement, start: level.start, target: target) else { return nil }
        var current: MyceliumArchitectArrangement = arrangement
        var result: [MyceliumArchitectAction] = []
        for action in certified {
            if case .run = action { continue }
            if isDone(action, in: current) { continue }
            guard let next = try? MyceliumArchitectPlay.changed(level, current, by: action) else { return nil }
            result.append(action)
            current = next
        }
        return result
    }

    /// The bounded breadth-first search of ``plan(_:certified:workBound:)`` from `play`'s arrangement: the first
    /// winning sequence of one, else two, legal moves within `min(actions left, 2)`, each new arrangement judged once
    /// (the current one never), and the arrangements judged. The legal moves of an arrangement are exactly
    /// `MyceliumArchitectPuzzle.moves(in:)`'s, in its order, each applied with the kernel's check. The plan is nil
    /// when no winning sequence is found or more than `workBound` arrangements would be judged (the work then stops
    /// at the bound).
    static func search(_ play: MyceliumArchitectPlay,
                       workBound: Int) -> (plan: MyceliumArchitectHintPlan?, work: Int) {
        let level: MyceliumArchitectLevel = play.level
        let cap: Int = min(maxActions, play.actionsLeft)
        guard cap >= 1 else { return (nil, 0) }
        let puzzle: MyceliumArchitectPuzzle = MyceliumArchitectPuzzle(level: level)
        let current: MyceliumArchitectPuzzle.Position =
            MyceliumArchitectPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
        var seen: Set<MyceliumArchitectArrangement> = [play.arrangement]
        var work: Int = 0
        var middles: [(action: MyceliumArchitectAction, arrangement: MyceliumArchitectArrangement)] = []
        for first in puzzle.moves(in: current) {
            guard let next = try? MyceliumArchitectPlay.changed(level, play.arrangement, by: first) else { continue }
            middles.append((first, next))
            if seen.contains(next) { continue }
            guard work < workBound else { return (nil, work) }
            work += 1
            seen.insert(next)
            if MyceliumArchitectGrowth.report(level, arrangement: next).wins {
                return (MyceliumArchitectHintPlan(actions: [first]), work)
            }
        }
        guard cap >= 2 else { return (nil, work) }
        for middle in middles {
            let position: MyceliumArchitectPuzzle.Position =
                MyceliumArchitectPuzzle.Position(arrangement: middle.arrangement, actionsSpent: play.actionsSpent + 1)
            for second in puzzle.moves(in: position) {
                guard let next = try? MyceliumArchitectPlay.changed(level, middle.arrangement, by: second) else {
                    continue
                }
                if seen.contains(next) { continue }
                guard work < workBound else { return (nil, work) }
                work += 1
                seen.insert(next)
                if MyceliumArchitectGrowth.report(level, arrangement: next).wins {
                    return (MyceliumArchitectHintPlan(actions: [middle.action, second]), work)
                }
            }
        }
        return (nil, work)
    }

    /// The plan of `play` while `playing`: empty when the current arrangement already wins (the play's report wins);
    /// else the certified witness's actions still to do while the arrangement lies on the way to the arrangement
    /// `certified` (the certified plan's arrangement actions, without the run) reaches, each a legal move in order,
    /// and the actions left cover them; else the first winning sequence of a breadth-first search within
    /// `min(actions left, 2)` legal moves of `MyceliumArchitectPuzzle.moves(in:)`, one action before two, each new
    /// arrangement judged once with `MyceliumArchitectGrowth.report(_:arrangement:)`. Nil in every other stage, when
    /// no winning arrangement is reachable within those actions, and when more than `workBound` arrangements would be
    /// judged. The play is not changed.
    public static func plan(_ play: MyceliumArchitectPlay, certified: [MyceliumArchitectAction]?,
                            workBound: Int = workBound) -> MyceliumArchitectHintPlan? {
        guard play.stage == .playing else { return nil }
        if play.report.wins { return MyceliumArchitectHintPlan(actions: []) }
        if let certified,
           let remaining = remainingCertified(play.arrangement, level: play.level, certified: certified),
           !remaining.isEmpty, remaining.count <= play.actionsLeft {
            return MyceliumArchitectHintPlan(actions: remaining)
        }
        return search(play, workBound: workBound).plan
    }

    /// The hint of `level` (clamped to 1 … 3) for `play` with the certified plan's arrangement actions `certified`:
    /// while `playing`, `run` with ``MyceliumArchitectHint/runText`` when the plan is empty, the plan's first action
    /// (`nutrient`, `blocker`, `clear`, `seed` or `unseed`, text per
    /// ``MyceliumArchitectHint/actionText(level:action:on:)``), or `stuck` with ``MyceliumArchitectHint/stuckText``
    /// when there is no plan; when `failed` (or `result` after a failure), `retry` with
    /// ``MyceliumArchitectHint/failedText``; nil in every other stage (loading, tutorial, paused, won, result after a
    /// win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: MyceliumArchitectPlay,
                            certified: [MyceliumArchitectAction]?) -> MyceliumArchitectHint? {
        switch play.stage {
        case .playing:
            break
        case .failed:
            return MyceliumArchitectHint(level: level, kind: .retry, action: nil, text: MyceliumArchitectHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return MyceliumArchitectHint(level: level, kind: .retry, action: nil, text: MyceliumArchitectHint.failedText)
        case .loading, .tutorial, .paused, .won:
            return nil
        }
        guard let found = plan(play, certified: certified) else {
            return MyceliumArchitectHint(level: level, kind: .stuck, action: nil, text: MyceliumArchitectHint.stuckText)
        }
        guard let first = found.actions.first else {
            return MyceliumArchitectHint(level: level, kind: .run, action: .run, text: MyceliumArchitectHint.runText)
        }
        guard let text = MyceliumArchitectHint.actionText(level: level, action: first, on: play.level) else {
            return MyceliumArchitectHint(level: level, kind: .stuck, action: nil, text: MyceliumArchitectHint.stuckText)
        }
        return MyceliumArchitectHint(level: level, kind: MyceliumArchitectHint.kind(of: first), action: first,
                                     text: text)
    }
}

/// The plain-English explanation of a failed run of the growth (FR-R02G2205-003; clarification Q5), from the play's
/// failure.
public struct MyceliumArchitectFailureExplanation: Sendable, Equatable {
    /// Why the run failed.
    public let failure: MyceliumArchitectFailure
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure): the
    /// level's words for it (``sentence(_:level:)``), one space and ``advice``. Nil when the failure names a terminal
    /// the level lacks.
    public init?(play: MyceliumArchitectPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        guard let sentence = Self.sentence(failure, level: play.level) else { return nil }
        self.failure = failure
        text = sentence + " " + Self.advice
    }

    /// The sentence of `failure` on `level`: the level's `failureDescription`, its first letter capitalised, then a
    /// full stop — toxic "Tip t grew into toxin at (c, r) on pulse p."; starved "Tip t ran out of nutrient on pulse p:
    /// growing to (c, r) would make the branch weight W, above the budget of B."; unreached "Terminal n at (c, r) was
    /// not reached."; overweight "The network's branch weight W is above the limit of L." (tips and terminals numbered
    /// from 1, numbers grouped as the level groups them). Nil for an unreached terminal the level lacks.
    public static func sentence(_ failure: MyceliumArchitectFailure, level: MyceliumArchitectLevel) -> String? {
        if case .unreached(let terminal) = failure, !level.terminals.indices.contains(terminal) { return nil }
        let words: String = level.failureDescription(failure)
        guard let first = words.first else { return nil }
        return String(first).uppercased() + String(words.dropFirst()) + "."
    }
}
