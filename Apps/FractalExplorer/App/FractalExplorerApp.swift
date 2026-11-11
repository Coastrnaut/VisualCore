// FractalExplorerApp.swift — Fractal Explorer app shell (feature 025 A03-P00 T-A03-004; FR-A03-005).
// Phase 00 is a titled home screen only: no render host, no permissions, no networking. The complex-plane domain,
// its CPU reference and rendering arrive in Phases 01–02 through VisualCore modules
// (docs/apps/fractal-explorer/visualcore-contract.md).
import SwiftUI

@main
struct FractalExplorerApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Fractal Explorer")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Fractal Explorer")
                    .accessibilityIdentifier("fe.home.title")
                Text("An explorer for the Mandelbrot and Julia sets.")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fe.home")
        }
    }
}
