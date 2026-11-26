// MicroscopicAuroraPuzzle — feature 481 (R02-G19-01) T-R02G1901-005 (FR-R02G1901-010; clarification Q5).
// Microscopic Aurora expressed as an R02-F23 puzzle contract so later features can certify levels with
// `PuzzleValidator`: a state is a `Position` (the three well slots and the actions spent), a move is a
// `MicroscopicAuroraAction` placement or removal, and a state is solved when the predicted play wins
// (`MicroscopicAuroraDish.report(level, wells:).wins`). While actions are left the legal moves are, in exactly this
// order: first the placements, by slot 0 … 2, within a slot by usable cell in row-major order (cells whose centre lies
// inside the enclosure, `MicroscopicAuroraLevel.isUsable`), skipping a cell another slot's well occupies, within a cell
// by strength 1 … 4 and within a strength by sense (clockwise, then counterclockwise), skipping the slot's current
// well; then `remove(slot)` for each occupied slot, ascending. With the budget spent nothing is legal. A move list
// holds up to about 3 · 380 · 8 + 3 ≈ 9,100 moves (radius 11), above `FairnessBudget.maxBranching` (1,024): a
// certification search must narrow the moves (for example to the level's candidate cells) before it uses this
// contract. The usable cells are computed once in `init`, so `moves(in:)` is one pass with no swim. Applying a move
// mirrors the play's `apply(_:expecting:)`: the slot takes the well or is emptied and 1 action is spent; a move the
// play would refuse (a slot, cell or strength out of range, an unchanged well, a cell another well occupies or outside
// the enclosure, removing an empty slot, no action left, or the play) is refused (nil). The play is not a move: it
// spends nothing and only reveals the outcome that `isSolved` already predicts. The rules carry no stage,
// fingerprints, report, failure, records, undo or redo: those belong to the play. Integers only; no clock, no random
// source. Modelled on `ApsidesWorkshopRules` (feature 471).
import VisualCoreSimulation

/// The pure rules of one Microscopic Aurora level as an R02-F23 puzzle contract.
public struct MicroscopicAuroraPuzzle: PuzzleRules {
    /// A position of a Microscopic Aurora play as the rules see it: the well slots and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The wells, one entry per slot (nil for an empty slot).
        public let wells: [MicroscopicAuroraWell?]
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(wells: [MicroscopicAuroraWell?], actionsSpent: Int) {
            self.wells = wells
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the wells and the actions spent.
    public typealias State = Position
    /// A player action: a placement or a removal (the play is never a legal move).
    public typealias Move = MicroscopicAuroraAction

    /// The level whose enclosure, swarm, stencil, targets and budget decide the results.
    public let level: MicroscopicAuroraLevel
    /// The cells a well may stand on, row-major: the usable cells, or the level's sites (feature 482).
    let usableCells: [MicroscopicAuroraCell]

    /// The rules of `level`.
    public init(level: MicroscopicAuroraLevel) {
        self.level = level
        var cells: [MicroscopicAuroraCell] = []
        for row in 0..<MicroscopicAuroraDish.cells {
            for column in 0..<MicroscopicAuroraDish.cells {
                let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: row, column: column)
                if level.allows(cell) { cells.append(cell) }
            }
        }
        self.usableCells = cells
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g19-microscopic-aurora" }

    /// The start position: the level's starting wells, no action spent.
    public var initialState: Position {
        Position(wells: level.wells, actionsSpent: 0)
    }

    /// Whether `state` can take a placement or removal: three slots and an action left.
    func isOpen(_ state: Position) -> Bool {
        state.wells.count == MicroscopicAuroraLevel.slots && state.actionsSpent >= 0
            && state.actionsSpent < level.budget
    }

    /// Whether another slot than `slot` holds a well on `cell`.
    func isOccupied(_ cell: MicroscopicAuroraCell, otherThan slot: Int, in wells: [MicroscopicAuroraWell?]) -> Bool {
        for other in 0..<wells.count where other != slot {
            if let well = wells[other], well.cell == cell { return true }
        }
        return false
    }

    /// The legal moves: none with the budget spent; otherwise every placement (slots ascending, usable cells
    /// row-major within a slot, skipping cells another well occupies, strengths 1 … 4 ascending within a cell, senses
    /// clockwise then counterclockwise within a strength, skipping the slot's current well), then `remove(slot)` for
    /// each occupied slot ascending.
    public func moves(in state: Position) -> [MicroscopicAuroraAction] {
        guard isOpen(state) else { return [] }
        let wells: [MicroscopicAuroraWell?] = state.wells
        var result: [MicroscopicAuroraAction] = []
        result.reserveCapacity(MicroscopicAuroraLevel.slots * usableCells.count * 8 + MicroscopicAuroraLevel.slots)
        for slot in 0..<MicroscopicAuroraLevel.slots {
            let current: MicroscopicAuroraWell? = wells[slot]
            for cell in usableCells where !isOccupied(cell, otherThan: slot, in: wells) {
                for strength in MicroscopicAuroraWell.strengths {
                    for sense in MicroscopicAuroraSense.allCases {
                        let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: cell, strength: strength,
                                                                                 sense: sense)
                        if well != current { result.append(.place(slot: slot, well: well)) }
                    }
                }
            }
        }
        for slot in 0..<MicroscopicAuroraLevel.slots where wells[slot] != nil {
            result.append(.remove(slot: slot))
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the slot takes the well or is emptied and 1
    /// action is spent. Refused: the play, a slot out of 0 … 2, a strength out of 1 … 4, a cell off the dish or outside
    /// the enclosure, a cell another slot's well occupies, a well equal to the slot's current one, removing an empty
    /// slot, no action left.
    public func apply(_ move: MicroscopicAuroraAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        var wells: [MicroscopicAuroraWell?] = state.wells
        let slots: Range<Int> = 0..<MicroscopicAuroraLevel.slots
        switch move {
        case .play:
            return nil
        case .place(let slot, let well):
            guard slots.contains(slot), MicroscopicAuroraWell.strengths.contains(well.strength),
                  level.allows(well.cell),
                  !isOccupied(well.cell, otherThan: slot, in: wells), wells[slot] != well else { return nil }
            wells[slot] = well
        case .remove(let slot):
            guard slots.contains(slot), wells[slot] != nil else { return nil }
            wells[slot] = nil
        }
        return Position(wells: wells, actionsSpent: state.actionsSpent + 1)
    }

    /// Whether a play from `state` would win: the predicted report of its placed wells (in slot order) meets every
    /// target (false for a position without three slots).
    public func isSolved(_ state: Position) -> Bool {
        guard state.wells.count == MicroscopicAuroraLevel.slots else { return false }
        let placed: [MicroscopicAuroraWell] = state.wells.compactMap { $0 }
        return MicroscopicAuroraDish.report(level, wells: placed).wins
    }
}
