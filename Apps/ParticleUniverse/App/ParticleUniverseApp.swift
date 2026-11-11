// ParticleUniverseApp.swift — Particle Universe app shell (feature 032 A04-P00 T-A04-004; FR-A04-005).
// Phase 00 shell: a titled home screen only. No render host, no permissions, no networking. The particle domain
// and rendering arrive in Phases 01–02 through VisualCore modules (docs/apps/particle-universe/visualcore-contract.md).
import SwiftUI
import VisualCoreUI

@main
struct ParticleUniverseApp: App {
    var body: some Scene {
        WindowGroup { HomeView().tint(AccessibleColors.accent) }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Particle Universe")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Particle Universe")
                    .accessibilityIdentifier("pu.home.title")
                Text("A particle sandbox with emitters, forces and trails.")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pu.home")
        }
    }
}
