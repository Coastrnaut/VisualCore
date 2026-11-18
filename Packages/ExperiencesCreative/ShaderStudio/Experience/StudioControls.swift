// StudioControls — feature 160 (A22-P02) T-A22-204 (FR-A22-201, FR-A22-205, FR-A22-207; clarification Q4;
// contracts/experience.md "Controls"). The native controls of Shader Studio. Every control reads the presenter's
// mirror, sends through the action port (never compiling: the next frame does), has a spoken label and value from one
// list (`labels(_:)`, also read by the tests), a hint and the identifier `experience.a22.shader-studio.<name>`
// (`ExperienceActionPort.identifier`):
//
//   - `template` segmented picker (Gradient, Noise flow, Rings → `template.select [0…2]`);
//   - `run` button ("Run" → `shader.run [1]`);
//   - a slider `uniform-<k>` per uniform of the document (its title and value in its own range; it sends the
//     normalized value → `uniform.set [k, 0…1]`);
//   - `status`: the status line ("Waiting", "Compiled", "Failed: N errors", "Refused: <first issue>");
//   - `diagnostics`: one "Line N: message" entry per diagnostic, anything outside the person's source first (as
//     "<file>: message", or "Shader: message" without a file).
import Foundation
import ShaderStudioCore
import SwiftUI
import VisualCoreExperienceHost
import VisualCoreParameters

/// One spoken label of a control: its identifier name, its title and its value.
struct StudioControlLabel: Equatable, Sendable {
    /// The identifier name (`experience.a22.shader-studio.<name>`).
    var name: String
    /// The spoken title, for example "Template".
    var title: String
    /// The spoken value, for example "Gradient".
    var value: String

    /// "<title>, <value>".
    var text: String { title + ", " + value }
}

/// The native controls of Shader Studio (see the file header).
struct StudioControls: View {
    /// The port the controls send through.
    let port: ExperienceActionPort
    /// What the controls show.
    let mirror: StudioMirror

    /// The template titles, by index of `ShaderTemplates.all`.
    static var templateTitles: [String] { ShaderTemplates.all.map(\.title) }

    /// A uniform's value in its own range, for example "1.50".
    static func valueText(_ value: Double) -> String { String(format: "%.2f", value) }

    /// One diagnostic as a line: "Line N: message" in the person's source, "<file>: message" outside it, or
    /// "Shader: message" without a file.
    static func diagnosticText(_ diagnostic: MappedDiagnostic) -> String {
        if DiagnosticMapper.isInPersonSource(diagnostic), let line = diagnostic.line {
            return "Line \(line): " + diagnostic.message
        }
        if DiagnosticMapper.unnamedFiles.contains(diagnostic.file) { return "Shader: " + diagnostic.message }
        if let line = diagnostic.line { return diagnostic.file + " line \(line): " + diagnostic.message }
        return diagnostic.file + ": " + diagnostic.message
    }

    /// The diagnostics' lines in display order (the mirror's order: outside the source first).
    static func diagnosticLines(_ mirror: StudioMirror) -> [String] { mirror.diagnostics.map(diagnosticText) }

    /// The spoken label of every control shown for `mirror`, in display order.
    static func labels(_ mirror: StudioMirror) -> [StudioControlLabel] {
        let titles = templateTitles
        let template = titles.isEmpty ? "" : titles[min(max(mirror.template, 0), titles.count - 1)]
        var list = [StudioControlLabel(name: "template", title: "Template", value: template),
                    StudioControlLabel(name: "run", title: "Run", value: "Compiles the shader")]
        for (k, definition) in mirror.uniforms.enumerated() {
            let normalized = mirror.values.indices.contains(k) ? mirror.values[k] : 0
            list.append(StudioControlLabel(name: "uniform-\(k)", title: definition.title,
                                           value: valueText(definition.value(normalized: normalized))))
        }
        list.append(StudioControlLabel(name: "status", title: "Status", value: mirror.status))
        let lines = diagnosticLines(mirror)
        list.append(StudioControlLabel(name: "diagnostics", title: "Diagnostics",
                                       value: lines.isEmpty ? "None" : lines.joined(separator: ". ")))
        return list
    }

    /// The controls.
    var body: some View {
        let spoken = Dictionary(Self.labels(mirror).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Shader Studio").font(.headline).accessibilityAddTraits(.isHeader)
            Picker(selection: Binding(get: { mirror.template },
                                      set: { next in
                                          guard next != mirror.template else { return }
                                          port.send("template.select", [Double(next)])
                                      })) {
                ForEach(Array(Self.templateTitles.enumerated()), id: \.offset) { index, title in
                    Text(verbatim: title).tag(index)
                }
            } label: {
                Text(verbatim: "Template")
            }
            .pickerStyle(.segmented)
            .spoken(spoken["template"])
            .accessibilityHint(Text(verbatim: "Opens one of the starter shaders and runs it"))
            .accessibilityIdentifier(port.identifier("template"))
            Button {
                port.send("shader.run", [1])
            } label: {
                Text(verbatim: "Run").frame(minHeight: 44)
            }
            .spoken(spoken["run"])
            .accessibilityHint(Text(verbatim: "Compiles the shader; the preview keeps the last working one on an error"))
            .accessibilityIdentifier(port.identifier("run"))
            ForEach(Array(mirror.uniforms.enumerated()), id: \.offset) { k, definition in
                slider(k, definition, spoken)
            }
            Text(verbatim: mirror.status)
                .font(.footnote)
                .spoken(spoken["status"])
                .accessibilityIdentifier(port.identifier("status"))
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(Self.diagnosticLines(mirror).enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(.footnote.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .spoken(spoken["diagnostics"])
            .accessibilityIdentifier(port.identifier("diagnostics"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A titled slider of uniform `k`, sending `uniform.set [k, normalized]`.
    private func slider(_ k: Int, _ definition: ParameterDefinition,
                        _ spoken: [String: StudioControlLabel]) -> some View {
        let name = "uniform-\(k)"
        let value = mirror.values.indices.contains(k) ? mirror.values[k] : 0
        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: (spoken[name]?.title ?? "") + ": " + (spoken[name]?.value ?? ""))
                .font(.footnote)
                .accessibilityHidden(true)
            Slider(value: Binding(get: { value },
                                  set: { next in
                                      let sent = min(max(next, 0), 1)
                                      guard sent != value else { return }
                                      port.send("uniform.set", [Double(k), sent])
                                  }), in: StudioCore.valueRange)
                .spoken(spoken[name])
                .accessibilityHint(Text(verbatim: "Changes the uniform " + definition.name + " in the preview"))
                .accessibilityIdentifier(port.identifier(name))
        }
    }
}

extension View {
    /// Applies `label`'s title and value as the accessibility label and value.
    func spoken(_ label: StudioControlLabel?) -> some View {
        accessibilityLabel(Text(verbatim: label?.title ?? ""))
            .accessibilityValue(Text(verbatim: label?.value ?? ""))
    }
}
