// GenerativeArtStudioApp.swift — Generative Art Studio app shell (feature 011 A01-P00 T-A01-007; FR-A01-005).
// Phase 00 is a titled home screen only: no render host, no permissions, no networking. Rendering, the gallery and the
// parameter panel arrive in Phases 01–02 through VisualCore modules (docs/apps/generative-art-studio/visualcore-contract.md).
import SwiftUI

@main
struct GenerativeArtStudioApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Generative Art Studio")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Generative Art Studio")
                    .accessibilityIdentifier("gas.home.title")
                Text("Procedural scenes are coming in the next phase.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
