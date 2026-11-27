// BinaryGardensPuzzle — feature 501 (R02-G21-01) T-R02G2101-005 (FR-R02G2101-010; clarification Q5; research R14).
// Binary Gardens expressed as an R02-F23 puzzle contract so R02-G21-02 can certify levels with `PuzzleValidator`: a
// state is a `Position` (the arrangement — both stars' rings, phases and luminosities and the tilt — and the actions
// spent), a move is a `BinaryGardensAction` arrangement action (ring, phase, luminosity, tilt; never the run), and a
// state is solved when the predicted run wins (`BinaryGardensSky.report(level, arrangement:).wins`). While actions are
// left the legal moves are, in exactly this order: for star 1 then star 2, `ring(star, index)` for the rings
// ascending, then `phase(star, step)` for the phases 0 … 47, then `luminosity(star, index)` for the luminosities
// ascending (each skipping the current value, locked controls and arrangements that break the minimum separation);
// then `tilt(step)` for the tilts 0 … T_max (skipping the current one and separation breakers). With the budget spent
// nothing is legal. A move list holds at most 2 · (7 + 47 + 3) + 6 = 120 moves, so R02-G21-02's fairness budget passes
// a maxBranching of at least 120. Applying a move uses the same check as the play's `apply(_:expecting:)`
// (`BinaryGardensSky.changed`), so a move is legal here exactly when the play accepts it in `playing` with actions left,
// and both produce the same arrangement; a move the play would refuse, or the run, is refused (nil). The rules carry no
// stage, fingerprints, report, failure, records, undo or redo: those belong to the play. Integers only; no clock, no
// random source. Modelled on `MushroomWeatherPuzzle` (feature 491).
import VisualCoreSimulation

/// The pure rules of one Binary Gardens level as an R02-F23 puzzle contract.
public struct BinaryGardensPuzzle: PuzzleRules {
    /// A position of a Binary Gardens play as the rules see it: the arrangement and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The arrangement: both stars' rings, phases and luminosities and the tilt.
        public let arrangement: BinaryGardensArrangement
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(arrangement: BinaryGardensArrangement, actionsSpent: Int) {
            self.arrangement = arrangement
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the arrangement and the actions spent.
    public typealias State = Position
    /// A player action: a ring, phase, luminosity or tilt change (the run is never a legal move).
    public typealias Move = BinaryGardensAction

    /// The level whose rings, stars, worlds, separation and budget decide the results.
    public let level: BinaryGardensLevel

    /// The rules of `level`.
    public init(level: BinaryGardensLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g21-binary-gardens" }

    /// The start position: the level's starting arrangement, no action spent.
    public var initialState: Position {
        Position(arrangement: level.start, actionsSpent: 0)
    }

    /// Whether `state` can take an arrangement action: a well-formed arrangement and an action left.
    func isOpen(_ state: Position) -> Bool {
        BinaryGardensSky.isWellFormed(level, state.arrangement) && state.actionsSpent >= 0
            && state.actionsSpent < level.budget
    }

    /// Every arrangement action of the level in the order of research R14, legal or not: for each star, the rings
    /// ascending, the phases 0 … 47 and the luminosities ascending; then the tilts 0 … T_max.
    func candidates() -> [BinaryGardensAction] {
        var result: [BinaryGardensAction] = []
        for star in 0..<2 {
            for index in level.ringRadii.indices { result.append(.ring(star: star, index: index)) }
            for step in 0..<BinaryGardensSky.cycle { result.append(.phase(star: star, step: step)) }
            for index in level.luminosityLevels.indices { result.append(.luminosity(star: star, index: index)) }
        }
        for step in 0...level.maxTilt { result.append(.tilt(step: step)) }
        return result
    }

    /// The legal moves: none with the budget spent; otherwise every arrangement action the play would accept, in the
    /// order of research R14 (star 1 then star 2: rings ascending, phases 0 … 47, luminosities ascending; then tilts
    /// 0 … T_max), at most 120.
    public func moves(in state: Position) -> [BinaryGardensAction] {
        guard isOpen(state) else { return [] }
        var result: [BinaryGardensAction] = []
        for move in candidates() {
            if (try? BinaryGardensSky.changed(level, state.arrangement, by: move)) != nil { result.append(move) }
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the star's ring, phase or luminosity or the
    /// tilt is set and 1 action is spent. Refused: the run, a star, ring, phase, luminosity or tilt out of range, a
    /// locked control, an unchanged value, an arrangement that breaks the minimum separation, no action left, an
    /// arrangement without the level's shape.
    public func apply(_ move: BinaryGardensAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        if case .run = move { return nil }
        guard let next = try? BinaryGardensSky.changed(level, state.arrangement, by: move) else { return nil }
        return Position(arrangement: next, actionsSpent: state.actionsSpent + 1)
    }

    /// Whether a run from `state` would win: the predicted report of its arrangement has no failure (false for an
    /// arrangement without the level's shape).
    public func isSolved(_ state: Position) -> Bool {
        guard BinaryGardensSky.isWellFormed(level, state.arrangement) else { return false }
        return BinaryGardensSky.report(level, arrangement: state.arrangement).wins
    }
}
