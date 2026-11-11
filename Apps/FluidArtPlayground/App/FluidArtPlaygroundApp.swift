// FluidArtPlaygroundApp.swift — Fluid Art Playground app shell (feature 018 A02-P00 T-A02-004; FR-A02-005).
// Phase 01 (feature 019 T-A02-112) adds the playground canvas, reached from the home screen (`fap.home.open`).
// No permissions, no networking; rendering goes through VisualCore modules
// (docs/apps/fluid-art-playground/visualcore-contract.md).
import SwiftUI

@main
struct FluidArtPlaygroundApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "drop.halffull")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Fluid Art Playground")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Fluid Art Playground")
                    .accessibilityIdentifier("fap.home.title")
                Text("Watch seeded dye fade on a fluid grid. Touch, ink and smoke arrive in the next phases.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                NavigationLink {
                    PlaygroundView()
                } label: {
                    Label("Open playground", systemImage: "play.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fap.home.open")
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fap.home")
        }
    }
}
