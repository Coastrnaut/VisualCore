// FluidCanvasDescription.swift — the canvas's spoken value (feature 019 T-A02-109; FR-A02-106; constitution A02
// accessibility rule).
import VisualCoreSimulation

/// Text VoiceOver reads for the fluid canvas.
public enum FluidCanvasDescription {
    /// For example "Dye pattern slowly fading, 128 by 128 grid, half-float storage, 2 splashes added".
    /// The splash count is only mentioned once at least one splash was added (feature 020).
    public static func text(configuration c: FluidConfiguration, storage: StoragePrecision, paused: Bool, splashes: Int = 0) -> String {
        let state: String
        if paused {
            state = "paused"
        } else if c.dyeDissipation == 0 {
            state = "holding steady"
        } else if c.dyeDissipation < 3 {
            state = "slowly fading"
        } else {
            state = "quickly fading"
        }
        let storageText = switch storage {
        case .float32: "32-bit float storage"
        case .float16, .float16TowardZero: "half-float storage"
        case .unorm8: "8-bit storage"
        }
        let splashText = splashes > 0 ? ", \(splashes) \(splashes == 1 ? "splash" : "splashes") added" : ""
        return "Dye pattern \(state), \(c.gridWidth) by \(c.gridHeight) grid, \(storageText)\(splashText)"
    }
}
