// StarlitCartoucheHints — feature 455 (R02-G16-05) T-R02G1605-002 (FR-R02G1605-002, 003, 007; SC-R02G1605-002, 003;
// clarifications Q1, Q5; research R1, R2, R6). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failure. While a play is playing (or paused) with actions left, the plan is the
// solver's minimal plan from the play's current star, beat and drawn strokes
// (`StarlitCartoucheSolver.plan(_:from:beat:drawn:maxLegs:workBound:)` with the default work bound and at most
// min(7, actions left) legs); it is offered only when its legs fit the actions left. A breadth-first plan is a shortest
// one, so after its first leg the plan from there has exactly one leg fewer and following the hints wins within the
// budget. The first leg (j, w) is the hint: level 1 names the stroke (the corridor from the ship's star to star j and
// its two stars), level 2 the destination, level 3 the exact leg with its wait ("1 beat" singular). A won play has no
// hint; a failed play's hint is the advice to undo or retry. As feature 445's Voxel Origami: a paused play is hinted
// as if playing; a play in `result` after a failure gets the failed advice; loading, tutorial, won and `result` after
// a win have no hint. Hints never change a play, are unlimited and do not affect stars; the hint level is presentation
// (held by the presenter, reset to 1 after any change of the play).
//
// The failure explanation counts actions from 1 ("Action m" is the action with 0-based index m − 1) and stars,
// corridors and hazards from 0. The failing action is the play's actions spent (every accepted leg spends 1 action, a
// failing one included). Its destination and wait are read from the actions still applied after the records (undone
// ones excluded, as the play's own undo and redo stacks do) for a leg the chart failed (departure, hazard, arrival,
// deadline, stroke), and from the last leg flown for the budget (that leg was clear and is part of the route). The
// sentence and the advice are joined by one space. Integers and strings only; no clock, no random source. Modelled on
// `VoxelOrigamiHints` (feature 445).
import Foundation

/// The plan of a play from its current state (clarification Q1): the minimal plan's legs. The first leg is the hint.
public struct StarlitCartoucheHintPlan: Sendable, Equatable {
    /// The legs (each `.leg(star, wait)`), in play order; the last one wins.
    public let legs: [StarlitCartoucheAction]

    /// A plan of the given legs (not checked).
    public init(legs: [StarlitCartoucheAction]) {
        self.legs = legs
    }
}

/// What a hint suggests (clarification Q1).
public enum StarlitCartoucheHintKind: String, Sendable, Codable {
    /// Fly a leg to a star after a wait.
    case leg
    /// No way to win fits in the actions left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested leg is the same at every level; only the text reveals more.
public struct StarlitCartoucheHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the stroke, 2 the destination, 3 the exact leg with its wait.
    public let level: Int
    /// What the hint suggests.
    public let kind: StarlitCartoucheHintKind
    /// The suggested leg; nil for `stuck`.
    public let action: StarlitCartoucheAction?
    /// The hint in plain English.
    public var text: String

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the actions left, at every level.
    public static let stuckText: String =
        "No way to win was found in the actions left: undo the last action or retry the level."

    /// A hint of the given values (`level` clamped to 1 … 3) and text.
    init(level: Int, kind: StarlitCartoucheHintKind, action: StarlitCartoucheAction?, text: String) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.text = text
    }

    /// "w beats", or "1 beat" when `beats` is 1.
    public static func beatsText(_ beats: Int) -> String {
        beats == 1 ? "1 beat" : String(beats) + " beats"
    }

    /// The text of a leg hint (clarification Q1) to star `star` after `wait` beats along corridor `corridor` joining
    /// stars `a` and `b`, at `level` (clamped to 1 … 3): level 1 "The next leg flies corridor c, between star a and
    /// star b", level 2 "Fly to star j", level 3 "Fly to star j after waiting w beats" ("1 beat" singular).
    public static func legText(level: Int, star: Int, wait: Int, corridor: Int, a: Int, b: Int) -> String {
        let clamped: Int = min(3, max(1, level))
        if clamped == 1 {
            return "The next leg flies corridor " + String(corridor) + ", between star " + String(a) + " and star "
                + String(b)
        }
        if clamped == 2 { return "Fly to star " + String(star) }
        return "Fly to star " + String(star) + " after waiting " + beatsText(wait)
    }
}

/// The hint engine of Starlit Cartouche (clarification Q1).
public enum StarlitCartoucheHints {
    /// The plan of `play` while `playing` or `paused` with actions left: the minimal plan from the play's current
    /// star, beat and drawn strokes (``StarlitCartoucheSolver/plan(_:from:beat:drawn:maxLegs:workBound:)`` with the
    /// default work bound and at most `min(7, actions left)` legs), offered only when its legs fit
    /// ``StarlitCartouchePlay/actionsLeft``. Nil in every other stage, when the search finds no plan or exceeds the
    /// work bound, and when the plan does not fit the actions left. The play is not changed.
    public static func plan(_ play: StarlitCartouchePlay) -> StarlitCartoucheHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.actionsLeft >= 1 else { return nil }
        let cap: Int = min(StarlitCartoucheSolver.maxLegs, play.actionsLeft)
        guard let minimal = StarlitCartoucheSolver.plan(play.level, from: play.star, beat: play.beat,
                                                        drawn: play.drawn, maxLegs: cap) else { return nil }
        guard !minimal.legs.isEmpty, minimal.size <= play.actionsLeft else { return nil }
        return StarlitCartoucheHintPlan(legs: minimal.legs)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first leg (`leg`,
    /// text per ``StarlitCartoucheHint/legText(level:star:wait:corridor:a:b:)``), or `stuck` with
    /// ``StarlitCartoucheHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure), `stuck`
    /// with ``StarlitCartoucheHint/failedText``; nil in every other stage (loading, tutorial, won, result after a
    /// win). The same leg is returned at every level; the play is not changed.
    public static func hint(level: Int, play: StarlitCartouchePlay) -> StarlitCartoucheHint? {
        switch play.stage {
        case .playing, .paused:
            break
        case .failed:
            return StarlitCartoucheHint(level: level, kind: .stuck, action: nil, text: StarlitCartoucheHint.failedText)
        case .result:
            guard play.failure != nil else { return nil }
            return StarlitCartoucheHint(level: level, kind: .stuck, action: nil, text: StarlitCartoucheHint.failedText)
        case .loading, .tutorial, .won:
            return nil
        }
        guard let first = plan(play)?.legs.first else {
            return StarlitCartoucheHint(level: level, kind: .stuck, action: nil, text: StarlitCartoucheHint.stuckText)
        }
        switch first {
        case .leg(let star, let wait):
            guard let index = StarlitCartoucheChart.corridor(play.level, joining: play.star, star) else {
                return StarlitCartoucheHint(level: level, kind: .stuck, action: nil,
                                            text: StarlitCartoucheHint.stuckText)
            }
            let corridor: StarlitCartoucheCorridor = play.level.corridors[index]
            let text: String = StarlitCartoucheHint.legText(level: level, star: star, wait: wait, corridor: index,
                                                            a: corridor.a, b: corridor.b)
            return StarlitCartoucheHint(level: level, kind: .leg, action: first, text: text)
        }
    }

    /// The actions still applied after `records`, in play order: a leg pushes, an undo moves the top to a redo stack,
    /// a redo moves it back and a new leg clears the redo stack, as the play's own stacks do. The i-th element is the
    /// action with 0-based index i of the current play.
    static func appliedActions(_ records: [StarlitCartoucheRecord]) -> [StarlitCartoucheAction] {
        var applied: [StarlitCartoucheAction] = []
        var undone: [StarlitCartoucheAction] = []
        for record in records {
            switch record.kind {
            case .leg:
                if let action = record.action { applied.append(action) }
                undone.removeAll()
            case .undo:
                if let action = applied.popLast() { undone.append(action) }
            case .redo:
                if let action = undone.popLast() { applied.append(action) }
            }
        }
        return applied
    }
}

/// The plain-English explanation of a failed play (FR-R02G1605-003, 007; clarification Q5), from the failing action.
public struct StarlitCartoucheFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: StarlitCartoucheFailure
    /// The number of the failing action, counted from 1 (its 0-based index + 1), as the text names it.
    public let action: Int
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With m
    /// the failing action's number (from 1, the play's actions spent) and that action a leg to star j after w beats
    /// ("1 beat" singular):
    /// - departure: "Action m (a leg to star j after w beats) leaves star i at beat t, after its window closed at beat
    ///   c."
    /// - hazard: "Action m (a leg to star j after w beats) flies corridor k through hazard h, active from beat a to
    ///   beat b."
    /// - arrival: "Action m (a leg to star j after w beats) reaches star j at beat t, outside its window from beat o
    ///   to beat c."
    /// - deadline: "Action m (a leg to star j after w beats) arrives at beat t, after the deadline at beat d."
    /// - stroke: "Action m (a leg to star j after w beats) flies corridor k, which is not part of the symbol."
    /// - budget: "Action m (a leg to star j after w beats) spent the last action without completing the symbol at the
    ///   beacon."
    /// each followed by a space and ``advice``, with the stars, beats, corridor and hazard the kernel recorded. For a
    /// failed leg the action is the latest of the records' actions still applied (undone ones excluded), which must be
    /// action m; for the budget it is the last leg flown. Nil when that action cannot be found.
    public init?(play: StarlitCartouchePlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let number: Int = play.actionsSpent
        guard number >= 1 else { return nil }
        let star: Int
        let wait: Int
        if case .budget = failure {
            guard let last = play.legs.last else { return nil }
            star = last.to
            wait = last.wait
        } else {
            let applied: [StarlitCartoucheAction] = StarlitCartoucheHints.appliedActions(play.records)
            guard applied.count == number, let latest = applied.last else { return nil }
            guard case .leg(let destination, let waited) = latest else { return nil }
            star = destination
            wait = waited
        }
        let head: String = "Action " + String(number) + " (a leg to star " + String(star) + " after "
            + StarlitCartoucheHint.beatsText(wait) + ")"
        let sentence: String
        switch failure {
        case .departure(let origin, let beat, let close):
            sentence = head + " leaves star " + String(origin) + " at beat " + String(beat)
                + ", after its window closed at beat " + String(close) + "."
        case .hazard(let corridor, let hazard, let from, let to):
            sentence = head + " flies corridor " + String(corridor) + " through hazard " + String(hazard)
                + ", active from beat " + String(from) + " to beat " + String(to) + "."
        case .arrival(let target, let beat, let open, let close):
            sentence = head + " reaches star " + String(target) + " at beat " + String(beat)
                + ", outside its window from beat " + String(open) + " to beat " + String(close) + "."
        case .deadline(let beat, let deadline):
            sentence = head + " arrives at beat " + String(beat) + ", after the deadline at beat " + String(deadline)
                + "."
        case .stroke(let corridor):
            sentence = head + " flies corridor " + String(corridor) + ", which is not part of the symbol."
        case .budget:
            sentence = head + " spent the last action without completing the symbol at the beacon."
        }
        self.failure = failure
        action = number
        text = sentence + " " + Self.advice
    }
}
