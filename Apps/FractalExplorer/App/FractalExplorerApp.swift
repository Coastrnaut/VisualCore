// FractalExplorerApp.swift — Fractal Explorer app shell (feature 025 A03-P00 T-A03-004; FR-A03-005).
// Phase 00 shell; Phase 01 (feature 026) adds the explorer link. No render host, no permissions, no networking. The complex-plane domain,
// its CPU reference and rendering arrive in Phases 01–02 through VisualCore modules
// (docs/apps/fractal-explorer/visualcore-contract.md).
import SwiftUI
import VisualCoreRendering
import VisualCoreUI

@main
struct FractalExplorerApp: App {
    /// Feature 029 (T-A03-407; US2 AC4): captures from a previous run are removed at launch.
    init() { Self.cleanUpCaptures() }

    /// Empties `tmp/Captures`; returns the number of files removed.
    @discardableResult
    static func cleanUpCaptures() -> Int { StillCapture.folder(named: ExplorerModel.captureFolderName).removeAll() }

    var body: some Scene {
        WindowGroup { HomeView().tint(AccessibleColors.accent) }
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
                // Feature 026 T-A03-104: the explorer (Mandelbrot and Julia modes with explanations).
                NavigationLink {
                    ExplorerView()
                } label: {
                    Label("Open explorer", systemImage: "play.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("fe.home.open")
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fe.home")
        }
    }
}
