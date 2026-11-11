// GenerativeArtStudioApp.swift — Generative Art Studio (features 011–012; FR-A01-101, FR-A01-111). Offline, no
// permissions; rendering goes through VisualCore only (docs/apps/generative-art-studio/visualcore-contract.md).
import SwiftUI
import VisualCoreUI

@main
struct GenerativeArtStudioApp: App {
    /// System Reduce Motion and Dim Flashing Lights, shared by every screen (feature 016).
    @State private var accessibility = SystemAccessibilityObserver()

    var body: some Scene {
        WindowGroup { GalleryView().environment(accessibility).tint(AppColors.accent) }
    }
}
