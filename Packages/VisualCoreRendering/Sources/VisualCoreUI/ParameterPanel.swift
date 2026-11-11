// ParameterPanel.swift — a SwiftUI form section that edits any ParameterSchema through a ParameterEditor binding
// (feature 013 T-A01-203; FR-A01-201, FR-A01-206, FR-A01-207; contract specs/013-gas-p02-scene-controls/contracts/api.md).
import SwiftUI
import VisualCoreParameters

/// One row of a `ParameterPanel`: what it shows and how VoiceOver reads it.
public struct ParameterRow: Sendable, Equatable, Identifiable {
    /// Parameter name (identifier `vc.param.<name>`).
    public let id: String
    /// Title, also the VoiceOver label.
    public let title: String
    /// Formatted value with unit, also the VoiceOver value.
    public let value: String
    /// Slider position 0…1.
    public let position: Double
    /// Whether the reset button is shown.
    public let isModified: Bool
}

/// Row content and VoiceOver adjustments for a `ParameterPanel` (testable without SwiftUI).
public enum ParameterPanelModel {
    /// VoiceOver increment/decrement step as a fraction of the slider range.
    public static let adjustStep = 0.05

    /// Rows in schema order.
    public static func rows(_ editor: ParameterEditor) -> [ParameterRow] {
        editor.schema.definitions.map {
            ParameterRow(id: $0.name, title: $0.title, value: editor.formatted($0.name),
                         position: editor.normalized($0.name), isModified: editor.isModified($0.name))
        }
    }

    /// Moves `name` one VoiceOver step up (`up == true`) or down, staying in range.
    public static func adjust(_ editor: inout ParameterEditor, _ name: String, up: Bool) {
        editor.set(name, normalized: editor.normalized(name) + (up ? adjustStep : -adjustStep))
    }
}

/// A form section with one slider per parameter (title, value with unit, reset when modified) and "Reset all".
/// Accessibility: each slider's label is the title, its value the formatted value, and it is adjustable in 5% steps.
/// Identifiers: `vc.param.<name>`, `vc.param.<name>.reset`, `vc.param.resetAll`.
public struct ParameterPanel: View {
    @Binding var editor: ParameterEditor

    /// A panel editing `editor`.
    public init(editor: Binding<ParameterEditor>) { _editor = editor }

    /// The parameter rows followed by "Reset all".
    public var body: some View {
        Section("Parameters") {
            ForEach(ParameterPanelModel.rows(editor)) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.title).font(.subheadline)
                        Spacer()
                        Text(row.value).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        if row.isModified {
                            Button { editor.reset(row.id) } label: { Image(systemName: "arrow.uturn.backward.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Reset \(row.title)")
                                .accessibilityIdentifier("vc.param.\(row.id).reset")
                        }
                    }
                    Slider(value: Binding(get: { editor.normalized(row.id) }, set: { editor.set(row.id, normalized: $0) }), in: 0...1)
                        .accessibilityLabel(row.title)
                        .accessibilityValue(row.value)
                        .accessibilityAdjustableAction { direction in
                            switch direction {
                            case .increment: ParameterPanelModel.adjust(&editor, row.id, up: true)
                            case .decrement: ParameterPanelModel.adjust(&editor, row.id, up: false)
                            @unknown default: break
                            }
                        }
                        .accessibilityIdentifier("vc.param.\(row.id)")
                }
            }
            Button("Reset all") { editor.resetAll() }
                .disabled(editor.modifiedNames.isEmpty)
                .accessibilityIdentifier("vc.param.resetAll")
        }
    }
}
