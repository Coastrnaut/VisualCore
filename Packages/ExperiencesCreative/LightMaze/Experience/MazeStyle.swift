// MazeStyle — feature 099 (A13-P04) T-A13-405 (FR-A13-430, FR-A13-431; clarification Q4; research D6).
// The state style of Light Maze: every state the board shows has a colour and a sign that marks it without colour, so
// no state is told apart by colour alone. The colours are the presenter's; this file adds the solved-board border and
// lists the nine states for the shared state-sign check.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The colours and colour-independent signs of Light Maze's nine board states.
enum MazeStyle {
    /// The border drawn around a solved board: a bright green, lighter and cooler than ``MazePresenter/litTargetColor``.
    nonisolated static let successColor = Vec4(0.55, 1, 0.6, 1)

    /// The colour as "#RRGGBB": each channel clamped to 0…1, scaled to 0…255 and rounded; alpha is ignored.
    nonisolated static func hex(_ color: Vec4) -> String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(color.x), byte(color.y), byte(color.z))
    }

    /// The nine states with their colours, in the order of ``signs``.
    nonisolated static var stateColors: [(id: String, color: Vec4)] {
        [
            ("wall", MazePresenter.wallColor),
            ("mirror", MazePresenter.mirrorColor),
            ("prism", MazePresenter.prismColor),
            ("emitter", MazePresenter.emitterColor),
            ("target-unlit", MazePresenter.targetColor),
            ("target-lit", MazePresenter.litTargetColor),
            ("beam", MazePresenter.beamColor),
            ("selected", MazePresenter.selectionColor),
            ("solved", successColor),
        ]
    }

    /// The nine states with their colours as hex and the sign that marks each without colour.
    nonisolated static var signs: [StateSign] {
        let shapes: [String: String] = [
            "wall": "filled square",
            "mirror": "single diagonal line",
            "prism": "double diagonal line",
            "emitter": "triangle",
            "target-unlit": "filled square with gap",
            "target-lit": "square with ring",
            "beam": "line with halo",
            "selected": "cell outline",
            "solved": "border with tick",
        ]
        var result: [StateSign] = []
        for state in stateColors {
            result.append(StateSign(id: state.id, colorHex: hex(state.color), sign: shapes[state.id] ?? ""))
        }
        return result
    }
}
