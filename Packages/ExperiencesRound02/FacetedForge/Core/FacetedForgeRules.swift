// FacetedForgeRules — feature 371 (R02-G08-01) T-R02G0801-005. Faceted Forge expressed as an R02-F23 puzzle contract
// so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the pieces in canonical order,
// the cuts spent and the outcome), a move is a `FacetedForgeAction`, and a state is solved when its outcome is `won`.
// While playing the moves are every non-degenerate cut, in this exact order: pieces in canonical order, directions
// 0 … 12, depths ascending over −24 … 24 where the plane passes through the piece's interior. A won or failed position
// offers nothing. Applying a cut mirrors `FacetedForgePlay.apply(_:expecting:)`: the piece is replaced by its two
// halves, the pieces are put back in canonical order, one cut is spent, and the outcome is judged — the sliver first (a
// new half whose share of the crystal is strictly below the level's sliver limit fails), then the win (the multiset of
// (share, face count) equals the target), then the budget (cuts spent equal to the budget fails). A move not listed in
// `moves(in:)`, or one whose exact arithmetic overflows (which the play refuses too), is refused (nil). The rules carry
// no stage, fingerprints, undo, redo or records: those belong to the play.
import VisualCoreSimulation

/// The pure rules of one Faceted Forge level as an R02-F23 puzzle contract.
public struct FacetedForgeRules: PuzzleRules {
    /// A position of a Faceted Forge play as the rules see it: the pieces, the cuts spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Cuts are still possible.
            case playing
            /// The pieces match the target.
            case won
            /// A cut left a sliver or the budget ran out.
            case failed
        }

        /// The pieces, in canonical order (``FacetedForgePiece/canonical(_:)``).
        public let pieces: [FacetedForgePiece]
        /// The cuts spent, 0 … the level's budget.
        public let cuts: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(pieces: [FacetedForgePiece], cuts: Int, outcome: Outcome) {
            self.pieces = pieces
            self.cuts = cuts
            self.outcome = outcome
        }
    }

    /// A position: pieces, cuts spent and outcome.
    public typealias State = Position
    /// A player action: a cut of one piece by one plane.
    public typealias Move = FacetedForgeAction

    /// The level whose crystal, budget, sliver limit and target decide the results.
    public let level: FacetedForgeLevel

    /// The rules of `level`.
    public init(level: FacetedForgeLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g08-faceted-forge" }

    /// The start position: the whole crystal as its one piece, no cut spent, still playing.
    public var initialState: Position {
        Position(pieces: [level.crystal], cuts: 0, outcome: .playing)
    }

    /// The legal moves: none once won or failed; otherwise every cut whose plane passes through a piece's interior,
    /// pieces in canonical order, then directions 0 … 12, then depths ascending over −24 … 24.
    public func moves(in state: Position) -> [FacetedForgeAction] {
        guard state.outcome == .playing else { return [] }
        var result: [FacetedForgeAction] = []
        for piece in state.pieces.indices {
            for direction in FacetedForgeDirection.all.indices {
                for depth in FacetedForgeHalfSpace.depths
                where state.pieces[piece].isCrossed(direction: direction, depth: depth) {
                    result.append(.cut(piece, direction, depth))
                }
            }
        }
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)`` or its exact arithmetic overflows.
    /// The piece is replaced by its halves (canonical order kept), one cut is spent, and the outcome is judged: sliver,
    /// then win, then budget, exactly as ``FacetedForgePlay`` judges it.
    public func apply(_ move: FacetedForgeAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        guard case .cut(let index, let direction, let depth) = move,
              FacetedForgePlay.inRange(move, pieces: state.pieces.count) else { return nil }
        let halves: (below: FacetedForgePiece, above: FacetedForgePiece)
        do {
            halves = try state.pieces[index].cut(direction: direction, depth: depth)
        } catch {
            return nil
        }
        var rest: [FacetedForgePiece] = state.pieces
        rest.remove(at: index)
        let next: [FacetedForgePiece] = FacetedForgePiece.canonical(rest + [halves.below, halves.above])
        var shares: [FacetedForgeFraction] = []
        shares.reserveCapacity(next.count)
        for piece in next {
            guard let share = try? piece.volume.dividing(by: level.crystal.volume) else { return nil }
            shares.append(share)
        }
        let cuts: Int = state.cuts + 1
        var outcome: Position.Outcome = .playing
        if FacetedForgePlay.sliverIndex(next, shares: shares, halves: halves, limit: level.sliver) != nil {
            outcome = .failed
        } else if FacetedForgePlay.matches(next, shares: shares, target: level.target) {
            outcome = .won
        } else if cuts >= level.budget {
            outcome = .failed
        }
        return Position(pieces: next, cuts: cuts, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
