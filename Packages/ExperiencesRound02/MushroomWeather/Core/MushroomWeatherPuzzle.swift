// MushroomWeatherPuzzle — feature 491 (R02-G20-01) T-R02G2001-005 (FR-R02G2001-010; clarification Q5). Mushroom
// Weather expressed as an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state
// is a `Position` (the arrangement — the pod of every slot, every vent's state and the moonlight — and the actions
// spent), a move is a `MushroomWeatherAction` arrangement action (place, remove, vent, moonlight; never the run), and a
// state is solved when the predicted run wins (`MushroomWeatherForest.report(level, arrangement:).wins`). While actions
// are left the legal moves are, in exactly this order: first the placements, by slot 0 … P − 1, within a slot by
// placeable cell in row-major order (floor cells no colony stands on), skipping a cell another slot's pod occupies and
// the slot's current cell; then `remove(slot)` for each occupied slot, ascending; then `vent(index, open: !current)`
// for each vent, ascending; then `moonlight(level)` for each level 0 … 3 other than the current one. With the budget
// spent nothing is legal. A move list holds at most 6 · 167 + 6 + 6 + 3 = 1,017 moves (a 12 × 14 floor with one
// colony), within `FairnessBudget.maxBranching` (1,024). The placeable cells are computed once in `init`, so
// `moves(in:)` is one pass with no run. Applying a move mirrors the play's `apply(_:expecting:)`: the slot takes the pod
// or is emptied, the vent is opened or closed, or the moonlight is set, and 1 action is spent; a move the play would
// refuse (a slot, vent or moonlight out of range, a cell off the floor, on a colony or under another slot's pod, an
// unchanged value, removing an empty slot, no action left, or the run) is refused (nil). The run is not a move: it
// spends nothing and only reveals the outcome that `isSolved` already predicts. The rules carry no stage, fingerprints,
// report, failure, records, undo or redo: those belong to the play. Integers only; no clock, no random source.
// Modelled on `MicroscopicAuroraPuzzle` (feature 481).
import VisualCoreSimulation

/// The pure rules of one Mushroom Weather level as an R02-F23 puzzle contract.
public struct MushroomWeatherPuzzle: PuzzleRules {
    /// A position of a Mushroom Weather play as the rules see it: the arrangement and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The arrangement: the pod of every slot, every vent's state and the moonlight.
        public let arrangement: MushroomWeatherArrangement
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(arrangement: MushroomWeatherArrangement, actionsSpent: Int) {
            self.arrangement = arrangement
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the arrangement and the actions spent.
    public typealias State = Position
    /// A player action: a placement, removal, vent change or moonlight change (the run is never a legal move).
    public typealias Move = MushroomWeatherAction

    /// The level whose floor, weather, vents, pods, colonies and budget decide the results.
    public let level: MushroomWeatherLevel
    /// The placeable cells of the level (floor cells no colony stands on), row-major.
    let placeableCells: [MushroomWeatherCell]

    /// The rules of `level`.
    public init(level: MushroomWeatherLevel) {
        self.level = level
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        var cells: [MushroomWeatherCell] = []
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: MushroomWeatherCell = MushroomWeatherCell(row: row, column: column)
                if level.isFloor(cell) && !colonies.contains(cell) { cells.append(cell) }
            }
        }
        self.placeableCells = cells
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g20-mushroom-weather" }

    /// The start position: the level's starting arrangement, no action spent.
    public var initialState: Position {
        Position(arrangement: level.start, actionsSpent: 0)
    }

    /// Whether `arrangement` has the level's shape: one entry per pod slot and per vent, and a moonlight of 0 … 3.
    func isWellFormed(_ arrangement: MushroomWeatherArrangement) -> Bool {
        arrangement.pods.count == level.podRules.slots && arrangement.ventsOpen.count == level.vents.count
            && MushroomWeatherLevel.moonlightLevels.contains(arrangement.moonlight)
    }

    /// Whether `state` can take an arrangement action: a well-formed arrangement and an action left.
    func isOpen(_ state: Position) -> Bool {
        isWellFormed(state.arrangement) && state.actionsSpent >= 0 && state.actionsSpent < level.budget
    }

    /// Whether another slot than `slot` holds a pod on `cell`.
    func isOccupied(_ cell: MushroomWeatherCell, otherThan slot: Int, in pods: [MushroomWeatherCell?]) -> Bool {
        for other in 0..<pods.count where other != slot && pods[other] == cell { return true }
        return false
    }

    /// The legal moves: none with the budget spent; otherwise every placement (slots ascending, placeable cells
    /// row-major within a slot, skipping cells another slot's pod occupies and the slot's current cell), then
    /// `remove(slot)` for each occupied slot ascending, then `vent(index, open: !current)` for each vent ascending, then
    /// `moonlight(level)` for each level 0 … 3 other than the current one.
    public func moves(in state: Position) -> [MushroomWeatherAction] {
        guard isOpen(state) else { return [] }
        let pods: [MushroomWeatherCell?] = state.arrangement.pods
        let vents: [Bool] = state.arrangement.ventsOpen
        var result: [MushroomWeatherAction] = []
        result.reserveCapacity(pods.count * placeableCells.count + pods.count + vents.count + 3)
        for slot in 0..<pods.count {
            for cell in placeableCells where pods[slot] != cell && !isOccupied(cell, otherThan: slot, in: pods) {
                result.append(.place(slot: slot, cell: cell))
            }
        }
        for slot in 0..<pods.count where pods[slot] != nil {
            result.append(.remove(slot: slot))
        }
        for index in 0..<vents.count {
            result.append(.vent(index: index, open: !vents[index]))
        }
        for moonlight in MushroomWeatherLevel.moonlightLevels where moonlight != state.arrangement.moonlight {
            result.append(.moonlight(level: moonlight))
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the slot takes the pod or is emptied, the vent
    /// is opened or closed, or the moonlight is set, and 1 action is spent. Refused: the run, a slot out of
    /// 0 … P − 1, a cell off the floor or on a colony, a cell another slot's pod occupies, the slot's current cell,
    /// removing an empty slot, a vent out of 0 … vents − 1 or its current state, a moonlight out of 0 … 3 or the
    /// current one, no action left.
    public func apply(_ move: MushroomWeatherAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        var pods: [MushroomWeatherCell?] = state.arrangement.pods
        var vents: [Bool] = state.arrangement.ventsOpen
        var moonlight: Int = state.arrangement.moonlight
        switch move {
        case .run:
            return nil
        case .place(let slot, let cell):
            guard pods.indices.contains(slot), level.isFloor(cell), !level.colonyCells.contains(cell),
                  !isOccupied(cell, otherThan: slot, in: pods), pods[slot] != cell else { return nil }
            pods[slot] = cell
        case .remove(let slot):
            guard pods.indices.contains(slot), pods[slot] != nil else { return nil }
            pods[slot] = nil
        case .vent(let index, let open):
            guard vents.indices.contains(index), vents[index] != open else { return nil }
            vents[index] = open
        case .moonlight(let value):
            guard MushroomWeatherLevel.moonlightLevels.contains(value), moonlight != value else { return nil }
            moonlight = value
        }
        let arrangement: MushroomWeatherArrangement = MushroomWeatherArrangement(pods: pods, ventsOpen: vents,
                                                                                 moonlight: moonlight)
        return Position(arrangement: arrangement, actionsSpent: state.actionsSpent + 1)
    }

    /// Whether a run from `state` would win: the predicted report of its arrangement has no failure (false for an
    /// arrangement without the level's shape).
    public func isSolved(_ state: Position) -> Bool {
        guard isWellFormed(state.arrangement) else { return false }
        return MushroomWeatherForest.report(level, arrangement: state.arrangement).wins
    }
}
