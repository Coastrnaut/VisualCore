// BackwardsAuroraHints — feature 395 (R02-G10-05) T-R02G1005-002 (FR-R02G1005-002, 003; SC-R02G1005-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the plain-English explanation
// of a failure. The plan is the solver's bounded search from the current wave
// (`BackwardsAuroraSolver.solve(_:from:reversalsLeft:workBound:)`): the fewest further reversals that win within the
// reversals left, by the certification's iterative deepening and seam-count pruning, replayed on a copy of the play
// before it is offered. Its first reversal is the hint, so following exact hints from any state with a plan wins (a win
// on the last reversal of the budget wins). Hints never change a play, are unlimited and do not affect stars; the hint
// level is presentation (held by the presenter, reset to 1 after any change of the play). A failure is explained from
// the failing reversal: the seam that tore with its bend against the breaking limit, or the spent budget with the
// checkpoints matched and the worst bend against the bend limit.
//
// Sample numbers in every text are the wave's positions 0 … N − 1, exactly as the control panel names the section's
// ends ("start at sample i", "end at sample j") and as `wave.reverse [start, end]` takes them, so a player can set the
// panel to the hinted numbers directly; seams are positions too (as `BackwardsAuroraSceneSnapshot.failureText` names
// them). Reversals are counted from 1. Integers only; no clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the reversals of a winning continuation that fits in
/// the reversals left; the first one is the hint.
public struct BackwardsAuroraPlan: Sendable, Equatable {
    /// The reversals, in play order; the last one wins.
    public let actions: [BackwardsAuroraAction]

    /// A plan of the given reversals (not checked).
    public init(actions: [BackwardsAuroraAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum BackwardsAuroraHintKind: String, Sendable, Codable {
    /// Reverse one section.
    case reverse
    /// No way to fold the aurora back fits in the reversals left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested reversal is the same at every level; only the text reveals
/// more.
public struct BackwardsAuroraHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the section's length, 2 adds where it starts, 3 names both ends.
    public let level: Int
    /// What the hint suggests.
    public let kind: BackwardsAuroraHintKind
    /// The suggested reversal (`reverse`); nil for `stuck`.
    public let action: BackwardsAuroraAction?
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (`level` clamped to 1 … 3; not otherwise checked).
    init(level: Int, kind: BackwardsAuroraHintKind, action: BackwardsAuroraAction? = nil, failed: Bool = false) {
        self.level = min(3, max(1, level))
        self.kind = kind
        self.action = action
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last reversal or retry the level."
    /// The text shown when no way to fold the aurora back was found in the reversals left, at every level.
    public static let stuckText: String =
        "No way to fold the aurora back was found in the reversals left: undo the last reversal or retry the level."

    /// The hint in plain English (clarification Q1), for the section [i, j] of n = j − i + 1 samples (positions as the
    /// panel names them):
    /// - level 1: "Reverse a section of n samples"
    /// - level 2: "Reverse a section of n samples starting at sample i"
    /// - level 3: "Reverse samples i to j"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        guard kind == .reverse, let action else { return failed ? Self.failedText : Self.stuckText }
        switch action {
        case let .reverse(start, end):
            if level >= 3 { return "Reverse samples " + String(start) + " to " + String(end) }
            var words: String = "Reverse a section of " + String(end - start + 1) + " samples"
            if level >= 2 { words += " starting at sample " + String(start) }
            return words
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it).
    public func at(level: Int) -> BackwardsAuroraHint {
        BackwardsAuroraHint(level: level, kind: kind, action: action, failed: failed)
    }
}

/// The hint engine of Backwards Aurora (clarification Q1).
public enum BackwardsAuroraHints {
    /// The plan of `play` while `playing` or `paused` with at least one reversal left: the solver's continuation
    /// (``BackwardsAuroraSolver/solve(_:from:reversalsLeft:workBound:)`` with the default work bound) from the play's
    /// wave within its reversals left, offered only when it replays on a copy of the play (resumed when paused) with
    /// every reversal accepted and a win on the last one. Nil in every other stage and when no continuation is found.
    public static func plan(_ play: BackwardsAuroraPlay) -> BackwardsAuroraPlan? {
        guard play.stage == .playing || play.stage == .paused, play.remaining >= 1,
              let solution = BackwardsAuroraSolver.solve(play.level, from: play.wave, reversalsLeft: play.remaining),
              !solution.actions.isEmpty else { return nil }
        var copy: BackwardsAuroraPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in solution.actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return BackwardsAuroraPlan(actions: solution.actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first reversal
    /// (`reverse`), `stuck` with ``BackwardsAuroraHint/stuckText`` when there is no plan; when `failed` (or `result`
    /// after a failure), `stuck` with ``BackwardsAuroraHint/failedText``; nil in every other stage (loading, tutorial,
    /// won, result after a win). The same reversal is returned at every level; the play is not changed.
    public static func hint(level: Int, play: BackwardsAuroraPlay) -> BackwardsAuroraHint? {
        switch play.stage {
        case .playing, .paused: break
        case .failed: return BackwardsAuroraHint(level: level, kind: .stuck, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return BackwardsAuroraHint(level: level, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return BackwardsAuroraHint(level: level, kind: .stuck)
        }
        return BackwardsAuroraHint(level: level, kind: .reverse, action: first)
    }
}

/// The plain-English explanation of a failed play (FR-R02G1005-003; clarification Q5), from the failing reversal.
public struct BackwardsAuroraFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: BackwardsAuroraFailure
    /// The reversal named, 1-based: the tearing reversal (its index + 1), or the reversals spent for `budget`.
    public let reversal: Int
    /// The tearing reversal's first sample (position); nil for `budget`.
    public let start: Int?
    /// The tearing reversal's last sample (position); nil for `budget`.
    public let end: Int?
    /// The seam (position) that tore; nil for `budget`.
    public let seam: Int?
    /// The bend magnitude named: the bend at the torn seam, or the worst bend of the wave for `budget`.
    public let bend: Int
    /// The limit the bend is set against: the breaking limit B for a tear, the bend limit L for `budget`.
    public let limit: Int
    /// The checkpoints at their true height at the failure.
    public let matched: Int
    /// The level's checkpoints.
    public let checkpoints: Int
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last reversal or retry the level."

    /// The explanation (clarification Q5), positions as the panel names them:
    /// - tear: "Reversal m (samples i to j) tore the aurora at seam s: a bend of b against the breaking limit B."
    /// - budget: "The reversals ran out: b of b spent with k of n checkpoints matched and a worst bend of w against the
    ///   limit L."
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure). The
    /// tearing reversal's section is the latest reversal still applied, found by replaying the records' reversals,
    /// undos and redos on a stack (a failure restored by a redo names the same reversal).
    public init?(play: BackwardsAuroraPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: BackwardsAuroraLevel = play.level
        let wave: BackwardsAuroraWave = play.wave
        self.failure = failure
        matched = play.matched.filter { $0 }.count
        checkpoints = level.checkpoints.count
        switch failure {
        case let .tear(index, torn):
            guard let action = Self.latestApplied(play.records) else { return nil }
            let first: Int
            let last: Int
            switch action {
            case let .reverse(a, b):
                first = a
                last = b
            }
            reversal = index + 1
            start = first
            end = last
            seam = torn
            bend = wave.interior.contains(torn) ? abs(wave.bend(at: torn)) : 0
            limit = level.breakingLimit
            detail = "Reversal " + String(index + 1) + " (samples " + String(first) + " to " + String(last)
                + ") tore the aurora at seam " + String(torn) + ": a bend of " + String(bend)
                + " against the breaking limit " + String(limit) + "."
        case .budget:
            reversal = play.spent
            start = nil
            end = nil
            seam = nil
            bend = wave.worstBend
            limit = level.bendLimit
            detail = "The reversals ran out: " + String(play.spent) + " of " + String(level.budget) + " spent with "
                + String(matched) + " of " + String(checkpoints) + " checkpoints matched and a worst bend of "
                + String(bend) + " against the limit " + String(limit) + "."
        }
    }

    /// The latest reversal still applied after `records`: reversals push, undos move the top to a redo stack, redos
    /// move it back and a new reversal clears the redo stack, as the play's own stacks do.
    static func latestApplied(_ records: [BackwardsAuroraRecord]) -> BackwardsAuroraAction? {
        var applied: [BackwardsAuroraAction] = []
        var undone: [BackwardsAuroraAction] = []
        for record in records {
            switch record.kind {
            case .reverse:
                if let action = record.action { applied.append(action) }
                undone.removeAll()
            case .undo:
                if let action = applied.popLast() { undone.append(action) }
            case .redo:
                if let action = undone.popLast() { applied.append(action) }
            }
        }
        return applied.last
    }
}
