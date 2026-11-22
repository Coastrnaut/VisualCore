// FacetedForgeHints — feature 375 (R02-G08-05) T-R02G0805-002 (FR-R02G0805-002, 003; SC-R02G0805-002, 003;
// clarifications Q1, Q5; research R1, R2). Progressive hints computed from the current state of a play and the
// plain-English explanation of a failure. Every accepted cut adds exactly one piece, so a winning continuation from the
// current pieces has exactly target pieces − current pieces cuts; the plan is found by the solver's bounded depth-first
// search started at the current pieces (`FacetedForgeSolver.solve(_:from:cutsLeft:workBound:)`: the same cut order,
// pruning and sliver rule as the certification), only when that many cuts are at least one, fit in the cuts left and
// the current pieces can still be partitioned into the target. Its first cut is the hint, so following exact hints from
// any state with a plan wins (a win on the last cut of the budget wins). Hints never change a play, are unlimited and
// do not affect stars; the hint level is presentation (held by the presenter, reset to 1 after any change of the play).
// A failure is explained from the failing cut: the sliver's cut, piece and share, or the spent budget, the pieces made
// and the target's piece count. Exact fractions and integers only; no clock, no random source.

/// The plan of a play from its current state (clarification Q1): the cuts of a winning continuation from the current
/// pieces that fits in the cuts left; the first one is the hint.
public struct FacetedForgePlan: Sendable, Equatable {
    /// The cuts, in play order (piece indices in the canonical order at the time of each cut).
    public let actions: [FacetedForgeAction]

    /// A plan of the given cuts (not checked).
    public init(actions: [FacetedForgeAction]) {
        self.actions = actions
    }
}

/// What a hint suggests (clarification Q1).
public enum FacetedForgeHintKind: String, Sendable, Codable {
    /// Cut one piece.
    case cut
    /// No way to match the target fits in the cuts left (or the play failed): undo or retry.
    case stuck
}

/// One hint of a play (clarification Q1). The suggested cut is the same at every level; only the text reveals more.
public struct FacetedForgeHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the piece, 2 adds the direction, 3 adds the depth (exact).
    public let level: Int
    /// What the hint suggests.
    public let kind: FacetedForgeHintKind
    /// The piece to cut (`cut`), its 0-based canonical index; nil otherwise.
    public let piece: Int?
    /// The direction of the cut (`cut`), 0 … 12; nil otherwise.
    public let direction: Int?
    /// The depth of the cut (`cut`), −24 … 24; nil otherwise.
    public let depth: Int?
    /// The piece in words (`cut`), else empty.
    let pieceName: String
    /// Whether a `stuck` hint is for a failed play.
    let failed: Bool

    /// A hint of the given values (not checked).
    init(level: Int, kind: FacetedForgeHintKind, piece: Int? = nil, direction: Int? = nil, depth: Int? = nil,
         pieceName: String = "", failed: Bool = false) {
        self.level = level
        self.kind = kind
        self.piece = piece
        self.direction = direction
        self.depth = depth
        self.pieceName = pieceName
        self.failed = failed
    }

    /// The text of a failed play's hint, at every level.
    public static let failedText: String = "Undo the last cut or retry the level."
    /// The text shown when no way to match the target fits in the cuts left, at every level.
    public static let stuckText: String =
        "No way to match the target was found in the cuts left: undo the last cut or retry the level."

    /// The hint in plain English (clarification Q1), with (piece) the piece in words — "piece k: s of the crystal,
    /// f faces" (``FacetedForgeLevel/pieceName(_:share:faces:)``) or "the whole crystal" before the first cut — and
    /// (direction) ``FacetedForgeDirection/name``:
    /// - cut: "Cut (piece)", "Cut (piece) in direction (direction)", "Cut (piece) in direction (direction) at depth d"
    /// - stuck: ``failedText`` for a failed play, else ``stuckText``, at every level
    public var text: String {
        switch kind {
        case .stuck:
            return failed ? Self.failedText : Self.stuckText
        case .cut:
            var words: String = "Cut " + pieceName
            if level >= 2, let direction, FacetedForgeDirection.all.indices.contains(direction) {
                words += " in direction " + FacetedForgeDirection.all[direction].name
            }
            if level >= 3, let depth { words += " at depth " + String(depth) }
            return words
        }
    }

    /// The same hint revealed at `level` (clamped to 1 … 3): the suggestion is unchanged, only the text differs
    /// (feature 375, T-R02G0805-012: a presenter caches one search per play and reveals the levels from it).
    public func at(level: Int) -> FacetedForgeHint {
        FacetedForgeHint(level: min(3, max(1, level)), kind: kind, piece: piece, direction: direction, depth: depth,
                         pieceName: pieceName, failed: failed)
    }

    /// The kernel action this hint names; nil for `stuck`.
    public var action: FacetedForgeAction? {
        guard kind == .cut, let piece, let direction, let depth else { return nil }
        return .cut(piece, direction, depth)
    }
}

/// The hint engine of Faceted Forge (clarification Q1).
public enum FacetedForgeHints {
    /// The plan of `play` while `playing` or `paused`: with need = target pieces − current pieces, a winning
    /// continuation of exactly need cuts from the current pieces
    /// (``FacetedForgeSolver/solve(_:from:cutsLeft:workBound:)`` with the default work bound), searched only when
    /// need ≥ 1, need ≤ ``FacetedForgePlay/remaining`` and ``FacetedForgeSolver/canPartition(_:into:crystal:)``
    /// accepts the current pieces. Nil in every other stage and
    /// when no continuation is found.
    public static func plan(_ play: FacetedForgePlay) -> FacetedForgePlan? {
        guard play.stage == .playing || play.stage == .paused else { return nil }
        let level: FacetedForgeLevel = play.level
        let need: Int = level.target.count - play.pieces.count
        guard need >= 1, need <= play.remaining,
              FacetedForgeSolver.canPartition(play.pieces, into: level.target, crystal: level.crystal.volume),
              let solution = FacetedForgeSolver.solve(level, from: play.pieces, cutsLeft: need),
              !solution.actions.isEmpty else { return nil }
        return FacetedForgePlan(actions: solution.actions)
    }

    /// Piece `index` of `play` in words: "the whole crystal" for a share of one, else
    /// ``FacetedForgeLevel/pieceName(_:share:faces:)``.
    static func pieceName(_ index: Int, play: FacetedForgePlay) -> String {
        guard play.pieces.indices.contains(index), play.shares.indices.contains(index) else {
            return "piece " + String(index + 1)
        }
        let share: FacetedForgeFraction = play.shares[index]
        if share == .one { return FacetedForgeLevel.shareText(share) }
        return play.level.pieceName(index, share: share, faces: play.pieces[index].faceCount)
    }

    /// The hint of `level` (clamped to 1 … 3) for `play`: while `playing` or `paused`, the plan's first cut (`cut`
    /// with its piece, direction and depth), `stuck` with ``FacetedForgeHint/stuckText`` when there is no plan; when
    /// `failed` (or `result` after a failure), `stuck` with ``FacetedForgeHint/failedText``; nil in every other stage
    /// (loading, tutorial, won, result after a win). The same cut is returned at every level; the play is not changed.
    public static func hint(level: Int, play: FacetedForgePlay) -> FacetedForgeHint? {
        let clamped: Int = min(3, max(1, level))
        switch play.stage {
        case .playing, .paused: break
        case .failed: return FacetedForgeHint(level: clamped, kind: .stuck, failed: true)
        case .result:
            return play.failure == nil ? nil : FacetedForgeHint(level: clamped, kind: .stuck, failed: true)
        case .loading, .tutorial, .won: return nil
        }
        guard let first = plan(play)?.actions.first else { return FacetedForgeHint(level: clamped, kind: .stuck) }
        switch first {
        case .cut(let piece, let direction, let depth):
            return FacetedForgeHint(level: clamped, kind: .cut, piece: piece, direction: direction, depth: depth,
                                    pieceName: pieceName(piece, play: play))
        }
    }
}

/// The plain-English explanation of a failed play (FR-R02G0805-003; clarification Q5), from the failing cut.
public struct FacetedForgeFailureExplanation: Sendable, Equatable {
    /// Why the play failed.
    public let failure: FacetedForgeFailure
    /// The cut named, 1-based: the sliver's cut (its cut index + 1), or the cuts spent for `budget`.
    public let cut: Int
    /// The sliver piece (`sliver`), its 0-based canonical index after the failing cut; nil for `budget`.
    public let piece: Int?
    /// The sliver piece's share of the crystal (`sliver`); nil for `budget`.
    public let share: FacetedForgeFraction?
    /// The pieces at the failure.
    public let pieces: Int
    /// The target's piece count.
    public let target: Int
    /// The explanation's sentence before the shared advice.
    private let detail: String

    /// The advice that ends every explanation.
    public static let advice: String = "Undo the last cut or retry the level."

    /// The explanation (clarification Q5), with p the piece's 1-based number and s its share in words
    /// (``FacetedForgeLevel/shareText(_:)``):
    /// - sliver: "Cut c left piece p at s of the crystal, thinner than the sliver limit of (limit)."
    /// - budget: "The cuts ran out: b of B spent with n pieces; the target has m."
    ///
    /// each followed by a space and ``advice``.
    public var text: String { detail + " " + Self.advice }

    /// The explanation of `play`'s failure, or nil unless the play is `failed` (or `result` after a failure).
    public init?(play: FacetedForgePlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        let level: FacetedForgeLevel = play.level
        self.failure = failure
        pieces = play.pieces.count
        target = level.target.count
        switch failure {
        case .sliver(let index, let cutIndex):
            guard play.shares.indices.contains(index) else { return nil }
            let pieceShare: FacetedForgeFraction = play.shares[index]
            cut = cutIndex + 1
            piece = index
            share = pieceShare
            detail = "Cut " + String(cutIndex + 1) + " left piece " + String(index + 1) + " at "
                + FacetedForgeLevel.shareText(pieceShare) + " of the crystal, thinner than the sliver limit of "
                + level.sliver.text + "."
        case .budget:
            cut = play.cuts
            piece = nil
            share = nil
            detail = "The cuts ran out: " + String(play.cuts) + " of " + String(level.budget) + " spent with "
                + String(play.pieces.count) + " pieces; the target has " + String(level.target.count) + "."
        }
    }
}
