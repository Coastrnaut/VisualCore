// AppAutomation.swift — the device-campaign automation entry (feature 017 T-A01-608; FR-A01-608). Compiled only under
// DEBUG || VISUALCORE_AUTOMATION; the only trigger is the launch environment VISUALCORE_AUTORUN=<mode>, set by
// simctl/devicectl. The shipping Release build has no automation code (scripts/check_release_symbols.py).
#if DEBUG || VISUALCORE_AUTOMATION
import GenerativeArtStudioCore
import SwiftUI
import VisualCoreAutomation
import VisualCoreRendering

enum AppAutomation {
    /// The requested mode, if this launch is an automation run.
    static let mode = AutomationRunner.requestedMode()

    /// The default Gradient Noise composition, as the gallery opens it, hosted for the run.
    @ViewBuilder
    static func root(mode: String) -> some View {
        AutomationView(mode: mode, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.GenerativeArtStudio",
                       makeScene: {
                           let family = FamilyCatalog.family(.gradientNoise)
                           return ArtSceneFactory.makeScene(for: CompositionEditor(family: family).composition)
                       },
                       configure: { scene, scale in (scene as? ArtScene)?.displayScale = Double(scale) })
            .ignoresSafeArea()
            .accessibilityIdentifier("gas.automation")
    }
}
#endif
