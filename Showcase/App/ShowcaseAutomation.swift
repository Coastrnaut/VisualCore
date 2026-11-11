// ShowcaseAutomation.swift — runs a VisualCoreAutomation mode on the gradient scene when launched with
// VISUALCORE_AUTORUN=<mode>, then exits (feature 010 T-F904; FR-F914). Compiled only under DEBUG || VISUALCORE_AUTOMATION:
// the shipping Release build has no automation code (checked by scripts/check_release_symbols.py). The only trigger
// is the launch environment set by Xcode/simctl/devicectl; there is no URL scheme or remote input.
#if DEBUG || VISUALCORE_AUTOMATION
import SwiftUI
import UIKit
import VisualCoreAutomation
import VisualCoreRendering

enum ShowcaseAutomation {
    /// The requested mode, if this launch is an automation run.
    static let mode = AutomationRunner.requestedMode()
}

/// Full-screen gradient scene that runs the requested mode once it is laid out in a window (VisualCoreAutomation's
/// shared `AutomationView`, feature 017 T-A01-603).
struct AutomationRootView: View {
    let mode: String
    let settings: ShowcaseSettings
    var body: some View {
        AutomationView(mode: mode, bundleID: Bundle.main.bundleIdentifier ?? "dev.visualcore.Showcase",
                       makeScene: { GradientTextureScene(settings: settings) },
                       configure: { scene, scale in
                           if scale > 0 { (scene as? GradientTextureScene)?.scale = Double(scale) }
                       })
            .ignoresSafeArea()
            .accessibilityLabel("Automation run: \(mode)")
            .accessibilityIdentifier("showcase.automation")
    }
}
#endif
