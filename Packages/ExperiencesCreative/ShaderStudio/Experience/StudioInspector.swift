// StudioInspector — feature 161 (A22-P03) T-A22-307 (FR-A22-303, FR-A22-305, FR-A22-306; clarification Q3;
// contracts/editor.md "Inspector"; contract gap G-INSPECTOR). The uniform inspector of Shader Studio: one row per float
// uniform of the live project (the last good one, `StudioMirror.uniforms`), so a uniform dropped by a recompile
// leaves the rows with it:
//
//   - a row (``InspectorRow``): the title, the value in its unit at two decimals ("1.00", "2.50 Hz"), the range
//     ("0.00 to 4.00"), and a slider `uniform-<k>` of the normalized value whose spoken value is the value text;
//   - sending: ``StudioInspector/send(_:normalized:port:)`` refuses a non-finite value (nothing is sent) and clamps
//     to 0…1 before `uniform.set [k, v]`; ``StudioInspector/send(_:value:definition:port:)`` clamps a value in the
//     uniform's own range first; the core keeps the normalized values;
//   - Reset (`reset`): `uniform.set [k, default]` for every row, the defaults normalized by their definitions.
//
// Nothing here compiles: the values reach the live scene's parameters at the next frame.
import Foundation
import ShaderStudioCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters

/// One inspector row: what it shows and the normalized value its slider holds.
struct InspectorRow: Equatable, Sendable {
    /// The uniform's index in the live project (and in the core's values).
    var index: Int
    /// The uniform's GLSL name, for example `u_speed`.
    var name: String
    /// The uniform's title, for example "Speed".
    var title: String
    /// The value at two decimals with its unit, for example "1.00" or "2.50 Hz".
    var valueText: String
    /// The range at two decimals, for example "0.00 to 4.00".
    var rangeText: String
    /// The normalized value (0…1) the slider holds.
    var normalized: Double
}

/// The uniform inspector (see the file header).
struct StudioInspector: View {
    /// The port the inspector sends through.
    let port: ExperienceActionPort
    /// The presenter's mirror: the live uniforms and the core's values.
    let mirror: StudioMirror

    /// `value` at two decimals, followed by `unit` when it has one: "1.00", "2.50 Hz".
    static func valueText(_ value: Double, unit: String) -> String {
        let number = String(format: "%.2f", value)
        return unit.isEmpty ? number : number + " " + unit
    }

    /// "a to b" at two decimals.
    static func rangeText(_ definition: ParameterDefinition) -> String {
        String(format: "%.2f", definition.minimum) + " to " + String(format: "%.2f", definition.maximum)
    }

    /// The rows of `uniforms` at the normalized `values` (a missing value reads as the uniform's default).
    static func rows(uniforms: [ParameterDefinition], values: [Double]) -> [InspectorRow] {
        uniforms.enumerated().map { k, definition in
            let normalized = values.indices.contains(k) ? values[k] : definition.normalized(definition.defaultValue)
            return InspectorRow(index: k, name: definition.name, title: definition.title,
                                valueText: valueText(definition.value(normalized: normalized), unit: definition.unit),
                                rangeText: rangeText(definition), normalized: normalized)
        }
    }

    /// The rows the mirror shows.
    static func rows(_ mirror: StudioMirror) -> [InspectorRow] { rows(uniforms: mirror.uniforms, values: mirror.values) }

    /// The normalized value that would be sent for `normalized`: clamped to 0…1; nil (nothing sent) when it is not
    /// finite.
    static func sendable(_ normalized: Double) -> Double? {
        guard normalized.isFinite else { return nil }
        return min(max(normalized, StudioCore.valueRange.lowerBound), StudioCore.valueRange.upperBound)
    }

    /// Sends `uniform.set [k, normalized]`, clamped to 0…1; a non-finite value sends nothing and returns nil.
    @MainActor
    @discardableResult
    static func send(_ k: Int, normalized: Double, port: ExperienceActionPort) -> ActionResult? {
        guard let value = sendable(normalized) else { return nil }
        return port.send("uniform.set", [Double(k), value])
    }

    /// Sends uniform `k` at `value` in `definition`'s own range: clamped to the range, then normalized; a non-finite
    /// value sends nothing and returns nil.
    @MainActor
    @discardableResult
    static func send(_ k: Int, value: Double, definition: ParameterDefinition,
                     port: ExperienceActionPort) -> ActionResult? {
        guard value.isFinite else { return nil }
        return send(k, normalized: definition.normalized(definition.clamped(value)), port: port)
    }

    /// Sends every uniform's default (`uniform.set [k, default]`, normalized); returns the results in order.
    @MainActor
    @discardableResult
    static func reset(_ uniforms: [ParameterDefinition], port: ExperienceActionPort) -> [ActionResult] {
        uniforms.enumerated().compactMap { k, definition in
            send(k, normalized: definition.normalized(definition.defaultValue), port: port)
        }
    }

    /// The rows and the Reset button.
    var body: some View {
        let rows = Self.rows(mirror)
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Uniforms").font(.subheadline.bold()).accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                Text(verbatim: "No uniforms").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.index) { row in
                rowView(row)
            }
            Button {
                Self.reset(mirror.uniforms, port: port)
            } label: {
                Text(verbatim: "Reset").frame(minHeight: 44)
            }
            .disabled(rows.isEmpty)
            .accessibilityLabel(Text(verbatim: "Reset"))
            .accessibilityHint(Text(verbatim: "Sets every uniform back to its default"))
            .accessibilityIdentifier(port.identifier("reset"))
        }
    }

    /// One row: the title and value, the range, and the slider.
    private func rowView(_ row: InspectorRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verbatim: row.title + ": " + row.valueText).font(.footnote)
                Spacer(minLength: 8)
                Text(verbatim: row.rangeText).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
            Slider(value: Binding(get: { row.normalized },
                                  set: { next in
                                      guard next != row.normalized else { return }
                                      Self.send(row.index, normalized: next, port: port)
                                  }), in: StudioCore.valueRange)
                .accessibilityLabel(Text(verbatim: row.title))
                .accessibilityValue(Text(verbatim: row.valueText))
                .accessibilityHint(Text(verbatim: "Range " + row.rangeText + "; changes " + row.name
                                        + " in the preview"))
                .accessibilityIdentifier(port.identifier("uniform-\(row.index)"))
        }
    }
}
