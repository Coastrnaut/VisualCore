// FluidArtPlaygroundApp.swift — Fluid Art Playground app shell (feature 018 A02-P00 T-A02-004; FR-A02-005).
// Feature 023 routes automation launches to AppAutomation. Phase 01 (feature 019 T-A02-112) adds the playground canvas and Phase 02 (feature 020) touch and splashes, reached from the home screen (`fap.home.open`).
// No permissions, no networking; rendering goes through VisualCore modules
// (docs/apps/fluid-art-playground/visualcore-contract.md).
import SwiftUI
import VisualCoreUI

@main
struct FluidArtPlaygroundApp: App {
    /// Crash recovery (feature 024 T-A02-602; FR-A02-605): captures left by a killed session are removed before any
    /// scene exists, including automation launches.
    init() {
        CaptureModel.folder.removeAll()
    }

    var body: some Scene {
        // The VisualCore accessible accent keeps prominent buttons above 4.5:1 in light and dark (feature 020 audit).
        WindowGroup {
            // Device-campaign automation (feature 023 T-A02-510): only in DEBUG || VISUALCORE_AUTOMATION builds and
            // only with VISUALCORE_AUTORUN in the launch environment.
            #if DEBUG || VISUALCORE_AUTOMATION
            if let mode = AppAutomation.mode {
                AppAutomation.root(mode: mode)
            } else {
                HomeView().tint(AccessibleColors.accent)
            }
            #else
            HomeView().tint(AccessibleColors.accent)
            #endif
        }
    }
}

struct HomeView: View {
    /// The home screen's description: only implemented, tested features (feature 024 FR-A02-609; CopyTests).
    static let summary = "Swipe to paint with dye that drifts with the flow, or use Add splash. Pause, step and reset the fluid, choose palettes and detail in Adjust, and capture stills."

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
                Text(Self.summary)
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
                // Feature 024 T-A02-606 (FR-A02-604): the bundled license texts (bundle_licenses.py), shown by VisualCoreUI.
                NavigationLink {
                    AcknowledgementsView(identifierPrefix: "fap.acknowledgements")
                } label: {
                    Label("Acknowledgements", systemImage: "doc.text")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("fap.home.acknowledgements")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("fap.home")
            }
        }
    }
}
