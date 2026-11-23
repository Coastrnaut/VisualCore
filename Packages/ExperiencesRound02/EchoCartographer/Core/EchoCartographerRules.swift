// EchoCartographerRules — feature 401 (R02-G11-01) T-R02G1101-005 (FR-R02G1101-010; clarifications Q2, Q3). Echo
// Cartographer expressed as an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a
// state is a `Position` (the knowledge of the chamber, the located beacons, the energy left and the outcome), a move is
// an `EchoCartographerAction`, and a state is solved when its outcome is `won`. While playing the legal moves are every
// valid pulse (from a cell known open), then every valid claim (a cell inside the chamber, not known wall, and not
// within the tolerance of located beacons only), each in cell-index order (y · W + x). Markers are not moves: they never
// decide anything. A won or failed position offers nothing. Applying a move mirrors the play's `apply(_:expecting:)`:
// a pulse spends 1 energy and adds what its echo reveals; a claim that hits locates the nearest unlocated beacon within
// the tolerance (`EchoCartographerLevel.claim(_:located:)`), makes that beacon's cell known open and is free; a miss
// spends min(miss cost, energy left) and reveals nothing. Then the outcome is judged: the win first (every beacon
// located), then the energy (none left with a beacon hidden fails). A move the play would refuse is refused (nil). The
// rules carry no stage, fingerprints, markers, undo, redo or records: those belong to the play. Integers only; no
// clock, no random source.
import VisualCoreSimulation

/// The pure rules of one Echo Cartographer level as an R02-F23 puzzle contract.
public struct EchoCartographerRules: PuzzleRules {
    /// A position of an Echo Cartographer play as the rules see it: knowledge, located beacons, energy and outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// Every beacon is located.
            case won
            /// The energy ran out with a beacon still hidden.
            case failed
        }

        /// What the player knows of the chamber.
        public let knowledge: EchoCartographerKnowledge
        /// The indices (in the level's beacon order) of the located beacons, ascending.
        public let located: [Int]
        /// The energy left, 0 … the level's budget.
        public let energy: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values; `located` is stored ascending without duplicates (otherwise not checked).
        public init(knowledge: EchoCartographerKnowledge, located: [Int], energy: Int, outcome: Outcome) {
            self.knowledge = knowledge
            self.located = Array(Set(located)).sorted()
            self.energy = energy
            self.outcome = outcome
        }
    }

    /// A position: knowledge, located beacons, energy and outcome.
    public typealias State = Position
    /// A player action: a pulse or a claim (a marker is refused, it is not a move).
    public typealias Move = EchoCartographerAction

    /// The level whose chamber, beacons, tolerance, energy and miss cost decide the results.
    public let level: EchoCartographerLevel

    /// The rules of `level`.
    public init(level: EchoCartographerLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g11-echo-cartographer" }

    /// The start position: only the entry known open, nothing located, the level's whole energy, still playing.
    public var initialState: Position {
        Position(knowledge: level.openingKnowledge, located: [], energy: level.energy, outcome: .playing)
    }

    /// Whether a pulse from `cell` is valid in `state` (inside the chamber and known open).
    public func canPulse(_ cell: EchoCartographerCell, in state: Position) -> Bool {
        level.chamber.isInside(cell) && state.knowledge[cell] == .open
    }

    /// Whether a claim on `cell` is valid in `state`: inside the chamber, not known wall, and not within the tolerance
    /// of located beacons only.
    public func canClaim(_ cell: EchoCartographerCell, in state: Position) -> Bool {
        guard level.chamber.isInside(cell), state.knowledge[cell] != .wall else { return false }
        return level.claim(cell, located: Set(state.located)) != .alreadyLocated
    }

    /// The legal moves: none once won or failed; otherwise every valid pulse, then every valid claim, each in
    /// cell-index order.
    public func moves(in state: Position) -> [EchoCartographerAction] {
        guard state.outcome == .playing else { return [] }
        let chamber: EchoCartographerChamber = level.chamber
        var pulses: [EchoCartographerAction] = []
        var claims: [EchoCartographerAction] = []
        for index in 0..<chamber.cellCount {
            let cell: EchoCartographerCell = chamber.cell(index)
            if canPulse(cell, in: state) { pulses.append(.pulse(cell.x, cell.y)) }
            if canClaim(cell, in: state) { claims.append(.claim(cell.x, cell.y)) }
        }
        return pulses + claims
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A pulse spends 1 energy and reveals
    /// its echo; a hit locates its beacon, marks the beacon's cell known open and is free; a miss spends
    /// min(miss cost, energy). Then the win is judged, then the energy, exactly as the play judges them.
    public func apply(_ move: EchoCartographerAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        var knowledge: EchoCartographerKnowledge = state.knowledge
        var located: Set<Int> = Set(state.located)
        var energy: Int = state.energy
        switch move {
        case let .pulse(x, y):
            let cell = EchoCartographerCell(x: x, y: y)
            guard canPulse(cell, in: state) else { return nil }
            energy -= 1
            knowledge.reveal(level.echo(from: cell))
        case let .claim(x, y):
            let cell = EchoCartographerCell(x: x, y: y)
            guard level.chamber.isInside(cell), state.knowledge[cell] != .wall else { return nil }
            switch level.claim(cell, located: located) {
            case let .hit(beacon):
                located.insert(beacon)
                knowledge.markOpen(level.beacons[beacon])
            case .alreadyLocated:
                return nil
            case .miss:
                energy -= min(level.missCost, energy)
            }
        case .mark:
            return nil
        }
        var outcome: Position.Outcome = .playing
        if located.count == level.beacons.count {
            outcome = .won
        } else if energy == 0 {
            outcome = .failed
        }
        return Position(knowledge: knowledge, located: Array(located), energy: energy, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
