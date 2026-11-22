// NocturneGardenRules — feature 381 (R02-G09-01) T-R02G0901-005 (FR-R02G0901-010). Nocturne Garden expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// blooms in canonical order, the sun elevation, the moves spent and the outcome), a move is a `NocturneGardenAction`,
// and a state is solved when its outcome is `won`. While playing the legal moves are, in this exact order: plants by
// kind (case order), row 0 … height − 1, column 0 … width − 1 and allowed size ascending, for every kind with supply
// left; then moves by bloom (every cell of the bed but the bloom's own, rows then columns); then resizes by bloom
// (every allowed size but its own, ascending); then removals by bloom; then the sun (every allowed elevation but the
// current one, ascending). A won or failed position offers nothing. Applying a move mirrors the play's
// `apply(_:expecting:)`: only what the action names changes, the blooms are put back in canonical order, one move is
// spent, the shadow mask is recomputed from scratch and the outcome is judged — the leak first (forbidden cells beyond
// the allowance fail), then the win (at least one bloom and the required match), then the budget (moves spent equal
// to the budget fail). A move the play would refuse (out of range, no supply, a no-op) is refused (nil). The rules
// carry no stage, fingerprints, undo, redo or records: those belong to the play. Integers only; no clock, no random
// source.
import VisualCoreSimulation

/// The pure rules of one Nocturne Garden level as an R02-F23 puzzle contract.
public struct NocturneGardenRules: PuzzleRules {
    /// A position of a Nocturne Garden play as the rules see it: the blooms, the sun, the moves spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// The shadow matches the target.
            case won
            /// The shadow leaked or the budget ran out.
            case failed
        }

        /// The planted blooms, in canonical order (``NocturneGardenBloom/<(_:_:)``); bloom operands index this array.
        public let blooms: [NocturneGardenBloom]
        /// The sun elevation (1 high … 4 low).
        public let sun: Int
        /// The moves spent, 0 … the level's budget.
        public let moves: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(blooms: [NocturneGardenBloom], sun: Int, moves: Int, outcome: Outcome) {
            self.blooms = blooms
            self.sun = sun
            self.moves = moves
            self.outcome = outcome
        }
    }

    /// A position: blooms, sun, moves spent and outcome.
    public typealias State = Position
    /// A player action: plant, move, resize, remove or sun.
    public typealias Move = NocturneGardenAction

    /// The level whose bed, supply, sizes, elevations, budget, target, forbidden regions and match decide the results.
    public let level: NocturneGardenLevel

    /// The rules of `level`.
    public init(level: NocturneGardenLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g09-nocturne-garden" }

    /// The start position: no bloom planted, the level's opening sun, no move spent, still playing.
    public var initialState: Position {
        Position(blooms: [], sun: level.sun, moves: 0, outcome: .playing)
    }

    /// The level's allowed sizes, ascending.
    public var sizes: [Int] { level.sizes.sorted() }

    /// The level's allowed sun elevations, ascending.
    public var elevations: [Int] { level.elevations.sorted() }

    /// How many blooms of `kind` are still in the supply in `state`: the level's count less those planted.
    public func available(_ kind: NocturneGardenKind, in state: Position) -> Int {
        var planted: Int = 0
        for bloom in state.blooms where bloom.kind == kind { planted += 1 }
        return level.supplyCount(kind) - planted
    }

    /// The legal moves: none once won or failed; otherwise plants by kind (case order, kinds with supply left), row,
    /// column and size ascending; then moves by bloom (every other cell, rows then columns); then resizes by bloom
    /// (every other allowed size); then removals by bloom; then the sun (every other allowed elevation).
    public func moves(in state: Position) -> [NocturneGardenAction] {
        guard state.outcome == .playing else { return [] }
        let sizes: [Int] = self.sizes
        var result: [NocturneGardenAction] = []
        for kind in NocturneGardenKind.allCases where available(kind, in: state) > 0 {
            for row in 0..<level.height {
                for column in 0..<level.width {
                    for size in sizes { result.append(.plant(kind, column, row, size)) }
                }
            }
        }
        for index in state.blooms.indices {
            let bloom: NocturneGardenBloom = state.blooms[index]
            for row in 0..<level.height {
                for column in 0..<level.width where column != bloom.column || row != bloom.row {
                    result.append(.move(index, column, row))
                }
            }
        }
        for index in state.blooms.indices {
            for size in sizes where size != state.blooms[index].size { result.append(.resize(index, size)) }
        }
        for index in state.blooms.indices { result.append(.remove(index)) }
        for elevation in elevations where elevation != state.sun { result.append(.sun(elevation)) }
        return result
    }

    /// Whether (column, row) is a cell of the bed.
    private func inBed(_ column: Int, _ row: Int) -> Bool {
        column >= 0 && column < level.width && row >= 0 && row < level.height
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. Only what the action names changes,
    /// the blooms are kept in canonical order, one move is spent, the mask is recomputed and the outcome is judged:
    /// leak, then win, then budget, exactly as ``NocturneGardenPlay`` judges it.
    public func apply(_ move: NocturneGardenAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        var next: [NocturneGardenBloom] = state.blooms
        var sun: Int = state.sun
        switch move {
        case let .plant(kind, column, row, size):
            guard inBed(column, row), level.sizes.contains(size), available(kind, in: state) > 0 else { return nil }
            next.append(NocturneGardenBloom(kind: kind, column: column, row: row, size: size))
        case let .move(index, column, row):
            guard state.blooms.indices.contains(index), inBed(column, row) else { return nil }
            let old: NocturneGardenBloom = state.blooms[index]
            guard old.column != column || old.row != row else { return nil }
            next[index] = NocturneGardenBloom(kind: old.kind, column: column, row: row, size: old.size)
        case let .resize(index, size):
            guard state.blooms.indices.contains(index), level.sizes.contains(size) else { return nil }
            let old: NocturneGardenBloom = state.blooms[index]
            guard old.size != size else { return nil }
            next[index] = NocturneGardenBloom(kind: old.kind, column: old.column, row: old.row, size: size)
        case let .remove(index):
            guard state.blooms.indices.contains(index) else { return nil }
            next.remove(at: index)
        case let .sun(elevation):
            guard level.elevations.contains(elevation), elevation != state.sun else { return nil }
            sun = elevation
        }
        next.sort()
        let moves: Int = state.moves + 1
        let mask: NocturneGardenMask = NocturneGardenMask.union(next, elevation: sun, width: level.width,
                                                                height: level.height)
        var outcome: Position.Outcome = .playing
        if mask.leak(forbidden: level.forbidden) > level.leakAllowance {
            outcome = .failed
        } else if !next.isEmpty && NocturneGardenMask.matches(mask: mask, target: level.target,
                                                               required: level.required) {
            outcome = .won
        } else if moves >= level.budget {
            outcome = .failed
        }
        return Position(blooms: next, sun: sun, moves: moves, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
