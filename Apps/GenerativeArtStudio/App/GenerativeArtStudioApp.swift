// GenerativeArtStudioApp.swift — Generative Art Studio (features 011–012; FR-A01-101, FR-A01-111). Offline, no
// permissions; rendering goes through VisualCore only (docs/apps/generative-art-studio/visualcore-contract.md).
import SwiftUI
import VisualCoreUI

@main
struct GenerativeArtStudioApp: App {
    /// System Reduce Motion and Dim Flashing Lights, shared by every screen (feature 016).
    @State private var accessibility = SystemAccessibilityObserver()

    init() {
        LaunchCleanup.run()   // crash recovery: stale exports from a killed session (feature 017)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG || VISUALCORE_AUTOMATION
            if let mode = AppAutomation.mode {
                AppAutomation.root(mode: mode)
            } else {
                GalleryView().environment(accessibility).tint(AccessibleColors.accent)
            }
            #else
            GalleryView().environment(accessibility).tint(AccessibleColors.accent)
            #endif
        }
    }
}
