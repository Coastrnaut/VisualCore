// AuroraLoomRules — feature 301 (R02-G01-01) T-R02G0101-005 (FR-R02G0101-008; clarification Q5). Aurora Loom expressed as
// an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is the three ribbons'
// wave and phase steps, a move sets one control of one ribbon to a new step, and a state is solved when it wins the level
// (`AuroraLoomHarmony.wins`). Moves are listed ribbon 0 … 2, then control (wave, then phase), then step 0 … 15, skipping
// the current value, so every state offers exactly 3 · 2 · 15 = 90 moves.
import VisualCoreSimulation

/// The pure rules of one Aurora Loom level as an R02-F23 puzzle contract.
public struct AuroraLoomRules: PuzzleRules {
    /// A position: the three ribbons' wave and phase steps.
    public typealias State = AuroraLoomSteps
    /// A player action: one control of one ribbon set to a new step.
    public typealias Move = AuroraLoomMove

    /// The level whose win test decides `isSolved(_:)`.
    public let level: AuroraLoomLevel

    /// The rules of `level`.
    public init(level: AuroraLoomLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g01-aurora-loom" }

    /// The controls in move order: wave, then phase.
    static let controlOrder: [AuroraLoomControl] = [.wave, .phase]

    /// Every single-control change, ordered ribbon 0 … 2, then control (wave, then phase), then step 0 … 15, skipping the
    /// current value (90 moves); empty for a state without three wave and three phase steps.
    public func moves(in state: AuroraLoomSteps) -> [AuroraLoomMove] {
        guard state.wave.count == 3, state.phase.count == 3 else { return [] }
        var result: [AuroraLoomMove] = []
        result.reserveCapacity(90)
        for ribbon in 0..<3 {
            for control in Self.controlOrder {
                let current: Int = Self.value(of: control, ribbon: ribbon, in: state)
                for step in 0...15 where step != current {
                    result.append(AuroraLoomMove(ribbon: ribbon, control: control, step: step))
                }
            }
        }
        return result
    }

    /// The steps after `move`, or nil for a ribbon outside 0 … 2, a step outside 0 … 15, a step equal to the current one
    /// or a state without three wave and three phase steps.
    public func apply(_ move: AuroraLoomMove, to state: AuroraLoomSteps) -> AuroraLoomSteps? {
        guard state.wave.count == 3, state.phase.count == 3 else { return nil }
        guard (0...2).contains(move.ribbon), (0...15).contains(move.step) else { return nil }
        guard Self.value(of: move.control, ribbon: move.ribbon, in: state) != move.step else { return nil }
        var next: AuroraLoomSteps = state
        switch move.control {
        case .wave: next.wave[move.ribbon] = move.step
        case .phase: next.phase[move.ribbon] = move.step
        }
        return next
    }

    /// Whether `state` wins the level (`AuroraLoomHarmony.wins`).
    public func isSolved(_ state: AuroraLoomSteps) -> Bool {
        AuroraLoomHarmony.wins(state, level: level)
    }

    /// The current step of `control` on `ribbon`.
    static func value(of control: AuroraLoomControl, ribbon: Int, in state: AuroraLoomSteps) -> Int {
        switch control {
        case .wave: state.wave[ribbon]
        case .phase: state.phase[ribbon]
        }
    }
}
