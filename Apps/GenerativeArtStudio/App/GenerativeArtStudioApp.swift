// GenerativeArtStudioApp.swift — Generative Art Studio (features 011–012; FR-A01-101, FR-A01-111). Offline, no
// permissions; rendering goes through VisualCore only (docs/apps/generative-art-studio/visualcore-contract.md).
import SwiftUI

@main
struct GenerativeArtStudioApp: App {
    var body: some Scene {
        WindowGroup { GalleryView() }
    }
}
