// FluidArtPlaygroundApp.swift — Fluid Art Playground app shell (feature 018 A02-P00 T-A02-004; FR-A02-005).
// Phase 00 is a titled home screen only: no render host, no permissions, no networking. The solver, its CPU reference
// and rendering arrive in Phases 01–02 through VisualCore modules (docs/apps/fluid-art-playground/visualcore-contract.md).
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
                Text("Ink, smoke and dye simulations are coming in the next phases.")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fap.home")
        }
    }
}
