// DemoModel.swift — observable diagnostics and settings for the InteractiveDemo (feature 006 T-F519; FR-F510).
import Foundation
import Observation

@MainActor
@Observable
final class DemoModel {
    var particles = 0
    var zoom = 1.0
    var running = true
    /// Largest number of fixed steps run in one frame since launch or the last return to the foreground.
    var maxStepsPerFrame = 0
    var reduceMotion = false
    var errorText: String?

    /// Read by UI tests through accessibility identifier `demo.diagnostics` (contract: interaction-api.md).
    var diagnostics: String {
        "particles=\(particles) zoom=\(String(format: "%.2f", zoom)) state=\(running ? "running" : "paused")"
    }
    var stepsLabel: String { "maxStepsPerFrame=\(maxStepsPerFrame)" }
}
