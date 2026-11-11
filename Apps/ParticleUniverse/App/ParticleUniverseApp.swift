// ParticleUniverseApp.swift — Particle Universe app shell (feature 032 A04-P00 T-A04-004; FR-A04-005).
// Phase 00 shell; Phase 01 (feature 033) adds the sandbox link (CPU preview of the seeded particle domain). No render
// host, no permissions, no networking yet; the GPU loop arrives in Phase 02 (docs/apps/particle-universe/visualcore-contract.md).
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
            ScrollView {
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
                // Only implemented features (constitution A04 truthful claims).
                Text("A particle sandbox: choose an emitter family, play, pause and step a seeded scene, or try a new seed.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pu.home.summary")
                // Feature 033 T-A04-106: the sandbox.
                NavigationLink {
                    SandboxView()
                } label: {
                    Label("Open sandbox", systemImage: "play.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("pu.home.open")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pu.home")
            }
        }
    }
}
