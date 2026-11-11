// AdjustPanel.swift — live tuning of viscosity, fading, solver quality and edge mode (feature 021 T-A02-307;
// FR-A02-306; US3; contract quality-and-solver.md). Native controls only: each slider shows its effective value with
// a unit and speaks it to VoiceOver. Changes reach the scene on the next frame without clearing the picture.
import FluidArtPlaygroundCore
import SwiftUI
import VisualCoreUI

struct AdjustPanel: View {
    @Bindable var model: PlaygroundModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    slider("Viscosity", id: "fap.adjust.viscosity", value: $model.configuration.viscosity,
                           range: FluidConfiguration.viscosityRange, step: 0.05,
                           text: String(format: "%.2f", model.configuration.viscosity), unit: "")
                    slider("Dye fade", id: "fap.adjust.dyeFade", value: $model.configuration.dyeDissipation,
                           range: FluidConfiguration.dissipationRange, step: 0.1,
                           text: String(format: "%.1f", model.configuration.dyeDissipation), unit: "per second")
                    slider("Motion fade", id: "fap.adjust.motionFade", value: $model.configuration.velocityDissipation,
                           range: FluidConfiguration.dissipationRange, step: 0.1,
                           text: String(format: "%.1f", model.configuration.velocityDissipation), unit: "per second")
                } header: {
                    Text("Motion")
                }
                .headerProminence(.increased)
                Section {
                    slider("Quality", id: "fap.adjust.quality", value: iterations, range: 1...80, step: 1,
                           text: "\(model.configuration.pressureIterations)",
                           unit: model.configuration.pressureIterations == 1 ? "iteration" : "iterations")
                    Picker("Edges", selection: $model.configuration.boundaryMode) {
                        Text("Walls").tag(BoundaryMode.walls)
                        Text("Open").tag(BoundaryMode.open)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("fap.adjust.edges")
                    Text("Quality: \(model.tierName) (automatic)")
                        .accessibilityIdentifier("fap.adjust.tier")
                    // A regular row, not a footer: footers are forced to secondary text, which fails contrast here.
                    Text("More iterations keep the motion swirling instead of spreading. When the device is hot or in Low Power Mode, quality is lowered automatically.")
                        .font(.footnote)
                } header: {
                    Text("Solver")
                }
                .headerProminence(.increased)
                Section {
                    // Not destructive (nothing is lost but tuning), so it uses the accessible accent, not system red.
                    Button("Reset to defaults") { model.resetConfiguration() }
                        .accessibilityIdentifier("fap.adjust.reset")
                }
            }
            // Opaque on every OS: iOS 26 keeps the sheet translucent, so the form paints its own background.
            .scrollContentBackground(.hidden)
            // Keeps the first header clear of the iOS 26 glass bar button's shadow, which the audit otherwise samples
            // as low contrast behind "Motion" (feature 021, iOS 26.5 audit).
            .contentMargins(.top, 24, for: .scrollContent)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("fap.adjust.done")
                }
            }
        }
        .tint(AccessibleColors.accent)
        .accessibilityIdentifier("fap.adjust.sheet")
    }

    private var iterations: Binding<Double> {
        Binding(get: { Double(model.configuration.pressureIterations) },
                set: { model.configuration.pressureIterations = Int($0.rounded()) })
    }

    private func slider(_ title: String, id: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
                        text: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) { Text(unit.isEmpty ? text : "\(text) \(unit)").monospacedDigit() }
                .accessibilityHidden(true)
            Slider(value: value, in: range, step: step) { Text(title) }
                .accessibilityIdentifier(id)
                .accessibilityValue(unit.isEmpty ? text : "\(text) \(unit)")
        }
    }
}
