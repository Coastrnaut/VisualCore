// NocturneGardenHints — feature 385 (R02-G09-05) T-R02G0905-002 (FR-R02G0905-002, 003; SC-R02G0905-002, 003;
// clarifications Q1, Q5). Progressive hints computed from the current state of a play and the plain-English explanation
// of a failure. The plan is the solver's bounded search from the current blooms and sun
// (`NocturneGardenSolver.solve(_:from:sun:movesLeft:supplyLeft:workBound:)`): the fewest further moves that win within
// the moves and supply left — plants at the current sun or a sun move first, then the removal of one planted bloom
// first — replayed on a copy of the play before it is offered. Its first move is the hint, so following exact hints
// from any state with a plan wins (a win on the last move of the budget wins). Hints never change a play, are unlimited
// and do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the
// play). A failure is explained from the failing move: the kernel's leak reason, or the spent budget and the match
// reached against the one required. Integers only; no clock, no random source.
import Foundation

/// The plan of a play from its current state (clarification Q1): the moves of a winning continuation that fits in the
/// moves and supply left; the first one is the hint.
public struct NocturneGardenPlan: Sendable, Equatable {
    /// The moves, in play order (bloom indices in the canonical order at the time of each move).
    public let actions: [NocturneGardenAction]

    /// A plan of the given moves (not checked).
    public init(actions: [NocturneGardenAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum NocturneGardenHintKind: String, Sendable, Codable {
    /// Make one move: plant a bloom, set the sun or remove a bloom.
    case move
    /// No way to match the target fits in the moves left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested move is the same at every level; only the text reveals more.
public struct NocturneGardenHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the move, 2 adds the size and sun, 3 adds the exact cell.
    public let level: Int
    /// What the hint suggests.
    public let kind: NocturneGardenHintKind
    /// The suggested kernel action (`move`); nil for `stuck`.
    public let action: NocturneGardenAction?
    /// The sun elevation of the play when the hint was asked.
    let elevation: Int
    /// The bloom the action names (`remove`, `move`, `resize`), as planted; nil otherwise.
    let bloom: NocturneGardenBloom?
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (not checked).
    init(level: Int, kind: NocturneGardenHintKind, action: NocturneGardenAction? = nil, elevation: Int = 0,
         bloom: NocturneGardenBloom? = nil, failed: Bool = false) {
        self.level = level
        self.kind = kind
        self.action = action
        self.elevation = elevation
        self.bloom = bloom
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last move or retry the level."
    /// The text shown when no way to match the target was found in the moves left, at every level.
    public static let stuckText: String =
        "No way to match the target was found in the moves left: undo the last move or retry the level."

    /// The sun `elevation` in hint words: "3 of 4" at level 1, "3 of 4, lower middle, shadows one and a half times as
    /// tall" from level 2 (``NocturneGardenLevel/sunName(_:)`` without its leading "sun ").
    static func sunWords(_ elevation: Int, full: Bool) -> String {
        var words: String = NocturneGardenLevel.sunName(elevation)
        if words.hasPrefix("sun ") { words = String(words.dropFirst(4)) }
        if !full, let comma = words.firstIndex(of: ",") { words = String(words[..<comma]) }
        return words
    }

    /// "a" or "an" before `word`.
    static func article(_ word: String) -> String {
        guard let first = word.first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    /// The hint in plain English (clarification Q1), with k the bloom kind, s its size, (c, r) its anchor and e the
    /// current sun:
    /// - plant: "Plant a k", "Plant a k of size s under sun e of 4", "Plant a k of size s under sun e of 4 at column c,
    ///   row r"
    /// - sun: "Set the sun to e of 4", then "Set the sun to e of 4, (height), (shadow length)" at levels 2 and 3
    /// - remove: "Remove bloom n", "Remove bloom n, a k of size s", "Remove bloom n, a k of size s at column c, row r"
    /// - move: "Move bloom n", "Move bloom n, a k of size s", "Move bloom n, a k of size s to column c, row r"
    /// - resize: "Resize bloom n", "Resize bloom n, a k, to size s", "Resize bloom n, a k at column c, row r, to size
    ///   s"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        guard kind == .move, let action else { return failed ? Self.failedText : Self.stuckText }
        switch action {
        case let .plant(kind, column, row, size):
            var words: String = "Plant " + Self.article(kind.name) + " " + kind.name
            if level >= 2 {
                words += " of size " + String(size) + " under sun " + Self.sunWords(elevation, full: false)
            }
            if level >= 3 { words += " at column " + String(column) + ", row " + String(row) }
            return words
        case let .sun(value):
            return "Set the sun to " + Self.sunWords(value, full: level >= 2)
        case let .remove(index):
            var words: String = "Remove bloom " + String(index + 1)
            if level >= 2, let bloom { words += ", " + Self.article(bloom.kind.name) + " " + bloom.kind.name
                + " of size " + String(bloom.size) }
            if level >= 3, let bloom { words += " at column " + String(bloom.column) + ", row " + String(bloom.row) }
            return words
        case let .move(index, column, row):
            var words: String = "Move bloom " + String(index + 1)
            if level >= 2, let bloom { words += ", " + Self.article(bloom.kind.name) + " " + bloom.kind.name
                + " of size " + String(bloom.size) }
            if level >= 3 { words += " to column " + String(column) + ", row " + String(row) }
            return words
        case let .resize(index, size):
            var words: String = "Resize bloom " + String(index + 1)
            if level >= 2, let bloom {
                words += ", " + Self.article(bloom.kind.name) + " " + bloom.kind.name
                if level >= 3 { words += " at column " + String(bloom.column) + ", row " + String(bloom.row) }
                words += ", to size " + String(size)
            }
            return words
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs (a
    /// presenter can cache one search per play and reveal the levels from it).
    public func at(level: Int) -> NocturneGardenHint {
        NocturneGardenHint(level: min(3, max(1, level)), kind: kind, action: action, elevation: elevation,
                           bloom: bloom, failed: failed)
    }
}

/// The hint engine of Nocturne Garden (clarification Q1).
public enum NocturneGardenHints {
    /// The supply left of `play`: per kind with a supply, the blooms not yet planted.
    static func supplyLeft(_ play: NocturneGardenPlay) -> [NocturneGardenKind: Int] {
        var supply: [NocturneGardenKind: Int] = [:]
        for kind in NocturneGardenKind.allCases where play.level.supplyCount(kind) > 0 {
            supply[kind] = max(0, play.available(kind))
        }
        return supply
    }

    /// The plan of `play` while `playing` or `paused` with at least one move left: the solver's continuation
    /// (``NocturneGardenSolver/solve(_:from:sun:movesLeft:supplyLeft:workBound:)`` with the default work bound) from
    /// the play's blooms and sun within its moves and supply left, offered only when it replays on a copy of the play
    /// (resumed when paused) with every move accepted and a win on the last one. Nil in every other stage and when no
    /// continuation is found.
    public static func plan(_ play: NocturneGardenPlay) -> NocturneGardenPlan? {
        guard play.stage == .playing || play.stage == .paused, play.remaining >= 1,
              let solution = NocturneGardenSolver.solve(play.level, from: play.blooms, sun: play.elevation,
                                                        movesLeft: play.remaining, supplyLeft: supplyLeft(play)),
              !solution.actions.isEmpty else { return nil }
        var copy: NocturneGardenPlay = play
        if copy.stage == .paused {
            do { try copy.handle(.resume) } catch { return nil }
        }
        for action in solution.actions {
            guard copy.stage == .playing else { return nil }
            do { try copy.apply(action, expecting: copy.fingerprint) } catch { return nil }
        }
        guard copy.stage == .won else { return nil }
        return NocturneGardenPlan(actions: solution.actions)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first move (`move`),
    /// `stuck` with ``NocturneGardenHint/stuckText`` when there is no plan; when `failed` (or `result` after a
    /// failure), `stuck` with ``NocturneGardenHint/failedText``; nil in every other stage (loading, tutorial, won,
    /// result after a win). The same move is returned at every level; the play is not changed.
    public static func hint(level: Int, play: NocturneGardenPlay) -> NocturneGardenHint? {
        let clamped: Int = min(3, max(1, level))
        switch play.stage {
        case .playing, .paused: break
        case .failed: return NocturneGardenHint(level: clamped, kind: .stuck, elevation: play.elevation, failed: true)
        case .result:
            guard play.failure != nil else { return nil }
            return NocturneGardenHint(level: clamped, kind: .stuck, elevation: play.elevation, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else {
            return NocturneGardenHint(level: clamped, kind: .stuck, elevation: play.elevation)
        }
        var bloom: NocturneGardenBloom?
        switch first {
        case let .remove(index), let .move(index, _, _), let .resize(index, _):
            if play.blooms.indices.contains(index) { bloom = play.blooms[index] }
        case .plant, .sun:
            bloom = nil
        }
        return NocturneGardenHint(level: clamped, kind: .move, action: first, elevation: play.elevation, bloom: bloom)
    }
}

/// The plain-English explanation of a failed play (FR-R02G0905-003; clarification Q5), from the failing move.
public struct NocturneGardenFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: NocturneGardenFailure
    /// The move named, 1-based: the leaking move (its index + 1), or the moves spent for `budget`.
    public let move: Int
    /// The dark cells in the forbidden regions at the failure.
    public let leak: Int
    /// The leak the level allows.
    public let allowed: Int
    /// The match at the failure: the cells dark and in the target.
    public let shared: Int
    /// The match at the failure: the cells dark or in the target.
    public let either: Int
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last move or retry the level."

    /// The explanation (clarification Q5):
    /// - leak: the kernel's reason (``NocturneGardenPlay/failureReason``) with its first letter upper-cased and a full
    ///   stop: "The shadow leaked into k cells of the forbidden regions at move m (…the action…), a allowed."
    /// - budget: "The moves ran out: b of b spent with a match of x/y; it needs p/q."
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure).
    public init?(play: NocturneGardenPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: NocturneGardenLevel = play.level
        let match: (shared: Int, either: Int) = play.match
        self.failure = failure
        leak = play.leak
        allowed = level.leakAllowance
        shared = match.shared
        either = match.either
        switch failure {
        case .leak(let index):
            move = index + 1
            var reason: String = play.failureReason
                ?? ("the shadow leaked into \(NocturneGardenLevel.cellsText(play.leak)) of the forbidden regions at "
                    + "move \(index + 1), \(level.leakAllowance) allowed")
            if let first = reason.first { reason = first.uppercased() + reason.dropFirst() }
            if !reason.hasSuffix(".") { reason += "." }
            detail = reason
        case .budget:
            move = play.moves
            detail = "The moves ran out: " + String(play.moves) + " of " + String(level.budget)
                + " spent with a match of " + String(match.shared) + "/" + String(match.either) + "; it needs "
                + level.required.text + "."
        }
    }
}
