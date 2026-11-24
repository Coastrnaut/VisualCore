// AcousticConstellatorHints — feature 425 (R02-G13-05) T-R02G1305-002 (FR-R02G1305-002, 003, 007; SC-R02G1305-002, 003;
// clarifications Q1, Q5; research R1, R2, R6). Progressive hints computed from the current state of a play, and the
// plain-English explanation of a failure. While a play is playing (or paused) with actions left, the plan is the
// solver's minimal plan from the play's current links and starting phases
// (`AcousticConstellatorSolver.plan(_:links:phases:maxActions:workBound:)`, the links already placed kept, no derived
// level, so a play may hold more than six links): the missing symbol pairs' links first (pair order), then its helper
// links (pair order), then its nudges (star order, one action per step), then the listen. It is offered only when all of
// those actions fit the actions left, the search stays within the work bound and they replay on a copy of the play with
// every action accepted and a win on the last. The first action is the hint: level 1 names the kind, level 2 the stars,
// level 3 the exact action. A won play has no hint; a failed play's hint is the advice to undo or retry. Hints never
// change a play, are unlimited and do not affect stars; the hint level is presentation (held by the presenter, reset to
// 1 after any change of the play).
//
// The failure explanation counts actions from 1 ("Action m" is the action with 0-based index m − 1) and ticks and stars
// from 0. The failing action is read from the actions still applied after the records (undone ones excluded): the
// latest one for a listen failure, the one at the recorded index for the budget. Its sentence and the advice are joined
// by one space. Integers and strings only; no clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the minimal plan's links (missing symbol pairs first,
/// then helper links, each in pair order), its nudges (star order, one per step), then the listen. The first action is
/// the hint.
public struct AcousticConstellatorHintPlan: Sendable, Equatable {
    /// The actions, in play order; the last one (the listen) wins.
    public let actions: [AcousticConstellatorAction]

    /// A plan of the given actions (not checked).
    public init(actions: [AcousticConstellatorAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum AcousticConstellatorHintKind: String, Sendable, Codable {
    /// Link a symbol pair that is still missing.
    case linkSymbol
    /// Link a helper pair (not part of the symbol) so the phases pull together.
    case linkHelper
    /// Nudge a star's starting phase by ±1.
    case nudge
    /// Every needed link and nudge is in place: listen.
    case listen
    /// No way to win fits in the moves left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested action is the same at every level; only the text reveals more.
public struct AcousticConstellatorHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the kind, 2 the stars, 3 the exact action.
    public let level: Int
    /// What the hint suggests.
    public let kind: AcousticConstellatorHintKind
    /// The suggested action (a link, a nudge or the listen); nil for `stuck`.
    public let action: AcousticConstellatorAction?
    /// The hint in plain English (see ``text(level:kind:action:failed:)``).
    public var text: String

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last action or retry the level."
    /// The text shown when no way to win was found in the moves left, at every level.
    public static let stuckText: String =
        "No way to win was found in the moves left: undo the last action or retry the level."
    /// The level-1 text of a hint to link a missing symbol pair.
    public static let linkSymbolText: String = "Link two stars of the symbol"
    /// The level-1 text of a hint to link a helper pair.
    public static let linkHelperText: String = "Link a helper pair so the phases pull together"
    /// The level-1 text of a nudge hint.
    public static let nudgeText: String = "Nudge a star's phase"
    /// The level-1 text of a listen hint.
    public static let listenText: String = "The symbol is ready: listen"
    /// The level-2 and level-3 text of a listen hint.
    public static let listenDetailText: String = "Listen: tap the coherence gauge"

    /// A hint of the given values (`level` clamped to 1 … 3), its text per ``text(level:kind:action:failed:)``.
    init(level: Int, kind: AcousticConstellatorHintKind, action: AcousticConstellatorAction? = nil,
         failed: Bool = false) {
        let clamped: Int = min(3, max(1, level))
        self.level = clamped
        self.kind = kind
        self.action = action
        text = Self.text(level: clamped, kind: kind, action: action, failed: failed)
    }

    /// The signed step of a nudge in words: "+1" or "−1" (U+2212 MINUS SIGN).
    public static func stepText(_ step: Int) -> String { step < 0 ? "\u{2212}1" : "+1" }

    /// The hint text (clarification Q1), for stars a, b and s (0-based):
    /// - linkSymbol / linkHelper: level 1 ``linkSymbolText`` / ``linkHelperText``; level 2 "Work on star a and star b";
    ///   level 3 "Link star a to star b"
    /// - nudge: level 1 ``nudgeText``; level 2 "Work on star s"; level 3 "Nudge star s by +1" (or "by −1")
    /// - listen: level 1 ``listenText``; levels 2 and 3 ``listenDetailText``
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public static func text(level: Int, kind: AcousticConstellatorHintKind, action: AcousticConstellatorAction?,
                            failed: Bool) -> String {
        switch kind {
        case .stuck:
            return failed ? failedText : stuckText
        case .listen:
            return level <= 1 ? listenText : listenDetailText
        case .linkSymbol, .linkHelper:
            guard case .link(let u, let v) = action else { return stuckText }
            let link = AcousticConstellatorLink.between(u, v)
            if level <= 1 { return kind == .linkSymbol ? linkSymbolText : linkHelperText }
            if level == 2 { return "Work on star " + String(link.a) + " and star " + String(link.b) }
            return "Link star " + String(link.a) + " to star " + String(link.b)
        case .nudge:
            guard case .nudge(let star, let step) = action else { return stuckText }
            if level <= 1 { return nudgeText }
            if level == 2 { return "Work on star " + String(star) }
            return "Nudge star " + String(star) + " by " + stepText(step)
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it). A stuck hint keeps its text.
    public func at(level: Int) -> AcousticConstellatorHint {
        var result = AcousticConstellatorHint(level: level, kind: kind, action: action)
        if kind == .stuck { result.text = text }
        return result
    }
}

/// The hint engine of Acoustic Constellator (clarification Q1).
public enum AcousticConstellatorHints {
    /// The plan of `play` while `playing` or `paused` with actions left: the minimal plan from the play's links and
    /// starting phases (``AcousticConstellatorSolver/plan(_:links:phases:maxActions:workBound:)`` with the default work
    /// bound and at most `min(6, actions left − 1)` actions before the listen) as actions — the missing symbol pairs'
    /// links in pair order, the helper links in pair order, the nudges in star order, then the listen. Offered only when
    /// those actions fit ``AcousticConstellatorPlay/actionsLeft`` and replay on a copy of the play (resumed when paused)
    /// with every action accepted and a win on the last. Nil in every other stage, when the search finds no plan or
    /// exceeds the work bound, and when the plan does not fit the actions left. The play is not changed.
    public static func plan(_ play: AcousticConstellatorPlay) -> AcousticConstellatorHintPlan? {
        guard play.stage == .playing || play.stage == .paused, play.actionsLeft >= 1 else { return nil }
        let cap: Int = min(AcousticConstellatorSolver.maxActions, play.actionsLeft - 1)
        guard let minimal = AcousticConstellatorSolver.plan(play.level, links: play.links, phases: play.phases,
                                                            maxActions: cap) else { return nil }
        let symbol: Set<AcousticConstellatorLink> = Set(play.level.symbol)
        var actions: [AcousticConstellatorAction] = []
        let links: [AcousticConstellatorLink] = minimal.links.sorted()
        for link in links where symbol.contains(link) { actions.append(.link(link.a, link.b)) }
        for link in links where !symbol.contains(link) { actions.append(.link(link.a, link.b)) }
        for nudge in minimal.nudges.sorted(by: { ($0.star, $0.step) < ($1.star, $1.step) }) {
            actions.append(.nudge(nudge.star, nudge.step))
        }
        actions.append(.listen)
        guard actions.count <= play.actionsLeft else { return nil }
        var copy: AcousticConstellatorPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return AcousticConstellatorHintPlan(actions: actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first action
    /// (`linkSymbol` for a missing symbol pair, `linkHelper` for another pair, `nudge` or `listen`), `stuck` with
    /// ``AcousticConstellatorHint/stuckText`` when there is no plan; when `failed` (or `result` after a failure), `stuck`
    /// with ``AcousticConstellatorHint/failedText``; nil in every other stage (loading, tutorial, won, result after a
    /// win). The same action is returned at every level; the play is not changed.
    public static func hint(level: Int, play: AcousticConstellatorPlay) -> AcousticConstellatorHint? {
        switch play.stage {
        case .playing, .paused: break
        case .failed: return AcousticConstellatorHint(level: level, kind: .stuck, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return AcousticConstellatorHint(level: level, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return AcousticConstellatorHint(level: level, kind: .stuck)
        }
        switch first {
        case .link(let u, let v):
            let kind: AcousticConstellatorHintKind = play.level.symbol.contains(AcousticConstellatorLink.between(u, v))
                ? .linkSymbol : .linkHelper
            return AcousticConstellatorHint(level: level, kind: kind, action: first)
        case .nudge: return AcousticConstellatorHint(level: level, kind: .nudge, action: first)
        case .listen, .unlink: return AcousticConstellatorHint(level: level, kind: .listen, action: first)
        }
    }

    /// The actions still applied after `records`, in play order: links, unlinks, nudges and listens push, an undo moves
    /// the top to a redo stack, a redo moves it back and a new action clears the redo stack, as the play's own stacks
    /// do. The i-th element is the action with 0-based index i of the current play.
    static func appliedActions(_ records: [AcousticConstellatorRecord]) -> [AcousticConstellatorAction] {
        var applied: [AcousticConstellatorAction] = []
        var undone: [AcousticConstellatorAction] = []
        for record in records {
            switch record.kind {
            case .link, .unlink, .nudge, .listen:
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

/// The plain-English explanation of a failed play (FR-R02G1305-003, 007; clarification Q5), from the failing action.
public struct AcousticConstellatorFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: AcousticConstellatorFailure
    /// The 0-based index of the failing action; the text counts from 1.
    public let action: Int
    /// The explanation: the sentence, one space and ``advice``.
    public var text: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last action or retry the level."

    /// The words for an action in a budget explanation: "a link of star a and star b", "an unlink of star a and star
    /// b", "a nudge of star s by +1" (or "by −1") or "the listen".
    public static func describe(_ action: AcousticConstellatorAction) -> String {
        switch action {
        case .link(let u, let v):
            let link = AcousticConstellatorLink.between(u, v)
            return "a link of star " + String(link.a) + " and star " + String(link.b)
        case .unlink(let u, let v):
            let link = AcousticConstellatorLink.between(u, v)
            return "an unlink of star " + String(link.a) + " and star " + String(link.b)
        case .nudge(let star, let step):
            return "a nudge of star " + String(star) + " by " + AcousticConstellatorHint.stepText(step)
        case .listen:
            return "the listen"
        }
    }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). With m the
    /// failing action's index + 1, H the level's hold and W its window:
    /// - missing: "Action m (the listen) found the symbol's pair star a – star b unlinked."
    /// - disconnected: "Action m (the listen): on tick t the link from star a to star b snapped and the symbol came
    ///   apart."
    /// - incoherent: "Action m (the listen): the stars held together for at most r of the H ticks needed within W."
    /// - budget: "Action m (<``describe(_:)``>) spent the last move without a win."
    /// each followed by a space and ``advice``. The failing action is read from the records' actions still applied
    /// (undone ones excluded): the latest of them for a listen failure, the one at the recorded index for the budget.
    public init?(play: AcousticConstellatorPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let applied: [AcousticConstellatorAction] = AcousticConstellatorHints.appliedActions(play.records)
        let index: Int
        switch failure {
        case .missing, .disconnected, .incoherent: index = play.actionsSpent - 1
        case .budget(let value): index = value
        }
        guard index >= 0, index < applied.count else { return nil }
        let failing: AcousticConstellatorAction = applied[index]
        let head: String = "Action " + String(index + 1)
        let sentence: String
        switch failure {
        case .missing(let pair):
            guard failing == .listen else { return nil }
            sentence = head + " (the listen) found the symbol's pair star " + String(pair.a) + " \u{2013} star "
                + String(pair.b) + " unlinked."
        case .disconnected(let tick, let link):
            guard failing == .listen else { return nil }
            sentence = head + " (the listen): on tick " + String(tick) + " the link from star " + String(link.a)
                + " to star " + String(link.b) + " snapped and the symbol came apart."
        case .incoherent(let run):
            guard failing == .listen else { return nil }
            sentence = head + " (the listen): the stars held together for at most " + String(run) + " of the "
                + String(play.level.hold) + " ticks needed within " + String(play.level.window) + "."
        case .budget:
            sentence = head + " (" + Self.describe(failing) + ") spent the last move without a win."
        }
        self.failure = failure
        action = index
        text = sentence + " " + Self.advice
    }
}
