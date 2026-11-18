// EditorModelTests — feature 161 (A22-P03) T-A22-305 (FR-A22-301, FR-A22-306; SC-A22-302; US1 AC1–AC4;
// clarification Q1; contract gap G-EDITOR). The editor's model and rules: the palette maps every token kind and its
// emphasis is a cue apart from colour; recolouring keeps the characters; a broken run marks exactly its line and the
// gutter says "error" there only; outside-source diagnostics come first; a fix clears the marks; choosing a diagnostic
// gives its line's start (`EditorDocument.lineStart`) as an editor index, also after `\r\n` and non-ASCII text; ⌘'
// "next error" skips outside entries and wraps; the layout stacks at compact widths and accessibility sizes; the
// gutter's wrapped rows. Short runs only.
import Foundation
import SwiftUI
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreShaderSource

@MainActor
@Suite(.serialized) struct EditorModelTests {
    /// A diagnostic of `file` on `line`.
    static func diagnostic(_ file: String, _ line: Int?, _ message: String = "m") -> MappedDiagnostic {
        MappedDiagnostic(file: file, line: line, severity: .error, stage: .fragment, message: message)
    }

    @Test func thePaletteMapsEveryKindAndEmphasisIsNotColour() {
        var roles = Set<SyntaxColorRole>()
        for kind in TokenKind.allCases {
            let style = SyntaxPalette.style(for: kind)
            roles.insert(style.role)
            let expected: SyntaxEmphasis = kind == .keyword ? .bold : kind == .comment ? .italic : .regular
            #expect(style.emphasis == expected, "\(kind)")
        }
        #expect(roles.count >= 7, "kinds are told apart by colour: \(roles)")
        // Emphasis is its own cue: regular kinds differ in colour, and bold and italic kinds have their own colours.
        let regular = TokenKind.allCases.filter { SyntaxPalette.style(for: $0).emphasis == .regular }
        #expect(Set(regular.map { SyntaxPalette.style(for: $0).role }).count > 1)
        #expect(SyntaxPalette.style(for: .keyword).role != SyntaxPalette.style(for: .comment).role)
        #expect(!regular.contains { SyntaxPalette.style(for: $0).role == .keyword || SyntaxPalette.style(for: $0).role == .comment })
    }

    @Test func recolouringKeepsTheCharactersAndStylesEachToken() {
        let source = "// c\r\nuniform float u_x; // é\nvoid main() {}\n"
        let text = SyntaxPalette.highlighted(source, fontSize: 14)
        #expect(String(text.characters) == source, "the characters and the trailing newline stay")
        let bold = SyntaxPalette.font(size: 14, emphasis: .bold)
        let italic = SyntaxPalette.font(size: 14, emphasis: .italic)
        var words: [String: Font?] = [:]
        for run in text.runs { words[String(text[run.range].characters)] = run.font }
        #expect(words["uniform"] == bold, "a keyword is bold")
        #expect(words["// c"] == italic && words["// é"] == italic, "comments are italic")
        #expect(words["float"] == SyntaxPalette.font(size: 14, emphasis: .regular))
    }

    @Test func aBrokenRunMarksExactlyItsLineAndAFixClearsIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let mirror = shell.presenter.mirror
        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        #expect(mirror.source == StudioTest.brokenSource)
        #expect(mirror.editor.markedLines == [StudioTest.brokenLine], "\(mirror.diagnostics)")
        for line in mirror.editor.lines {
            let label = StudioEditorLayout.gutterLabel(line)
            #expect(label.hasPrefix("Line \(line.number)"))
            #expect(label.contains("error") == (line.number == StudioTest.brokenLine), "\(label)")
        }
        #expect(mirror.editor.lines.count == EditorDocument(source: StudioTest.brokenSource).lines.count)

        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(mirror.editor.markedLines.isEmpty && mirror.diagnostics.isEmpty)
        #expect(!mirror.editor.lines.contains { StudioEditorLayout.gutterLabel($0).contains("error") })
    }

    @Test func anEditUpdatesTheEditorAndNeverCompiles() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let compiles = presenter.pipeline.compileCount
        #expect(presenter.setSource(StudioTest.fixedSource))
        #expect(presenter.mirror.source == StudioTest.fixedSource)
        #expect(presenter.mirror.editor == EditorDocument(source: StudioTest.fixedSource))
        try StudioTest.draw(session, frames: 2)
        #expect(presenter.pipeline.compileCount == compiles, "an edit compiles nothing")
    }

    @Test func outsideSourceEntriesComeFirst() {
        let person = EditorDocument.personFile
        let list = [Self.diagnostic(person, 5), Self.diagnostic("ss/prelude.glsl", 2), Self.diagnostic(person, 2),
                    Self.diagnostic("unknown", nil)]
        let ordered = StudioPresenter.ordered(list)
        #expect(ordered == [list[1], list[3], list[2], list[0]])
        #expect(StudioControls.diagnosticText(ordered[0]) == "ss/prelude.glsl line 2: m")
        #expect(StudioControls.diagnosticText(ordered[2]) == "Line 2: m")
    }

    @Test func choosingADiagnosticGivesItsLineStart() throws {
        let source = StudioTest.brokenSource
        let document = EditorDocument(source: source, diagnostics: [Self.diagnostic(EditorDocument.personFile, 4)])
        let offset = try #require(StudioEditorLayout.selectionOffset(for: document.lines[3].diagnostics[0],
                                                                     in: document))
        #expect(offset == document.lineStart(4))
        let text = AttributedString(source)
        let index = try #require(StudioEditorLayout.index(in: text, utf8Offset: offset))
        #expect(String(text.characters[index...]).hasPrefix(document.lines[3].text))
        #expect(StudioEditorLayout.selectionOffset(for: Self.diagnostic("ss/prelude.glsl", 4), in: document) == nil)
        #expect(StudioEditorLayout.selectionOffset(for: Self.diagnostic(EditorDocument.personFile, 99),
                                                   in: document) == nil)
        #expect(document.lineStart(0) == nil && document.lineStart(1) == 0)

        // `\r\n`, `\r` and multi-byte text before the line.
        let mixed = "// é\r\nfloat a;\rvoid main() {}\n"
        let model = EditorDocument(source: mixed)
        #expect(model.lineStarts == [0, 7, 16, 31])
        let attributed = SyntaxPalette.highlighted(mixed, fontSize: 14)
        for line in model.lines {
            let start = try #require(model.lineStart(line.number))
            let at = try #require(StudioEditorLayout.index(in: attributed, utf8Offset: start))
            #expect(String(attributed.characters[at...]).hasPrefix(line.text), "line \(line.number)")
        }
        #expect(StudioEditorLayout.index(in: attributed, utf8Offset: 4) == nil, "inside é")
        #expect(StudioEditorLayout.index(in: attributed, utf8Offset: 99) == nil)
    }

    @Test func nextErrorSkipsOutsideEntriesAndWraps() {
        let person = EditorDocument.personFile
        let list = [Self.diagnostic("unknown", nil), Self.diagnostic(person, 2), Self.diagnostic(person, 7)]
        #expect(StudioEditorLayout.nextDiagnostic(after: nil, in: list) == 1)
        #expect(StudioEditorLayout.nextDiagnostic(after: 1, in: list) == 2)
        #expect(StudioEditorLayout.nextDiagnostic(after: 2, in: list) == 1, "wraps, skipping the outside entry")
        #expect(StudioEditorLayout.nextDiagnostic(after: nil, in: [list[0]]) == nil)
        #expect(StudioEditorLayout.nextDiagnostic(after: nil, in: []) == nil)
    }

    @Test func theLayoutStacksAtCompactWidthsAndAccessibilitySizes() {
        #expect(StudioEditorLayout.arrangement(horizontalSizeClass: .regular, dynamicTypeSize: .large) == .sideBySide)
        #expect(StudioEditorLayout.arrangement(horizontalSizeClass: .regular, dynamicTypeSize: .xxxLarge)
                == .sideBySide)
        #expect(StudioEditorLayout.arrangement(horizontalSizeClass: .compact, dynamicTypeSize: .large) == .stacked)
        #expect(StudioEditorLayout.arrangement(horizontalSizeClass: nil, dynamicTypeSize: .large) == .stacked)
        #expect(StudioEditorLayout.arrangement(horizontalSizeClass: .regular, dynamicTypeSize: .accessibility1)
                == .stacked)
        let small = StudioEditorLayout.fontSize(.large), large = StudioEditorLayout.fontSize(.accessibility5)
        #expect(small == StudioEditorLayout.baseFontSize || abs(small - StudioEditorLayout.baseFontSize) < 1)
        #expect(large > 2 * small, "the editor's text follows Dynamic Type")
        let metrics = StudioEditorLayout.metrics(fontSize: small)
        #expect(metrics.advance > 0 && metrics.lineHeight > small)
    }

    @Test func gutterRowsFollowTheWrappedLines() {
        #expect(StudioEditorLayout.rows(of: "", columns: 10) == 1)
        #expect(StudioEditorLayout.rows(of: "0123456789", columns: 10) == 1)
        #expect(StudioEditorLayout.rows(of: "01234 6789 ab", columns: 10) == 2, "wraps at the space")
        #expect(StudioEditorLayout.rows(of: String(repeating: "x", count: 25), columns: 10) == 3, "a long word breaks")
        #expect(StudioEditorLayout.rows(of: "0123456789   ", columns: 10) == 1, "trailing spaces hang")
        #expect(StudioEditorLayout.columns(width: 100, advance: 9) == 10)
        #expect(StudioEditorLayout.columns(width: 0, advance: 9) == 1)
    }
}
