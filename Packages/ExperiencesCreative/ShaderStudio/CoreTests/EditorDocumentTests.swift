// EditorDocumentTests — feature 159 (A22-P01) T-A22-109 (SC-A22-103; FR-A22-105; clarification Q4; User Story 4,
// acceptance scenarios 1 and 2). Host-free and short:
// - lines are numbered from 1 the same way over `\n`, `\r\n`, `\r` and with no final newline, and carry their tokens;
// - diagnostics of `ss/shader.frag` on lines 3 and 7 attach to those lines in input order, and no other line has any;
// - a diagnostic with no line, of another file, or on a line out of range is listed in `outside`, in input order.
import Testing
import VisualCoreShaderSource
import ShaderStudioCore

@Suite struct EditorDocumentTests {
    private static let source = """
    precision highp float;
    uniform float u_speed;
    float wave(float x) {
        return sin(x * u_speed)
    }
    void main() {
        fragColor = vec4(wave(v_uv.x), 0.0, 0.0, 1.0)
    }
    """

    private static func diagnostic(_ line: Int?, _ message: String, file: String = EditorDocument.personFile,
                                   severity: ShaderDiagnostic.Severity = .error) -> MappedDiagnostic {
        MappedDiagnostic(file: file, line: line, severity: severity, stage: .fragment, message: message)
    }

    /// The source with each `\n` replaced by `terminator` (no Foundation needed).
    private static func relined(_ terminator: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false).joined(separator: terminator)
    }

    @Test func linesAreNumberedFromOneWithTokens() {
        let document = EditorDocument(source: Self.source)
        #expect(document.lines.count == 8)
        #expect(document.lines.map(\.number) == Array(1...8))
        #expect(document.lines[3].text == "    return sin(x * u_speed)")
        for line in document.lines {
            #expect(line.tokens.map(\.text).joined() == line.text)
            #expect(line.diagnostics.isEmpty)
        }
        #expect(document.outside.isEmpty)
        #expect(document.markedLines.isEmpty)
    }

    @Test func lineEndingsNumberTheSameWay() {
        let plain = EditorDocument(source: Self.source)
        let crlf = EditorDocument(source: Self.relined("\r\n"))
        let cr = EditorDocument(source: Self.relined("\r"))
        #expect(crlf == plain)
        #expect(cr == plain)
        // A trailing newline adds the empty line an editor shows after it; the numbered lines before it are the same.
        let trailing = EditorDocument(source: Self.source + "\r\n")
        #expect(trailing.lines.count == 9)
        #expect(Array(trailing.lines.prefix(8)) == plain.lines)
        #expect(trailing.lines[8] == EditorLine(number: 9, text: "", tokens: [], diagnostics: []))
        #expect(EditorDocument(source: "").lines == [EditorLine(number: 1, text: "", tokens: [], diagnostics: [])])
    }

    @Test func diagnosticsOnLinesThreeAndSevenAttachInOrder() {
        let first = Self.diagnostic(7, "'fragColor' : missing ';'")
        let second = Self.diagnostic(3, "syntax error")
        let third = Self.diagnostic(7, "unused value", severity: .warning)
        let document = EditorDocument(source: Self.source, diagnostics: [first, second, third])
        #expect(document.lines[2].diagnostics == [second])
        #expect(document.lines[6].diagnostics == [first, third])
        for line in document.lines where line.number != 3 && line.number != 7 { #expect(line.diagnostics.isEmpty) }
        #expect(document.outside.isEmpty)
        #expect(document.markedLines == [3, 7])
        // The tokens are the same with or without diagnostics.
        #expect(document.lines.map(\.tokens) == EditorDocument(source: Self.source).lines.map(\.tokens))
    }

    @Test func otherDiagnosticsGoOutsideInOrder() {
        let noLine = Self.diagnostic(nil, "link failed")
        let prelude = Self.diagnostic(3, "in the prelude", file: "ss/prelude.glsl")
        let include = Self.diagnostic(12, "in an include", file: "vc/noise.glsl")
        let past = Self.diagnostic(9, "past the end")
        let zero = Self.diagnostic(0, "line zero")
        let onLine = Self.diagnostic(1, "on line one")
        let document = EditorDocument(source: Self.source,
                                      diagnostics: [noLine, prelude, onLine, include, past, zero])
        #expect(document.outside == [noLine, prelude, include, past, zero])
        #expect(document.lines[0].diagnostics == [onLine])
        #expect(document.markedLines == [1])
        #expect(EditorDocument.personFile == "ss/shader.frag")
    }
}
