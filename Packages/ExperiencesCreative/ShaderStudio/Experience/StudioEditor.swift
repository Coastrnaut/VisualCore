// StudioEditor — feature 161 (A22-P03) T-A22-304 (FR-A22-301, FR-A22-302, FR-A22-306; clarification Q1;
// contracts/editor.md "Editor", "Edits and Run"; contract gap G-EDITOR). The code editor of Shader Studio:
//
//   - Editing: a monospaced iOS 26 SwiftUI `TextEditor(text: Binding<AttributedString>, selection:)` over the
//     presenter's document source (`StudioMirror.source`), recoloured in place by ``SyntaxPalette`` from an
//     `EditorDocument` after every edit (the characters, the trailing newline included, are never changed, and the
//     selection is carried through `AttributedString.transform(updating:)`). Autocorrection and autocapitalisation
//     are off. An edit calls the presenter's `setSource(_:)` (through `edit`) and never compiles; a change of the
//     document from outside (a template) replaces the text.
//   - Gutter (`gutter`): one element per line, `gutter-line-<n>` from 1, showing the number and, on a line that
//     carries a diagnostic of the person's file, a marker. The spoken label is "Line N", or "Line N, error: message"
//     ("warning" when the line has warnings only). Colour is not the only cue: the marker is a symbol.
//   - Alignment: the editor does not scroll on its own; it is as tall as its wrapped text (plus one spare line), and
//     the controls' scroll view scrolls it. Long lines wrap, and each gutter line is as tall as its line's wrapped
//     rows, estimated from the monospaced advance (``StudioEditorLayout/rows(of:columns:)``, greedy word wrap).
//   - Diagnostics (`diagnostics`, a container of separate elements): one button per diagnostic, `diagnostic-<k>` from 0,
//     in the mirror's order (outside the source first, then by line), labelled "Line N: message"
//     (`StudioControls.diagnosticText`), followed by its guidance (feature 162, `Guidance.forDiagnostic`), shown under it
//     and spoken after it (``StudioEditorLayout/diagnosticLabel(_:)``). Choosing one in the person's source puts the selection at its line's start
//     (`EditorDocument.lineStart(_:)`, a UTF-8 offset, converted by ``StudioEditorLayout/index(in:utf8Offset:)``).
//   - Keyboard: ⌘' ("Next error", `next-diagnostic`) moves to the next diagnostic in the person's source, wrapping
//     around (``StudioEditorLayout/nextDiagnostic(after:in:)``); Run is ⌘R on the controls' Run button.
//   - Dynamic Type: the font size follows the environment's type size (``StudioEditorLayout/fontSize(_:)``), and the
//     gutter's rows follow it.
//
// No GL call, no compile: only the presenter's next frame compiles, after a `shader.run`.
import Foundation
import ShaderStudioCore
import SwiftUI
import UIKit
import VisualCoreExperienceHost

/// How the editor and the inspector are arranged in the controls.
enum StudioArrangement: Equatable, Sendable {
    /// The editor beside the inspector (regular width at a non-accessibility type size).
    case sideBySide
    /// The editor above the inspector (compact width, or an accessibility type size).
    case stacked
}

/// The pure layout and navigation rules of the editor (see the file header).
enum StudioEditorLayout {
    /// The editor's base font size at the default type size, in points.
    static let baseFontSize: CGFloat = 14
    /// The text view's top and bottom inset, in points (UIKit's text container inset).
    static let verticalInset: CGFloat = 8
    /// The text view's horizontal padding on both sides together, in points (two line fragment paddings).
    static let horizontalPadding: CGFloat = 10

    /// Side by side in a regular width at a non-accessibility type size; stacked otherwise (iPhone, split view,
    /// accessibility sizes), so that the editor and the inspector each keep a usable width.
    static func arrangement(horizontalSizeClass: UserInterfaceSizeClass?,
                            dynamicTypeSize: DynamicTypeSize) -> StudioArrangement {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize ? .sideBySide : .stacked
    }

    /// The editor's font size at `dynamicTypeSize`: ``baseFontSize`` scaled like body text.
    static func fontSize(_ dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: .body).scaledValue(for: baseFontSize, compatibleWith: traits)
    }

    /// The monospaced font's character advance and line height at `size` points.
    static func metrics(fontSize size: CGFloat) -> (advance: CGFloat, lineHeight: CGFloat) {
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let advance = ("0" as NSString).size(withAttributes: [.font: font]).width
        return (max(advance, 1), font.lineHeight)
    }

    /// The characters that fit on one row of a text `width` points wide at `advance` points per character (at least 1).
    static func columns(width: CGFloat, advance: CGFloat) -> Int {
        max(Int(((width - horizontalPadding) / max(advance, 1)).rounded(.down)), 1)
    }

    /// The rows `line` takes when wrapped at `columns` characters: greedy word wrap at spaces (a space at a row's end
    /// hangs), a word longer than a row broken by characters; at least 1.
    static func rows(of line: String, columns: Int) -> Int {
        let columns = max(columns, 1)
        var rows = 1, column = 0
        for (k, word) in line.split(separator: " ", omittingEmptySubsequences: false).enumerated() {
            if k > 0, column < columns { column += 1 }
            var width = word.count
            guard width > 0 else { continue }
            if column + width <= columns {
                column += width
                continue
            }
            if column > 0 { rows += 1 }
            while width > columns {
                rows += 1
                width -= columns
            }
            column = width
        }
        return rows
    }

    /// The spoken label of a gutter line: "Line N", or "Line N, error: message" (the first diagnostic's message;
    /// "warning" when the line has no error).
    static func gutterLabel(_ line: EditorLine) -> String {
        guard let first = line.diagnostics.first else { return "Line \(line.number)" }
        let kind = line.diagnostics.contains { $0.severity == .error } ? "error" : "warning"
        return "Line \(line.number), \(kind): " + first.message
    }

    /// The spoken label of a diagnostics entry (feature 162): "Line N: message. <guidance>".
    static func diagnosticLabel(_ diagnostic: MappedDiagnostic) -> String {
        StudioControls.diagnosticText(diagnostic) + ". " + Guidance.forDiagnostic(message: diagnostic.message)
    }

    /// The UTF-8 offset in `document`'s source at which `diagnostic`'s line starts; nil for a diagnostic outside the
    /// person's source or past its last line.
    static func selectionOffset(for diagnostic: MappedDiagnostic, in document: EditorDocument) -> Int? {
        guard diagnostic.file == EditorDocument.personFile, let line = diagnostic.line else { return nil }
        return document.lineStart(line)
    }

    /// The index of `text` at the UTF-8 offset `offset` of its characters; nil when the offset is past the end or
    /// inside a character's encoding. A line start lies after a whole terminator, so it always converts.
    static func index(in text: AttributedString, utf8Offset offset: Int) -> AttributedString.Index? {
        let source = String(text.characters)
        let utf8 = source.utf8
        guard offset >= 0, let position = utf8.index(utf8.startIndex, offsetBy: offset, limitedBy: utf8.endIndex),
              let scalar = position.samePosition(in: source.unicodeScalars) else { return nil }
        let scalars = source.unicodeScalars.distance(from: source.unicodeScalars.startIndex, to: scalar)
        return text.unicodeScalars.index(text.startIndex, offsetBy: scalars, limitedBy: text.endIndex)
    }

    /// The index in `diagnostics` of the next diagnostic in the person's source after the index `current` (from the
    /// first when `current` is nil), wrapping around; nil when none is in the source.
    static func nextDiagnostic(after current: Int?, in diagnostics: [MappedDiagnostic]) -> Int? {
        guard !diagnostics.isEmpty else { return nil }
        let start = current.map { $0 + 1 } ?? 0
        for step in 0..<diagnostics.count {
            let k = (start + step) % diagnostics.count
            if DiagnosticMapper.isInPersonSource(diagnostics[k]) { return k }
        }
        return nil
    }
}

/// The code editor with its gutter and diagnostics list (see the file header).
struct StudioEditor: View {
    /// The port the editor names its elements with.
    let port: ExperienceActionPort
    /// The presenter's mirror: the document source, its editor model and the diagnostics.
    let mirror: StudioMirror
    /// Sets the presenter's document source (`StudioPresenter.setSource`); never compiles.
    let edit: @MainActor (String) -> Void

    /// The text shown, coloured.
    @State private var text = AttributedString()
    /// The editor's selection.
    @State private var selection = AttributedTextSelection()
    /// The source `text` holds; nil before the first load.
    @State private var loaded: String?
    /// The diagnostic chosen last (an index of `mirror.diagnostics`), for "Next error".
    @State private var chosen: Int?
    /// The editor's width in points, measured.
    @State private var width: CGFloat = 320
    /// The type size of the environment.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The editor and its diagnostics list.
    var body: some View {
        let size = StudioEditorLayout.fontSize(dynamicTypeSize)
        let metrics = StudioEditorLayout.metrics(fontSize: size)
        let columns = StudioEditorLayout.columns(width: width, advance: metrics.advance)
        let document = mirror.editor
        let rows = document.lines.map { StudioEditorLayout.rows(of: $0.text, columns: columns) }
        let height = CGFloat(rows.reduce(0, +) + 1) * metrics.lineHeight + 2 * StudioEditorLayout.verticalInset
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 2) {
                gutter(document, rows: rows, lineHeight: metrics.lineHeight, fontSize: size)
                TextEditor(text: $text, selection: $selection)
                    .font(SyntaxPalette.font(size: size, emphasis: .regular))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .scrollDisabled(true)
                    .frame(height: height)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                    .accessibilityLabel(Text(verbatim: "Shader source"))
                    .accessibilityHint(Text(verbatim: "Edit the shader; Run compiles it"))
                    .accessibilityIdentifier(port.identifier("editor"))
            }
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            Button {
                moveToNextDiagnostic()
            } label: {
                Text(verbatim: "Next error").frame(minHeight: 44)
            }
            .keyboardShortcut("'", modifiers: .command)
            .disabled(StudioEditorLayout.nextDiagnostic(after: nil, in: mirror.diagnostics) == nil)
            .accessibilityLabel(Text(verbatim: "Next error"))
            .accessibilityHint(Text(verbatim: "Moves the cursor to the next line with a diagnostic"))
            .accessibilityIdentifier(port.identifier("next-diagnostic"))
            diagnosticsList
        }
        .onAppear { if loaded == nil { load(mirror.source, fontSize: size) } }
        .onChange(of: mirror.source) { _, source in
            if source != loaded { load(source, fontSize: size) }
        }
        .onChange(of: text) { _, next in edited(next, fontSize: size) }
        .onChange(of: size) { _, next in recolour(fontSize: next) }
        .onChange(of: mirror.diagnostics) { chosen = nil }
    }

    /// The gutter: one element per line, as tall as the line's wrapped rows.
    private func gutter(_ document: EditorDocument, rows: [Int], lineHeight: CGFloat, fontSize: CGFloat) -> some View {
        let digits = String(document.lines.count).count
        return VStack(alignment: .trailing, spacing: 0) {
            ForEach(document.lines, id: \.number) { line in
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(Color(uiColor: .systemRed))
                        .opacity(line.diagnostics.isEmpty ? 0 : 1)
                    Text(verbatim: String(repeating: " ", count: digits - String(line.number).count)
                         + String(line.number))
                        .foregroundStyle(line.diagnostics.isEmpty ? Color(uiColor: .secondaryLabel)
                                                                  : Color(uiColor: .systemRed))
                }
                .font(SyntaxPalette.font(size: fontSize, emphasis: line.diagnostics.isEmpty ? .regular : .bold))
                .frame(height: CGFloat(rows[line.number - 1]) * lineHeight, alignment: .top)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: StudioEditorLayout.gutterLabel(line)))
                .accessibilityIdentifier(port.identifier("gutter-line-\(line.number)"))
            }
        }
        .padding(.top, StudioEditorLayout.verticalInset)
        .padding(.leading, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Line numbers"))
        .accessibilityIdentifier(port.identifier("gutter"))
    }

    /// The diagnostics list: one button per entry, choosing its line.
    private var diagnosticsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            if mirror.diagnostics.isEmpty {
                Text(verbatim: "No diagnostics").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(Array(mirror.diagnostics.enumerated()), id: \.offset) { k, diagnostic in
                let line = StudioControls.diagnosticText(diagnostic)
                Button {
                    choose(k)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: line)
                            .font(.footnote.monospaced())
                        Text(verbatim: Guidance.forDiagnostic(message: diagnostic.message))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityLabel(Text(verbatim: StudioEditorLayout.diagnosticLabel(diagnostic)))
                .accessibilityHint(Text(verbatim: DiagnosticMapper.isInPersonSource(diagnostic)
                                        ? "Moves the cursor to this line" : "Outside your source"))
                .accessibilityIdentifier(port.identifier("diagnostic-\(k)"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Diagnostics"))
        .accessibilityIdentifier(port.identifier("diagnostics"))
    }

    /// Shows `source`, coloured, with the caret at the start.
    private func load(_ source: String, fontSize: CGFloat) {
        loaded = source
        text = SyntaxPalette.highlighted(source, fontSize: fontSize)
        selection = AttributedTextSelection()
        chosen = nil
    }

    /// After an edit: passes a changed source to the presenter and recolours it (an attribute-only change, such as
    /// the recolouring itself, passes nothing on).
    private func edited(_ next: AttributedString, fontSize: CGFloat) {
        let source = String(next.characters)
        guard source != loaded else { return }
        loaded = source
        edit(source)
        recolour(fontSize: fontSize)
    }

    /// Recolours the text in place, keeping the selection.
    private func recolour(fontSize: CGFloat) {
        let document = EditorDocument(source: String(text.characters))
        text.transform(updating: &selection) { SyntaxPalette.apply(document, to: &$0, fontSize: fontSize) }
    }

    /// Chooses diagnostic `k`: in the person's source, the selection moves to its line's start.
    private func choose(_ k: Int) {
        chosen = k
        guard mirror.diagnostics.indices.contains(k),
              let offset = StudioEditorLayout.selectionOffset(for: mirror.diagnostics[k], in: mirror.editor),
              let index = StudioEditorLayout.index(in: text, utf8Offset: offset) else { return }
        selection = AttributedTextSelection(insertionPoint: index)
    }

    /// Chooses the next diagnostic in the person's source (⌘').
    private func moveToNextDiagnostic() {
        guard let next = StudioEditorLayout.nextDiagnostic(after: chosen, in: mirror.diagnostics) else { return }
        choose(next)
    }
}
