// FluidArtPlaygroundApp.swift — Fluid Art Playground app shell (feature 018 A02-P00 T-A02-004; FR-A02-005).
// Phase 01 (feature 019 T-A02-112) adds the playground canvas and Phase 02 (feature 020) touch and splashes, reached from the home screen (`fap.home.open`).
// No permissions, no networking; rendering goes through VisualCore modules
// (docs/apps/fluid-art-playground/visualcore-contract.md).
import SwiftUI
import VisualCoreUI

@main
struct FluidArtPlaygroundApp: App {
    var body: some Scene {
        // The VisualCore accessible accent keeps prominent buttons above 4.5:1 in light and dark (feature 020 audit).
        WindowGroup { HomeView().tint(AccessibleColors.accent) }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            // Scrolls so the largest accessibility text sizes never clip (feature 020 audit).
            ScrollView {
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
                Text("Swipe to paint with dye that drifts with the flow, or use Add splash. Palettes, capture and more arrive in later phases.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fap.home")
            }
        }
    }
}
