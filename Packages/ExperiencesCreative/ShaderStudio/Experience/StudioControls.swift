// StudioControls — feature 160 (A22-P02) T-A22-204 (FR-A22-201, FR-A22-205, FR-A22-207; clarification Q4;
// contracts/experience.md "Controls"); feature 161 (A22-P03) T-A22-304, T-A22-307 (FR-A22-301, FR-A22-303,
// FR-A22-306; clarifications Q1, Q3) added the editor and the inspector. The native controls of Shader Studio. Every
// control reads the presenter's mirror, sends through the action port (never compiling: the next frame does), has a
// spoken label and value from one list (`labels(_:)`, also read by the tests), a hint and the identifier
// `experience.a22.shader-studio.<name>` (`ExperienceActionPort.identifier`):
//
//   - `template` segmented picker (the titles of `ShaderTemplates.all` → `template.select [i]`);
//   - `run` button ("Run" → `shader.run [1]`; ⌘R on a hardware keyboard);
//   - `status`: the status line ("Waiting", "Compiled", "Failed: N errors", "Refused: <first issue>", "Stopped: frames
//     took longer than 0.25 s");
//   - `guidance` (feature 162): the sentence under the status saying what to change (the core's `Guidance`), shown
//     when there is one; its spoken label is the sentence;
//   - `preview-reset` (feature 162): a button shown while the watchdog has stopped the preview (`preview.reset [1]`);
//   - `library` (feature 162, T-A22-410): a button, shown when the experience has storage, that opens
//     ``StudioLibraryView`` in a sheet;
//   - ``StudioEditor``: `editor`, `gutter` (`gutter-line-<n>`), `next-diagnostic` (⌘') and `diagnostics`
//     (`diagnostic-<k>`, "Line N: message", anything outside the person's source first, as "<file>: message", or
//     "Shader: message" without a file);
//   - ``StudioInspector``: a slider `uniform-<k>` per live uniform (its title, its value with its unit at two
//     decimals, its range), a picker `texture-<i>` per live texture input (`texture.set`) and `reset`.
//
// Layout (``StudioEditorLayout/arrangement(horizontalSizeClass:dynamicTypeSize:)``): the editor beside the inspector
// in a regular width at a non-accessibility type size, stacked otherwise; the preview stays above the controls, whose
// height the session host bounds.
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
    /// Sets the presenter's document source (the editor's edits); never compiles.
    var edit: @MainActor (String) -> Void = { _ in }
    /// The project library's actions (feature 162); nil when the experience has no storage.
    var library: StudioLibraryActions?
    /// Whether the library sheet is shown.
    @State private var showsLibrary = false
    /// The width class of the environment.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// The type size of the environment.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The template titles, by index of `ShaderTemplates.all`.
    static var templateTitles: [String] { ShaderTemplates.all.map(\.title) }

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
        for row in StudioInspector.rows(mirror) {
            list.append(StudioControlLabel(name: "uniform-\(row.index)", title: row.title, value: row.valueText))
        }
        for row in StudioInspector.textureRows(inputs: mirror.textureInputs, choices: mirror.textures) {
            list.append(StudioControlLabel(name: "texture-\(row.index)", title: "Texture \(row.index + 1)",
                                           value: row.recipe.title))
        }
        list.append(StudioControlLabel(name: "status", title: "Status", value: mirror.status))
        if !mirror.guidance.isEmpty {
            list.append(StudioControlLabel(name: "guidance", title: mirror.guidance, value: ""))
        }
        if mirror.stopped {
            list.append(StudioControlLabel(name: "preview-reset", title: "Reset preview",
                                           value: "Goes back to the last shader that ran well"))
        }
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
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityHint(Text(verbatim: "Compiles the shader; the preview keeps the last working one on an error"))
            .accessibilityIdentifier(port.identifier("run"))
            if library != nil {
                Button {
                    showsLibrary = true
                } label: {
                    Text(verbatim: "Library").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Library"))
                .accessibilityHint(Text(verbatim: "Saves, opens, renames and removes your shader projects"))
                .accessibilityIdentifier(port.identifier("library"))
            }
            Text(verbatim: mirror.status)
                .font(.footnote)
                .spoken(spoken["status"])
                .accessibilityIdentifier(port.identifier("status"))
            if !mirror.guidance.isEmpty {
                Text(verbatim: mirror.guidance)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: mirror.guidance))
                    .accessibilityIdentifier(port.identifier("guidance"))
            }
            if mirror.stopped {
                Button {
                    port.send("preview.reset", [1])
                } label: {
                    Text(verbatim: "Reset preview").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Reset preview"))
                .accessibilityHint(Text(verbatim: "Goes back to the last shader that ran well; nothing is compiled"))
                .accessibilityIdentifier(port.identifier("preview-reset"))
            }
            switch StudioEditorLayout.arrangement(horizontalSizeClass: horizontalSizeClass,
                                                  dynamicTypeSize: dynamicTypeSize) {
            case .sideBySide:
                HStack(alignment: .top, spacing: 16) {
                    StudioEditor(port: port, mirror: mirror, edit: edit).frame(maxWidth: .infinity)
                    StudioInspector(port: port, mirror: mirror).frame(width: 300)
                }
            case .stacked:
                StudioEditor(port: port, mirror: mirror, edit: edit)
                StudioInspector(port: port, mirror: mirror)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showsLibrary) {
            if let library {
                StudioLibraryView(port: port, actions: library, close: { showsLibrary = false })
            }
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
